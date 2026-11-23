"""After Play 5.4.0 audio.

- Jumpscare stings: the owner's six jumpscare sounds (Pixabay, Pixabay Content
  License) from the media folder, cut to the hit, levelled and faded so they can
  sit on top of every creature scream.
- Balloon burst: a synthesized cluster of balloon pops for the "party_burst"
  anomaly, which had accidentally been playing a scare scream.
"""
import pathlib, subprocess, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = pathlib.Path.home() / "Desktop" / "Medien After Play und Stream" / "02 After Play Sounds und Stimmen" / "Jumpscare Sounds"
OUT = ROOT / "games" / "kinderparadies" / "assets" / "jumpscare-v540"
OUT.mkdir(parents=True, exist_ok=True)

# file, start, length (s)
STINGS = [
    ("freesound_community-ascending-jumpscare-102061.mp3", 0.0, 2.6),
    ("freesound_community-jumpscare-68730.mp3", 0.0, 2.6),
    ("freesound_community-screamer-jumpscare-66896.mp3", 0.0, 2.4),
    ("jeremayjimenez-smile-dog-jumpscare-167171.mp3", 0.0, 2.09),
    ("sound_effects75-robotic_jumpscare-485532.mp3", 0.0, 2.4),
    ("freesound_community-fuzzy-jumpscare-80560.mp3", 0.0, 2.2),
]

for i, (name, start, length) in enumerate(STINGS, 1):
    fade = 0.7 if length > 2.2 else 0.35
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(length), "-i", str(SRC / name),
        "-af", f"afade=t=in:d=0.004,loudnorm=I=-11:TP=-1.0:LRA=7,afade=t=out:st={length - fade:.3f}:d={fade}",
        "-ar", "44100", "-ac", "2", "-c:a", "libvorbis", "-q:a", "6", str(OUT / f"sting-{i}.ogg"),
    ], check=True)

# Balloon burst: a few rubber pops in quick succession, each a broadband crack
# with a fast decay, a tiny tonal snap and a low body thump, plus a short room.
rate = 44100
rng = np.random.default_rng(540)
total = np.zeros(int(rate * 1.4))

def pop(gain, bright):
    n = int(rate * 0.18)
    t = np.arange(n) / rate
    noise = rng.uniform(-1, 1, n)
    hp = np.diff(noise, prepend=0)  # brighter crack
    crack = (bright * hp + (1 - bright) * noise) * np.exp(-t / 0.012)
    snap = np.sin(2 * np.pi * rng.uniform(1300, 2100) * t) * np.exp(-t / 0.006) * 0.5
    thump = np.sin(2 * np.pi * rng.uniform(85, 130) * t) * np.exp(-t / 0.035) * 0.6
    return (crack + snap + thump) * gain

for at, gain, bright in [(0.0, 1.0, 0.7), (0.06, 0.75, 0.55), (0.15, 0.85, 0.65), (0.33, 0.6, 0.5), (0.52, 0.45, 0.6)]:
    p = pop(gain, bright)
    s = int(at * rate)
    total[s:s + len(p)] += p

# Small-room reflections.
room = total.copy()
for delay, g in [(0.023, 0.35), (0.041, 0.25), (0.067, 0.18), (0.101, 0.11)]:
    d = int(delay * rate)
    room[d:] += total[:-d] * g
room /= np.max(np.abs(room)) / 0.93
tmp = OUT / "balloon-burst.wav"
with wave.open(str(tmp), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes((room * 32767).astype(np.int16).tobytes())
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", "6", str(OUT / "balloon-burst.ogg")], check=True)
tmp.unlink()

(OUT / "provenance.json").write_text("""{
  "sting-1.ogg ... sting-6.ogg": "Cut from the owner's jumpscare sounds in 'Medien After Play und Stream/02 After Play Sounds und Stimmen/Jumpscare Sounds' (Pixabay: freesound_community ascending-jumpscare-102061, jumpscare-68730, screamer-jumpscare-66896; jeremayjimenez smile-dog-jumpscare-167171; sound_effects75 robotic_jumpscare-485532; freesound_community fuzzy-jumpscare-80560), Pixabay Content License. Layered on every jumpscare from 5.4.0.",
  "balloon-burst.ogg": "Synthesized for the game by tools/generate-after-play-v540-audio.py (balloon pops for the party_burst anomaly).",
  "added_in": "5.4.0"
}
""", encoding="utf-8")
print("ok", sorted(p.name for p in OUT.iterdir()))
