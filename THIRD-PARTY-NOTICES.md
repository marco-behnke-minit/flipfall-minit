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

## Music — Suno Basic plan, NON-COMMERCIAL ONLY, NOT REDISTRIBUTABLE

`assets/audio/loop.mp3` was generated with [Suno](https://suno.com) on the
**Basic (free) plan**. Under Suno's terms for that tier:

- **Suno owns the song.** The account holder does not.
- Use is permitted for **non-commercial purposes only**.
- Subscribing to a paid plan later does **not** grant rights retroactively to
  songs made on the free plan; Suno considers that case by case.

Two consequences, and neither is about this repository's own code:

1. **It is not ours to redistribute.** The MIT grant in `LICENSE` does not
   extend to this file, and a public repository would be offering others rights
   the account holder does not hold. Keep the repository private while this file
   is in it — noting it is in git history from the first commit, so removing it
   from the tip is not enough to undo that.

2. **It likely cannot ship commercially.** Publishing on a platform where
   creators can earn is hard to characterise as non-commercial use. That needs
   settling before release, not after.

The clean fix is to regenerate the track while subscribed to Pro or Premier, so
the song is owned outright with a commercial licence — or to replace it with one
whose terms are already clear.

Removing it degrades gracefully and is a real option: with the file gone the
game still boots, fires `loading_done` and `report_result`, and raises no
errors. Every sound effect is synthesised at runtime; music is the only asset.

Sources: Suno, [Do I have the copyrights to songs I
made?](https://help.suno.com/en/articles/2746945) and [If I subscribe, do I get
rights for the songs I made before
subscribing?](https://help.suno.com/en/articles/2425729)
