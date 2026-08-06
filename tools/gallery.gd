extends SceneTree
## Capture one still per sampled room, so every tile type gets looked at.
##
##   godot --script res://tools/gallery.gd --resolution 960x1480

const OUT_DIR := "user://shots"
const ROOMS := [5, 6, 8, 9, 21, 39]  # ice, ice+spikes, sticky, everything, hard, insane

var _game: Node
var _frame := 0
var _index := 0
var _pending := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> bool:
	_frame += 1
	# One room every 12 frames: long enough for the arm-and-settle to land.
	if _frame % 12 == 6:
		if _index >= ROOMS.size():
			quit()
			return false
		var room: int = ROOMS[_index]
		_game.set("_level_index", room)
		_game.call("_arm_level", room)
		_index += 1
	elif _frame % 12 == 10 and _index > 0:
		_pending = "room-%02d-%s" % [ROOMS[_index - 1] + 1, String(Levels.ALL[ROOMS[_index - 1]]["name"]).to_lower()]
	return false


func _capture() -> void:
	if _pending == "":
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, _pending])
	print("wrote ", _pending)
	_pending = ""
