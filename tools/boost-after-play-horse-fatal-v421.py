"""Add a low sub layer under the existing fatal horse scream for extra weight,
to match the louder, bigger first/second-catch sounds from v421. Run after
sound-after-play-horse-v401.py (which must exist first).
"""
import subprocess
import shutil
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
CREATURE = ROOT / 'tools/art-source/creature-sfx-cc0'
TARGET = A / 'encounter-v401/horse-final-scream.wav'
assert TARGET.exists(), 'Run sound-after-play-horse-v401.py first'
FF = shutil.which('ffmpeg')
assert FF
RATE = 32000


def read(path):
    result = subprocess.run([FF, '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'],
                             capture_output=True, check=True)
    return np.frombuffer(result.stdout, '<f4').astype(float)


def band(x, low, high):
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    lowpass = 1. / np.sqrt(1 + (f / high) ** 8)
    response = (f * f / (f * f + low * low)) * lowpass if low > 0 else lowpass
    return np.fft.irfft(np.fft.rfft(x) * response, len(x))


scream = read(TARGET)
roar = read(CREATURE / 'roar_02.ogg')
slow = np.interp(np.arange(len(scream)) * .55, np.arange(len(roar)), roar, right=0)
sub = band(slow, 0, 170) * .55
envelope = np.minimum(1., np.arange(len(scream)) / (.02 * RATE))
envelope *= np.minimum(1., (len(scream) - np.arange(len(scream))) / (.2 * RATE))
mixed = scream + sub * envelope
peak = np.max(np.abs(mixed))
mixed *= min(1., 0.90 / max(.001, peak))
subprocess.run([FF, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-',
                 str(TARGET)], input=mixed.astype('<f4').tobytes(), check=True)
print('boosted', TARGET, 'new peak', float(np.max(np.abs(mixed))))
