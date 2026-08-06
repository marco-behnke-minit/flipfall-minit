// Reference trace, produced by the ORIGINAL JavaScript physics.
//
// Run the same scripted rotation schedule through every room and print the
// resulting state. tools/trace.gd prints the identical format from the GDScript
// port, and tools/compare-trace.mjs diffs the two — which is what shows the port
// reproduces the simulation the rooms were proven solvable against.
//
//   node tools/trace_js.mjs > /tmp/trace-js.txt
import { LEVELS } from '../../flipfall/src/levels.js';
import { createWorld, stepWorld, rotate } from '../../flipfall/src/physics.js';
import { SUBSTEP } from '../../flipfall/src/constants.js';

// Deliberately awkward: rotations land mid-flight, not at rest, so the schedule
// exercises the collision and friction paths rather than settling between moves.
const SCHEDULE = [
  { wait: 0.5, dir: 1 },
  { wait: 1.0, dir: -1 },
  { wait: 0.75, dir: 1 },
  { wait: 1.5, dir: 1 },
  { wait: 2.0, dir: null },
];

const FRAME = 1 / 60;

for (let i = 0; i < LEVELS.length; i++) {
  const level = LEVELS[i];
  const w = createWorld(level);
  const impacts = [];

  for (const stage of SCHEDULE) {
    let t = 0;
    while (t < stage.wait && w.status === 'playing') {
      stepWorld(w, FRAME, SUBSTEP);
      for (const ev of w.events) if (ev.type === 'impact') impacts.push(ev.speed);
      w.events.length = 0;
      t += FRAME;
    }
    if (stage.dir !== null) rotate(w, stage.dir);
  }

  const buttons = [...w.buttons].sort().join('');
  const impactSum = impacts.reduce((a, b) => a + b, 0);
  console.log(
    [
      String(i + 1).padStart(2, '0'),
      level.name,
      w.status,
      w.cause || '-',
      w.orb.x.toFixed(8),
      w.orb.y.toFixed(8),
      w.orb.vx.toFixed(8),
      w.orb.vy.toFixed(8),
      w.time.toFixed(8),
      w.rotations,
      buttons || '-',
      impacts.length,
      impactSum.toFixed(6),
    ].join(' ')
  );
}
