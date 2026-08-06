extends Node2D
## The two rotate buttons and the bottom pill.
##
## This whole band anchors to the bottom edge of the viewport, so the spare
## height `expand` reveals opens up between the playfield and the controls
## instead of piling up as dead space underneath them. game.gd positions the
## node; everything below is drawn in design coordinates as before, which is also
## what makes hit-testing work — game.gd converts a touch into this node's local
## space rather than tracking the offset itself.
##
## Purely a view: game.gd owns every value below and pushes it in each frame.

# Named so src/warmup.gd can pre-rasterise exactly these sizes, and cannot drift
# out of step with them.
const HINT_TITLE_SIZE := 30
const HINT_SUB_SIZE := 20
const RETRY_TITLE_SIZE := 27
const RETRY_SUB_SIZE := 17

var held_ccw := false
var held_cw := false
var held_pill := false
var live := true
var attention := false      # room 1, before the first rotation
var time_ms := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_rotate_button(false, held_ccw)
	_draw_rotate_button(true, held_cw)
	_draw_pill("hint" if attention else "retry", held_pill)


# --- rotate buttons ---------------------------------------------------------

func _draw_rotate_button(clockwise: bool, held: bool) -> void:
	var c: Vector2 = Const.ROT_CW if clockwise else Const.ROT_CCW
	var press := 0.94 if held else 1.0
	var glow_t := (sin(time_ms * 0.005) + 1.0) / 2.0 if attention else 0.0
	var alpha := 1.0 if live else 0.4

	draw_set_transform(c, 0.0, Vector2(press, press))

	if attention:
		DrawUtil.glow(self, Vector2.ZERO, Const.ROT_R, Const.C_ORB,
			16.0 + glow_t * 26.0, (0.5 + glow_t * 0.9) * alpha)

	var fill := Color("#3B4658") if held else Color("#2A2F3A")
	fill.a = alpha
	draw_circle(Vector2.ZERO, Const.ROT_R, fill)

	var stroke := Const.C_ORB if attention else Color(1, 1, 1, 0.14)
	stroke.a *= alpha
	DrawUtil.stroke_arc(self, Vector2.ZERO, Const.ROT_R, 0.0, TAU, stroke,
		4.0 + glow_t * 4.0 if attention else 3.0)

	_draw_rotate_glyph(Const.ROT_R * 0.44, clockwise, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rotate_glyph(radius: float, clockwise: bool, alpha: float) -> void:
	var col := Const.C_HUD
	col.a = alpha
	# The clockwise glyph is authored, and the counter-clockwise one is its
	# mirror image — so build both in one space and flip x at the end.
	var flip := 1.0 if clockwise else -1.0
	var mirror := func(p: Vector2) -> Vector2: return Vector2(p.x * flip, p.y)

	var pts := PackedVector2Array()
	for i in 33:
		var a: float = lerp(PI * 0.78, PI * 2.14, float(i) / 32.0)
		pts.append(mirror.call(Vector2(cos(a), sin(a)) * radius))
	draw_polyline(pts, col, 11.0, true)

	# Arrowhead at the arc's leading end, turned to face along the arc.
	var head_a := PI * 0.14
	var head := Vector2(cos(head_a), sin(head_a)) * radius
	var tri := [Vector2(0, -19), Vector2(-15, 11), Vector2(15, 11)]
	var out := PackedVector2Array()
	for p in tri:
		out.append(mirror.call(head + p.rotated(head_a - PI / 2.0)))
	draw_colored_polygon(out, col)


# --- bottom pill ------------------------------------------------------------

## Before the first input this is the "rotate gravity" prompt; once the run is
## live it becomes Retry, which costs an attempt.
func _draw_pill(mode: String, held: bool) -> void:
	var o := Const.PILL_POS
	var w := Const.PILL_SIZE.x
	var h := Const.PILL_SIZE.y
	var press := 0.96 if held else 1.0
	draw_set_transform(o, 0.0, Vector2(press, press))

	if mode == "hint":
		var p := (sin(time_ms * 0.004) + 1.0) / 2.0
		var big := DrawUtil.bold()
		var small := DrawUtil.semibold()
		var c1 := Const.C_ORB
		c1.a = 0.55 + p * 0.45
		DrawUtil.draw_tracked(self, big, HINT_TITLE_SIZE,
			Vector2(0, DrawUtil.middle_baseline(big, HINT_TITLE_SIZE, -4.0)),
			"ROTATE GRAVITY", c1, 4.0, 0.5)
		var c2 := Const.C_HUD
		c2.a = 0.4 + p * 0.3
		DrawUtil.draw_tracked(self, small, HINT_SUB_SIZE,
			Vector2(0, DrawUtil.middle_baseline(small, HINT_SUB_SIZE, 28.0)),
			"TO BEGIN", c2, 2.0, 0.5)
	else:
		var rect := Rect2(-w / 2.0, -h / 2.0, w, h)
		DrawUtil.fill_rounded_rect(self, rect, h / 2.0,
			Color(0.937, 0.267, 0.267, 0.3 if held else 0.12))
		DrawUtil.stroke_rounded_rect(self, rect, h / 2.0, Const.C_SPIKE, 3.0)

		# Reset glyph.
		var g := Vector2(-w / 2.0 + 52.0, 0.0)
		DrawUtil.stroke_arc(self, g, 17.0, PI * 0.35, PI * 1.85, Const.C_SPIKE, 6.0)
		draw_colored_polygon(PackedVector2Array([
			g + Vector2(17, -14), g + Vector2(6, -3), g + Vector2(22, 2),
		]), Const.C_SPIKE)

		var big := DrawUtil.bold()
		DrawUtil.draw_tracked(self, big, RETRY_TITLE_SIZE,
			Vector2(26, DrawUtil.middle_baseline(big, RETRY_TITLE_SIZE, -9.0)),
			"RETRY", Const.C_SPIKE, 2.0, 0.5)
		var small := DrawUtil.semibold()
		var faint := Const.C_SPIKE
		faint.a = 0.75
		DrawUtil.draw_tracked(self, small, RETRY_SUB_SIZE,
			Vector2(26, DrawUtil.middle_baseline(small, RETRY_SUB_SIZE, 20.0)),
			"COSTS 1 ATTEMPT", faint, 0.0, 0.5)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
