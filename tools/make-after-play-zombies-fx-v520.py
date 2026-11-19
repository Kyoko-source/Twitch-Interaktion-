"""Partynacht effects, sounds and music for After Play 5.2.0.

Everything here is generated from code (numpy + PIL + ffmpeg), nothing is
downloaded:
  fx/     particle and decal textures (glow, flame, smoke, muzzle stars,
          blood splats, scorch, bullet hole, shock ring)
  sfx/    explosions, electric zaps, flamethrower loop, launcher thump,
          gore splats, round gong, round end chime, upgrade, barrier break
  music/  an original music-box lullaby in A minor and a dread layer of the
          same length (heartbeat, low cluster, high whine) that the game
          fades in with the rounds. Both loop seamlessly.

Run: python tools/make-after-play-zombies-fx-v520.py
Output: games/kinderparadies/assets/zombies-v520/{fx,sfx,music}
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/zombies-v520'
SR = 44100
rng = np.random.default_rng(520)


# ---------------------------------------------------------------- textures
def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + .5) / n * 2 - 1, (y + .5) / n * 2 - 1


def fbm(n, octaves=5, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((n, n), np.float32)
    amp, total = 1., 0.
    for o in range(octaves):
        cells = 2 ** (o + 2)
        base = r.random((cells + 1, cells + 1)).astype(np.float32)
        img = Image.fromarray((base * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        out += np.asarray(img, np.float32) / 255 * amp
        total += amp
        amp *= .5
    return out / total


def save_rgba(name, rgb, alpha):
    rgb = np.clip(rgb, 0, 1)
    alpha = np.clip(alpha, 0, 1)
    if rgb.ndim == 2:
        rgb = np.stack([rgb] * 3, -1)
    data = np.dstack([rgb, alpha[..., None]])
    Image.fromarray((data * 255).astype(np.uint8), 'RGBA').save(OUT / 'fx' / name)


def textures():
    (OUT / 'fx').mkdir(parents=True, exist_ok=True)
    n = 256
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    # Soft glow dot (additive particles, light cores).
    glow = np.exp(-(r / .42) ** 2 * 2.2) * (r < 1)
    save_rgba('glow.png', np.ones_like(r), glow)
    # Flame tongue: teardrop pointing up, broken up by noise; white = hot.
    noise = fbm(n, 5, 1)
    tear = np.sqrt((x / (.55 + .25 * (y + 1) * .5)) ** 2 + ((y - .1) / .85) ** 2)
    flame = np.clip(1.15 - tear - (noise - .5) * .9, 0, 1) ** 1.4
    save_rgba('flame.png', np.ones_like(r), flame)
    # Smoke puff: lumpy soft ball, grey with alpha.
    smoke_noise = fbm(n, 6, 2)
    smoke = np.clip((1 - r) * 1.6 - (1 - smoke_noise) * .9, 0, 1) ** 1.2
    save_rgba('smoke.png', .55 + smoke_noise * .45, smoke)
    # Muzzle flash stars, three variants.
    angle = np.arctan2(y, x)
    for v in range(3):
        spikes = 5 + v
        phase = rng.random() * 6.28
        lengths = .55 + rng.random(spikes) * .45
        a = (angle + phase) % (2 * np.pi)
        idx = (a / (2 * np.pi) * spikes).astype(int) % spikes
        local = (a / (2 * np.pi) * spikes) % 1 - .5
        reach = lengths[idx]
        spike = np.clip(1 - np.abs(local) * (2.2 + r * 9), 0, 1) * np.clip(1 - r / reach, 0, 1)
        core = np.exp(-(r / .2) ** 2 * 2)
        star = np.clip(spike * 1.1 + core + (fbm(n, 4, 10 + v) - .5) * .35 * spike, 0, 1)
        save_rgba(f'muzzle-{v}.png', np.ones_like(r), star)
    # Side flash: a cone flame seen from the side (for the barrel).
    cone = np.clip(1 - np.abs(y) / (.08 + (x + 1) * .22), 0, 1) * np.clip(1 - (x + 1) / 2, 0, 1) ** .6
    cone = np.clip(cone * (1.1 - (fbm(n, 4, 20) - .5) * .8), 0, 1)
    save_rgba('muzzle-side.png', np.ones_like(r), cone)
    # Blood splats for decals: blob, satellites, drips, streaks.
    for v in range(6):
        sr = np.random.default_rng(100 + v)
        mask = np.zeros((n, n), np.float32)
        blob_noise = fbm(n, 5, 200 + v)
        mask = np.maximum(mask, np.clip((.42 + sr.random() * .12 - r) * 6 + (blob_noise - .5) * 2.4, 0, 1))
        for _ in range(sr.integers(10, 22)):
            ang = sr.random() * 6.28
            dist = .35 + sr.random() * .55
            cx, cy = np.cos(ang) * dist, np.sin(ang) * dist
            rad = .02 + sr.random() * .07
            d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            mask = np.maximum(mask, np.clip((rad - d) * 60, 0, 1))
        for _ in range(sr.integers(3, 7)):
            ang = sr.random() * 6.28
            ux, uy = np.cos(ang), np.sin(ang)
            along = x * ux + y * uy
            side = np.abs(-x * uy + y * ux)
            width = .015 + sr.random() * .03
            length = .5 + sr.random() * .45
            streak = np.clip((width * (1 - along / length) - side) * 80, 0, 1) * (along > .2) * (along < length)
            mask = np.maximum(mask, streak)
        mask *= r < .98
        shade = .55 + blob_noise * .45
        rgb = np.stack([.42 * shade, .01 * shade, .03 * shade], -1)
        save_rgba(f'blood-{v}.png', rgb, mask * .96)
    # Scorch mark.
    scorch_noise = fbm(n, 6, 300)
    scorch = np.clip((1 - r) * 1.5 - (1 - scorch_noise) * .7, 0, 1)
    save_rgba('scorch.png', np.stack([.05 + 0 * r, .04 + 0 * r, .035 + 0 * r], -1), scorch * .92)
    # Bullet hole.
    hole = np.clip((.25 - r) * 14, 0, 1) + np.clip((.55 - r) * 4, 0, 1) * .45 * fbm(n, 4, 301)
    save_rgba('hole.png', np.stack([.03 + 0 * r] * 3, -1), np.clip(hole, 0, 1))
    # Shock ring.
    ring = np.exp(-((r - .8) / .07) ** 2) + np.exp(-((r - .8) / .2) ** 2) * .35
    save_rgba('ring.png', np.ones_like(r), np.clip(ring, 0, 1))


# ---------------------------------------------------------------- audio
def write(name, data, folder='sfx', quality=5):
    data = np.asarray(data, np.float64)
    peak = np.max(np.abs(data)) or 1.
    data = data / peak * .89
    path = OUT / folder / f'{name}.ogg'
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / 'a.wav'
        with wave.open(str(wav_path), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((data * 32767).astype(np.int16).tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(wav_path), '-c:a', 'libvorbis', '-q:a', str(quality), str(path)], check=True)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def spectral(signal, low=None, high=None):
    """Brick-ish band filter in the frequency domain (soft edges)."""
    spec = np.fft.rfft(signal)
    f = np.fft.rfftfreq(len(signal), 1 / SR)
    gain = np.ones_like(f)
    if low:
        gain *= 1 / (1 + (low / np.maximum(f, 1)) ** 4)
    if high:
        gain *= 1 / (1 + (f / high) ** 4)
    return np.fft.irfft(spec * gain, len(signal))


def noise(seconds, seed):
    return np.random.default_rng(seed).standard_normal(int(seconds * SR))


def sweep(f0, f1, seconds, curve=3.):
    t = t_axis(seconds)
    f = f1 + (f0 - f1) * np.exp(-t * curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def reverb(signal, seconds=2.2, mix=.35, seed=7, damp=3.):
    t = t_axis(seconds)
    ir = np.random.default_rng(seed).standard_normal(len(t)) * np.exp(-t * damp)
    ir = spectral(ir, high=5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = len(signal) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(ir, size), size)[:len(signal) + len(ir) - 1]
    out = np.zeros(len(wet))
    out[:len(signal)] += signal * (1 - mix)
    out += wet * mix
    return out


def sounds():
    for v in range(3):
        t = t_axis(2.4)
        body = spectral(noise(2.4, 10 + v), high=900 + v * 300) * np.exp(-t * (3.2 - v * .4))
        crack = spectral(noise(2.4, 20 + v), low=1500) * np.exp(-t * 22)
        boom = sweep(95 - v * 10, 32, 2.4, 4.) * np.exp(-t * 2.6) * 1.6
        crackle = (np.random.default_rng(30 + v).random(len(t)) > .9985) * np.random.default_rng(31 + v).standard_normal(len(t)) * np.exp(-t * 1.5) * 2.
        write(f'explosion-{v}', reverb(body * 1.3 + crack * .7 + boom + spectral(crackle, low=800), 1.6, .3, 40 + v))
    for v in range(3):
        t = t_axis(.42)
        base = 70 + v * 25
        buzz = np.sign(np.sin(2 * np.pi * base * t + 3 * np.sin(2 * np.pi * 13 * t))) * .4
        hiss = spectral(noise(.42, 50 + v), low=2500) * (np.random.default_rng(60 + v).random(len(t)) > .6)
        env = np.exp(-t * 7) * (1 + .6 * np.sin(2 * np.pi * 37 * t))
        write(f'zap-{v}', (buzz + hiss * .9) * env)
    # Flamethrower loop: 2 s, made seamless by a crossfade with its own tail.
    length = 2.0
    raw = spectral(noise(length + .5, 70), low=120, high=1800) * 1. + spectral(noise(length + .5, 71), low=2000, high=6000) * .25
    t = t_axis(length + .5)
    raw *= 1 + .25 * np.sin(2 * np.pi * 7 * t) * np.sin(2 * np.pi * .7 * t)
    n = int(length * SR)
    fade = int(.5 * SR)
    loop = raw[:n].copy()
    w = np.linspace(0, 1, fade)
    loop[:fade] = raw[:fade] * w + raw[n:n + fade] * (1 - w)
    write('flame-loop', loop)
    t = t_axis(.5)
    write('launcher', sweep(160, 45, .5, 9.) * np.exp(-t * 7) + spectral(noise(.5, 80), high=600) * np.exp(-t * 25) * .8)
    for v in range(3):
        t = t_axis(.35)
        splat = spectral(noise(.35, 90 + v), high=700 + v * 250) * np.exp(-t * 16) + sweep(220, 70, .35, 14.) * np.exp(-t * 18) * .5
        write(f'gore-{v}', splat)
    # Round gong: low bell partials + reverse swell + drum.
    t = t_axis(5.)
    bell = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, a, d in [(73.4, 1., .7), (146.8 * 1.003, .5, 1.), (198.2, .35, 1.4), (276.5, .25, 1.9), (392.1, .15, 2.6)])
    swell_t = t_axis(1.2)
    swell = spectral(noise(1.2, 100), low=300, high=3000) * (swell_t / 1.2) ** 3 * .6
    drum = sweep(110, 40, 1.2, 8.) * np.exp(-swell_t * 4) * 1.4
    gong = np.zeros(len(t) + len(swell_t))
    gong[:len(swell_t)] += swell
    gong[len(swell_t):len(swell_t) + len(drum)] += drum
    gong[len(swell_t):] += bell
    write('round-start', reverb(gong, 3., .4, 101))
    # Round end: music-box falling phrase.
    phrase = np.zeros(int(3.2 * SR))
    for i, semi in enumerate([12, 7, 3, 0, -1]):
        note = musicbox(440 * 2 ** (semi / 12), 1.6, .9)
        at = int(i * .32 * SR)
        phrase[at:at + len(note)] += note[:len(phrase) - at]
    write('round-end', reverb(phrase, 2.5, .45, 102))
    t = t_axis(2.2)
    rise = sweep(120, 1400, 2.2, -1.1) if False else np.sin(2 * np.pi * np.cumsum(120 + 1300 * (t / 2.2) ** 2) / SR) * (t / 2.2) * .5
    clang = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(523., 1.), (1187., .6), (1979., .4)]) * np.exp(-np.maximum(t - 1.7, 0) * 5) * (t > 1.7)
    write('upgrade', reverb(rise + clang + spectral(noise(2.2, 110), low=4000) * (t / 2.2) ** 4 * .4, 2., .35, 111))
    t = t_axis(1.1)
    hits = np.zeros(len(t))
    for k, at in enumerate([0, .07, .19, .33, .5, .62]):
        i = int(at * SR)
        seg = spectral(noise(.25, 120 + k), low=200 + k * 150, high=3000) * np.exp(-t_axis(.25) * 26)
        hits[i:i + len(seg)] += seg[:len(hits) - i] * (1 - k * .12)
    write('barrier-break', hits + sweep(90, 40, 1.1, 6.) * np.exp(-t * 6) * .6)
    t = t_axis(.6)
    write('confetti', spectral(noise(.6, 130), low=3000) * np.exp(-t * 9) * (np.random.default_rng(131).random(len(t)) > .7))


def musicbox(freq, seconds, velocity=1.):
    t = t_axis(seconds)
    wow = 1 + .004 * np.sin(2 * np.pi * .35 * t)
    tone = np.zeros(len(t))
    for ratio, amp, decay in [(1., 1., 2.3), (2.76, .26, 4.5), (5.40, .1, 8.), (8.93, .04, 12.)]:
        for detune, weight in [(1., 1.), (1.0025, .45)]:
            tone += amp * weight * np.sin(2 * np.pi * np.cumsum(np.full(len(t), freq * ratio * detune) * wow) / SR) * np.exp(-t * decay)
    attack = np.minimum(t / .002, 1)
    click = np.random.default_rng(int(freq)).standard_normal(len(t)) * np.exp(-t * 900) * .15
    return (tone * attack + click) * velocity * .5


# ---------------------------------------------------------------- music
BPM = 72
BEAT = 60 / BPM
# (semitones from A4, beats) per bar, 16 bars of 3/4 in A minor.
MELODY = [
    [(7, 2), (5, 1)], [(3, 1), (2, 1), (0, 1)], [(7, 1), (8, 1), (7, 1)], [(-1, 3)],
    [(0, 1), (3, 1), (7, 1)], [(12, 2), (10, 1)], [(8, 1), (7, 1), (6, 1)], [(7, 3)],
    [(3, 2), (5, 1)], [(7, 1), (5, 1), (3, 1)], [(2, 1), (3, 1), (-1, 1)], [(0, 3)],
    [(8, 2), (7, 1)], [(6, 1), (7, 1), (2, 1)], [(3, 1), (2, 1), (-4, 1)], [(0, 3)],
]
ROOTS = [0, 0, 0, -5, 0, -4, -7, -5, -4, 3, -5, 0, -7, -5, -7, 0]


def music():
    bars = len(MELODY)
    length = bars * 3 * BEAT
    total = int(length * SR)
    tail = int(4 * SR)
    calm = np.zeros(total + tail)

    def place(buffer, sound, at):
        i = int(at * SR)
        end = min(i + len(sound), len(buffer))
        buffer[i:end] += sound[:end - i]

    for bar, notes in enumerate(MELODY):
        beat = bar * 3
        for semi, beats in notes:
            place(calm, musicbox(440 * 2 ** (semi / 12), 3.5, .9 + rng.random() * .15), beat * BEAT + rng.random() * .012)
            beat += beats
        root = 440 * 2 ** ((ROOTS[bar] - 12) / 12)
        place(calm, musicbox(root, 3.5, .55), bar * 3 * BEAT)
        place(calm, musicbox(root * 1.5, 2.5, .25), (bar * 3 + 1) * BEAT)
        place(calm, musicbox(root * 2, 2.5, .22), (bar * 3 + 2) * BEAT)
    t = t_axis(length + 4)[:len(calm)]
    drone = (np.sin(2 * np.pi * 110 * t) + .6 * np.sin(2 * np.pi * 164.8 * t) + .3 * np.sin(2 * np.pi * 220.6 * t)) * (.5 + .5 * np.sin(2 * np.pi * t / length * 2)) * .07
    calm += drone
    calm = reverb(calm, 3.5, .45, 200, 1.6)

    dread = np.zeros(total + tail)
    beat_sound = sweep(70, 42, .35, 10.) * np.exp(-t_axis(.35) * 9)
    for bar in range(bars):
        place(dread, beat_sound, bar * 3 * BEAT)
        place(dread, beat_sound * .7, bar * 3 * BEAT + .32)
    t = t_axis(length + 4)[:len(dread)]
    cluster = np.zeros(len(t))
    for f in [55., 58.27, 82.4, 87.3]:
        cluster += ((t * f) % 1 * 2 - 1)
    cluster = spectral(cluster, high=420) * (.6 + .4 * np.sin(2 * np.pi * t / length * 2 - 1.5)) * .35
    whine = np.sin(2 * np.pi * np.cumsum(1318.5 * (1 + .006 * np.sin(2 * np.pi * 5.3 * t))) / SR) * .025 * (.5 + .5 * np.sin(2 * np.pi * t / length * 4))
    breath = spectral(noise(len(t) / SR, 210), low=300, high=1200)[:len(t)] * .05 * (.5 + .5 * np.sin(2 * np.pi * t / BEAT / 6))
    dread += cluster + whine + breath
    dread = reverb(dread, 3., .4, 201, 1.8)

    for name, track in [('partynacht-lullaby', calm), ('partynacht-dread', dread)]:
        loop = track[:total].copy()
        overflow = track[total:]
        loop[:len(overflow)] += overflow[:total]
        write(name, loop, 'music', 6)


def main():
    textures()
    sounds()
    music()
    for p in sorted(OUT.rglob('*')):
        if p.is_file():
            print(p.relative_to(OUT), p.stat().st_size)


main()
