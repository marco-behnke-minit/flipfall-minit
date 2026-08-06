// Prove src/sim.gd still reproduces the JavaScript physics in tools/reference/ —
// the implementation tools/solve.mjs runs to prove every room solvable.
//
// Two implementations of the same simulation, checked against each other, is the
// point rather than an accident: the game runs the GDScript one and the verifier
// runs the JavaScript one, so this is what lets a solver proof mean anything
// about the shipped build.
//
//   node tools/compare-trace.mjs
//
// Both engines run the same scripted rotation schedule through all forty rooms.
// Discrete outcomes (status, cause, buttons pressed, rotations, impact count)
// must match exactly; positions and velocities are allowed a small tolerance,
// because V8 and the platform libm round exp() differently in the last place and
// nothing can close that gap short of reimplementing exp.
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const project = resolve(here, '..');
const GODOT = process.env.GODOT ?? '/Applications/Godot.app/Contents/MacOS/Godot';

// One hundredth of a pixel, against a 60 px cell and a 22 px orb.
const TOLERANCE = 0.01;

const FIELDS = ['idx', 'name', 'status', 'cause', 'x', 'y', 'vx', 'vy', 'time',
  'rotations', 'buttons', 'impacts', 'impactSum'];
// `idx` is deliberately not compared: this project sorts its rooms by measured
// difficulty (see src/levels.gd), so the same room sits at a different index in
// each project. Rooms are matched by name instead.
const DISCRETE = new Set(['name', 'status', 'cause', 'rotations', 'buttons', 'impacts']);

const run = (cmd, args) =>
  execFileSync(cmd, args, { cwd: project, encoding: 'utf8', maxBuffer: 1 << 24 })
    .split('\n')
    .filter((l) => /^\d\d /.test(l))
    .map((l) => Object.fromEntries(l.trim().split(/\s+/).map((v, i) => [FIELDS[i], v])));

const js = run(process.execPath, ['tools/trace_js.mjs']);
const gd = run(GODOT, ['--headless', '--script', 'res://tools/trace.gd']);

if (js.length !== 40 || gd.length !== 40) {
  console.error(`expected 40 rooms from each engine, got js=${js.length} gd=${gd.length}`);
  process.exit(1);
}

const failures = [];
const worst = {};

const byName = new Map(gd.map((room) => [room.name, room]));
for (const missing of js.filter((room) => !byName.has(room.name))) {
  failures.push(`${missing.name}: present in the JS rooms, absent from src/levels.gd`);
}

for (let i = 0; i < js.length; i++) {
  const counterpart = byName.get(js[i].name);
  if (!counterpart) continue;
  for (const field of FIELDS) {
    if (field === 'idx') continue;
    const a = js[i][field];
    const b = counterpart[field];
    if (DISCRETE.has(field)) {
      if (a !== b) failures.push(`${js[i].name}: ${field} js=${a} gd=${b}`);
    } else {
      const d = Math.abs(Number(a) - Number(b));
      worst[field] = Math.max(worst[field] ?? 0, d);
      if (d > TOLERANCE) failures.push(`${js[i].name}: ${field} drifted ${d.toFixed(6)}`);
    }
  }
}

console.log(`compared ${js.length} rooms`);
console.log('max drift:', Object.fromEntries(
  Object.entries(worst).map(([k, v]) => [k, v.toExponential(2)])));

if (failures.length) {
  console.error(`\n${failures.length} mismatch(es):`);
  for (const f of failures.slice(0, 20)) console.error('  ' + f);
  process.exit(1);
}
console.log('\nPASS — the port reproduces the simulation the rooms were verified against.');
