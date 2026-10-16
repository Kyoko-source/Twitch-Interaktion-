"""Original, deterministic spatial water/pipe ambience; no music or third-party audio."""
import math
import random
import struct
import wave
from pathlib import Path

rate, duration = 24000, 14
rng = random.Random(711)
samples = [0.0] * (rate * duration)
for when in [0.8, 2.1, 2.4, 5.0, 7.6, 8.1, 11.3, 12.7]:
    start = int(when * rate)
    pitch = rng.uniform(660, 1200)
    for i in range(int(rate * 0.42)):
        t = i / rate
        envelope = math.exp(-t * 15) * min(1, t * 800)
        phase = 2 * math.pi * (pitch * t + 150 * (1 - math.exp(-t * 35)))
        drop = math.sin(phase) * 0.18 + math.sin(phase * 1.73) * 0.08
        drop += rng.uniform(-1, 1) * math.exp(-t * 70) * 0.14
        samples[start + i] += drop * envelope
target = Path(__file__).resolve().parents[1] / "games/kinderparadies/assets/drips.wav"
with wave.open(str(target), "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, value)) * 32767)) for value in samples))
print(target)
