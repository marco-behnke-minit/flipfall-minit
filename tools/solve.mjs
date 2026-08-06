// Level verifier. Runs the reference physics under Node so no room can ship
// unsolvable.
//
//   node tools/solve.mjs             verify every room
//   node tools/solve.mjs 7           verify one room and print its solution
//   node tools/solve.mjs --fix-par   rewrite par in src/levels.gd from the solver
//   node tools/solve.mjs --force     ignore the cache and re-search everything
//
// Two independent searches per room:
//
//   REST  Rotations only while the orb is settled, so the player never has to
//         hit a timing window. This is the route a human finds, and its length
//         is what `par` should be. A room that fails here must be forgiving in
//         the TIMED pass instead.
//
//   FAST  Rotations at any moment. Reports the fewest-rotation route and the
//         most forgiving route, with the width of the tightest timing window in
//         each — the skill ceiling. Best-effort: big rooms hit the node cap.
//
// Searching all forty rooms takes minutes, so results are cached in
// .levelcache.json, keyed by a hash of the room's own map plus a hash of every
// input that could change the answer: the physics, the tuning constants and the
// search itself. Edit one room and only that room is re-searched; touch the
// engine and the whole cache is discarded.
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { loadLevels, validateLevels, tierOf, writePar } from './lib/levels.mjs';
import { solveRestOnly, solveTimed, play } from './reference/search.js';

// A room with no rest-only route needs a timing window a human can hit. How wide
// is a difficulty decision, so the bar scales with the tier.
const FORGIVING_MS = { easy: 250, medium: 200, hard: 120, insane: 60 };

const args = process.argv.slice(2);
const fixPar = args.includes('--fix-par');
const force = args.includes('--force');
const onlyArg = args.find((a) => /^\d+$/.test(a));
const only = onlyArg ? Number(onlyArg) : null;

const LEVELS = loadLevels();
const problems = validateLevels(LEVELS);
if (problems.length) {
  console.error('src/levels.gd has authoring problems:');
  for (const p of problems) console.error('  ' + p);
  process.exit(1);
}

// --- cache -----------------------------------------------------------------
const sha = (s) => createHash('sha256').update(s).digest('hex').slice(0, 16);
const readSrc = (rel) => readFileSync(new URL(rel, import.meta.url), 'utf8');
const CACHE_PATH = new URL('../.levelcache.json', import.meta.url);

// Anything that can change a search result, other than the room itself.
const ENGINE_HASH = sha(
  readSrc('./reference/physics.js') + readSrc('./reference/constants.js') + readSrc('./reference/search.js')
);
// Keyed on the map alone, so renaming a room or moving it in the list still
// hits, while changing one tile misses only that room.
const roomHash = (level) => sha(level.map.join('|'));

let cache = { engine: ENGINE_HASH, rooms: {} };
if (!force && existsSync(CACHE_PATH)) {
  try {
    const disk = JSON.parse(readFileSync(CACHE_PATH, 'utf8'));
    if (disk.engine === ENGINE_HASH) cache = disk;
    else console.log('physics, constants or search changed — re-verifying every room\n');
  } catch { /* unreadable cache is simply a miss */ }
}
let cacheHits = 0;
let cacheMisses = 0;
let cacheDirty = false;

/** Search a room, or reuse a cached result for an identical room. */
function verify(level) {
  const key = roomHash(level);
  const hit = cache.rooms[key];
  if (hit && !force) {
    cacheHits++;
    return { ...hit, cached: true };
  }
  cacheMisses++;
  const rest = solveRestOnly(level);
  const fast = solveTimed(level);
  const result = {
    rest: rest.ok
      ? { ok: true, rotations: rest.rotations, path: rest.path, seconds: play(level, rest.path).time }
      : { ok: false, reason: rest.reason },
    fast: fast.ok
      ? {
          ok: true,
          truncated: !!fast.truncated,
          shortest: { rotations: fast.shortest.path.length, slack: fast.shortest.slack, path: fast.shortest.path },
          best: { rotations: fast.best.path.length, slack: fast.best.slack, time: fast.best.time, path: fast.best.path },
        }
      : { ok: false, reason: fast.reason },
  };
  cache.rooms[key] = result;
  cacheDirty = true;
  return { ...result, cached: false };
}

const parFixes = [];
let failures = 0;
let parMismatch = 0;
let totalTime = 0;

LEVELS.forEach((level, i) => {
  const n = i + 1;
  if (only && n !== only) return;

  const res = verify(level);
  const { rest, fast } = res;

  // Shippable if there is a rest-only route (no timing at all) or a timed route
  // with a window a human can actually hit.
  const tier = tierOf(i);
  const bestSlackMs = fast.ok && fast.best.slack !== null ? fast.best.slack * 1000 : null;
  const forgiving = rest.ok || (fast.ok && (bestSlackMs === null || bestSlackMs >= FORGIVING_MS[tier] - 1));

  let restCol;
  let suggestedPar;
  if (rest.ok) {
    totalTime += rest.seconds;
    restCol = `rest-only ${String(rest.rotations).padStart(2)} rot / ${rest.seconds.toFixed(1)}s`;
    suggestedPar = rest.rotations;
  } else {
    restCol = 'rest-only NONE';
    if (fast.ok) {
      totalTime += fast.best.time;
      suggestedPar = fast.best.rotations;
    }
  }

  let fastCol;
  if (fast.ok) {
    const win = (s) => (s === null ? 'no timing' : `${(s * 1000).toFixed(0)}ms`);
    fastCol =
      `fast ${String(fast.shortest.rotations).padStart(2)} rot (${win(fast.shortest.slack)})` +
      `  forgiving ${String(fast.best.rotations).padStart(2)} rot (${win(fast.best.slack)})` +
      (fast.truncated ? ' *' : '');
  } else {
    fastCol = `fast — ${fast.reason}`;
  }

  if (!forgiving) failures++;
  let parNote = '';
  if (suggestedPar !== undefined && suggestedPar !== level.par) {
    parMismatch++;
    parNote = `  ← set par: ${suggestedPar}`;
    parFixes.push({ name: level.name, from: level.par, to: suggestedPar });
  }
  const mark = res.cached ? ' ' : '+'; // + = freshly searched this run
  console.log(
    `${forgiving ? '✓' : '✗'}${mark}${String(n).padStart(2)}. ${tier.padEnd(6)} ` +
      `${level.name.padEnd(12)} ${restCol.padEnd(28)} ${fastCol}${parNote}`
  );

  if (only) {
    if (rest.ok) {
      console.log('\n   rest-only solution (no timing needed):');
      rest.path.forEach((s, j) => {
        const when = s.wait === 'rest' ? 'once settled' : 'immediately after';
        console.log(`     ${j + 1}. ${when}  →  ${s.dir > 0 ? 'press ↺' : 'press ↻'}`);
      });
    }
    if (fast.ok) {
      console.log('\n   most forgiving solution:');
      fast.best.path.forEach((s, j) => {
        console.log(`     ${j + 1}. wait ${(s.wait * 1000).toFixed(0)}ms  →  ${s.dir > 0 ? 'press ↺' : 'press ↻'}`);
      });
    }
  }
});

if (cacheDirty) writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 1));

if (!only) {
  console.log(`\n${cacheHits} room(s) from cache, ${cacheMisses} freshly searched (marked +).`);
  console.log('* marks a search truncated by the node cap — those numbers are a lower bound.');
  console.log(`rest-only run length: ~${Math.round(totalTime)}s of simulation across ${LEVELS.length} rooms`);
  if (parMismatch) console.log(`${parMismatch} room(s) have a par that disagrees with the solver.`);
}

// `par` is informational (there is no rotation cap), but it should describe the
// route the solver actually found rather than a guess made while authoring.
if (fixPar && parFixes.length) {
  const missed = writePar(parFixes);
  for (const name of missed) console.log(`  ! could not rewrite par for ${name}`);
  console.log(`\nrewrote ${parFixes.length - missed.length} par value(s) in src/levels.gd`);
}

if (failures) {
  console.log(`\n${failures} room(s) are neither rest-only solvable nor forgiving. Fix before shipping.`);
  process.exit(1);
}
