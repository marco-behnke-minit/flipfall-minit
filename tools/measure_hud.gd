extends SceneTree
## Print the HUD's real geometry in design coordinates.
##
##   godot --headless --script res://tools/measure_hud.gd
##
## The layout is authored against a 960x1480 surface, but panel widths depend on
## the font, and this build substitutes Godot's bundled face for the SDK's Lato.
## So the crowding has to be measured rather than assumed.

func _initialize() -> void:
	var label_font := DrawUtil.regular()
	var value_font := DrawUtil.bold()

	print("design width: %d, safe area: %d..%d" % [
		Const.DESIGN_W, Const.DESIGN_W * Const.SAFE_INSET,
		Const.DESIGN_W * (1.0 - Const.SAFE_INSET)])
	print("header padding: %d, label %dpx, value %dpx" % [Const.HUD_PAD, 36, 48])
	print("")

	var panels := [["Attempts", "3"], ["Rotations", "0 / 12"], ["Score", "12871"]]
	for p in panels:
		var lw := label_font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		var vw := value_font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		print("panel %-10s label %6.1f  value %6.1f  -> width %6.1f" % [p[0], lw, vw, maxf(60.0, maxf(lw, vw))])

	var attempts_w: float = maxf(60.0, label_font.get_string_size("Attempts", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x)
	var rotations_w: float = maxf(60.0, label_font.get_string_size("Rotations", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x)
	var score_w: float = maxf(60.0, label_font.get_string_size("Score", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x)

	var left_end := Const.HUD_PAD + attempts_w + 12.0 + rotations_w
	var score_start := Const.DESIGN_W - Const.HUD_PAD - score_w
	var compass_l := Const.COMPASS.x - Const.COMPASS_R
	var compass_r := Const.COMPASS.x + Const.COMPASS_R

	print("")
	print("left group  : %.0f .. %.0f" % [Const.HUD_PAD, left_end])
	print("compass     : %.0f .. %.0f" % [compass_l, compass_r])
	print("score panel : %.0f .. %.0f" % [score_start, Const.DESIGN_W - Const.HUD_PAD])
	print("gap left-group -> compass : %.0f px" % (compass_l - left_end))
	print("gap compass -> score      : %.0f px" % (score_start - compass_r))

	# Vertical bands, at a few viewport heights. `expand` never gives less than
	# the design height, so 1480 is the floor.
	print("")
	print("%-10s %10s %10s %10s" % ["viewport", "above pf", "below pf", "under pill"])
	for height in [1480.0, 1520.0, 1587.0, 1700.0]:
		var controls_h := Const.CONTROLS_BOTTOM - Const.CONTROLS_TOP
		var controls_top: float = maxf(Const.CONTROLS_TOP, height - Const.BOTTOM_MARGIN - controls_h)
		var field_h := Const.FIELD_BOTTOM - Const.FIELD_TOP
		var spare: float = maxf(0.0, (controls_top - Const.TOP_BAND_BOTTOM) - field_h)
		var field_dy := Const.TOP_BAND_BOTTOM + spare / 2.0 - Const.FIELD_TOP
		print("%-10.0f %10.0f %10.0f %10.0f" % [
			height,
			(Const.FIELD_TOP + field_dy) - Const.TOP_BAND_BOTTOM,
			controls_top - (Const.FIELD_BOTTOM + field_dy),
			height - (controls_top + controls_h),
		])
	# The attention halo reaches ROT_R + shadowBlur above the button centre; it
	# used to be sized as a multiple of the radius and washed over the playfield.
	print("")
	print("attention halo reaches %.0f px above the button top" % (16.0 + 26.0))
	quit()
