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
## WHAT PLAYTESTING SAID, which overturned the metric that produced them:
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
	# underneath. Dropping through used to BE the win, which is why it played as
	# a re-skin of Skim; now the drop is the start of the problem. You fall with
	# whatever speed the ice gave you and have to carry enough of it rightward to
	# clear the spikes below.
	{"name": "Trapdoor", "par": 5, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#...........#",
		"#.....1.....#",
		"#IIIIIaIIIII#",
		"#...........#",
		"#...........#",
		"#^^^^^^^E...#",
		"#############",
	]},
	# The same room on stone. Friction eats the speed, so the drop goes nearly
	# straight down into the spikes. The point is to make ice visibly
	# load-bearing rather than a number in a report — the previous pair differed
	# by 11x in measured window and read as identical in play.
	{"name": "Trapdoor (stone)", "par": 5, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#...........#",
		"#.....1.....#",
		"######a######",
		"#...........#",
		"#...........#",
		"#^^^^^^^E...#",
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
