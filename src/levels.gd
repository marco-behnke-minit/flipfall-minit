class_name Levels
extends RefCounted
## Handcrafted 13x13 rooms. One screen, one puzzle, no scrolling.
##
##   #  wall            .  air              O  orb spawn        E  exit
##   ^  spike           I  ice (slippery)   T  sticky (grippy)
##   1  2  3  button    a  b  c  door opened by button 1 / 2 / 3
##
## `par` is the shortest solution the solver could find. It is informational
## only — there is no rotation cap.
##
## ORDER MATTERS. Rooms are grouped into blocks by the newest mechanic each one
## asks for, in the order a player meets them, and ramp up inside each block. The
## felt difficulty is a sawtooth — introduce, push, master, reset — and only the
## rise is authored; the fall happens in the player. tools/curve.mjs produces it.
##
## Every room here earns its place on two measured tests, applied by
## tools/triage.mjs: deleting its hazards changes the solution, and its geometry
## is not a copy of an earlier room's. Eighteen rooms that failed both were cut —
## fifteen had a skeleton identical to a room already played, wearing spikes the
## route never went near.

const ALL := [
	{"name": "Teeth", "par": 3, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#.^^^^^^^^^^#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#############",
	]},
	{"name": "Trapdoor", "par": 2, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#...........#",
		"#.....1.....#",
		"#IIIIIaaIIII#",
		"#...........#",
		"#...........#",
		"#^^^^^.E....#",
		"#############",
	]},
	{"name": "Well", "par": 4, "map": [
		"#############",
		"#O..........#",
		"#IIIII.IIII^#",
		"######.######",
		"######.######",
		"######.######",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#E..........#",
		"#...........#",
		"#############",
	]},
	{"name": "Skim", "par": 4, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#IIIII.II^^^#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#.....E.....#",
		"#############",
	]},
	{"name": "Skate", "par": 4, "map": [
		"#############",
		"#..........E#",
		"#^^^^^^^^^^.#",
		"#...........#",
		"#...........#",
		"###########.#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........^#",
		"#IIIIIIIIIII#",
		"#############",
	]},
	# The answer to "the purple traps are harmless": they are, and this is why.
	#
	# Gravity parallel to a surface never presses the orb into it, so flying past
	# sticky costs nothing — the same reason ice underfoot changes nothing when you
	# are airborne. Sticky only bites on the flip that drives you INTO it.
	#
	# So the room is a run, not a fall. Flip right and the orb accelerates freely
	# down the corridor; the gap in the floor is too far to coast to, and at full
	# speed the orb skims straight over it like a wheel over a pothole. The only way
	# in is to flip down EARLY and bleed off exactly enough speed to arrive slow
	# enough to drop. Too early and you settle in the tar; too late and the spikes
	# at the end have you.
	#
	#   flip down after   375-670ms   295ms wide, 118 of 241 timings lethal
	#
	# NOTE: this room was built when sticky braked at k=30 and the mechanic WAS the
	# braking. Tar now grips like stone, so what carries it is the hold rather than
	# the friction — stopping short no longer parks you, it kills you. The window
	# widened from 165ms to 295ms in the change, which makes it the gentlest of the
	# three tar rooms rather than the harshest.
	#
	# NOTE ON "one is top and one is bottom": measured, and it does not hold. Only
	# the face you flip into ever does anything — a sticky ceiling here gives the
	# identical 180ms window as stone or ice. Lining both faces would be the same
	# decorative purple, just relocated, so the ceiling is stone.
	#
	# Under the tar rule both failures now kill: stop short and you settle on the
	# sticky and are held until it takes you, overshoot and the spikes do. The
	# spawn tile is stone on purpose — sticky there killed the player for thinking.
	#
	# It also ends the creep here. Walking the orb along the sticky means resting
	# on it, and resting on it is fatal, so the cheap route is simply gone.
	{"name": "Pothole", "par": 3, "map": [
		"#############",
		"#############",
		"#O........^^#",
		"##TT....TTTT#",
		"####....#####",
		"####....#####",
		"####....#####",
		"####...E#####",
		"#############",
		"#############",
		"#############",
		"#############",
		"#############",
	]},

	# Rebuilt. The old Grip put its tar in the bottom floor at cols 5-7 and then
	# routed you up and away from it — playtested as "no use of that tile, you take
	# a different path to solve anyways", and the counterfactual agreed: swapping it
	# for stone left the room identical.
	#
	# Here the tar IS the floor, and the exit is at the far end of it. There is no
	# path that avoids it: land, slide, and be off before the 250ms runs out. The
	# winning line rides the tar for up to 246ms of the allowance, and 69% of
	# sampled timings die — held by the tar, or impaled if you overrun.
	#
	# The spawn tile is stone. Tar there would kill the player for thinking.
	{"name": "Grip", "par": 4, "map": [
		"#############",
		"#############",
		"#############",
		"#O.........^#",
		"##.........##",
		"#...........#",
		"#TTTTTTTTTTE#",
		"#############",
		"#############",
		"#############",
		"#############",
		"#############",
		"#############",
	]},
	# Rebuilt, for the reason a screenshot made obvious: the old Anchor put tar in
	# the floor and then let you fly over it. Gravity along the direction of travel
	# never presses the orb into anything, so the winning line passed the tar
	# tangentially — 0ms of contact, closest approach exactly one orb radius — and
	# "there is no way the trap is a danger to you" was simply correct.
	#
	# The rule that follows: you can fly past any surface, so tar only threatens
	# when the OBJECTIVE sits on it. Here the button is one row below the spawn
	# ledge, so flying straight across cannot reach it. The only way to press it is
	# to land on the tar, and then you have 250ms to leave — dawdle 300ms and it
	# takes you. Swapped for stone the room solves at a 75ms window instead of 50ms.
	{"name": "Anchor", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###aaaaa#####",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"##.........1#",
		"##TTTTTTTTTT#",
		"#############",
		"#############",
	]},
	# Promoted from src/prototypes.gd, where it playtested as "amazing". It replaces
	# Hairline, whose single sticky cell and ice floor both failed the counterfactual
	# — the room solved identically with either swapped for stone.
	#
	# Three lanes, and the outer two are sealed alternately, so both routes exist:
	# ride a wall and switch before each block, or hold the middle channel and touch
	# nothing at all. The middle is a 16.8px band — the entire geometric slack of a
	# 44px orb in a 60px channel.
	#
	# The blocks are stone on purpose. Built from sticky the room solves in the same
	# 4 rotations at the same 300ms window, because you avoid them and so never
	# slide on them; the material of a block you dodge cannot matter. A spike leads
	# each block so riding into a sealed lane kills rather than parks you, and that
	# is what removed the rest-only route.
	{"name": "Slalom", "par": 4, "map": [
		"#############",
		"#############",
		"#############",
		"#############",
		"#############",
		"#..^##......#",
		"#O.........E#",
		"#.....^##...#",
		"#############",
		"#############",
		"#############",
		"#############",
		"#############",
	]},
	{"name": "Overhead", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#####aa######",
		"#^^^^..^^^^^#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	{"name": "Eyelet", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"######a######",
		"#^^^^^.^^^^^#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
]


## Sanity-check every level's shape and contents. Pushes an error on an
## authoring slip and returns false, so a bad edit is loud rather than silent.
##
## Takes a room set, because src/prototypes.gd holds scratch rooms that get the
## same authoring checks without having to fill the tier structure.
static func validate(rooms: Array = ALL, expect_full_set: bool = true) -> bool:
	var ok := true
	if expect_full_set and rooms.size() != Const.LEVEL_COUNT:
		push_error("%d rooms, but the tier structure declares %d" % [rooms.size(), Const.LEVEL_COUNT])
		ok = false

	for i in rooms.size():
		var lvl: Dictionary = rooms[i]
		var where := "level %d (\"%s\")" % [i + 1, lvl["name"]]
		var rows: Array = lvl["map"]
		if rows.size() != Const.GRID:
			push_error("%s: %d rows, expected %d" % [where, rows.size(), Const.GRID])
			ok = false
			continue
		for r in rows.size():
			if String(rows[r]).length() != Const.GRID:
				push_error("%s row %d: %d cols, expected %d" % [where, r, String(rows[r]).length(), Const.GRID])
				ok = false

		var flat := "".join(PackedStringArray(rows))
		if _count(flat, "O") != 1:
			push_error("%s: needs exactly 1 orb spawn, found %d" % [where, _count(flat, "O")])
			ok = false
		if _count(flat, "E") < 1:
			push_error("%s: needs an exit" % where)
			ok = false
		for pair in [["1", "a"], ["2", "b"], ["3", "c"]]:
			var btn: String = pair[0]
			var door: String = pair[1]
			if _count(flat, door) > 0 and _count(flat, btn) == 0:
				push_error("%s: door '%s' has no button '%s'" % [where, door, btn])
				ok = false
			if _count(flat, btn) > 0 and _count(flat, door) == 0:
				push_error("%s: button '%s' opens no door '%s'" % [where, btn, door])
				ok = false
			if _count(flat, btn) > 1:
				push_error("%s: duplicate button '%s'" % [where, btn])
				ok = false
		for ch in flat:
			if not "#.OE^IT123abc".contains(ch):
				push_error("%s: unknown tile '%s'" % [where, ch])
				ok = false
				break
	return ok


static func _count(haystack: String, needle: String) -> int:
	return haystack.count(needle)
