# Flipfall 🔄🔵

> A momentum-based gravity puzzle for portrait mobile, built on the Minit Games SDK.

## High Concept

The player never controls the ball directly.

They rotate **gravity** in 90° increments to guide a rolling orb through
handcrafted puzzle rooms. Forty rooms, sorted by measured difficulty and split
into four tiers of ten. A drop publishes all forty by default, and can publish a
single tier instead by setting `startLevel` / `endLevel`.

------------------------------------------------------------------------

# Core Pillars

-   One simple mechanic: rotate gravity.
-   Learn in seconds, master through clever level design.
-   Mid-flight rotation creates curved trajectories and last-second saves.
-   The room tumbles so falling always reads as screen-down.
-   Small handcrafted rooms — one screen, one puzzle.
-   Every room machine-verified solvable before it ships.

------------------------------------------------------------------------

# Controls

Two large buttons, plus an instant reset.

-   **↺** rotate gravity counter-clockwise
-   **↻** rotate gravity clockwise
-   **Retry** reset the room — costs 1 Attempt

Gravity cycles clockwise: `Down → Left → Up → Right`
(and counter-clockwise: `Down → Right → Up → Left`)

**The button glyph describes what the room does, not what the gravity
vector does — and those are opposites.** Turning gravity clockwise
(`Down → Left`) tips the room counter-clockwise, so **↺ sends gravity
clockwise**. Getting this backwards makes the world visibly spin against
the icon the player just pressed, which reads as a bug.

**Rotation is allowed at any time, including mid-flight.** This is the
mechanic. Restricting it to rest states would reduce every puzzle to
wait → rotate → wait → rotate, and would remove curved trajectories,
momentum puzzles, last-second saves and speed-running skill.

------------------------------------------------------------------------

# The Room Tumbles

Falling must always read as **screen-down**. So on every rotation the
room turns a quarter turn beneath a fixed gravity direction, over 240 ms
with an ease-out.

This was originally specified the other way round — gravity rotating
inside a fixed room — on the grounds that the player should never have to
re-read the maze. Playtesting reversed it: with a fixed room, a sideways
or upward fall is genuinely hard to parse, and that cost more than
re-reading does.

A square rotated 45° needs `sqrt(2)` times its own width — 1103 px, which
a 960 px surface does not have. So the room scales to exactly fit while
turning (71% at 45°, 100% at rest). Nothing is ever clipped, and the
shrink reads as a deliberate tumble.

Also animates on a rotation:

-   the compass dial (see below)
-   a 2 px screen shake
-   a downward particle whoosh

A new room always opens upright, never mid-turn.

## The compass

Because gravity is always screen-down, the arrow is **fixed** and the
**dial** rotates instead. The amber tick marks the room's original top,
so the player can always see how far the room has turned from the way
they first read it.

------------------------------------------------------------------------

# Run Structure

One run = one session. No menus, no cross-session progression.

-   The rooms of the published segment, played in order — all forty by default
-   3 **Attempts** shared across the whole run
-   An Attempt is spent when the player hits spikes, falls out of the
    room, **or** presses Retry — all three mean "I couldn't solve this
    attempt", so there is no need to distinguish dying from giving up
-   Reaching 0 Attempts ends the run immediately
-   Clearing the final room ends the run — even on the last Attempt

Charging Retry an Attempt is deliberate. A free Retry would make the
optimal strategy "make one bad rotation, reset, lose nothing", which
makes Attempts meaningless and pushes players to reset after every
awkward slide instead of improvising a recovery.

A Retry resets the room's clock and rotation count. The lost Attempt is
the penalty, so there is nothing left to punish — and resetting for a
cleaner start buys nothing.

------------------------------------------------------------------------

# First-Input Rule

The orb does not move until the player rotates gravity. Every room loads
frozen:

    gravity        = Down
    velocity       = 0
    physicsPaused  = true
    clock          = 0

The first rotation unfreezes physics and starts that room's clock. On
room 1 the two buttons pulse and a prompt reads **ROTATE GRAVITY / TO
BEGIN** — the first action the player takes *is* the mechanic, so no
tutorial text is needed.

Applying the freeze to *every* room (not just the first) means no room
can ever fail before the player has read it, and reading time is free.

------------------------------------------------------------------------

# Scoring

    +1000   per room cleared
    +500    per Attempt still in hand when the run ends
    -5      per gravity rotation (winning attempt only)
    +time   max(0, 200 - seconds x 10) per room

Measured by `tools/run-sim.js`, which plays the segment with the real physics
and the real scoring module.

The default drop is all forty rooms (`npm run sim -- <think> 1 40`):

| Play style              | Active play | Final score |
| ----------------------- | ----------- | ----------- |
| Flawless speedrun       | 5m 01s      | 45208       |
| Confident (8s/room)     | 10m 21s     | 42035       |

That is a long session for a Minit — the two-to-five-minute target belongs to a
single ten-room tier, which a drop can still publish on its own.

Rooms 1–10 (`npm run sim -- 15 1 10`):

| Play style              | Active play | Final score |
| ----------------------- | ----------- | ----------- |
| Flawless speedrun       | 0m 44s      | 12871       |
| Confident (8s/room)     | 2m 04s      | 12071       |
| Deliberate (15s/room)   | 3m 14s      | 11444       |
| Slow (25s/room)         | 4m 54s      | 11310       |

All four segments at 15s deliberation, which is what makes scores comparable
across differently-published drops:

| Segment          | Active play | Final score |
| ---------------- | ----------- | ----------- |
| easy   (1–10)    | 3m 14s      | 11444       |
| medium (11–20)   | 3m 45s      | 11214       |
| hard   (21–30)   | 4m 09s      | 11082       |
| insane (31–40)   | 3m 52s      | 11150       |

Harder tiers take longer and score marginally lower, since the rotation
penalty grows with route length — they are longer, not stingier, and every
segment lands inside the 2–5 minute target. Insane scoring *above* hard is
the same length imbalance recorded under [Rooms and Tiers](#rooms-and-tiers),
showing up in the score.

The time bonus is a mastery reward, not a punishment — it floors at 0
after 20 s and a thoughtful run still scores ~11.3k.

## Rotation budget

Soft limit only. The header shows `Rotations 7 / 5` purely as
information. Hard caps produce "oops, I'm one move over"; soft scoring
says "I solved it… but maybe there's a cleaner solution."

------------------------------------------------------------------------

# Core Objects

| Tile        | Meaning                                              |
| ----------- | ---------------------------------------------------- |
| `#`         | Wall                                                 |
| `.`         | Air                                                  |
| `O`         | Orb spawn                                            |
| `E`         | Exit — clears the room                               |
| `^`         | Spike — omnidirectional caltrop, fatal from any side  |
| `1` `2` `3` | Button — **latching**, stays pressed forever          |
| `a` `b` `c` | Door — opened for good by button 1 / 2 / 3            |
| `I`         | Ice — almost no grip                                 |
| `T`         | Sticky — stops the orb dead                          |

Buttons latch rather than being momentary. Momentary buttons create
escort and timing puzzles that don't fit a deliberate puzzle game, and
players never have to babysit anything.

## How friction actually works

Gravity is always axis-aligned, so it is always exactly perpendicular or
exactly parallel to any surface. Parallel means the orb is **not pressed
into** the surface at all — so it glides past with no contact and no
friction.

Friction therefore only bleeds off *residual* velocity after a direction
change. That makes Ice and Sticky mechanics about **landing and
skidding**, not sliding:

| Surface | Skid from full speed |
| ------- | -------------------- |
| Stone   | ~5 cells             |
| Ice     | most of the room     |
| Sticky  | half a cell          |

Sticky is the only way to stop somewhere precise; Ice is the reason you
can't. Both require one mid-flight rotation, which is what earns them
their place in the progression.

------------------------------------------------------------------------

# Rooms and Tiers

Forty rooms in four tiers of ten. A drop publishes one segment via the
`startLevel` / `endLevel` config, so difficulty is a publishing decision
rather than an in-run curve.

| Tier   | Rooms | Avg par | Needs timing | Character                          |
| ------ | ----- | ------- | ------------ | ---------------------------------- |
| easy   | 1–10  | 3.8     | 1/10         | Teaches one element at a time; rest-only apart from the finale. |
| medium | 11–20 | 6.1     | 1/10         | Longer routes on the same elements; the crossings grow, not the precision. |
| hard   | 21–30 | 6.4     | 4/10         | Execution starts to matter, and hazards become route constraints. |
| insane | 31–40 | 9.4     | 2/10         | The longest chains, the most lethal rooms, the narrowest brake pads. |

**The tiers are the four tenths of a measured ranking**, not an authoring
judgement — see [Difficulty ranking](#difficulty-ranking). Sorting them this way
removed 17 strict inversions (an easy room beating a hard room on every axis at
once), cut misfiled rooms from 20 to 2, and made every tier rise monotonically as
it is played. The two remaining "misfiles" are deliberate: the sticky teacher is
pinned into easy, because easy is also the teaching tier.

**Remaining imbalance:** the *execution* axis still is not a curve — 1, 1, 4, 2
rooms per tier need a timing window. Sorting cannot fix that; only 8 of 40 rooms
demand any timing at all, so there is nothing to distribute. That is a
level-design gap, not an ordering one.

## What actually makes a room harder

Door and button *sides* change the route; hazards only punish deviation
from it. An early draft of the hard and insane tiers decorated one
skeleton with spikes, ice and open edges — and the solver reported twelve
rooms with an identical 12-rotation, 13.2 s solution. They were one room
with twelve skins. The tiers were rebuilt by varying which end each door
and each button sits on, which is what actually changes the answer.

The easy tier teaches one element per room:

| #  | Room     | Teaches                              |
| -- | -------- | ------------------------------------ |
| 1  | Roll     | rotate gravity                       |
| 2  | Press    | buttons and doors                    |
| 3  | Glide    | ice — fast, hard to stop             |
| 4  | Ledge    | open edges — you can fall out        |
| 5  | Teeth    | spikes — look before you leap        |
| 6  | Climb    | chained doors, gravity-up            |
| 7  | Rink     | a door chain over ice                |
| 8  | Needle   | one safe column through the spikes   |
| 9  | Zigzag   | doors alternating ends               |
| 10 | Grip     | sticky — landing to brake, and the first room that needs timing |

The cheapest room introducing each element is pinned here, which is the one place
the ordering departs from a pure difficulty sort.

------------------------------------------------------------------------

# Camera & Transitions

One screen = one puzzle. No scrolling, and the camera never pans or
tracks — the only movement is the room's own quarter-turn tumble.

On clear: exit flashes → orb shrinks into the exit (200 ms) → fade out
(130 ms) → next room fades in (130 ms). Total under 500 ms.

On death: burst + shake (300 ms) → fade (90 ms) → reset (90 ms).

On Retry: instant. No confirmation, no animation.

------------------------------------------------------------------------

# Visual Style

Minimal, clean geometric shapes, strong contrast, the orb the brightest
object on screen so the eye follows it.

| Element    | Colour      | Hex       |
| ---------- | ----------- | --------- |
| Background | Charcoal    | `#1E1F26` |
| Pit        | Near-black  | `#16171C` |
| Walls      | Slate       | `#4A5568` |
| Orb        | Bright Cyan | `#34D1FF` |
| Exit       | Emerald     | `#22C55E` |
| Buttons    | Amber       | `#FBBF24` |
| Doors      | Indigo      | `#6366F1` |
| Spikes     | Crimson     | `#EF4444` |
| Ice        | Pale Blue   | `#C7F2FF` |
| Sticky     | Purple      | `#7C3AED` |
| HUD        | White       | `#FFFFFF` |

------------------------------------------------------------------------

# Audio

Sound effects are **synthesised in WebAudio** — no files, nothing to load
before the first interactive frame. Music is one bundled track.

## Music, and why it is shaped like this

`public/audio/loop.mp3` — 5m 09s, 44.1 kHz stereo, 128 kbps, 5.0 MB. It is
fetched **once, in full**, and played from a `blob:` URL through a media
element.

Every part of that sentence is load-bearing, and each was arrived at by
fixing a bug:

**Not `decodeAudioData`.** Decoded PCM is `duration x sampleRate x channels
x 4 bytes` — about 104 MB for this track, which a phone WebView will not
tolerate. Bitrate does not enter that formula, so re-encoding does not help;
only duration, channels and sample rate do. Roughly **mono under ~100 s** is
where full decoding becomes viable.

**From a blob, not streamed.** Streaming makes the media element cross-origin
inside the sandboxed play-page frame, which *taints* it — and a tainted
element routed through `createMediaElementSource` emits **pure silence while
`currentTime` advances**. A `blob:` URL is same-origin to the frame that
created it, so taint becomes impossible. It also removes range requests, so
playback cannot stall mid-file. The CDN sends
`access-control-allow-origin: *`, which is what makes the fetch readable.

**`preload='none'`.** The element used to stream the whole file while the
prefetch downloaded it again — 10 MB for a 5 MB track, and doubled again
because the play page mounts the game twice.

**`src` is set before the fetch resolves**, so the first tap always has
something to play. Deferring `play()` until a fetch resolves leaves the
gesture, and iOS blocks it.

## Volume routes

Chosen by capability, never by sniffing the platform, and never in a way that
can end in silence:

| Route      | When                                              | Fades |
| ---------- | ------------------------------------------------- | ----- |
| `element`  | `el.volume` is writable (desktop, Android)         | yes   |
| `webaudio` | volume read-only (iOS) **and** the source is a blob, so provably untainted | yes |
| `fixed`    | volume read-only and still streaming               | no    |

`element` fades are advanced from the **game's animation frame, never a
timer**. Chrome throttles timers in iframes, and a throttled interval leaves
the volume parked at its start value — silent, while `paused` is false and
`currentTime` advances. Safari escaped that bug only because iOS has
read-only volume and therefore takes the WebAudio route, whose ramp runs on
the audio clock. Driving fades from the frame loop means that if the fade is
throttled the game is frozen anyway.

Belt and braces: `element` mode starts at 40% of target rather than 0, so the
worst case for a fade that never advances is *quieter than intended* rather
than *silent*.

## Lifecycle

-   Buffering starts at load; `loadingDone()` is **never** gated on it
-   Playback begins on the **first rotation**, inside the pointer gesture
    that already unlocks audio, so it starts exactly when the run does
-   Ducks to 40% under the level-clear jingle and the death sting
-   **Keeps playing under the host's result screen** — a run should not end
    in sudden silence. `stopMusic()` exists but is not called.
-   Pauses on `visibilitychange`, resumes if the run is still live
-   A missing or undecodable file leaves gameplay untouched

## The lesson worth keeping

Two separate bugs produced the *same* symptom: **plays, `currentTime`
advances, silent**. Once from a tainted graph, once from a throttled timer.
`paused === false` and an advancing `currentTime` are therefore **not**
evidence of audibility, and any check that stops there proves nothing.

The test that actually works is an `AnalyserNode` tapped onto the graph: a
tainted or silent source reads all zeros, a real one does not.

`window.flipfallMusic()` reports the live route, source kind, volume, target
and context state, for diagnosing this on a device that cannot be attached to
a debugger.

------------------------------------------------------------------------

# Resolution & Layout

Fixed design surface: **960 × 1480**, portrait only. Every position,
size and bound is authored against it. The live viewport is read in
exactly one place (`src/scale.js`) for the wrapper's uniform scale.

    scaleCover = max(innerWidth / 960, innerHeight / 1480)

Crop is capped at 5% per axis; beyond that it falls back to a fit that
letterboxes slightly rather than cutting gameplay.

| Element         | Position (logical)                          |
| --------------- | ------------------------------------------- |
| SDK header bar  | y 60, side padding 75                       |
| Gravity compass | (480, 115) r 52                             |
| Playfield       | 780 × 780 at (90, 215), 13 × 13 cells of 60 |
| ↺ button        | (250, 1130) r 118                           |
| ↻ button        | (710, 1130) r 118                           |
| Retry / prompt  | (480, 1330) 320 × 120                       |

All gameplay-critical elements sit inside the central 90% safe area
(48–912 horizontally, 74–1406 vertically). The decorative background
canvas is overscanned 5% per side so an edge crop never reveals a gap.

------------------------------------------------------------------------

# Minit SDK Integration

-   `initializeSDK()` at startup
-   `loadingDone()` on the first drawn frame — never gated behind a button
-   `reportResult(score, { flavorText })` once, when the run ends
-   No start menu, no pause menu, no replay menu, no in-game result UI —
    the host owns all of it
-   `createHeaderBar({ container: wrapper })` so the HUD scales with the
    surface and `getPosition()` returns logical coordinates
-   Feedback on every emotionally significant beat: room clear, door
    opened, spiked, fell out, retry, last attempt
-   `spawnRewards` flies the room's points from the exit to the Score panel
-   `flavorText` reports a session *moment*, never the score — e.g.
    "All 10 rooms, never touched a spike", "Impaled 3 times"
-   `meta.json` declares `config` (see below), `resultSorting`, and
    `schemaVersion: 1`
-   No `userData`: one self-contained session, no cross-session state
-   No external requests: the music ships inside the ZIP and every sound
    effect is synthesised (see [Audio](#audio))

------------------------------------------------------------------------

# Verification

Levels are not hand-checked — they are proved by running the shipped
physics under Node.

    npm run solve            verify every room is solvable, print par
    npm run solve:force      re-search everything, ignoring the cache
    node tools/solve.js 7    print room 7's solutions step by step
    npm run sim 8            simulate a full run, 8s thinking per room
    npm run check-meta       validate meta.json against the console schema
    npm run zip              verify + build + package the upload ZIP

`tools/solve.js` runs two searches per room:

-   **rest-only** — rotations only while the orb is settled, so the
    player never has to hit a timing window. Its length becomes `par`.
-   **timed** — rotations at any moment. Reports the fewest-rotation
    route and the *most forgiving* route, with the width of the tightest
    timing window in each.

A room ships only if it is rest-only solvable **or** has a timed route with
a window a human can hit. How wide is a difficulty decision, so the bar
scales with the tier:

| Tier   | Minimum window |
| ------ | -------------- |
| easy   | 250 ms         |
| medium | 200 ms         |
| hard   | 120 ms         |
| insane | 60 ms          |

## Difficulty ranking

`par` orders rooms by route *length*, which is only one axis of difficulty — it
says nothing about whether a route needs a timing window, or how much of the room
kills you for missing it. Sorting on it alone let the tiers overlap badly enough
that an easy room outranked a hard one.

`tools/difficulty.mjs` (in the Godot project) reads the solver's cache and scores
every room on three axes:

-   **planning** — rotations on the route a player actually takes
-   **execution** — whether the room is rest-only solvable at all, and if not,
    how tight the most forgiving window is
-   **risk** — spikes, and gaps in the border the orb can leave through

It reports the ranking against the filed tier, and — independent of any weighting
— every *strict inversion*, where a room in an easier tier beats one in a harder
tier on all three axes at once. Those are what the room order is sorted to
remove.

## Result cache

Searching forty rooms takes 4m 24s, which is far too slow to sit in front of
every `npm run zip`. Results are cached in `.levelcache.json` (gitignored),
keyed by a hash of **each room's own map**, plus a hash of everything else
that could change the answer: `physics.js`, `constants.js` and `search.js`.

That split is the whole point — a cache that can serve a stale result is
worse than no cache:

| Change                          | Effect                        |
| ------------------------------- | ----------------------------- |
| one room's map edited           | that room re-searched (~4 s)   |
| room renamed or reordered       | full cache hit                |
| physics, constants or search    | entire cache discarded, announced |

Freshly searched rooms are marked `+`. Warm, `npm run zip` is **0.8 s**
rather than 4m 24s. `npm run solve:force` ignores the cache.

The cache is gitignored, so a fresh clone pays the 264 s once. Committing it
would make clones instant at the cost of churn on every level edit.

## `par` comes from the solver

`npm run solve -- --fix-par` rewrites `par` in `src/levels.js` from the route
the solver actually found. Par was originally guessed while authoring and was
wrong on 19 of 40 rooms.

## What validateLevels enforces

Cheap authoring slips that the solver would otherwise spend minutes failing
to route around:

-   13x13, one orb spawn, at least one exit, known tile characters only
-   a door with no button, **and** a button with no door — the second one
    shipped a broken room (Eventide) before the check existed
-   the room count matches the declared tier structure

------------------------------------------------------------------------

# Config

Declared in `meta.json`'s `config` block, which is what makes the keys
discoverable to whoever sets up the drop (and unlocks the Allow
Superposting toggle in the create wizard).

| Key          | Type   | Default | Bounds  | Moddable | Purpose                        |
| ------------ | ------ | ------- | ------- | -------- | ------------------------------ |
| `attempts`   | number | 3       | 1 – 9   | yes      | Failed solves allowed per run  |
| `startLevel` | number | 1       | 1 – 40  | **no**   | First room of the drop         |
| `endLevel`   | number | 40      | 1 – 40  | **no**   | Last room of the drop          |

`startLevel` / `endLevel` select the segment of the room list a drop plays. The
default is the whole list; a drop can publish a single difficulty band instead by
setting a tenth — 1–10 easy, 11–20 medium, 21–30 hard, 31–40 insane — because the
list is sorted by measured difficulty. Both are locked (`moddable: false`) on
purpose — a mod that swapped the room set would report a score for a run nobody
played.

`tools/check-meta.js` validates in two layers:

-   **Schema** — `meta.schema.json`, the mirror of the console's Zod
    source. Authoritative on shape, types and field names, and it rejects
    unknown fields, so a typo'd `moddible` fails rather than being
    silently ignored.
-   **Semantic** — the cross-field and cross-file rules JSON Schema cannot
    express: keys unique *after trimming*, a value actually inside its own
    range or bounds, and agreement with `CONFIG` in `src/constants.js`.

`CONFIG` is the single source of truth: the game reads and clamps through
it, and the build fails if it and `meta.json` disagree on any key, type,
default or bound — a wizard and a runtime enforcing different rules is a
bug that would only surface in production.

Values arrive as strings or `undefined`, so every read is coerced and
clamped: `attempts=99` becomes 9, `startLevel=abc` becomes room 1.

**Nothing that affects physics is configurable.** Gravity, friction and
max speed are what `tools/solve.js` proved the rooms solvable at; exposing
them would invalidate every proof.

`resultSorting` is `highestScore` — Flipfall's score is higher-is-better.

------------------------------------------------------------------------

# Project Layout

    src/constants.js     design surface, layout, tuning, tiers, CONFIG
    src/levels.js        the forty rooms + an authoring validator
    src/physics.js       orb simulation (DOM-free, shared with the solver)
    src/score.js         scoring + flavor text (pure, unit-verifiable)
    src/scale.js         the only place the viewport is read
    src/render.js        all drawing
    src/particles.js     particle pool
    src/audio.js         synthesised SFX + the music routes
    src/main.js          state machine, input, SDK lifecycle
    public/meta.json     Creator Console metadata + config declaration
    public/audio/        the music track, copied verbatim to the ZIP root
    meta.schema.json     JSON Schema mirror of the console's Zod source
    tools/search.js      shared level-solving search
    tools/solve.js       level verifier + result cache
    tools/run-sim.js     whole-run simulation
    tools/check-meta.js  meta.json + config validator (schema + semantic)
    tools/zip.js         upload packaging + pre-flight checks
    vite.config.js       single-file inlining, dotfile stripping

## Packaging

`npm run zip` verifies, builds, runs pre-flight checks and produces the
upload archive:

    index.html      123 KB    everything inlined — no JS/CSS side files
    audio/loop.mp3  4990 KB
    meta.json         3 KB

`index.html` and `meta.json` sit at the ZIP root, audio alongside. The
pre-flight refuses to package a build with `src/`, a `vite.config.*`, a
`package.json`, an external URL, a dotfile, or a `meta.json` that would be
rejected. Vite copies `public/` verbatim *including dotfiles*, so the build
strips them — a `.gitkeep` shipped inside an upload before that existed.

------------------------------------------------------------------------

# Deliberately Excluded

-   Multiplayer
-   Meta progression, currency, unlocks, retention hooks
-   Start menu, pause menu, replay menu
-   Landscape orientation
-   Paint gameplay, teleporters, auto-gravity tiles, pushable crates
-   Global timers (the per-room clock only feeds the time bonus)
-   Configurable physics. Gravity, friction and max speed are what the
    solver proved the rooms solvable at; exposing them would invalidate
    every proof at once.
-   Moddable room ranges. `startLevel` / `endLevel` are creator-set but
    locked to mods, so a mod cannot swap the room set out from under a score.

------------------------------------------------------------------------

# Design Goal

Every room asks one question:

> "How can I manipulate gravity and momentum to reach the exit?"

Every new element deepens that single idea rather than introducing an
unrelated system.
