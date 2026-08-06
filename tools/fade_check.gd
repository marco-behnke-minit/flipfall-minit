extends SceneTree
## Catch the transition fade at a phone aspect ratio.
##
##   godot --script res://tools/fade_check.gd --resolution 480x1200
##
## At 480x1200 the design box is narrower than the window's aspect allows, so
## `expand` reveals extra area above and below it — exactly the case where a fade
## that only covered the design box would leave lit bands. The capture is
## triggered off the game's own fade value rather than a frame number, so it
## lands mid-transition every run.

const OUT_DIR := "user://shots"

var _game: Node
var _frame := 0
var _shots := 0
var _pending := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 14:
		# Room 1 is solved by tipping gravity right — the clockwise button.
		var surface := _game.get_node("Surface") as Node2D
		var p: Vector2 = surface.position + Const.ROT_CW
		_game.call("_on_touch", p, true)
		_game.call("_on_touch", p, false)

	var fade := float(_game.get("_fade"))
	if fade > 0.35 and _shots < 2:
		_shots += 1
		_pending = "fade-%d" % _shots
	if _frame > 240:
		quit()
	return false


func _capture() -> void:
	if _pending == "":
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, _pending])
	print("wrote ", _pending)
	_pending = ""
