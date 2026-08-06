// ---------------------------------------------------------------------------
// Scoring, kept pure so tools/run-sim.js can verify a whole run under Node.
//
//   +1000  per room cleared
//   +500   per Attempt still in hand when the run ends
//   -5     per gravity rotation (winning attempt only — a reset wipes the slate,
//          the lost Attempt is the penalty)
//   +time  max(0, 200 - seconds * 10) per room, timed from the first rotation
// ---------------------------------------------------------------------------
import {
  PTS_PER_LEVEL, PTS_PER_ATTEMPT, PTS_PER_ROTATION,
  TIME_BONUS_BASE, TIME_BONUS_DECAY,
} from './constants.js';

export function timeBonus(seconds) {
  return Math.max(0, Math.round(TIME_BONUS_BASE - seconds * TIME_BONUS_DECAY));
}

/** Points banked for clearing one room. */
export function levelScore(rotations, seconds) {
  return Math.max(0, PTS_PER_LEVEL + timeBonus(seconds) + rotations * PTS_PER_ROTATION);
}

/** Final total: everything banked, plus the unspent Attempts. */
export function finalScore(bankedPoints, attemptsLeft) {
  return Math.max(0, bankedPoints + Math.max(0, attemptsLeft) * PTS_PER_ATTEMPT);
}

export function emptyStats() {
  return {
    spikeDeaths: 0,
    outDeaths: 0,
    retries: 0,
    fastest: null, // { name, seconds }
    messiest: null, // { name, rotations }
    parClears: 0,
  };
}

/**
 * One memorable moment from the session for the host's result screen and
 * activity feed — never the score itself, and never rendered in-game.
 */
export function flavorText(stats, levelsCleared, totalLevels) {
  const fails = stats.spikeDeaths + stats.outDeaths;
  const c = [];
  if (fails === 0 && levelsCleared === totalLevels) {
    c.push([10, `All ${totalLevels} rooms, never touched a spike`]);
  }
  if (stats.spikeDeaths >= 2) c.push([9, `Impaled ${stats.spikeDeaths} times`]);
  if (stats.outDeaths >= 2) c.push([9, `Fell out of the room ${stats.outDeaths} times`]);
  if (stats.spikeDeaths === 1 && stats.outDeaths === 1) c.push([8, 'One spike, one long fall']);
  if (stats.messiest && stats.messiest.rotations >= 12) {
    c.push([7, `Spun gravity ${stats.messiest.rotations} times on ${stats.messiest.name}`]);
  }
  if (stats.retries >= 2) c.push([6, `Gave up and reset ${stats.retries} times`]);
  if (stats.parClears >= 6) c.push([5, `Hit par on ${stats.parClears} rooms`]);
  if (stats.spikeDeaths === 1) c.push([4, 'Died on the spikes once']);
  if (stats.outDeaths === 1) c.push([4, 'Slipped out of the room once']);
  if (stats.fastest) c.push([3, `${stats.fastest.name} cracked in ${stats.fastest.seconds.toFixed(1)}s`]);
  if (levelsCleared === 0) c.push([2, 'Never solved the first room']);
  if (!c.length) c.push([1, `Stopped at room ${levelsCleared + 1}`]);
  c.sort((a, b) => b[0] - a[0]);
  return c[0][1];
}

/** Fold one cleared room into the running stats. */
export function recordClear(stats, level, rotations, seconds) {
  if (rotations <= level.par) stats.parClears++;
  if (!stats.fastest || seconds < stats.fastest.seconds) {
    stats.fastest = { name: level.name, seconds };
  }
  if (!stats.messiest || rotations > stats.messiest.rotations) {
    stats.messiest = { name: level.name, rotations };
  }
  return stats;
}
