extends Node2D
## The room and the orb, drawn in room coordinates (0..PF_SIZE).
##
## This node lives inside the playfield SubViewport and carries the tumble: its
## rotation is the room's world angle and its scale is the shrink that keeps a
## rotated square inside a square frame. Everything below therefore draws as if
## the room were upright, which is also how the level data reads.

const HALF := Const.PF_SIZE / 2.0

var world: Sim = null
var trail: Array[Vector2] = []
var orb_scale := 1.0
var orb_alpha := 1.0
var show_orb := true
var time_ms := 0.0

var _ice_stripes: Array[PackedVector2Array] = []
var _orb_tex: ImageTexture
var _orb_tex_radius := 0.0  # orb radius in texture pixels


func _ready() -> void:
	position = Vector2(HALF + Const.PIT_PAD, HALF + Const.PIT_PAD)
	_build_ice_stripes()
	_build_orb_texture()


## Room point -> this node's local space.
static func room_to_local(p: Vector2) -> Vector2:
	return p - Vector2(HALF, HALF)


# --- one-off art -----------------------------------------------------------

func _build_ice_stripes() -> void:
	# Three diagonal highlights per ice cell, clipped to the cell so a stripe
	# never bleeds into the air beside it (canvas2d did this with ctx.clip()).
	var cell := PackedVector2Array([
		Vector2(0, 0), Vector2(Const.CELL, 0),
		Vector2(Const.CELL, Const.CELL), Vector2(0, Const.CELL),
	])
	for i in range(-1, 2):
		var a := Vector2(i * 26 + 6, Const.CELL)
		var b := Vector2(i * 26 + 34, 0)
		var n := (b - a).normalized().orthogonal() * 2.5
		var quad := PackedVector2Array([a + n, b + n, b - n, a - n])
		for piece in Geometry2D.intersect_polygons(quad, cell):
			_ice_stripes.append(piece)


func _build_orb_texture() -> void:
	# The orb is the brightest thing on screen: a lit sphere plus a soft halo.
	# Baked into one texture so the per-frame cost is a single textured quad
	# instead of a stack of translucent discs.
	var size := 128
	var centre := Vector2(size / 2.0, size / 2.0)
	var core := 44.0
	var halo := 63.0
	_orb_tex_radius = core

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var lit := centre + Vector2(-0.3, -0.35) * core
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(centre)
			var col: Color
			if d <= core:
				var t: float = clampf((p.distance_to(lit) - core * 0.15) / (core * 0.85), 0.0, 1.0)
				if t < 0.4:
					col = Color.WHITE.lerp(Const.C_ORB, t / 0.4)
				else:
					col = Const.C_ORB.lerp(Const.C_ORB_DEEP, (t - 0.4) / 0.6)
				col.a = clampf(core - d, 0.0, 1.0)  # one-pixel edge feather
			else:
				col = Const.C_ORB
				var f: float = clampf(1.0 - (d - core) / (halo - core), 0.0, 1.0)
				col.a = 0.4 * f * f
			img.set_pixel(x, y, col)
	_orb_tex = ImageTexture.create_from_image(img)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if world == null:
		return
	_draw_solids()
	_draw_wall_lips()
	_draw_interactive()
	if show_orb:
		_draw_orb()


func _draw_solids() -> void:
	for r in Const.GRID:
		for c in Const.GRID:
			var ch: String = world.grid[r][c]
			if not Sim.is_solid_char(ch):
				continue
			var o := room_to_local(Vector2(c * Const.CELL, r * Const.CELL))
			var rect := Rect2(o, Vector2(Const.CELL, Const.CELL))
			if ch == "I":
				draw_rect(rect, Const.C_ICE)
				for stripe in _ice_stripes:
					var moved := PackedVector2Array()
					for p in stripe:
						moved.append(p + o)
					draw_colored_polygon(moved, Color(1, 1, 1, 0.85))
			elif ch == "T":
				draw_rect(rect, Const.C_STICKY)
				for a in 3:
					for b in 3:
						draw_circle(o + Vector2(14 + a * 16, 14 + b * 16), 3.4, Color(1, 1, 1, 0.28))
			else:
				draw_rect(rect, Const.C_WALL)


func _draw_wall_lips() -> void:
	# A lit lip on every solid face that meets open space, so the walls read as
	# one geometric mass rather than a grid of tiles.
	for r in Const.GRID:
		for c in Const.GRID:
			if world.grid[r][c] != "#":
				continue
			var o := room_to_local(Vector2(c * Const.CELL, r * Const.CELL))
			if _open(c, r - 1):
				draw_rect(Rect2(o, Vector2(Const.CELL, 4)), Const.C_WALL_LIP)
			if _open(c, r + 1):
				draw_rect(Rect2(o + Vector2(0, Const.CELL - 4), Vector2(Const.CELL, 4)), Const.C_WALL_LIP)
			if _open(c - 1, r):
				draw_rect(Rect2(o, Vector2(4, Const.CELL)), Const.C_WALL_LIP)
			if _open(c + 1, r):
				draw_rect(Rect2(o + Vector2(Const.CELL - 4, 0), Vector2(4, Const.CELL)), Const.C_WALL_LIP)


func _open(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= Const.GRID or r >= Const.GRID:
		return false
	return not Sim.is_solid_char(world.grid[r][c])


func _draw_interactive() -> void:
	for r in Const.GRID:
		for c in Const.GRID:
			var ch: String = world.grid[r][c]
			var o := room_to_local(Vector2(c * Const.CELL, r * Const.CELL))
			if ch == "^":
				_draw_spike(o)
			elif Sim.is_button(ch):
				_draw_button(o, world.buttons.has(ch))
			elif Sim.is_door(ch):
				_draw_door(o, world.doors_open.has(ch))
			elif ch == "E":
				_draw_exit(o)


func _draw_spike(o: Vector2) -> void:
	var centre := o + Vector2(Const.CELL, Const.CELL) / 2.0
	var pulse := 1.0 + sin(time_ms * 0.004) * 0.05
	var outer := 25.0 * pulse
	var inner := 9.5
	var pts := PackedVector2Array()
	for i in 16:
		var a := (float(i) / 16.0) * TAU - PI / 2.0
		var rad := outer if i % 2 == 0 else inner
		pts.append(centre + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Const.C_SPIKE)
	draw_circle(centre, 5.5, Color(0, 0, 0, 0.34))


func _draw_button(o: Vector2, pressed: bool) -> void:
	var centre := o + Vector2(Const.CELL, Const.CELL) / 2.0
	if pressed:
		draw_circle(centre, 20.0, Const.C_BUTTON)
		var tick := PackedVector2Array([
			centre + Vector2(-8, 1), centre + Vector2(-2, 7), centre + Vector2(9, -6),
		])
		draw_polyline(tick, Color(0, 0, 0, 0.35), 5.0, true)
	else:
		var pulse := 1.0 + sin(time_ms * 0.005) * 0.07
		DrawUtil.stroke_arc(self, centre, 19.0 * pulse, 0.0, TAU, Const.C_BUTTON, 6.0)
		draw_circle(centre, 6.0, Const.C_BUTTON)


func _draw_door(o: Vector2, open: bool) -> void:
	if open:
		var col := Const.C_DOOR
		col.a = 0.4
		_dashed_rounded_rect(Rect2(o + Vector2(5, 5), Vector2(Const.CELL - 10, Const.CELL - 10)), 8.0, col, 3.0, 9.0, 8.0)
		return
	draw_rect(Rect2(o, Vector2(Const.CELL, Const.CELL)), Const.C_DOOR)
	for i in 3:
		draw_rect(Rect2(o + Vector2(9 + i * 16, 7), Vector2(7, Const.CELL - 14)), Color(0, 0, 0, 0.22))


func _dashed_rounded_rect(rect: Rect2, radius: float, color: Color, width: float, on: float, off: float) -> void:
	var pts := DrawUtil.rounded_rect(rect, radius)
	pts.append(pts[0])
	var travelled := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var walked := 0.0
		while walked < seg:
			var cycle := fmod(travelled + walked, on + off)
			if cycle < on:
				var run: float = min(on - cycle, seg - walked)
				draw_line(a.lerp(b, walked / seg), a.lerp(b, (walked + run) / seg), color, width, true)
				walked += run
			else:
				walked += min(on + off - cycle, seg - walked)
		travelled += seg


func _draw_exit(o: Vector2) -> void:
	var centre := o + Vector2(Const.CELL, Const.CELL) / 2.0
	var p := (sin(time_ms * 0.0035) + 1.0) / 2.0
	DrawUtil.glow(self, centre, 22.0, Const.C_EXIT, 22.0 + p * 16.0, 0.7 + p * 0.5)
	DrawUtil.stroke_arc(self, centre, 22.0, 0.0, TAU, Const.C_EXIT, 5.0)
	var inner := Const.C_EXIT
	inner.a = 0.45 + p * 0.35
	DrawUtil.stroke_arc(self, centre, 13.0 - p * 3.0, 0.0, TAU, inner, 5.0)
	draw_circle(centre, 5.0 + p * 2.5, Const.C_EXIT)


func _draw_orb() -> void:
	var p := room_to_local(world.orb_pos())

	# Cosmetic trail, for readability at speed.
	for i in trail.size():
		var f := float(i + 1) / trail.size()
		var col := Const.C_ORB
		col.a = orb_alpha * f * 0.34
		draw_circle(room_to_local(trail[i]), Const.ORB_R * f * 0.82 * orb_scale, col)

	var r := Const.ORB_R * orb_scale
	var span := r * (_orb_tex.get_width() / 2.0) / _orb_tex_radius
	draw_texture_rect(_orb_tex, Rect2(p - Vector2(span, span), Vector2(span, span) * 2.0),
		false, Color(1, 1, 1, orb_alpha))
