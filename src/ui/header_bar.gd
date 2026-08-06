extends Node2D
## Header bar — the standard Minit HUD.
##
## The Godot SDK is the lifecycle facade only (`Minit.loading_done`,
## `report_result`, `get_config_value`, `get_user_data`); it has no counterpart
## to the JS SDK's `@minit-games/sdk/ui` module. So the three UI pieces this game
## uses are reimplemented here, in header_bar.gd / feedback.gd / rewards.gd,
## against the same contract the JS module documents: fixed Lato-ish styling,
## label above value, score right and secondary stats left, plain-text labels and
## no emoji, and an animated count-up on value changes.

const LABEL_SIZE := 36
const VALUE_SIZE := 48
const LINE_HEIGHT := 1.2
const PANEL_GAP := 12.0
const PANEL_MIN_W := 60.0
const COUNT_UP_SECONDS := 0.3

var _panels: Array[Dictionary] = []
var _dirty := true


func _process(delta: float) -> void:
	var animating := false
	for p in _panels:
		if p["anim_t"] < 1.0:
			p["anim_t"] = minf(1.0, float(p["anim_t"]) + delta / COUNT_UP_SECONDS)
			var eased: float = 1.0 - pow(1.0 - float(p["anim_t"]), 3.0)  # ease-out cubic
			p["shown"] = str(int(round(lerp(float(p["anim_from"]), float(p["anim_to"]), eased))))
			animating = true
	if animating or _dirty:
		_dirty = false
		queue_redraw()


## Returns the panel's index, which is the handle for every other call.
func add_panel(label: String, value: Variant, align: String = "left") -> int:
	_panels.append({
		"label": label,
		"value": value,
		"shown": str(value),
		"align": align,
		"anim_t": 1.0,
		"anim_from": 0.0,
		"anim_to": 0.0,
		"x": 0.0,
		"w": 0.0,
	})
	_layout()
	return _panels.size() - 1


func set_value(index: int, value: Variant, animate: bool = false) -> void:
	var p := _panels[index]
	var old = p["value"]
	p["value"] = value
	if animate and (old is int or old is float) and (value is int or value is float):
		p["anim_from"] = float(old)
		p["anim_to"] = float(value)
		p["anim_t"] = 0.0
	else:
		p["anim_t"] = 1.0
		p["shown"] = str(value)
	_layout()


func get_value(index: int) -> Variant:
	return _panels[index]["value"]


## Centre of the panel's value text, in design coordinates — the target flying
## rewards aim at.
func get_panel_position(index: int) -> Vector2:
	var p := _panels[index]
	return Vector2(float(p["x"]) + float(p["w"]) / 2.0, _value_centre_y())


func _label_centre_y() -> float:
	return Const.HUD_Y + LABEL_SIZE * LINE_HEIGHT / 2.0


func _value_centre_y() -> float:
	return Const.HUD_Y + LABEL_SIZE * LINE_HEIGHT + VALUE_SIZE * LINE_HEIGHT / 2.0


func _layout() -> void:
	var label_font := DrawUtil.regular()
	var value_font := DrawUtil.bold()
	for p in _panels:
		var lw := label_font.get_string_size(String(p["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var vw := value_font.get_string_size(String(p["shown"]), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_SIZE).x
		p["w"] = maxf(PANEL_MIN_W, maxf(lw, vw))

	var x := Const.HUD_PAD
	for p in _panels:
		if p["align"] != "right":
			p["x"] = x
			x += float(p["w"]) + PANEL_GAP

	# Right group is packed against the far inset, in declaration order.
	var right: Array[Dictionary] = []
	for p in _panels:
		if p["align"] == "right":
			right.append(p)
	var total := 0.0
	for p in right:
		total += float(p["w"]) + PANEL_GAP
	var rx := Const.DESIGN_W - Const.HUD_PAD - maxf(0.0, total - PANEL_GAP)
	for p in right:
		p["x"] = rx
		rx += float(p["w"]) + PANEL_GAP

	_dirty = true


func _draw() -> void:
	var label_font := DrawUtil.regular()
	var value_font := DrawUtil.bold()
	for p in _panels:
		var cx := float(p["x"]) + float(p["w"]) / 2.0
		DrawUtil.draw_tracked_shadowed(self, label_font, LABEL_SIZE,
			Vector2(cx, DrawUtil.middle_baseline(label_font, LABEL_SIZE, _label_centre_y())),
			String(p["label"]), Const.C_HUD, 0.0, 0.5)
		DrawUtil.draw_tracked_shadowed(self, value_font, VALUE_SIZE,
			Vector2(cx, DrawUtil.middle_baseline(value_font, VALUE_SIZE, _value_centre_y())),
			String(p["shown"]), Const.C_HUD, 0.0, 0.5)
