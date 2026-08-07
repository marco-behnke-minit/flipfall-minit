class_name SessionLog
extends RefCounted
## Records how a playtest actually went, so a room can be judged on evidence
## rather than on recollection.
##
## Written only when running locally — the editor, or a desktop build. A web
## export never logs, so nothing about this reaches the shipped game or the host.
##
## One JSON file per run, under tmp/sessions/ (gitignored). It is rewritten after
## every attempt rather than at the end, so quitting halfway still leaves the
## data. Read it with `node tools/session-report.mjs`.
##
## Per attempt it keeps: what ended it, how many rotations it took, the room
## clock, and the wall-clock time actually spent — which is the one that shows
## hesitation, since the room clock only starts on the first rotation.

const DIR_EDITOR := "res://tmp/sessions"
const DIR_FALLBACK := "user://sessions"

var _path := ""
var _data := {}
var _room: Dictionary = {}
var _room_started_ms := 0


static func is_enabled() -> bool:
	# The shipped build is a web export; it must never try to write anything.
	return not OS.has_feature("web")


func begin(room_set: String, config: Dictionary) -> void:
	if not is_enabled():
		return
	var dir := DIR_EDITOR if OS.has_feature("editor") else DIR_FALLBACK
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		push_warning("[flipfall] could not create %s — not logging this session" % dir)
		return

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_path = "%s/%s-%s.json" % [dir, room_set, stamp]
	_data = {
		"startedAt": Time.get_datetime_string_from_system(),
		"rooms": room_set,
		"config": config,
		"godot": Engine.get_version_info()["string"],
		"log": [],
		"result": {},
	}
	_flush()


## Called when a room is armed — both the first time and after every death or
## retry, so each pass through a room is its own attempt record.
func room_started(index: int, name: String, par: int) -> void:
	if _path.is_empty():
		return
	# Same room again after a death or retry: keep accumulating into the existing
	# record rather than starting a new one. `index` is 0-based here and stored
	# 1-based, which is exactly the mistake this comparison made first time.
	if not _room.is_empty() and int(_room["index"]) == index + 1 and _room["outcome"] == "in progress":
		_room_started_ms = Time.get_ticks_msec()
		return
	_room = {
		"index": index + 1,
		"name": name,
		"par": par,
		"attempts": [],
		"deaths": {"spike": 0, "out": 0, "stuck": 0},
		"retries": 0,
		"outcome": "in progress",
	}
	_data["log"].append(_room)
	_room_started_ms = Time.get_ticks_msec()
	_flush()


## `how` is "clear", "retry", or a death cause ("spike", "out", "stuck").
## Unknown causes are counted rather than crashing the run.
func attempt_ended(how: String, rotations: int, room_seconds: float) -> void:
	if _path.is_empty() or _room.is_empty():
		return
	_room["attempts"].append({
		"outcome": how,
		"rotations": rotations,
		"roomSeconds": snappedf(room_seconds, 0.01),
		"wallSeconds": snappedf((Time.get_ticks_msec() - _room_started_ms) / 1000.0, 0.01),
	})
	match how:
		"clear": _room["outcome"] = "cleared"
		"retry": _room["retries"] = int(_room["retries"]) + 1
		_: _room["deaths"][how] = int(_room["deaths"].get(how, 0)) + 1
	_flush()


func run_ended(score: int, rooms_cleared: int, attempts_left: int, flavor: String) -> void:
	if _path.is_empty():
		return
	if not _room.is_empty() and _room["outcome"] == "in progress":
		_room["outcome"] = "run ended here"
	_data["result"] = {
		"score": score,
		"roomsCleared": rooms_cleared,
		"attemptsLeft": attempts_left,
		"flavorText": flavor,
	}
	_flush()
	print("[flipfall] session log: %s" % ProjectSettings.globalize_path(_path))


func _flush() -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_warning("[flipfall] could not write %s" % _path)
		_path = ""
		return
	f.store_string(JSON.stringify(_data, "  "))
	f.close()
