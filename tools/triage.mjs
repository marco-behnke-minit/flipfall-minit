// Keep or cut: which of the 45 rooms are actually rooms.
//
//   node tools/triage.mjs
//
// Two failings showed up in playtesting, and both are measurable.
//
// DECORATION. Delete a room's hazards and re-solve. If the answer is the same
// number of rotations, those hazards never constrained anything — they only made
// the room look harder. 15 of 26 spiked rooms and 11 of 19 iced rooms fail this.
//
// REPETITION. Strip the hazards back to bare geometry and compare rooms to each
// other. The shipped set is largely one shelf-stack skeleton wearing different
// paint, which is why whole runs of rooms played as "mostly the same".
//
// A room earns its place by failing to be either. Everything else is a candidate
// for retirement, so the effort goes into new rooms instead of redecorating old
// ones.
import { solveRestOnly, solveTimed } from './reference/search.js';
import { GRID } from './reference/constants.js';
import { loadLevels } from './lib/levels.mjs';

const LEVELS = loadLevels();

/** The room with its paint removed: spikes become air, ice and sticky become stone. */
const skeleton = (level) =>
  level.map.map((row) => row.replace(/\^/g, '.').replace(/[IT]/g, '#'));

// Compared over structure only. Counting every cell equally rates two rooms 90%
// alike because both are mostly air inside the same border — so only cells that
// carry something in either room count, and the shared frame is excluded.
function sameness(a, b) {
  let shared = 0;
  let union = 0;
  for (let r = 1; r < GRID - 1; r++) {
    for (let c = 1; c < GRID - 1; c++) {
      const x = a[r][c];
      const y = b[r][c];
      if (x === '.' && y === '.') continue;
      union++;
      if (x === y) shared++;
    }
  }
  return union ? shared / union : 1;
}

const strip = (level, from, to) => ({
  ...level,
  map: level.map.map((row) => row.split('').map((ch) => (from.includes(ch) ? to : ch)).join('')),
});

const rooms = LEVELS.map((level, i) => {
  const flat = level.map.join('');
  const base = solveRestOnly(level);
  const par = base.ok ? base.rotations : null;

  // Does removing each hazard change the answer?
  //
  // This used to compare rest-only rotation counts alone, which quietly passed
  // every hazard in a room that has no rest-only route: par was null, the
  // stripped solve failed too, and `!r.ok` marked it load-bearing regardless.
  // Eight of the ten shipped rooms have no rest-only route, so the column was
  // meaningless for exactly the rooms it was being used to judge — it rated
  // Grip's sticky as mattering when swapping it for stone changes nothing at all.
  //
  // So the signature falls back to the timed route when there is no rest route,
  // and compares rotations AND window width.
  const signature = (lvl) => {
    const r = solveRestOnly(lvl);
    if (r.ok) return `rest:${r.rotations}`;
    const t = solveTimed(lvl);
    if (!t.ok) return 'unsolvable';
    const slack = t.best.slack === null ? 'none' : Math.round(t.best.slack * 1000);
    return `timed:${t.best.path.length}:${slack}`;
  };
  const baseSig = signature(level);

  let loadBearing = false;
  const carries = [];
  for (const [ch, replacement, label] of [['^', '.', 'spikes'], ['I', '#', 'ice'], ['T', '#', 'sticky']]) {
    if (!flat.includes(ch)) continue;
    if (signature(strip(level, ch, replacement)) !== baseSig) { loadBearing = true; carries.push(label); }
  }
  // A room with no hazards is not decorated — judge it on its shape alone.
  const bare = !/[\^IT]/.test(flat);
  if (bare) loadBearing = true;

  return { n: i + 1, name: level.name, par, loadBearing, carries,
            bare: !/[\^IT]/.test(flat), skel: skeleton(level), flat };
});

// Repetition is judged against everything before it: the first room to use a
// shape is the one that teaches it, and later copies are the redundant ones.
for (const room of rooms) {
  room.twin = null;
  for (const earlier of rooms) {
    if (earlier.n >= room.n) break;
    const s = sameness(room.skel, earlier.skel);
    if (s >= 0.85 && (!room.twin || s > room.twin.s)) room.twin = { name: earlier.name, n: earlier.n, s };
  }
}

for (const room of rooms) {
  if (room.loadBearing && !room.twin) room.verdict = 'KEEP';
  else if (!room.loadBearing && room.twin) room.verdict = 'CUT';
  else room.verdict = room.loadBearing ? 'keep?' : 'cut?';
}

console.log('  #  room               verdict  hazards        shape\n');
for (const r of rooms) {
  const haz = r.carries.length ? `${r.carries.join('+')} matter`
    : r.bare ? 'no hazards'
    : r.par === null ? 'no rest route'
    : 'all decoration';
  const shape = r.twin ? `${(r.twin.s * 100).toFixed(0)}% of #${r.twin.n} ${r.twin.name}` : 'distinct';
  console.log(`  ${String(r.n).padStart(2)} ${r.name.padEnd(18)} ${r.verdict.padEnd(8)} ${haz.padEnd(14)} ${shape}`);
}

const by = (v) => rooms.filter((r) => r.verdict === v);
console.log(`\n  KEEP  ${by('KEEP').length}   hazards matter and the shape is new`);
console.log(`  keep? ${by('keep?').length}   hazards matter, but the shape repeats an earlier room`);
console.log(`  cut?  ${by('cut?').length}   shape is new, but nothing in it does anything`);
console.log(`  CUT   ${by('CUT').length}   neither\n`);
console.log('  keeping only KEEP and keep?: '
  + rooms.filter((r) => r.verdict.startsWith('KEEP') || r.verdict === 'keep?').map((r) => r.name).join(', '));
