"""Cubicle graffiti variants for the washroom, After Play 4.15.0.

Every partition and door gets its own doodles instead of one shared sheet:
hearts, smileys, tally marks, spirals, stick figures plus stars, suns,
flowers, houses, arrows, noughts-and-crosses and crowns, each variant with
its own mix, density and favourite colours. No words: the triplanar mapping
mirrors them on half the faces.
Run: python tools/make-after-play-cubicle-graffiti-v4140.py
Output: games/kinderparadies/assets/annex-v4130/cubicle-graffiti-1..5.png
"""
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/annex-v4130'
COLOURS = [(30, 30, 40), (40, 60, 150), (160, 30, 40), (30, 110, 60), (120, 60, 140), (200, 110, 30)]
# seed, doodle count, weights for the 12 motifs, favoured colours, scratches
VARIANTS = [
    (41411, 26, [3, 3, 2, 1, 2, 2, 0, 2, 0, 1, 0, 1], [2, 4, 1], 90),
    (41412, 18, [1, 1, 3, 2, 2, 0, 2, 0, 2, 2, 1, 0], [0, 3, 1], 160),
    (41413, 30, [2, 4, 1, 1, 1, 3, 1, 3, 0, 0, 2, 2], [5, 2, 4], 70),
    (41414, 14, [1, 1, 4, 3, 3, 0, 0, 1, 1, 3, 0, 0], [0, 1, 2], 200),
    (41415, 22, [4, 2, 1, 2, 1, 1, 3, 1, 2, 1, 2, 3], [4, 3, 5], 110),
]


def doodle(d, rs, kind, x, y, s, c):
    w = 4
    if kind == 0:  # heart
        d.ellipse([x, y, x + s, y + s], outline=c, width=w); d.ellipse([x + s, y, x + 2 * s, y + s], outline=c, width=w)
        d.line([x + 2, y + s * .7, x + s, y + 2 * s, x + 2 * s - 2, y + s * .7], fill=c, width=w)
    elif kind == 1:  # smiley
        d.ellipse([x, y, x + 2 * s, y + 2 * s], outline=c, width=w); d.ellipse([x + s * .5, y + s * .6, x + s * .7, y + s * .8], fill=c)
        d.ellipse([x + s * 1.3, y + s * .6, x + s * 1.5, y + s * .8], fill=c)
        if rs.random() < .3: d.arc([x + s * .4, y + s * 1.2, x + s * 1.6, y + s * 2.0], 200, 340, fill=c, width=w)
        else: d.arc([x + s * .4, y + s * .6, x + s * 1.6, y + s * 1.6], 20, 160, fill=c, width=w)
    elif kind == 2:  # tally marks
        for g in range(rs.integers(1, 6)):
            gx = x + g * 60
            for k in range(4): d.line([gx + k * 10, y, gx + k * 10 + 2, y + 45], fill=c, width=3)
            d.line([gx - 5, y + 30, gx + 40, y + 12], fill=c, width=3)
    elif kind == 3:  # spiral
        turns = rs.uniform(9, 18)
        pts = [(x + s + math.cos(t) * t * 3, y + s + math.sin(t) * t * 3) for t in np.linspace(0, turns, 90)]; d.line(pts, fill=c, width=3)
    elif kind == 4:  # stick figure
        d.ellipse([x + 10, y, x + 30, y + 20], outline=c, width=3); d.line([x + 20, y + 20, x + 20, y + 55], fill=c, width=3)
        d.line([x, y + 32, x + 40, y + 32], fill=c, width=3); d.line([x + 20, y + 55, x + 5, y + 80], fill=c, width=3); d.line([x + 20, y + 55, x + 35, y + 80], fill=c, width=3)
    elif kind == 5:  # five-point star
        pts = [(x + s + math.cos(-math.pi / 2 + i * 4 * math.pi / 5) * s, y + s + math.sin(-math.pi / 2 + i * 4 * math.pi / 5) * s) for i in range(6)]
        d.line(pts, fill=c, width=w)
    elif kind == 6:  # sun
        d.ellipse([x + s * .5, y + s * .5, x + s * 1.5, y + s * 1.5], outline=c, width=w)
        for i in range(10):
            a = i * math.pi / 5
            d.line([x + s + math.cos(a) * s * .65, y + s + math.sin(a) * s * .65, x + s + math.cos(a) * s * 1.1, y + s + math.sin(a) * s * 1.1], fill=c, width=3)
    elif kind == 7:  # flower
        for i in range(5):
            a = i * 2 * math.pi / 5; px, py = x + s + math.cos(a) * s * .45, y + s * .8 + math.sin(a) * s * .45
            d.ellipse([px - s * .3, py - s * .3, px + s * .3, py + s * .3], outline=c, width=3)
        d.line([x + s, y + s * 1.3, x + s, y + s * 2.6], fill=(30, 110, 60), width=3)
    elif kind == 8:  # house
        d.rectangle([x, y + s, x + 2 * s, y + 2.4 * s], outline=c, width=w); d.line([x - 6, y + s, x + s, y, x + 2 * s + 6, y + s], fill=c, width=w)
        d.rectangle([x + s * .75, y + 1.6 * s, x + s * 1.25, y + 2.4 * s], outline=c, width=3)
    elif kind == 9:  # arrow
        a = rs.uniform(0, 2 * math.pi); ln = s * 3; ex, ey = x + math.cos(a) * ln, y + math.sin(a) * ln
        d.line([x, y, ex, ey], fill=c, width=w)
        for side in (-1, 1):
            b = a + math.pi + side * .5; d.line([ex, ey, ex + math.cos(b) * s * .6, ey + math.sin(b) * s * .6], fill=c, width=w)
    elif kind == 10:  # noughts and crosses
        g = s * .8
        for i in (1, 2):
            d.line([x + i * g, y, x + i * g + 3, y + 3 * g], fill=c, width=3); d.line([x, y + i * g, x + 3 * g, y + i * g - 2], fill=c, width=3)
        for cx in range(3):
            for cy in range(3):
                r = rs.random(); ox, oy = x + cx * g + g * .2, y + cy * g + g * .2
                if r < .33: d.line([ox, oy, ox + g * .6, oy + g * .6], fill=c, width=3); d.line([ox + g * .6, oy, ox, oy + g * .6], fill=c, width=3)
                elif r < .66: d.ellipse([ox, oy, ox + g * .6, oy + g * .6], outline=c, width=3)
    else:  # crown
        d.line([x, y + s * 1.4, x, y + s * .3, x + s * .5, y + s * .9, x + s, y, x + s * 1.5, y + s * .9, x + 2 * s, y + s * .3, x + 2 * s, y + s * 1.4, x, y + s * 1.4], fill=c, width=w)


def graffiti(index, seed, count, weights, favourites, scratches):
    from PIL import Image, ImageDraw
    rs = np.random.default_rng(seed); size = 1024
    base = (np.ones((size, size, 3)) * np.array([.70, .78, .70]) * (.93 + .07 * rs.random((size, size, 1))) * 255).astype(np.uint8)
    im = Image.fromarray(base); d = ImageDraw.Draw(im)
    p = np.array(weights, dtype=float); p /= p.sum()
    for _ in range(count):
        x, y = rs.integers(60, size - 180), rs.integers(60, size - 180)
        c = COLOURS[favourites[rs.integers(0, len(favourites))]] if rs.random() < .7 else COLOURS[rs.integers(0, len(COLOURS))]
        doodle(d, rs, int(rs.choice(len(weights), p=p)), x, y, int(rs.integers(22, 58)), c)
    arr = np.asarray(im).astype(np.float32) / 255
    for _ in range(scratches):  # pale key scratches
        x0, y0 = rs.random(2) * size; a = rs.uniform(0, math.pi); ln = rs.integers(20, 140)
        for t in range(ln):
            ix, iy = int(x0 + math.cos(a) * t) % size, int(y0 + math.sin(a) * t) % size; arr[iy, ix] = np.minimum(1, arr[iy, ix] * 1.18)
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(OUT / f'cubicle-graffiti-{index}.png')


for i, v in enumerate(VARIANTS, 1):
    graffiti(i, *v)
