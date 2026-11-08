"""An original marimba ringtone for the night guard's phone (4.3.1).

Synthesised: struck-bar partials (1, 3.93, 9.5) with fast decays, an original
two-bar phrase played twice, then shaped like a small phone loudspeaker
(band-limited 320 Hz-6 kHz, gentle saturation). Writes
games/kinderparadies/assets/intro-v431/ringtone.ogg (about 3 s, then silence
before the intro script restarts it).
"""
import shutil, subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/intro-v431'; OUT.mkdir(parents=True, exist_ok=True)
FF = shutil.which('ffmpeg'); RATE = 44100


def note(name):
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    return 440 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def bar(freq, length):
    t = np.arange(int(length * RATE)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 5.5)
    tone += .32 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t * 16)
    tone += .12 * np.sin(2 * np.pi * freq * 9.5 * t) * np.exp(-t * 40)
    attack = np.minimum(1, t / .002)
    return tone * attack


phrase = [('E5', 0), ('B5', .14), ('G#5', .28), ('E5', .42), ('F#5', .70), ('B5', .84), ('D#6', .98), ('B5', 1.12)]
x = np.zeros(int(3.0 * RATE))
for rep in range(2):
    for name, at in phrase:
        start = int((at + rep * 1.5) * RATE); b = bar(note(name), .9)
        n = min(len(b), len(x) - start); x[start:start + n] += b[:n] * (1. if rep == 0 else .95)
f = np.fft.rfftfreq(len(x), 1 / RATE)
resp = (f * f / (f * f + 320 ** 2)) / np.sqrt(1 + (f / 6000) ** 6)
x = np.fft.irfft(np.fft.rfft(x) * resp, len(x))
x = np.tanh(x / np.max(np.abs(x)) * 1.6) / np.tanh(1.6)
x *= .89 / np.max(np.abs(x))
x[-int(.02 * RATE):] *= np.linspace(1, 0, int(.02 * RATE))
subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '6', str(OUT / 'ringtone.ogg')],
               input=x.astype('<f4').tobytes(), check=True)
(OUT / 'LICENSE.txt').write_text('ringtone.ogg: original synthesised melody for After Play (tools/make-after-play-ringtone-v431.py).\n', encoding='utf-8')
print(OUT / 'ringtone.ogg')
