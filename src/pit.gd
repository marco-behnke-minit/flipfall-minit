extends Node2D
## The recessed frame the room sits in. Never rotates.
##
## Drawn inside the playfield SubViewport, underneath room_view, so the viewport
## clips anything that leaves the frame — which is exactly what happens when an
## open-sided room lets the orb fall out of the level.

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2.ONE * (Const.PF_SIZE + Const.PIT_PAD * 2.0))
	DrawUtil.fill_rounded_rect(self, rect, 20.0, Const.C_PIT)
	DrawUtil.stroke_rounded_rect(self, rect, 20.0, Color(1, 1, 1, 0.06), 3.0)
