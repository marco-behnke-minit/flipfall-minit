// Candidate rooms, run through the same solver the shipped set is verified with.
//
//   node tools/prototypes.mjs
//
// These are not in src/levels.gd and do not ship. The point is to test design
// ideas cheaply: the shipped rooms are too easy mainly because 32 of 40 are
// rest-only solvable — you can let the orb settle before every flip, so nothing
// can be failed through execution. So the bar each candidate has to clear is
// "NOT rest-only solvable", with a timing window a human can actually hit.
import { solveRestOnly, solveTimed, play } from './reference/search.js';
import { validateLevels, GRID } from './lib/levels.mjs';

// A hole in a floor is only reachable by a timed flip when it is NOT against a
// wall: the orb can always fly to a wall and stop there for free, so any target
// away from one demands either a sticky pad or a mid-flight commit. That is the
// primitive most of these are built on.
const PROTOTYPES = [
  {
    name: 'Skim',
    idea: 'Ice skid into a hole, with lethal overshoot. Flip down late and you '
        + 'carry too much speed, skim the hole and hit the spikes.',
    par: 2,
    map: [
      '#############',
      '#...........#',
      '#...........#',
      '#...........#',
      '#O..........#',
      '#...........#',
      '#IIIII.II^^^#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#.....E.....#',
      '#############',
    ],
  },
  {
    name: 'Trapdoor',
    idea: 'The button sits directly on its own door, so touching it removes the '
        + 'floor underneath and drops the orb into the chamber below.',
    par: 3,
    map: [
      '#############',
      '#...........#',
      '#...........#',
      '#...........#',
      '#O..........#',
      '#...........#',
      '#...........#',
      '#.....1.....#',
      '#####a#######',
      '#...........#',
      '#...........#',
      '#.....E.....#',
      '#############',
    ],
  },
  {
    name: 'Overhead',
    idea: 'A spiked ceiling with one safe column, so the reflex flip-up at a '
        + 'wall is fatal and the climb has to be committed mid-flight.',
    par: 3,
    map: [
      '#############',
      '#E..........#',
      '#...........#',
      '######a######',
      '#^^^^^.^^^^^#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#O.........1#',
      '#############',
    ],
  },
  {
    name: 'Trapdoor + ice',
    idea: 'The same trapdoor, but the floor either side of the door is ice, so '
        + 'the orb keeps sliding toward the hole instead of having to arrive on it.',
    par: 3,
    map: [
      '#############',
      '#...........#',
      '#...........#',
      '#...........#',
      '#O..........#',
      '#...........#',
      '#...........#',
      '#.....1.....#',
      '#IIIIIaIIIII#',
      '#...........#',
      '#...........#',
      '#.....E.....#',
      '#############',
    ],
  },
  {
    name: 'Overhead, 2-cell gap',
    idea: 'The same spiked ceiling, with the safe column widened to two cells.',
    par: 3,
    map: [
      '#############',
      '#E..........#',
      '#...........#',
      '#####aa######',
      '#^^^^..^^^^^#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#O.........1#',
      '#############',
    ],
  },
  {
    name: 'Well',
    idea: 'Exit below the start rather than above it, down a one-cell shaft — '
        + 'the ladder topology every shipped room shares, inverted.',
    par: 3,
    map: [
      '#############',
      '#O..........#',
      '#IIIIIIII.II#',
      '#########.###',
      '#########.###',
      '#########.###',
      '#...........#',
      '#...........#',
      '#...........#',
      '#...........#',
      '#E..........#',
      '#...........#',
      '#############',
    ],
  },
];

const problems = validateLevels(PROTOTYPES, {expectFullSet: false});
if (problems.length) {
  console.error('prototype authoring problems:');
  for (const p of problems) console.error('  ' + p);
  process.exit(1);
}
console.log(`${PROTOTYPES.length} prototypes, all ${GRID}x${GRID} and valid\n`);

for (const level of PROTOTYPES) {
  console.log(`${level.name}`);
  console.log(`  ${level.idea}`);

  const rest = solveRestOnly(level);
  const fast = solveTimed(level);

  if (!rest.ok && !fast.ok) {
    console.log(`  UNSOLVABLE — rest: ${rest.reason}, timed: ${fast.reason}\n`);
    continue;
  }

  if (rest.ok) {
    const t = play(level, rest.path).time;
    console.log(`  rest-only:  ${rest.rotations} rot / ${t.toFixed(1)}s   <-- TOO EASY, no timing needed`);
  } else {
    console.log(`  rest-only:  none  <-- good, execution is required`);
  }

  if (fast.ok) {
    const win = (s) => (s === null ? 'no timing' : `${(s * 1000).toFixed(0)}ms`);
    console.log(`  fastest:    ${fast.shortest.path.length} rot (window ${win(fast.shortest.slack)})`);
    console.log(`  forgiving:  ${fast.best.path.length} rot (window ${win(fast.best.slack)})`
      + (fast.truncated ? '  [search truncated]' : ''));
  } else {
    console.log(`  timed:      ${fast.reason}`);
  }
  console.log('');
}

console.log('For reference, the shipped set: 32 of 40 rooms are rest-only solvable,');
console.log('and the tightest forgiving window anywhere is 175ms.');
