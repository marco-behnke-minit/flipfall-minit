// ---------------------------------------------------------------------------
// Deterministic orb simulation. No DOM access anywhere in this file — tools/
// solve.js imports it under Node to prove every level is solvable.
//
// Coordinates here are playfield-local: (0,0) .. (PF_SIZE, PF_SIZE).
// ---------------------------------------------------------------------------
import { CELL, GRID, ORB_R, GRAVITY, MAX_SPEED, REST_SPEED } from './constants.js';

// Gravity states, in clockwise order: dir=+1 steps clockwise through them
// (Down → Left → Up → Right). Note that the ↺ *button* sends dir=+1, because
// turning gravity clockwise tips the room counter-clockwise — see main.js.
export const GRAV = [
  { x: 0, y: 1, name: 'down' },
  { x: -1, y: 0, name: 'left' },
  { x: 0, y: -1, name: 'up' },
  { x: 1, y: 0, name: 'right' },
];
export const DOWN = 0;

// Surface materials. `k` is a per-second exponential velocity decay, so an orb
// landing at speed v skids roughly v/k pixels before settling. At MAX_SPEED
// that is ~5 cells on stone, most of the room on ice, and half a cell on
// sticky — which is the whole point of the two modifiers.
const WALL = { k: 3.0, e: 0.1, kind: 'wall' };
const ICE = { k: 0.25, e: 0.05, kind: 'ice' };
const STICKY = { k: 30, e: 0.0, kind: 'sticky' };

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

const isDoor = (ch) => ch >= 'a' && ch <= 'c';
const isButton = (ch) => ch >= '1' && ch <= '3';
export const doorFor = (btn) => String.fromCharCode(btn.charCodeAt(0) - 48 + 96);

function materialOf(ch) {
  if (ch === 'I') return ICE;
  if (ch === 'T') return STICKY;
  return WALL;
}

function tileAt(w, c, r) {
  if (c < 0 || r < 0 || c >= GRID || r >= GRID) return null; // outside the grid is void
  return w.grid[r][c];
}

function solidAt(w, ch) {
  if (ch === '#' || ch === 'I' || ch === 'T') return true;
  if (isDoor(ch)) return !w.doorsOpen.has(ch);
  return false;
}

/** Does the orb overlap cell (c,r), shrunk by `inset` on every side? */
function overlapsCell(orb, c, r, inset) {
  const x0 = c * CELL + inset;
  const y0 = r * CELL + inset;
  const x1 = (c + 1) * CELL - inset;
  const y1 = (r + 1) * CELL - inset;
  const nx = clamp(orb.x, x0, x1);
  const ny = clamp(orb.y, y0, y1);
  const dx = orb.x - nx;
  const dy = orb.y - ny;
  return dx * dx + dy * dy < ORB_R * ORB_R;
}

export function createWorld(level) {
  const grid = level.map.map((row) => row.split(''));
  let start = null;
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      if (grid[r][c] === 'O') {
        start = { c, r };
        grid[r][c] = '.'; // the spawn marker is not a tile
      }
    }
  }
  if (!start) throw new Error(`level "${level.name}" has no orb start`);

  const w = {
    grid,
    orb: {
      x: start.c * CELL + CELL / 2,
      y: start.r * CELL + CELL / 2,
      vx: 0,
      vy: 0,
    },
    gravity: DOWN,
    buttons: new Set(),
    doorsOpen: new Set(),
    status: 'playing', // 'playing' | 'clear' | 'dead'
    cause: null, // 'spike' | 'out'
    contact: null, // material kind touched this step, for sfx / rendering
    resting: false,
    events: [], // drained by the caller each frame
    time: 0,
    rotations: 0,
  };

  // A cell-centred spawn floats CELL/2 - ORB_R above the surface below it, so
  // the orb's first sideways move would glide with no contact and skip friction
  // entirely. Drop it onto its supporting surface first, so the frozen opening
  // state the player sees is a genuine resting state.
  for (let i = 0; i < 480 && !w.resting && w.status === 'playing'; i++) substep(w, 1 / 240);
  w.orb.vx = 0;
  w.orb.vy = 0;
  w.status = 'playing';
  w.cause = null;
  w.events.length = 0;
  w.time = 0;
  w.rotations = 0;
  return w;
}

export function rotate(w, dir) {
  if (w.status !== 'playing') return;
  w.gravity = (w.gravity + (dir > 0 ? 1 : 3)) % 4;
  w.rotations++;
  w.events.push({ type: 'rotate', dir });
}

/** Advance one fixed substep. Call via stepWorld, not directly. */
function substep(w, dt) {
  const o = w.orb;
  const g = GRAV[w.gravity];

  o.vx += g.x * GRAVITY * dt;
  o.vy += g.y * GRAVITY * dt;

  const sp = Math.hypot(o.vx, o.vy);
  if (sp > MAX_SPEED) {
    o.vx = (o.vx / sp) * MAX_SPEED;
    o.vy = (o.vy / sp) * MAX_SPEED;
  }

  o.x += o.vx * dt;
  o.y += o.vy * dt;

  // --- collide against every solid tile the orb's AABB touches ---
  const c0 = Math.floor((o.x - ORB_R) / CELL);
  const c1 = Math.floor((o.x + ORB_R) / CELL);
  const r0 = Math.floor((o.y - ORB_R) / CELL);
  const r1 = Math.floor((o.y + ORB_R) / CELL);

  let contactK = 0;
  let touched = false;
  let hardest = 0; // impact speed, for collision sfx
  let contactKind = null;

  for (let r = r0; r <= r1; r++) {
    for (let c = c0; c <= c1; c++) {
      const ch = tileAt(w, c, r);
      if (ch === null || !solidAt(w, ch)) continue;

      const rx = c * CELL;
      const ry = r * CELL;
      const nearX = clamp(o.x, rx, rx + CELL);
      const nearY = clamp(o.y, ry, ry + CELL);
      let dx = o.x - nearX;
      let dy = o.y - nearY;
      const d = Math.hypot(dx, dy);

      let nx;
      let ny;
      let pen;
      if (d > 1e-6) {
        if (d >= ORB_R) continue;
        nx = dx / d;
        ny = dy / d;
        pen = ORB_R - d;
      } else {
        // Centre is inside the tile — eject along the shallowest axis.
        const left = o.x - rx;
        const right = rx + CELL - o.x;
        const top = o.y - ry;
        const bottom = ry + CELL - o.y;
        const m = Math.min(left, right, top, bottom);
        if (m === left) { nx = -1; ny = 0; pen = ORB_R + left; }
        else if (m === right) { nx = 1; ny = 0; pen = ORB_R + right; }
        else if (m === top) { nx = 0; ny = -1; pen = ORB_R + top; }
        else { nx = 0; ny = 1; pen = ORB_R + bottom; }
      }

      o.x += nx * pen;
      o.y += ny * pen;

      const mat = materialOf(ch);
      const vn = o.vx * nx + o.vy * ny;
      if (vn < 0) {
        if (-vn > hardest) hardest = -vn;
        o.vx -= (1 + mat.e) * vn * nx;
        o.vy -= (1 + mat.e) * vn * ny;
      }
      touched = true;
      if (mat.k > contactK) {
        contactK = mat.k;
        contactKind = mat.kind;
      }
    }
  }

  // Surface drag. The normal component is already resolved above, so decaying
  // the whole velocity is equivalent to tangential friction and stays stable.
  if (touched) {
    const f = Math.exp(-contactK * dt);
    o.vx *= f;
    o.vy *= f;
  }

  w.contact = contactKind;
  w.resting = touched && Math.hypot(o.vx, o.vy) < REST_SPEED;
  if (hardest > 150) w.events.push({ type: 'impact', speed: hardest, kind: contactKind });

  // --- hazards and triggers ---
  for (let r = r0; r <= r1; r++) {
    for (let c = c0; c <= c1; c++) {
      const ch = tileAt(w, c, r);
      if (ch === null) continue;

      if (ch === '^') {
        if (overlapsCell(o, c, r, 12)) {
          w.status = 'dead';
          w.cause = 'spike';
          return;
        }
      } else if (isButton(ch)) {
        if (!w.buttons.has(ch) && overlapsCell(o, c, r, 6)) {
          w.buttons.add(ch);
          w.doorsOpen.add(doorFor(ch));
          w.events.push({ type: 'button', ch, c, r });
        }
      } else if (ch === 'E') {
        const cx = c * CELL + CELL / 2;
        const cy = r * CELL + CELL / 2;
        if (Math.hypot(o.x - cx, o.y - cy) < CELL * 0.44) {
          w.status = 'clear';
          w.events.push({ type: 'clear', c, r });
          return;
        }
      }
    }
  }

  // --- fell out of the level ---
  const pad = CELL * 1.5;
  if (o.x < -pad || o.y < -pad || o.x > GRID * CELL + pad || o.y > GRID * CELL + pad) {
    w.status = 'dead';
    w.cause = 'out';
  }
}

/** Advance `dt` seconds using fixed substeps. Returns the world. */
export function stepWorld(w, dt, substepSize) {
  if (w.status !== 'playing') return w;
  const h = substepSize;
  let remaining = Math.min(dt, 0.1); // never simulate more than 100ms per frame
  while (remaining > 0 && w.status === 'playing') {
    const s = Math.min(h, remaining);
    substep(w, s);
    w.time += s;
    remaining -= s;
  }
  return w;
}
