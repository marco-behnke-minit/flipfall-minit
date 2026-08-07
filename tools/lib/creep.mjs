// Can a room be finished by creeping?
//
// Alternating gravity walks the orb along any surface without timing, so a
// player can park it at rest anywhere on a floor, and from rest a single flip is
// a straight line. This parks the orb at every resting spot, with buttons
// already pressed since the creep reaches them all anyway, and tries every one-
// and two-flip continuation.
//
// It is used two ways: as a design warning (tools/creep-check.mjs), and by
// tools/solve.mjs as the real shippability gate — a room a player can always
// walk home from cannot strand them, whatever its timing window looks like.
import { createWorld, stepWorld, rotate } from '../reference/physics.js';
import { SUBSTEP, CELL, GRID } from '../reference/constants.js';

const WAITS = [0.15, 0.3, 0.5, 0.8, 1.2, 1.8, 2.5];

function advance(w, seconds) {
  for (let t = 0; t < seconds && w.status === 'playing'; t += 1 / 240) stepWorld(w, 1 / 240, SUBSTEP);
}

/** A world with the orb parked at rest at (col, row), buttons already pressed. */
function parked(level, col, row) {
  const w = createWorld(level);
  for (const b of ['1', '2', '3']) {
    if (level.map.join('').includes(b)) {
      w.buttons.add(b);
      w.doorsOpen.add(String.fromCharCode(b.charCodeAt(0) - 48 + 96));
    }
  }
  w.orb.x = col * CELL + CELL / 2;
  w.orb.y = row * CELL + CELL / 2;
  w.orb.vx = 0;
  w.orb.vy = 0;
  return w;
}

/** Every cell the orb could be parked in: open, with something solid beneath. */
function restSpots(level) {
  const solid = (c, r) => {
    if (c < 0 || r < 0 || c >= GRID || r >= GRID) return true;
    const ch = level.map[r][c];
    return ch === '#' || ch === 'I' || ch === 'T';   // doors are open in this check
  };
  const spots = [];
  for (let r = 0; r < GRID; r++) {
    for (let c = 0; c < GRID; c++) {
      const ch = level.map[r][c];
      if (ch === '#' || ch === 'I' || ch === 'T' || ch === '^') continue;
      if (solid(c, r + 1) || solid(c, r - 1) || solid(c - 1, r) || solid(c + 1, r)) spots.push([c, r]);
    }
  }
  return spots;
}

export function creepable(level) {
  for (const [c, r] of restSpots(level)) {
    for (const d1 of [1, -1]) {
      // One flip, straight line.
      let w = parked(level, c, r);
      rotate(w, d1);
      advance(w, 4);
      if (w.status === 'clear') return { how: `park (${c},${r}) then one flip`, };
      // Two flips, with a wait between — a curve, but launched from rest.
      for (const wait of WAITS) {
        for (const d2 of [1, -1]) {
          w = parked(level, c, r);
          rotate(w, d1);
          advance(w, wait);
          if (w.status !== 'playing') continue;
          rotate(w, d2);
          advance(w, 4);
          if (w.status === 'clear') {
            return { how: `park (${c},${r}), flip, wait ${(wait * 1000).toFixed(0)}ms, flip` };
          }
        }
      }
    }
  }
  return null;
}

