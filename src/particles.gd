extends Node2D
## Tiny particle pool — sparks on impact, bursts on clear/death, gravity whoosh.
## Drawn in design-surface coordinates, outside the room's tumble transform, so
## a burst never rotates with the room.

const MAX_PARTICLES := 220

var _pool: Array[Dictionary] = []
var _cursor := 0


func _ready() -> void:
	for i in MAX_PARTICLES:
		_pool.append({"alive": false})


func _take() -> Dictionary:
	for i in MAX_PARTICLES:
		var p: Dictionary = _pool[(_cursor + i) % MAX_PARTICLES]
		if not p["alive"]:
			_cursor = (_cursor + i + 1) % MAX_PARTICLES
			return p
	_cursor = (_cursor + 1) % MAX_PARTICLES
	return _pool[_cursor]  # pool exhausted — recycle the oldest slot


func _spawn(pos: Vector2, v: Vector2, life: float, radius: float, color: Color,
		drag: float = 2.4, shape: String = "dot", spin: float = 0.0, rot: float = 0.0) -> void:
	var p := _take()
	p["alive"] = true
	p["pos"] = pos
	p["vel"] = v
	p["life"] = life
	p["age"] = 0.0
	p["r"] = radius
	p["color"] = color
	p["drag"] = drag
	p["shape"] = shape
	p["spin"] = spin
	p["rot"] = rot


## Sparks kicked out along a surface when the orb lands hard.
func impact(pos: Vector2, speed: float, color: Color) -> void:
	var n: int = mini(9, 2 + int(round(speed / 110.0)))
	for i in n:
		var a := randf() * TAU
		var s := 60.0 + randf() * speed * 0.5
		_spawn(pos, Vector2(cos(a), sin(a)) * s, 0.22 + randf() * 0.2, 2.0 + randf() * 3.0, color)


func burst(pos: Vector2, color: Color, count: int = 24, power: float = 420.0) -> void:
	for i in count:
		var a := (float(i) / count) * TAU + randf() * 0.4
		var s := power * (0.45 + randf() * 0.75)
		_spawn(pos, Vector2(cos(a), sin(a)) * s, 0.4 + randf() * 0.45, 3.0 + randf() * 5.0,
			color, 1.7, "shard" if randf() < 0.5 else "dot", (randf() - 0.5) * 14.0, randf() * PI)


## Ring of streaks flung in the new gravity direction on a rotation. Because the
## room tumbles, that direction is always screen-down.
func whoosh(centre: Vector2, radius: float, g: Vector2, color: Color) -> void:
	for i in 14:
		var a := (float(i) / 14.0) * TAU
		var dir := Vector2(cos(a), sin(a))
		_spawn(centre + dir * radius, g * 300.0 + dir * 70.0,
			0.3 + randf() * 0.18, 2.0 + randf() * 2.5, color, 3.2)


func update(dt: float) -> void:
	for p in _pool:
		if not p["alive"]:
			continue
		p["age"] = float(p["age"]) + dt
		if float(p["age"]) >= float(p["life"]):
			p["alive"] = false
			continue
		var f: float = exp(-float(p["drag"]) * dt)
		p["vel"] = Vector2(p["vel"]) * f
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * dt
		p["rot"] = float(p["rot"]) + float(p["spin"]) * dt
	queue_redraw()


func _draw() -> void:
	for p in _pool:
		if not p["alive"]:
			continue
		var t: float = 1.0 - float(p["age"]) / float(p["life"])
		var col: Color = p["color"]
		col.a = t * t
		var pos: Vector2 = p["pos"]
		if p["shape"] == "shard":
			var s: float = float(p["r"]) * t * 1.6
			draw_set_transform(pos, float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-s, -s * 0.4, s * 2.0, s * 0.8), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(pos, float(p["r"]) * t, col)
