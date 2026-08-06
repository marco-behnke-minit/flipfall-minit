extends Node2D
## Run state machine, input and Minit lifecycle — the port of the original's
## src/main.js.
##
## Minit lifecycle, in order:
##   Minit.get_config_value(...)  read the drop's config off the URL query string
##   Minit.loading_done()         on the first drawn frame, never behind a button
##   Minit.report_result(...)     once, when the run ends
##
## There is no start menu, pause menu, replay menu or in-game result UI: a drop
## is one session and the host owns everything either side of it.

@onready var _surface: Node2D = $Surface
@onready var _shake_node: Node2D = $Surface/Shake
@onready var _playfield: SubViewportContainer = $Surface/Shake/Playfield
@onready var _sub_viewport: SubViewport = $Surface/Shake/Playfield/SubViewport
@onready var _dpi: Node2D = $Surface/Shake/Playfield/SubViewport/Dpi
@onready var _room: Node2D = $Surface/Shake/Playfield/SubViewport/Dpi/Room
@onready var _label: Node2D = $Surface/Shake/LevelLabel
@onready var _particles: Node2D = $Surface/Shake/Particles
@onready var _hud: Node2D = $Surface/Hud
@onready var _header: Node2D = $Surface/Header
@onready var _rewards: Node2D = $Surface/Rewards
@onready var _feedback: Node2D = $Surface/Feedback
@onready var _audio: Node = $Audio
@onready var _background: Node2D = $Background

# --- config -----------------------------------------------------------------
var _start_attempts := Const.ATTEMPTS
var _start_level := 0
var _end_level := 9
var _segment_size := 10

# --- header panels ----------------------------------------------------------
var _panel_attempts := 0
var _panel_rotations := 0
var _panel_score := 0

# --- run state --------------------------------------------------------------
var _level_index := 0
var _attempts := 3
var _score := 0
var _levels_cleared := 0
var _stats := {}

var _world: Sim
var _phase := "armed"       # armed | play | clearing | dying | entering | over
var _phase_t := 0.0
var _trail: Array[Vector2] = []
var _shake := 0.0
var _compass_pulse := 0.0
var _fade := 0.0
var _exit_cell := Vector2i(-1, -1)
var _time_ms := 0.0

# The room tumbles to keep gravity pointing screen-down. Tweened rather than
# eased-to-target so every quarter turn takes the same crisp beat.
var _world_angle := 0.0
var _tumble_from := 0.0
var _tumble_to := 0.0
var _tumble_t := 1.0

var _held_ccw := false
var _held_cw := false
var _held_pill := false

var _first_frame_done := false
var _flying_points := 0


func _ready() -> void:
	Levels.validate()

	_start_attempts = _config_number("attempts")
	# The drop plays a segment of the room list: 1-10 easy, 11-20 medium,
	# 21-30 hard, 31-40 insane. Locked against mods in meta.json.
	_start_level = mini(Levels.ALL.size(), _config_number("startLevel")) - 1
	_end_level = maxi(_start_level, mini(Levels.ALL.size(), _config_number("endLevel")) - 1)
	_segment_size = _end_level - _start_level + 1

	_level_index = _start_level
	_attempts = _start_attempts
	_stats = Score.empty_stats()

	_panel_attempts = _header.add_panel("Attempts", _start_attempts)
	_panel_rotations = _header.add_panel("Rotations", "0 / %d" % Levels.ALL[_start_level]["par"])
	_panel_score = _header.add_panel("Score", 0, "right")

	_world = Sim.new(Levels.ALL[_start_level])
	_snap_tumble(_world.gravity)
	_room.world = _world
	_push_level_label()

	get_viewport().size_changed.connect(_centre_surface)
	_centre_surface()


## Values arrive as strings (or empty), so coerce and clamp every one: the bounds
## declared in meta.json constrain the create wizard, not a hand-edited URL.
## Bounds come from Const.CONFIG so they cannot drift from what we declared.
func _config_number(key: String) -> int:
	var spec := Const.config_spec(key)
	var fallback := int(spec["value"])
	var raw := String(Minit.get_config_value(key, str(fallback)))
	var v := int(raw) if raw.is_valid_int() else fallback
	return clampi(v, int(spec["min"]), int(spec["max"]))


## `expand` reveals extra viewport area rather than letterboxing, so the design
## box is centred inside whatever the host gives us and background.gd paints the
## rest.
func _centre_surface() -> void:
	var v := get_viewport_rect().size
	_surface.position = ((v - Vector2(Const.DESIGN_W, Const.DESIGN_H)) / 2.0).floor()
	_match_playfield_to_device()


## The playfield renders through a SubViewport so an orb that leaves an
## open-sided room is clipped at the frame instead of being drawn over the
## controls. A SubViewport renders at its own pixel size, though, and would be
## upscaled — and therefore blurred — on any device whose screen is denser than
## the 960x1480 design surface. So its size tracks the real pixels-per-design-
## unit ratio, the contents are scaled up to match, and the container is scaled
## back down so the frame still occupies exactly 804 design units.
func _match_playfield_to_device() -> void:
	var canvas := get_viewport_rect().size
	if canvas.x <= 0.0:
		return
	var ratio: float = clampf(float(get_window().size.x) / canvas.x, 1.0, 3.0)
	var side := Const.PF_SIZE + Const.PIT_PAD * 2.0
	var pixels := int(ceil(side * ratio))

	_sub_viewport.size = Vector2i(pixels, pixels)
	_dpi.scale = Vector2(ratio, ratio)
	_playfield.size = Vector2(pixels, pixels)
	_playfield.scale = Vector2(1.0 / ratio, 1.0 / ratio)


# --- geometry ---------------------------------------------------------------

## The room tumbles so gravity always reads as screen-down. A square rotated 45°
## needs sqrt(2) times its own width, which the frame does not have, so shrink to
## exactly fit while turning — at rest this is 1 and costs nothing.
static func fit_scale(angle: float) -> float:
	return 1.0 / (absf(cos(angle)) + absf(sin(angle)))


## World angle that makes the given gravity direction point screen-down.
static func world_angle_for(gravity_index: int) -> float:
	return -atan2(-Sim.GRAV_X[gravity_index], Sim.GRAV_Y[gravity_index])


## Room coordinates (0..PF_SIZE) to on-screen design coordinates.
func _room_to_screen(p: Vector2) -> Vector2:
	var f := fit_scale(_world_angle)
	var d := (p - Vector2.ONE * (Const.PF_SIZE / 2.0)) * f
	var centre := Vector2(Const.PF_X, Const.PF_Y) + Vector2.ONE * (Const.PF_SIZE / 2.0)
	return centre + d.rotated(_world_angle)


func _orb_screen() -> Vector2:
	return _room_to_screen(_world.orb_pos())


func _cell_screen(c: int, r: int) -> Vector2:
	return _room_to_screen(Vector2(c * Const.CELL + Const.CELL / 2.0, r * Const.CELL + Const.CELL / 2.0))


func _start_tumble(gravity_index: int) -> void:
	var target := world_angle_for(gravity_index)
	# Take the short way round from wherever the room currently sits.
	var d := wrapf(target - _world_angle, -PI, PI)
	_tumble_from = _world_angle
	_tumble_to = _world_angle + d
	_tumble_t = 0.0


func _snap_tumble(gravity_index: int) -> void:
	_world_angle = world_angle_for(gravity_index)
	_tumble_from = _world_angle
	_tumble_to = _world_angle
	_tumble_t = 1.0


# --- level lifecycle --------------------------------------------------------

func _arm_level(index: int) -> void:
	_world = Sim.new(Levels.ALL[index])
	_room.world = _world
	_trail.clear()
	_exit_cell = Vector2i(-1, -1)
	_snap_tumble(_world.gravity)  # a new room opens upright, never mid-turn
	_phase = "armed"
	_phase_t = 0.0
	_header.set_value(_panel_rotations, "0 / %d" % Levels.ALL[index]["par"])
	_push_level_label()


func _push_level_label() -> void:
	var level: Dictionary = Levels.ALL[_level_index]
	_label.set_level(_level_index - _start_level, _segment_size, String(level["name"]),
		Const.tier_of(_level_index))


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _phase == "over":
		return
	# Touch is the input that matters; the mouse fallback is only so the game can
	# be played in the editor without a touch device.
	if event is InputEventScreenTouch:
		_on_touch(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(event.position, event.pressed)


func _on_touch(viewport_pos: Vector2, pressed: bool) -> void:
	if not pressed:
		_held_ccw = false
		_held_cw = false
		_held_pill = false
		return

	var p := viewport_pos - _surface.position

	# The glyph describes what the player sees happen to the room, not what
	# happens to the gravity vector — and those are opposites. Turning gravity
	# clockwise (Down -> Left) tips the room counter-clockwise, so the ↺ button
	# is the one that sends gravity clockwise.
	if p.distance_squared_to(Const.ROT_CCW) <= Const.ROT_R * Const.ROT_R:
		_held_ccw = true
		_do_rotate(1)
	elif p.distance_squared_to(Const.ROT_CW) <= Const.ROT_R * Const.ROT_R:
		_held_cw = true
		_do_rotate(-1)
	elif _in_pill(p):
		_held_pill = true
		if _phase != "armed":
			_do_retry()


func _in_pill(p: Vector2) -> bool:
	return absf(p.x - Const.PILL_POS.x) <= Const.PILL_SIZE.x / 2.0 \
		and absf(p.y - Const.PILL_POS.y) <= Const.PILL_SIZE.y / 2.0


func _do_rotate(dir: int) -> void:
	if _phase != "armed" and _phase != "play":
		return
	if _phase == "armed":
		_phase = "play"  # the first rotation starts the level
	_world.rotate(dir)
	_audio.start_music()  # no-op after the first call
	_audio.rotate_sfx(dir)
	_shake = 2.0
	_compass_pulse = 1.0
	_start_tumble(_world.gravity)
	# Gravity now reads as screen-down, so the whoosh always streams downward.
	_particles.whoosh(_orb_screen(), Const.ORB_R + 12.0, Vector2(0, 1), Const.C_ORB)
	_header.set_value(_panel_rotations, "%d / %d" % [_world.rotations, Levels.ALL[_level_index]["par"]])


func _do_retry() -> void:
	if _phase != "armed" and _phase != "play":
		return
	if _phase == "armed" and _world.rotations == 0:
		return  # nothing to retry yet
	_stats["retries"] = int(_stats["retries"]) + 1
	_audio.retry()
	_feedback.show_negative("Retry")
	_lose_attempt("retry")


func _lose_attempt(reason: String) -> void:
	_attempts -= 1
	_header.set_value(_panel_attempts, _attempts, true)
	if _attempts <= 0:
		_end_run()
		return
	if _attempts == 1:
		_feedback.show_neutral("Last Attempt!")
	if reason == "retry":
		_arm_level(_level_index)  # instant, no animation


# --- level outcomes ---------------------------------------------------------

func _on_level_clear() -> void:
	var level: Dictionary = Levels.ALL[_level_index]
	var bonus := Score.time_bonus(_world.time)
	var gained := Score.level_score(_world.rotations, _world.time)

	_levels_cleared += 1
	Score.record_clear(_stats, level, _world.rotations, _world.time)

	_audio.clear()
	_audio.duck_music(0.8)
	_feedback.show_positive("Fast Clear!" if bonus >= 140 else "Level Clear!")

	var from := _cell_screen(_exit_cell.x, _exit_cell.y) if _exit_cell.x >= 0 else _orb_screen()
	_particles.burst(from, Const.C_EXIT, 28, 460.0)

	_flying_points += gained
	_rewards.spawn(gained, from, _header.get_panel_position(_panel_score), 34.0,
		func() -> void:
			# The run can end while points are still in the air — _end_run()
			# already banked everything in flight, so don't add it a second time.
			if _phase == "over":
				return
			_score += gained
			_flying_points -= gained
			_header.set_value(_panel_score, _score, true))

	_phase = "clearing"
	_phase_t = 0.0


func _on_death(cause: String) -> void:
	if cause == "spike":
		_stats["spike_deaths"] = int(_stats["spike_deaths"]) + 1
		_feedback.show_negative("Spiked!")
	else:
		_stats["out_deaths"] = int(_stats["out_deaths"]) + 1
		_feedback.show_negative("Fell Out!")
	_audio.death(cause)
	_audio.duck_music(0.9)
	_particles.burst(_orb_screen(), Const.C_ORB, 30, 500.0)
	_shake = 6.0
	_phase = "dying"
	_phase_t = 0.0


func _end_run() -> void:
	if _phase == "over":
		return
	var completed := _levels_cleared == _segment_size
	_phase = "over"
	_phase_t = 0.0
	if completed:
		_audio.clear()
	else:
		_audio.run_over()
	# Music keeps playing under the host's result screen rather than cutting out.

	# Any score still mid-flight lands immediately — the host is about to take over.
	var total := Score.final_score(_score + _flying_points, _attempts)
	_score = total
	_header.set_value(_panel_score, total, true)

	# Nothing may be scheduled after this: the host takes focus immediately.
	Minit.report_result(total, {
		"flavor_text": Score.flavor_text(_stats, _levels_cleared, _segment_size),
	})


# --- loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	_time_ms += dt * 1000.0
	_phase_t += dt

	if _phase == "play":
		_simulate(dt)

	_advance_transitions()

	# --- animate ---
	_particles.update(dt)
	_shake = maxf(0.0, _shake - dt * 22.0)
	_compass_pulse = maxf(0.0, _compass_pulse - dt * 3.4)
	if _tumble_t < 1.0:
		_tumble_t = minf(1.0, _tumble_t + dt / Const.TUMBLE_SECONDS)
		var e := 1.0 - pow(1.0 - _tumble_t, 3.0)  # ease-out cubic
		_world_angle = lerp(_tumble_from, _tumble_to, e)

	if _phase == "clearing" and _exit_cell.x >= 0:
		# The orb collapses into the exit rather than vanishing where it stopped.
		var e := Vector2(_exit_cell.x * Const.CELL + Const.CELL / 2.0,
			_exit_cell.y * Const.CELL + Const.CELL / 2.0)
		var p := _world.orb_pos()
		_world.set_orb_pos(p + (e - p) * minf(1.0, dt * 14.0))

	_render()

	if not _first_frame_done:
		_first_frame_done = true
		# The host keeps a loading state over the WebView until this fires, so it
		# goes out on the first frame the player could actually act on.
		Minit.loading_done()

	if _phase == "over":
		_stop_drawing()


func _simulate(dt: float) -> void:
	_world.step(dt, Const.SUBSTEP)

	for ev in _world.events:
		match ev["type"]:
			"button":
				_audio.button()
				_audio.door()
				_feedback.show_neutral("Door Open")
				_particles.burst(_cell_screen(ev["c"], ev["r"]), Const.C_BUTTON, 14, 260.0)
			"impact":
				_audio.impact(ev["speed"], ev["kind"])
				var tint := Const.C_WALL_LIP
				if ev["kind"] == "ice":
					tint = Const.C_ICE
				elif ev["kind"] == "sticky":
					tint = Const.C_STICKY
				_particles.impact(_orb_screen(), ev["speed"], tint)
				if float(ev["speed"]) > 420.0:
					_shake = maxf(_shake, 2.0)
			"clear":
				_exit_cell = Vector2i(ev["c"], ev["r"])
	_world.events.clear()

	if _world.status == "clear":
		_on_level_clear()
	elif _world.status == "dead":
		_on_death(_world.cause)

	if _world.speed() > 40.0:
		_trail.append(_world.orb_pos())
		if _trail.size() > 14:
			_trail.remove_at(0)
	elif not _trail.is_empty():
		_trail.remove_at(0)


func _advance_transitions() -> void:
	match _phase:
		"clearing":
			# shrink 200ms, fade out 130ms, swap, fade in 130ms
			if _phase_t < 0.2:
				_fade = 0.0
			elif _phase_t < 0.33:
				_fade = (_phase_t - 0.2) / 0.13
			else:
				var next := _level_index + 1
				if next > _end_level:
					_fade = 1.0
					_end_run()
				else:
					_level_index = next
					_arm_level(next)
					_phase = "entering"
					_phase_t = 0.0
					_fade = 1.0
		"dying":
			if _phase_t < 0.3:
				_fade = 0.0
			elif _phase_t < 0.39:
				_fade = (_phase_t - 0.3) / 0.09
			else:
				_fade = 1.0
				_lose_attempt("death")
				if _phase == "dying":
					_arm_level(_level_index)
					_phase = "entering"
					_phase_t = 0.0
		"entering":
			_fade = maxf(0.0, 1.0 - _phase_t / 0.13)
			if _phase_t >= 0.13:
				_fade = 0.0
				_phase = "armed"
				_phase_t = 0.0
		"over":
			pass
		_:
			_fade = 0.0


func _render() -> void:
	if _shake > 0.05:
		_shake_node.position = Vector2(randf() - 0.5, randf() - 0.5) * _shake
	else:
		_shake_node.position = Vector2.ZERO

	_room.rotation = _world_angle
	var f := fit_scale(_world_angle)
	_room.scale = Vector2(f, f)
	_room.trail = _trail
	_room.time_ms = _time_ms
	if _phase == "clearing":
		var k: float = maxf(0.0, 1.0 - _phase_t / 0.2)
		_room.orb_scale = k
		_room.orb_alpha = k
		_room.show_orb = true
	else:
		_room.orb_scale = 1.0
		_room.orb_alpha = 1.0
		_room.show_orb = _phase != "dying"
	_room.queue_redraw()

	_hud.world_angle = _world_angle
	_hud.compass_pulse = _compass_pulse
	_hud.held_ccw = _held_ccw
	_hud.held_cw = _held_cw
	_hud.held_pill = _held_pill
	_hud.live = _phase == "armed" or _phase == "play"
	_hud.attention = _phase == "armed" and _level_index == _start_level and _world.rotations == 0
	_hud.fade = _fade
	_hud.time_ms = _time_ms


## The SDK is explicit that the host overlays its result screen and takes focus
## the moment report_result fires, so the game stops driving frames — exactly
## what the browser build does by not requesting another animation frame. The
## HUD overlays and the music are left alone; the host fades them out itself.
func _stop_drawing() -> void:
	set_process(false)
	_hud.set_process(false)
	_particles.set_process(false)
	_background.set_process(false)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
