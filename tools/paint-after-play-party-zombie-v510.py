"""Face paint and dress fabric for the rigged party zombies, After Play 5.1.0.

party-face.png: the scanned visitor complexion turned into the reference look:
chalk-pale cracked skin, deep black eye sockets with running smudges, an
ear-to-ear smear of red around the grin and sick red cheeks.
party-dress-a.png / party-dress-b.png: faded party fabric (dots or stripes),
dirt rising from the hem, blood splashes and torn darker seams.
Run: python tools/paint-after-play-party-zombie-v510.py
Output: games/kinderparadies/assets/zombies-v510/
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
OUT = A / 'zombies-v510'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(510)


def blur(mask, radius):
    return np.asarray(Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))).astype(float) / 255


def face():
    img = np.asarray(Image.open(A / 'visitors-v421/ragged-face.png').convert('RGB')).astype(float) / 255
    h, w = img.shape[:2]; yy, xx = np.mgrid[0:h, 0:w]; u = xx / w; v = yy / h
    lum = img @ np.array([.299, .587, .114])
    pale = np.stack([lum * 1.05 + .42, lum * 1.03 + .41, lum * 1.08 + .42], -1)
    img = np.clip(img * .25 + pale * .75, 0, 1)
    # Grime and fine cracks.
    noise = blur(rng.random((h, w)), 6)
    img *= (.82 + .25 * noise)[..., None]
    for _ in range(160):
        x, y = rng.integers(0, w), rng.integers(0, h); a = rng.uniform(0, np.pi); n = rng.integers(10, 60)
        for t in range(n):
            ix, iy = int(x + np.cos(a) * t) % w, int(y + np.sin(a) * t) % h; img[iy, ix] *= .6
    sockets = np.zeros((h, w)); drips = np.zeros((h, w))
    for cu in (.424, .579):
        sockets += np.exp(-(((u - cu) / .055) ** 2 + ((v - .312) / .04) ** 2) * 1.6)
        for k in range(5):
            x0 = cu + rng.uniform(-.03, .03); length = rng.uniform(.04, .11)
            drips += np.exp(-((u - x0) / .004) ** 2) * ((v > .33) & (v < .33 + length)) * (1 - (v - .33) / length)
    dark = np.clip(sockets * 1.2 + blur(drips, 2) * .8, 0, 1)[..., None]
    img = img * (1 - dark) + np.array([.03, .02, .025]) * dark
    # The red smear around the grin and fevered cheeks.
    x = (u - .5) / .205
    grin_line = .505 + .02 * (1 - x * x) - .085 * x * x
    smear = np.exp(-((v - grin_line + .015) / .035) ** 2) * (np.abs(x) < 1.08)
    smear = blur(smear * (.7 + .5 * rng.random((h, w))), 5)
    cheeks = np.exp(-(((u - .355) / .05) ** 2 + ((v - .43) / .04) ** 2)) + np.exp(-(((u - .645) / .05) ** 2 + ((v - .43) / .04) ** 2))
    red = np.clip(smear * .85 + cheeks * .45, 0, 1)[..., None]
    img = img * (1 - red) + np.array([.5, .04, .07]) * red
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(OUT / 'party-face.png')


def dress(name, base, accent, stripes):
    s = 1024; yy, xx = np.mgrid[0:s, 0:s]; u = xx / s; v = yy / s
    img = np.ones((s, s, 3)) * np.array(base)
    if stripes:
        band = (np.sin(u * np.pi * 2 * 18) > .55)[..., None]
        img = np.where(band, img * .6 + np.array(accent) * .4, img)
    else:
        for cy in range(0, s, 64):
            for cx in range(0, s, 64):
                ox = cx + (32 if (cy // 64) % 2 else 0)
                m = (xx - ox) ** 2 + (yy - cy) ** 2 < 13 ** 2
                img[m] = img[m] * .45 + np.array(accent) * .55
    weave = blur(rng.random((s, s)), 1.2)
    img *= (.85 + .2 * weave)[..., None]
    dirt = np.clip((v - .45) / .55, 0, 1) ** 1.6 * (.6 + .4 * blur(rng.random((s, s)), 18))
    img = img * (1 - dirt[..., None] * .75) + np.array([.12, .09, .06]) * dirt[..., None] * .75
    splash = np.zeros((s, s))
    for _ in range(26):
        cx, cy = rng.integers(0, s), rng.integers(int(s * .3), s); r = rng.integers(8, 40)
        splash += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r)))
        for k in range(4):
            dx = rng.integers(-60, 60); dy = rng.integers(-60, 60); rr = rng.integers(3, 9)
            splash += np.exp(-(((xx - cx - dx) ** 2 + (yy - cy - dy) ** 2) / (rr * rr)))
    blood = np.clip(splash, 0, 1)[..., None] * .8
    img = img * (1 - blood) + np.array([.28, .02, .03]) * blood
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(OUT / f'{name}.png')


face()
dress('party-dress-a', (.5, .3, .34), (.78, .66, .6), False)
dress('party-dress-b', (.27, .36, .35), (.6, .62, .5), True)
print('painted into', OUT)
