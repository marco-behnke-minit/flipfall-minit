// Candidate rooms, run through the same solver the shipped set is verified with.
//
//   node tools/prototypes.mjs           measure them all
//   node tools/prototypes.mjs Skim      one room's route, flip by flip
//
// The rooms live in src/prototypes.gd and are read from there, so the set that
// is measured is the set that is played. They do not ship.
//
// The bar: NOT rest-only solvable. The shipped set is too easy mainly because
// 32 of its 40 rooms are — the orb can be left to settle before every flip, so
// nothing can be failed through execution.
//
// Read the window numbers with care. Playtesting overturned them once already: a
// room scored at 0ms was beaten first try because the room before it had taught
// the move, and two rooms differing 11x in window played as identical. A search
// printing [search truncated] hit the node cap, so its window is a lower bound.
// What separated hard from annoying in play was whether a mistake could kill.
import {
  solveRestOnly, solveTimed, play,
  cloneWorld, advance, clearsUntouched, HORIZON,
} from './reference/search.js';
import { createWorld, rotate } from './reference/physics.js';
import { loadLevelsFrom, validateLevels, GRID } from './lib/levels.mjs';

const PROTOTYPES = loadLevelsFrom(new URL('../src/prototypes.gd', import.meta.url));

/**
 * The window on EACH flip of a route, not just the tightest.
 *
 * slackOf() in the reference search computes these and reports only the minimum,
 * which hides where a room is actually hard: one knife-edge flip among four
 * generous ones plays nothing like four medium ones. Same probe, kept per step.
 * `null` means the flip is taken at rest — no timing at all.
 */
function stepWindows(level, path) {
  const w = createWorld(level);
  const windows = [];

  path.forEach((step, idx) => {
    const wait = step.wait === 'rest' ? 0 : step.wait;
    const probeState = cloneWorld(w);
    advance(probeState, wait);

    if (probeState.resting) {
      windows.push(null);
    } else {
      const probe = (t) => {
        if (t < 0) return false;
        const test = cloneWorld(w);
        advance(test, t);
        if (test.status !== 'playing') return false;
        rotate(test, step.dir);
        for (const rem of path.slice(idx + 1)) {
          advance(test, rem.wait === 'rest' ? HORIZON : rem.wait);
          if (test.status !== 'playing') break;
          rotate(test, rem.dir);
        }
        return clearsUntouched(test);
      };
      let lo = wait;
      let hi = wait;
      for (let d = 0.025; d <= 1.5; d += 0.025) { if (probe(wait - d)) lo = wait - d; else break; }
      for (let d = 0.025; d <= 1.5; d += 0.025) { if (probe(wait + d)) hi = wait + d; else break; }
      windows.push(hi - lo);
    }

    advance(w, wait);
    rotate(w, step.dir);
  });
  return windows;
}

const only = process.argv[2];

const PROTOTYPE_ROOMS = PROTOTYPES;
const problems = validateLevels(PROTOTYPE_ROOMS, { expectFullSet: false });
if (problems.length) {
  console.error('prototype authoring problems:');
  for (const p of problems) console.error('  ' + p);
  process.exit(1);
}
console.log(`${PROTOTYPE_ROOMS.length} prototypes from src/prototypes.gd, all ${GRID}x${GRID} and valid\n`);

for (const level of PROTOTYPE_ROOMS) {
  if (only && !level.name.toLowerCase().startsWith(only.toLowerCase())) continue;
  console.log(level.name);

  const rest = solveRestOnly(level);
  const fast = solveTimed(level);

  if (!rest.ok && !fast.ok) {
    console.log(`  UNSOLVABLE — rest: ${rest.reason}, timed: ${fast.reason}\n`);
    continue;
  }

  if (rest.ok) {
    console.log(`  rest-only:  ${rest.rotations} rot / ${play(level, rest.path).time.toFixed(1)}s`
      + '   <-- TOO EASY, nothing has to be timed');
  } else {
    console.log('  rest-only:  none  <-- good, execution is required');
  }

  if (fast.ok) {
    const win = (s) => (s === null ? 'no timing' : `${(s * 1000).toFixed(0)}ms`);
    console.log(`  fastest:    ${fast.shortest.path.length} rot (window ${win(fast.shortest.slack)})`);
    console.log(`  forgiving:  ${fast.best.path.length} rot (window ${win(fast.best.slack)})`
      + (fast.truncated ? '  [search truncated — window is a lower bound]' : ''));
  } else {
    console.log(`  timed:      ${fast.reason}`);
  }

  if (only && fast.ok) {
    console.log('\n  the forgiving route, flip by flip:');
    stepWindows(level, fast.best.path).forEach((w, i) => {
      const s = fast.best.path[i];
      const verdict = w === null ? 'at rest, no timing'
        : w >= 0.25 ? `${(w * 1000).toFixed(0)}ms  comfortable`
        : w >= 0.15 ? `${(w * 1000).toFixed(0)}ms  tight`
        : `${(w * 1000).toFixed(0)}ms  very tight`;
      console.log(`    ${i + 1}. wait ${(s.wait * 1000).toFixed(0).padStart(4)}ms  ->  `
        + `press ${s.dir > 0 ? 'CCW' : 'CW '}   ${verdict}`);
    });
  }
  console.log('');
}
