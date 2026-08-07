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
	{"name": "Anchor", "par": 4, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###aaaaa#####",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#####TTT#####",
		"#############",
	]},
	{"name": "Hairline", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"######a######",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#IIIIITIIIII#",
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
