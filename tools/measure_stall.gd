extends SceneTree
## Frame-time check around the first feedback pop — the beat that stalled.
##
##   godot --script res://tools/measure_stall.gd --resolution 960x1480
##
## Must run with a real renderer, not --headless: half the first-use cost is
## texture upload and pipeline creation, which the dummy driver never pays.
##
## The door-opening beat fires a neutral pop, a particle burst and two sounds at
## once. If the warm-up did its job, that frame costs no more than a quiet one.

const SETTLE := 40   # frames of ordinary play to establish a baseline
const TAIL := 12     # frames to watch after the beat

var _game: Node
var _frame := 0
var _deltas: Array[float] = []
var _beat_frame := -1


func _initialize() -> void:
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)


func _process(delta: float) -> bool:
	_frame += 1
	_deltas.append(delta * 1000.0)

	if _frame == SETTLE:
		# Exactly what opening a door does.
		_beat_frame = _deltas.size()
		_game.get_node("Surface/Feedback").call("show_neutral", "Door Open")
		_game.get_node("Surface/Shake/Particles").call(
			"burst", Vector2(400, 600), Const.C_BUTTON, 14, 260.0)

	if _frame >= SETTLE + TAIL:
		_report()
		quit()
	return false


func _report() -> void:
	# Skip the first handful of frames: startup is not what is being measured.
	var baseline := _deltas.slice(8, _beat_frame)
	var beat := _deltas.slice(_beat_frame, _deltas.size())

	baseline.sort()
	var median: float = baseline[baseline.size() / 2]
	var baseline_max := 0.0
	for d in baseline:
		baseline_max = maxf(baseline_max, d)
	var beat_max := 0.0
	for d in beat:
		beat_max = maxf(beat_max, d)

	print("")
	print("baseline frames : median %.2f ms, worst %.2f ms" % [median, baseline_max])
	print("first pop       : worst %.2f ms over the %d frames after the beat" % [beat_max, TAIL])
	print("spike vs median : %+.2f ms" % (beat_max - median))
	print(beat as Array)
