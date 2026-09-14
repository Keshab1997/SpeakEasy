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
const ANSWER_KEYS = 'battle_answer_keys';
const CHALLENGES = 'battle_challenges';
const PRESENCE = 'battle_presence';
const LEADERBOARD = 'battle_leaderboard';
const FRIEND_REQUESTS = 'friend_requests';
const FRIENDSHIPS = 'friendships';

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
// Server-side verification for SEED rooms: recompute a player's score from
// their recorded answers/times + the admin-only answer key. The correct
// answers never live on the room doc, so a modified client cannot fake them.
function computeLegitScoreFromAnswers(player, correctAnswers, timeLimits) {
  const answers = player.roundAnswers || {};
  const times = player.roundTimes || {};
  let total = 0;
  for (let i = 0; i < correctAnswers.length; i++) {
    const k = String(i);
    if (!(k in answers)) continue; // unanswered round = 0 pts
    const isRight = answers[k] === correctAnswers[i];
    const limit = (Array.isArray(timeLimits) && timeLimits[i]) || DEFAULT_TIME_LIMIT;
    total += roundScore(isRight, times[k], limit);
  }
  return total;
}

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

    // SEED rooms carry only a question seed in the doc — both clients
    // regenerate the questions locally and the correct answers live in the
    // admin-only battle_answer_keys collection (never readable by clients).
    const isSeedRoom = Number.isInteger(room.questionSeed);
    const questionCount = isSeedRoom
      ? (Number(room.questionCount) || 5)
      : questions.length;
    if (!isSeedRoom && questions.length === 0) return null;

    // Load the answer key once for seed rooms (non-fatal if missing).
    let seedKey = null;
    if (isSeedRoom) {
      try {
        const keySnap = await db.collection(ANSWER_KEYS).doc(after.id).get();
        if (keySnap.exists) seedKey = keySnap.data();
      } catch (e) {
        functions.logger.warn('answer key read failed', e);
      }
    }
    const hasKey =
      isSeedRoom && seedKey && Array.isArray(seedKey.answers) && seedKey.answers.length > 0;

    const updates = {};

    // --- Anti-cheat: clamp each player's currentScore to the legit value ---
    const maxPossible = questionCount * (BASE_SCORE + MAX_SPEED_BONUS);
    ['player1', 'player2'].forEach((key) => {
      const p = room[key];
      if (!p || !p.id) return;
      const reported = typeof p.currentScore === 'number' ? p.currentScore : 0;
      const answers = p.roundAnswers || {};
      const times = p.roundTimes || {};
      const answeredKeys = Object.keys(answers);

      let legit;
      const hasTimingForAll = answeredKeys.every((k) => times[k] !== undefined);
      if (isSeedRoom) {
        // Verified against the admin-only answer key. If the key is missing
        // (write failed / very old room) fall back to the hard cap so we
        // never penalise a legitimate player.
        legit = hasKey && hasTimingForAll && answeredKeys.length > 0
          ? computeLegitScoreFromAnswers(p, seedKey.answers, seedKey.timeLimits)
          : maxPossible;
      } else if (hasTimingForAll && answeredKeys.length > 0) {
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
      answeredCount(room.player1) >= questionCount &&
      answeredCount(room.player2) >= questionCount;

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
// 1c) When a challenge is ACCEPTED (especially an async one, where the
//     challenger may be offline by now), push the challenger so they come
//     back and join the room: "X accepted your challenge — join now!"
//     The challenger's app auto-joins the room on open via the outgoing
//     challenge listener (GlobalBattleChallengeGate).
// ---------------------------------------------------------------------------

exports.onBattleChallengeUpdate = functions.firestore
  .document(`${CHALLENGES}/{challengeId}`)
  .onUpdate(async (change) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      // Only react to the pending -> accepted transition.
      if (before.status !== 'pending' || after.status !== 'accepted') return null;

      const toUid = after.toUserId;
      const fromUid = after.fromUserId;
      if (!toUid || !fromUid || String(fromUid).startsWith('guest_')) return null;

      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
      const appId = os && os.AppId;
      const apiKey = os && os.ApiKey;
      if (!appId || !apiKey) {
        functions.logger.log('onBattleChallengeUpdate: OneSignal config missing — skip push');
        return null;
      }

      // Receiver's display name (presence doc has it; users doc as fallback).
      let toName = 'A player';
      try {
        const presenceSnap = await db.collection(PRESENCE).doc(toUid).get();
        if (presenceSnap.exists && presenceSnap.data().name) {
          toName = presenceSnap.data().name;
        } else {
          const userSnap = await db.collection('users').doc(toUid).get();
          if (userSnap.exists && userSnap.data().name) {
            toName = userSnap.data().name;
          }
        }
      } catch (_) {}

      const payload = {
        app_id: appId,
        target_channel: 'push',
        include_aliases: { external_id: [fromUid] },
        headings: { en: '⚔️ Challenge accepted!' },
        contents: { en: `${toName} accepted your challenge — open the app and join the battle now!` },
        priority: 10,
        // NOTE: no `android_channel_id` — OneSignal now rejects unknown ids
        // with HTTP 400 "Could not find android_channel_id" (verified 2026-09-03).
        ttl: 3600,
        data: {
          actionType: 'battle_challenge',
          type: 'battle_challenge',
          notification_id: `battle_accepted_${change.after.id}`,
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
        functions.logger.error('OneSignal accepted push failed', res.status, body);
      } else {
        functions.logger.log('Challenge-accepted push sent →', fromUid, body);
      }
    } catch (e) {
      functions.logger.error('onBattleChallengeUpdate error', e);
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 1d) FRIENDS — push the target when someone sends a friend request.
// ---------------------------------------------------------------------------

exports.onFriendRequestCreate = functions.firestore
  .document(`${FRIEND_REQUESTS}/{requestId}`)
  .onCreate(async (snap) => {
    try {
      const req = snap.data() || {};
      const toUid = req.toUserId;
      const fromName = req.fromUserName || 'A learner';
      if (!toUid || String(toUid).startsWith('guest_')) return null;

      // ── Dedup guard ────────────────────────────────────────────────
      // New clients use a deterministic doc id (req_{from}_{to}) so
      // duplicates are impossible, but legacy auto-id requests could stack
      // up (the "accept one, three more appear" bug). If several pending
      // requests exist between the same pair, keep ONLY the oldest and
      // delete the rest — including this one if it isn't the oldest.
      try {
        const dupSnap = await db
          .collection(FRIEND_REQUESTS)
          .where('toUserId', '==', toUid)
          .where('status', '==', 'pending')
          .get();
        const samePair = [];
        dupSnap.forEach((d) => {
          if (d.id === snap.id) {
            samePair.push(d); // include self
          } else if ((d.data() || {}).fromUserId === req.fromUserId) {
            samePair.push(d);
          }
        });
        if (samePair.length > 1) {
          let oldest = null;
          samePair.forEach((d) => {
            const c = (d.data() || {}).createdAt;
            const t = c && c.toDate ? c.toDate().getTime() : Number.MAX_SAFE_INTEGER;
            if (oldest === null || t < oldest.t) oldest = { id: d.id, t };
          });
          const dels = [];
          samePair.forEach((d) => {
            if (d.id !== oldest.id) dels.push(d.ref.delete());
          });
          await Promise.all(dels);
          functions.logger.log(
            `friend-request dedup: removed ${dels.length} duplicate(s) between ${req.fromUserId} -> ${toUid}`
          );
          // If THIS doc was one of the deleted duplicates, stop here —
          // the receiver already has the original request.
          if (oldest.id !== snap.id) return null;
        }
      } catch (e) {
        functions.logger.error('friend-request dedup check failed', e);
      }

      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
      const appId = os && os.AppId;
      const apiKey = os && os.ApiKey;
      if (!appId || !apiKey) {
        functions.logger.log('onFriendRequestCreate: OneSignal config missing — skip push');
        return null;
      }

      const payload = {
        app_id: appId,
        target_channel: 'push',
        include_aliases: { external_id: [toUid] },
        headings: { en: '🤝 New friend request!' },
        contents: { en: `${fromName} wants to be your friend. Open the Battle Arena to respond!` },
        priority: 10,
        ttl: 259200,
        data: {
          actionType: 'friend_request',
          type: 'friend_request',
          notification_id: `friend_req_${snap.id}`,
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
        functions.logger.error('OneSignal friend-request push failed', res.status, body);
      } else {
        functions.logger.log('Friend request push sent →', toUid);
      }
    } catch (e) {
      functions.logger.error('onFriendRequestCreate error', e);
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 1e) FRIENDS — when a request is ACCEPTED, write BOTH sides of the
//     friendship (clients may only write their own doc) and push the
//     requester "X accepted your friend request!".
// ---------------------------------------------------------------------------

exports.onFriendRequestUpdate = functions.firestore
  .document(`${FRIEND_REQUESTS}/{requestId}`)
  .onUpdate(async (change) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status !== 'pending' || after.status !== 'accepted') return null;

      const fromUid = after.fromUserId;
      const toUid = after.toUserId;
      if (!fromUid || !toUid) return null;

      // Receiver's display snapshot (presence doc → users doc fallback).
      let toName = 'A learner';
      let toPhoto = '';
      let toTrophies = 100;
      try {
        const presenceSnap = await db.collection(PRESENCE).doc(toUid).get();
        if (presenceSnap.exists) {
          const p = presenceSnap.data();
          toName = p.name || toName;
          toPhoto = p.photoUrl || '';
          toTrophies = typeof p.trophies === 'number' ? p.trophies : toTrophies;
        } else {
          const userSnap = await db.collection('users').doc(toUid).get();
          if (userSnap.exists) {
            const u = userSnap.data();
            toName = u.name || toName;
            toPhoto = u.photoUrl || '';
            toTrophies = typeof u.trophies === 'number' ? u.trophies : toTrophies;
          }
        }
      } catch (_) {}

      const now = new Date();
      const batch = db.batch();
      batch.set(
        db.collection(FRIENDSHIPS).doc(fromUid),
        {
          friends: {
            [toUid]: {
              name: toName,
              photoUrl: toPhoto,
              trophies: toTrophies,
              addedAt: now,
            },
          },
          updatedAt: now,
        },
        { merge: true }
      );
      batch.set(
        db.collection(FRIENDSHIPS).doc(toUid),
        {
          friends: {
            [fromUid]: {
              name: after.fromUserName || 'A learner',
              photoUrl: after.fromUserPhoto || '',
              trophies: typeof after.fromUserTrophies === 'number' ? after.fromUserTrophies : 100,
              addedAt: now,
            },
          },
          updatedAt: now,
        },
        { merge: true }
      );
      await batch.commit();

      // Push the requester.
      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
      const appId = os && os.AppId;
      const apiKey = os && os.ApiKey;
      if (!appId || !apiKey || String(fromUid).startsWith('guest_')) return null;

      const payload = {
        app_id: appId,
        target_channel: 'push',
        include_aliases: { external_id: [fromUid] },
        headings: { en: '🎉 Friend request accepted!' },
        contents: { en: `${toName} is now your friend. Challenge them to a duel! ⚔️` },
        priority: 10,
        ttl: 259200,
        data: {
          actionType: 'friend_accepted',
          type: 'friend_accepted',
          notification_id: `friend_acc_${change.after.id}`,
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
        functions.logger.error('OneSignal friend-accepted push failed', res.status, body);
      } else {
        functions.logger.log('Friend accepted push sent →', fromUid);
      }
    } catch (e) {
      functions.logger.error('onFriendRequestUpdate error', e);
    }
    return null;
  });

// ---------------------------------------------------------------------------
// 1f) FRIENDS — "friend is online now" alert.
//     Fires only on the isOnline false→true transition of battle_presence
//     (heartbeats keep isOnline true, so they never retrigger this).
//     Reads my friends list and pushes all of them in ONE OneSignal call.
// ---------------------------------------------------------------------------

exports.onBattlePresenceOnline = functions.firestore
  .document(`${PRESENCE}/{userId}`)
  .onUpdate(async (change) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};

      // Only the offline → online transition.
      if (before.isOnline === true || after.isOnline !== true) return null;

      const uid = change.params.userId;
      if (!uid || uid.startsWith('guest_')) return null;

      const fsSnap = await db.collection(FRIENDSHIPS).doc(uid).get();
      if (!fsSnap.exists) return null;
      const friends = (fsSnap.data() || {}).friends || {};
      const friendIds = Object.keys(friends)
        .filter((id) => !id.startsWith('guest_'))
        .slice(0, 100); // OneSignal alias batch safety cap
      if (friendIds.length === 0) return null;

      const cfgSnap = await db.collection('Config').doc('app_settings').get();
      const os = cfgSnap.exists ? cfgSnap.data() && cfgSnap.data().onesignal : null;
      const appId = os && os.AppId;
      const apiKey = os && os.ApiKey;
      if (!appId || !apiKey) return null;

      const name = after.name || 'Your friend';
      const payload = {
        app_id: appId,
        target_channel: 'push',
        include_aliases: { external_id: friendIds },
        headings: { en: `🟢 ${name} is online!` },
        contents: { en: 'Your friend just entered the Battle Arena — challenge them to a duel ⚔️' },
        priority: 10,
        ttl: 3600,
        data: {
          actionType: 'friend_online',
          type: 'friend_online',
          notification_id: `friend_online_${uid}_${Date.now()}`,
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
        functions.logger.error('OneSignal friend-online push failed', res.status, body);
      } else {
        functions.logger.log(`Friend-online push sent for ${uid} → ${friendIds.length} friend(s)`);
      }
    } catch (e) {
      functions.logger.error('onBattlePresenceOnline error', e);
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

    // 2a. Stale matchmaking queue entries (> 30s) + DEDUP per user.
    //     Spam-mashing Quick Match could leave several waiting entries for
    //     one user; keep only the NEWEST per userId.
    try {
      const queueSnap = await db.collection(QUEUE).get();
      const batch = db.batch();
      let n = 0;
      const newestByUser = new Map(); // userId -> { time, ref }
      queueSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 999999;
        if (age > 30 * 1000) {
          batch.delete(doc.ref);
          n++;
          return;
        }
        if (d.status !== 'waiting') return;
        const uid = d.userId;
        if (!uid) return;
        const t = created ? created.getTime() : 0;
        const cur = newestByUser.get(uid);
        if (!cur) {
          newestByUser.set(uid, { time: t, ref: doc.ref });
        } else if (t > cur.time) {
          batch.delete(cur.ref); // the older duplicate
          n++;
          newestByUser.set(uid, { time: t, ref: doc.ref });
        } else {
          batch.delete(doc.ref); // this one is older
          n++;
        }
      });
      if (n > 0) await batch.commit();
      if (n > 0) functions.logger.log(`cleanup: removed ${n} stale/duplicate queue entries`);
    } catch (e) {
      functions.logger.error('queue cleanup failed', e);
    }

    // 2b. Expired pending challenges.
    //     • live challenges (no `type` or type=='live'): expire after 90s —
    //       the challenger was online and will have reacted by now.
    //     • async challenges (type=='async'): the target was offline; keep
    //       pending up to 48h so it can be delivered when they return.
    //     Also sweep ACCEPTED challenges after 2h (room was created but the
    //     challenger never joined; room itself is abandoned after 30 min).
    try {
      const ASYNC_TTL = 48 * 60 * 60 * 1000; // 48h
      const LIVE_TTL = 90 * 1000; // 90s
      const ACCEPTED_TTL = 2 * 60 * 60 * 1000; // 2h

      let n = 0;
      const batch = db.batch();

      // Pending challenges — TTL depends on type (missing field = live).
      const pendingSnap = await db
        .collection(CHALLENGES)
        .where('status', '==', 'pending')
        .limit(500)
        .get();
      pendingSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 0;
        const ttl = d.type === 'async' ? ASYNC_TTL : LIVE_TTL;
        if (age > ttl) {
          batch.delete(doc.ref);
          n++;
        }
      });

      // Accepted-but-never-joined challenges (room was created, challenger
      // never showed up; the room itself is abandoned after 30 min).
      const accSnap = await db
        .collection(CHALLENGES)
        .where('status', '==', 'accepted')
        .limit(500)
        .get();
      accSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 0;
        if (age > ACCEPTED_TTL) {
          batch.delete(doc.ref);
          n++;
        }
      });

      if (n > 0) await batch.commit();
      if (n > 0) functions.logger.log(`cleanup: removed ${n} expired challenges`);
    } catch (e) {
      functions.logger.error('challenge cleanup failed', e);
    }

    // 2b2. Friend requests hygiene:
    //      • accepted requests: both friendship docs are already written by
    //        the Cloud Function → sweep the request after 24h.
    //      • pending requests older than 7 days: stale/spam → delete.
    try {
      const ACC_TTL = 24 * 60 * 60 * 1000; // 24h
      const PENDING_TTL = 7 * 24 * 60 * 60 * 1000; // 7d
      const frSnap = await db.collection(FRIEND_REQUESTS).limit(500).get();
      const batch = db.batch();
      let n = 0;

      // Dedup: for pending requests between the same pair (legacy auto-id
      // spam), keep only the oldest and delete the stacked copies.
      const pendingByPair = new Map(); // "from->to" -> { oldestTime, dupRefs }
      frSnap.forEach((doc) => {
        const d = doc.data();
        const created = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        const age = created ? now - created.getTime() : 0;
        if (d.status === 'accepted' && age > ACC_TTL) {
          batch.delete(doc.ref);
          n++;
        } else if (d.status === 'pending' && age > PENDING_TTL) {
          batch.delete(doc.ref);
          n++;
        } else if (d.status === 'pending') {
          const key = `${d.fromUserId}->${d.toUserId}`;
          const t = created ? created.getTime() : Number.MAX_SAFE_INTEGER;
          const entry = pendingByPair.get(key);
          if (!entry) {
            pendingByPair.set(key, { oldestTime: t, oldestRef: doc.ref, dupRefs: [] });
          } else if (t < entry.oldestTime) {
            // This doc is older — the previous "oldest" becomes a duplicate.
            entry.dupRefs.push(entry.oldestRef);
            entry.oldestTime = t;
            entry.oldestRef = doc.ref;
          } else {
            entry.dupRefs.push(doc.ref);
          }
        }
      });
      pendingByPair.forEach((entry) => {
        entry.dupRefs.forEach((ref) => {
          batch.delete(ref);
          n++;
        });
      });
      if (n > 0) await batch.commit();
      if (n > 0) functions.logger.log(`cleanup: removed ${n} stale friend requests`);
    } catch (e) {
      functions.logger.error('friend request cleanup failed', e);
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

    // 2d. Seed-room answer keys older than 24h (rooms never live past 30min
    //     active / 48h cleanup, so 24h is a generous safety margin).
    try {
      const keysSnap = await db.collection(ANSWER_KEYS).limit(500).get();
      const batch = db.batch();
      let n = 0;
      keysSnap.forEach((doc) => {
        const d = doc.data();
        const ts = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : null;
        if (!ts || now - ts.getTime() > 24 * 60 * 60 * 1000) {
          batch.delete(doc.ref);
          n++;
        }
      });
      if (n > 0) {
        await batch.commit();
        functions.logger.log(`cleanup: removed ${n} expired answer keys`);
      }
    } catch (e) {
      functions.logger.error('answer key cleanup failed', e);
    }

    return null;
  });

// ---------------------------------------------------------------------------
// 3) Auto-forfeit: a player whose presence went silent mid-battle loses.
//    Checks players flagged isInBattle whose heartbeat (every 20s client-side)
//    went silent for > 90s. Runs every minute for fast resolution.
// ---------------------------------------------------------------------------

// Heartbeats now arrive every 20s (client), so 90s of silence means ~4-5
// missed beats — the player is genuinely gone. Running every minute (was 5)
// means a disconnected opponent is resolved within ~1-2 minutes instead of
// leaving the other player staring at a frozen arena.
exports.autoForfeitDisconnectedPlayers = functions.pubsub
  .schedule('every 1 minutes')
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
        if (age > 90 * 1000) deadIds.push(doc.id);
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
