// Order the rooms as a learning curve rather than a difficulty ranking.
//
//   node tools/curve.mjs           the proposed order, and what is missing
//   node tools/curve.mjs --names   just the names, for pasting into levels.gd
//
// WHY NOT A DIFFICULTY SORT
//
// The rooms were sorted ascending by a difficulty score, which produced a
// monotonic ramp — and a monotonic ramp is the wrong shape. Difficulty is not a
// property of a room, it is a property of a room GIVEN WHAT THE PLAYER ALREADY
// KNOWS. Playtesting made that concrete: a room the solver called frame-perfect
// was cleared first try because the room before it had taught the move, and ice
// rooms went from hard to easy once the player worked out how ice behaves.
//
// So the shape to build is a sawtooth. A mechanic is introduced, the rooms using
// it get harder, the player masters it and they start to feel easy — and then a
// NEW mechanic resets the difficulty and the cycle repeats. The rise is authored;
// the fall happens by itself, in the player.
//
// This orders rooms into blocks, one per mechanic in the order they are first
// needed, and ramps up within each block. The felt curve is the sawtooth; the
// authored curve is only ever the rise.
//
// The window numbers the earlier model leaned on are deliberately NOT used here.
// Alternating gravity walks the orb along any surface without timing (see
// src/prototypes.gd), so a measured window describes a route players do not take.
// What is left that is trustworthy: route length, and how lethal a room is.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { loadLevels, GRID } from './lib/levels.mjs';

const LEVELS = loadLevels();
const cache = JSON.parse(readFileSync(new URL('../.levelcache.json', import.meta.url), 'utf8'));
const solved = (l) => cache.rooms[createHash('sha256').update(l.map.join('|')).digest('hex').slice(0, 16)];

// The order a player meets things. A room belongs to the LAST of these it uses,
// because that is the newest thing it asks of them.
//
// The thresholds matter: one stray gap in a wall does not make a room about
// falling out of the level, so a mechanic has to be present in some quantity
// before it owns a room.
//
// There is deliberately no `midair` entry keyed on "the solver found no
// rest-only route". That test looked like a test for airborne commitment and is
// not one — alternating gravity walks the orb along a surface without any timing
// (see src/prototypes.gd), so those rooms are solved on the ground. Genuine
// mid-air rooms have to be authored and tagged, and none of the shipped forty
// qualify; the two validated Overhead prototypes are the seed.
const MECHANICS = [
  ['rotate', () => true],
  ['doors', (m) => /[abc]/.test(m.flat)],
  ['spikes', (m) => m.spikes >= 5],
  ['ice', (m) => (m.flat.match(/I/g) ?? []).length >= 5],
  ['sticky', (m) => /T/.test(m.flat)],
  ['edges', (m) => m.openEdges >= 3],
  // Spikes hanging from a ceiling rather than lying on a floor. No shipped room
  // used them; the two that do are the ones that playtested best, because the
  // reflex flip-up at a wall is fatal and the climb has to be committed. Last in
  // the order because it is the newest thing the game asks for.
  ['ceiling', (m) => m.ceilingSpikes > 0],
];

/** Spikes with something solid directly above them — a hazard you rise into. */
function countCeilingSpikes(level) {
  const solid = (c, r) => {
    if (c < 0 || r < 0 || c >= GRID || r >= GRID) return false;
    const ch = level.map[r][c];
    return ch === '#' || ch === 'I' || ch === 'T' || /[abc]/.test(ch);
  };
  let n = 0;
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      if (level.map[r][c] === '^' && solid(c, r - 1) && !solid(c, r + 1)) n++;
    }
  }
  return n;
}

function measure(level) {
  const flat = level.map.join('');
  let openEdges = 0;
  for (let i = 0; i < GRID; i++) {
    if (level.map[0][i] !== '#') openEdges++;
    if (level.map[GRID - 1][i] !== '#') openEdges++;
    if (level.map[i][0] !== '#') openEdges++;
    if (level.map[i][GRID - 1] !== '#') openEdges++;
  }
  const s = solved(level);
  if (!s) throw new Error(`no cached solution for "${level.name}" — run node tools/solve.mjs`);
  const restOnly = s.rest.ok;
  const m = {
    name: level.name,
    par: level.par,
    flat,
    openEdges,
    spikes: (flat.match(/\^/g) ?? []).length,
    ceilingSpikes: countCeilingSpikes(level),
    restOnly,
    rotations: restOnly ? s.rest.rotations : (s.fast.ok ? s.fast.best.rotations : 0),
  };
  // Length, plus what a mistake costs. Both survive the creep; windows do not.
  m.effort = m.rotations + m.spikes / 5 + m.openEdges / 2;
  m.block = MECHANICS.filter(([, test]) => test(m)).at(-1)[0];
  return m;
}

const rooms = LEVELS.map(measure);
const order = [];
for (const [mech] of MECHANICS) {
  const block = rooms.filter((r) => r.block === mech).sort((a, b) => a.effort - b.effort);
  if (block.length) order.push([mech, block]);
}

if (process.argv.includes('--names')) {
  console.log(order.flatMap(([, b]) => b.map((r) => r.name)).join(' '));
  process.exit(0);
}

console.log('PROPOSED ORDER — blocks in the order each mechanic is first needed,\n'
  + 'ramping up inside each block. Difficulty falls between blocks by itself.\n');

let n = 0;
for (const [mech, block] of order) {
  console.log(`  ${mech.toUpperCase()}  (${block.length} rooms)`);
  for (const r of block) {
    n++;
    const notes = [];
    if (r.spikes) notes.push(`${r.spikes} spikes`);
    if (r.openEdges) notes.push(`${r.openEdges} open edges`);
    // Deliberately not labelled "needs a mid-air flip": that is the !restOnly
    // test, which the creep discredits. It only means the solver found no
    // rest-only route inside its twelve-rotation cap.
    if (!r.restOnly) notes.push('no short rest-only route');
    console.log(`   ${String(n).padStart(2)}. ${r.name.padEnd(13)} ${String(r.rotations).padStart(2)} rot`
      + `   effort ${r.effort.toFixed(1).padStart(5)}   ${notes.join(', ')}`);
  }
  console.log('');
}

console.log('WHERE THE CURVE RUNS OUT\n');
console.log('  midair   NO ROOMS. The hardest arc the curve is supposed to end on does');
console.log('           not exist: every shipped room is solved on a surface, and a');
console.log('           surface can be crept along without timing. Overhead and');
console.log('           Overhead (narrow) in src/prototypes.gd are the only two rooms');
console.log('           that demand a commitment in the air, and both playtested well.');
console.log('           The arc above that — two flips in a row to steer a curve');
console.log('           mid-flight — has no rooms at all yet.');
const counts = Object.fromEntries(order.map(([m, b]) => [m, b.length]));
for (const [mech] of MECHANICS) {
  const c = counts[mech] ?? 0;
  if (c === 0) console.log(`  ${mech.padEnd(8)} NO ROOMS — the curve has no ${mech} arc at all`);
  else if (c < 3) console.log(`  ${mech.padEnd(8)} only ${c} room(s) — too few to rise and be mastered`);
}
console.log('\n  A block wants roughly 4-6 rooms: one to introduce the mechanic plainly,');
console.log('  two or three that lean on it harder, and one that combines it with what');
console.log('  came before. Fewer than three and the player never gets to feel the fall.');
