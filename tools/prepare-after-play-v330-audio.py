"""Original ignition, engine revs and drive-away for After Play's secret ending."""
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/arrival-v330'
OUT.mkdir(parents=True, exist_ok=True)
FFMPEG = ROOT / 'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'
RATE = 24000
t = np.arange(int(RATE * 9.2)) / RATE
rng = np.random.default_rng(330)
def smooth(a, b):
    v = np.clip((t - a) / (b - a), 0, 1)
    return v * v * (3 - 2 * v)
def band(lo, hi):
    f = np.fft.rfftfreq(t.size, 1 / RATE)
    z = np.fft.rfft(rng.standard_normal(t.size))
    z *= np.exp(-(f / hi) ** 4) * (1 - np.exp(-(f / lo) ** 4))
    x = np.fft.irfft(z, n=t.size)
    return x / max(x.std(), .001)
rpm = 27 + 55*smooth(2.8, 4.0) - 25*smooth(4.0, 4.3) + 61*smooth(4.3, 5.6) - 24*smooth(5.6, 5.8) + 32*smooth(5.8, 6.8)
phase = 2*np.pi*np.cumsum(rpm * (1-.15*smooth(5.4,8.8))) / RATE
engine = sum(np.sin(phase*h + .11*np.sin(phase*.5)) / h**1.6 for h in range(1, 13))
engine += band(60, 850)*.09*(.55+.45*np.sin(phase)**6)
engine *= smooth(1.4, 1.65) * (1-smooth(6.3, 9.0)) * (.40+.30*smooth(2.8, 4.0))
starter = (np.sin(2*np.pi*153*t) + .4*band(180, 1500)) * smooth(.65,.72) * (1-smooth(1.45,1.58))*.13
clunk = band(60, 2800) * np.exp(-np.maximum(t-.20,0)*40) * (t>=.20)*.19
tyres = band(180, 2600) * smooth(4.0,5.8) * (1-smooth(6.9,9.1))*.12
signal = engine + starter + clunk + tyres
signal += np.roll(signal, 437)*.04
signal *= (1-smooth(9.0,9.2))
signal *= 10**(-3/20) / np.max(np.abs(signal))
pan = .1 + .75*smooth(4.1,8.0)
stereo = np.stack([signal*np.sqrt(1-pan), signal*np.sqrt(pan)], axis=1).astype('<f4')
file = OUT / 'car-departure.ogg'
subprocess.run([str(FFMPEG),'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(file)],input=stereo.tobytes(),check=True)
(OUT/'audio-provenance.json').write_text(json.dumps({'origin':'Original synthesized starter, combustion pulses, tyres and Doppler envelope; no external samples.','duration':9.2,'peak_dbfs':-3,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('After Play 3.3: original car ignition and drive-away sound, authored for the game. No external samples.\n',encoding='utf-8')
print(file, file.stat().st_size)
