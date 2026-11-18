"""Music-box tune for the theraidenlena plush (After Play 4.9.1).

"ahh theraidenlena, kein Horrorspiel kann ihr was anhaben": picking her up plays a short, cheerful
music-box phrase, as if the horror around her did not matter at all. Synthesised here (no recording,
no third-party material): each note is a plucked comb tooth, a sine with slightly inharmonic upper
partials, a click of attack and an exponential decay, plus a soft room tail.

Melody (C major, bright and bouncy, ending on a confident upward leap):
G5 C6 E6 G6 | E6 C6 D6 | G6 C7 (held)

Run: python tools/make-after-play-theraidenlena-v490.py
Output: games/kinderparadies/assets/theraidenlena-v490/music-box.ogg
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
OUT = ROOT / 'games/kinderparadies/assets/theraidenlena-v490'
RATE = 48000
rng = np.random.default_rng(490)

def hz(note):
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    return 440.0 * 2 ** ((names[note[0]] + 12 * (int(note[1]) + 1) - 69) / 12)

def tooth(freq, seconds, gain):
    n = int(seconds * RATE); t = np.arange(n) / RATE
    # Comb-tooth partials: fundamental plus slightly sharp upper modes, each decaying faster.
    tone = (np.sin(2 * np.pi * freq * t) * np.exp(-t * 3.2)
            + .32 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 9.0)
            + .12 * np.sin(2 * np.pi * freq * 5.40 * t) * np.exp(-t * 18.0)
            + .05 * np.sin(2 * np.pi * freq * 8.93 * t) * np.exp(-t * 30.0))
    click = rng.normal(0, 1, n) * np.exp(-t * 900) * .25
    attack = np.minimum(1, t / .0025)
    return (tone + click) * attack * gain

MELODY = [('G5', .15, .8), ('C6', .15, .85), ('E6', .15, .9), ('G6', .24, 1.0),
          ('E6', .15, .8), ('C6', .15, .8), ('D6', .27, .9),
          ('G6', .17, .95), ('C7', 1.1, 1.0)]
total = sum(step for _, step, _ in MELODY) + 1.2
signal = np.zeros(int(total * RATE))
at = 0.0
for note, step, gain in MELODY:
    start = int(at * RATE); voice = tooth(hz(note), 1.6, gain)
    end = min(len(signal), start + len(voice)); signal[start:end] += voice[:end - start]
    if note == 'C7':                                     # a soft fifth under the last note
        under = tooth(hz('G6'), 1.6, .35)[:end - start]; signal[start:end] += under
    at += step
# Small room: two early reflections and a short decaying tail.
for delay, level in ((.023, .22), (.041, .14)):
    d = int(delay * RATE); signal[d:] += signal[:-d] * level
tail = np.convolve(signal, rng.normal(0, 1, int(.35 * RATE)) * np.exp(-np.arange(int(.35 * RATE)) / RATE * 12) * .004, mode='full')[:len(signal)]
signal += tail
signal /= np.max(np.abs(signal)) + 1e-9
fade = int(.25 * RATE); signal[-fade:] *= np.linspace(1, 0, fade)

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / 'music-box.ogg'
with tempfile.TemporaryDirectory() as tmp:
    wav = Path(tmp) / 'music-box.wav'
    with wave.open(str(wav), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((signal * .9 * 32767).astype(np.int16).tobytes())
    subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-i', str(wav),
                    '-af', 'loudnorm=I=-19:TP=-3:LRA=7,aresample=48000,alimiter=limit=0.7:level=false',
                    '-ar', '48000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'sound': 'music-box tune, synthesised (tools/make-after-play-theraidenlena-v490.py), no recording',
    'character': 'theraidenlena',
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'model': 'tools/model-after-play-theraidenlena-v490.py',
}, indent=2), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
