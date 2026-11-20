"""After Play 5.2.1 trailer: "Ein ruhiges, atmosphärisches Horrorspiel."

Three acts in about 83 seconds:
  1. the original night shift (slow camera moves, music box, quiet cards),
  2. Nightwatch Protocol (control room, full-screen anomaly, generator QTE),
  3. the switch (tape stop, record scratch, "...WAR ES.", a red stamp) and the
     Partynacht escalation cut to a synthesised party-metal track.

Inputs:
  --capture DIR   folder with trailer.avi (Godot movie maker, 30 fps) and
                  trailer.log (the "TRAILER MARK name frame" lines)
Output: games/kinderparadies/build/trailer/After-Play-Partynacht-Trailer-1080p.mp4

Music, sound effects and cards are generated here (numpy, PIL, ffmpeg).
Footage is unmodified game capture from scripts/trailer_director.gd.
"""
import json
import math
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'games/kinderparadies'
OUT = GAME / 'build/trailer/After-Play-Partynacht-Trailer-1080p.mp4'
FPS = 30
W, H = 1920, 1080
SR = 48000
OSWALD = str(GAME / 'assets/Oswald.ttf')
SERIF = str(GAME / 'assets/presentation-v250/BodoniModa.ttf')
rng = np.random.default_rng(521)

# ---------------------------------------------------------------- timeline
# kind, name, duration, extra
T_SWITCH = 40.0
T_DROP = 45.0
TIMELINE = [
    ('card', 'open', 3.0, {}),
    ('clip', 'a1', 4.5, {}),
    ('card', 'night', 2.0, {}),
    ('clip', 'a2', 4.0, {}),
    ('clip', 'a3', 4.0, {}),
    ('card', 'rounds', 2.0, {}),
    ('clip', 'a4', 3.5, {}),
    ('clip', 'a5', 3.5, {}),
    ('card', 'protocol', 2.0, {}),
    ('clip', 'b1', 3.5, {}),
    ('clip', 'b2', 3.0, {}),
    ('clip', 'b3', 3.0, {'last': True}),
    ('card', 'calm', 2.0, {}),          # 38.0 .. 40.0, tape stop at the end
    ('card', 'scratch', 0.6, {}),       # frozen, desaturated
    ('card', 'wares', 2.5, {}),
    ('card', 'rule', 1.9, {}),          # .. 45.0 drop
    ('clip', 'c1', 3.5, {'lower': 'RUNDE 1 · DIE GÄSTE SIND DA'}),
    ('clip', 'c2', 3.0, {}),
    ('card', 'cakes', 1.0, {}),
    ('clip', 'c3', 1.5, {'lower': 'TORTENWERFER TW-3', 'offset': 0.0}),
    ('clip', 'c4', 3.5, {'lower': 'KUCHENBRENNER F-9'}),
    ('clip', 'c5', 3.0, {'lower': 'GEWITTERKIND TESLA-SPULE'}),
    ('card', 'rating', 1.0, {}),
    ('clip', 'c6', 3.5, {'lower': 'MARELL, DER KOCH DER LETZTEN TORTE'}),
    ('clip', 'c7', 3.5, {}),
    ('card', 'list', 1.2, {}),
    ('clip', 'c8', 3.8, {}),
    ('card', 'logo', 6.0, {}),
    ('card', 'sting', 3.2, {}),
]


def starts():
    t, out = 0.0, []
    for row in TIMELINE:
        out.append(t)
        t += row[2]
    return out, t


# ---------------------------------------------------------------- cards
def font(path, size):
    return ImageFont.truetype(path, size)


def text_size(draw, text, f):
    box = draw.textbbox((0, 0), text, font=f)
    return box[2] - box[0], box[3] - box[1], box


def base(dark=(4, 3, 6)):
    img = Image.new('RGB', (W, H), dark)
    return img


def vignette_grain(img, seed, grain=10):
    arr = np.asarray(img).astype(np.float32)
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
    arr *= np.clip(1.15 - d * .45, 0, 1)[..., None]
    arr += np.random.default_rng(seed).normal(0, grain, (H, W, 1))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def centered(draw, lines, f, color, y_center, spacing=1.25, alpha=1.0):
    sizes = [text_size(draw, line, f) for line in lines]
    total = sum(s[1] for s in sizes) * spacing
    y = y_center - total / 2
    for line, (w, h, box) in zip(lines, sizes):
        c = tuple(int(v * alpha) for v in color)
        draw.text(((W - w) / 2 - box[0], y - box[1]), line, font=f, fill=c)
        y += h * spacing


def glow_text(lines, f, color, y_center, blur=18, strength=1.6, spacing=1.25):
    layer = Image.new('RGB', (W, H), (0, 0, 0))
    centered(ImageDraw.Draw(layer), lines, f, color, y_center, spacing)
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    halo = Image.eval(halo, lambda v: min(255, int(v * strength)))
    return layer, halo


def add(a, b):
    return Image.fromarray(np.clip(np.asarray(a).astype(np.int16) + np.asarray(b).astype(np.int16), 0, 255).astype(np.uint8))


def rgb_split(img, px):
    arr = np.asarray(img)
    out = arr.copy()
    out[..., 0] = np.roll(arr[..., 0], px, axis=1)
    out[..., 2] = np.roll(arr[..., 2], -px, axis=1)
    return Image.fromarray(out)


def scaled(img, s):
    if abs(s - 1) < 1e-3:
        return img
    w2, h2 = int(W * s), int(H * s)
    big = img.resize((w2, h2), Image.BICUBIC)
    canvas = Image.new('RGB', (W, H), (0, 0, 0))
    canvas.paste(big, ((W - w2) // 2, (H - h2) // 2))
    return canvas


def ease_out_back(x):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def card_frames(name, seconds, still=None):
    n = int(round(seconds * FPS))
    serif_big, serif_mid = font(SERIF, 86), font(SERIF, 54)
    osw_huge, osw_big, osw_mid, osw_small = font(OSWALD, 300), font(OSWALD, 150), font(OSWALD, 64), font(OSWALD, 38)
    for i in range(n):
        t = i / FPS
        k = i / max(n - 1, 1)
        fade = min(1, t / .45, (seconds - t) / .45)
        if name in ('open', 'night', 'rounds', 'calm'):
            lines = {'open': ['Ein Kinderparadies.'], 'night': ['Nachts gehört es dir.'],
                     'rounds': ['Dreizehn Rundgänge.', 'Keine zweite Sicherheit.'],
                     'calm': ['Ein ruhiges,', 'atmosphärisches Horrorspiel.']}[name]
            img = base()
            centered(ImageDraw.Draw(img), lines, serif_big, (236, 228, 210), H / 2, alpha=max(fade, 0))
            yield vignette_grain(img, i)
        elif name == 'protocol':
            img = base((2, 6, 4))
            d = ImageDraw.Draw(img)
            a = max(fade, 0)
            centered(d, ['NIGHTWATCH PROTOCOL'], osw_big, (140, 255, 170), H / 2 - 60, alpha=a)
            centered(d, ['Bewache die Nacht. Melde jede Anomalie.'], serif_mid, (210, 230, 210), H / 2 + 90, alpha=a)
            arr = np.asarray(img).astype(np.float32)
            arr[::3] *= .55
            yield vignette_grain(Image.fromarray(arr.astype(np.uint8)), i, 14)
        elif name == 'scratch':
            # The last control-room frame, frozen and drained of colour.
            img = still.convert('L').convert('RGB') if still else base()
            img = scaled(img, 1 + k * .04)
            d = ImageDraw.Draw(img)
            centered(d, ['* KRATZ *'], osw_mid, (255, 255, 255), H - 140)
            yield img
        elif name == 'wares':
            img = base((0, 0, 0))
            layer, halo = glow_text(['… WAR ES.'], osw_huge, (255, 40, 60), H / 2)
            img = add(add(img, layer), halo)
            pop = ease_out_back(min(t / .3, 1))
            img = scaled(img, 2.2 - 1.2 * pop)
            jitter = int((rng.random() - .5) * 26 * max(0, 1 - t / 1.2)) + (8 if (i // 3) % 4 == 0 else 0)
            img = rgb_split(img, 6 + jitter)
            arr = np.asarray(img).astype(np.float32)
            arr[::4] *= .7
            if (i // 2) % 9 == 0:
                cut = rng.integers(0, H - 80)
                arr[cut:cut + 60] = np.roll(arr[cut:cut + 60], int(rng.integers(-90, 90)), axis=1)
            yield Image.fromarray(arr.clip(0, 255).astype(np.uint8))
        elif name == 'rule':
            img = base((10, 8, 6))
            d = ImageDraw.Draw(img)
            centered(d, ['SICHERHEITSVORSCHRIFT § 1'], osw_mid, (230, 210, 160), H / 2 - 120)
            centered(d, ['Keine Waffen im Kinderparadies.'], serif_big, (240, 232, 214), H / 2)
            if t > .75:
                s = max(1., 2.6 - (t - .75) / .12 * 1.6)
                stamp = Image.new('RGBA', (1100, 300), (0, 0, 0, 0))
                sd = ImageDraw.Draw(stamp)
                sd.rounded_rectangle((10, 10, 1090, 290), radius=26, outline=(220, 20, 30, 255), width=16)
                sw, sh, sbox = text_size(sd, 'ABGELEHNT', osw_big)
                sd.text(((1100 - sw) / 2 - sbox[0], (300 - sh) / 2 - sbox[1]), 'ABGELEHNT', font=osw_big, fill=(225, 25, 35, 255))
                stamp = stamp.rotate(-12, expand=True, resample=Image.BICUBIC)
                stamp = stamp.resize((int(stamp.width * s), int(stamp.height * s)), Image.BICUBIC)
                img.paste(stamp, ((W - stamp.width) // 2, (H - stamp.height) // 2 + 70), stamp)
            shake = int(14 * max(0, 1 - (t - .75) / .3)) if t > .75 else 0
            img = Image.fromarray(np.roll(np.asarray(img), (int(rng.integers(-shake, shake + 1)) if shake else 0), axis=0))
            yield vignette_grain(img, i, 8)
        elif name in ('cakes', 'rating'):
            top, big = {'cakes': ('JETZT MIT', '100 % MEHR TORTEN'), 'rating': ('ALTERSFREIGABE', 'KINDERGEBURTSTAG')}[name]
            colors = [(255, 60, 140), (255, 210, 60), (60, 255, 180), (80, 170, 255)]
            img = base((14, 0, 20) if name == 'cakes' else (20, 2, 2))
            # confetti
            d = ImageDraw.Draw(img)
            cr = np.random.default_rng(7 + i // 2)
            for c in range(160):
                x, y = cr.integers(0, W), (cr.integers(0, H) + i * 14) % H
                d.rectangle((x, y, x + 14, y + 8), fill=colors[c % 4])
            layer, halo = glow_text([big], osw_big, (255, 255, 255), H / 2 + 40, 14, 1.3)
            img = add(add(img, halo), layer)
            d = ImageDraw.Draw(img)
            centered(d, [top], osw_mid, colors[1], H / 2 - 110)
            pop = ease_out_back(min(t / .22, 1))
            yield rgb_split(scaled(img, 1.6 - .6 * pop), 4)
        elif name == 'list':
            words = ['33 WAFFEN', '12 PERKS', '4 BOSSE', 'UNENDLICH RUNDEN', 'KONFETTI']
            word = words[min(int(t / (seconds / len(words))), len(words) - 1)]
            colors = [(255, 40, 60), (255, 210, 60), (60, 255, 180), (190, 110, 255), (255, 120, 40)]
            img = base((0, 0, 0))
            layer, halo = glow_text([word], osw_big, colors[words.index(word)], H / 2, 16, 1.5)
            yield rgb_split(scaled(add(add(img, layer), halo), 1.08 - (t % (seconds / len(words))) * .25), 5)
        elif name == 'logo':
            img = base((3, 2, 5))
            a = min(1, t / .6)
            title, halo = glow_text(['AFTER PLAY'], font(SERIF, 210), (240, 232, 214), H / 2 - 120, 22, 1.2)
            flick = 1.0 if (i % 37) not in (3, 4, 19) else .25
            neon, nhalo = glow_text(['PARTYNACHT'], osw_big, (255, 50, 150), H / 2 + 80, 24, 2.2)
            img = add(img, Image.eval(halo, lambda v: int(v * a)))
            img = add(img, Image.eval(title, lambda v: int(v * a)))
            if t > .5:
                img = add(img, Image.eval(nhalo, lambda v: int(v * flick)))
                img = add(img, Image.eval(neon, lambda v: int(v * flick)))
            d = ImageDraw.Draw(img)
            if t > 1.2:
                centered(d, ['Kostenlos spielen · my-aviary.de · itch.io'], osw_mid, (240, 220, 170), H - 230)
                centered(d, ['Version 5.2.2 · Windows'], osw_small, (170, 165, 150), H - 150)
            # falling confetti
            cr = np.random.default_rng(99)
            colors = [(255, 60, 140), (255, 210, 60), (60, 255, 180), (80, 170, 255), (190, 110, 255)]
            for c in range(120):
                x0, sp = cr.integers(0, W), cr.uniform(80, 260)
                y = (cr.integers(-H, 0) + t * sp) % (H + 40) - 20
                x = x0 + math.sin(t * 2 + c) * 30
                d.rectangle((x, y, x + 12, y + 7), fill=colors[c % 5])
            img = scaled(img, 1.0 + k * .03)
            yield vignette_grain(img, i, 6)
        elif name == 'sting':
            img = base()
            d = ImageDraw.Draw(img)
            if t < 1.6:
                centered(d, ['Die Gäste warten.'], serif_big, (236, 228, 210), H / 2, alpha=min(1, t / .4))
            else:
                centered(d, ['Bring Kuchen mit.'], serif_mid, (255, 120, 170), H / 2, alpha=min(1, (t - 1.6) / .2, (seconds - t) / .3))
            yield vignette_grain(img, i)


def write_frames(frames, path, seconds):
    proc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                             '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p', '-t', f'{seconds:.3f}', str(path)], stdin=subprocess.PIPE)
    for f in frames:
        proc.stdin.write(f.tobytes())
    proc.stdin.close()
    proc.wait()


def lower_third(text, path):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(OSWALD, 58)
    w, h, box = text_size(d, text, f)
    x, y = 90, H - 230
    d.rectangle((x - 30, y - 22, x + w + 40, y + h + 30), fill=(10, 0, 8, 170))
    d.rectangle((x - 30, y - 22, x - 18, y + h + 30), fill=(255, 40, 120, 255))
    d.text((x - box[0], y - box[1]), text, font=f, fill=(255, 245, 230, 255))
    img.save(path)


# ---------------------------------------------------------------- audio
def write_wav(path, data):
    data = np.clip(data, -1, 1)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        stereo = np.stack([data, data], -1) if data.ndim == 1 else data
        w.writeframes((stereo * 32767).astype(np.int16).tobytes())


def read_audio(path, seconds=None):
    cmd = ['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '1', '-ar', str(SR)]
    if seconds:
        cmd += ['-t', str(seconds)]
    raw = subprocess.run(cmd + ['-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def tt(seconds):
    return np.arange(int(seconds * SR)) / SR


def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec / (1 + (f / cutoff) ** 4), len(x))


def highpass(x, cutoff):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec / (1 + (cutoff / np.maximum(f, 1)) ** 4), len(x))


def place(buf, sound, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[:end - i]


def kick():
    t = tt(.35)
    f = 45 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 1.1 + np.random.default_rng(1).standard_normal(len(t)) * np.exp(-t * 300) * .3


def snare():
    t = tt(.25)
    return highpass(np.random.default_rng(2).standard_normal(len(t)), 1200) * np.exp(-t * 16) * .55 + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 22) * .5


def hat(open_=False):
    t = tt(.25 if open_ else .06)
    return highpass(np.random.default_rng(3).standard_normal(len(t)), 7000) * np.exp(-t * (10 if open_ else 70)) * .22


def crash():
    t = tt(2.2)
    return highpass(np.random.default_rng(4).standard_normal(len(t)), 4500) * np.exp(-t * 1.8) * .3


def boom(length=2.0, pitch=55):
    t = tt(length)
    f = pitch * .6 + pitch * 1.5 * np.exp(-t * 5)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    return body * 1.2 + lowpass(np.random.default_rng(5).standard_normal(len(t)), 900) * np.exp(-t * 6) * .6


def whoosh(length=.6):
    t = tt(length)
    n = np.random.default_rng(6).standard_normal(len(t))
    env = np.sin(np.pi * t / length) ** 2
    return highpass(n, 600) * env * .35


def power(freq, length, mute=True):
    t = tt(length)
    wave_ = np.zeros(len(t))
    for ratio, amp in [(1, 1.), (1.5, .8), (2, .6)]:
        for det in (1., 1.006):
            wave_ += amp * (((t * freq * ratio * det) % 1) * 2 - 1)
    env = np.exp(-t * (14 if mute else 1.2)) * np.minimum(t / .004, 1)
    dist = np.tanh(wave_ * 2.8 * env)
    return lowpass(dist, 2600) * .45


def square_lead(freq, length):
    t = tt(length)
    vib = 1 + .006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / .2, 1)
    ph = np.cumsum(freq * vib) / SR
    sq = np.sign(np.sin(2 * np.pi * ph)) * .5 + np.sign(np.sin(2 * np.pi * ph * 2.001)) * .15
    env = np.minimum(t / .01, 1) * np.exp(-t * 1.4)
    return lowpass(sq, 3200) * env * .32


def tape_stop(x, seconds):
    """Slow the end of x down to a halt (the classic 'record runs out')."""
    n = int(seconds * SR)
    head, tail = x[:-n], x[-n:]
    speed = np.linspace(1, 0, n) ** 1.5
    pos = np.cumsum(speed)
    pos = np.clip(pos, 0, len(tail) - 1)
    return np.concatenate([head, np.interp(pos, np.arange(len(tail)), tail)])


def scratch():
    t = tt(.55)
    wob = np.sin(2 * np.pi * (3 + 9 * t) * t)
    n = np.random.default_rng(8).standard_normal(len(t))
    sig = np.fft.irfft(np.fft.rfft(n) * np.exp(-((np.fft.rfftfreq(len(t), 1 / SR) - 1400) / 900) ** 2), len(t))
    return sig * (np.abs(wob) ** .5) * np.exp(-t * 2.5) * 3.


A_MIN = [0, 3, 7, 12]
LULLABY = [(7, 2), (5, 1), (3, 1), (2, 1), (0, 1), (7, 1), (8, 1), (7, 1), (-1, 3), (0, 1), (3, 1), (7, 1), (12, 2), (10, 1), (8, 1), (7, 1), (6, 1), (7, 3)]


def party_metal(length):
    bpm = 150
    beat = 60 / bpm
    buf = np.zeros(int(length * SR) + SR)
    riff = [45, 45, 48, 50, 45, 45, 53, 52]  # MIDI: A2 A2 C3 D3 A2 A2 F3 E3 (8ths, 1 bar = 8)
    bars = int(length / (beat * 4)) + 1
    for bar in range(bars):
        b0 = bar * beat * 4
        hot = bar >= 8
        for step in range(8):
            at = b0 + step * beat / 2
            note = riff[(step + (4 if bar % 4 == 3 else 0)) % 8]
            place(buf, power(440 * 2 ** ((note - 69) / 12), beat / 2 * .95, mute=step % 2 == 1), at)
            place(buf, hat(step % 4 == 3) * (1.2 if hot else 1.), at)
            if hot:
                place(buf, hat() * .7, at + beat / 4)
        for k in [0, 1.5, 2] if hot else [0, 2]:
            place(buf, kick(), b0 + k * beat)
        for k in [1, 3]:
            place(buf, snare(), b0 + k * beat)
        if bar % 4 == 0 or (hot and bar % 2 == 0):
            place(buf, crash(), b0)
    # The lullaby, now on a screaming square lead.
    at = beat * 4 * 2
    while at < length - 1:
        for semi, beats in LULLABY:
            place(buf, square_lead(880 * 2 ** (semi / 12), beats * beat * .95), at)
            at += beats * beat
            if at >= length - 1:
                break
        at += beat * 4
    return buf[:int(length * SR)]


def riser(length):
    t = tt(length)
    n = highpass(np.random.default_rng(9).standard_normal(len(t)), 900) * (t / length) ** 2 * .5
    saw = (((np.cumsum(110 + 700 * (t / length) ** 2) / SR) % 1) * 2 - 1) * (t / length) ** 3 * .25
    roll = np.zeros(len(t))
    pos = 0.
    while pos < length:
        place(roll, snare() * (.3 + .7 * pos / length), pos)
        pos += max(.05, .25 * (1 - pos / length))
    return n + lowpass(saw, 3000) + roll


def music(total):
    buf = np.zeros(int((total + 1) * SR))
    lullaby = read_audio(GAME / 'assets/zombies-v520/music/partynacht-lullaby.ogg', T_SWITCH)
    lullaby = tape_stop(lullaby, 1.6)
    lullaby[:int(1.5 * SR)] *= np.linspace(0, 1, int(1.5 * SR))
    place(buf, lullaby * .9, 0)
    place(buf, scratch(), T_SWITCH)
    place(buf, boom(2.5, 50) * .9, T_SWITCH + .6)
    place(buf, riser(T_DROP - T_SWITCH - 3.1), T_SWITCH + 3.1)
    logo_at = None
    s, _ = starts()
    for (kind, name, dur, extra), at in zip(TIMELINE, s):
        if name == 'logo':
            logo_at = at
        if name in ('rule',):
            place(buf, boom(1.4, 70) * .7, at + .75)
        if name in ('cakes', 'rating', 'list'):
            place(buf, whoosh(.4), at - .2)
            place(buf, boom(.8, 80) * .6, at)
    metal_len = logo_at - T_DROP
    metal = party_metal(metal_len)
    fade = int(.15 * SR)
    metal[-fade:] *= np.linspace(1, 0, fade)
    place(buf, metal, T_DROP)
    place(buf, boom(3., 45) * 1.1, T_DROP)
    place(buf, crash() * 1.4, T_DROP)
    # Logo: one huge hit, a ringing chord and the music box again.
    place(buf, boom(4., 40) * 1.2, logo_at)
    place(buf, crash() * 1.6, logo_at)
    t = tt(5.5)
    chord = sum(np.sin(2 * np.pi * 220 * 2 ** (s_ / 12) * t) for s_ in A_MIN) * np.exp(-t * .7) * .12
    place(buf, chord, logo_at)
    box = read_audio(GAME / 'assets/zombies-v520/sfx/round-end.ogg')
    place(buf, box * .7, logo_at + 6.2)
    return buf[:int(total * SR)]


# ---------------------------------------------------------------- edit
def marks(log_path):
    found = {}
    for line in Path(log_path).read_text(encoding='utf-8', errors='ignore').splitlines():
        m = re.search(r'TRAILER MARK (\w+) (\d+)', line)
        if m:
            found[m.group(1)] = int(m.group(2))
    return found


def main():
    capture = Path(sys.argv[sys.argv.index('--capture') + 1])
    avi = capture / 'trailer.avi'
    frame_of = marks(capture / 'trailer.log')
    first = min(frame_of.values())
    base_frame = int(json.loads((capture / 'trailer-offset.json').read_text())['first_frame']) if (capture / 'trailer-offset.json').exists() else 0
    work = Path(tempfile.mkdtemp(prefix='ap-trailer-'))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    s, total = starts()
    parts, game_audio = [], np.zeros(int((total + 1) * SR))
    still = None
    for idx, ((kind, name, dur, extra), at) in enumerate(zip(TIMELINE, s)):
        clip = work / f'{idx:02d}-{name}.mp4'
        if kind == 'clip':
            start = (frame_of[name] - base_frame) / FPS + extra.get('offset', .1)
            vf = 'scale=1920:1080:flags=lanczos,setsar=1' + (',eq=gamma=1.35:brightness=0.02:saturation=1.12' if name.startswith('a') else '')
            inputs = ['-ss', f'{start:.3f}', '-t', f'{dur:.3f}', '-i', str(avi)]
            if extra.get('lower'):
                lt = work / f'{name}-lower.png'
                lower_third(extra['lower'], lt)
                inputs += ['-loop', '1', '-t', f'{dur:.3f}', '-i', str(lt)]
                vf = f'[0:v]scale=1920:1080:flags=lanczos,setsar=1[v0];[1:v]format=rgba,fade=t=in:st=0.2:d=0.25:alpha=1,fade=t=out:st={dur - .4:.2f}:d=0.3:alpha=1[lt];[v0][lt]overlay=0:0'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', vf, '-r', str(FPS), '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p', str(clip)], check=True)
            else:
                subprocess.run(['ffmpeg', '-v', 'error', '-y', *inputs, '-vf', vf, '-r', str(FPS), '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p', str(clip)], check=True)
            if extra.get('last'):
                still_path = work / 'still.png'
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{start + dur - .05:.3f}', '-i', str(avi), '-frames:v', '1', str(still_path)], check=True)
                still = Image.open(still_path).convert('RGB').resize((W, H))
            sound = read_audio_segment(avi, start, dur)
            level = .35 if name.startswith(('a', 'b')) else .8
            place(game_audio, sound * level, at)
        else:
            write_frames(card_frames(name, dur, still), clip, dur)
        parts.append(clip)
    listing = work / 'parts.txt'
    listing.write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts), encoding='utf-8')
    video = work / 'video.mp4'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(listing), '-c', 'copy', str(video)], check=True)
    mix = music(total) * .8 + game_audio[:int(total * SR)] * .9
    mix = mix / max(1e-6, np.max(np.abs(mix))) * .95
    audio = work / 'mix.wav'
    write_wav(audio, mix)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(video), '-i', str(audio),
                    '-af', 'loudnorm=I=-14:TP=-1.2:LRA=9', '-map', '0:v', '-map', '1:a',
                    '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-maxrate', '14M', '-bufsize', '28M', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-movflags', '+faststart', '-shortest',
                    '-metadata', 'title=After Play — Partynacht Trailer', '-metadata', 'comment=Unmodified game capture, generated music and cards.',
                    str(OUT)], check=True)
    print(OUT, f'{total:.1f}s')


def read_audio_segment(path, start, dur):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-ss', f'{start:.3f}', '-t', f'{dur:.3f}', '-i', str(path), '-vn', '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True).stdout
    data = np.frombuffer(raw, np.float32).astype(np.float64)
    fade = min(len(data) // 4, int(.05 * SR))
    if fade:
        data[:fade] *= np.linspace(0, 1, fade)
        data[-fade:] *= np.linspace(1, 0, fade)
    return data


if __name__ == '__main__':
    if '--preview-cards' in sys.argv:
        out = Path(sys.argv[sys.argv.index('--preview-cards') + 1])
        out.mkdir(parents=True, exist_ok=True)
        for kind, name, dur, extra in TIMELINE:
            if kind == 'card':
                frames = list(card_frames(name, dur))
                frames[len(frames) * 2 // 3].save(out / f'card-{name}.png')
        print('cards in', out)
    elif '--preview-music' in sys.argv:
        out = Path(sys.argv[sys.argv.index('--preview-music') + 1])
        _, total = starts()
        write_wav(out, music(total) * .8)
        print(out)
    else:
        main()
