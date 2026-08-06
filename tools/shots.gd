extends SceneTree
## Visual smoke test: run the real main scene, drive it through a scripted
## session, and write PNGs of the viewport at the interesting beats.
##
##   godot --script res://tools/shots.gd --resolution 960x1480
##
## It calls the game's touch handler directly rather than synthesising OS input,
## so a capture never depends on window focus or pointer plumbing.

const OUT_DIR := "user://shots"

var _game: Node
var _frame := 0
var _script: Array = []
var _next := 0
var _pending := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)

	# Room 1 ("Roll") is solved in one rotation: the orb rests bottom-left and
	# the exit is on the same floor to its right, so tipping gravity right rolls
	# it home. Gravity order is down/left/up/right, so that is the CW button.
	_script = [
		{"at": 10, "shot": "01-armed"},
		{"at": 14, "tap": Const.ROT_CW},
		{"at": 20, "shot": "02-tumbling"},
		{"at": 45, "shot": "03-rolling"},
		{"at": 100, "shot": "04-clearing"},
		{"at": 130, "shot": "05-room2"},
		{"at": 134, "tap": Const.ROT_CCW},
		{"at": 150, "tap": Const.ROT_CCW},
		{"at": 175, "shot": "06-room2-mid"},
		{"at": 180, "tap": Const.PILL_POS},
		{"at": 195, "shot": "07-after-retry"},
	]
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> bool:
	_frame += 1
	while _next < _script.size() and int(_script[_next]["at"]) <= _frame:
		var step: Dictionary = _script[_next]
		if step.has("tap"):
			var p: Vector2 = step["tap"]
			var surface := _game.get_node("Surface") as Node2D
			# call() rather than a direct invocation: _game is a plain Node here,
			# so the handler is resolved at runtime instead of against Node2D.
			_game.call("_on_touch", surface.position + p, true)
			_game.call("_on_touch", surface.position + p, false)
		if step.has("shot"):
			_pending = step["shot"]
		_next += 1
	if _next >= _script.size() and _frame > int(_script[-1]["at"]) + 5:
		quit()
	return false


func _capture() -> void:
	if _pending == "":
		return
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, _pending]
	img.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	_pending = ""
