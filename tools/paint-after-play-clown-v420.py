"""Repaint the credited clown skin as cracked greasepaint for the v4.2 clown.

The mask shapes match the facial cuts in model-after-play-clown-v420.py, which
imports MOUTH and EYES from this file's constants via the shared JSON output.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'clown-v420'
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 2048

# All coordinates use image UV: u right, v down.
LAYOUT = {
    'mouth': {'left': [.366, .412], 'right': [.640, .392], 'upper': .449, 'lower': .531},
    'eyes': [
        {'center': [.424, .312], 'radius': [.030, .0185], 'tilt': .30},
        {'center': [.579, .310], 'radius': [.030, .0185], 'tilt': -.30},
    ],
}


def fractal(rng, octaves=6, base=4, falloff=.55):
    total = np.zeros((SIZE, SIZE), np.float32)
    amplitude = 1.
    for octave in range(octaves):
        cells = base * 2 ** octave
        grid = (rng.random((cells, cells)) * 255).astype(np.uint8)
        layer = Image.fromarray(grid).resize((SIZE, SIZE), Image.BICUBIC)
        total += np.asarray(layer, np.float32) / 255 * amplitude
        amplitude *= falloff
    total -= total.min()
    return total / total.max()


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blur(mask, radius):
    image = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255


def cracks(rng):
    """Thin ridges of warped noise read as dried paint rather than tiles."""
    total = np.zeros((SIZE, SIZE), np.float32)
    for base, width, weight in [(10, .010, 1.), (24, .008, .7), (52, .007, .42)]:
        field = fractal(rng, 4, base, .5)
        total = np.maximum(total, (1 - smooth(.0, width, np.abs(field - .5))) * weight)
    return total


def mouth_edges(u):
    m = LAYOUT['mouth']
    left, right = m['left'], m['right']
    span = np.clip((u - left[0]) / (right[0] - left[0]), 0, 1)
    corner = left[1] + (right[1] - left[1]) * span
    arch = 1 - (span * 2 - 1) ** 2
    return corner + (m['upper'] - corner) * arch ** .62, corner + (m['lower'] - corner) * arch ** .72


def main():
    rng = np.random.default_rng(420)
    source = Image.open(ASSETS / 'detail-v310/clown-skin-albedo.png').convert('RGB')
    base = np.asarray(source.resize((SIZE, SIZE), Image.LANCZOS), np.float32) / 255
    axis = (np.arange(SIZE, dtype=np.float32) + .5) / SIZE
    u, v = np.meshgrid(axis, axis)
    noise, fine, grain = fractal(rng, 6, 5), fractal(rng, 5, 28), fractal(rng, 4, 90)
    wobble = (noise - .5) * .05

    luma = base.mean(axis=2)
    soft = np.asarray(Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26)), np.float32) / 255
    relief = ((luma / soft.clip(.05)) ** 2.4).clip(.28, 1.5)[..., None]

    # Dead grey skin everywhere, with the scan's pores retained.
    grey = base.mean(axis=2, keepdims=True)
    color = grey * np.array([.70, .63, .58], np.float32) + base * .10

    # Thick white paint with an uneven hairline and a chewed lower boundary.
    face = 1 - smooth(.84, 1.06, np.sqrt(((u - .5) / .235) ** 2 + ((v - .385) / .265) ** 2) + wobble * 1.5)
    paint = np.array([.80, .77, .69], np.float32) * relief
    dirt = smooth(.45, .78, noise)[..., None]
    paint = paint * (1 - dirt * .36) + np.array([.47, .41, .30], np.float32) * dirt * .36
    crack = cracks(rng)
    flaking = smooth(.60, .78, fine) * smooth(.48, .72, noise)
    coverage = face * (1 - flaking * .72)
    color = color * (1 - coverage[..., None]) + paint * coverage[..., None]
    color *= 1 - (crack * face * .56)[..., None]

    # Black sockets drawn upward through the brow and down the cheek as runs.
    soot = np.zeros_like(u)
    for eye in LAYOUT['eyes']:
        cu, cv = eye['center']
        dx, dy = u - cu, v - cv
        tilt = eye['tilt']
        rx = dx * np.cos(tilt) + dy * np.sin(tilt)
        ry = -dx * np.sin(tilt) + dy * np.cos(tilt)
        socket = 1 - smooth(.55, 1.22, np.sqrt((rx / .056) ** 2 + (ry / .049) ** 2) + wobble * 1.6)
        spike_up = (1 - smooth(.0, .012 + (cv - v).clip(0) * -.09 + .010, np.abs(dx))) * smooth(cv - .125, cv - .04, v) * (v < cv)
        soot = np.maximum(soot, np.maximum(socket, spike_up.clip(0, 1)))
        for offset, length in [(-.019, .118), (.016, .142)]:
            lane = u - cu - offset - np.sin(v * 60 + offset * 90) * .0025
            run = (1 - smooth(.0008, .0034, np.abs(lane))) * smooth(cv, cv + .05, v) * (1 - smooth(cv + length * .7, cv + length, v))
            soot = np.maximum(soot, run * .94)
    soot *= .72 + .28 * grain
    color = color * (1 - soot[..., None]) + np.array([.018, .014, .015], np.float32) * relief * soot[..., None]

    # Raw edge around the mouth, stretched into the cheeks.
    upper, lower = mouth_edges(u)
    left, right = LAYOUT['mouth']['left'][0], LAYOUT['mouth']['right'][0]
    inside_span = smooth(left - .055, left, u) * (1 - smooth(right, right + .055, u))
    distance = np.maximum(upper - v, v - lower)
    lip = (1 - smooth(.004, .034, distance + wobble * .34)) * inside_span
    raw = np.array([.27, .018, .025], np.float32) * (.55 + .65 * fine[..., None])
    color = color * (1 - lip[..., None]) + raw * lip[..., None]
    tear = (1 - smooth(.002, .009, distance)) * inside_span
    color = color * (1 - tear[..., None] * .9) + np.array([.055, .004, .007], np.float32) * tear[..., None] * .9

    # A rotten painted nose instead of a toy ball.
    nose = 1 - smooth(.62, 1.1, np.sqrt(((u - .502) / .031) ** 2 + ((v - .386) / .029) ** 2) + wobble)
    color = color * (1 - nose[..., None] * .92) + np.array([.20, .012, .018], np.float32) * (.7 + .5 * relief) * nose[..., None] * .92

    # Dried blood runs off the chin and from both corners.
    blood = np.zeros_like(u)
    for x in rng.uniform(.42, .59, 15):
        width = rng.uniform(.0009, .0034)
        start = float(mouth_edges(np.array([x]))[1][0])
        length = rng.uniform(.02, .085)
        lane = u - x - np.sin(v * rng.uniform(30, 60)) * .003
        run = (1 - smooth(width * .5, width * 1.7, np.abs(lane))) * smooth(start - .012, start + .005, v) * (1 - smooth(start + length * .72, start + length, v))
        blood = np.maximum(blood, run)
    chin = (1 - smooth(.5, 1.12, np.sqrt(((u - .505) / .118) ** 2 + ((v - .566) / .052) ** 2) + wobble * 3)) * .82
    blood = np.maximum(blood, chin * smooth(.38, .62, noise))
    color = color * (1 - blood[..., None] * .88) + np.array([.115, .006, .012], np.float32) * (.65 + fine[..., None] * .5) * blood[..., None] * .88

    image = Image.fromarray((np.clip(color, 0, 1) ** (1 / 1.04) * 255).astype(np.uint8))
    image.save(OUT / 'clown-skin-albedo.png', optimize=True)
    (OUT / 'face-layout.json').write_text(json.dumps(LAYOUT, indent=1), encoding='utf-8')
    print('painted', OUT / 'clown-skin-albedo.png')


if __name__ == '__main__':
    main()
