extends Node2D
## Flying rewards — the Minit "one icon per point" collection animation.
##
## Reimplementation of the JS SDK's spawnRewards for Godot (see header_bar.gd for
## why). Same clustering rule, so a 1,150-point room clear reads as five large
## bundles rather than a thousand circles, and the same spawn -> scatter -> hold
## -> fly timeline, with the callback firing at 70% of the flight so the score
## panel ticks over while the icons are still visible.

const SPAWN_DRIFT := 0.4
const HOLD := 0.35
const ANTICIPATE := 0.08
const FLY := 0.45
const ARRIVE_AT := 0.7   # fraction of the flight
const STAGGER := 0.05
const SCATTER := 30.0
const DEFAULT_COLOR := Color("#f7931e")

var _icons: Array[Dictionary] = []
var _pending: Array[Dictionary] = []


## Cluster a count into denominations to keep the icon count at five or fewer
## while still representing one icon per point.
static func _cluster(count: int) -> Array:
	if count <= 5:
		var single := []
		for i in count:
			single.append(1.0)
		return single
	var result := []
	var remaining := count
	for denom in [[125, 2.2], [25, 1.6], [5, 1.2], [1, 1.0]]:
		while remaining >= int(denom[0]) and result.size() < 5:
			result.append(float(denom[1]))
			remaining -= int(denom[0])
		if result.size() >= 5:
			break
	while remaining > 0 and result.size() < 5:
		result.append(1.0)
		remaining -= 1
	return result


func spawn(count: int, start: Vector2, target: Vector2, size: float, on_all_arrive: Callable) -> void:
	var scales := _cluster(count)
	if scales.is_empty():
		if on_all_arrive.is_valid():
			on_all_arrive.call()
		return

	var shared := {"total": scales.size(), "arrived": 0, "cb": on_all_arrive}
	for i in scales.size():
		_pending.append({
			"at": i * STAGGER,
			"scale": float(scales[i]),
			"start": start + Vector2(randf() - 0.5, randf() - 0.5) * 20.0,
			"target": target,
			"size": size,
			"shared": shared,
		})


func _process(delta: float) -> void:
	# Note the state *before* this frame's removals: when the last icon retires we
	# still owe one more redraw, otherwise the frame that drew it stays on screen
	# forever.
	var had_icons := not _icons.is_empty()

	var i := _pending.size() - 1
	while i >= 0:
		_pending[i]["at"] = float(_pending[i]["at"]) - delta
		if float(_pending[i]["at"]) <= 0.0:
			_launch(_pending[i])
			_pending.remove_at(i)
		i -= 1

	i = _icons.size() - 1
	while i >= 0:
		var icon := _icons[i]
		icon["age"] = float(icon["age"]) + delta
		var age: float = icon["age"]
		var fly_start: float = SPAWN_DRIFT + HOLD + ANTICIPATE

		if not icon["arrived"] and age >= fly_start + FLY * ARRIVE_AT:
			icon["arrived"] = true
			var shared: Dictionary = icon["shared"]
			shared["arrived"] = int(shared["arrived"]) + 1
			if int(shared["arrived"]) >= int(shared["total"]):
				var cb: Callable = shared["cb"]
				if cb.is_valid():
					cb.call()

		if age >= fly_start + FLY:
			_icons.remove_at(i)
		i -= 1

	if had_icons or not _icons.is_empty():
		queue_redraw()


func _launch(spec: Dictionary) -> void:
	var a := randf() * TAU
	var d := SCATTER * (0.5 + randf() * 0.5)
	_icons.append({
		"age": 0.0,
		"start": spec["start"],
		"scatter": Vector2(spec["start"]) + Vector2(cos(a), sin(a)) * d,
		"target": spec["target"],
		"size": float(spec["size"]) * float(spec["scale"]),
		"shared": spec["shared"],
		"arrived": false,
	})


func _draw() -> void:
	for icon in _icons:
		var age: float = icon["age"]
		var fly_start: float = SPAWN_DRIFT + HOLD + ANTICIPATE
		var pos: Vector2
		var scale := 1.0
		var alpha := 1.0

		if age < SPAWN_DRIFT:
			var t := age / SPAWN_DRIFT
			var eased := 1.0 - pow(1.0 - t, 3.0)
			pos = Vector2(icon["start"]).lerp(Vector2(icon["scatter"]), eased)
			scale = lerp(0.3, 1.0, minf(1.0, t / 0.35 * 1.0))
			alpha = minf(1.0, t / 0.15)
		elif age < fly_start:
			pos = icon["scatter"]
		else:
			var t: float = clampf((age - fly_start) / FLY, 0.0, 1.0)
			var eased := t * t * (3.0 - 2.0 * t)  # smoothstep, standing in for the CSS ease
			pos = Vector2(icon["scatter"]).lerp(Vector2(icon["target"]), eased)
			# 1 -> 1.15 -> 0.95 -> 1.05 -> shrink away, matching rewardFlyWobble.
			if t < 0.25:
				scale = lerp(1.0, 1.15, t / 0.25)
			elif t < 0.5:
				scale = lerp(1.15, 0.95, (t - 0.25) / 0.25)
			elif t < 0.7:
				scale = lerp(0.95, 1.05, (t - 0.5) / 0.2)
			elif t < 0.9:
				scale = lerp(1.05, 0.5, (t - 0.7) / 0.2)
			else:
				scale = lerp(0.5, 0.25, (t - 0.9) / 0.1)
			alpha = 1.0 if t < 0.9 else 1.0 - (t - 0.9) / 0.1

		_draw_coin(pos, float(icon["size"]) * scale / 2.0, alpha)


## The SDK's default reward: an orange disc with a lighter top-left face and a
## darker rim.
func _draw_coin(centre: Vector2, radius: float, alpha: float) -> void:
	if radius <= 0.0:
		return
	var base := DEFAULT_COLOR
	var light := base.lightened(0.25)
	var dark := base.darkened(0.35)
	base.a = alpha
	light.a = alpha
	dark.a = alpha

	draw_circle(centre, radius, base)
	draw_circle(centre + Vector2(-radius * 0.22, -radius * 0.22), radius * 0.62, light)
	DrawUtil.stroke_arc(self, centre, radius - 2.0, 0.0, TAU, dark, 4.0)
