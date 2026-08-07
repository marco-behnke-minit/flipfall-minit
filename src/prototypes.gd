class_name Prototypes
extends RefCounted
## Scratch rooms for design work. NOT shipped — src/levels.gd is the game.
##
##     godot --path . -- --rooms=prototypes --attempts=9
##
## This file is the source of truth for them: tools/prototypes.mjs reads these
## maps rather than keeping its own copy, so what is measured is what is played.
##
## They exist because the shipped set has no difficulty in it — 32 of its 40
## rooms are rest-only solvable, so the orb can be left to settle before every
## flip and nothing can be failed through execution.
##
## THE CREEP, which is the finding that matters most.
##
## Alternating gravity left/right/left walks the orb along a surface a fraction
## of a cell at a time, with no timing required at all — flip, flip back, repeat
## until it is where you want it. Measured on a flat floor: about 0.9 cells per
## flip-pair on ice at a 100ms half-period, and 0.6 on stone, both controllable
## by how long you hold each flip.
##
## So it is NOT an ice problem. Any room whose challenge is "get the orb to a
## particular spot on a surface" is defeated by it, and every shipped room is
## exactly that. It is also invisible to the solver: search.js caps at
## MAX_ROTATIONS = 12, and a creep spends far more than twelve, so the windows it
## reports describe a route no player would take.
##
## The two rooms that survived playtesting — Overhead and Overhead (narrow) —
## both ask for a commitment made IN THE AIR, flipping up through a gap in a
## spiked ceiling. There is no surface to creep along mid-flight and gravity acts
## in full, so the timing is real. That is the principle worth building on:
##
##     surface positioning is cheesable; airborne commitment is not.
##
## WHAT ELSE PLAYTESTING SAID, which overturned the metric that produced them:
##
##   - Lethality is the difficulty axis, not the timing window. The rooms with
##     spikes played as hard and insane; the rooms where a mistake only cost a
##     retry played as "not hard, just annoying". So every room here now has a
##     way to die.
##   - A room the solver scored at 0ms — supposedly frame-perfect — was beaten
##     on the first attempt once its neighbour had taught the move, and was
##     liked for exactly that. Both Overhead searches hit the node cap, so their
##     windows are lower bounds, and "0ms" did not mean unfair.
##   - Rooms that differ only in floor material read as the same room. Ice has
##     to visibly change what happens, not just widen a number.

const ALL := [
	# VALIDATED as hard. Build speed on the ice, then flip down EARLY: arrive
	# slow and you drop into the hole, arrive fast and you skim over it into the
	# spikes. Playtest: "hard because of the spikes behind the ice."
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
	# The exit is BELOW the start, down a one-cell shaft — the ladder shape every
	# shipped room is built on, inverted.
	#
	# Two playtests shaped this. With no hazard at all it was "not hard, just
	# annoying, you can't die". With spikes one cell past the shaft it was
	# unplayable: seven attempts, seven impalings, never cleared — overshooting
	# by a single cell was instant death with nothing to react to.
	#
	# So the shaft moved left and the spike moved to the far wall, leaving four
	# cells of ice as runoff. Overshooting is still fatal, but there are now
	# 0.4-0.7s between clearing the shaft and reaching the spike, against roughly
	# 0.1s before — enough to see the mistake and flip out of it, which is the
	# difference between hard and a wall.
	{"name": "Well", "par": 5, "map": [
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
	# The button sits directly on its own door, so touching it removes the floor
	# underneath, and the drop is the start of the problem rather than the win.
	#
	# The first version put a one-cell hole above a spike floor with the exit two
	# cells right of it, and was correctly called impossible. Simulated, the orb
	# only enters a one-cell hole below about 150px/s, and at that speed it lands
	# straight down on the spikes — the solver's "solution" needed a 50ms entry
	# followed by mid-air steering, which is not a thing a person can do.
	#
	# So the door is two cells, which the orb can carry speed through, and the
	# spikes moved to the LEFT of the landing zone. Drifting left kills, drifting
	# right merely misses. That took the forgiving window from 50ms to 325ms —
	# the band Skim sits in, which played as properly hard.
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
	# The same room on stone, to make ice visibly load-bearing rather than a
	# number in a report — the previous pair differed by 11x in measured window
	# and read as identical in play. It now shows: ice needs one committed flip at
	# 325ms, stone needs two at 125ms and two more rotations to get there.
	{"name": "Trapdoor (stone)", "par": 4, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#...........#",
		"#.....1.....#",
		"######aa#####",
		"#...........#",
		"#...........#",
		"#^^^^^.E....#",
		"#############",
	]},
	# VALIDATED as insane. A spiked ceiling with a two-cell safe column, so the
	# reflex flip-up at a wall is fatal and the climb has to be committed
	# mid-flight. Playtest: "insane, not unfair — took approx 8 attempts."
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
	# VALIDATED, and the most interesting result. The same again with a one-cell
	# column, which the solver scored at 0ms. Playtest: one attempt, because
	# Overhead had already taught the move — "which is nice since you can apply
	# something learned". A room is not hard or easy on its own; it is hard or
	# easy given what the room before it taught.
	{"name": "Overhead (narrow)", "par": 5, "map": [
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
