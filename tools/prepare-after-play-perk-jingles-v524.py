"""Partynacht perk jingles from the owner's Pixabay picks, After Play 5.2.4.

Seven jingles in the desktop folder "Zombie Sounds" become twelve perk
jingles: the longer tracks give two different phrases each. Every cut starts
on a beat (tempo found from the onset envelope) and lasts two bars, clamped to
3.0-4.0 s, with a short fade in and a 0.7 s fade out; two tracks with a real
ending keep that ending instead. Loudness is matched, the originals are never
changed.

Run: python tools/prepare-after-play-perk-jingles-v524.py
Output: games/kinderparadies/assets/zombies-v524/jingles/<perk id>.ogg
"""
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / 'Desktop' / 'Medien After Play und Stream' / '02 After Play Sounds und Stimmen' / 'Zombie Sounds'
OUT = ROOT / 'games/kinderparadies/assets/zombies-v524/jingles'
SR, HOP = 22050, 256
MIN_LEN, MAX_LEN, FADE = 3.0, 4.0, .7

BOMB = 'bombinsound-kids-happy-background-music-09-second-495402.mp3'
CUTE = 'freesound_community-cute-music-26476.mp3'
BOUNCY = 'goldensoundlabs-bouncy-again-cheerful-opening-501854.mp3'
DUCK = 'goldensoundlabs-dancing-with-a-duck-energetic-opening-510257.mp3'
PATH = 'openmindaudio-cartoon-background-music-modern-path-short-preview-497396.mp3'
SPARK = 'openmindaudio-cartoon-good-vibes-intro-sunny-spark-497372.mp3'
OOPS = 'openmindaudio-cartoon-reaction-sting-oopsie-little-bounce-500909.mp3'

# perk id -> (track, which phrase: 0 = first strong phrase, 1 = a later one,
# 'end' = the track's own ending)
PERKS = {
    'pluesch_segen': (BOMB, 'end'),     # sweet, short, a real ending
    'grabesschritt': (OOPS, 'end'),     # "oops, missed me"
    'leerer_blick': (OOPS, 0),
    'hoellenlauf': (DUCK, 0),           # the fastest track
    'leichenfinger': (DUCK, 1),
    'todesatem': (BOUNCY, 0),
    'eiserne_rippen': (BOUNCY, 1),
    'seelenvorrat': (CUTE, 0),
    'achter_sinn': (CUTE, 1),
    'blutdurst': (PATH, 0),
    'zerreisser': (PATH, 1),
    'flackergeist': (SPARK, 0),         # "sunny spark"
}


def load(path: Path) -> np.ndarray:
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(float) / 32768


def analyse(x: np.ndarray):
    """Onset envelope, beat length in seconds and beat times."""
    n = 1024
    frames = np.lib.stride_tricks.sliding_window_view(x, n)[::HOP] * np.hanning(n)
    spec = np.log1p(np.abs(np.fft.rfft(frames, axis=1)) * 10)
    flux = np.concatenate([[0], np.maximum(np.diff(spec, axis=0), 0).sum(1)])
    flux = np.maximum(flux - np.convolve(flux, np.ones(16) / 16, 'same'), 0)
    fps = SR / HOP
    ac = np.correlate(flux, flux, 'full')[len(flux) - 1:]
    lo, hi = int(fps * 60 / 180), int(fps * 60 / 70)
    lag = lo + int(np.argmax(ac[lo:hi]))
    phase = max(range(lag), key=lambda o: flux[o::lag].sum())
    return flux, fps, lag / fps, np.arange(phase, len(flux), lag) / fps


def rms_db(x: np.ndarray, a: float, b: float) -> float:
    seg = x[int(a * SR):int(b * SR)]
    return 20 * np.log10(np.sqrt((seg ** 2).mean()) + 1e-9) if len(seg) else -120.


def last_sound(x: np.ndarray) -> float:
    """End of the music: last 50 ms window above -40 dB."""
    w = int(.05 * SR)
    for i in range(len(x) // w - 1, -1, -1):
        if rms_db(x, i * w / SR, (i + 1) * w / SR) > -40:
            return (i + 1) * w / SR
    return len(x) / SR


def phrases(x: np.ndarray):
    """Candidate starts: strong beats with a full, loud two bars after them."""
    flux, fps, beat, beats = analyse(x)
    length = float(np.clip(beat * 8, MIN_LEN, MAX_LEN))
    end = last_sound(x)
    out = []
    for t in beats:
        if t + length > end - .3 or t < .05:
            continue
        i = int(t * fps)
        strength = flux[max(i - 2, 0):i + 3].max() / (flux.max() + 1e-9)
        out.append((strength + rms_db(x, t, t + length) / 40, t))
    out.sort(reverse=True)
    picked = []
    for _, t in out:  # best phrases at least two cuts apart
        if all(abs(t - p) > length * 2 for p in picked):
            picked.append(t)
    return sorted(picked[:2]), length, beat, end


def main() -> None:
    assert shutil.which('ffmpeg'), 'ffmpeg is needed'
    OUT.mkdir(parents=True, exist_ok=True)
    sources = []
    cache = {}
    for perk, (track, which) in PERKS.items():
        src = SOURCE / track
        if track not in cache:
            x = load(src)
            cache[track] = (x, *phrases(x))
        x, starts, length, beat, end = cache[track]
        if which == 'end':
            start = max(beat * round((end - MAX_LEN) / beat), 0.)
            if end - start < MIN_LEN:
                start = max(start - beat * 2, 0.)
            length, fade = end - start, .25
        else:
            start, fade = starts[min(which, len(starts) - 1)], FADE
        fade_at = max(length - fade, 0.)
        out = OUT / f'{perk}.ogg'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{start:.3f}', '-t', f'{length:.3f}', '-i', str(src), '-af',
                        f'afade=t=in:d=0.015,afade=t=out:st={fade_at:.3f}:d={fade:.3f},loudnorm=I=-17:TP=-1.5:LRA=11',
                        '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '6', str(out)], check=True)
        sources.append({'file': out.name, 'source': track, 'start': round(start, 3), 'length': round(length, 3)})
        print(f'{perk:15s} {start:6.2f} s + {length:4.2f} s  <- {track[:48]}  ({60 / beat:.0f} BPM)')
    (OUT / 'jingle-sources.json').write_text(json.dumps({'license': 'Pixabay Content License', 'jingles': sources}, indent=1),
                                            encoding='utf-8')


main()
