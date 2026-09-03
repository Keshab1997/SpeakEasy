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
const LEADERBOARD = 'battle_leaderboard';

const ROUNDS_PER_MATCH = 5;
const BASE_SCORE = 100;
const MAX_SPEED_BONUS = 50;
const DEFAULT_TIME_LIMIT = 15;

const TROPHY_WIN = 25;
const TROPHY_LOSS = -10;
const TROPHY_DRAW = 5;
const COMEBACK_BONUS = 5; // extra trophies for a win while below 100 (=> +30)
const COMEBACK_THRESHOLD = 100;
const LOSS_SHIELD_AFTER = 3; // 3rd straight loss arms a shield; the 4th loss is free

/**
 * Division trophy floors — once a player earns a rank they can never be
 * demoted below its starting trophy line (rank protection).
 */
function divisionFloor(trophies) {
  if (trophies >= 1500) return 1500; // Grandmaster
  if (trophies >= 800) return 800;   // Master
  if (trophies >= 300) return 300;   // Challenger
  return 0;                          // Novice
}

function isFakeUser(id) {
  return !id || String(id).startsWith('bot_') || String(id).startsWith('guest_');
}

/**
 * Records a finished battle for a real player: updates trophies + career
 * stats on their presence doc AND their leaderboard entry (one write each),
 * server-side so it can't be tampered with.
 *   result: 'win' | 'loss' | 'draw'
 * Trophy rules:
 *   • win  = +25 (or +30 if under 100 trophies — comeback bonus)
 *   • draw = +5
 *   • loss = −10, but every 4th consecutive loss is FREE (loss-streak shield),
 *     and trophies never drop below the floor of the player's current division
 *     nor below 0 (Rookie Shield).
 */
function recordMatchResult(userId, name, photoUrl, result) {
  if (isFakeUser(userId)) return Promise.resolve();

  const presenceRef = db.collection(PRESENCE).doc(userId);
  const lbRef = db.collection(LEADERBOARD).doc(userId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(presenceRef);
    const d = snap.exists ? snap.data() : {};
    const currentTrophies = d.trophies || 100;

    // ── Compute trophy change ──
    let lossStreak = d.lossStreak || 0;
    let applied = 0;
    let shielded = false;
    let comeback = false;

    if (result === 'win') {
      lossStreak = 0;
      comeback = currentTrophies < COMEBACK_THRESHOLD;
      applied = TROPHY_WIN + (comeback ? COMEBACK_BONUS : 0);
    } else if (result === 'draw') {
      applied = TROPHY_DRAW; // loss streak held
    } else {
      // loss
      if (lossStreak >= LOSS_SHIELD_AFTER) {
        shielded = true;
        applied = 0; // free loss — shield consumed
        lossStreak = 0;
      } else {
        applied = TROPHY_LOSS;
        lossStreak += 1;
      }
    }

    const floor = divisionFloor(currentTrophies);
    let trophies = Math.max(0, Math.max(floor, currentTrophies + applied));

    const total = (d.totalMatches || 0) + 1;
    const wins = (d.wins || 0) + (result === 'win' ? 1 : 0);
    const losses = (d.losses || 0) + (result === 'loss' ? 1 : 0);
    const draws = (d.draws || 0) + (result === 'draw' ? 1 : 0);
    // Win streak resets on loss, held on draw, incremented on win.
    const winStreak = result === 'win'
      ? (d.winStreak || 0) + 1
      : (result === 'draw' ? (d.winStreak || 0) : 0);
    const bestStreak = Math.max(d.bestStreak || 0, winStreak);

    const base = {
      name: d.name || name || 'Player',
      photoUrl: d.photoUrl || photoUrl || '',
      trophies,
      wins,
      losses,
      draws,
      totalMatches: total,
      winStreak,
      bestStreak,
      lossStreak,
      lastShielded: shielded,
      lastComeback: comeback,
      lastActive: now,
    };

    // Presence doc (powers profile card + online list).
    if (!snap.exists) {
      tx.set(presenceRef, { id: userId, isOnline: true, ...base }, { merge: true });
    } else {
      tx.update(presenceRef, base);
    }

    // Leaderboard entry (doc id = userId), safe upsert.
    const lbSnap = await tx.get(lbRef);
    if (!lbSnap.exists) {
      tx.set(lbRef, { userId, ...base });
    } else {
      tx.update(lbRef, base);
    }
  });
}

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

      const jobs = [];
      const isDraw = !winnerId;
      const info = (p) => ({
        name: p && (p.name || ''),
        photoUrl: p && (p.photoUrl || ''),
      });

      if (isForfeit) {
        if (p1 && p2) {
          if (p1.isForfeited) {
            jobs.push(recordMatchResult(p1.id, info(p1).name, info(p1).photoUrl, 'loss'));
            jobs.push(recordMatchResult(p2.id, info(p2).name, info(p2).photoUrl, 'win'));
          } else {
            jobs.push(recordMatchResult(p2.id, info(p2).name, info(p2).photoUrl, 'loss'));
            jobs.push(recordMatchResult(p1.id, info(p1).name, info(p1).photoUrl, 'win'));
          }
        }
      } else if (isDraw) {
        if (p1) jobs.push(recordMatchResult(p1.id, p1.name, p1.photoUrl, 'draw'));
        if (p2) jobs.push(recordMatchResult(p2.id, p2.name, p2.photoUrl, 'draw'));
      } else if (winnerId) {
        if (p1 && p1.id === winnerId) {
          jobs.push(recordMatchResult(p1.id, p1.name, p1.photoUrl, 'win'));
          if (p2) jobs.push(recordMatchResult(p2.id, p2.name, p2.photoUrl, 'loss'));
        } else if (p2) {
          jobs.push(recordMatchResult(p2.id, p2.name, p2.photoUrl, 'win'));
          if (p1) jobs.push(recordMatchResult(p1.id, p1.name, p1.photoUrl, 'loss'));
        }
      }

      await Promise.all(jobs);
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
        // NOTE: no `android_channel_id` — OneSignal now rejects unknown ids
        // with HTTP 400 "Could not find android_channel_id" (verified 2026-09-03).
        ttl: 259200,
        data: {
          actionType: 'battle_challenge',
          type: 'battle_challenge',
          notification_id: `battle_${snap.id}`,
        },
      };

      const res = await fetch('https://api.onesignal.com/notifications', {
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

// ---------------------------------------------------------------------------
// 4) Daily server push — delivers even when app is killed / not opened for weeks
//    Uses OneSignal high-priority FCM via Play Services (not AlarmManager).
//    Local AlarmManager is killed by OEMs when app is swiped; this is not.
// ---------------------------------------------------------------------------
async function sendOneSignalToAll(title, body, extraData) {
  try {
    const cfgSnap = await db.collection('Config').doc('app_settings').get();
    const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
    const appId = os && os.AppId;
    const apiKey = os && os.ApiKey;
    if (!appId || !apiKey) {
      functions.logger.log('dailyPush: OneSignal config missing — skip');
      return;
    }
    const payload = {
      app_id: appId,
      target_channel: 'push',
      included_segments: ['All'],
      headings: { en: title },
      contents: { en: body },
      priority: 10,
      // NOTE: no `android_channel_id` — OneSignal now rejects unknown ids
      // with HTTP 400 "Could not find android_channel_id" (verified 2026-09-03).
      ttl: 259200,
      data: extraData || {},
    };
    const res = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8', Authorization: `Key ${apiKey}` },
      body: JSON.stringify(payload),
    });
    const text = await res.text();
    if (!res.ok) functions.logger.error('dailyPush failed', res.status, text);
    else functions.logger.log('dailyPush sent:', title, text);
  } catch (e) {
    functions.logger.error('dailyPush error', e);
  }
}

// 8:00 AM Asia/Kolkata — Daily Quiz reminder (morning, fun)
exports.dailyQuizPush = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await sendOneSignalToAll(
      '🧠 Daily Quiz Ready! ☀️',
      'Good morning! 10 ta fun question tomar jonno ready — 5 min e quiz ta complete koro? 🔥',
      { type: 'daily_quiz', payload: 'daily_quiz', actionType: 'daily_quiz' }
    );
    return null;
  });

// 7:00 PM Asia/Kolkata — Practice reminder
exports.dailyPracticePush = functions.pubsub
  .schedule('0 19 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await sendOneSignalToAll(
      '⏰ Time to Practice! 🎯',
      "Don't break your streak! 5 min practice kore felo 🔥",
      { type: 'practice_reminder', payload: 'practice_reminder', actionType: 'game' }
    );
    return null;
  });

// ---------------------------------------------------------------------------
// 5) Daily Quiz Winner announcement — 9:00 PM Asia/Kolkata (or config time)
//    Reads TODAY's real `daily_quiz_leaderboard/{date}/entries` and pushes the
//    champion's NAME + SCORE to everyone, encouraging others to play tomorrow.
//    Toggle: Config/app_settings → dailyQuizWinnerPush.enabled = false.
// ---------------------------------------------------------------------------
function kolkataDateKey() {
  // en-CA locale yields YYYY-MM-DD — same key the app uses.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function buildWinnerMessage(w, second, third) {
  const name = String(w.userName || 'Champion').trim().slice(0, 20);
  const score = Number(w.score || 0);
  const correct = w.correctCount != null ? Number(w.correctCount) : null;

  let title = `🏆 ${name} — Ajker Champion! 🎉`;
  if (title.length > 55) title = title.slice(0, 52) + '...';

  let body = `${name} ${score} points score koreche!`;
  if (correct != null && correct > 0) body += ` (${correct} ta correct)`;
  if (second) {
    body += ` ${String(second.userName || '').slice(0, 20)} ${Number(second.score || 0)} points — ektu holei pichhe!`;
  }
  body += ' Kal tomar turn — quiz khelo, naam likho! 💪🔥';
  if (body.length > 180) body = body.slice(0, 177) + '...';
  return { title, body };
}

exports.dailyQuizWinnerPush = functions.pubsub
  .schedule('0 21 * * *') // 9:00 PM IST
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    try {
      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const cfg = cfgSnap.exists ? cfgSnap.data() : {};
      const wCfg = (cfg.dailyQuizWinnerPush || {});
      if (wCfg.enabled === false) {
        functions.logger.log('dailyQuizWinnerPush: disabled in config — skip');
        return null;
      }

      const date = kolkataDateKey();
      const snap = await db
        .collection('daily_quiz_leaderboard')
        .doc(date)
        .collection('entries')
        .orderBy('score', 'desc')
        .orderBy('totalTime', 'asc')
        .limit(3)
        .get();

      if (snap.empty) {
        functions.logger.log('dailyQuizWinnerPush: no entries for ' + date + ' — skip');
        return null;
      }

      const entries = snap.docs.map((d) => d.data());
      const { title, body } = buildWinnerMessage(entries[0], entries[1], entries[2]);

      await sendOneSignalToAll(title, body, {
        type: 'quiz_winner',
        payload: date,
        actionType: 'daily_quiz',
        winnerName: String(entries[0].userName || ''),
        winnerScore: String(entries[0].score || 0),
      });
      functions.logger.log(
        'dailyQuizWinnerPush sent — ' + date + ' winner: ' + entries[0].userName + ' (' + entries[0].score + ')'
      );
    } catch (e) {
      functions.logger.error('dailyQuizWinnerPush error', e);
    }
    return null;
  });
