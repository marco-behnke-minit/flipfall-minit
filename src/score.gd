class_name Score
extends RefCounted
## Scoring, kept pure so it can be reasoned about (and tested) on its own.
##
##   +1000  per room cleared
##   +500   per Attempt still in hand when the run ends
##   -5     per gravity rotation (winning attempt only — a reset wipes the slate,
##          the lost Attempt is the penalty)
##   +time  max(0, 200 - seconds * 10) per room, timed from the first rotation


static func time_bonus(seconds: float) -> int:
	return int(max(0.0, round(Const.TIME_BONUS_BASE - seconds * Const.TIME_BONUS_DECAY)))


## Points banked for clearing one room.
static func level_score(rotations: int, seconds: float) -> int:
	return maxi(0, Const.PTS_PER_LEVEL + time_bonus(seconds) + rotations * Const.PTS_PER_ROTATION)


## Final total: everything banked, plus the unspent Attempts.
static func final_score(banked_points: int, attempts_left: int) -> int:
	return maxi(0, banked_points + maxi(0, attempts_left) * Const.PTS_PER_ATTEMPT)


static func empty_stats() -> Dictionary:
	return {
		"spike_deaths": 0,
		"out_deaths": 0,
		"retries": 0,
		"fastest": {},   # { name, seconds }
		"messiest": {},  # { name, rotations }
		"par_clears": 0,
	}


## One memorable moment from the session for the host's result screen and
## activity feed — never the score itself, and never rendered in-game.
static func flavor_text(stats: Dictionary, levels_cleared: int, total_levels: int) -> String:
	var spikes: int = stats["spike_deaths"]
	var outs: int = stats["out_deaths"]
	var fails := spikes + outs
	var c: Array = []

	if fails == 0 and levels_cleared == total_levels:
		c.append([10, "All %d rooms, never touched a spike" % total_levels])
	if spikes >= 2:
		c.append([9, "Impaled %d times" % spikes])
	if outs >= 2:
		c.append([9, "Fell out of the room %d times" % outs])
	if spikes == 1 and outs == 1:
		c.append([8, "One spike, one long fall"])
	var messiest: Dictionary = stats["messiest"]
	if not messiest.is_empty() and int(messiest["rotations"]) >= 12:
		c.append([7, "Spun gravity %d times on %s" % [messiest["rotations"], messiest["name"]]])
	if int(stats["retries"]) >= 2:
		c.append([6, "Gave up and reset %d times" % stats["retries"]])
	if int(stats["par_clears"]) >= 6:
		c.append([5, "Hit par on %d rooms" % stats["par_clears"]])
	if spikes == 1:
		c.append([4, "Died on the spikes once"])
	if outs == 1:
		c.append([4, "Slipped out of the room once"])
	var fastest: Dictionary = stats["fastest"]
	if not fastest.is_empty():
		c.append([3, "%s cracked in %.1fs" % [fastest["name"], fastest["seconds"]]])
	if levels_cleared == 0:
		c.append([2, "Never solved the first room"])
	if c.is_empty():
		c.append([1, "Stopped at room %d" % (levels_cleared + 1)])

	c.sort_custom(func(a, b): return a[0] > b[0])
	return c[0][1]


## Fold one cleared room into the running stats.
static func record_clear(stats: Dictionary, level: Dictionary, rotations: int, seconds: float) -> void:
	if rotations <= int(level["par"]):
		stats["par_clears"] = int(stats["par_clears"]) + 1
	var fastest: Dictionary = stats["fastest"]
	if fastest.is_empty() or seconds < float(fastest["seconds"]):
		stats["fastest"] = {"name": level["name"], "seconds": seconds}
	var messiest: Dictionary = stats["messiest"]
	if messiest.is_empty() or rotations > int(messiest["rotations"]):
		stats["messiest"] = {"name": level["name"], "rotations": rotations}
