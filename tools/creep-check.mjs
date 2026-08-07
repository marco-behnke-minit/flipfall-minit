// Is a room defeated by creeping?
//
//   node tools/creep-check.mjs              check the prototypes
//   node tools/creep-check.mjs --shipped    check the shipped forty
//
// WHY THIS EXISTS
//
// Alternating gravity walks the orb along any surface without timing, so a
// player can park it at rest anywhere on a floor. From rest, one flip sends it
// in a straight line along an axis. So any room whose answer is "be at column C,
// then flip" is solved without timing, however tight the solver says its window
// is.
//
// The verifier could not see this. solve.mjs searches within twelve rotations
// and a creep spends far more, so it reported knife-edge windows for rooms that
// are actually walked. Three separate design conclusions were drawn from those
// numbers and all three were wrong. This checks the thing that actually matters.
//
// The check: park the orb at rest at every open cell that touches a surface,
// with all buttons already pressed, then try every one- and two-flip
// continuation. Buttons are pre-pressed because the creep reaches every one of
// them anyway — the question this answers is whether the FINAL approach needs
// timing, or is just another straight line.
import { createWorld, stepWorld, rotate } from './reference/physics.js';
import { SUBSTEP, CELL, GRID } from './reference/constants.js';
import { loadLevels, loadLevelsFrom } from './lib/levels.mjs';

const WAITS = [0.15, 0.3, 0.5, 0.8, 1.2, 1.8, 2.5];

function advance(w, seconds) {
  for (let t = 0; t < seconds && w.status === 'playing'; t += 1 / 240) stepWorld(w, 1 / 240, SUBSTEP);
}

/** A world with the orb parked at rest at (col, row), buttons already pressed. */
function parked(level, col, row) {
  const w = createWorld(level);
  for (const b of ['1', '2', '3']) {
    if (level.map.join('').includes(b)) {
      w.buttons.add(b);
      w.doorsOpen.add(String.fromCharCode(b.charCodeAt(0) - 48 + 96));
    }
  }
  w.orb.x = col * CELL + CELL / 2;
  w.orb.y = row * CELL + CELL / 2;
  w.orb.vx = 0;
  w.orb.vy = 0;
  return w;
}

/** Every cell the orb could be parked in: open, with something solid beneath. */
function restSpots(level) {
  const solid = (c, r) => {
    if (c < 0 || r < 0 || c >= GRID || r >= GRID) return true;
    const ch = level.map[r][c];
    return ch === '#' || ch === 'I' || ch === 'T';   // doors are open in this check
  };
  const spots = [];
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      const ch = level.map[r][c];
      if (ch === '#' || ch === 'I' || ch === 'T' || ch === '^') continue;
      if (solid(c, r + 1) || solid(c, r - 1) || solid(c - 1, r) || solid(c + 1, r)) spots.push([c, r]);
    }
  }
  return spots;
}

function creepable(level) {
  for (const [c, r] of restSpots(level)) {
    for (const d1 of [1, -1]) {
      // One flip, straight line.
      let w = parked(level, c, r);
      rotate(w, d1);
      advance(w, 4);
      if (w.status === 'clear') return { how: `park (${c},${r}) then one flip`, };
      // Two flips, with a wait between — a curve, but launched from rest.
      for (const wait of WAITS) {
        for (const d2 of [1, -1]) {
          w = parked(level, c, r);
          rotate(w, d1);
          advance(w, wait);
          if (w.status !== 'playing') continue;
          rotate(w, d2);
          advance(w, 4);
          if (w.status === 'clear') {
            return { how: `park (${c},${r}), flip, wait ${(wait * 1000).toFixed(0)}ms, flip` };
          }
        }
      }
    }
  }
  return null;
}

const shipped = process.argv.includes('--shipped');
const levels = shipped
  ? loadLevels()
  : loadLevelsFrom(new URL('../src/prototypes.gd', import.meta.url));

console.log(`Checking ${levels.length} ${shipped ? 'shipped' : 'prototype'} rooms.\n`);
let cheesable = 0;
for (const level of levels) {
  const hit = creepable(level);
  if (hit) cheesable++;
  console.log(`  ${(hit ? 'CREEPABLE' : 'resists  ').padEnd(10)} ${level.name.padEnd(18)} ${hit ? hit.how : ''}`);
}
console.log(`\n  ${cheesable} of ${levels.length} rooms can be walked to and solved from rest.`);
if (!shipped) {
  console.log('\n  A room that resists needs the flip to happen while the orb is already');
  console.log('  moving, on a path no straight line from a resting spot can reproduce.');
}
