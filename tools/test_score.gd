extends SceneTree
## Scoring and flavor-text checks, against the values in the design doc.
##
##   godot --headless --script res://tools/test_score.gd

var _failures := 0


func _check(label: String, got, want) -> void:
	if str(got) != str(want):
		_failures += 1
		print("FAIL  %s: got %s, want %s" % [label, got, want])
	else:
		print("ok    %s = %s" % [label, got])


func _initialize() -> void:
	# +1000 per room, plus max(0, 200 - seconds*10) for speed.
	_check("time_bonus(0s)", Score.time_bonus(0.0), 200)
	_check("time_bonus(8s)", Score.time_bonus(8.0), 120)
	_check("time_bonus(20s)", Score.time_bonus(20.0), 0)
	_check("time_bonus(45s) floors at 0", Score.time_bonus(45.0), 0)
	# Rotations are scored against par: +40 each saved, -25 each wasted.
	_check("at par", Score.rotation_score(4, 4), 0)
	_check("two under par", Score.rotation_score(2, 4), 80)
	_check("three over par", Score.rotation_score(7, 4), -75)
	# Creeping a par-4 room in 24 rotations should hurt.
	_check("crept, 20 rotations over", Score.rotation_score(24, 4), -500)

	_check("level_score(at par, 8s)", Score.level_score(4, 8.0, 4), 1120)
	_check("level_score(perfect line)", Score.level_score(2, 0.0, 4), 1280)
	_check("level_score(crept)", Score.level_score(24, 30.0, 4), 500)
	_check("level_score never negative", Score.level_score(60, 60.0, 1), 0)

	# +500 per Attempt still in hand, -150 per death.
	_check("final_score(10000, 3, no deaths)", Score.final_score(10000, 3, 0), 11500)
	_check("final_score(10000, 3, 4 deaths)", Score.final_score(10000, 3, 4), 10900)
	_check("final_score never negative", Score.final_score(0, -2, 9), 0)

	# Flavor text reports a session moment, never the score.
	var flawless := Score.empty_stats()
	_check("flawless run", Score.flavor_text(flawless, 10, 10), "All 10 rooms, never touched a spike")

	var impaled := Score.empty_stats()
	impaled["spike_deaths"] = 3
	_check("impaled outranks the rest", Score.flavor_text(impaled, 4, 10), "Impaled 3 times")

	var fast := Score.empty_stats()
	Score.record_clear(fast, {"name": "Roll", "par": 1}, 1, 2.5)
	Score.record_clear(fast, {"name": "Press", "par": 3}, 14, 9.0)
	# Roll was cleared in 1 rotation against a par of 1; Press took 14 against 3.
	_check("only at-or-under-par clears count", fast["par_clears"], 1)
	_check("fastest room tracked", fast["fastest"]["name"], "Roll")
	_check("messiest room tracked", fast["messiest"]["rotations"], 14)
	_check("messiest wins at 12+", Score.flavor_text(fast, 2, 10), "Spun gravity 14 times on Press")

	var quiet := Score.empty_stats()
	Score.record_clear(quiet, {"name": "Roll", "par": 1}, 1, 2.5)
	_check("falls back to fastest", Score.flavor_text(quiet, 1, 10), "Roll cracked in 2.5s")

	var nothing := Score.empty_stats()
	_check("stopped-at fallback", Score.flavor_text(nothing, 3, 10), "Stopped at room 4")

	print("")
	if _failures > 0:
		print("%d FAILURE(S)" % _failures)
	else:
		print("all scoring checks passed")
	quit(1 if _failures > 0 else 0)
