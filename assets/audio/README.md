# Music

The game expects one looping track here as `loop.mp3`. It is the only audio
asset — every sound effect is synthesised at runtime in `src/audio.gd`.

The game runs fine without it: `src/audio.gd` warns once and plays on in
silence, so a missing track degrades rather than breaks.

## Licensing

Whatever goes here has to be redistributable, because this repository is public
and the track ships inside the exported `.pck`. A previous track was generated
on Suno's Basic (free) plan, where Suno owns the song and use is non-commercial
only — not compatible with either. See `THIRD-PARTY-NOTICES.md`, and record the
new track's terms there.
