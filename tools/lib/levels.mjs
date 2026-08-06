// src/levels.gd is the single source of truth for the rooms. The verification
// tooling is JavaScript, because that is where the solver's search lives (see
// tools/reference/), so it reads the GDScript rather than keeping a second copy
// of forty maps that could drift.
import { readFileSync, writeFileSync } from 'node:fs';

export const GRID = 13;
export const TIERS = ['easy', 'medium', 'hard', 'insane'];
export const TIER_SIZE = 10;
export const LEVEL_COUNT = TIERS.length * TIER_SIZE;
export const tierOf = (index) => TIERS[Math.floor(index / TIER_SIZE)];

const LEVELS_GD = new URL('../../src/levels.gd', import.meta.url);
const ENTRY = /\{"name": "([^"]+)", "par": (\d+), "map": \[([\s\S]*?)\]\}/g;

export function loadLevels() {
  const src = readFileSync(LEVELS_GD, 'utf8');
  const levels = [...src.matchAll(ENTRY)].map((m) => ({
    name: m[1],
    par: Number(m[2]),
    map: [...m[3].matchAll(/"([^"]*)"/g)].map((row) => row[1]),
  }));
  if (!levels.length) throw new Error('parsed no rooms from src/levels.gd — has the format changed?');
  return levels;
}

/**
 * The same authoring checks src/levels.gd runs at startup, so a slip is caught
 * by the verifier too rather than only at runtime. Returns a list of problems.
 */
export function validateLevels(levels) {
  const problems = [];
  if (levels.length !== LEVEL_COUNT) {
    problems.push(`${levels.length} rooms, but the tier structure declares ${LEVEL_COUNT}`);
  }
  levels.forEach((lvl, i) => {
    const where = `level ${i + 1} ("${lvl.name}")`;
    if (lvl.map.length !== GRID) {
      problems.push(`${where}: ${lvl.map.length} rows, expected ${GRID}`);
      return;
    }
    lvl.map.forEach((row, r) => {
      if (row.length !== GRID) problems.push(`${where} row ${r}: ${row.length} cols, expected ${GRID}`);
    });
    const flat = lvl.map.join('');
    const count = (ch) => flat.split(ch).length - 1;
    if (count('O') !== 1) problems.push(`${where}: needs exactly 1 orb spawn, found ${count('O')}`);
    if (count('E') < 1) problems.push(`${where}: needs an exit`);
    for (const [btn, door] of [['1', 'a'], ['2', 'b'], ['3', 'c']]) {
      if (count(door) > 0 && count(btn) === 0) problems.push(`${where}: door '${door}' has no button '${btn}'`);
      if (count(btn) > 0 && count(door) === 0) problems.push(`${where}: button '${btn}' opens no door '${door}'`);
      if (count(btn) > 1) problems.push(`${where}: duplicate button '${btn}'`);
    }
    for (const ch of flat) {
      if (!'#.OE^IT123abc'.includes(ch)) {
        problems.push(`${where}: unknown tile '${ch}'`);
        break;
      }
    }
  });
  return problems;
}

/**
 * Rewrite `par` in src/levels.gd for the given rooms. `par` should describe the
 * route the solver actually found, not a guess made while authoring — in the
 * original project a hand-guessed par was wrong on 19 of 40 rooms.
 */
export function writePar(fixes) {
  let src = readFileSync(LEVELS_GD, 'utf8');
  const missed = [];
  for (const { name, to } of fixes) {
    const re = new RegExp(`(\\{"name": "${name}", "par": )\\d+`);
    if (!re.test(src)) {
      missed.push(name);
      continue;
    }
    src = src.replace(re, `$1${to}`);
  }
  writeFileSync(LEVELS_GD, src);
  return missed;
}
