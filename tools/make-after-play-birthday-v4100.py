"""Music-box "Happy Birthday" for the secret ending of After Play 4.10.0.

The children found again, the plushes at the birthday table, Happyland lights up
room by room: under it a slow, warm music box plays "Happy Birthday to You"
(melody in the public domain), twice, the second time an octave higher with a
soft lower voice. Synthesised here, no recording: each note is a plucked comb
tooth (sine with slightly inharmonic partials, attack click, exponential decay)
in a small room.

Run: python tools/make-after-play-birthday-v4100.py
Output: games/kinderparadies/assets/secret-v4100/birthday-music-box.ogg
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
OUT = ROOT / 'games/kinderparadies/assets/secret-v4100'
RATE = 44100
BEAT = .62
rng = np.random.default_rng(4100)

def hz(note):
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    return 440.0 * 2 ** ((names[note[0]] + 12 * (int(note[1]) + 1) - 69) / 12)

def tooth(freq, seconds, gain):
    n = int(seconds * RATE); t = np.arange(n) / RATE
    tone = (np.sin(2 * np.pi * freq * t) * np.exp(-t * 2.4)
            + .30 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 7.5)
            + .11 * np.sin(2 * np.pi * freq * 5.40 * t) * np.exp(-t * 15.0)
            + .04 * np.sin(2 * np.pi * freq * 8.93 * t) * np.exp(-t * 26.0))
    click = rng.normal(0, 1, n) * np.exp(-t * 800) * .2
    return (tone + click) * np.minimum(1, t / .003) * gain

# (note, beats) in 3/4, starting on the pick-up.
TUNE = [('G4', .75), ('G4', .25), ('A4', 1), ('G4', 1), ('C5', 1), ('B4', 2),
        ('G4', .75), ('G4', .25), ('A4', 1), ('G4', 1), ('D5', 1), ('C5', 2),
        ('G4', .75), ('G4', .25), ('G5', 1), ('E5', 1), ('C5', 1), ('B4', 1), ('A4', 1),
        ('F5', .75), ('F5', .25), ('E5', 1), ('C5', 1), ('D5', 1), ('C5', 3)]
BASS = {0: 'C3', 3: 'G3', 6: 'G3', 9: 'C3', 12: 'C3', 15: 'F3', 18: 'C3', 21: 'G3', 24: 'C3'}

def up(note, octaves):
    return note[0] + str(int(note[1]) + octaves)

length = sum(b for _, b in TUNE) * BEAT
total = length * 2 + 3.0
signal = np.zeros(int(total * RATE))

def add(at, voice):
    start = int(at * RATE); end = min(len(signal), start + len(voice)); signal[start:end] += voice[:end - start]

for verse in range(2):
    at = verse * length; beat = 0.0
    for note, beats in TUNE:
        add(at + beat * BEAT, tooth(hz(up(note, verse)), 2.4, .9 if verse == 0 else .75))
        beat += beats
    for b, note in BASS.items():                       # soft lower voice on the bar lines
        add(at + b * BEAT + .75 * BEAT, tooth(hz(up(note, verse)), 2.4, .28))
for delay, level in ((.027, .2), (.049, .12), (.083, .07)):
    d = int(delay * RATE); signal[d:] += signal[:-d] * level
signal /= np.max(np.abs(signal)) + 1e-9
fade = int(1.5 * RATE); signal[-fade:] *= np.linspace(1, 0, fade)

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / 'birthday-music-box.ogg'
with tempfile.TemporaryDirectory() as tmp:
    wav = Path(tmp) / 'birthday.wav'
    with wave.open(str(wav), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((signal * .9 * 32767).astype(np.int16).tobytes())
    subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-i', str(wav),
                    '-af', 'loudnorm=I=-18:TP=-2:LRA=9,alimiter=limit=0.75:level=false',
                    '-ar', '44100', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'sound': 'music-box "Happy Birthday to You", synthesised (tools/make-after-play-birthday-v4100.py), no recording',
    'melody': 'Happy Birthday to You, public domain',
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
}, indent=2), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
