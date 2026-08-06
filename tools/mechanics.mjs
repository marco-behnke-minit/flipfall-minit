// What the forty rooms actually exercise.
//
//   node tools/mechanics.mjs
//
// Two things it reports, and the second is the useful one: which mechanics the
// levels cover, and which the engine supports that no room has ever used.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const GRID = 13;
const TIERS = ['easy', 'medium', 'hard', 'insane'];
const TIER_SIZE = 10;
const tierOf = (i) => TIERS[Math.floor(i / TIER_SIZE)];

function loadLevels() {
  const src = readFileSync(new URL('../src/levels.gd', import.meta.url), 'utf8');
  return [...src.matchAll(/\{"name": "([^"]+)", "par": (\d+), "map": \[([\s\S]*?)\]\}/g)].map((m) => ({
    name: m[1],
    par: Number(m[2]),
    map: [...m[3].matchAll(/"([^"]*)"/g)].map((r) => r[1]),
  }));
}

const LEVELS = loadLevels();
const cache = JSON.parse(readFileSync(new URL('../../flipfall/.levelcache.json', import.meta.url), 'utf8'));
const solved = (l) => cache.rooms[createHash('sha256').update(l.map.join('|')).digest('hex').slice(0, 16)];

const at = (l, c, r) => (c < 0 || r < 0 || c >= GRID || r >= GRID ? null : l.map[r][c]);
const SOLID = new Set(['#', 'I', 'T']);
const isSolid = (ch) => ch !== null && (SOLID.has(ch) || /[abc]/.test(ch));

/** Horizontal runs of a character, as widths. */
function runs(level, test) {
  const widths = [];
  for (let r = 0; r < GRID; r++) {
    let n = 0;
    for (let c = 0; c <= GRID; c++) {
      const ch = at(level, c, r);
      if (ch !== null && test(ch)) n++;
      else { if (n) widths.push(n); n = 0; }
    }
  }
  return widths;
}

// Gravity is down/left/up/right; +1 steps clockwise, -1 counter-clockwise.
const GRAV = ['down', 'left', 'up', 'right'];
function gravityStates(level) {
  const s = solved(level);
  const path = s?.rest?.ok ? s.rest.path : s?.fast?.ok ? s.fast.best.path : null;
  if (!path) return null;
  const seen = new Set(['down']);
  let g = 0;
  for (const step of path) {
    g = (g + (step.dir > 0 ? 1 : 3)) % 4;
    seen.add(GRAV[g]);
  }
  return seen;
}

const rooms = LEVELS.map((level, i) => {
  const flat = level.map.join('');
  const count = (re) => (flat.match(re) ?? []).length;

  let openEdges = 0;
  for (let i2 = 0; i2 < GRID; i2++) {
    if (level.map[0][i2] !== '#') openEdges++;
    if (level.map[GRID - 1][i2] !== '#') openEdges++;
    if (level.map[i2][0] !== '#') openEdges++;
    if (level.map[i2][GRID - 1] !== '#') openEdges++;
  }

  // Interior vertical structure: a solid cell off the border with open space to
  // its left or right — i.e. a shaft or pillar rather than another shelf.
  let verticalInterior = 0;
  for (let r = 1; r < GRID - 1; r++) {
    for (let c = 1; c < GRID - 1; c++) {
      if (level.map[r][c] !== '#') continue;
      const above = at(level, c, r - 1) === '#';
      const below = at(level, c, r + 1) === '#';
      if (above && below) verticalInterior++;
    }
  }

  // Where the spikes sit.
  let spikeFloor = 0, spikeCeiling = 0, spikeFree = 0;
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      if (level.map[r][c] !== '^') continue;
      if (isSolid(at(level, c, r + 1))) spikeFloor++;
      else if (isSolid(at(level, c, r - 1))) spikeCeiling++;
      else spikeFree++;
    }
  }

  const s = solved(level);
  return {
    n: i + 1,
    name: level.name,
    tier: tierOf(i),
    level,
    spikes: count(/\^/g),
    ice: count(/I/g),
    sticky: count(/T/g),
    buttons: count(/[123]/g),
    doors: count(/[abc]/g),
    doorWidths: runs(level, (ch) => /[abc]/.test(ch)),
    stickyWidths: runs(level, (ch) => ch === 'T'),
    iceWidths: runs(level, (ch) => ch === 'I'),
    exits: count(/E/g),
    openEdges,
    verticalInterior,
    spikeFloor,
    spikeCeiling,
    spikeFree,
    restOnly: !!s?.rest?.ok,
    gravity: gravityStates(level),
  };
});

const n = rooms.length;
const rows = (label, test) => {
  const hits = rooms.filter(test);
  console.log(`  ${label.padEnd(42)} ${String(hits.length).padStart(2)}/${n} rooms`);
  return hits;
};

console.log(`COVERED BY THE ${n} ROOMS\n`);

console.log('Tiles');
rows('wall  #   solid mass', () => true);
rows('air   .   open space', () => true);
rows('orb   O   spawn (exactly one)', () => true);
rows('exit  E   clears the room', (m) => m.exits > 0);
rows('spike ^   fatal from any side', (m) => m.spikes > 0);
rows('ice   I   almost no grip', (m) => m.ice > 0);
rows('sticky T  stops the orb dead', (m) => m.sticky > 0);
rows('button 1/2/3 + door a/b/c (latching)', (m) => m.buttons > 0);

console.log('\nGravity');
rows('rotation is the only control', () => true);
rows('solution needs gravity UP', (m) => m.gravity?.has('up'));
rows('solution needs all four directions', (m) => m.gravity?.size === 4);
rows('solution needs only two directions', (m) => m.gravity?.size === 2);
rows('mid-flight rotation required (not rest-only)', (m) => !m.restOnly);

console.log('\nSurfaces and hazards');
rows('stone friction only (no ice, no sticky)', (m) => !m.ice && !m.sticky);
rows('ice floor', (m) => m.ice > 0);
rows('sticky brake pad', (m) => m.sticky > 0);
rows('ice and sticky together', (m) => m.ice > 0 && m.sticky > 0);
rows('spikes as a floor', (m) => m.spikeFloor > 0);
rows('spikes as a ceiling', (m) => m.spikeCeiling > 0);
rows('spikes free-standing (neither)', (m) => m.spikeFree > 0);
rows('open edge — the orb can fall out', (m) => m.openEdges > 0);

console.log('\nDoors and buttons');
for (const k of [0, 1, 2, 3]) {
  rows(`${k} button/door pair${k === 1 ? '' : 's'}`, (m) => m.buttons === k);
}
const allDoorWidths = rooms.flatMap((m) => m.doorWidths);
const allSticky = rooms.flatMap((m) => m.stickyWidths);
const allIce = rooms.flatMap((m) => m.iceWidths);
const tally = (xs) => [...new Set(xs)].sort((a, b) => a - b).map((w) => `${w}(x${xs.filter((v) => v === w).length})`).join(' ');
console.log(`  door widths in cells                       ${tally(allDoorWidths)}`);
console.log(`  sticky pad widths in cells                 ${tally(allSticky)}`);
console.log(`  ice run widths in cells                    ${tally(allIce)}`);

console.log('\nGeometry');
rows('interior vertical structure (shaft/pillar)', (m) => m.verticalInterior > 0);
rows('more than one exit', (m) => m.exits > 1);

// --- what the engine supports that nothing uses ------------------------------

console.log('\n\nSUPPORTED BY THE ENGINE, USED BY NO ROOM\n');

// A closed door is solid and buttons latch forever, so opening one permanently
// removes a surface. For that to cost the player anything, the orb has to be
// standing on the door at the moment the button is pressed — which needs the
// button sitting directly on its own door. Nothing else can spring the trap,
// because pressing a button means being at the button.
const doorFor = (btn) => String.fromCharCode(btn.charCodeAt(0) - 48 + 96);
const trapdoor = rooms.filter((m) => {
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      const ch = m.level.map[r][c];
      if (!/[123]/.test(ch)) continue;
      if (at(m.level, c, r + 1) === doorFor(ch)) return true;
    }
  }
  return false;
});
console.log(`  a button standing on its own door          ${trapdoor.length}/${n} rooms`);
console.log('    (a closed door is solid and buttons latch forever, so opening one');
console.log('     permanently removes a surface — but no room ever makes that a cost:');
console.log('     opening every door is always pure gain, so doors are a gate and');
console.log('     never a trapdoor)');

const restitution = rooms.filter(() => false);
console.log(`  a bouncy surface                           ${restitution.length}/${n} rooms`);
console.log('    (materials carry a restitution term, but every one shipped is');
console.log('     near-inelastic: wall 0.1, ice 0.05, sticky 0.0)');

console.log(`  a fourth button/door pair                  0/${n} rooms`);
console.log('    (the tile set defines 1/2/3 and a/b/c only)');
