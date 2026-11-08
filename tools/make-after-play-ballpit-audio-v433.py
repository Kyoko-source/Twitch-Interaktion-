"""Plastic ball-pit rustle for wading through the pit (4.3.3).

Hollow thin-walled plastic balls knocking together: each contact is a short
burst of two inharmonic shell modes (around 1-4 kHz) with a soft thump,
scattered densely in clusters like balls shoved aside by legs. Writes
games/kinderparadies/assets/ballpit-v433/wade-{1..4}.ogg. Original synthesis.
"""
import shutil, subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/ballpit-v433'; OUT.mkdir(parents=True, exist_ok=True)
FF = shutil.which('ffmpeg'); RATE = 44100
rng = np.random.default_rng(433)


def knock(gain):
    n = int(.09 * RATE); t = np.arange(n) / RATE
    f1 = rng.uniform(950, 2300); f2 = f1 * rng.uniform(1.6, 2.3)
    x = np.sin(2 * np.pi * f1 * t) * np.exp(-t * rng.uniform(70, 120))
    x += .55 * np.sin(2 * np.pi * f2 * t) * np.exp(-t * rng.uniform(110, 180))
    x += .5 * rng.normal(0, 1, n) * np.exp(-t * 600)  # the contact click
    x += .35 * np.sin(2 * np.pi * rng.uniform(160, 260) * t) * np.exp(-t * 45)  # hollow body
    return x * gain


for v in range(1, 5):
    length = 1.1; x = np.zeros(int(length * RATE) + RATE // 10)
    # Two leg pushes per clip: dense clusters that thin out as balls settle.
    for push in (rng.uniform(.0, .08), rng.uniform(.5, .6)):
        for k in range(rng.integers(26, 40)):
            at = push + rng.exponential(.11)
            if at > length: continue
            g = rng.uniform(.25, 1.) * np.exp(-(at - push) * 3.)
            s = int(at * RATE); b = knock(g); x[s:s + len(b)] += b
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    x = np.fft.irfft(np.fft.rfft(x) * (f * f / (f * f + 120 ** 2)) / np.sqrt(1 + (f / 9000) ** 4), len(x))
    x = x[:int(length * RATE)]; x *= .8 / np.max(np.abs(x))
    fade = int(.03 * RATE); x[-fade:] *= np.linspace(1, 0, fade)
    subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(OUT / f'wade-{v}.ogg')],
                   input=x.astype('<f4').tobytes(), check=True)
(OUT / 'LICENSE.txt').write_text('wade-*.ogg: original synthesised plastic ball sounds for After Play (tools/make-after-play-ballpit-audio-v433.py).\n', encoding='utf-8')
print('ok')
