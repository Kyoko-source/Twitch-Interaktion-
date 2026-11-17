"""Purr for the Jule_heartbeat plush (After Play 4.7.0).

Jule's plush hugs a sleeping tuxedo cat; picking it up lets the cat purr. The purr is synthesised here
(no recording, no third-party material): two breaths, out and in, each a train of soft glottal
pulses at 24-27 Hz (exhale) and 21-23 Hz (inhale) shaping low-passed noise plus a quiet body tone,
with breath swells and a little jitter so it does not sound mechanical.

Run: python tools/make-after-play-jule-v470.py
Output: games/kinderparadies/assets/jule-v470/purr.ogg
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
OUT = ROOT / 'games/kinderparadies/assets/jule-v470'
RATE = 48000
rng = np.random.default_rng(1704)

def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE); y = np.empty_like(x); acc = 0.
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc; y[i] = acc
    return y

def breath(seconds, rate_hz, gain, brightness):
    n = int(seconds * RATE); t = np.arange(n) / RATE
    # Pulse train with jitter: each pulse a short decaying burst.
    phase = np.cumsum((rate_hz + rng.normal(0, .6, n) * .2) / RATE)
    frac = phase % 1.0
    pulse = np.exp(-frac * 9.0) * (1 - np.exp(-frac * 120))
    noise = lowpass(rng.normal(0, 1, n), brightness)
    body = np.sin(2 * np.pi * rate_hz * 2 * t) * .25 + np.sin(2 * np.pi * 110 * t + np.sin(2 * np.pi * 3 * t)) * .06
    swell = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** .7
    return (noise * 3.2 + body) * pulse * swell * gain

parts = [breath(1.05, 25.5, 1.0, 420), np.zeros(int(.07 * RATE)), breath(.8, 22.0, .72, 330),
         np.zeros(int(.09 * RATE)), breath(1.0, 25.0, .95, 400)]
signal = np.concatenate(parts)
signal = lowpass(signal, 1800) - lowpass(signal, 45)          # band 45 Hz .. 1.8 kHz
signal /= np.max(np.abs(signal)) + 1e-9
fade = int(.03 * RATE); signal[:fade] *= np.linspace(0, 1, fade); signal[-fade * 4:] *= np.linspace(1, 0, fade * 4)

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / 'purr.ogg'
with tempfile.TemporaryDirectory() as tmp:
    wav = Path(tmp) / 'purr.wav'
    with wave.open(str(wav), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((signal * .9 * 32767).astype(np.int16).tobytes())
    subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-i', str(wav),
                    '-af', 'loudnorm=I=-19:TP=-3:LRA=7,aresample=48000,alimiter=limit=0.7:level=false',
                    '-ar', '48000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'sound': 'cat purr, synthesised (tools/make-after-play-jule-v470.py), no recording',
    'character': 'Jule_heartbeat',
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'model': 'tools/model-after-play-jule-v470.py',
}, indent=2), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
