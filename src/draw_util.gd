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
##
## `blur` is the reach beyond `radius` in pixels, matching shadowBlur's units.
## It used to be a multiple of the radius, which made the halo scale with the
## object — on the 118 px rotate buttons that reached 83 px up into the
## playfield frame. Call sites now pass the same blur the original did.
static func glow(ci: CanvasItem, centre: Vector2, radius: float, color: Color,
		blur: float, strength: float = 1.0, rings: int = 5) -> void:
	if blur <= 0.0 or strength <= 0.0:
		return
	for i in range(rings, 0, -1):
		var t := float(i) / rings
		var c := color
		c.a = color.a * strength * 0.10 * (1.0 - t + 0.25)
		ci.draw_circle(centre, radius + blur * t, c)


# --- fonts ------------------------------------------------------------------
#
# The real SDK faces, not substitutes: Lato for the HUD and Bowlby One SC for
# the feedback pops, extracted from the JS SDK's bundled woff2 (both SIL OFL,
# licences alongside them in assets/fonts). Godot loads woff2 directly.
#
# This is not only cosmetic. Panel widths are font metrics, and the layout in
# DESIGN.md is authored against Lato's — a wider substitute pushed the Attempts /
# Rotations group to within 12 px of the gravity compass.

const LATO_REGULAR := "res://assets/fonts/Lato-Regular.woff2"
const LATO_BOLD := "res://assets/fonts/Lato-Bold.woff2"
const BOWLBY := "res://assets/fonts/BowlbyOneSC-Regular.woff2"

static var _faces: Dictionary = {}


static func _load(path: String) -> Font:
	if not _faces.has(path):
		var f := load(path)
		if f == null:
			push_warning("[flipfall] missing font %s, falling back" % path)
			f = ThemeDB.fallback_font
		_faces[path] = f
	return _faces[path]


## HUD labels and body text.
static func regular() -> Font:
	return _load(LATO_REGULAR)


## Lato ships Regular and Bold only, so the in-between weight the original got
## from `600` is the bold face — closer than emboldening the regular one.
static func semibold() -> Font:
	return _load(LATO_BOLD)


static func bold() -> Font:
	return _load(LATO_BOLD)


## Feedback pops only. Bowlby One SC is a heavy small-caps display face, which is
## what the SDK uses for those and nothing else — the bottom pill's "ROTATE
## GRAVITY" / "RETRY" are plain bold in the original and stay on Lato.
static func display() -> Font:
	return _load(BOWLBY)


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
