extends SceneTree
## One tap must be one quarter turn, through the engine's real input path.
##
##   godot --script res://tools/test_touch.gd --resolution 960x1480
##
## On a touch device the engine also synthesises a left click for every tap, so a
## handler that takes both events turns gravity 180° per press and the game
## becomes unplayable — which is exactly what iOS did, while a desktop browser
## (mouse only, no emulation) looked fine. Needs a real window: the headless
## display server pins the viewport to 64x64, and OS input outside that rect is
## discarded before it ever reaches the game.

var _failures := 0


func _check(label: String, got, want) -> void:
	if str(got) != str(want):
		_failures += 1
		print("FAIL  %s: got %s, want %s" % [label, got, want])
	else:
		print("ok    %s = %s" % [label, got])


## A tap on the counter-clockwise button, fed in the way the OS feeds it, and the
## quarter turns it cost. Emulation happens inside Input, so the event has to go
## through parse_input_event — pushing straight to the viewport would skip the
## very duplicate this is here to catch.
func _tap(game: Node, controls: Node2D) -> int:
	var before: int = game._world.rotations
	var at: Vector2 = controls.get_global_transform() * Const.ROT_CCW
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame
	return game._world.rotations - before


func _initialize() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# The test is only meaningful while the engine is emulating; say so if that
	# setting is ever turned off, rather than passing for the wrong reason.
	print("emulate_mouse_from_touch=", ProjectSettings.get_setting(
		"input_devices/pointing/emulate_mouse_from_touch"))

	var controls: Node2D = game.get_node("Surface/Controls")
	_check("first tap, quarter turns", await _tap(game, controls), 1)
	_check("second tap, quarter turns", await _tap(game, controls), 1)

	print("")
	if _failures > 0:
		print("%d FAILURE(S)" % _failures)
	else:
		print("all touch checks passed")
	quit(1 if _failures > 0 else 0)
