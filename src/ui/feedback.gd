extends Node2D
## Feedback pops — the Minit "every emotionally significant beat" flash.
##
## Reimplementation of the JS SDK's showPositiveFeedback / showNeutralFeedback /
## showNegativeFeedback for Godot (see header_bar.gd for why). Same three
## variants, same timing: pop in over 150 ms with a slight overshoot, hold ~1 s,
## fade out over 150 ms while drifting up. Non-blocking and never interactive.

const POP_IN := 0.15
const FADE_OUT := 0.15
const HOLD := 1.0
const SIZE := 110
const OUTLINE_SHADOW := 10
const OUTLINE_STROKE := 6
const MAX_WIDTH := Const.DESIGN_W * 0.85

# The JS variants are vertical gradients with a dark stroke. Godot's text drawing
# has no gradient fill, so each variant keeps its top colour plus the stroke,
# which is what carries the read at this size.
const VARIANTS := {
	"positive": {"fill": Color("#a6db67"), "stroke": Color("#346306")},
	"neutral": {"fill": Color("#fbb03a"), "stroke": Color("#77301d")},
	"negative": {"fill": Color("#c43535"), "stroke": Color("#350404")},
}

var _pops: Array[Dictionary] = []


func show_positive(text: String) -> void:
	_show(text, "positive")


func show_neutral(text: String) -> void:
	_show(text, "neutral")


func show_negative(text: String) -> void:
	_show(text, "negative")


func _show(text: String, variant: String) -> void:
	var font := DrawUtil.display()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	_pops.append({
		"text": text,
		"variant": variant,
		"age": 0.0,
		"fit": minf(1.0, MAX_WIDTH / maxf(1.0, w)),
	})


func _process(delta: float) -> void:
	if _pops.is_empty():
		return
	var i := _pops.size() - 1
	while i >= 0:
		_pops[i]["age"] = float(_pops[i]["age"]) + delta
		if float(_pops[i]["age"]) >= POP_IN + HOLD + FADE_OUT:
			_pops.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var font := DrawUtil.display()
	var centre := Vector2(Const.DESIGN_W / 2.0, Const.DESIGN_H / 2.0)

	for pop in _pops:
		var age: float = pop["age"]
		var fit: float = pop["fit"]
		var scale := fit
		var alpha := 1.0
		var offset := 0.0

		if age < POP_IN:
			var t := age / POP_IN
			# 0.5 -> 1.1 at 70% -> 1.0, matching the CSS keyframes.
			scale = fit * (lerp(0.5, 1.1, t / 0.7) if t < 0.7 else lerp(1.1, 1.0, (t - 0.7) / 0.3))
			alpha = t
		elif age > POP_IN + HOLD:
			var t := (age - POP_IN - HOLD) / FADE_OUT
			scale = fit * lerp(1.0, 0.8, t)
			alpha = 1.0 - t
			offset = -49.0 * t  # the CSS -20px, in design pixels

		var style: Dictionary = VARIANTS[pop["variant"]]
		var fill: Color = style["fill"]
		var stroke: Color = style["stroke"]
		fill.a = alpha
		stroke.a = alpha

		var w := font.get_string_size(String(pop["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
		var pos := Vector2(-w / 2.0, DrawUtil.middle_baseline(font, SIZE, 0.0))

		draw_set_transform(centre + Vector2(0, offset), 0.0, Vector2(scale, scale))
		draw_string_outline(font, pos + Vector2(0, 8), String(pop["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, OUTLINE_SHADOW, Color(0, 0, 0, alpha))
		draw_string_outline(font, pos, String(pop["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, OUTLINE_STROKE, stroke)
		draw_string(font, pos, String(pop["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, fill)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
