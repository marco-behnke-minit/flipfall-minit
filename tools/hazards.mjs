// Which hazards actually do anything?
//
//   node tools/hazards.mjs           per-room summary
//   node tools/hazards.mjs --worst   just the rooms that are mostly decoration
//   node tools/hazards.mjs --cut     DELETE each hazard type and re-solve
//
// Playtest, on rooms 29-34: "the spikes are pointless, they are in walls you
// never touch because you bypass them". On 22, 25, 27, 28: "ice on a wall that
// you don't need is pointless".
//
// Proximity turned out to be the wrong measure: rooms like Vault come within a
// cell of all 27 of their spikes and touch none, because the route flies down a
// corridor the spikes merely line. Passing something safely is not being
// constrained by it.
//
// So --cut runs the test that settles it: delete every spike (or every patch of
// ice) and re-solve. If the room still solves in the same number of rotations,
// that hazard was never doing anything. It cannot threaten, constrain or teach —
// it only makes the room look harder than it is, which is how 44 of 45 rooms
// came to be cleared on the first attempt.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createWorld, stepWorld, rotate } from './reference/physics.js';
import { SUBSTEP, CELL, ORB_R, GRID } from './reference/constants.js';
import { loadLevels } from './lib/levels.mjs';

const LEVELS = loadLevels();
const cache = JSON.parse(readFileSync(new URL('../.levelcache.json', import.meta.url), 'utf8'));
const solved = (l) => cache.rooms[createHash('sha256').update(l.map.join('|')).digest('hex').slice(0, 16)];

// Touched: the orb was in contact. Near: it passed within a cell, so the hazard
// shaped the route even if it never bit. Beyond that it is scenery.
const TOUCHED = ORB_R + 6;
const NEAR = CELL;

/** Every position the orb visits while the route is played out. */
function pathOf(level, path) {
  const w = createWorld(level);
  const points = [];
  const sample = () => points.push([w.orb.x, w.orb.y]);
  for (const step of path) {
    if (step.wait === 'rest') {
      for (let i = 0; i < 1200 && w.status === 'playing'; i++) {
        stepWorld(w, SUBSTEP, SUBSTEP); sample();
        if (w.resting && i > 30) break;
      }
    } else {
      const until = w.time + step.wait;
      while (w.time < until && w.status === 'playing') { stepWorld(w, SUBSTEP, SUBSTEP); sample(); }
    }
    if (w.status !== 'playing') break;
    rotate(w, step.dir);
  }
  for (let i = 0; i < 1200 && w.status === 'playing'; i++) { stepWorld(w, SUBSTEP, SUBSTEP); sample(); }
  return points;
}

/** Closest the orb ever came to a cell, measured to the cell's edge. */
function closest(points, c, r) {
  const x0 = c * CELL, y0 = r * CELL, x1 = x0 + CELL, y1 = y0 + CELL;
  let best = Infinity;
  for (const [px, py] of points) {
    const dx = Math.max(x0 - px, 0, px - x1);
    const dy = Math.max(y0 - py, 0, py - y1);
    best = Math.min(best, Math.hypot(dx, dy));
  }
  return best;
}

const rows = [];
for (const level of LEVELS) {
  const s = solved(level);
  const path = s?.rest?.ok ? s.rest.path : (s?.fast?.ok ? s.fast.best.path : null);
  if (!path) continue;
  const points = pathOf(level, path);

  const tally = { '^': [0, 0, 0], I: [0, 0, 0], T: [0, 0, 0] };  // touched, near, scenery
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      const ch = level.map[r][c];
      if (!tally[ch]) continue;
      const d = closest(points, c, r);
      tally[ch][d <= TOUCHED ? 0 : d <= NEAR ? 1 : 2]++;
    }
  }
  const total = Object.values(tally).reduce((n, t) => n + t[0] + t[1] + t[2], 0);
  const scenery = Object.values(tally).reduce((n, t) => n + t[2], 0);
  rows.push({ name: level.name, tally, total, scenery, ratio: total ? scenery / total : 0 });
}

if (process.argv.includes('--cut')) {
  const { solveRestOnly } = await import('./reference/search.js');
  const strip = (level, from, to) => ({
    ...level,
    map: level.map.map((row) => row.split('').map((ch) => (from.includes(ch) ? to : ch)).join('')),
  });
  console.log('Delete a hazard and re-solve. Same rotations = it was never doing anything.\n');
  console.log('  #  room               par   without spikes   without ice');
  let deadSpikes = 0, deadIce = 0, hasSpikes = 0, hasIce = 0;
  LEVELS.forEach((level, i) => {
    const base = solveRestOnly(level);
    const par = base.ok ? base.rotations : null;
    const flat = level.map.join('');
    let spikeCol = '-', iceCol = '-';
    if (flat.includes('^')) {
      hasSpikes++;
      const r = solveRestOnly(strip(level, '^', '.'));
      const same = r.ok && r.rotations === par;
      if (same) deadSpikes++;
      spikeCol = r.ok ? `${r.rotations} rot ${same ? 'SAME' : 'changed'}` : 'unsolvable';
    }
    if (flat.includes('I')) {
      hasIce++;
      const r = solveRestOnly(strip(level, 'I', '#'));   // stone in its place
      const same = r.ok && r.rotations === par;
      if (same) deadIce++;
      iceCol = r.ok ? `${r.rotations} rot ${same ? 'SAME' : 'changed'}` : 'unsolvable';
    }
    if (spikeCol === '-' && iceCol === '-') return;
    console.log(`  ${String(i + 1).padStart(2)} ${level.name.padEnd(18)} ${String(par ?? '-').padStart(3)}`
      + `   ${spikeCol.padEnd(16)} ${iceCol}`);
  });
  console.log(`\n  spikes: ${deadSpikes} of ${hasSpikes} rooms solve identically without them.`);
  console.log(`  ice:    ${deadIce} of ${hasIce} rooms solve identically with stone in its place.`);
  process.exit(0);
}

const worst = process.argv.includes('--worst');
const shown = worst ? rows.filter((r) => r.total >= 4 && r.ratio >= 0.8) : rows;

console.log('How close the solved route comes to each hazard.\n');
console.log('  #  room               spikes         ice            sticky        scenery');
rows.forEach((r, i) => {
  if (!shown.includes(r)) return;
  const fmt = (t) => (t[0] + t[1] + t[2] === 0 ? '-'.padEnd(14)
    : `${t[0]}t ${t[1]}n ${t[2]}x`.padEnd(14));
  const flag = r.total >= 4 && r.ratio >= 0.8 ? '  <-- all scenery' : '';
  console.log(`  ${String(i + 1).padStart(2)} ${r.name.padEnd(18)} ${fmt(r.tally['^'])} ${fmt(r.tally.I)} `
    + `${fmt(r.tally.T)} ${(r.total ? (r.ratio * 100).toFixed(0) + '%' : '-').padStart(7)}${flag}`);
});

console.log('\n  t = touched, n = passed within a cell, x = never approached\n');
const dead = rows.filter((r) => r.total >= 4 && r.ratio >= 0.8);
const cells = rows.reduce((n, r) => n + r.total, 0);
const deadCells = rows.reduce((n, r) => n + r.scenery, 0);
console.log(`  ${deadCells} of ${cells} hazard cells (${(deadCells / cells * 100).toFixed(0)}%) are never approached.`);
console.log(`  ${dead.length} rooms are at least 80% scenery.`);
