class_name Const
extends RefCounted
## Design surface. Everything in the game is authored against these numbers and
## nothing is ever derived from the live viewport — src/background.gd is the one
## place get_viewport_rect() is read, and only so the decorative backdrop can
## paint the area `expand` reveals beyond the design box.

const DESIGN_W := 960.0
const DESIGN_H := 1480.0

# Safe area: gameplay-critical elements stay inside the central 90%.
const SAFE_INSET := 0.05

# Playfield: one screen, one puzzle. Square so gravity rotation is symmetric.
const GRID := 13
const CELL := 60.0
const PF_SIZE := GRID * CELL        # 780
const PF_X := (DESIGN_W - PF_SIZE) / 2.0  #  90
const PF_Y := 215.0
const PIT_PAD := 12.0               # recessed frame around the playfield

# Controls.
const ROT_R := 118.0
const ROT_CCW := Vector2(250, 1130)
const ROT_CW := Vector2(710, 1130)
const PILL_POS := Vector2(480, 1330)
const PILL_SIZE := Vector2(320, 120)

# Gravity compass lives in the dead centre of the SDK header bar.
const COMPASS := Vector2(480, 115)
const COMPASS_R := 52.0
const HUD_Y := 60.0
# DESIGN.md specifies 75, but the compass sits in the dead centre of the bar and
# the left group is two panels against Score's one, so at 75 the Attempts /
# Rotations block came within 39 px of the dial while 264 px went unused on the
# right. Padding is the SDK's documented positioning knob, and 48 is the safe-area
# inset the rest of the layout already uses, so the bar now spans it exactly.
const HUD_PAD := 48.0

# ---------------------------------------------------------------------------
# Vertical bands.
#
# The browser build cover-scales its 960x1480 surface and crops, so it never has
# spare height. Godot's `expand` does the opposite: it reveals extra viewport
# height, which as a plain centred box turns into dead margin above and below
# while the playfield still sits 5 px off the rotate buttons. So the HUD anchors
# to the real edges — top bar to the top, controls to the bottom — and the
# playfield centres in what is left, which is where the spare height goes.
#
# At exactly the design aspect these collapse back to the authored layout.
# ---------------------------------------------------------------------------
const TOP_BAND_BOTTOM := 167.0                       # compass bottom, below the header values
const FIELD_TOP := PF_Y - 44.0                       # top of the level label
const FIELD_BOTTOM := PF_Y + PF_SIZE + PIT_PAD       # bottom of the recessed frame
const CONTROLS_TOP := 1130.0 - 118.0                 # ROT_CCW.y - ROT_R
const CONTROLS_BOTTOM := 1330.0 + 60.0               # PILL_POS.y + PILL_SIZE.y / 2
const BOTTOM_MARGIN := DESIGN_H * SAFE_INSET         # the safe-area inset, 74

# Orb / simulation. Tuned so a full-width traverse takes about a second: fast
# enough to feel momentum, slow enough that mid-flight rotations are a fair ask
# on a touch screen rather than a frame-perfect input.
const ORB_R := 22.0
const GRAVITY := 1100.0   # px/s^2
const MAX_SPEED := 900.0  # px/s
const REST_SPEED := 14.0  # px/s, below this while touching = at rest
const SUBSTEP := 1.0 / 240.0

# The room tumbles to keep gravity pointing screen-down.
const TUMBLE_SECONDS := 0.24

# Run rules.
const ATTEMPTS := 3
const ATTEMPTS_MIN := 1
const ATTEMPTS_MAX := 9

# Rooms per difficulty tier. The room list is exactly TIERS.size() * TIER_SIZE
# long, and src/levels.gd asserts it.
const TIERS: Array[String] = ["easy", "medium", "hard", "insane"]
const TIER_SIZE := 10
const LEVEL_COUNT := 40  # TIERS.size() * TIER_SIZE


static func tier_of(index: int) -> String:
	return TIERS[clampi(index / TIER_SIZE, 0, TIERS.size() - 1)]


# ---------------------------------------------------------------------------
# Host-settable config. This is the single source of truth: game.gd reads values
# through it, and it must agree with the `config` block in meta.json on every
# key, type, default and bound.
# ---------------------------------------------------------------------------
const CONFIG := [
	{"key": "attempts", "value_type": "number", "value": ATTEMPTS, "min": ATTEMPTS_MIN, "max": ATTEMPTS_MAX},
	# start_level / end_level select the segment of the room list a drop plays,
	# which is how difficulty is published: 1-10 easy, 11-20 medium, 21-30 hard,
	# 31-40 insane. Locked against mods so a mod cannot swap the room set out
	# from under a score.
	{"key": "startLevel", "value_type": "number", "value": 1, "min": 1, "max": LEVEL_COUNT},
	{"key": "endLevel", "value_type": "number", "value": 10, "min": 1, "max": LEVEL_COUNT},
]


static func config_spec(key: String) -> Dictionary:
	for spec in CONFIG:
		if spec["key"] == key:
			return spec
	push_error("undeclared config key \"%s\"" % key)
	return {}


# Scoring.
const PTS_PER_LEVEL := 1000
const PTS_PER_ATTEMPT := 500
const PTS_PER_ROTATION := -5
const TIME_BONUS_BASE := 200.0
const TIME_BONUS_DECAY := 10.0  # points lost per second

# Palette.
const C_BG := Color("#1E1F26")
const C_PIT := Color("#16171C")
const C_WALL := Color("#4A5568")
const C_WALL_LIP := Color("#5D6B7E")
const C_ORB := Color("#34D1FF")
const C_ORB_DEEP := Color("#0EA5C8")
const C_EXIT := Color("#22C55E")
const C_BUTTON := Color("#FBBF24")
const C_DOOR := Color("#6366F1")
const C_SPIKE := Color("#EF4444")
const C_ICE := Color("#C7F2FF")
const C_STICKY := Color("#7C3AED")
const C_HUD := Color("#FFFFFF")

const TIER_COLOR := {
	"easy": Color(1, 1, 1, 0.4),
	"medium": Color("#34D1FF"),
	"hard": Color("#FBBF24"),
	"insane": Color("#EF4444"),
}
