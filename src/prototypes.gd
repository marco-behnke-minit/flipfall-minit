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
	# Rejected. The same room as the shipped Trapdoor but on stone instead of ice.
	# Playtested as "nearly the exact same room", and the creep is why: alternating
	# gravity walks the orb along either surface, so the floor material changes
	# nothing a player can feel. Kept as the record of a distinction that measured
	# 11x in window width and was invisible in play.
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
]
