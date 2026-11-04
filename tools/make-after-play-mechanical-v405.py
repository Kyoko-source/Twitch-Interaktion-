"""Original, short physical mechanism sounds. No external recordings or music."""
from pathlib import Path
import json
import subprocess
import tempfile
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/mechanical-v405'
OUT.mkdir(exist_ok=True)
RATE = 24000
rng = np.random.default_rng(405)

def modes(duration, frequencies, decays, amplitudes):
    t = np.arange(round(duration * RATE)) / RATE
    signal = np.zeros_like(t)
    for frequency, decay, amplitude in zip(frequencies, decays, amplitudes):
        signal += amplitude * np.sin(2 * np.pi * frequency * t) * np.exp(-t / decay)
    signal *= np.minimum(t / .0018, 1)
    return signal

def tap(duration=.12, weight=1):
    signal = modes(duration, [175, 438, 1130, 2710], [.018, .013, .010, .005], [.6, .4, .18, .08])
    t = np.arange(len(signal)) / RATE
    return weight * (signal + rng.normal(0, .12, len(t)) * np.exp(-t / .004))

def write(name, signal):
    signal[-min(100, len(signal)):] *= np.linspace(1, 0, min(100, len(signal)))
    signal *= .76 / max(.01, np.max(np.abs(signal)))
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / 'mechanism.wav'
        with wave.open(str(path), 'wb') as output:
            output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE)
            output.writeframes((signal * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(path),
                        '-c:a', 'libvorbis', '-q:a', '2', str(OUT / f'{name}.ogg')], check=True)

write('bell', modes(1.4, [1180, 2393, 3170, 4730], [.36, .20, .13, .08], [.68, .23, .09, .04]))
gum = np.zeros(RATE)
for index, moment in enumerate([.0, .07, .15, .24, .34, .45, .57, .70, .82]):
    tick = tap(.10, .60 if index % 2 else .85)
    start = round(moment * RATE); gum[start:start + len(tick)] += tick
write('gum', gum)
ticket = tap(.35)
ticket[round(.10 * RATE):] += np.pad(tap(.11, .4), (0, len(ticket) - round(.10 * RATE) - round(.11 * RATE)))
write('ticket', ticket)
write('pot', modes(.24, [485, 1175, 2560], [.026, .054, .027], [.52, .23, .10]) + tap(.24, .22))
(OUT / 'provenance.json').write_text(json.dumps({
    'author': 'After Play project', 'license': 'Original project audio',
    'description': 'Authored decaying resonant modes and transient ratchet/lever sounds; no borrowed audio.',
    'generator': 'tools/make-after-play-mechanical-v405.py',
    'files': ['bell.ogg', 'gum.ogg', 'ticket.ogg', 'pot.ogg'],
}, indent=2) + '\n', encoding='utf-8')
print('Authored mechanism sounds:', sum(p.stat().st_size for p in OUT.glob('*.ogg')), 'bytes')
