extends Node2D
## The transition fade.
##
## Covers the whole viewport, not just the design box: `expand` reveals extra
## area beside the 960x1480 surface, and fading only the design box would leave
## lit bands there on every level change and death.
##
## Sits above the playfield and the controls but below the header, feedback and
## rewards — the same layering the browser build gets for free, where those three
## are DOM elements over the game canvas.

var amount := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if amount <= 0.0:
		return
	var c := Const.C_BG
	c.a = minf(1.0, amount)
	# This node is only translated, never scaled, so viewport extents map
	# one-to-one into local space.
	var origin := get_global_transform().affine_inverse() * Vector2.ZERO
	draw_rect(Rect2(origin, get_viewport_rect().size), c)
