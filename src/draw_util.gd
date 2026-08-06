class_name DrawUtil
extends RefCounted
## Shared immediate-mode drawing helpers.
##
## The HTML5 original is a canvas2d game, so most of its art is rounded rects,
## arcs and letter-spaced text. Godot's CanvasItem API has no rounded-rect or
## letter-spacing primitive, so both are built here once rather than open-coded
## in every drawing script.


## Outline of a rounded rectangle as a closed polygon, corner-first.
static func rounded_rect(rect: Rect2, radius: float, steps: int = 6) -> PackedVector2Array:
	var r: float = min(radius, min(rect.size.x, rect.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI, 1.5 * PI],                                    # top-left
		[rect.position + Vector2(rect.size.x - r, r), 1.5 * PI, TAU],                      # top-right
		[rect.position + rect.size - Vector2(r, r), 0.0, 0.5 * PI],                        # bottom-right
		[rect.position + Vector2(r, rect.size.y - r), 0.5 * PI, PI],                       # bottom-left
	]
	for corner in corners:
		var centre: Vector2 = corner[0]
		var a0: float = corner[1]
		var a1: float = corner[2]
		for i in steps + 1:
			var a: float = lerp(a0, a1, float(i) / steps)
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


static func fill_rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	ci.draw_colored_polygon(rounded_rect(rect, radius), color)


static func stroke_rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := rounded_rect(rect, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


## An open arc as a polyline, matching canvas2d's `ctx.arc(...)` + `stroke()`.
static func stroke_arc(ci: CanvasItem, centre: Vector2, radius: float, from: float, to: float,
		color: Color, width: float, steps: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a: float = lerp(from, to, float(i) / steps)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	ci.draw_polyline(pts, color, width, true)


## A soft radial glow, standing in for canvas2d's `shadowBlur`. Cheap enough to
## run per-frame: a handful of concentric translucent discs.
static func glow(ci: CanvasItem, centre: Vector2, radius: float, color: Color, strength: float = 1.0, rings: int = 5) -> void:
	for i in range(rings, 0, -1):
		var t := float(i) / rings
		var c := color
		c.a = color.a * strength * 0.10 * (1.0 - t + 0.25)
		ci.draw_circle(centre, radius * (1.0 + t * 0.75), c)


# --- fonts ------------------------------------------------------------------
#
# The original picks up the device's system-ui face at several weights. Godot
# web builds ship one bundled face, so the weights are synthesised with
# FontVariation rather than pulling extra font files into the .pck.

static var _faces: Dictionary = {}


static func face(embolden: float = 0.0) -> Font:
	var key := snappedf(embolden, 0.01)
	if not _faces.has(key):
		if is_zero_approx(embolden):
			_faces[key] = ThemeDB.fallback_font
		else:
			var v := FontVariation.new()
			v.base_font = ThemeDB.fallback_font
			v.variation_embolden = embolden
			_faces[key] = v
	return _faces[key]


static func regular() -> Font:
	return face(0.0)


static func semibold() -> Font:
	return face(0.35)


static func bold() -> Font:
	return face(0.6)


static func heavy() -> Font:
	return face(0.9)


## Baseline y for text whose vertical centre should sit at `centre_y` — the
## canvas2d `textBaseline = 'middle'` equivalent.
static func middle_baseline(font: Font, size: int, centre_y: float) -> float:
	return centre_y + (font.get_ascent(size) - font.get_descent(size)) / 2.0


# --- letter-spaced text -----------------------------------------------------

static func measure_tracked(font: Font, size: int, text: String, tracking: float) -> float:
	if text.is_empty():
		return 0.0
	var w := 0.0
	for ch in text:
		w += font.get_char_size(ch.unicode_at(0), size).x + tracking
	return w - tracking


## Draw `text` with per-character tracking. `anchor` is 0 left, 0.5 centre,
## 1 right; `pos.y` is the text baseline.
static func draw_tracked(ci: CanvasItem, font: Font, size: int, pos: Vector2, text: String,
		color: Color, tracking: float = 0.0, anchor: float = 0.0) -> void:
	var x := pos.x - measure_tracked(font, size, text, tracking) * anchor
	var rid := ci.get_canvas_item()
	for ch in text:
		var code := ch.unicode_at(0)
		font.draw_char(rid, Vector2(x, pos.y), code, size, color)
		x += font.get_char_size(code, size).x + tracking


## Tracked text with the SDK header bar's two-layer drop shadow.
static func draw_tracked_shadowed(ci: CanvasItem, font: Font, size: int, pos: Vector2, text: String,
		color: Color, tracking: float = 0.0, anchor: float = 0.0) -> void:
	draw_tracked(ci, font, size, pos + Vector2(0, 3), text, Color(0, 0, 0, 0.55), tracking, anchor)
	draw_tracked(ci, font, size, pos + Vector2(0, 1), text, Color(0, 0, 0, 0.6), tracking, anchor)
	draw_tracked(ci, font, size, pos, text, color, tracking, anchor)
