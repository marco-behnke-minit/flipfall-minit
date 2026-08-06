extends Node2D
## Decorative backdrop.
##
## The one node that reads the live viewport. `expand` reveals extra area beyond
## the 960x1480 design box rather than letterboxing, and anything the game does
## not paint there shows up as an unlit strip in the clear colour — so this fills
## get_viewport_rect() edge to edge, whatever aspect the host hands us.

var _time_ms := 0.0
var _gradient: GradientTexture2D


func _ready() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color("#23242D"), Const.C_BG, Color("#15161B")])

	_gradient = GradientTexture2D.new()
	_gradient.gradient = g
	_gradient.width = 128
	_gradient.height = 128
	# Mirrors the canvas2d gradient's (0,0) -> (w*0.4, h) axis.
	_gradient.fill_from = Vector2(0, 0)
	_gradient.fill_to = Vector2(0.4, 1.0)

	get_viewport().size_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_time_ms += delta * 1000.0
	queue_redraw()


func _draw() -> void:
	var v := get_viewport_rect().size
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, v), false)

	# Slow drifting geometry, well below the playfield's contrast level.
	var t := _time_ms
	for i in 7:
		var p := float(i) / 7.0
		var x: float = v.x * (0.12 + 0.76 * fmod(p * 1.7, 1.0))
		var y: float = v.y * (fmod(p * 2.3 + t * 0.006 * (0.4 + p), 1.2) - 0.1)
		var s: float = 90.0 + p * 190.0
		var col := Const.C_ORB if i % 3 == 0 else Const.C_DOOR
		col.a = 0.05
		draw_set_transform(Vector2(x, y), t * 0.00012 * (1.0 if i % 2 else -1.0) + p * 3.0, Vector2.ONE)
		DrawUtil.stroke_rounded_rect(self, Rect2(-s / 2.0, -s / 2.0, s, s), 22.0, col, 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
