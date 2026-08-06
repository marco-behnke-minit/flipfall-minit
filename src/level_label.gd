extends Node2D
## The room's name and place in the run, above the playfield.
##
## Its own node because it sits inside the screen shake with the playfield, while
## the compass, rotate buttons and pill below deliberately stay put.

var level_index := 0    # index within the published segment
var level_total := 10
var level_name := ""
var level_tier := "easy"


func set_level(index: int, total: int, level_title: String, tier: String) -> void:
	level_index = index
	level_total = total
	level_name = level_title
	level_tier = tier
	queue_redraw()


func _draw() -> void:
	var font := DrawUtil.bold()
	var size := 22
	var tracking := 3.0
	var label := "LEVEL %d / %d  ·  %s" % [level_index + 1, level_total, level_name.to_upper()]
	var y := Const.PF_Y - 26.0
	var dim := Color(1, 1, 1, 0.4)

	# Tier is worth colouring: with segmented drops it is the only cue for which
	# difficulty band the player is in.
	if level_tier != "" and level_tier != "easy":
		var suffix := "  ·  %s" % level_tier.to_upper()
		var w := DrawUtil.measure_tracked(font, size, label, tracking)
		var tw := DrawUtil.measure_tracked(font, size, suffix, tracking)
		var x := Const.DESIGN_W / 2.0 - (w + tw) / 2.0
		DrawUtil.draw_tracked(self, font, size, Vector2(x, y), label, dim, tracking)
		DrawUtil.draw_tracked(self, font, size, Vector2(x + w, y), suffix,
			Const.TIER_COLOR.get(level_tier, dim), tracking)
	else:
		DrawUtil.draw_tracked(self, font, size, Vector2(Const.DESIGN_W / 2.0, y), label, dim, tracking, 0.5)
