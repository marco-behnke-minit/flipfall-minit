// ---------------------------------------------------------------------------
// Shared level-solving search, used by tools/solve.js and tools/run-sim.js.
// Runs the shipped physics unmodified.
// ---------------------------------------------------------------------------
import { createWorld, stepWorld, rotate } from './physics.js';
import { SUBSTEP, CELL, GRID } from './constants.js';

export const WAITS = [0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.25, 1.5, 1.8, 2.2, 2.6];
export const HORIZON = 5.0;
export const MAX_ROTATIONS = 12;
export const REST_CAP = 900000;
export const FAST_CAP = 150000;

export function cloneWorld(w) {
  return {
    grid: w.grid, // never mutated
    orb: { ...w.orb },
    gravity: w.gravity,
    buttons: new Set(w.buttons),
    doorsOpen: new Set(w.doorsOpen),
    status: w.status,
    cause: w.cause,
    contact: w.contact,
    resting: w.resting,
    events: [],
    time: w.time,
    rotations: w.rotations,
  };
}

/** Coarse fingerprint so the search collapses near-identical states. */
export function key(w) {
  const c = Math.floor(w.orb.x / (CELL / 2));
  const r = Math.floor(w.orb.y / (CELL / 2));
  const sp = Math.min(6, Math.floor(Math.hypot(w.orb.vx, w.orb.vy) / 220));
  const dir = w.resting ? 9 : (Math.round((Math.atan2(w.orb.vy, w.orb.vx) / Math.PI) * 4 + 4) % 8);
  return `${c},${r},${w.gravity},${sp},${dir},${[...w.buttons].sort().join('')}`;
}

/** Simulate up to `seconds`, stopping early once settled, cleared or dead. */
export function advance(w, seconds) {
  let t = 0;
  let restFor = 0;
  while (t < seconds && w.status === 'playing') {
    stepWorld(w, SUBSTEP, SUBSTEP);
    t += SUBSTEP;
    restFor = w.resting ? restFor + SUBSTEP : 0;
    if (restFor > 0.4) break; // settled — waiting longer changes nothing
  }
  return t;
}

export function clearsUntouched(w0, seconds = HORIZON) {
  const w = cloneWorld(w0);
  advance(w, seconds);
  return w.status === 'clear';
}

/**
 * Rest-only search: rotations are allowed only while the orb is settled, so the
 * player never has to hit a timing window. From a settled state, rotating k
 * times back-to-back reaches any gravity (k=1 neighbours, k=2 opposite).
 */
export function solveRestOnly(level) {
  const root = createWorld(level);
  if (clearsUntouched(root)) return { ok: true, path: [], rotations: 0 };

  const seen = new Set([key(root)]);
  let frontier = [{ w: root, path: [] }];
  let nodes = 0;

  for (let depth = 0; depth < MAX_ROTATIONS; depth++) {
    const next = [];
    for (const node of frontier) {
      for (const [dir, times] of [[1, 1], [-1, 1], [1, 2]]) {
        if (++nodes > REST_CAP) return { ok: false, reason: `node cap (${nodes})` };
        if (node.path.length + times > MAX_ROTATIONS) continue;

        const w = cloneWorld(node.w);
        for (let i = 0; i < times; i++) rotate(w, dir);
        advance(w, HORIZON);

        const path = [...node.path];
        for (let i = 0; i < times; i++) path.push({ wait: i === 0 ? 'rest' : 0, dir });

        if (w.status === 'clear') return { ok: true, path, rotations: path.length };
        if (w.status !== 'playing' || !w.resting) continue; // died, or never settled

        const k = key(w);
        if (seen.has(k)) continue;
        seen.add(k);
        next.push({ w, path });
      }
    }
    frontier = next;
    if (!frontier.length) break;
  }
  return { ok: false, reason: `no rest-only route within ${MAX_ROTATIONS} rotations` };
}

/**
 * Timed search. Keeps looking past the first hit — the fewest-rotation route is
 * usually frame-perfect, while a route one or two rotations longer can be far
 * more forgiving. Returns the shortest and the most forgiving.
 */
export function solveTimed(level, { solutionBudget = 60, extraDepth = 2 } = {}) {
  const root = createWorld(level);
  if (clearsUntouched(root)) {
    const zero = { path: [], slack: null, time: 0 };
    return { ok: true, shortest: zero, best: zero };
  }

  const seen = new Set([key(root)]);
  // Physics is frozen until the first rotation, so the authored state persists
  // indefinitely — the opening action can only be an immediate rotation.
  let frontier = [{ w: root, path: [], first: true }];
  let nodes = 0;
  const solutions = [];
  let firstDepth = null;
  let exhausted = false;

  for (let depth = 0; depth < MAX_ROTATIONS && !exhausted; depth++) {
    if (firstDepth !== null && depth > firstDepth + extraDepth) break;
    const next = [];
    for (const node of frontier) {
      for (const dir of [1, -1]) {
        for (const wait of node.first ? [0] : WAITS) {
          if (++nodes > FAST_CAP) { exhausted = true; break; }
          const w = cloneWorld(node.w);
          advance(w, wait);
          if (w.status !== 'playing') continue;
          rotate(w, dir);

          const path = [...node.path, { wait, dir }];
          if (clearsUntouched(w)) {
            if (firstDepth === null) firstDepth = depth;
            if (solutions.length < solutionBudget) solutions.push(path);
            continue;
          }
          const k = key(w);
          if (seen.has(k)) continue;
          seen.add(k);
          next.push({ w, path, first: false });
        }
        if (exhausted) break;
      }
      if (exhausted) break;
    }
    frontier = next;
    if (!frontier.length) break;
  }

  if (!solutions.length) {
    return { ok: false, reason: exhausted ? `node cap (${nodes})` : `no route within ${MAX_ROTATIONS} rotations` };
  }

  const scored = solutions.map((p) => ({ path: p, ...slackOf(level, p) }));
  const shortest = scored.reduce((a, b) => (b.path.length < a.path.length ? b : a));
  const best = scored.reduce((a, b) => {
    const av = a.slack === null ? Infinity : a.slack;
    const bv = b.slack === null ? Infinity : b.slack;
    return bv > av ? b : a;
  });
  return { ok: true, shortest, best, truncated: exhausted };
}

/** Replay a path and measure the tightest mid-flight timing window in it. */
export function slackOf(level, path) {
  const w = createWorld(level);
  let tightest = Infinity;

  path.forEach((step, idx) => {
    const wait = step.wait === 'rest' ? 0 : step.wait;
    const probeState = cloneWorld(w);
    advance(probeState, wait);

    if (!probeState.resting) {
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
      tightest = Math.min(tightest, hi - lo);
    }

    advance(w, wait);
    rotate(w, step.dir);
  });

  advance(w, HORIZON);
  return { slack: tightest === Infinity ? null : tightest, time: w.time };
}

/** Play a path for real and return the resolved world. */
export function play(level, path) {
  const w = createWorld(level);
  for (const step of path) {
    advance(w, step.wait === 'rest' ? HORIZON : step.wait);
    if (w.status !== 'playing') break;
    rotate(w, step.dir);
  }
  if (w.status === 'playing') advance(w, HORIZON);
  return w;
}

/**
 * The route a player is expected to take: prefer the forgiving timed route, and
 * fall back to the rest-only route when the timed search can't finish.
 */
export function playerRoute(level) {
  const rest = solveRestOnly(level);
  const fast = solveTimed(level);
  if (rest.ok && !fast.ok) return { path: rest.path, kind: 'rest-only' };
  if (!rest.ok && fast.ok) return { path: fast.best.path, kind: 'timed' };
  if (!rest.ok && !fast.ok) return null;
  // Both available: rest-only never needs a timing window, so prefer it unless
  // the timed route is shorter and still comfortable.
  const comfy = fast.best.slack === null || fast.best.slack >= 0.25;
  if (comfy && fast.best.path.length < rest.rotations) return { path: fast.best.path, kind: 'timed' };
  return { path: rest.path, kind: 'rest-only' };
}

export { GRID };
