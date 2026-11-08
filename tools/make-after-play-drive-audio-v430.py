"""Audio for the secret ending drive home (4.3.0).

Writes games/kinderparadies/assets/drive-v430/:
  drive-loop.ogg      seamless engine drone + rough forest road under the tyres
  pothole-{1..3}.ogg  suspension slams for the camera jolts
  shout.ogg           the red line, "screamed" by the two dead children
  child-shriek.ogg    the back-seat jumpscare
  mirror-drone.ogg    the rising dread while the driver looks up

Sources: the project's own CC0 material (Ogrebane monster voices, cook scream,
Kenney/Joseph SARDIN surfaces) and rubberduck's "80 CC0 creature SFX"
(tools/art-source/creature-sfx-cc0, CC0 1.0). Engine and road are synthesised.
"""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
CREATURE = ROOT / 'tools/art-source/creature-sfx-cc0'
OUT = A / 'drive-v430'
OUT.mkdir(parents=True, exist_ok=True)
FF = shutil.which('ffmpeg')
assert FF
RATE = 32000
rng = np.random.default_rng(430)
report = {}


def read(path):
    r = subprocess.run([FF, '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'], capture_output=True, check=True)
    x = np.frombuffer(r.stdout, '<f4').astype(float)
    return x / max(.001, np.max(np.abs(x)))


def band(x, low, high):
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    resp = 1. / np.sqrt(1 + (f / high) ** 8)
    if low > 0:
        resp = resp * (f * f / (f * f + low * low))
    return np.fft.irfft(np.fft.rfft(x) * resp, len(x))


def resample(src, speed, offset=0.):
    n = max(1, int((len(src) - 1 - offset * RATE) / speed))
    idx = np.clip(offset * RATE + np.arange(n) * speed, 0, len(src) - 1.001)
    return np.interp(idx, np.arange(len(src)), src)


def add(dst, src, time, gain, speed=1., offset=0.):
    piece = resample(src, speed, offset); start = round(time * RATE)
    n = min(len(piece), len(dst) - start)
    if n < 1: return
    piece = piece[:n].copy(); fade = min(n // 4, round(.012 * RATE))
    if fade:
        piece[:fade] *= np.linspace(0, 1, fade); piece[-fade:] *= np.linspace(1, 0, fade)
    dst[start:start + n] += piece * gain


def saturate(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def tail(x, taps):
    out = x.copy()
    for delay, gain, damp in taps:
        s = np.zeros_like(x); n = round(delay * RATE)
        if n < len(x): s[n:] = x[:len(x) - n]
        if damp: s = band(s, 0, damp)
        out += s * gain
    return out


def write(name, x, peak_db, drive=1.0, edge=.015):
    if drive > 1: x = saturate(x, drive)
    x = band(x, 25, 12500)
    fade = min(len(x) // 4, round(edge * RATE))
    if fade:
        x[:fade] *= np.linspace(0, 1, fade); x[-fade:] *= np.linspace(1, 0, fade)
    x *= 10 ** (peak_db / 20) / max(.001, np.max(np.abs(x)))
    path = OUT / (name + '.ogg')
    subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(path)],
                   input=x.astype('<f4').tobytes(), check=True)
    report[name] = {'seconds': round(len(x) / RATE, 3), 'peak_dbfs': peak_db, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def brown(n):
    w = rng.normal(0, 1, n); b = np.cumsum(w); b -= np.convolve(b, np.ones(2001) / 2001, 'same'); return b / np.max(np.abs(b))


# ---------------------------------------------------------------- drive loop
# Built over an integer number of engine cycles and crossfaded at the seam,
# so Godot can loop it without a click.
L = 8.0; n = round(L * RATE); t = np.arange(n) / RATE
rpm = 26.0  # firing frequency, an old diesel crawling in second gear
wob = .6 * np.sin(2 * np.pi * t / L * 3) + .3 * np.sin(2 * np.pi * t / L * 7)
phase = 2 * np.pi * np.cumsum(rpm + wob) / RATE
engine = sum(np.sin(phase * k + k) / k ** .8 for k in range(1, 9))
engine *= .7 + .3 * np.sin(phase * .5) ** 2
engine = band(engine, 20, 900)
rumble = band(brown(n), 15, 220) * 1.2
gravel = band(rng.normal(0, 1, n), 900, 5200)
grit = np.abs(band(rng.normal(0, 1, n), 2, 18))
gravel *= .15 + 1.4 * grit / grit.max()
cabin = band(rng.normal(0, 1, n), 150, 900) * .25  # wind against the closed car body
loop = engine * .55 + rumble * .9 + gravel * .22 + cabin
seam = round(.5 * RATE)
loop[:seam] = loop[:seam] * np.linspace(0, 1, seam) + loop[-seam:] * np.linspace(1, 0, seam)
loop = loop[:-seam]
loop *= 10 ** (-7 / 20) / np.max(np.abs(loop))
path = OUT / 'drive-loop.ogg'
subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', str(path)],
               input=loop.astype('<f4').tobytes(), check=True)
report['drive-loop'] = {'seconds': round(len(loop) / RATE, 3), 'peak_dbfs': -7, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

# ---------------------------------------------------------------- potholes
cloth = read(A / 'polish/impact-cloth.wav')
plastic = read(A / 'polish/impact-plastic.wav')
metal = read(A / 'ambience-v193/duct-stress.wav')
for v in range(1, 4):
    x = np.zeros(round(RATE * .9)); tt = np.arange(len(x)) / RATE
    thump = np.sin(2 * np.pi * (48 - 18 * tt) * tt) * np.exp(-tt * (9 + v)) * 1.3
    x += thump
    add(x, plastic, .01, .35, .7 + v * .08)
    add(x, metal, .03, .12, 1.4 + v * .1)
    add(x, cloth, .0, .3, .8)
    x += band(rng.normal(0, 1, len(x)), 1200, 6000) * np.exp(-tt * 25) * .25
    write(f'pothole-{v}', x, -4.5 - v)

# ---------------------------------------------------------------- the shouted line
voices = {i: read(ROOT / f'tools/art-source/v300/monster-{i}.wav') for i in (2, 7, 8)}
creature = {k: read(CREATURE / f'{k}.ogg') for k in ('scream_01', 'scream_02', 'cute_03', 'cute_06', 'hurt_02', 'breath')}
cook = read(A / 'finale/cook-scream.wav')
x = np.zeros(round(RATE * 3.2))
# Two small voices: the cook's shriek and a creature scream sped up to a
# child's register, a frightened intake before, a long hall tail after.
add(x, creature['breath'], 0, .35, 1.5)
choir = np.zeros_like(x)
add(choir, cook, .28, 1., 1.55)
add(choir, cook, .31, .7, 1.72, .05)
add(choir, creature['scream_02'], .30, .55, 1.45)
add(choir, voices[7], .29, .5, 1.6)
add(choir, voices[2], .33, .25, 1.75)
choir = band(choir, 420, 9000)
env = np.minimum(1, np.arange(len(x)) / RATE / .05)
x += choir * env
x = tail(x, [(.09, .45, 4200), (.21, .35, 3000), (.38, .25, 2200), (.61, .15, 1500)])
write('shout', x, -2.0, drive=1.9, edge=.03)

# ---------------------------------------------------------------- the back-seat shriek
x = np.zeros(round(RATE * 1.15))
add(x, plastic, 0, .6, .8)
add(x, cloth, 0, .5, .9)
s = np.zeros_like(x)
add(s, cook, .0, 1., 1.62)
add(s, creature['scream_01'], .005, .8, 1.55)
add(s, creature['scream_02'], .02, .6, 1.7)
add(s, voices[8], .0, .35, 1.9)
add(s, creature['cute_06'], .0, .3, 1.2)
s = band(s, 500, 11000)
x += s
x = tail(x, [(.022, .35, 6000), (.05, .2, 4000)])
write('child-shriek', x, -.3, drive=2.2, edge=.004)

# ---------------------------------------------------------------- mirror dread
L = 4.0; tt = np.arange(round(L * RATE)) / RATE
d = sum(np.sin(2 * np.pi * f * tt * (1 + .015 * tt)) for f in (55, 58.3, 110.6, 164))
d += band(rng.normal(0, 1, len(tt)), 2000, 7000) * .3
d *= (tt / L) ** 2.2
write('mirror-drone', d, -9, edge=.002)

(OUT / 'provenance.json').write_text(json.dumps({'sources': ['project CC0 recordings', 'rubberduck 80 CC0 creature SFX'], 'files': report}, indent=2), encoding='utf-8')
(OUT / 'LICENSE.txt').write_text('Secret ending drive audio. Built from CC0 sources (Ogrebane monster voices, Kenney/Joseph SARDIN impacts,\n'
                                 'rubberduck "80 CC0 creature SFX" https://opengameart.org/content/80-cc0-creature-sfx) and original synthesis.\n', encoding='utf-8')
print(json.dumps(report, indent=1))
