extends SceneTree
## Trace of the GDScript physics port, in the same format tools/trace_js.mjs
## prints from the original JavaScript. Diff the two to confirm the port
## reproduces the simulation every room was proven solvable against.
##
##   godot --headless --script res://tools/trace.gd > /tmp/trace-gd.txt

# Deliberately awkward: rotations land mid-flight, not at rest, so the schedule
# exercises the collision and friction paths rather than settling between moves.
const SCHEDULE := [
	{"wait": 0.5, "dir": 1},
	{"wait": 1.0, "dir": -1},
	{"wait": 0.75, "dir": 1},
	{"wait": 1.5, "dir": 1},
	{"wait": 2.0, "dir": 0},
]

const FRAME := 1.0 / 60.0


func _initialize() -> void:
	for i in Levels.ALL.size():
		var level: Dictionary = Levels.ALL[i]
		var w := Sim.new(level)
		var impacts: Array[float] = []

		for stage in SCHEDULE:
			var t := 0.0
			while t < float(stage["wait"]) and w.status == "playing":
				w.step(FRAME, Const.SUBSTEP)
				for ev in w.events:
					if ev["type"] == "impact":
						impacts.append(float(ev["speed"]))
				w.events.clear()
				t += FRAME
			if int(stage["dir"]) != 0:
				w.rotate(int(stage["dir"]))

		var pressed := PackedStringArray(w.buttons.keys())
		pressed.sort()
		var impact_sum := 0.0
		for s in impacts:
			impact_sum += s

		print(" ".join(PackedStringArray([
			"%02d" % (i + 1),
			String(level["name"]),
			w.status,
			w.cause if w.cause != "" else "-",
			"%.8f" % w.x,
			"%.8f" % w.y,
			"%.8f" % w.vx,
			"%.8f" % w.vy,
			"%.8f" % w.time,
			str(w.rotations),
			"".join(pressed) if pressed.size() > 0 else "-",
			str(impacts.size()),
			"%.6f" % impact_sum,
		])))
	quit()
