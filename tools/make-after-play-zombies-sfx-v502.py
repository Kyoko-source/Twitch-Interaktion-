"""Gun, hit and kill sounds for Partynacht, After Play 5.0.2.

Layered synthesis, three variants each:
  shot-<frame>-<n>: muzzle crack, blast noise, low thump, sub for heavy guns,
    action noise (slide, pump, bolt), room tail. Frames: pistol, revolver,
    smg, rifle, shotgun, lmg, sniper, rift (an energy discharge).
  hit-body-<n>, hit-head-<n>: wet body thud / crisp head crack with a tink.
  kill-<n>, kill-head-<n>: splat and crunch; the head kill adds a bright
    confirmation ding. hitmarker, reload-out, reload-in, chamber, empty,
    swap, melee-swing, melee-hit.
Run: python tools/make-after-play-zombies-sfx-v502.py
Output: games/kinderparadies/assets/zombies-v500/sfx/*.ogg
"""
import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/zombies-v500/sfx'
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def biquad(x, kind, f, q=.707):
    w = 2 * math.pi * f / SR; a = math.sin(w) / (2 * q); c = math.cos(w)
    if kind == 'lp': b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif kind == 'hp': b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    else: b = [a, 0, -a]
    den = [1 + a, -2 * c, 1 - a]
    b = [v / den[0] for v in b]; a1, a2 = den[1] / den[0], den[2] / den[0]
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.
    for i in range(len(x)):
        v = b[0] * x[i] + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x[i], y1, v; y[i] = v
    return y


def env(t, attack, decay):
    return np.minimum(t / max(attack, 1e-4), 1.) * np.exp(-t / decay)


def place(dst, src, at, gain=1.):
    i = int(at * SR); n = min(len(src), len(dst) - i)
    if n > 0: dst[i:i + n] += src[:n] * gain


def reverb(x, size=1., mix=.3):
    out = x.copy(); wet = np.zeros(len(x) + int(SR * .9 * size))
    for delay, fb in ((.0297, .76), (.0371, .73), (.0411, .71), (.0437, .69)):
        d = int(delay * size * SR); buf = np.zeros(len(wet)); buf[:len(x)] = x
        for i in range(d, len(buf)): buf[i] += buf[i - d] * fb
        wet += buf
    wet = biquad(wet, 'lp', 3200) * .12
    res = np.zeros(len(wet)); res[:len(out)] = out * (1 - mix * .3); res += wet * mix
    return res


def finish(x, peak=.92, drive=1.6):
    x = np.tanh(x * drive) / math.tanh(drive)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x) // 6, int(.05 * SR)); x[-fade:] *= np.linspace(1, 0, fade)
    return x


def write(name, x):
    with tempfile.TemporaryDirectory() as tmp:
        w = Path(tmp) / 'a.wav'
        with wave.open(str(w), 'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(w), '-c:a', 'libvorbis', '-q:a', '7', str(OUT / f'{name}.ogg')], check=True)


def click(rng, f=3000., length=.006, ring=(2300, 3700, 5100), ring_decay=.02):
    t = t_axis(length + ring_decay * 4)
    n = rng.standard_normal(len(t)) * env(t, .0003, length * .4)
    x = biquad(n, 'bp', f, 1.2) * 2.
    for k, fr in enumerate(ring): x += np.sin(2 * math.pi * fr * t + rng.uniform(0, 6)) * env(t, .0005, ring_decay) * (.35 / (k + 1))
    return x


GUNS = {
    #        len  blast_lp decay thump f0  f1  thump_amp sub  action          room
    'pistol': (.55, 5200, .045, 160, 70, .9, 0., [('slide', .055)], .8),
    'revolver': (.9, 4200, .085, 120, 50, 1.3, .5, [('cylinder', .16)], 1.1),
    'smg': (.4, 6000, .032, 180, 85, .7, 0., [('bolt', .04)], .7),
    'rifle': (.75, 4800, .06, 140, 60, 1.1, .35, [('bolt', .05)], 1.),
    'shotgun': (1.1, 3600, .11, 110, 45, 1.6, .8, [('pump', .32), ('pump', .43)], 1.25),
    'lmg': (.65, 4400, .07, 120, 55, 1.3, .6, [('bolt', .045)], 1.),
    'sniper': (1.4, 3800, .14, 95, 38, 1.8, 1., [('bolt', .45), ('bolt', .6)], 1.5),
}


def gunshot(frame, seed):
    rng = np.random.default_rng(seed)
    length, lp, decay, f0, f1, thump_amp, sub, actions, room = GUNS[frame]
    t = t_axis(length); x = np.zeros(len(t))
    crack = rng.standard_normal(len(t)) * env(t, .0001, .0025)
    x += biquad(crack, 'hp', 1800) * 1.6
    blast = rng.standard_normal(len(t)) * env(t, .0008, decay * rng.uniform(.9, 1.1))
    x += biquad(biquad(blast, 'lp', lp * rng.uniform(.9, 1.1)), 'hp', 120) * 1.2
    sweep = np.cumsum(2 * math.pi * (f1 + (f0 - f1) * np.exp(-t / .03)) / SR)
    x += np.sin(sweep) * env(t, .001, decay * 1.4) * thump_amp
    if sub: x += np.sin(2 * math.pi * 48 * t) * env(t, .004, .12) * sub
    for kind, at in actions:
        piece = {'slide': lambda: click(rng, 2600, .005, (2100, 3300, 4800), .018),
                 'bolt': lambda: click(rng, 3400, .004, (2800, 4100), .012),
                 'cylinder': lambda: click(rng, 2200, .004, (1900, 2900), .03),
                 'pump': lambda: click(rng, 1400, .012, (900, 1700, 2600), .03)}[kind]()
        place(x, piece, at * rng.uniform(.95, 1.05), .5 if kind != 'pump' else .8)
    x = reverb(x, room, .35)
    return finish(x, .95, 2.2)


def rift(seed):
    rng = np.random.default_rng(seed); t = t_axis(1.3); x = np.zeros(len(t))
    freq = 1800 * np.exp(-t / .08) + 140
    x += np.sin(np.cumsum(2 * math.pi * freq / SR) + 3 * np.sin(2 * math.pi * 37 * t)) * env(t, .002, .35)
    x += np.sin(2 * math.pi * 52 * t) * env(t, .01, .3) * 1.2
    crackle = (rng.random(len(t)) > .985) * rng.standard_normal(len(t)) * env(t, .01, .4)
    x += biquad(crackle, 'hp', 2500) * 2.
    x += biquad(rng.standard_normal(len(t)) * env(t, .0005, .05), 'lp', 5000) * .8
    return finish(reverb(x, 1.4, .4), .95, 1.8)


def thud(rng, f0=110, f1=55, decay=.07):
    t = t_axis(.35)
    return np.sin(np.cumsum(2 * math.pi * (f1 + (f0 - f1) * np.exp(-t / .02)) / SR)) * env(t, .001, decay)


def wet(rng, f=900, decay=.05, length=.35):
    t = t_axis(length); n = rng.standard_normal(len(t)) * env(t, .001, decay)
    return biquad(n, 'bp', f, 1.4) * 2.5


def hit_body(seed):
    rng = np.random.default_rng(seed); x = np.zeros(int(.35 * SR))
    place(x, thud(rng, 120, 60, .06), 0, 1.)
    place(x, wet(rng, rng.uniform(700, 1100), .035), 0, .9)
    place(x, biquad(rng.standard_normal(int(.02 * SR)) * env(t_axis(.02), .0002, .004), 'hp', 3000), 0, .5)
    return finish(x, .8, 1.8)


def hit_head(seed):
    rng = np.random.default_rng(seed); x = np.zeros(int(.4 * SR)); t = t_axis(.4)
    place(x, biquad(rng.standard_normal(len(t)) * env(t, .0001, .006), 'hp', 2400), 0, 1.6)
    place(x, thud(rng, 160, 80, .045), 0, .8)
    place(x, (np.sin(2 * math.pi * 2900 * t) + .5 * np.sin(2 * math.pi * 4400 * t)) * env(t, .0005, .05), .004, .35)
    place(x, wet(rng, 1500, .03), .002, .6)
    return finish(x, .85, 1.6)


def splat(rng, length=.6):
    t = t_axis(length); n = rng.standard_normal(len(t)) * env(t, .002, .14)
    sweep = np.zeros(len(t))
    for k, f in enumerate(np.geomspace(1600, 260, 8)):
        seg = slice(int(k * len(t) / 10), int((k + 3) * len(t) / 10))
        sweep[seg] += biquad(n[seg], 'bp', f, 1.6)[:len(sweep[seg])]
    sweep *= 1 + .5 * np.sin(2 * math.pi * 28 * t)
    return sweep * 2.


def crunch(rng, count=7, span=.08):
    x = np.zeros(int((span + .03) * SR))
    for k in range(count): place(x, click(rng, rng.uniform(1500, 4000), .003, (rng.uniform(1200, 2500),), .006), rng.uniform(0, span), rng.uniform(.3, .8))
    return x


def kill(seed, head):
    rng = np.random.default_rng(seed); x = np.zeros(int(1.0 * SR)); t = t_axis(1.)
    place(x, thud(rng, 95, 45, .12), 0, 1.3)
    place(x, splat(rng, .6), .01, 1.)
    place(x, crunch(rng, 9 if head else 5), .005, .9)
    if head:
        place(x, np.sin(2 * math.pi * 200 * t[:int(.06 * SR)]) * env(t[:int(.06 * SR)], .0005, .015), 0, 1.)
        ding = (np.sin(2 * math.pi * 1568 * t) + .6 * np.sin(2 * math.pi * 3136 * t) + .25 * np.sin(2 * math.pi * 4704 * t)) * env(t, .002, .22)
        place(x, ding, .03, .45)
    return finish(reverb(x, .7, .2), .92, 1.7)


def hitmarker():
    rng = np.random.default_rng(7); t = t_axis(.06)
    x = (np.sin(2 * math.pi * 2200 * t) * .6 + biquad(rng.standard_normal(len(t)), 'bp', 3800, 3.) * .5) * env(t, .0003, .012)
    return finish(x, .7, 1.2)


def mech(seed, parts):
    rng = np.random.default_rng(seed); x = np.zeros(int(.45 * SR))
    for at, f, gain in parts: place(x, click(rng, f, .006, (f * .8, f * 1.3), .025), at, gain)
    return finish(reverb(x, .5, .15), .75, 1.3)


def swing(seed):
    rng = np.random.default_rng(seed); t = t_axis(.32)
    n = rng.standard_normal(len(t)); band = np.zeros(len(t))
    for k in range(6):
        seg = slice(int(k * len(t) / 6), int((k + 1) * len(t) / 6)); band[seg] = biquad(n[seg], 'bp', 400 + 700 * math.sin(k / 5 * math.pi), 1.)[:len(band[seg])]
    return finish(band * np.sin(np.pi * t / t[-1]) ** 2, .6, 1.2)


for frame in GUNS:
    for v in range(3): write(f'shot-{frame}-{v}', gunshot(frame, sum(map(ord, frame)) + v * 17))
for v in range(3): write(f'shot-rift-{v}', rift(90 + v))
for v in range(3):
    write(f'hit-body-{v}', hit_body(200 + v)); write(f'hit-head-{v}', hit_head(300 + v))
    write(f'kill-{v}', kill(400 + v, False)); write(f'kill-head-{v}', kill(500 + v, True))
write('hitmarker', hitmarker())
write('reload-out', mech(1, [(0, 1800, .8), (.06, 2600, .5)]))
write('reload-in', mech(2, [(0, 1500, .9), (.03, 2300, .7)]))
write('chamber', mech(3, [(0, 2400, .8), (.12, 1700, 1.)]))
write('empty', mech(4, [(0, 3400, .6)]))
write('swap', mech(5, [(0, 1200, .5), (.08, 2000, .6)]))
write('melee-swing', swing(6))
write('melee-hit', kill(600, False))
print('sfx written to', OUT)
