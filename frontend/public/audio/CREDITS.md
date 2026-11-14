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

## PEPPLE Pinball (`audio/pinball/`, `music/pinball/`)

Main in-game track (not CC0): `music/pinball/arcade-rush.mp3`, "Arcade Rush" (made with Suno), supplied by the site owner.

All CC0 (public domain), credited anyway:
- Sound effects: Kenney Impact Sounds, Digital Audio, Interface Sounds, Sci-fi Sounds and Music Jingles (https://kenney.nl). Licence: `audio/pinball/Kenney-License.txt`.
- `music/pinball/play.mp3`: "Synth Wave" by Pro Sensory, https://opengameart.org/content/synth-wave (no longer used in play)
- `music/pinball/multiball.mp3`: "Synthwave House Loop" by Fupi, https://opengameart.org/content/synthwave-house-loop
- `music/pinball/attract.mp3`: "arcade background music" by aqrezes, https://opengameart.org/content/arcade-background-music

Music files were loudness-normalised (-17 LUFS) and re-encoded to MP3; nothing else was changed. The pinball uses no synthesized tones or oscillators; music can be switched off in the game.
- Announcer voices (`audio/pinball/vo-*.ogg`): Kenney Voiceover Pack and Voiceover Pack: Fighter, CC0 (https://kenney.nl).
- The chibi girls Mimi and Luna are original SVG drawings in `src/pinball/crew.jsx`.
