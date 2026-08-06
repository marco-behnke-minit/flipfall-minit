// Whole-run simulation. Plays a segment with the reference physics and the
// reference scoring, so the score a player can actually reach is verified rather
// than estimated.
//
//   node tools/run-sim.mjs               flawless speedrun of the whole list
//   node tools/run-sim.mjs 8             add 8s of deliberation per room
//   node tools/run-sim.mjs 8 21 30       simulate one tier instead
//
// Defaults to every room, which is what the drop publishes by default; pass a
// range to model a segmented drop.
import { loadLevels, validateLevels, LEVEL_COUNT } from './lib/levels.mjs';
import { ATTEMPTS } from './reference/constants.js';
import {
  levelScore, finalScore, timeBonus, emptyStats, flavorText, recordClear,
} from './reference/score.js';
import { playerRoute, play } from './reference/search.js';

const LEVELS = loadLevels();
const problems = validateLevels(LEVELS);
if (problems.length) {
  console.error('src/levels.gd has authoring problems:');
  for (const p of problems) console.error('  ' + p);
  process.exit(1);
}

const THINK = Number(process.argv[2] || 0); // seconds of deliberation per room
const FROM = Math.max(1, Number(process.argv[3] || 1));
const TO = Math.min(LEVELS.length, Number(process.argv[4] || LEVEL_COUNT));
const SEGMENT = LEVELS.slice(FROM - 1, TO);

const stats = emptyStats();
let banked = 0;
const attempts = ATTEMPTS;
let cleared = 0;
let rotationsTotal = 0;
let wall = 0;

console.log(`Simulated run — rooms ${FROM}-${TO}, ${THINK}s deliberation per room\n`);
console.log('room             route       rot   time   bonus   points');
console.log('─'.repeat(58));

for (const level of SEGMENT) {
  const r = playerRoute(level);
  if (!r) {
    console.log(`${level.name.padEnd(16)} NO ROUTE FOUND`);
    process.exitCode = 1;
    continue;
  }
  const w = play(level, r.path);
  if (w.status !== 'clear') {
    console.log(`${level.name.padEnd(16)} route did NOT clear on replay (${w.status})`);
    process.exitCode = 1;
    continue;
  }

  // A real player deliberates between rotations, and the room clock is running
  // from their first rotation onward.
  const seconds = w.time + THINK;
  const pts = levelScore(w.rotations, seconds);
  banked += pts;
  cleared++;
  rotationsTotal += w.rotations;
  wall += seconds;
  recordClear(stats, level, w.rotations, seconds);

  console.log(
    `${level.name.padEnd(16)} ${r.kind.padEnd(10)} ${String(w.rotations).padStart(3)}  ` +
      `${seconds.toFixed(1).padStart(5)}s  ${String(timeBonus(seconds)).padStart(5)}   ${String(pts).padStart(6)}`
  );
}

const total = finalScore(banked, attempts);
console.log('─'.repeat(58));
console.log(`rooms cleared      ${cleared} / ${SEGMENT.length}`);
console.log(`rotations          ${rotationsTotal}  (−${rotationsTotal * 5} pts)`);
console.log(`banked             ${banked}`);
console.log(`attempts left      ${attempts}  (+${attempts * 500} pts)`);
console.log(`FINAL SCORE        ${total}`);
console.log(`active play        ${Math.floor(wall / 60)}m ${Math.round(wall % 60)}s`);
console.log(`flavor text        "${flavorText(stats, cleared, SEGMENT.length)}"`);

if (cleared !== SEGMENT.length) {
  console.log('\nNot every room cleared — check the routes above.');
  process.exitCode = 1;
}
