extends Node2D
## Pay every lazy first-use cost before the game is revealed.
##
## Godot fills the font atlas on first use, per (face, size, outline) — and the
## feedback pops are Bowlby One SC at 110 px drawn three times over, a fill plus
## two outline passes. Left lazy, the first pop rasterises all of that inside a
## frame, which is a visible stall exactly when something interesting is
## happening: the first door opening, or the first room cleared. The canvas draw
## pipelines are built on first use too.
##
## Both are paid here instead, during the frames before Minit.loading_done(),
## while the host still has its loading state over the WebView — so the player
## never sees them at all.

## Frames to hold before reporting ready. The glyph work lands on the first one;
## the rest let the driver finish building the pipelines the priming draw asked
## for, since that happens asynchronously on some backends.
const FRAMES := 3

const ControlsScript = preload("res://src/controls.gd")
const LevelLabelScript = preload("res://src/level_label.gd")
const HeaderScript = preload("res://src/ui/header_bar.gd")
const FeedbackScript = preload("res://src/ui/feedback.gd")

# Latin-1 punctuation is not in the ASCII sweep, and the level label separator
# lives there.
const SEPARATOR := 0xB7

var _priming := false
var _pixel: ImageTexture


## Every (face, size, outline) the game will ever draw. Sizes are referenced from
## the scripts that draw them rather than repeated, so this list cannot quietly
## fall out of step.
func _text_styles() -> Array:
	return [
		[DrawUtil.regular(), Vector2i(HeaderScript.LABEL_SIZE, 0)],
		[DrawUtil.bold(), Vector2i(HeaderScript.VALUE_SIZE, 0)],
		[DrawUtil.bold(), Vector2i(LevelLabelScript.LABEL_SIZE, 0)],
		[DrawUtil.bold(), Vector2i(ControlsScript.HINT_TITLE_SIZE, 0)],
		[DrawUtil.bold(), Vector2i(ControlsScript.RETRY_TITLE_SIZE, 0)],
		[DrawUtil.semibold(), Vector2i(ControlsScript.HINT_SUB_SIZE, 0)],
		[DrawUtil.semibold(), Vector2i(ControlsScript.RETRY_SUB_SIZE, 0)],
		# The expensive ones.
		[DrawUtil.display(), Vector2i(FeedbackScript.SIZE, 0)],
		[DrawUtil.display(), Vector2i(FeedbackScript.SIZE, FeedbackScript.OUTLINE_STROKE)],
		[DrawUtil.display(), Vector2i(FeedbackScript.SIZE, FeedbackScript.OUTLINE_SHADOW)],
	]


func prime() -> void:
	var ts := TextServerManager.get_primary_interface()
	for style in _text_styles():
		var font: Font = style[0]
		var size: Vector2i = style[1]
		for rid in font.get_rids():
			ts.font_render_range(rid, size, 32, 126)
			ts.font_render_range(rid, size, SEPARATOR, SEPARATOR)

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(img)

	_priming = true
	queue_redraw()


func finish() -> void:
	_priming = false
	_pixel = null
	queue_redraw()
	# Nothing left to do — the atlases and pipelines outlive this node.
	queue_free()


## One of every primitive the game draws, so each canvas pipeline is built now.
## Drawn a few pixels across in the corner at an alpha that rounds to nothing:
## the draw call still goes through the renderer, which is all that is needed,
## and the frame stays clean even outside the host's loading overlay.
func _draw() -> void:
	if not _priming:
		return
	var ghost := Color(1, 1, 1, 0.002)
	var box := Rect2(1, 1, 4, 4)
	var line := PackedVector2Array([Vector2(1, 1), Vector2(5, 5), Vector2(5, 1)])

	draw_rect(box, ghost)
	draw_circle(Vector2(3, 3), 2.0, ghost)
	draw_circle(Vector2(3, 3), 2.0, ghost, false, 1.0, true)
	draw_line(Vector2(1, 1), Vector2(5, 5), ghost, 1.0, true)
	draw_polyline(line, ghost, 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(5, 1), Vector2(3, 5)]), ghost)
	draw_texture_rect(_pixel, box, false, ghost)

	# Text, including the outlined path the feedback pops take.
	var font := DrawUtil.display()
	draw_string_outline(font, Vector2(1, 6), "F", HORIZONTAL_ALIGNMENT_LEFT, -1,
		FeedbackScript.SIZE, FeedbackScript.OUTLINE_SHADOW, ghost)
	draw_string(font, Vector2(1, 6), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, FeedbackScript.SIZE, ghost)
	# draw_tracked goes through Font.draw_char, which is a separate path.
	DrawUtil.draw_tracked(self, DrawUtil.bold(), HeaderScript.VALUE_SIZE, Vector2(1, 6), "0", ghost)

	# The transform stack, which almost every drawing script uses.
	draw_set_transform(Vector2(1, 1), 0.1, Vector2(0.5, 0.5))
	draw_rect(box, ghost)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
