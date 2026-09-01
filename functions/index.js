/**
 * SpeakEasy — Battle Arena Cloud Functions
 * ---------------------------------------------------------------------------
 * 1. onBattleRoomWrite  — SERVER-AUTHORITATIVE scoring & trophy distribution.
 *    • Recomputes each player's score from the answers they actually gave
 *      (correctAnswer comes from the immutable questions stored in the room).
 *    • Any client-sent score higher than the legitimate value is clamped,
 *      so a cheater can't write currentScore = 99999.
 *    • When the match completes (both finished / 5 rounds, or a forfeit),
 *      awards trophies on the server: winner +25, loser -10, draw +5,
 *      exactly once per room (guarded by a `trophiesAwarded` flag).
 *
 * 2. cleanupBattleData (runs every 5 minutes) — removes garbage:
 *    • matchmaking queue entries older than 30s
 *    • pending challenges older than 90s (never answered)
 *    • in_progress rooms abandoned for > 30 minutes (marked abandoned)
 *
 * 3. onPresenceOffline — if a player is online but their last heartbeat is
 *    older than 4 minutes AND they are marked in a battle, any in-progress
 *    room they belong to is forfeit to the opponent (handled inside cleanup).
 *
 * Pricing: all of these run well inside the free Blaze allowance
 * (2,000,000 function calls/month).
 */

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

const ROOMS = 'battle_rooms';
const QUEUE = 'battle_queue';
const CHALLENGES = 'battle_challenges';
const PRESENCE = 'battle_presence';

const ROUNDS_PER_MATCH = 5;
const BASE_SCORE = 100;
const MAX_SPEED_BONUS = 50;
const DEFAULT_TIME_LIMIT = 15;

const TROPHY_WIN = 25;
const TROPHY_LOSS = -10;
const TROPHY_DRAW = 5;

// ---------------------------------------------------------------------------
// Score helpers (mirrors the client's BattleGameService)
// ---------------------------------------------------------------------------

function roundScore(isCorrect, timeTaken, timeLimit) {
  if (!isCorrect) return 0;
  const limit = timeLimit > 0 ? timeLimit : DEFAULT_TIME_LIMIT;
  const clamped = Math.max(0, Math.min(timeTaken == null ? limit : timeTaken, limit));
  const speedBonus = Math.round(((limit - clamped) * MAX_SPEED_BONUS) / limit);
  return BASE_SCORE + speedBonus;
}

/**
 * Recomputes the legitimate total score for a player map from the room's
 * questions and the per-round answers/times stored by that player.
 */
function computeLegitScore(player, questions) {
  const answers = player.roundAnswers || {};
  const times = player.roundTimes || {};
  let total = 0;
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    const key = String(i);
    if (!(key in answers)) continue; // didn't answer this round (0 pts)
    const given = answers[key];
    const correct = given === q.correctAnswer;
    const limit = q.timeLimit || DEFAULT_TIME_LIMIT;
    total += roundScore(correct, times[key], limit);
  }
  return total;
}

function changeTrophies(userId, delta) {
  if (!userId || String(userId).startsWith('bot_') || String(userId).startsWith('guest_')) {
    return Promise.resolve(); // bots / guests have no server trophy record
  }
  const ref = db.collection(PRESENCE).doc(userId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? (snap.data().trophies || 100) : 100;
    const next = Math.max(0, current + delta);
    if (!snap.exists) {
      tx.set(ref, { trophies: next, lastActive: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } else {
      tx.update(ref, { trophies: next, lastActive: admin.firestore.FieldValue.serverTimestamp() });
    }
  });
}

// ---------------------------------------------------------------------------
// 1) Server-authoritative score & trophies on every room write
// ---------------------------------------------------------------------------

exports.onBattleRoomWrite = functions.firestore
  .document(`${ROOMS}/{roomId}`)
  .onWrite(async (change) => {
    const after = change.after;
    if (!after.exists) return null;
    const room = after.data();
    const questions = Array.isArray(room.questions) ? room.questions : [];
    if (questions.length === 0) return null;

    const updates = {};

    // --- Anti-cheat: clamp each player's currentScore to the legit value ---
    const maxPossible = questions.length * (BASE_SCORE + MAX_SPEED_BONUS);
    ['player1', 'player2'].forEach((key) => {
      const p = room[key];
      if (!p || !p.id) return;
      const reported = typeof p.currentScore === 'number' ? p.currentScore : 0;
      const answers = p.roundAnswers || {};
      const times = p.roundTimes || {};
      const answeredKeys = Object.keys(answers);

      let legit;
      const hasTimingForAll = answeredKeys.every((k) => times[k] !== undefined);
      if (hasTimingForAll && answeredKeys.length > 0) {
        // New client sends per-round times → we can recompute exactly.
        legit = computeLegitScore(p, questions);
      } else {
        // Older client / no timing data → only enforce the hard maximum cap
        // (can't prove speed bonus, so don't penalise a legitimate player).
        legit = maxPossible;
      }

      if (reported > legit) {
        updates[`${key}.currentScore`] = legit;
      }
    });

    const answeredCount = (p) => Object.keys(p && p.roundAnswers ? p.roundAnswers : {}).length;
    const bothFinished =
      answeredCount(room.player1) >= questions.length &&
      answeredCount(room.player2) >= questions.length;

    const isForfeit = Boolean(
      (room.player1 && room.player1.isForfeited) ||
        (room.player2 && room.player2.isForfeited)
    );

    const shouldFinish =
      room.status !== 'completed' && (bothFinished || isForfeit);

    if (shouldFinish) {
      const s1 = room.player1 && room.player1.currentScore ? room.player1.currentScore : 0;
      const s2 = room.player2 && room.player2.currentScore ? room.player2.currentScore : 0;

      let winnerId = null;
      if (isForfeit) {
        winnerId = room.winnerId ||
          (room.player1 && room.player1.isForfeited ? room.player2.id : room.player1.id);
      } else if (s1 !== s2) {
        winnerId = s1 > s2 ? room.player1.id : room.player2.id;
      }

      updates.status = 'completed';
      updates.winnerId = winnerId;
      updates.finishedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    // Apply score correction / completion first.
    if (Object.keys(updates).length > 0) {
      await after.ref.update(updates);
    }

    // --- Award trophies exactly once when a match completes ---
    if ((room.status === 'completed' || shouldFinish) && !room.trophiesAwarded) {
      const winnerId = updates.winnerId !== undefined ? updates.winnerId : room.winnerId;
      const p1 = room.player1;
      const p2 = room.player2;

      const trophyJobs = [];
      const isDraw = !winnerId;

      if (isForfeit) {
        // Loser (who forfeited) gets -10, winner gets +25.
        if (p1 && p2) {
          if (p1.isForfeited) {
            trophyJobs.push(changeTrophies(p1.id, TROPHY_LOSS));
            trophyJobs.push(changeTrophies(p2.id, TROPHY_WIN));
          } else {
            trophyJobs.push(changeTrophies(p2.id, TROPHY_LOSS));
            trophyJobs.push(changeTrophies(p1.id, TROPHY_WIN));
          }
        }
      } else if (isDraw) {
        trophyJobs.push(changeTrophies(p1 && p1.id, TROPHY_DRAW));
        trophyJobs.push(changeTrophies(p2 && p2.id, TROPHY_DRAW));
      } else if (winnerId) {
        if (p1 && p1.id === winnerId) {
          trophyJobs.push(changeTrophies(p1.id, TROPHY_WIN));
          trophyJobs.push(changeTrophies(p2 && p2.id, TROPHY_LOSS));
        } else if (p2) {
          trophyJobs.push(changeTrophies(p2.id, TROPHY_WIN));
          trophyJobs.push(changeTrophies(p1 && p1.id, TROPHY_LOSS));
        }
      }

      await Promise.all(trophyJobs);
      await after.ref.update({ trophiesAwarded: true });
    }

    return null;
  });

// ---------------------------------------------------------------------------
// 1b) Send a push to the challenged player when a 1v1 challenge is created.
//     Targets exactly that user via OneSignal external_id alias (the app calls
//     OneSignal.login(uid) on sign-in). App ID + REST key come from the same
//     Firestore Config/app_settings.onesignal doc the admin panel uses.
// ---------------------------------------------------------------------------

exports.onBattleChallengeCreate = functions.firestore
  .document(`${CHALLENGES}/{challengeId}`)
  .onCreate(async (snap) => {
    try {
      const ch = snap.data() || {};
      const toUid = ch.toUserId;
      const fromName = ch.fromUserName || 'A player';
      if (!toUid || String(toUid).startsWith('guest_')) return null;

      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
      const appId = os && os.AppId;
      const apiKey = os && os.ApiKey;
      if (!appId || !apiKey) {
        functions.logger.log('onBattleChallengeCreate: OneSignal config missing — skip push');
        return null;
      }

      const payload = {
        app_id: appId,
        target_channel: 'push',
        include_aliases: { external_id: [toUid] },
        headings: { en: `⚔️ ${fromName} challenges you!` },
        contents: { en: 'Tap to accept the 1v1 English duel!' },
        priority: 10,
        small_icon: 'ic_stat_onesignal_default',
        large_icon: 'ic_stat_onesignal_default',
        data: {
          actionType: 'battle_challenge',
          type: 'battle_challenge',
          notification_id: `battle_${snap.id}`,
        },
      };

      const res = await fetch('https://onesignal.com/api/v1/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          Authorization: `Key ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });
      const body = await res.text();
      if (!res.ok) {
        functions.logger.error('OneSignal challenge push failed', res.status, body);
      } else {
        functions.logger.log('Battle challenge push sent →', toUid, body);
      }
    } catch (e) {
      functions.logger.error('onBattleChallengeCreate error', e);
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 2) Scheduled cleanup (every 5 minutes)
// ---------------------------------------------------------------------------

exports.cleanupBattleData = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async () => {
    const now = Date.now();

    // 2a. Stale matchmaking queue entries (> 30s)
    try {
      const queueSnap = await db.collection(QUEUE).get();
      const batch = db.batch();
      let n = 0;
      queueSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 999999;
        if (age > 30 * 1000) {
          batch.delete(doc.ref);
          n++;
        }
      });
      if (n > 0) await batch.commit();
      functions.logger.log(`cleanup: removed ${n} stale queue entries`);
    } catch (e) {
      functions.logger.error('queue cleanup failed', e);
    }

    // 2b. Expired pending challenges (> 90s)
    try {
      const chSnap = await db
        .collection(CHALLENGES)
        .where('status', '==', 'pending')
        .get();
      const batch = db.batch();
      let n = 0;
      chSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 0;
        if (age > 90 * 1000) {
          batch.delete(doc.ref);
          n++;
        }
      });
      if (n > 0) await batch.commit();
      functions.logger.log(`cleanup: removed ${n} expired challenges`);
    } catch (e) {
      functions.logger.error('challenge cleanup failed', e);
    }

    // 2c. Abandoned in-progress rooms (> 30 min) → mark abandoned
    try {
      const roomsSnap = await db
        .collection(ROOMS)
        .where('status', '==', 'in_progress')
        .get();
      const batch = db.batch();
      let n = 0;
      roomsSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 0;
        if (age > 30 * 60 * 1000) {
          batch.update(doc.ref, { status: 'abandoned' });
          n++;
        }
      });
      if (n > 0) await batch.commit();
      functions.logger.log(`cleanup: abandoned ${n} stale rooms`);
    } catch (e) {
      functions.logger.error('room cleanup failed', e);
    }

    return null;
  });

// ---------------------------------------------------------------------------
// 3) Auto-forfeit: a player whose presence went silent mid-battle loses.
//    Runs with the same schedule; checks online players who haven't sent a
//    heartbeat in > 4 minutes while flagged isInBattle.
// ---------------------------------------------------------------------------

exports.autoForfeitDisconnectedPlayers = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async () => {
    const now = Date.now();
    try {
      const presenceSnap = await db
        .collection(PRESENCE)
        .where('isInBattle', '==', true)
        .get();

      const deadIds = [];
      presenceSnap.forEach((doc) => {
        const d = doc.data();
        const last = d.lastActive && d.lastActive.toDate ? d.lastActive.toDate() : null;
        const age = last ? now - last.getTime() : 999999;
        if (age > 4 * 60 * 1000) deadIds.push(doc.id);
      });

      if (deadIds.length === 0) return null;

      // Find any in-progress rooms involving a disconnected player.
      const roomsSnap = await db
        .collection(ROOMS)
        .where('status', '==', 'in_progress')
        .get();

      const batch = db.batch();
      let changed = 0;
      roomsSnap.forEach((doc) => {
        const r = doc.data();
        const p1id = r.player1 && r.player1.id;
        const p2id = r.player2 && r.player2.id;
        let forfeitKey = null;
        let winner = null;
        if (deadIds.includes(p1id)) {
          forfeitKey = 'player1.isForfeited';
          winner = p2id;
        } else if (deadIds.includes(p2id)) {
          forfeitKey = 'player2.isForfeited';
          winner = p1id;
        }
        if (forfeitKey && winner) {
          batch.update(doc.ref, {
            status: 'completed',
            winnerId: winner,
            [forfeitKey]: true,
            finishedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          changed++;
        }
      });

      if (changed > 0) {
        await batch.commit();
        functions.logger.log(`auto-forfeit: resolved ${changed} rooms with disconnected players`);
      }
    } catch (e) {
      functions.logger.error('auto-forfeit failed', e);
    }
    return null;
  });
