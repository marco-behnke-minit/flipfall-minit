extends SceneTree
## Time the lazy first-use costs that show up as an in-game stall.
##
##   godot --headless --script res://tools/measure_warmup.gd
##
## Godot rasterises glyphs into the font atlas on first use, per (face, size,
## outline) combination. The feedback pops are Bowlby One SC at 110 px drawn
## three times over — a fill and two outline passes — so the first pop pays for
## three full atlas fills in the middle of a frame.

func _initialize() -> void:
	var ts := TextServerManager.get_primary_interface()

	var jobs := [
		["Lato Regular 36 (HUD labels)", DrawUtil.regular(), Vector2i(36, 0)],
		["Lato Bold 48 (HUD values)", DrawUtil.bold(), Vector2i(48, 0)],
		["Lato Bold 30 (pill)", DrawUtil.bold(), Vector2i(30, 0)],
		["Lato Bold 27 (pill)", DrawUtil.bold(), Vector2i(27, 0)],
		["Lato Bold 22 (level label)", DrawUtil.bold(), Vector2i(22, 0)],
		["Lato Bold 20 (pill)", DrawUtil.bold(), Vector2i(20, 0)],
		["Lato Bold 17 (pill)", DrawUtil.bold(), Vector2i(17, 0)],
		["Bowlby 110 fill (feedback)", DrawUtil.display(), Vector2i(110, 0)],
		["Bowlby 110 outline 6 (feedback)", DrawUtil.display(), Vector2i(110, 6)],
		["Bowlby 110 outline 10 (feedback)", DrawUtil.display(), Vector2i(110, 10)],
	]

	var total := 0.0
	for job in jobs:
		var font: Font = job[1]
		var size: Vector2i = job[2]
		var began := Time.get_ticks_usec()
		for rid in font.get_rids():
			ts.font_render_range(rid, size, 32, 126)
			ts.font_render_range(rid, size, 0xB7, 0xB7)  # the level label's separator
		var ms := (Time.get_ticks_usec() - began) / 1000.0
		total += ms
		print("%-36s %7.1f ms" % [job[0], ms])

	print("")
	print("total glyph rasterisation: %.1f ms" % total)
	quit()
