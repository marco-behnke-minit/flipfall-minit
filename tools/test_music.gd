extends SceneTree
## Music wiring check.
##
##   godot --headless --script res://tools/test_music.gd
##
## The track is optional by design — a missing one warns and the game plays on in
## silence. That is good behaviour and a bad failure mode for a typo: renaming
## the file without updating MUSIC_PATH silently ships a game with no music and
## no error. This asserts the file the code points at exists, imports as a
## looping stream, and actually starts on the first rotation.

var _game: Node
var _frame := 0
var _failures := 0


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		print("ok    %s" % label)
	else:
		_failures += 1
		print("FAIL  %s%s" % [label, "" if detail.is_empty() else "  (%s)" % detail])


func _initialize() -> void:
	var audio := load("res://src/audio.gd")
	var path: String = audio.MUSIC_PATH
	print("MUSIC_PATH = %s" % path)
	_check("the file MUSIC_PATH points at exists", ResourceLoader.exists(path))

	var stream := ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	_check("it imports as an AudioStreamMP3", stream is AudioStreamMP3,
		"got %s" % ("null" if stream == null else stream.get_class()))
	if stream is AudioStreamMP3:
		_check("it is longer than a minute", stream.get_length() > 60.0,
			"%.0fs" % stream.get_length())

	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)


func _process(_delta: float) -> bool:
	_frame += 1
	var player: AudioStreamPlayer = null
	if _game != null:
		player = _game.get_node("Audio").get("_music") as AudioStreamPlayer

	if _frame == 5:
		_check("the player picked the stream up", player != null and player.stream != null)
		_check("the stream loops", player != null and player.stream != null and player.stream.loop)
		_check("nothing plays before the first rotation", player != null and not player.playing)
		# The first rotation is what starts the run, and the music with it.
		var surface := _game.get_node("Surface") as Node2D
		var p: Vector2 = surface.position + Const.ROT_CW
		_game.call("_on_touch", p, true)
		_game.call("_on_touch", p, false)

	if _frame == 15:
		_check("it starts on the first rotation", player != null and player.playing)
		# Tear the scene down and let a frame pass before quitting: this runs
		# inside package.sh, and a leaked-objects warning there reads like a real
		# build problem. Freeing in the same frame as quit() is not enough — the
		# tweens and players the run created are released on the next idle pass.
		root.remove_child(_game)
		_game.queue_free()
		_game = null

	if _frame == 20:
		print("")
		if _failures > 0:
			print("%d FAILURE(S)" % _failures)
		else:
			print("music is wired up correctly")
		quit(1 if _failures > 0 else 0)
	return false
