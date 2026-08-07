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
	# ===== ROTATE — the one control, and nothing else to think about
	{"name": "Roll", "par": 1, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O........E.#",
		"#############",
	]},

	# ===== DOORS — routing. Longer chains, but nothing can kill you yet
	{"name": "Press", "par": 3, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#...........#",
		"#O........1.#",
		"#############",
	]},
	{"name": "Ledge", "par": 4, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#a###########",
		"#1..........#",
		"#...........#",
		"#######......",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#############",
	]},
	{"name": "Climb", "par": 5, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#...........#",
		"#b###########",
		"#2..........#",
		"#...........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#...........#",
		"#O........1.#",
		"#############",
	]},
	{"name": "Zigzag", "par": 6, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		"#...........#",
		"#b###########",
		"#..........2#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#O1.........#",
		"#############",
	]},
	{"name": "Detour", "par": 7, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#...........#",
		"#b###########",
		"#.2.........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.......1..#",
		"#############",
	]},
	{"name": "Ladder", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#3..........#",
		"#...........#",
		"###########b#",
		"#..........2#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	{"name": "Errand", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#b###########",
		"#..........2#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	{"name": "Relay", "par": 9, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#b###########",
		"#..........2#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	{"name": "Spire", "par": 12, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#...........#",
		"#b###########",
		"#..........2#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"#############",
	]},

	# ===== SPIKES — the first way to die
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
	{"name": "Vault", "par": 12, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^.#",
		"###########b#",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"#a###########",
		"#...........#",
		"#O^^^^^^^^^1#",
		"#############",
	]},

	# ===== ICE — almost no grip, so momentum has to be planned
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

	# ===== STICKY — the only way to stop somewhere exact
	{"name": "Grip", "par": 3, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###.....#####",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#####TTT#####",
		"#############",
	]},
	{"name": "Brake", "par": 3, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###.....#####",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#IITTTTTIIII#",
		"#############",
	]},
	{"name": "Anchor", "par": 5, "map": [
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
	{"name": "Scalpel", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"####aa#######",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"............#",
		"#O.........1#",
		"#IIITTIIIIII#",
		"#############",
	]},
	{"name": "Flipfall", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"###aaaaa#####",
		"#1..........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#.......^^^^#",
		"#O..........#",
		"#IITTTTTIIII#",
		"#############",
	]},
	{"name": "Eventide", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"######aa#####",
		"#...........#",
		"#.^^^^..^^^.#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#IIIIITTIIII#",
		"#############",
	]},
	{"name": "Needlepoint", "par": 5, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#####aa######",
		"#...........#",
		"#.^^^^^^^^^.#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#####TT######",
		"#############",
	]},

	# ===== OPEN EDGES — the room stops holding you in
	{"name": "Precipice", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#3..........#",
		"#............",
		"###########b#",
		"#..........2#",
		"#............",
		"#a###########",
		"#............",
		"#O1.........#",
		"#############",
	]},

	# ===== CEILING SPIKES — the flip up is no longer free
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
