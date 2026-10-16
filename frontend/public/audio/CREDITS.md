# Game audio

Actual OGG one-shot samples from Kenney, Creative Commons CC0:
- Sci-fi Sounds: https://kenney.nl/assets/sci-fi-sounds
- Impact Sounds: https://kenney.nl/assets/impact-sounds

Original license notices are included alongside the clips. Audio files are unchanged; playback gain/rate and a limiter are applied by the game. No continuous synthesized music or ball oscillator is used.

NULLSIGNAL's `nullsignal-workshop.wav` and `nullsignal-low-power.wav` are original
offline-rendered non-musical noise/room textures, not third-party recordings.
Reproduce them with `node frontend/scripts/generate-nullsignal-ambience.mjs`.
The room-only bus loops these finite WAV files with seam crossfades; one-shot
mechanical details use the existing CC0 impact sample. No tonal melody or
continuous Web Audio oscillator is used. The user's MP3 tracks are separate.
