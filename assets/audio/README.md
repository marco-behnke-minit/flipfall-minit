# Music

`neon-drift-circuit.mp3` is the game's only audio asset — every sound effect is
synthesised at runtime in `src/audio.gd`. The filename is referenced by
`MUSIC_PATH` there, so a replacement either takes the same name or updates it.

The game runs fine without a track: `src/audio.gd` checks for the file, warns
once and plays on in silence, so a missing or removed track degrades rather than
breaks.

## Licensing

Whatever goes here has to be redistributable, because this repository is public
and the track ships inside the exported `.pck`.

The current track was generated with Suno on a **Pro** subscription, which
grants ownership and commercial use, and is released under this project's MIT
licence along with everything else. Its terms are recorded in
`THIRD-PARTY-NOTICES.md`, and its ID3 tags carry the copyright line and Suno's
provenance id. Record the same for any replacement.
