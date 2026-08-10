// How hard is a room for someone who does not know the answer?
//
//   node tools/coldread.mjs            all rooms
//   node tools/coldread.mjs --trials=2000
//
// The problem this exists for: once you have played a room fifty times you
// cannot feel its difficulty any more. Session logs show the designer's thinking
// time down to a second or two per room, which tells you nothing about a first
// encounter. So instead of measuring a player who knows, this measures players
// who do not — three of them, each a different kind of beginner.
//
//   FLAILER   random flips at random moments. The floor: how forgiving is the
//             room to someone who has understood nothing at all?
//   SETTLER   the honest beginner. Flip only once the orb has come to rest, so
//             nothing ever has to be timed. This is how everyone plays at first.
//   CREEPER   flip back and forth to walk the orb along a surface. The cheap
//             route, and the one that beats most rooms if you find it.
//
// A room the SETTLER can finish needs no execution. A room only the CREEPER can
// finish is one where a beginner is stuck until they stumble on the trick. A room
// where the FLAILER dies constantly is punishing on contact rather than on skill.
import { createWorld, stepWorld, rotate } from './reference/physics.js';
import { SUBSTEP } from './reference/constants.js';
import { loadLevels } from './lib/levels.mjs';
import { solveRestOnly } from './reference/search.js';
import { creepable } from './lib/creep.mjs';

const arg = (k, d) => {
  const a = process.argv.find((x) => x.startsWith(`--${k}=`));
  return a ? Number(a.split('=')[1]) : d;
};
const TRIALS = arg('trials', 1200);

// A cheap deterministic PRNG, so a run is reproducible and reviewable.
let seed = 12345;
const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

function settle(w, maxSteps = 900) {
  for (let i = 0; i < maxSteps && w.status === 'playing'; i++) {
    stepWorld(w, SUBSTEP, SUBSTEP);
    if (w.resting && i > 30) return true;
  }
  return false;
}

/** Random flips at random moments — understood nothing. */
function flail(level) {
  const w = createWorld(level);
  const flips = 1 + Math.floor(rnd() * 6);
  for (let i = 0; i < flips && w.status === 'playing'; i++) {
    const wait = 0.1 + rnd() * 0.9;
    for (let t = 0; t < wait && w.status === 'playing'; t += SUBSTEP) stepWorld(w, SUBSTEP, SUBSTEP);
    if (w.status !== 'playing') break;
    rotate(w, rnd() < 0.5 ? 1 : -1);
  }
  for (let i = 0; i < 1200 && w.status === 'playing'; i++) stepWorld(w, SUBSTEP, SUBSTEP);
  return w.status;
}

const pct = (n, d) => `${((n / d) * 100).toFixed(0)}%`;

console.log('Rooms as they meet someone who does not know the answer.\n');
console.log('  #  room          flailer: clear / dead      settler   creeper   verdict');

const LEVELS = loadLevels();
LEVELS.forEach((level, i) => {
  let clear = 0, dead = 0;
  for (let t = 0; t < TRIALS; t++) {
    const s = flail(level);
    if (s === 'clear') clear++; else if (s === 'dead') dead++;
  }
  const settler = solveRestOnly(level).ok;
  const creeper = !!creepable(level);

  const verdict = settler ? 'beginner can finish it'
    : creeper ? 'needs the creep, or timing'
    : 'timing only — no cheap way';

  console.log(`  ${String(i + 1).padStart(2)} ${level.name.padEnd(12)}`
    + ` ${pct(clear, TRIALS).padStart(7)} / ${pct(dead, TRIALS).padStart(4)}`
    + `        ${(settler ? 'yes' : 'no').padStart(3)}`
    + `      ${(creeper ? 'yes' : 'no').padStart(3)}`
    + `     ${verdict}`);
});

console.log(`\n  ${TRIALS} random attempts per room, seeded so the numbers are reproducible.`);
console.log('  flailer clear% is a floor, not a prediction — a real beginner aims.');
console.log('  What it compares is rooms against each other, which is the part you can no longer feel.');
