class_name Levels
extends RefCounted
## Forty handcrafted 13x13 rooms. One screen, one puzzle, no scrolling.
##
##   #  wall            .  air              O  orb spawn        E  exit
##   ^  spike           I  ice (slippery)   T  sticky (grippy)
##   1  2  3  button    a  b  c  door opened by button 1 / 2 / 3
##
## `par` is the shortest solution the solver could find. It is informational
## only — there is no rotation cap.
##
## ORDER MATTERS. Rooms are sorted by measured difficulty, ascending, and the
## tiers are the four tenths of that order — so a drop that publishes a segment
## gets a band that actually rises as it is played. The ranking comes from
## tools/difficulty.mjs, which scores three independent axes: route length,
## whether a timing window is required at all, and how lethal the room is. `par`
## alone measures only the first, which is how the tiers came to overlap so badly
## that an easy room outranked a hard one. The single departure from a pure sort
## is that the cheapest room introducing each element is pinned into the easy
## tier, because easy is also the teaching tier and the default published drop.

const ALL := [
	# ====================== EASY (1-10) ================================
	# Introduces one element at a time — doors, ice, spikes, sticky — and stays
	# rest-only solvable apart from the finale, which is where timing first
	# matters. This is the default published segment.
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
	{"name": "Glide", "par": 4, "map": [
		"#############",
		"#...........#",
		"#.........#.#",
		"#.........#E#",
		"#.........#.#",
		"#.........#.#",
		"#.........###",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#IIIIIIIIIII#",
		"#############",
	]},
	# Open right edge: send the orb that way and it leaves the room.
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
	# Same climb, but the floor is ice — every leg arrives at speed.
	{"name": "Rink", "par": 5, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#b###########",
		"#2..........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#IIIIIIIIIII#",
		"#############",
	]},
	# One safe column through the spikes, and it is not the one the button is on.
	{"name": "Needle", "par": 4, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#.^^^^^^^^^^#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	# Doors alternate ends, buttons alternate against them.
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
	# Sticky teach. Gravity parallel to a floor never presses the orb into it,
	# so the sticky patch only bites once the player flips gravity down onto
	# it — landing there kills the orb's momentum dead, under the ceiling gap.
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

	# ===================== MEDIUM (11-20) ==============================
	# Longer routes on the same elements. Still almost entirely rest-only: what
	# grows is the number of crossings you have to plan, not the precision.
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
	# Ice floor, a spike ceiling with two safe columns, and a door chain that uses
	# both of them.
	{"name": "Gauntlet", "par": 5, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#b###########",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"###########a#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O.........1#",
		"#IIIIIIIIIII#",
		"#############",
	]},
	# Ice below, spikes above, one safe column between them.
	{"name": "Slalom", "par": 5, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"#b###########",
		"#2..........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#^^^^^^^^^^.#",
		"#...........#",
		"#O.........1#",
		"#IIIIIIIIIII#",
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
	# Buttons share their door column, so the climb is direct — but the chamber
	# floors bite.
	{"name": "Shortcut", "par": 4, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#3..........#",
		"#.^^^^^^^^^.#",
		"#b###########",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"#a###########",
		"#...........#",
		"#O1.........#",
		"#############",
	]},
	# Doors and buttons sit at wall ends, because a wall end is the only place the
	# orb can reliably come to rest and therefore act without a timing window.
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
	# Every button is at the far end from the door it opens, so each chamber
	# has to be crossed twice.
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
	# Ice either side of the sticky landing zone: overshoot the patch and the
	# orb skids the rest of the room instead of stopping.
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
	# The right wall is missing below every ledge.
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
	# Both doors on the left, both buttons on the right.
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

	# ====================== HARD (21-30) ===============================
	# Where execution starts to matter: half of these need a timing window, and
	# the hazards stop being decoration and become route constraints.
	# Doors alternate, buttons follow them, spikes underfoot.
	{"name": "Cascade", "par": 6, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#..........3#",
		"#.^^^^^^^^^.#",
		"#b###########",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"###########a#",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	# Everything at once: fetch the button at the far wall, skate back across
	# the ice, brake on the sticky, then rise through the only spike-free
	# columns — which are exactly the ones the sticky can stop you on.
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
	# The Ladder, with a spike floor waiting under the third chamber.
	{"name": "Rungs", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#3..........#",
		"#^^^^^^^^^^.#",
		"###########b#",
		"#..........2#",
		"#...........#",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	# Two doors left, one right, and a hole in the left wall.
	{"name": "Crucible", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^.#",
		"#b###########",
		"#..........2#",
		"............#",
		"###########a#",
		"#...........#",
		"#O1.........#",
		"#############",
	]},
	# Fetch the button, skate back, and brake on the pad under the doors.
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
	# Alternating doors, alternating holes, ice underneath.
	{"name": "Freefall", "par": 6, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		"..^^^^^^^^^.#",
		"#b###########",
		"#..........2#",
		"#.^^^^^^^^^..",
		"###########a#",
		"............#",
		"#O1.........#",
		"IIIIIIIIIIIII",
	]},
	# Teeth in two chambers and an open corner below the last ledge.
	{"name": "Forge", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^.#",
		"###########b#",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"###########a#",
		"#............",
		"#O1.........#",
		"#############",
	]},
	# One cell of grip in the whole room. Land on it or skate past.
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
	# Maximum crossings, teeth below two of them, and a chamber open both sides.
	{"name": "Meatgrinder", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^.#",
		"###########b#",
		"#2..........#",
		"..^^^^^^^^^..",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	# Everything: ice run in, two-cell brake, and the only spike-free columns
	# are exactly the two the doors sit above.
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

	# ===================== INSANE (31-40) ==============================
	# Everything at once — the longest chains, the most lethal rooms, and the
	# narrowest brake pads. Ordered so the hardest room in the game is last.
	# Every button sits opposite its door, so each chamber is crossed twice — the
	# longest rest-only route in the game.
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
	# Brake pad flanked by ice, with both walls missing at the pad's height.
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
	# A two-cell brake pad, and the doors above it are the only way up.
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
	# Ice underfoot, teeth above it, and the long way round every chamber.
	{"name": "Maelstrom", "par": 8, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^..",
		"###########b#",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"#a###########",
		"............#",
		"#O.........1#",
		"IIIIIIIIIIIII",
	]},
	# All doors right, all buttons left, and the floor is ice.
	{"name": "Glacier", "par": 10, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		"#...........#",
		"###########b#",
		"#2..........#",
		"#...........#",
		"###########a#",
		"#...........#",
		"#O1.........#",
		"IIIIIIIIIIIII",
	]},
	# Ice floor and a spiked middle chamber; no two doors alike.
	{"name": "Whiteout", "par": 10, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		"#...........#",
		"#b###########",
		"#..........2#",
		"#.^^^^^^^^^.#",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"IIIIIIIIIIIII",
	]},
	# Ice, and a chamber with nothing holding the orb in on either side.
	{"name": "Abyss", "par": 10, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		".............",
		"###########b#",
		"#2..........#",
		"#.^^^^^^^^^.#",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"IIIIIIIIIIIII",
	]},
	# Ice, teeth, three holes, and no two doors alike.
	{"name": "Singularity", "par": 10, "map": [
		"#############",
		"#..........E#",
		"#...........#",
		"###########c#",
		"#3..........#",
		"..^^^^^^^^^.#",
		"#b###########",
		"#..........2#",
		"#.^^^^^^^^^..",
		"#a###########",
		"............#",
		"#O.........1#",
		"IIIIIIIIIIIII",
	]},
	# Spire, with teeth and a missing right wall under two of the ledges.
	{"name": "Razor", "par": 12, "map": [
		"#############",
		"#E..........#",
		"#...........#",
		"#c###########",
		"#..........3#",
		"#.^^^^^^^^^..",
		"#b###########",
		"#..........2#",
		"#.^^^^^^^^^..",
		"#a###########",
		"#...........#",
		"#O.........1#",
		"#############",
	]},
	# Spiked floors in all three lower chambers: cross high or die.
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
