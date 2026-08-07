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
import { creepable } from './lib/creep.mjs';
import { loadLevels, loadLevelsFrom } from './lib/levels.mjs';

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
