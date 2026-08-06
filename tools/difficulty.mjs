// Rank all forty rooms by how hard they actually are, and compare that with the
// tier each one is filed under.
//
//   node tools/difficulty.mjs            the table
//   node tools/difficulty.mjs --csv      same, as CSV
//
// `par` orders the tiers today, but par only measures route LENGTH. It says
// nothing about whether a route needs a timing window a human has to hit, or
// about how much of the room kills you for missing it. Those are independent
// axes, and a tier list sorted on one of them can flatten while looking fine.
//
// Rooms come from src/levels.gd — this project is the source of truth for them.
// The solved routes come from .levelcache.json, which `npm run solve` fills in
// the sibling HTML5 project, where the solver lives. That cache is keyed by a
// hash of each room's own map, so it stays valid however the rooms are ordered
// here, and only goes stale if a map is actually edited.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const GRID = 13;
const TIERS = ['easy', 'medium', 'hard', 'insane'];
const TIER_SIZE = 10;
const tierOf = (i) => TIERS[Math.floor(i / TIER_SIZE)];

/** Read the room table straight out of the GDScript. */
function loadLevels() {
  const src = readFileSync(new URL('../src/levels.gd', import.meta.url), 'utf8');
  const levels = [];
  const re = /\{"name": "([^"]+)", "par": (\d+), "map": \[([\s\S]*?)\]\}/g;
  for (const m of src.matchAll(re)) {
    levels.push({
      name: m[1],
      par: Number(m[2]),
      map: [...m[3].matchAll(/"([^"]*)"/g)].map((r) => r[1]),
    });
  }
  if (levels.length !== TIERS.length * TIER_SIZE) {
    throw new Error(`parsed ${levels.length} rooms from src/levels.gd, expected ${TIERS.length * TIER_SIZE}`);
  }
  return levels;
}

const LEVELS = loadLevels();
const cachePath = new URL('../../flipfall/.levelcache.json', import.meta.url);
const cache = JSON.parse(readFileSync(cachePath, 'utf8'));
const roomHash = (level) =>
  createHash('sha256').update(level.map.join('|')).digest('hex').slice(0, 16);

// A window this wide or wider is not really a timing test any more.
const GENEROUS_MS = 300;

// --- per-room measurement ---------------------------------------------------

function measure(level, index) {
  const solved = cache.rooms[roomHash(level)];
  if (!solved) throw new Error(`no cached solution for "${level.name}" — run npm run solve`);

  const restOnly = solved.rest.ok;
  const forgivingMs =
    solved.fast.ok && solved.fast.best.slack !== null ? solved.fast.best.slack * 1000 : null;

  // Length: rotations on the route a player would actually take.
  const rotations = restOnly ? solved.rest.rotations : solved.fast.ok ? solved.fast.best.rotations : 0;
  const seconds = restOnly ? solved.rest.seconds : solved.fast.ok ? solved.fast.best.time : 0;

  // Lethality: what the room does when you get it wrong. Spikes are fatal from
  // any side; a gap in the border means the orb can leave the room entirely.
  const flat = level.map.join('');
  const spikes = (flat.match(/\^/g) ?? []).length;
  let openEdges = 0;
  for (let i = 0; i < GRID; i++) {
    if (level.map[0][i] !== '#') openEdges++;
    if (level.map[GRID - 1][i] !== '#') openEdges++;
    if (level.map[i][0] !== '#') openEdges++;
    if (level.map[i][GRID - 1] !== '#') openEdges++;
  }
  const doors = (flat.match(/[abc]/g) ?? []).length;
  const buttons = (flat.match(/[123]/g) ?? []).length;

  return {
    n: index + 1,
    name: level.name,
    tier: tierOf(index),
    par: level.par,
    rotations,
    seconds,
    restOnly,
    forgivingMs,
    spikes,
    openEdges,
    buttons,
    doors,
  };
}

// --- the three axes ---------------------------------------------------------

const norm = (v, lo, hi) => Math.max(0, Math.min(1, (v - lo) / (hi - lo)));

/** Planning: how long the route is, and how much of it you hold in your head. */
const planScore = (m) => norm(m.rotations, 1, 12);

/**
 * Execution: whether the room can be solved from rest at all, and if not, how
 * tight the most forgiving window is. Needing *any* timing is a step change, so
 * it carries a floor — a room with a luxurious 300 ms window is still asking
 * something a rest-only room never asks.
 */
function execScore(m) {
  if (m.restOnly) return 0;
  if (m.forgivingMs === null) return 0.35;
  return 0.35 + 0.65 * (1 - norm(m.forgivingMs, 0, GENEROUS_MS));
}

/** Risk: what a mistake costs. */
const riskScore = (m) => norm(m.spikes / 10 + m.openEdges / 6, 0, 3);

const WEIGHTS = { plan: 0.4, exec: 0.4, risk: 0.2 };
const difficulty = (m) =>
  100 * (WEIGHTS.plan * planScore(m) + WEIGHTS.exec * execScore(m) + WEIGHTS.risk * riskScore(m));

// --- report -----------------------------------------------------------------

const rooms = LEVELS.map(measure);
for (const m of rooms) m.score = difficulty(m);

const ranked = [...rooms].sort((a, b) => a.score - b.score);
ranked.forEach((m, i) => {
  m.rank = i + 1;
  m.shouldBe = TIERS[Math.floor(i / TIER_SIZE)];
});

// --- the shipping order -----------------------------------------------------
//
// Sorting purely by difficulty is not quite right, because the easy tier has a
// second job: it is the DEFAULT published segment (startLevel 1, endLevel 10),
// and it is where each element is taught. A pure sort moves both sticky rooms
// into medium, so the default drop would never show a mechanic its own store
// description promises.
//
// So: the cheapest room introducing each element is pinned into easy, and
// everything else falls into place by measured difficulty. Within every tier the
// order is ascending, which is what kills the sawtooth.

const TEACHES = [
  ['doors', /[abc]/],
  ['spikes', /\^/],
  ['ice', /I/],
  ['sticky', /T/],
];

function shippingOrder() {
  const byScore = [...rooms].sort((a, b) => a.score - b.score);
  const pinned = [];
  for (const [, pattern] of TEACHES) {
    const first = byScore.find((m) => pattern.test(m.map ?? LEVELS[m.n - 1].map.join('')) && !pinned.includes(m));
    if (first) pinned.push(first);
  }
  const easy = [...pinned];
  for (const m of byScore) {
    if (easy.length >= TIER_SIZE) break;
    if (!easy.includes(m)) easy.push(m);
  }
  easy.sort((a, b) => a.score - b.score);
  const rest = byScore.filter((m) => !easy.includes(m));
  return [...easy, ...rest];
}

if (process.argv.includes('--order')) {
  const order = shippingOrder();
  const teaches = (m) => {
    const flat = LEVELS[m.n - 1].map.join('');
    return TEACHES.filter(([, p]) => p.test(flat)).map(([n]) => n);
  };
  const seen = new Set();
  console.log('SHIPPING ORDER (difficulty ascending, with the teaching rooms pinned into easy)');
  order.forEach((m, i) => {
    const tier = TIERS[Math.floor(i / TIER_SIZE)];
    const intro = teaches(m).filter((t) => !seen.has(t));
    intro.forEach((t) => seen.add(t));
    console.log(
      `  ${String(i + 1).padStart(2)}  ${tier.padEnd(7)} ${m.name.padEnd(13)} ` +
        `score ${m.score.toFixed(1).padStart(5)}  was #${String(m.n).padStart(2)} ${m.tier.padEnd(7)}` +
        (intro.length ? `  introduces ${intro.join(', ')}` : '')
    );
  });
  console.log('\nNAMES, in order:');
  console.log(order.map((m) => m.name).join(' '));
  process.exit(0);
}

if (process.argv.includes('--csv')) {
  console.log('n,name,tier,par,rotations,seconds,restOnly,forgivingMs,spikes,openEdges,score,rank,shouldBe');
  for (const m of rooms) {
    console.log([m.n, m.name, m.tier, m.par, m.rotations, m.seconds.toFixed(1), m.restOnly,
      m.forgivingMs ?? '', m.spikes, m.openEdges, m.score.toFixed(1), m.rank, m.shouldBe].join(','));
  }
  process.exit(0);
}

const win = (m) => (m.restOnly ? 'rest-only' : m.forgivingMs === null ? '?' : `${m.forgivingMs.toFixed(0)}ms`);

console.log('IN PLAY ORDER'.padEnd(52) + 'axes (0-100)');
console.log(
  '  #  tier    room          par  rot    exec-window  spike edge   plan exec risk  score  rank  belongs'
);
let prevTier = '';
for (const m of rooms) {
  if (m.tier !== prevTier) {
    console.log('  ' + '-'.repeat(100));
    prevTier = m.tier;
  }
  const misfiled = m.shouldBe !== m.tier ? `  ${m.shouldBe.toUpperCase()}` : '';
  console.log(
    `  ${String(m.n).padStart(2)} ${m.tier.padEnd(7)} ${m.name.padEnd(13)} ` +
      `${String(m.par).padStart(2)}  ${String(m.rotations).padStart(2)}  ${win(m).padStart(12)}  ` +
      `${String(m.spikes).padStart(4)} ${String(m.openEdges).padStart(4)}   ` +
      `${(100 * planScore(m)).toFixed(0).padStart(4)} ${(100 * execScore(m)).toFixed(0).padStart(4)} ` +
      `${(100 * riskScore(m)).toFixed(0).padStart(4)}  ${m.score.toFixed(1).padStart(5)}  ` +
      `${String(m.rank).padStart(4)}${misfiled}`
  );
}

// --- summaries --------------------------------------------------------------

console.log('\nTIER AVERAGES');
console.log('  tier     par   score   needs-timing   avg spikes   avg open edges');
for (const tier of TIERS) {
  const inTier = rooms.filter((m) => m.tier === tier);
  const avg = (f) => (inTier.reduce((s, m) => s + f(m), 0) / inTier.length).toFixed(1);
  const timed = inTier.filter((m) => !m.restOnly).length;
  console.log(
    `  ${tier.padEnd(8)} ${avg((m) => m.par).padStart(4)}  ${avg((m) => m.score).padStart(6)}` +
      `   ${String(timed).padStart(6)}/10   ${avg((m) => m.spikes).padStart(10)}   ${avg((m) => m.openEdges).padStart(14)}`
  );
}

console.log('\nMISFILED (by composite rank)');
const misfiled = rooms.filter((m) => m.shouldBe !== m.tier);
const order = Object.fromEntries(TIERS.map((t, i) => [t, i]));
misfiled.sort((a, b) => order[a.tier] - order[b.tier] || a.n - b.n);
for (const m of misfiled) {
  const dir = order[m.shouldBe] > order[m.tier] ? 'under-rated' : 'over-rated';
  console.log(
    `  ${String(m.n).padStart(2)} ${m.name.padEnd(13)} filed ${m.tier.padEnd(7)} -> ${m.shouldBe.padEnd(7)} (${dir}, rank ${m.rank})`
  );
}
console.log(`\n  ${misfiled.length} of ${rooms.length} rooms are in the wrong tenth.`);

// The composite's weights are a judgement call, so here is the part that is not:
// pairs where a room in an EASIER tier beats one in a HARDER tier on every axis
// at once. No weighting can reverse those.
console.log('\nSTRICT INVERSIONS (easier-tier room dominates a harder-tier room on all three axes)');
const axes = (m) => [m.rotations, execScore(m), riskScore(m)];
const inversions = [];
for (const easy of rooms) {
  for (const hard of rooms) {
    if (order[easy.tier] >= order[hard.tier]) continue;
    const a = axes(easy);
    const b = axes(hard);
    if (a.every((v, i) => v >= b[i]) && a.some((v, i) => v > b[i])) {
      inversions.push({ easy, hard });
    }
  }
}
for (const { easy, hard } of inversions) {
  console.log(
    `  ${easy.tier.padEnd(6)} #${String(easy.n).padStart(2)} ${easy.name.padEnd(12)} ` +
      `>= ${hard.tier.padEnd(6)} #${String(hard.n).padStart(2)} ${hard.name.padEnd(12)} ` +
      `(rot ${easy.rotations} vs ${hard.rotations}, spikes ${easy.spikes} vs ${hard.spikes}, edges ${easy.openEdges} vs ${hard.openEdges})`
  );
}
console.log(`  ${inversions.length} inversion(s).`);

console.log('\nPROPOSED TIERS (existing forty rooms, resorted by measured difficulty)');
for (const tier of TIERS) {
  const members = ranked.filter((m) => m.shouldBe === tier);
  console.log(`  ${tier.padEnd(7)} ${members.map((m) => `${m.name}(${m.score.toFixed(0)})`).join('  ')}`);
}

console.log('\nMONOTONICITY (does difficulty rise as you play?)');
for (const tier of TIERS) {
  const inTier = rooms.filter((m) => m.tier === tier);
  const drops = [];
  for (let i = 1; i < inTier.length; i++) {
    const d = inTier[i].score - inTier[i - 1].score;
    if (d < -5) drops.push(`${inTier[i - 1].name}->${inTier[i].name} ${d.toFixed(0)}`);
  }
  console.log(`  ${tier.padEnd(8)} ${drops.length} backward step(s)${drops.length ? ': ' + drops.join(', ') : ''}`);
}
