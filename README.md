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
node tools/check-meta.mjs                        # meta.json: schema + semantic
node tools/test-schema.mjs                       # the schema validator itself
node tools/difficulty.mjs                        # rank rooms vs their tier
node tools/difficulty.mjs --order                # the shipping order it implies
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
godot --path . -- --attempts=9 --startLevel=31 --endLevel=40   # the insane tier
godot --path . -- --startLevel=22 --endLevel=22                # one room
```

There is one more override, for design work rather than configuration:

```bash
godot --path . -- --rooms=prototypes --attempts=9
```

That swaps `src/levels.gd` for the scratch rooms in `src/prototypes.gd` — the
candidates being tested against the difficulty problem, measured by
`node tools/prototypes.mjs`. They are not the game, nothing about the shipped
set moves to accommodate them, and like every other override it is inert in a
web export. The nine attempts are worth passing: the last three rooms are
deliberately too tight and exist only for comparison.

From the editor, put the same arguments after `--` in **Project Settings →
Editor → Run → Main Run Args**. The game prints a line on startup when an
override is active, so a test run can't be mistaken for the shipped defaults.

A web export has no user args, so this is inert in production and cannot shadow
what the host sends. Overrides go through exactly the same coercion and clamping
as the host's values, so they cannot reach out-of-range settings either.

The default is the whole forty-room list, which is a long session — publishing
picks a segment instead. Note that `startLevel` / `endLevel` can only express a
*contiguous* range, so a drop that samples across tiers (say rooms 1, 11, 21, 31
for a curve inside one playthrough) is not expressible today; it would need a
different config key.

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

## Room order

`src/levels.gd` is sorted by measured difficulty, ascending, and the four tiers
are simply the four tenths of that order — so a drop that publishes a segment
gets a band that actually rises as it is played.

The ordering came out of `tools/difficulty.mjs`, which scores three independent
axes from the solver's cache: route length, whether a timing window is required
at all, and how lethal the room is. `par` alone measures only the first, and
sorting on it had left the tiers overlapping badly:

| | before | after |
| --- | --- | --- |
| strict inversions (easier-tier room beating a harder-tier one on every axis) | 17 | **0** |
| rooms in the wrong tenth | 20 | **2** |
| backward difficulty steps within tiers | 12 | **0** |
| avg par by tier | 3.8 / 6.1 / 8.4 / **7.4** | 3.8 / 6.1 / 6.4 / **9.4** |

The two remaining "misfiles" are deliberate: the cheapest room introducing each
element is pinned into the easy tier, because easy is also the teaching tier and
the default drop. That pin is the only departure from a pure sort.

What sorting could *not* fix: the execution axis still is not a curve (1, 1, 4, 2
rooms per tier need a timing window), because only 8 of 40 rooms demand timing at
all. That is a level-design gap, not an ordering one.

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
