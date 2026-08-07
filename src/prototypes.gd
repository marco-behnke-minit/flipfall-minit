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
	# The slalom, and the room that taught me sticky cannot do this job.
	#
	# Sticky is SOLID — a block, not a coating — so a patch in a lane seals it
	# rather than slowing whatever passes. That is what makes three lanes work
	# where two cannot: at two lanes a patch leaves a 60px gap for a 44px orb and
	# the route is forced, with no middle line to be skilled about. At three:
	#
	#   SAFE      ride a wall, and switch lanes before each block seals yours.
	#   SKILLED   hold the middle channel and touch nothing. A 16.8px band on row
	#             6.5 — the whole geometric slack of a 44px orb in a 60px channel.
	#
	# The blocks are STONE, because purple here would be a lie. Built with sticky
	# the room solves in 4 rotations at a 300ms window; built with stone, the same
	# 4 rotations at the same 300ms. You avoid the blocks, so you never slide on
	# them, so their material never acts. Moving the sticky onto the ridden walls
	# instead changes nothing either — sticky, stone and ice all give 4/300ms.
	#
	# Sticky only earns a room when the route is FORCED to slide along it with
	# gravity pressing in. That is a narrow condition, and Pothole below is the
	# shape that meets it.
	#
	# Reaching the middle band is the hard part, not holding it. Gravity along the
	# corridor does not cancel vertical speed, so a level run needs vy = 0 at the
	# moment of the flip: rise, arrest the rise, turn at the apex. That is the
	# two-flips-in-the-air control, with the corridor as the thing it is FOR.
	# A spike leads each patch, so riding a lane into a sealed section impales you
	# rather than merely parking you against it — the playtest note that a room you
	# cannot lose in is "not hard, just annoying". The exit sits at the far end of
	# the middle lane, which both routes can reach: the middle line arrives head on,
	# and a wall rider drops through it on the way past.
	{"name": "Slalom", "par": 3, "map": [
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

	# The answer to "the purple traps are harmless": they are, and this is why.
	#
	# Gravity parallel to a surface never presses the orb into it, so flying past
	# sticky costs nothing — the same reason ice underfoot changes nothing when you
	# are airborne. Sticky only bites on the flip that drives you INTO it.
	#
	# So the room is a run, not a fall. Flip right and the orb accelerates freely
	# down a corridor lined with sticky; the gap in the floor is too far to coast
	# to, and at full speed the orb skims straight over it like a wheel over a
	# pothole. The only way in is to flip down EARLY and let the sticky bleed off
	# exactly enough speed to arrive slow enough to drop. Too early and it stops
	# short; too late and the spikes at the end have you.
	#
	#   flip down after   500-680ms   180ms wide, and 25 of 281 timings are lethal
	#
	# Sticky is load-bearing here, and it is the hardest of the three materials
	# precisely because it brakes hardest — swapping the floor to stone widens the
	# window to 270ms, ice to 505ms.
	#
	# NOTE ON "one is top and one is bottom": measured, and it does not hold. Only
	# the face you flip into ever does anything — a sticky ceiling here gives the
	# identical 180ms window as stone or ice. Lining both faces would be the same
	# decorative purple, just relocated, so the ceiling is stone.
	#
	# The creep still works, at about 0.18 cells per flip-pair against 0.62 on
	# stone and 0.87 on ice — roughly 30 rotations against a par of 2, which the
	# scoring charges at 25 points each. Walkable, and expensive.
	{"name": "Pothole", "par": 2, "map": [
		"#############",
		"#############",
		"#O........^^#",
		"#TTT....TTTT#",
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
