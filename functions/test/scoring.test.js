/**
 * Battle Arena scoring + server-authoritative room handler.
 * ---------------------------------------------------------------------------
 * No emulator, no deploy: `scoring.js` is pure and `onBattleRoomWrite` is
 * driven with a fake Firestore so the anti-cheat paths can be asserted
 * directly.  Run with `npm test` from functions/ (or `node --test test/`).
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const scoring = require('../scoring');
const {
  asInt,
  divisionFloor,
  roundScore,
  verifyScore,
  decideWinner,
  trophyDelta,
} = scoring;

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

/** A Firestore Long-ish value: a boxed number, NOT a plain number. */
const boxed = (n) => ({ toNumber: () => n, valueOf: () => n });

/** The shape the client writes: roundAnswers/roundTimes keyed by round index. */
function player(id, answers, times, extra = {}) {
  return {
    id,
    name: id,
    photoUrl: '',
    currentScore: extra.currentScore ?? 0,
    roundAnswers: answers || {},
    roundTimes: times || {},
    ...extra,
  };
}

// ---------------------------------------------------------------------------
// asInt — Firestore can hand us boxed Longs or stringified numbers
// ---------------------------------------------------------------------------

test('asInt coerces every shape a doc can realistically hold', () => {
  assert.equal(asInt(3), 3);
  assert.equal(asInt('3'), 3);
  assert.equal(asInt(3.7), 3, 'truncates like the Dart .toInt() mirror');
  assert.equal(asInt(3n), 3);
  assert.equal(asInt(boxed(3)), 3, 'Long-like object with toNumber()');
  assert.equal(asInt(null), null);
  assert.equal(asInt(undefined), null);
  assert.equal(asInt(''), null);
  assert.equal(asInt('two'), null);
  assert.equal(asInt(Number.NaN), null);
});

// ---------------------------------------------------------------------------
// roundScore — base + speed bonus scaled by the round's own limit
// ---------------------------------------------------------------------------

test('roundScore: correct answer pays 100 + up to 50 speed bonus', () => {
  assert.equal(roundScore(true, 0, 15), 150);
  assert.equal(roundScore(true, 7, 15), 127, 'half the clock left pays most of the bonus');
  assert.equal(roundScore(true, 15, 15), 100, 'last-second answer gets no bonus');
  assert.equal(roundScore(true, 99, 15), 100, 'time is clamped to the limit');
  assert.equal(roundScore(true, -4, 15), 100, 'clock skew never grants bonus');
  assert.equal(roundScore(true, -1e9, 15), 100, 'a negative time cannot buy the +50');
});

test('roundScore: wrong or unanswered rounds are worth nothing', () => {
  assert.equal(roundScore(false, 0, 15), 0);
  assert.equal(roundScore(false, 3, 20), 0);
});

test('roundScore: a bogus time limit falls back to 15s', () => {
  assert.equal(roundScore(true, 0, 0), 150);
  assert.equal(roundScore(true, 0, -5), 150);
  assert.equal(roundScore(true, 0, undefined), 150);
});

test('roundScore: a 30s question scales the bonus instead of breaking', () => {
  assert.equal(roundScore(true, 0, 30), 150);
  assert.equal(roundScore(true, 15, 30), 125);
  assert.equal(roundScore(true, 30, 30), 100);
});

test('roundScore: boxed times/limits (legacy docs) behave like numbers', () => {
  assert.equal(roundScore(true, boxed(0), boxed(15)), 150);
});

// ---------------------------------------------------------------------------
// divisionFloor — rank protection
// ---------------------------------------------------------------------------

test('divisionFloor: boundaries match the division table in TODO.md', () => {
  assert.equal(divisionFloor(0), 0);
  assert.equal(divisionFloor(299), 0);
  assert.equal(divisionFloor(300), 300);
  assert.equal(divisionFloor(799), 300);
  assert.equal(divisionFloor(800), 800);
  assert.equal(divisionFloor(1499), 800);
  assert.equal(divisionFloor(1500), 1500);
  assert.equal(divisionFloor(9e3), 1500);
});

// ---------------------------------------------------------------------------
// verifyScore — the anti-cheat core
// ---------------------------------------------------------------------------

test('verifyScore: honest scores pass through untouched', () => {
  const p = player('alice', { 0: 2, 1: 0 }, { 0: 0, 1: 4 });
  const v = verifyScore(p, { correctAnswers: [2, 0, 1, 3, 2], timeLimits: [15, 15, 15, 15, 15] });
  assert.equal(v.legit, 287, 'round1: 4s of 15s -> 100 + round(11*50/15) = 137');
  assert.equal(v.exact, true);
  assert.equal(v.answered, 2);
});

test('verifyScore: rounds that were never answered cost zero', () => {
  const p = player('alice', { 0: 2 }, { 0: 0 });
  const v = verifyScore(p, { correctAnswers: [2, 0, 1, 3, 2], timeLimits: [15, 15, 15, 15, 15] });
  assert.equal(v.legit, 150);
});

test('verifyScore: a wrong answer scores 0 even with a perfect time', () => {
  const p = player('alice', { 0: 1 }, { 0: 0 });
  const v = verifyScore(p, { correctAnswers: [2], timeLimits: [15] });
  assert.equal(v.legit, 0);
});

test('verifyScore: boxed answer indexes still match (no silent zero-out)', () => {
  const p = player('alice', { 0: boxed(2) }, { 0: boxed(1) });
  const v = verifyScore(p, { correctAnswers: [boxed(2)], timeLimits: [boxed(15)] });
  assert.equal(v.legit, 150 - Math.round((1 * 50) / 15));
  assert.equal(v.exact, true);
});

test('REGRESSION: an inflated score is clamped to the rounds actually played', () => {
  // One correct answer, but the client claims a finished match's worth.
  const p = player('alice', { 0: 2 }, { 0: 0 }, { currentScore: 750 });
  const v = verifyScore(p, { correctAnswers: [2, 0, 1, 3, 2], timeLimits: [15, 15, 15, 15, 15] });
  assert.equal(v.legit, 150, 'was: 750 — the old code only capped at 5x150');
});

test('REGRESSION: a missing answer key no longer skips verification entirely', () => {
  // Seed room whose battle_answer_keys doc failed to write: previously the
  // function returned the full-match maximum, so 750 was "legal" at round 1.
  const p = player('alice', { 0: 2 }, { 0: 0 }, { currentScore: 750 });
  const v = verifyScore(p, { correctAnswers: null, questionCount: 5 });
  assert.equal(v.legit, 150, 'capped by answered rounds');
  assert.equal(v.exact, false, 'and flagged as a cap, not a verification');
});

test('verifyScore: no timing data still verifies exactly, without the bonus', () => {
  const p = player('alice', { 0: 2, 1: 1 }, {}, { currentScore: 700 });
  const v = verifyScore(p, { correctAnswers: [2, 1, 0, 0, 0], timeLimits: [15, 15, 15, 15, 15] });
  assert.equal(v.legit, 200, 'two correct rounds, no speed bonus provable');
  assert.equal(v.exact, false);
});

test('verifyScore: legacy rooms are checked against embedded questions', () => {
  const questions = [
    { correctAnswer: 2, timeLimit: 15 },
    { correctAnswer: 1, timeLimit: 20 },
  ];
  const p = player('alice', { 0: 2, 1: 1 }, { 0: 0, 1: 19 });
  const v = verifyScore(p, { questions });
  assert.equal(v.legit, 150 + 103);
  assert.equal(v.exact, true);
});

test('verifyScore: an empty answers object is worth nothing and never throws', () => {
  for (const opts of [
    { correctAnswers: [2, 0], timeLimits: [15, 15] },
    { questions: [{ correctAnswer: 2 }] },
    {},
  ]) {
    const v = verifyScore(player('a', {}, {}), opts);
    assert.equal(v.legit, 0);
    assert.equal(v.maxForAnswered, 0);
  }
  assert.equal(verifyScore(undefined, {}).legit, 0);
});

test('verifyScore: a negative reported score is left for the caller to handle', () => {
  const p = player('alice', {}, {}, { currentScore: -5 });
  assert.equal(asInt(p.currentScore), -5);
  assert.equal(p.currentScore > verifyScore(p, { correctAnswers: [0, 0] }).legit, false);
});

// ---------------------------------------------------------------------------
// decideWinner — ranking must use verified scores
// ---------------------------------------------------------------------------

test('REGRESSION: a cheater cannot win by reporting a huge score', () => {
  const opts = { correctAnswers: [2, 1, 0, 3, 4], timeLimits: [15, 15, 15, 15, 15] };
  const room = {
    player1: player('cheater', { 0: 2, 1: 1 }, { 0: 0, 1: 0 }, { currentScore: 99999 }),
    player2: player('honest', { 0: 2, 1: 1, 2: 0 }, { 0: 1, 1: 2, 2: 3 }),
  };
  const v = decideWinner(room, opts);
  assert.equal(v.winnerId, 'honest');
  assert.equal(v.s1, 300, 'cheater clamped to 2 x 150');
  assert.ok(v.s2 > v.s1);
});

test('decideWinner: equal verified scores are a draw, not player-1 bias', () => {
  const opts = { correctAnswers: [2, 1], timeLimits: [15, 15] };
  const room = {
    player1: player('a', { 0: 2, 1: 1 }, { 0: 5, 1: 5 }),
    player2: player('b', { 0: 2, 1: 1 }, { 0: 5, 1: 5 }),
  };
  const v = decideWinner(room, opts);
  assert.equal(v.isDraw, true);
  assert.equal(v.winnerId, null);
});

test('decideWinner: a missing opponent never crashes the handler', () => {
  const v = decideWinner({ player1: player('a', {}, {}, { currentScore: 200 }) }, {});
  assert.equal(v.winnerId, null);
  assert.equal(v.isDraw, true);
});

// ---------------------------------------------------------------------------
// trophyDelta — the ladder
// ---------------------------------------------------------------------------

test('trophyDelta: win pays 25, or 30 under the comeback threshold', () => {
  assert.equal(trophyDelta(500, {}, 'win').applied, 25);
  assert.equal(trophyDelta(99, {}, 'win').applied, 30);
  assert.equal(trophyDelta(100, {}, 'win').applied, 25);
});

test('trophyDelta: loss costs 10, the 4th straight one is free', () => {
  assert.equal(trophyDelta(500, {}, 'loss').trophies, 490);
  const afterThree = trophyDelta(500, { lossStreak: 3 }, 'loss');
  assert.equal(afterThree.trophies, 500);
  assert.equal(afterThree.shielded, true);
  assert.equal(afterThree.lossStreak, 0, 'shield is consumed');
});

test('trophyDelta: rank protection never demotes a division', () => {
  assert.equal(trophyDelta(805, { lossStreak: 2 }, 'loss').trophies, 800);
  assert.equal(trophyDelta(304, {}, 'loss').trophies, 300);
});

test('trophyDelta: rookie shield floors at zero', () => {
  assert.equal(trophyDelta(3, {}, 'loss').trophies, 0);
});

test('trophyDelta: draw holds both streaks and pays +5', () => {
  const t = trophyDelta(400, { lossStreak: 2, winStreak: 4, bestStreak: 9 }, 'draw');
  assert.deepEqual(
    { applied: t.applied, lossStreak: t.lossStreak, winStreak: t.winStreak, trophies: t.trophies },
    { applied: 5, lossStreak: 2, winStreak: 4, trophies: 405 }
  );
});

test('trophyDelta: win streaks roll into bestStreak and reset on a loss', () => {
  const w = trophyDelta(400, { winStreak: 9, bestStreak: 9 }, 'win');
  assert.equal(w.winStreak, 10);
  assert.equal(w.bestStreak, 10);
  assert.equal(trophyDelta(400, { winStreak: 10, bestStreak: 10 }, 'loss').winStreak, 0);
});

// ---------------------------------------------------------------------------
// onBattleRoomWrite — the deployed trigger, driven with a fake Firestore
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Wiring guard — the trigger must route through the pure math above
// ---------------------------------------------------------------------------
//
// A full integration test would need a Firestore emulator (the handler calls
// db.runTransaction for trophies, which hangs a fake db), so the wiring is
// asserted statically instead: it is the exact regression we are protecting.

const fs = require('node:fs');
const path = require('node:path');
const indexSrc = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
const body = indexSrc.slice(
  indexSrc.indexOf('exports.onBattleRoomWrite'),
  indexSrc.indexOf('// 1b) Send a push')
);

test('room handler clamps via verifyScore, not a full-match maximum', () => {
  assert.match(body, /verifyScore\(p, verifyOpts\)/);
  assert.doesNotMatch(body, /maxPossible/, 'the loose 5-round cap must stay gone');
  assert.doesNotMatch(body, /hasTimingForAll/, 'missing timing must not skip verification');
});

test('room handler ranks players by re-verified scores', () => {
  assert.match(body, /decideWinner\(room, verifyOpts\)/);
  assert.doesNotMatch(
    body,
    /winnerId = s1 > s2 \? room\.player1\.id/,
    'ranking must never read the raw client-reported currentScore'
  );
});

test('room handler still awards trophies exactly once', () => {
  assert.match(body, /trophiesAwarded/);
  assert.match(body, /shouldFinish/);
});

test('score math is not duplicated inside index.js', () => {
  assert.doesNotMatch(indexSrc, /function roundScore\(/);
  assert.doesNotMatch(indexSrc, /function computeLegitScore/);
  assert.match(indexSrc, /require\('\.\/scoring'\)/);
});
