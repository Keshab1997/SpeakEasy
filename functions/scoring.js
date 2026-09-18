/**
 * Battle Arena — pure game math (score verification + trophy economy).
 * ---------------------------------------------------------------------------
 * Deliberately free of `firebase-admin` / `firebase-functions` so it can be
 * unit-tested directly (`node --test`) without an emulator or a deploy.
 *
 * This file is the single source of truth for what a legitimate score is.
 * The client mirrors it in `BattleGameService.calculateRoundScore`, but the
 * client is only a courtesy copy — the numbers that end up on the leaderboard
 * are the ones computed here, server-side.
 */

'use strict';

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
 * Firestore hands plain JS numbers back to us, but a client that wrote the
 * field with a non-standard serializer (or a legacy doc patched by hand) can
 * deliver a Long-like `{ _long: '2' }` / a string `'2'`. `===` on those
 * silently fails and would zero out an honest player's score, so every
 * index/answer comparison goes through this.
 */
function asInt(v) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? Math.trunc(v) : null;
  if (typeof v === 'string') return /^-?\d+$/.test(v.trim()) ? parseInt(v, 10) : null;
  if (typeof v === 'bigint') return Number(v);
  if (typeof v === 'object') {
    if (typeof v.toNumber === 'function') {
      try {
        const n = v.toNumber();
        return Number.isFinite(n) ? Math.trunc(n) : null;
      } catch (_) {
        /* fall through */
      }
    }
    if (typeof v.valueOf === 'function') {
      const raw = v.valueOf();
      if (raw !== v && typeof raw === 'number') {
        return Number.isFinite(raw) ? Math.trunc(raw) : null;
      }
    }
  }
  return null;
}

/** Trophies can never drop a player below the floor of their own division. */
function divisionFloor(trophies) {
  if (trophies >= 1500) return 1500; // Grandmaster
  if (trophies >= 800) return 800;   // Master
  if (trophies >= 300) return 300;   // Challenger
  return 0;                          // Novice
}

/** +100 base, plus a speed bonus up to +50 scaled by the round's time limit. */
function roundScore(isCorrect, timeTaken, timeLimit) {
  if (!isCorrect) return 0;
  const limit = asInt(timeLimit) > 0 ? asInt(timeLimit) : DEFAULT_TIME_LIMIT;
  const raw = asInt(timeTaken);
  // Missing or out-of-range time is charged at the WORST end of the round.
  // Clamping a negative value up to 0 would hand out the full speed bonus for
  // free, which is exactly what a tampered clock is for.
  let clamped;
  if (raw === null || raw > limit || raw < 0) {
    clamped = limit;
  } else {
    clamped = raw;
  }
  const speedBonus = Math.round(((limit - clamped) * MAX_SPEED_BONUS) / limit);
  return BASE_SCORE + speedBonus;
}

/**
 * Verify one player's reported score.
 *
 * @param {object} player         room.player1 / room.player2
 * @param {object} opts
 * @param {Array}  [opts.correctAnswers] admin-only answer key (seed rooms)
 * @param {Array}  [opts.timeLimits]     per-round time limits from the same key
 * @param {Array}  [opts.questions]      legacy rooms embed their questions
 * @param {number} [opts.questionCount]  rounds in this match
 * @returns {{legit:number, exact:boolean, answered:number, maxForAnswered:number}}
 *   `legit`  — the highest score this player may hold
 *   `exact`  — true when it was derived from real answers (not a cap)
 *   `answered` — rounds that carry an answer
 */
function verifyScore(player, opts = {}) {
  const answers = (player && player.roundAnswers) || {};
  const times = (player && player.roundTimes) || {};
  const keys = Object.keys(answers);
  const answered = keys.length;

  const totalRounds =
    asInt(opts.questionCount) ||
    (Array.isArray(opts.questions) ? opts.questions.length : 0) ||
    (Array.isArray(opts.correctAnswers) ? opts.correctAnswers.length : ROUNDS_PER_MATCH);

  // A round that has not been answered yet is worth 0, so the ceiling scales
  // with what the player has actually played — reporting 500 after one correct
  // answer is as illegal as reporting 5000 after five.
  const maxForAnswered = Math.min(answered, totalRounds) * (BASE_SCORE + MAX_SPEED_BONUS);

  const compute = (isRight, timeTaken, limit) => roundScore(isRight, timeTaken, limit);

  let legit = null;
  let exact = false;

  const key = Array.isArray(opts.correctAnswers) ? opts.correctAnswers : null;
  if (key && key.length) {
    const limits = Array.isArray(opts.timeLimits) ? opts.timeLimits : [];
    let total = 0;
    let exactThisRound = true;
    for (let i = 0; i < Math.min(key.length, totalRounds); i++) {
      const k = String(i);
      if (!(k in answers)) continue; // unanswered round = 0 pts
      const given = asInt(answers[k]);
      const right = given !== null && given === asInt(key[i]);
      const limit = asInt(limits[i]) || DEFAULT_TIME_LIMIT;
      const t = asInt(times[k]);
      // No timestamp recorded (legacy client / partial write): we cannot prove
      // the speed bonus, so score it as an instant-before-whistle answer
      // instead of throwing verification away and falling back to a loose cap.
      if (t === null) exactThisRound = false;
      total += compute(right, t === null ? limit : t, limit);
    }
    legit = total;
    exact = exactThisRound;
  } else if (Array.isArray(opts.questions) && opts.questions.length) {
    // Legacy rooms keep the questions (and their answers) in the room doc.
    let total = 0;
    let exactThisRound = true;
    for (let i = 0; i < opts.questions.length; i++) {
      const q = opts.questions[i] || {};
      const k = String(i);
      if (!(k in answers)) continue;
      const given = asInt(answers[k]);
      const right = given !== null && given === asInt(q.correctAnswer);
      const limit = asInt(q.timeLimit) || DEFAULT_TIME_LIMIT;
      const t = asInt(times[k]);
      if (t === null) exactThisRound = false;
      total += compute(right, t === null ? limit : t, limit);
    }
    legit = total;
    exact = exactThisRound;
  }

  return {
    legit: legit === null ? maxForAnswered : Math.min(legit, maxForAnswered),
    exact,
    answered,
    maxForAnswered,
  };
}

/**
 * Decide the winner from a room. `currentScore` may still hold the inflated
 * value the client wrote, so both scores are re-verified first — otherwise a
 * cheater keeps the match (and its trophy) just because the clamp write
 * landed a moment too late.
 */
function decideWinner(room, verifyOpts = {}) {
  const p1 = room.player1;
  const p2 = room.player2;
  if (!p1 || !p2 || !p1.id || !p2.id) return { winnerId: null, isDraw: true, s1: 0, s2: 0 };

  const s1 = verifyScore(p1, verifyOpts).legit;
  const s2 = verifyScore(p2, verifyOpts).legit;
  if (s1 === s2) return { winnerId: null, isDraw: true, s1, s2 };
  return { winnerId: s1 > s2 ? p1.id : p2.id, isDraw: false, s1, s2 };
}

/**
 * One trophy step of the ladder. Pure so the economy (rank protection,
 * comeback bonus, loss shield, streak rules) can be asserted round-trip.
 *
 * @param {number} currentTrophies
 * @param {object} prev {lossStreak, winStreak, bestStreak}
 * @param {'win'|'loss'|'draw'} result
 */
function trophyDelta(currentTrophies, prev, result) {
  const have = asInt(currentTrophies) || 0;
  const lossStreak = asInt(prev && prev.lossStreak) || 0;
  const winStreak = asInt(prev && prev.winStreak) || 0;
  const bestStreak = asInt(prev && prev.bestStreak) || 0;

  let applied = 0;
  let shielded = false;
  let comeback = false;
  let nextLossStreak = lossStreak;
  let nextWinStreak = winStreak;

  if (result === 'win') {
    nextLossStreak = 0;
    nextWinStreak = winStreak + 1;
    comeback = have < COMEBACK_THRESHOLD;
    applied = TROPHY_WIN + (comeback ? COMEBACK_BONUS : 0);
  } else if (result === 'draw') {
    applied = TROPHY_DRAW; // both streaks held
  } else if (lossStreak >= LOSS_SHIELD_AFTER) {
    shielded = true; // 4th straight loss is free; shield consumed
    nextLossStreak = 0;
    nextWinStreak = 0;
  } else {
    applied = TROPHY_LOSS;
    nextLossStreak = lossStreak + 1;
    nextWinStreak = 0;
  }

  const floor = divisionFloor(have);
  const trophies = Math.max(0, Math.max(floor, have + applied));

  return {
    applied,
    trophies,
    shielded,
    comeback,
    lossStreak: nextLossStreak,
    winStreak: nextWinStreak,
    bestStreak: Math.max(bestStreak, nextWinStreak),
  };
}

module.exports = {
  ROUNDS_PER_MATCH,
  BASE_SCORE,
  MAX_SPEED_BONUS,
  DEFAULT_TIME_LIMIT,
  TROPHY_WIN,
  TROPHY_LOSS,
  TROPHY_DRAW,
  COMEBACK_BONUS,
  COMEBACK_THRESHOLD,
  LOSS_SHIELD_AFTER,
  asInt,
  divisionFloor,
  roundScore,
  verifyScore,
  decideWinner,
  trophyDelta,
};
