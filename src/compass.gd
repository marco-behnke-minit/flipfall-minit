extends Node2D
## The gravity compass, in the dead centre of the SDK header bar.
##
## Lives in the top band with the header, which anchors to the top edge of the
## viewport — see Const's vertical bands.
##
## Purely a view: game.gd owns both values below and pushes them in each frame.

var world_angle := 0.0
var pulse := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


## Because the room tumbles, gravity is always screen-down — so the arrow is
## fixed and the dial rotates instead, showing how far the room has turned from
## how the player first read it. The amber tick is the room's original top.
func _draw() -> void:
	var o := Const.COMPASS
	var r := Const.COMPASS_R

	DrawUtil.stroke_arc(self, o, r, 0.0, TAU, Color(1, 1, 1, 0.16), 3.0)

	# Rotating dial: the room's orientation.
	for i in 4:
		draw_set_transform(o, world_angle + (float(i) / 4.0) * TAU, Vector2.ONE)
		if i == 0:
			draw_rect(Rect2(-4, -r - 3, 8, 13), Const.C_BUTTON)
		else:
			draw_rect(Rect2(-2, -r - 1, 4, 9), Color(1, 1, 1, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fixed gravity arrow — down is always down.
	var s := 1.0 + pulse * 0.16
	draw_set_transform(o, 0.0, Vector2(s, s))
	DrawUtil.glow(self, Vector2(0, r - 20), 20.0, Const.C_ORB,
		14.0 + pulse * 20.0, 0.6 + pulse * 1.2, 4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, r - 8), Vector2(-15, r - 30), Vector2(0, r - 24), Vector2(15, r - 30),
	]), Const.C_ORB)
	draw_rect(Rect2(-2.5, -r + 12, 5, r - 22), Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
