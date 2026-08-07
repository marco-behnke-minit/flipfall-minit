class_name Sim
extends RefCounted
## Deterministic orb simulation. No node or rendering access anywhere in this
## file — it is a straight port of the JS project's src/physics.js, which the
## solver ran headless under Node to prove every room solvable. Keeping it pure
## means those proofs still describe this build.
##
## The orb's position and velocity are kept as bare floats rather than a Vector2
## on purpose: Vector2 is 32-bit in a standard Godot build, and the original runs
## in JavaScript doubles. Halving the mantissa in a loop this chaotic drifts the
## trajectory enough to change whether a tight room is solvable at all, so every
## number below stays a GDScript float (a double). tools/trace.gd diffs this
## against the JS for all forty rooms.
##
## Coordinates here are playfield-local: (0,0) .. (PF_SIZE, PF_SIZE).

## Gravity states, in clockwise order: dir=+1 steps clockwise through them
## (Down -> Left -> Up -> Right). Note that the CCW *button* sends dir=+1,
## because turning gravity clockwise tips the room counter-clockwise — see
## game.gd.
const GRAV_X: Array[float] = [0.0, -1.0, 0.0, 1.0]
const GRAV_Y: Array[float] = [1.0, 0.0, -1.0, 0.0]
const GRAV_NAMES: Array[String] = ["down", "left", "up", "right"]
const DOWN := 0

# Surface materials. `k` is a per-second exponential velocity decay, so an orb
# landing at speed v skids roughly v/k pixels before settling. At MAX_SPEED that
# is ~5 cells on stone, most of the room on ice, and half a cell on sticky —
# which is the whole point of the two modifiers.
const K_WALL := 3.05
const E_WALL := 0.1
const K_ICE := 0.25
const E_ICE := 0.05
const K_STICKY := 3.0
const E_STICKY := 0.0

var grid: Array = []            # Array[Array[String]], one single-char String per cell
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var gravity: int = DOWN
var buttons: Dictionary = {}    # set of pressed button chars
var doors_open: Dictionary = {} # set of opened door chars
var status: String = "playing"  # "playing" | "clear" | "dead"
var cause: String = ""          # "spike" | "out" | "stuck"
var sticky_time: float = 0.0    # unbroken seconds touching sticky; STICKY_DEATH is fatal
var contact: String = ""        # material kind touched this step, for sfx / rendering
var resting: bool = false
var events: Array[Dictionary] = []  # drained by the caller each frame
var time: float = 0.0
var rotations: int = 0


static func door_for(btn: String) -> String:
	return char(btn.unicode_at(0) - 48 + 96)


static func is_door(ch: String) -> bool:
	return ch >= "a" and ch <= "c"


static func is_button(ch: String) -> bool:
	return ch >= "1" and ch <= "3"


static func is_solid_char(ch: String) -> bool:
	return ch == "#" or ch == "I" or ch == "T"


## JavaScript's Math.hypot, reproduced exactly.
##
## It is not sqrt(a*a + b*b): the spec scales by the larger magnitude and sums
## with Kahan compensation, so it lands a unit in the last place away from the
## naive form. That sounds academic, but this simulation runs ~1,400 substeps per
## room with contact resolution in the loop, and a 1-ULP seed drift grows into a
## visible trajectory difference by the end. tools/trace.gd is what caught it.
static func hypot(a: float, b: float) -> float:
	var ax := absf(a)
	var bx := absf(b)
	var m: float = maxf(ax, bx)
	if m == 0.0:
		return 0.0
	var total := 0.0
	var compensation := 0.0
	for n in [ax / m, bx / m]:
		var summand: float = n * n - compensation
		var preliminary: float = total + summand
		compensation = (preliminary - total) - summand
		total = preliminary
	return m * sqrt(total)


func _init(level: Dictionary) -> void:
	var start := Vector2i(-1, -1)
	for r in Const.GRID:
		var row: Array = []
		var src := String(level["map"][r])
		for c in Const.GRID:
			var ch := src[c]
			if ch == "O":
				start = Vector2i(c, r)
				ch = "."  # the spawn marker is not a tile
			row.append(ch)
		grid.append(row)
	if start.x < 0:
		push_error("level \"%s\" has no orb start" % level["name"])
		start = Vector2i(1, 1)

	x = start.x * Const.CELL + Const.CELL / 2.0
	y = start.y * Const.CELL + Const.CELL / 2.0

	# A cell-centred spawn floats CELL/2 - ORB_R above the surface below it, so
	# the orb's first sideways move would glide with no contact and skip friction
	# entirely. Drop it onto its supporting surface first, so the frozen opening
	# state the player sees is a genuine resting state.
	var i := 0
	while i < 480 and not resting and status == "playing":
		_substep(1.0 / 240.0)
		i += 1
	vx = 0.0
	vy = 0.0
	status = "playing"
	cause = ""
	sticky_time = 0.0  # the settle loop may have parked it on sticky; that is not a death
	events.clear()
	time = 0.0
	rotations = 0


# --- view helpers -----------------------------------------------------------

func orb_pos() -> Vector2:
	return Vector2(x, y)


func set_orb_pos(p: Vector2) -> void:
	x = p.x
	y = p.y


func speed() -> float:
	return hypot(vx, vy)


# --- world queries ----------------------------------------------------------

func tile_at(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= Const.GRID or r >= Const.GRID:
		return ""  # outside the grid is void
	return grid[r][c]


func solid_at(ch: String) -> bool:
	if ch == "#" or ch == "I" or ch == "T":
		return true
	if is_door(ch):
		return not doors_open.has(ch)
	return false


## Does the orb overlap cell (c,r), shrunk by `inset` on every side?
func _overlaps_cell(c: int, r: int, inset: float) -> bool:
	var x0 := c * Const.CELL + inset
	var y0 := r * Const.CELL + inset
	var x1 := (c + 1) * Const.CELL - inset
	var y1 := (r + 1) * Const.CELL - inset
	var nx: float = clampf(x, x0, x1)
	var ny: float = clampf(y, y0, y1)
	var dx := x - nx
	var dy := y - ny
	return dx * dx + dy * dy < Const.ORB_R * Const.ORB_R


func rotate(dir: int) -> void:
	if status != "playing":
		return
	gravity = (gravity + (1 if dir > 0 else 3)) % 4
	rotations += 1
	events.append({"type": "rotate", "dir": dir})


## Advance one fixed substep. Call via step(), not directly.
func _substep(dt: float) -> void:
	vx += GRAV_X[gravity] * Const.GRAVITY * dt
	vy += GRAV_Y[gravity] * Const.GRAVITY * dt

	var sp := hypot(vx, vy)
	if sp > Const.MAX_SPEED:
		vx = vx / sp * Const.MAX_SPEED
		vy = vy / sp * Const.MAX_SPEED

	x += vx * dt
	y += vy * dt

	# --- collide against every solid tile the orb's AABB touches ---
	var c0 := int(floor((x - Const.ORB_R) / Const.CELL))
	var c1 := int(floor((x + Const.ORB_R) / Const.CELL))
	var r0 := int(floor((y - Const.ORB_R) / Const.CELL))
	var r1 := int(floor((y + Const.ORB_R) / Const.CELL))

	var contact_k := 0.0
	var touched := false
	var hardest := 0.0     # impact speed, for collision sfx
	var contact_kind := ""

	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch := tile_at(c, r)
			if ch == "" or not solid_at(ch):
				continue

			var rx := c * Const.CELL
			var ry := r * Const.CELL
			var near_x: float = clampf(x, rx, rx + Const.CELL)
			var near_y: float = clampf(y, ry, ry + Const.CELL)
			var dx := x - near_x
			var dy := y - near_y
			var d := hypot(dx, dy)

			var nx := 0.0
			var ny := 0.0
			var pen := 0.0
			if d > 1e-6:
				if d >= Const.ORB_R:
					continue
				nx = dx / d
				ny = dy / d
				pen = Const.ORB_R - d
			else:
				# Centre is inside the tile — eject along the shallowest axis.
				var left := x - rx
				var right := rx + Const.CELL - x
				var top := y - ry
				var bottom := ry + Const.CELL - y
				var m: float = min(min(left, right), min(top, bottom))
				if m == left:
					nx = -1.0; ny = 0.0; pen = Const.ORB_R + left
				elif m == right:
					nx = 1.0; ny = 0.0; pen = Const.ORB_R + right
				elif m == top:
					nx = 0.0; ny = -1.0; pen = Const.ORB_R + top
				else:
					nx = 0.0; ny = 1.0; pen = Const.ORB_R + bottom

			x += nx * pen
			y += ny * pen

			var mat_k := K_WALL
			var mat_e := E_WALL
			var mat_kind := "wall"
			if ch == "I":
				mat_k = K_ICE; mat_e = E_ICE; mat_kind = "ice"
			elif ch == "T":
				mat_k = K_STICKY; mat_e = E_STICKY; mat_kind = "sticky"

			var vn := vx * nx + vy * ny
			if vn < 0.0:
				if -vn > hardest:
					hardest = -vn
				vx -= (1.0 + mat_e) * vn * nx
				vy -= (1.0 + mat_e) * vn * ny
			touched = true
			if mat_k > contact_k:
				contact_k = mat_k
				contact_kind = mat_kind

	# Surface drag. The normal component is already resolved above, so decaying
	# the whole velocity is equivalent to tangential friction and stays stable.
	if touched:
		var f := exp(-contact_k * dt)
		vx *= f
		vy *= f

	contact = contact_kind
	sticky_time = sticky_time + dt if contact_kind == "sticky" else 0.0
	resting = touched and hypot(vx, vy) < Const.REST_SPEED
	if hardest > 150.0:
		events.append({"type": "impact", "speed": hardest, "kind": contact_kind})

	# --- hazards and triggers ---
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var ch := tile_at(c, r)
			if ch == "":
				continue

			if ch == "^":
				if _overlaps_cell(c, r, 12.0):
					status = "dead"
					cause = "spike"
					return
			elif is_button(ch):
				if not buttons.has(ch) and _overlaps_cell(c, r, 6.0):
					buttons[ch] = true
					doors_open[door_for(ch)] = true
					events.append({"type": "button", "ch": ch, "c": c, "r": r})
			elif ch == "E":
				var cx := c * Const.CELL + Const.CELL / 2.0
				var cy := r * Const.CELL + Const.CELL / 2.0
				if hypot(x - cx, y - cy) < Const.CELL * 0.44:
					status = "clear"
					events.append({"type": "clear", "c": c, "r": r})
					return

	# --- held too long in the tar ---
	# After the exit check, so touching E on the fatal step still counts as a win.
	if sticky_time >= Const.STICKY_DEATH:
		status = "dead"
		cause = "stuck"
		return

	# --- fell out of the level ---
	var pad := Const.CELL * 1.5
	var span := Const.GRID * Const.CELL
	if x < -pad or y < -pad or x > span + pad or y > span + pad:
		status = "dead"
		cause = "out"


## Advance `dt` seconds using fixed substeps.
func step(dt: float, substep_size: float) -> void:
	if status != "playing":
		return
	var remaining: float = min(dt, 0.1)  # never simulate more than 100ms per frame
	while remaining > 0.0 and status == "playing":
		var s: float = min(substep_size, remaining)
		_substep(s)
		time += s
		remaining -= s
