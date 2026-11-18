"""Close thunder for the storm over Happyland, After Play 4.11.0.

Three strikes right over the building, synthesised (no recording): a split-
second tearing crack of broadband noise in rapid bursts, then a long rolling
rumble of low, brown noise that swells and ebbs, with a sub-bass thump. The
existing distant thunder recordings stay for far-away flashes.

Run: python tools/make-after-play-thunder-v4110.py
Output: games/kinderparadies/assets/weather-v4110/close-thunder-1..3.ogg
"""
import hashlib
import json
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/weather-v4110'
RATE = 44100

def lowpass(x, cutoff):
    # One-pole low-pass, vectorised through an IIR via cumulative weighting in blocks.
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x); acc = 0.
    for i in range(0, len(x), 4096):
        block = x[i:i + 4096]; out = np.empty_like(block)
        for j, v in enumerate(block):
            acc = (1 - a) * v + a * acc; out[j] = acc
        y[i:i + 4096] = out
    return y

def strike(seed, seconds):
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE); t = np.arange(n) / RATE
    # Crack: a few tearing bursts in the first 0.4 s.
    crack = np.zeros(n)
    for k in range(rng.integers(4, 8)):
        at = rng.uniform(0, .35); length = rng.uniform(.02, .09)
        s, e = int(at * RATE), int((at + length) * RATE)
        crack[s:e] += rng.normal(0, 1, e - s) * np.exp(-np.linspace(0, 6, e - s)) * rng.uniform(.5, 1)
    crack = crack - lowpass(crack, 250)
    # Rumble: brown noise, slow swells, long tail.
    brown = np.cumsum(rng.normal(0, 1, n)); brown -= lowpass(brown, 20); brown /= np.max(np.abs(brown)) + 1e-9
    rumble = lowpass(brown, 380)
    swell = np.zeros(n)
    for k in range(6):
        c = rng.uniform(.3, seconds * .7); w = rng.uniform(.5, 1.8)
        swell += np.exp(-((t - c) / w) ** 2) * rng.uniform(.4, 1)
    envelope = np.minimum(1, t / .12) * np.exp(-t / (seconds * .42))
    rumble = rumble * (.35 + swell) * envelope
    thump = np.sin(2 * np.pi * 38 * t) * np.exp(-t * 3.5) * np.minimum(1, t / .02)
    mix = crack * 1.4 + rumble * 2.2 + thump * .5
    mix /= np.max(np.abs(mix)) + 1e-9
    fade = int(.6 * RATE); mix[-fade:] *= np.linspace(1, 0, fade)
    return mix

OUT.mkdir(parents=True, exist_ok=True)
rows = []
for i, (seed, seconds) in enumerate(((7011, 7.5), (7012, 9.0), (7013, 6.5)), 1):
    signal = strike(seed, seconds)
    target = OUT / f'close-thunder-{i}.ogg'
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'thunder.wav'
        with wave.open(str(wav), 'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
            f.writeframes((signal * .92 * 32767).astype(np.int16).tobytes())
        subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-i', str(wav),
                        '-af', 'loudnorm=I=-16:TP=-1:LRA=14', '-ar', str(RATE), '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
    rows.append({'file': target.name, 'seconds': seconds, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    print(target.name)
(OUT / 'provenance.json').write_text(json.dumps({'sound': 'close thunder, synthesised (tools/make-after-play-thunder-v4110.py), no recording', 'files': rows}, indent=2), encoding='utf-8')
