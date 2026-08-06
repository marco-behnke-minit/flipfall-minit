# Flipfall — Godot 🔄🔵

A Godot 4 port of the HTML5 [Flipfall](../flipfall), a momentum-based gravity
puzzle for portrait mobile, built on the Minit Games SDK.

The game itself is unchanged: rotate gravity in 90° increments to guide a rolling
orb through handcrafted rooms; the room tumbles beneath a fixed gravity so
falling always reads as screen-down. `../flipfall/DESIGN.md` remains the design
document — this README only covers what the port does differently.

## Running

```bash
godot --path .                                   # play it
node tools/compare-trace.mjs                     # physics == the original's
godot --headless --script res://tools/test_score.gd   # scoring + flavor text
node tools/check-meta.mjs                        # meta.json == src/constants.gd
godot --script res://tools/gallery.gd --resolution 960x1480   # one still per room
godot --script res://tools/fade_check.gd --resolution 480x1200 # fade at a phone aspect
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

## Web export

Per the SDK's Godot article, the preset in `export_presets.cfg` sets **Thread
Support OFF** (a threaded build needs `SharedArrayBuffer`, which requires
cross-origin-isolation headers the host iframe does not guarantee), **PWA OFF**,
and **Canvas Resize Policy: Adaptive**.

## Layout

The original is authored against a fixed 960×1480 design surface and cover-scales
it, capping the crop at 5%. Godot's `canvas_items` / `expand` stretch does not
crop at all — it *reveals* extra viewport area on the wider axis — so:

- the viewport is the 960×1480 design surface, and `Surface` is centred in
  whatever the host actually gives us;
- `src/background.gd` is the only node that reads `get_viewport_rect()`, and it
  paints the full revealed area so no unpainted strip can appear at an edge.

Everything else is authored in design coordinates exactly as before.

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

**Sound effects are synthesised at startup** into `AudioStreamWAV` buffers, as
the original synthesised them in WebAudio — including an RBJ band-pass standing
in for the `BiquadFilterNode`. The music track is the one real audio asset and,
as before, is deliberately left playing under the host's result screen.

### Known deviations

- **Fonts.** The original picks up the device's `system-ui` at several weights,
  and the SDK's UI ships bundled Lato and Bowlby One SC as woff2 — a format Godot
  cannot load. Weights are synthesised from Godot's bundled face with
  `FontVariation`, so type is close but not identical.
- **Feedback gradient.** The SDK's feedback text is a vertical gradient fill;
  Godot's text drawing has no gradient, so each variant uses its top colour plus
  the dark stroke that carries the read at that size.
- **Bundle size.** A Godot 4 web export ships the whole engine — roughly 35–40 MB
  uncompressed, ~7–10 MB Brotli — where the HTML5 build was a few hundred KB plus
  the 5 MB music track.

## Layout of the source

    src/constants.gd    design surface, layout, tuning, config declaration
    src/levels.gd       the forty rooms + an authoring validator
    src/sim.gd          orb simulation (node-free, verified against the JS)
    src/score.gd        scoring + flavor text (pure)
    src/game.gd         state machine, input, Minit lifecycle
    src/room_view.gd    the room and orb, inside the tumble transform
    src/pit.gd          the recessed frame the room sits in
    src/hud.gd          compass, rotate buttons, pill, fade
    src/level_label.gd  room name and place in the run
    src/background.gd   decorative backdrop; the only reader of the live viewport
    src/particles.gd    particle pool
    src/audio.gd        synthesised SFX + music
    src/draw_util.gd    rounded rects, arcs, letter-spaced text, fonts
    src/ui/             header bar, feedback pops, flying rewards
    addons/minit/       the Minit Games SDK addon
    tools/              verification, capture and packaging
