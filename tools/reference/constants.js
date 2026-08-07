// ---------------------------------------------------------------------------
// Design surface. Everything in the game is authored against these numbers and
// nothing is ever derived from the live viewport. The wrapper's uniform scale
// (see scale.js) is the only place innerWidth / innerHeight are read.
// ---------------------------------------------------------------------------
export const DESIGN_W = 960;
export const DESIGN_H = 1480;

// Safe area: gameplay-critical elements stay inside the central 90%.
export const SAFE_INSET = 0.05;
export const SAFE_L = DESIGN_W * SAFE_INSET; //  48
export const SAFE_R = DESIGN_W * (1 - SAFE_INSET); // 912
export const SAFE_T = DESIGN_H * SAFE_INSET; //  74
export const SAFE_B = DESIGN_H * (1 - SAFE_INSET); // 1406

// Playfield: one screen, one puzzle. Square so gravity rotation is symmetric.
export const GRID = 13;
export const CELL = 60;
export const PF_SIZE = GRID * CELL; // 780
export const PF_X = (DESIGN_W - PF_SIZE) / 2; //  90
export const PF_Y = 215;

// Controls.
export const ROT_R = 118;
export const ROT_CCW = { x: 250, y: 1130 };
export const ROT_CW = { x: 710, y: 1130 };
export const PILL = { x: 480, y: 1330, w: 320, h: 120 };

// Gravity compass lives in the dead centre of the SDK header bar.
export const COMPASS = { x: 480, y: 115, r: 52 };
export const HUD_Y = 60;
export const HUD_PAD = 75;

// Orb / simulation. Tuned so a full-width traverse takes about a second: fast
// enough to feel momentum, slow enough that mid-flight rotations are a fair ask
// on a touch screen rather than a frame-perfect input.
export const ORB_R = 22;
export const GRAVITY = 1100; // px/s^2
export const MAX_SPEED = 900; // px/s
export const REST_SPEED = 14; // px/s, below this while touching = at rest
export const SUBSTEP = 1 / 240;

// Run rules.
export const ATTEMPTS = 3;
export const ATTEMPTS_MIN = 1;
export const ATTEMPTS_MAX = 9;

// Rooms per difficulty tier. The room list is exactly TIERS.length * TIER_SIZE
// long, and src/levels.js asserts it.
export const TIERS = ['easy', 'medium', 'hard', 'insane'];
export const TIER_SIZE = 10;
export const LEVEL_COUNT = TIERS.length * TIER_SIZE;
export const tierOf = (index) => TIERS[Math.floor(index / TIER_SIZE)];

// ---------------------------------------------------------------------------
// Host-settable config. This is the single source of truth: main.js reads
// values through it, and tools/zip.js fails the build if it and the `config`
// block in public/meta.json ever disagree on a key, type, default or bound.
// ---------------------------------------------------------------------------
export const CONFIG = [
  {
    key: 'attempts',
    valueType: 'number',
    value: ATTEMPTS,
    min: ATTEMPTS_MIN,
    max: ATTEMPTS_MAX,
  },
  // startLevel / endLevel select the segment of the room list a drop plays,
  // which is how difficulty is published: 1-10 easy, 11-20 medium, 21-30 hard,
  // 31-40 insane. Locked against mods so a mod cannot swap the room set out
  // from under a score.
  {
    key: 'startLevel',
    valueType: 'number',
    value: 1,
    min: 1,
    max: LEVEL_COUNT,
  },
  {
    key: 'endLevel',
    valueType: 'number',
    value: 10,
    min: 1,
    max: LEVEL_COUNT,
  },
];

export const configSpec = (key) => {
  const spec = CONFIG.find((c) => c.key === key);
  if (!spec) throw new Error(`undeclared config key "${key}"`);
  return spec;
};
export const PTS_PER_LEVEL = 1000;
export const PTS_PER_ATTEMPT = 500;
export const PTS_PER_ROTATION_UNDER_PAR = 40;
export const PTS_PER_ROTATION_OVER_PAR = 25;
export const PTS_PER_DEATH = -150;
export const TIME_BONUS_BASE = 200;
export const TIME_BONUS_DECAY = 10; // points lost per second

export const COLORS = {
  bg: '#1E1F26',
  pit: '#16171C',
  floor: '#ECECEC',
  wall: '#4A5568',
  wallLip: '#5D6B7E',
  orb: '#34D1FF',
  exit: '#22C55E',
  button: '#FBBF24',
  door: '#6366F1',
  spike: '#EF4444',
  ice: '#C7F2FF',
  sticky: '#7C3AED',
  hud: '#FFFFFF',
  dim: '#6B7280',
};
