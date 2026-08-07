extends Node
## All sound effects are synthesised at startup — no SFX files to bundle, which
## matters more here than in the browser build because everything ships inside
## the .pck. The original built these with WebAudio oscillator/noise graphs; the
## same graphs are rendered offline into AudioStreamWAV buffers below, so the
## sounds are the ones the game was tuned with.
##
## The music track is the one real audio asset, and it is deliberately left
## playing under the host's result screen rather than cutting to silence.

const MUSIC_PATH := "res://assets/audio/loop.mp3"
const MIX_RATE := 44100
const MASTER := 0.34         # the WebAudio master gain
const MUSIC_LEVEL := 0.3
const VOICES := 12

var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _bank: Dictionary = {}
var _impact_cache: Dictionary = {}

var _music: AudioStreamPlayer
var _music_wanted := false
var _music_tween: Tween


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_bank["rotate_cw"] = _render([_noise(0.2, 0.22, 500.0, 0.8)])
	_bank["rotate_ccw"] = _render([_noise(0.2, 0.22, 1400.0, 0.8)])
	_bank["button"] = _render([
		_tone(660.0, 990.0, 0.09, "square", 0.16),
		_tone(990.0, 990.0, 0.16, "sine", 0.2, 0.07),
	])
	_bank["door"] = _render([_tone(300.0, 620.0, 0.28, "sawtooth", 0.1, 0.0, "lin")])
	_bank["clear"] = _render([
		_tone(523.0, 523.0, 0.3, "sine", 0.26, 0.0),
		_tone(659.0, 659.0, 0.3, "sine", 0.26, 0.065),
		_tone(784.0, 784.0, 0.3, "sine", 0.26, 0.13),
		_tone(1047.0, 1047.0, 0.3, "sine", 0.26, 0.195),
	])
	_bank["death_spike"] = _render([
		_tone(420.0, 90.0, 0.34, "sawtooth", 0.24),
		_noise(0.2, 0.2, 400.0, 0.7),
	])
	_bank["death_out"] = _render([_tone(500.0, 60.0, 0.5, "triangle", 0.22)])
	_bank["retry"] = _render([_tone(240.0, 160.0, 0.14, "square", 0.14)])
	_bank["run_over"] = _render([
		_tone(784.0, 784.0, 0.42, "sine", 0.24, 0.0),
		_tone(587.0, 587.0, 0.42, "sine", 0.24, 0.13),
		_tone(466.0, 466.0, 0.42, "sine", 0.24, 0.26),
		_tone(349.0, 349.0, 0.42, "sine", 0.24, 0.39),
	])

	_music = AudioStreamPlayer.new()
	add_child(_music)
	# The track is the one real audio asset and is deliberately optional — see
	# assets/audio/README.md. Ask before loading, so a build without it reports a
	# warning rather than an engine "resource not found" error that reads like a
	# bug; everything else is synthesised above and is unaffected.
	var stream: Resource = ResourceLoader.load(MUSIC_PATH) if ResourceLoader.exists(MUSIC_PATH) else null
	if stream is AudioStreamMP3:
		stream.loop = true
		_music.stream = stream
		_music.volume_db = linear_to_db(0.0001)
	else:
		push_warning("[flipfall] no music track at %s — running without it" % MUSIC_PATH)


# --- playback ---------------------------------------------------------------

func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.play()


func rotate_sfx(dir: int) -> void:
	_play(_bank["rotate_cw" if dir > 0 else "rotate_ccw"])


func impact(speed: float, kind: String) -> void:
	# Quantised so a busy landing reuses buffers instead of synthesising one per
	# collision; four steps is finer than the ear resolves on a 90 ms tick.
	var hard: float = snappedf(minf(1.0, speed / 700.0), 0.25)
	var key := "%s:%.2f" % [kind, hard]
	if not _impact_cache.has(key):
		var events: Array = []
		if kind == "ice":
			events = [_noise(0.07, 0.1 + hard * 0.12, 3200.0, 2.5)]
		elif kind == "sticky":
			events = [_tone(150.0, 70.0, 0.11, "sine", 0.16 + hard * 0.1)]
		else:
			events = [
				_tone(190.0, 90.0, 0.09, "triangle", 0.14 + hard * 0.2),
				_noise(0.05, 0.06 + hard * 0.1, 700.0, 1.0),
			]
		_impact_cache[key] = _render(events)
	_play(_impact_cache[key])


func button() -> void:
	_play(_bank["button"])


func door() -> void:
	_play(_bank["door"])


func clear() -> void:
	_play(_bank["clear"])


func death(cause: String) -> void:
	_play(_bank["death_spike" if cause == "spike" else "death_out"])


func retry() -> void:
	_play(_bank["retry"])


func run_over() -> void:
	_play(_bank["run_over"])


# --- music ------------------------------------------------------------------

## Begin playback, fading in. No-op after the first call.
func start_music(fade_seconds: float = 1.6) -> void:
	if _music_wanted or _music.stream == null:
		return
	_music_wanted = true
	_music.volume_db = linear_to_db(0.0001)
	_music.play()
	_ramp_music(MUSIC_LEVEL, fade_seconds)


## Dip under a jingle, then come back.
func duck_music(seconds: float = 0.7, to: float = 0.4) -> void:
	if not _music_wanted:
		return
	_ramp_music(MUSIC_LEVEL * to, 0.12)
	await get_tree().create_timer(0.14).timeout
	if _music_wanted:
		_ramp_music(MUSIC_LEVEL, seconds * 0.7)


## Pause with the tab, resume if the run is still live — the design's
## `visibilitychange` behaviour. Godot's web platform raises the window-focus
## notifications from the browser's blur/visibility events, so this covers a
## backgrounded tab as well as an unfocused desktop window.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _music_wanted and _music != null:
				_music.stream_paused = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _music_wanted and _music != null:
				_music.stream_paused = false


func _ramp_music(to: float, seconds: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", linear_to_db(maxf(0.0001, to)), maxf(0.01, seconds))


# --- offline synthesis ------------------------------------------------------

static func _tone(freq: float, to: float, dur: float, type: String, gain: float,
		delay: float = 0.0, curve: String = "exp") -> Dictionary:
	return {"kind": "tone", "freq": freq, "to": to, "dur": dur, "type": type,
		"gain": gain, "delay": delay, "curve": curve}


static func _noise(dur: float, gain: float, freq: float, q: float, delay: float = 0.0) -> Dictionary:
	return {"kind": "noise", "dur": dur, "gain": gain, "freq": freq, "q": q, "delay": delay}


func _render(events: Array) -> AudioStreamWAV:
	var total := 0.0
	for e in events:
		total = maxf(total, float(e["delay"]) + float(e["dur"]))
	var n := int(ceil((total + 0.02) * MIX_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)

	for e in events:
		if e["kind"] == "tone":
			_render_tone(buf, e)
		else:
			_render_noise(buf, e)

	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: int = clampi(int(round(clampf(buf[i] * MASTER, -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Attack then exponential decay, mirroring the WebAudio gain envelope:
## linearRampToValueAtTime(gain) followed by exponentialRampToValueAtTime(1e-4).
static func _envelope(t: float, dur: float, gain: float, attack: float) -> float:
	if t < attack:
		return gain * (t / maxf(attack, 1e-6))
	return gain * pow(0.0001 / gain, (t - attack) / maxf(dur - attack, 1e-6))


func _render_tone(buf: PackedFloat32Array, e: Dictionary) -> void:
	var dur: float = e["dur"]
	var freq: float = e["freq"]
	var to: float = maxf(1.0, float(e["to"]))
	var gain: float = e["gain"]
	var attack: float = minf(0.012, dur * 0.3)
	var start := int(float(e["delay"]) * MIX_RATE)
	var count := int(dur * MIX_RATE)
	var phase := 0.0

	for i in count:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		var f := freq
		if not is_equal_approx(to, freq):
			# exponentialRampToValueAtTime is a geometric sweep; linear is a lerp.
			f = freq * pow(to / freq, t / dur) if e["curve"] == "exp" else lerp(freq, to, t / dur)
		phase += TAU * f / MIX_RATE
		buf[idx] += _wave(e["type"], phase) * _envelope(t, dur, gain, attack)


static func _wave(type: String, phase: float) -> float:
	var p := fposmod(phase, TAU)
	match type:
		"square":
			return 1.0 if p < PI else -1.0
		"sawtooth":
			return p / PI - 1.0
		"triangle":
			return (2.0 / PI) * asin(sin(p))
		_:
			return sin(p)


func _render_noise(buf: PackedFloat32Array, e: Dictionary) -> void:
	var dur: float = e["dur"]
	var gain: float = e["gain"]
	var start := int(float(e["delay"]) * MIX_RATE)
	var count := int(dur * MIX_RATE)
	if count <= 0:
		return

	# RBJ band-pass (constant 0 dB peak), the analog of the WebAudio
	# BiquadFilterNode the original ran the noise buffer through.
	var w0 := TAU * float(e["freq"]) / MIX_RATE
	var alpha := sin(w0) / (2.0 * maxf(0.0001, float(e["q"])))
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0

	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	for i in count:
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		# The source buffer itself fades out linearly, then the gain node decays.
		var x := (randf() * 2.0 - 1.0) * (1.0 - float(i) / count)
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[idx] += y * gain * pow(0.0001 / gain, t / dur)
