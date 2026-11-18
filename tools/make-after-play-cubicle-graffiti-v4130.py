"""Cubicle door graffiti for the washroom, After Play 4.13.0.

Pale green laminate with children's marker doodles: names, hearts, smileys,
tally marks, spirals, stick figures and pale key scratches.
Run: python tools/make-after-play-cubicle-graffiti-v4130.py
Output: games/kinderparadies/assets/annex-v4130/cubicle-graffiti.png
"""
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/annex-v4130'

def graffiti():
    from PIL import Image, ImageDraw, ImageFont
    rs = np.random.default_rng(41302); size = 1024
    base = (np.ones((size, size, 3)) * np.array([.70, .78, .70]) * (.93 + .07 * rs.random((size, size, 1))) * 255).astype(np.uint8)
    im = Image.fromarray(base); d = ImageDraw.Draw(im)
    font_path = ROOT / 'games/kinderparadies/assets/backstage-v270/Caveat.ttf'
    colours = [(30, 30, 40), (40, 60, 150), (160, 30, 40), (30, 110, 60), (120, 60, 140)]
    # No words: the triplanar mapping mirrors them on half the faces.
    words = []
    for word in words:
        f = ImageFont.truetype(str(font_path), int(rs.integers(40, 90)))
        x, y = rs.integers(30, size - 300), rs.integers(30, size - 100)
        layer = Image.new('RGBA', (400, 140), (0, 0, 0, 0)); ImageDraw.Draw(layer).text((10, 10), word, font=f, fill=(*colours[rs.integers(0, 5)], 200))
        layer = layer.rotate(rs.uniform(-20, 20), expand=True); im.paste(layer, (int(x), int(y)), layer)
    for _ in range(22):  # hearts, smileys, tally marks, spirals, stick figures
        x, y = rs.integers(60, size - 120), rs.integers(60, size - 120); c = colours[rs.integers(0, 5)]; kind = rs.integers(0, 5); s = rs.integers(25, 50)
        if kind == 0:
            d.ellipse([x, y, x + s, y + s], outline=c, width=4); d.ellipse([x + s, y, x + 2 * s, y + s], outline=c, width=4); d.line([x + 2, y + s * .7, x + s, y + 2 * s, x + 2 * s - 2, y + s * .7], fill=c, width=4)
        elif kind == 1:
            d.ellipse([x, y, x + 2 * s, y + 2 * s], outline=c, width=4); d.ellipse([x + s * .5, y + s * .6, x + s * .7, y + s * .8], fill=c); d.ellipse([x + s * 1.3, y + s * .6, x + s * 1.5, y + s * .8], fill=c); d.arc([x + s * .4, y + s * .6, x + s * 1.6, y + s * 1.6], 20, 160, fill=c, width=4)
        elif kind == 2:
            for g in range(rs.integers(2, 5)):
                gx = x + g * 60
                for k in range(4): d.line([gx + k * 10, y, gx + k * 10 + 2, y + 45], fill=c, width=3)
                d.line([gx - 5, y + 30, gx + 40, y + 12], fill=c, width=3)
        elif kind == 3:
            pts = [(x + s + math.cos(t) * t * 3, y + s + math.sin(t) * t * 3) for t in np.linspace(0, 14, 80)]; d.line(pts, fill=c, width=3)
        else:
            d.ellipse([x + 10, y, x + 30, y + 20], outline=c, width=3); d.line([x + 20, y + 20, x + 20, y + 55], fill=c, width=3)
            d.line([x, y + 32, x + 40, y + 32], fill=c, width=3); d.line([x + 20, y + 55, x + 5, y + 80], fill=c, width=3); d.line([x + 20, y + 55, x + 35, y + 80], fill=c, width=3)
    arr = np.asarray(im).astype(np.float32) / 255
    for _ in range(120):  # pale key scratches
        x0, y0 = rs.random(2) * size; a = rs.uniform(0, math.pi); ln = rs.integers(20, 120)
        for t in range(ln):
            ix, iy = int(x0 + math.cos(a) * t) % size, int(y0 + math.sin(a) * t) % size; arr[iy, ix] = np.minimum(1, arr[iy, ix] * 1.18)
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(OUT / 'cubicle-graffiti.png')


graffiti()
