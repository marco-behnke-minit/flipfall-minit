# Flipfall — Godot 🔄🔵

A momentum-based gravity puzzle for portrait mobile, built in Godot 4 on the
Minit Games SDK. Ported from an HTML5 original, which it now supersedes.

The game itself is unchanged: rotate gravity in 90° increments to guide a rolling
orb through handcrafted rooms; the room tumbles beneath a fixed gravity so
falling always reads as screen-down. `DESIGN.md` is the design document; this
README covers how the project is built and verified.

It is self-contained: the JavaScript physics, scoring and level-solving search
the verifier runs live in `tools/reference/`, copied from the HTML5 project that
this one replaces.

## Running

```bash
godot --path .                                   # play it
node tools/solve.mjs                             # every room solvable + par
node tools/run-sim.mjs 8                         # simulate a run, 8s/room
node tools/compare-trace.mjs                     # src/sim.gd == the reference
godot --headless --script res://tools/test_score.gd    # scoring + flavor text
godot --headless --script res://tools/test_config.gd  # config coercion + clamping
godot --headless --script res://tools/test_music.gd   # the music is actually wired up
godot --script res://tools/test_touch.gd --resolution 960x1480 # one tap = one quarter turn
node tools/check-meta.mjs                        # meta.json: schema + semantic
node tools/test-schema.mjs                       # the schema validator itself
node tools/curve.mjs                             # the learning-curve order
node tools/creep-check.mjs                       # which rooms can be walked home
node tools/mechanics.mjs                         # what the rooms actually exercise
godot --script res://tools/gallery.gd --resolution 960x1480   # one still per room
godot --script res://tools/fade_check.gd --resolution 480x1200 # fade at a phone aspect
godot --script res://tools/measure_stall.gd --resolution 960x1480 # frame spike at the first pop
tools/package.sh                                 # export + upload ZIP
```

`tools/package.sh` needs the Web export templates, which are a one-time editor
install: **Editor > Manage Export Templates > Download and Install**. It writes
`build/flipfall-godot.zip` — ~15 MB, `index.html` and `meta.json` at the root,
no `src/` and no project files — ready to upload at
[console.minit.games](https://console.minit.games).

The exported build has been run in a browser: it loads, renders, takes taps on
the rotate buttons, clears a room and advances, with no console errors.

## Minit SDK

`addons/minit/minit.gd` is the SDK facade, byte-identical to the copy the docs
serve. `project.godot` registers it as the `Minit` autoload directly, as well as
via `addons/minit/plugin.gd`, so a headless export works without the editor ever
having enabled the plugin.

Three lifecycle calls, as in the original:

| Call | When |
| --- | --- |
| `Minit.get_config_value(key, default)` | at startup, for `attempts` / `startLevel` / `endLevel` |
| `Minit.loading_done()` | on the first drawn frame, never behind a button |
| `Minit.report_result(score, {flavor_text})` | once, when the run ends |

No start menu, no pause menu, no replay menu, no in-game result UI — the host
owns all of it. No `userData`: one self-contained session.

### Config, and how to change it locally

The host passes `attempts` / `startLevel` / `endLevel` on the URL query string,
which the SDK reads. Outside the host there is no query string, so every value
would be stuck at its default and no segment other than the default could be
played. Hence a command-line override:

```bash
godot --path . -- --attempts=9 --startLevel=37 --endLevel=45   # the last two blocks
godot --path . -- --startLevel=44 --endLevel=45                # the ceiling rooms
```

There is one more override, for design work rather than configuration:

```bash
godot --path . -- --rooms=prototypes --attempts=9
```

That swaps `src/levels.gd` for the scratch rooms in `src/prototypes.gd`, where
candidate rooms are tried out before they earn a place. Five of them have since
been promoted into the shipped set; what remains is the one that did not, kept as
a record of why. `node tools/prototypes.mjs` measures whatever is in there.

From the editor, put the same arguments after `--` in **Project Settings →
Editor → Run → Main Run Args**. The game prints a line on startup when an
override is active, so a test run cannot be mistaken for the shipped defaults.

**Left and right arrow keys** drive the two rotate buttons, which makes testing
in a browser much less fiddly than aiming at them. They press the on-screen
button too, so what a tester sees still matches what they did.

A web export has no user args, so all of this is inert in production and cannot
shadow what the host sends. Overrides go through exactly the same coercion and
clamping as the host's values, so they cannot reach out-of-range settings either.

The default is the whole 45-room list, which is a long session — publishing picks
a segment instead, and should cut at a block boundary (see Room order). Note that
`startLevel` / `endLevel` can only express a *contiguous* range, so a drop that
samples across blocks is not expressible today; it would need a different key.

### Playtest logs

Every local run writes a session log to `tmp/sessions/` (gitignored): per room,
each attempt with what ended it, the rotations used, the room clock and the
wall-clock time. Read it with:

```bash
node tools/session-report.mjs          # the last session
node tools/session-report.mjs --all    # every session, aggregated per room
```

The gap between wall time and room time is the interesting column — the room
clock only starts on the first rotation, so the difference is hesitation, which
is what a genuinely puzzling room produces and a merely fiddly one does not.

A web export never writes anything: `SessionLog.is_enabled()` is false there, so
none of this reaches the shipped game or the host.

**The Godot SDK is the lifecycle facade only.** It has no counterpart to the JS
SDK's `@minit-games/sdk/ui` module, so the three UI pieces the game uses are
reimplemented against the same documented contract:

| JS SDK | Here |
| --- | --- |
| `createHeaderBar` / `addPanel` | `src/ui/header_bar.gd` |
| `showPositive/Neutral/NegativeFeedback` | `src/ui/feedback.gd` |
| `spawnRewards` | `src/ui/rewards.gd` |

They keep the SDK's conventions: score on the right and secondary stats left,
plain-text labels with no emoji, an animated count-up on value changes, the three
feedback variants with their colours and ~1 s timing, and one flying icon per
point clustered into 125/25/5/1 denominations.

They also use the SDK's real typefaces. `assets/fonts/` holds Lato (HUD) and
Bowlby One SC (feedback pops), extracted from the woff2 the JS SDK bundles —
Godot loads woff2 directly — with their SIL OFL licences alongside. This is not
just cosmetic: panel widths *are* font metrics, and a wider substitute pushed the
Attempts / Rotations group to within 12 px of the gravity compass.

## Web export

Per the SDK's Godot article, the preset in `export_presets.cfg` sets **Thread
Support OFF** (a threaded build needs `SharedArrayBuffer`, which requires
cross-origin-isolation headers the host iframe does not guarantee), **PWA OFF**,
and **Canvas Resize Policy: Adaptive**.

`web/shell.html` is Godot's stock 4.7.1 web shell (`godot.html`, straight out of
`web_nothreads_release.zip`) plus one added block, and the preset points at it
via `html/custom_html_shell`. The block retries a failed
`AudioWorklet.addModule()` through `fetch()` + a `blob:` URL, because inside the
Minit app the game is served from a custom URL scheme that a worklet module
fetch cannot reach — `addModule()` rejects, Godot's audio driver never connects
its output node, and the game plays perfectly with no sound at all. Nothing
shows in gameplay; the only trace is a console `Failed to create
PositionWorklet`. Everything else in the file is stock, so on a Godot upgrade
re-extract `godot.html` from the new templates and re-apply the block rather
than carrying this copy forward.

## Layout

The original is authored against a fixed 960×1480 design surface and cover-scales
it, capping the crop at 5%. Godot's `canvas_items` / `expand` stretch does the
opposite — it *reveals* extra viewport area rather than cropping — so the layout
has to decide what to do with the spare space.

Centring the design box wastes it: on a phone the extra height becomes dead
margin above and below, while the playfield still sits 5 px off the rotate
buttons. So the HUD anchors to the real edges instead, which is what the SDK's
Godot article recommends. Vertically there are three bands:

| Band | Anchored to | Contents |
| --- | --- | --- |
| top | viewport top | header bar, gravity compass |
| field | centred in between | level label, playfield, particles |
| controls | viewport bottom | rotate buttons, pill |

Everything *inside* a band is still authored in the design coordinates DESIGN.md
specifies — only the bands move — and at exactly the design aspect all three
offsets are zero and the authored layout is reproduced exactly. On the game frame
of an iPhone 16 (~1588 logical px tall) it turns 14 px above the playfield and
5 px below into 66 px on each side, and drops the dead space under the pill from
143 px to the design's own 74 px safe-area inset.

Two consequences worth knowing:

- Hit-testing converts a touch into the controls band's own space rather than
  tracking the offset by hand, so the buttons stay authored at their design
  coordinates.
- Flying rewards cross bands — they start at a burst in the field band and land
  on a header panel in the top band — so `game.gd` adds the band offsets when it
  spawns them.

Horizontally the design box is simply centred, and `src/background.gd` is the
only node that reads `get_viewport_rect()`, painting the full revealed area so no
unpainted strip can appear at an edge.

## Scoring

Every room can be finished by **creeping** — alternating gravity walks the orb
along any surface a fraction of a cell at a time, needing no timing at all
(`tools/creep-check.mjs` confirms this of all 45). That is deliberately left in:
working a mechanic out and mastering it is the satisfying part, and a stuck
player should always have a way home.

So difficulty lives in the score, not in pass/fail:

| | |
| --- | --- |
| +1000 | per room cleared |
| +500 | per Attempt still in hand at the end |
| +200 | time bonus per room, draining 10 a second |
| **+40** | **per rotation under par** |
| **−25** | **per rotation over par** |
| **−150** | **per death** |

`par` is the committed route the solver found, which makes it the natural
benchmark: under par means you took the line, far over means you walked it.
Creeping a par-4 room in 24 rotations costs 500 points against a clean 1120 —
a visible sacrifice rather than the 21% it cost when rotations were a flat −5.

## Room order

11 rooms, ordered as a **learning curve** rather than a difficulty ranking —
`tools/curve.mjs` produces the order and `src/levels.gd` carries it.

A monotonic ramp is the wrong shape. Difficulty is not a property of a room, it
is a property of a room *given what the player already knows*: a room the solver
called frame-perfect was cleared first try because its neighbour had taught the
move, and ice rooms went from hard to easy the moment ice was understood. So the
shape is a sawtooth — introduce a mechanic, ramp up the rooms using it, let
mastery make them feel easy, then reset with something new. **Only the rise is
authored; the fall happens in the player.**

| # | room | teaches | window |
| --- | --- | --- | --- |
| 1 | Teeth | spikes | rest-only |
| 2 | Trapdoor | ice | 325 ms |
| 3 | Well | ice | 200 ms |
| 4 | Skim | ice | 275 ms |
| 5 | Skate | ice | rest-only |
| 6 | Pothole | tar | 375 ms |
| 7 | Grip | tar | 825 ms |
| 8 | Anchor | tar | 50 ms |
| 9 | Slalom | lane geometry | 300 ms |
| 10 | Overhead | ceiling spikes | 50 ms |
| 11 | Eyelet | ceiling spikes | tight |

Every room has a hazard that changes its solution when removed — `tools/triage.mjs`
checks this by deleting each hazard and re-solving. None is rest-only solvable
except Teeth and Skate, so nine of eleven require a timed flip.

**Tar** (`T`) is the one tile with a rule of its own: it grips like stone, but
holding contact for `STICKY_DEATH` kills, and the hold sheds at only half speed so
creeping across it does not beat the clock. It earns a room only when the
objective sits ON it — you can always fly past a surface gravity is not pressing
you into, which is how three earlier tar rooms came to be pure decoration.

Nine of the ten require a timed flip; the shipped 40 had eight out of forty.
Five came from `src/prototypes.gd` after playtesting: Trapdoor, Well, Skim,
Overhead and Eyelet.

### Every room has to earn its place

A full playthrough cleared 44 of 45 rooms on the **first attempt**, with one to
three seconds of thinking per room. `tools/triage.mjs` applies the two tests that
explain why, and **eighteen rooms were cut** for failing both:

- **Decoration.** Delete a room's hazards and re-solve. Same rotations means they
  never constrained anything. 15 of 26 spiked rooms and 11 of 19 iced rooms
  failed this — Vault passed within a cell of all 27 of its spikes and touched
  none, because the route flew down a corridor they merely lined.
- **Repetition.** Strip the hazards to bare geometry and compare. Rungs was
  *identical* to Ladder, Razor to Spire, Singularity to Whiteout — same room,
  different paint.

Run it on anything new: a room that does not come out KEEP is not a room yet.

A consequence worth knowing: this order does **not** segment cleanly. Publishing
an arbitrary tenth drops a player into the middle of a mechanic they were never
taught, so a segment should be cut at a block boundary if it is cut at all.

## Notes on the port

**Physics is verified, not eyeballed.** `src/sim.gd` is a line-for-line port of
the original `src/physics.js`, which the HTML5 project's solver ran under Node to
prove all forty rooms solvable. `tools/compare-trace.mjs` runs the same scripted
rotation schedule through both engines and compares:

- status, cause, buttons pressed, rotation count and impact count match **exactly**
  on all forty rooms;
- positions and velocities agree to ~2×10⁻³ px after 5.8 s of simulation.

Two things were needed to get there, and both are load-bearing:

- **The orb's state is bare floats, not a `Vector2`.** `Vector2` is 32-bit in a
  standard Godot build; the original runs in JavaScript doubles. Halving the
  mantissa in a loop this chaotic drifts trajectories far enough to change
  whether a tight room is solvable.
- **`Sim.hypot()` reproduces JavaScript's `Math.hypot`,** which is not
  `sqrt(a*a + b*b)` — it scales by the larger magnitude and sums with Kahan
  compensation. The 1-ULP difference compounds over ~1,400 substeps per room into
  a visible divergence. `tools/compare-trace.mjs` is what caught it.

The residual drift is `exp()` rounding differently between V8 and the platform
libm, which nothing short of reimplementing `exp` would close.

**Rendering** is immediate-mode `_draw()`, which maps closely onto the original's
canvas2d. Where Godot has no primitive, `src/draw_util.gd` supplies it: rounded
rects, arcs, letter-spaced text, and a layered-disc stand-in for `shadowBlur`.
The orb's radial gradient and halo are baked into one procedural texture at
startup.

**The playfield renders through a SubViewport** so an orb that leaves an
open-sided room is clipped at the frame instead of drawn over the controls — the
job `ctx.clip()` did. Because a SubViewport renders at its own pixel size and
would be blurred on a dense screen, its size tracks the real
pixels-per-design-unit ratio and the container is scaled back down.

**Nothing is left to load lazily.** Godot fills the font atlas on first use, per
(face, size, outline) — and the feedback pops are Bowlby One SC at 110 px drawn
three times over, a fill plus two outline passes. Left alone, the first pop
rasterises all of that inside a frame, which lands exactly on an interesting
beat: the first door opening, or the first room cleared. Measured on an M3 Max,
that frame cost **28.1 ms against an 8.3 ms median — a +19.8 ms spike**, and a
wasm build on a phone is several times worse.

`src/warmup.gd` pays it up front instead: it pre-rasterises every glyph the game
can draw and primes each canvas draw pipeline, during the frames *before*
`Minit.loading_done()` fires — while the host still has its loading state over
the WebView, so the player never sees it. The same frame now costs 9.1 ms, a
+0.0 ms spike. `tools/measure_stall.gd` is the A/B, and `tools/measure_warmup.gd`
breaks the cost down by face and size.

The text sizes live as named constants on the scripts that draw them, and the
warm-up references those rather than repeating the numbers, so the list cannot
quietly fall out of step with the drawing code.

**Sound effects are synthesised at startup** into `AudioStreamWAV` buffers, as
the original synthesised them in WebAudio — including an RBJ band-pass standing
in for the `BiquadFilterNode`. The music track is the one real audio asset and,
as before, is deliberately left playing under the host's result screen.

### Two simulations, on purpose

The game runs `src/sim.gd`. The verifier runs `tools/reference/physics.js`. That
is not duplication left over from the port — it is what makes the proofs mean
something:

- `tools/solve.mjs` proves every room solvable, using the reference physics and
  the search that was written against it.
- `tools/compare-trace.mjs` proves `src/sim.gd` *is* that simulation, on all
  forty rooms.

Together they say the shipped build can clear every room. Either alone says
nothing. It is also a differential test — a mistake in one implementation has to
be mirrored exactly in the other to go unnoticed.

Rooms live only in `src/levels.gd`; the JavaScript tooling parses them from
there (`tools/lib/levels.mjs`), so there is never a second copy of a map to
drift. Editing a map invalidates only that room's cache entry; editing the
reference engine invalidates all forty.

### What DESIGN.md describes that does not apply here

- **The music "volume routes" (`element` / `webaudio` / `fixed`).** Those exist
  to work around a tainted `MediaElementSource` and a read-only `el.volume` on
  iOS. Godot plays the stream through its own mixer, where `volume_db` is always
  writable, so there is one route and `duck_music()` just tweens it.
- **Vite, `public/`, and single-file inlining.** Godot's exporter produces the
  web build; `tools/package.sh` adds `meta.json` and runs the pre-flight.

### Known deviations

- **Header side padding is 48, not the 75 in DESIGN.md's layout table.** The
  compass sits in the dead centre of the bar and the left group is two panels
  against Score's one, so at 75 the Attempts / Rotations block came within 39 px
  of the dial while 264 px went unused on the right — it read as crowded on a
  real device. Padding is the SDK's documented positioning knob, and 48 is the
  safe-area inset the rest of the layout already uses, so the bar now spans it
  exactly. Everything else in that table is unchanged.
- **Body text weights.** Lato ships Regular and Bold only, so the original's
  `600` and `800` both land on Bold.
- **Feedback gradient.** The SDK's feedback text is a vertical gradient fill;
  Godot's text drawing has no gradient, so each variant uses its top colour plus
  the dark stroke that carries the read at that size.
- **Bundle size.** A Godot 4 web export ships the whole engine — roughly 35–40 MB
  uncompressed, ~7–10 MB Brotli — where the HTML5 build was a few hundred KB plus
  the 5 MB music track.

## Layout of the source

    src/constants.gd    design surface, layout, tuning, config declaration
    src/levels.gd       the forty rooms, sorted by difficulty, + a validator
    src/prototypes.gd   scratch rooms for design work, not shipped
    src/session_log.gd  playtest logging, local runs only
    src/sim.gd          orb simulation (node-free, verified against the JS)
    src/score.gd        scoring + flavor text (pure)
    src/game.gd         state machine, input, Minit lifecycle
    src/room_view.gd    the room and orb, inside the tumble transform
    src/pit.gd          the recessed frame the room sits in
    src/compass.gd      the gravity compass (top band)
    src/controls.gd     rotate buttons and pill (bottom band)
    src/fade.gd         full-viewport transition fade
    src/level_label.gd  room name and place in the run
    src/background.gd   decorative backdrop; the only reader of the live viewport
    src/particles.gd    particle pool
    src/audio.gd        synthesised SFX + music
    src/warmup.gd       glyph + pipeline warm-up, before loading_done()
    tools/reference/    the JS physics, scoring and search the verifier runs
    tools/lib/          levels.gd parser, JSON Schema validator
    src/draw_util.gd    rounded rects, arcs, letter-spaced text, fonts
    assets/fonts/       Lato + Bowlby One SC (SIL OFL), as used by the SDK
    src/ui/             header bar, feedback pops, flying rewards
    addons/minit/       the Minit Games SDK addon
    tools/              verification, capture and packaging

## Licence

MIT — see `LICENSE`.

Bundled third-party material keeps its own terms, listed in
`THIRD-PARTY-NOTICES.md`: the Minit Games SDK addon (MIT, Drop GmbH), and the
Lato and Bowlby One SC fonts (SIL OFL).

That includes the music: `assets/audio/neon-drift-circuit.mp3` was generated
with Suno on a Pro subscription, so it is owned outright and released under MIT
with everything else. Every sound effect is synthesised at runtime, and the game
runs without the track if it is removed.
