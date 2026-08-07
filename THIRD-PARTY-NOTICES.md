# Third-party notices

The MIT licence in `LICENSE` covers this project's own code and content. The
material below is bundled with it and stays under its own terms — MIT does not
and cannot relicense it.

## Minit Games SDK — MIT

`addons/minit/minit.gd` is the Minit Games Godot SDK facade, redistributed
unmodified.

> Copyright (c) 2024 Drop GmbH — MIT License

The full text is in `addons/minit/LICENSE`, which MIT requires to travel with
the code.

## Lato — SIL Open Font License 1.1

`assets/fonts/Lato-Regular.woff2`, `assets/fonts/Lato-Bold.woff2`. Used for the
HUD, matching the typeface the Minit SDK's own header bar ships.

Source: Google Fonts, latin subset. Full text in `assets/fonts/Lato-OFL.txt`.

## Bowlby One SC — SIL Open Font License 1.1

`assets/fonts/BowlbyOneSC-Regular.woff2`. Used for the feedback pops, matching
the SDK.

Source: Google Fonts, latin subset. Full text in
`assets/fonts/BowlbyOneSC-OFL.txt`.

The OFL permits bundling and redistribution with the licence text, and forbids
selling the fonts on their own or releasing them under a reserved font name.
Neither applies here.

## Godot Engine — MIT

A web export embeds the Godot engine runtime. Godot is MIT licensed
(Copyright (c) 2014-present Godot Engine contributors), and the exporter emits
its own copyright notice into the build. Nothing in this repository contains
engine source.

## Music — LICENCE NOT ESTABLISHED

`assets/audio/loop.mp3` (5 m 09 s, 5.0 MB) came across from the HTML5 project,
which recorded no provenance for it: the placeholder it replaced only said
"drop the music loop here", and the shipped file does not match that note's
spec. **Its licence and origin are unknown to this repository.**

Consequences, until that is resolved:

- The MIT grant in `LICENSE` does **not** extend to this file.
- Do not treat this repository as redistributable in full, and take care before
  making it public.

To resolve: confirm the source and terms, add them here, and either keep the
file or replace it with one whose licence is known. If it turns out to be
unlicensed for redistribution, removing it degrades gracefully — `src/audio.gd`
warns and plays on in silence, and every sound effect is synthesised at runtime
rather than loaded.
