extends SceneTree
## End-of-run smoke test: drive the real game until the Attempts run out and
## confirm the one call every Minit must make actually fires.
##
##   godot --headless --script res://tools/endrun.gd
##
## Outside the Minit host the SDK facade degrades to a print, so the expected
## output is a "[Minit] reportResult <score>" line — which is also what proves
## the score and flavor text were computed rather than skipped.

var _game: Node
var _frame := 0
var _taps: Array = []
var _next := 0


func _initialize() -> void:
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	# One rotation to leave the armed state (Retry is a no-op before the player
	# has acted), then spend all three Attempts on Retry.
	_taps = [
		{"at": 5, "p": Const.ROT_CW},
		{"at": 15, "p": Const.PILL_POS},
		{"at": 25, "p": Const.ROT_CW},
		{"at": 35, "p": Const.PILL_POS},
		{"at": 45, "p": Const.ROT_CW},
		{"at": 55, "p": Const.PILL_POS},
	]


func _process(_delta: float) -> bool:
	_frame += 1
	while _next < _taps.size() and int(_taps[_next]["at"]) <= _frame:
		var surface := _game.get_node("Surface") as Node2D
		var p: Vector2 = surface.position + Vector2(_taps[_next]["p"])
		_game.call("_on_touch", p, true)
		_game.call("_on_touch", p, false)
		_next += 1
	if _frame > 90:
		print("attempts left: ", _game.get("_attempts"))
		print("phase: ", _game.get("_phase"))
		quit()
	return false
