"""Original phone ringtone and elevator chime; no voice is synthesized."""
from pathlib import Path
import wave
import numpy as np

out = Path(__file__).resolve().parents[1] / 'games/kinderparadies/assets/intro'
out.mkdir(exist_ok=True)
rate = 24000
for name, duration in [('ring', 1.15), ('chime', 2.0)]:
    t = np.arange(round(rate * duration)) / rate
    if name == 'ring':
        envelope = (np.sin(2*np.pi*7*t) > 0) * np.minimum(1, t/.02) * np.minimum(1, (duration-t)/.04)
        samples = (np.sin(2*np.pi*440*t) + .6*np.sin(2*np.pi*480*t)) * envelope * .17
    else:
        samples = (np.sin(2*np.pi*1046.5*t) + .25*np.sin(2*np.pi*2093*t)) * np.minimum(1, t/.004) * np.exp(-t*3.2) * .45
    with wave.open(str(out / (name+'.wav')), 'wb') as handle:
        handle.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        handle.writeframes((samples*32767).astype('<i2').tobytes())
