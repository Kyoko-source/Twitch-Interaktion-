"""A distinct, shrill fatal horse scream from existing credited CC0 monster edits."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'

def read(name):
    with wave.open(str(ASSETS / 'revamp-v300' / name), 'rb') as stream:
        assert stream.getnchannels() == 1 and stream.getsampwidth() == 2
        rate = stream.getframerate()
        data = struct.unpack('<' + 'h' * stream.getnframes(), stream.readframes(stream.getnframes()))
        return rate, [sample / 32768 for sample in data]

def sample(track, time):
    rate, values = track
    at = time * rate
    index = int(at)
    if index < 0 or index + 1 >= len(values):
        return 0.
    return values[index] * (1 - (at - index)) + values[index + 1] * (at - index)

high, body = read('ossuary-3.wav'), read('ossuary-1.wav')
rate = 32000
duration = 1.7
samples = []
previous = 0.
for index in range(int(rate * duration)):
    time = index / rate
    pitched = sample(high, time * 1.48)
    # Retain the creature's lower vocal body under a rasping higher register.
    high_pass = pitched - previous * .65
    previous = pitched
    echo = sample(high, (time - .068) * 1.48) * .17 if time > .068 else 0.
    signal = high_pass * .73 + sample(body, time * .92) * .30 + echo
    envelope = min(1., time / .006) * min(1., (duration - time) / .15)
    samples.append(math.tanh(signal * 1.8) * envelope)
peak = max(abs(v) for v in samples)
gain = .88 / max(peak, .001)
output = ASSETS / 'encounter-v401/horse-final-scream.wav'
output.parent.mkdir(exist_ok=True)
with wave.open(str(output), 'wb') as stream:
    stream.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    stream.writeframes(struct.pack('<' + 'h' * len(samples), *(round(v * gain * 32767) for v in samples)))
print(f'{output.name}: {duration:.2f}s, peak -1.1 dBFS, existing Ogrebane CC0 recordings')
