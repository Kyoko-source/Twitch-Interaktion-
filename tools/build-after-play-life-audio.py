"""Original small spatial machinery/water sounds. No API or external downloads."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'games/kinderparadies/assets/life-v2110'
RATE = 24000
rng = np.random.default_rng(2110)

def save(name, samples):
    samples = np.tanh(samples) * .65
    with wave.open(str(OUT / name), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes((samples * 32767).astype('<i2').tobytes())

def noise(count, cutoff):
    data = rng.standard_normal(count)
    spectrum = np.fft.rfft(data)
    spectrum *= np.exp(-(np.fft.rfftfreq(count, 1 / RATE) / cutoff) ** 2)
    result = np.fft.irfft(spectrum, n=count)
    return result / max(result.std(), .0001)

OUT.mkdir(parents=True, exist_ok=True)
t = np.arange(RATE * 4) / RATE
hum = (.13*np.sin(2*np.pi*50*t) + .045*np.sin(2*np.pi*100*t)
       + .018*np.sin(2*np.pi*150*t)) * (1+.08*np.sin(2*np.pi*.5*t))
save('photo-hum.wav', hum)
t = np.arange(RATE * 9) / RATE
envelope = np.minimum(t/.45, 1) * np.minimum((9-t)/1.2, 1)
motor = (.16*np.sin(2*np.pi*(53*t+.11*np.sin(t*2))) + .055*np.sin(2*np.pi*106*t)
         + .02*noise(t.size, 440)) * envelope
motor += .12*noise(t.size, 1800)*np.exp(-t*36)
save('compressor.wav', motor)
t = np.arange(int(RATE*.85)) / RATE
drop = .34*np.sin(2*np.pi*(960*t-260*t*t))*np.exp(-t*20)
drop += .10*noise(t.size, 2700)*np.exp(-t*58)
for delay, volume in [(.047,.22),(.093,.12),(.161,.065)]:
    at = int(delay*RATE); drop[at:] += drop[:-at]*volume
save('bucket-drop.wav', drop)
t = np.arange(RATE * 8) / RATE
air = .023*noise(t.size, 360) + .012*np.sin(2*np.pi*75*t)
# Gentle seam fade keeps the low room tone from clicking on a loop.
air *= np.minimum(t/.15,1)*np.minimum((8-t)/.15,1)
save('washroom-air.wav', air)
print('Created original booth hum, compressor cycle, bucket drip and washroom air.')
