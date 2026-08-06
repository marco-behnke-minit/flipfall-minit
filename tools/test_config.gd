extends SceneTree
## Config coercion checks.
##
##   godot --headless --script res://tools/test_config.gd
##
## Config values arrive off the URL query string as strings, or not at all, so
## every read is coerced and clamped. The design calls out two cases by name:
## `attempts=99` becomes 9, and `startLevel=abc` becomes room 1.

var _failures := 0


func _check(label: String, got, want) -> void:
	if str(got) != str(want):
		_failures += 1
		print("FAIL  %s: got %s, want %s" % [label, got, want])
	else:
		print("ok    %s = %s" % [label, got])


func _initialize() -> void:
	var game := load("res://src/game.gd")
	var attempts := Const.config_spec("attempts")        # default 3, 1..9
	var start_level := Const.config_spec("startLevel")   # default 1, 1..40
	var end_level := Const.config_spec("endLevel")       # default 10, 1..40

	# The two cases the design names explicitly.
	_check("attempts=99 clamps to the max", game.coerce_config("99", attempts), 9)
	_check("startLevel=abc falls back to 1", game.coerce_config("abc", start_level), 1)

	# Absent key: the SDK facade hands back the empty default.
	_check("attempts absent -> default", game.coerce_config("", attempts), 3)
	_check("endLevel absent -> default", game.coerce_config("", end_level), 10)

	# parseInt semantics rather than to_int(): a leading integer wins, junk after
	# it is ignored, and junk instead of it falls back to the default — never to
	# the minimum.
	_check("attempts=5.9 -> 5", game.coerce_config("5.9", attempts), 5)
	_check("attempts=7abc -> 7", game.coerce_config("7abc", attempts), 7)
	_check("attempts=abc -> default, not min", game.coerce_config("abc", attempts), 3)
	_check("attempts='  4 ' -> 4", game.coerce_config("  4 ", attempts), 4)
	_check("attempts=+8 -> 8", game.coerce_config("+8", attempts), 8)

	# Clamping is two-sided, and a negative must not become the default.
	_check("attempts=-5 clamps to the min", game.coerce_config("-5", attempts), 1)
	_check("attempts=0 clamps to the min", game.coerce_config("0", attempts), 1)
	_check("startLevel=999 clamps to 40", game.coerce_config("999", start_level), 40)

	print("")
	if _failures > 0:
		print("%d FAILURE(S)" % _failures)
	else:
		print("all config checks passed")
	quit(1 if _failures > 0 else 0)
