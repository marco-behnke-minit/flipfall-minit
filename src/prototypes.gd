class_name Prototypes
extends RefCounted
## Scratch rooms for design work. NOT shipped — src/levels.gd is the game.
##
## Play them with:
##
##     godot --path . -- --rooms=prototypes --attempts=9
##
## They exist because the shipped set has no difficulty in it: 32 of its 40 rooms
## are rest-only solvable, so the orb can be left to settle before every flip and
## nothing can be failed through execution. Each room here is built to fail that
## test — the solver confirms none has a rest-only route — and they are ordered
## so the last three are deliberately too tight, to feel the difference against
## the first three rather than to be enjoyed.
##
## `par` is the forgiving route's rotation count, as tools/solve.mjs reports it.
## The window in each comment is the tightest wait on that route: the design
## document's bar is 250ms for easy, 200 medium, 120 hard, 60 insane.
##
## Keep in step with tools/prototypes.mjs, which is what measures them.

const ALL := [
	# 275ms. Build speed on the ice, then flip down EARLY: arrive slow and you
	# drop into the hole, arrive fast and you skim straight over it into the
	# spikes. The opposite of the usual instinct.
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
	# 200ms. The exit is BELOW the start, down a one-cell shaft — the ladder
	# shape every shipped room is built on, inverted.
	{"name": "Well", "par": 5, "map": [
		"#############",
		"#O..........#",
		"#IIIIIIII.II#",
		"#########.###",
		"#########.###",
		"#########.###",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#E..........#",
		"#...........#",
		"#############",
	]},
	# 275ms. The button sits directly on its own door, so touching it removes the
	# floor underneath. The ice either side is what makes it fair: the orb slides
	# into the hole instead of having to arrive on it.
	{"name": "Trapdoor", "par": 4, "map": [
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
		"#.....E.....#",
		"#############",
	]},

	# --- below here the rooms are too tight to ship, kept for comparison ---

	# 25ms. The same trapdoor on stone instead of ice. One tile changed, and the
	# window collapses by a factor of eleven — this is the room that shows what
	# ice is actually for.
	{"name": "Trapdoor (stone)", "par": 4, "map": [
		"#############",
		"#...........#",
		"#...........#",
		"#...........#",
		"#O..........#",
		"#...........#",
		"#...........#",
		"#.....1.....#",
		"#####a#######",
		"#...........#",
		"#...........#",
		"#.....E.....#",
		"#############",
	]},
	# 50ms. A spiked ceiling with a two-cell safe column: the reflex flip-up at a
	# wall is fatal, so the climb has to be committed mid-flight. Still under the
	# 60ms bar even insane sets.
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
	# 0ms. The same again with a one-cell column. Included to show that a
	# vertical flip has no equivalent of ice to widen it, which is why this
	# primitive looks unfair rather than hard.
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
