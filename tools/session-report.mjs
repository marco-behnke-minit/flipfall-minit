// Summarise playtest sessions written by src/session_log.gd.
//
//   node tools/session-report.mjs              the most recent session
//   node tools/session-report.mjs --all        every session, per room
//   node tools/session-report.mjs <file.json>  a specific one
//
// The point is to answer "how did that room actually play" with evidence rather
// than recollection — how many attempts it swallowed, what killed you, how long
// you spent thinking versus how long the room clock ran. That gap is the useful
// one: the room clock only starts on the first rotation, so wall time minus room
// time is hesitation, which is what a genuinely puzzling room produces.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const DIR = new URL('../tmp/sessions/', import.meta.url).pathname;
const args = process.argv.slice(2);
const all = args.includes('--all');
const explicit = args.find((a) => a.endsWith('.json'));

if (!explicit && !existsSync(DIR)) {
  console.error('No sessions yet. Play with:');
  console.error('  godot --path . -- --rooms=prototypes --attempts=9');
  process.exit(1);
}

const files = explicit
  ? [explicit]
  : readdirSync(DIR).filter((f) => f.endsWith('.json')).sort().map((f) => join(DIR, f));

if (!files.length) {
  console.error(`No session files in ${DIR}`);
  process.exit(1);
}

const chosen = all ? files : files.slice(-1);
const rooms = new Map();

for (const file of chosen) {
  const s = JSON.parse(readFileSync(file, 'utf8'));
  if (!all) {
    console.log(`${s.rooms} rooms · ${s.startedAt} · attempts=${s.config.attempts}`
      + ` · rooms ${s.config.startLevel}-${s.config.endLevel}\n`);
    console.log('  #  room               tries  cleared   rot   room-time  thinking  died');
  }
  for (const r of s.log) {
    const tries = r.attempts.length;
    const cleared = r.attempts.find((a) => a.outcome === 'clear');
    const wall = r.attempts.reduce((t, a) => t + a.wallSeconds, 0);
    const roomTime = r.attempts.reduce((t, a) => t + a.roomSeconds, 0);
    const died = r.deaths.spike + r.deaths.out;
    const parts = [];
    if (r.deaths.spike) parts.push(`${r.deaths.spike} spike`);
    if (r.deaths.out) parts.push(`${r.deaths.out} fell out`);
    if (r.retries) parts.push(`${r.retries} retry`);

    if (!all) {
      console.log(
        `  ${String(r.index).padStart(2)}  ${r.name.padEnd(18)} ${String(tries).padStart(5)}`
        + `  ${(cleared ? `yes(${r.attempts.indexOf(cleared) + 1})` : r.outcome).padEnd(8)}`
        + ` ${String(cleared ? cleared.rotations : '-').padStart(4)}`
        + ` ${(roomTime.toFixed(1) + 's').padStart(10)}`
        + ` ${((wall - roomTime).toFixed(1) + 's').padStart(9)}`
        + `  ${parts.join(', ')}`);
    }

    const agg = rooms.get(r.name) ?? { name: r.name, sessions: 0, tries: 0, died: 0, retries: 0, cleared: 0, wall: 0 };
    agg.sessions++; agg.tries += tries; agg.died += died; agg.retries += r.retries;
    agg.cleared += cleared ? 1 : 0; agg.wall += wall;
    rooms.set(r.name, agg);
  }
  if (!all) {
    const res = s.result ?? {};
    console.log(`\n  score ${res.score ?? '-'} · cleared ${res.roomsCleared ?? '-'}`
      + ` · attempts left ${res.attemptsLeft ?? '-'}`
      + (res.flavorText ? ` · "${res.flavorText}"` : ''));
  }
}

if (all) {
  console.log(`Across ${chosen.length} session(s)\n`);
  console.log('  room               played  cleared  tries/play  deaths  retries  time');
  for (const r of [...rooms.values()].sort((a, b) => b.tries / b.sessions - a.tries / a.sessions)) {
    console.log(
      `  ${r.name.padEnd(18)} ${String(r.sessions).padStart(6)} ${String(r.cleared).padStart(8)}`
      + ` ${(r.tries / r.sessions).toFixed(1).padStart(11)} ${String(r.died).padStart(7)}`
      + ` ${String(r.retries).padStart(8)} ${(r.wall.toFixed(0) + 's').padStart(6)}`);
  }
  console.log('\n  tries/play is the headline: 1.0 is a room that never resists,');
  console.log('  and anything past ~4 is where a three-attempt run starts ending.');
}
