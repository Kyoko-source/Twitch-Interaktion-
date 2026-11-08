"""Paint the chained archive corpse's face: leathery, rotting, mould-flecked.
Run before model-after-play-archive-corpse-v431.py (needs PIL + numpy).
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'finale'


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def fractal(rng, size, base, octaves=5):
    total = np.zeros((size, size), np.float32); amp = 1.
    for o in range(octaves):
        cells = base * 2 ** o
        layer = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        total += np.asarray(layer, np.float32) / 255 * amp; amp *= .55
    total -= total.min(); return total / total.max()


size = 1536; rng = np.random.default_rng(431)
src = Image.open(ASSETS / 'detail-v310/clown-skin-albedo.png').convert('RGB').resize((size, size), Image.LANCZOS)
luma = np.asarray(src, np.float32).mean(axis=2) / 255
soft = np.asarray(Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18)), np.float32) / 255
relief = ((luma / soft.clip(.05)) ** 2.6).clip(.25, 1.7)[..., None]
axis = (np.arange(size, dtype=np.float32) + .5) / size
u, v = np.meshgrid(axis, axis)
n1, n2, n3 = fractal(rng, size, 5), fractal(rng, size, 28), fractal(rng, size, 70, 3)
# Dried, tanned leather in browns and grey-greens.
col = np.array([.30, .22, .15], np.float32) * relief * (.7 + .5 * n1[..., None])
grey = smooth(.45, .75, fractal(rng, size, 7))
col = col * (1 - grey[..., None] * .5) + np.array([.24, .23, .19]) * relief * grey[..., None] * .5
# Black-green putrefaction pooling in the hollows of eyes, nose and mouth.
rot = np.zeros_like(u)
for cu in (.424, .579):
    rot = np.maximum(rot, 1 - smooth(.3, 1.35, np.sqrt(((u - cu) / .07) ** 2 + ((v - .315) / .065) ** 2) + (n1 - .5) * .5))
rot = np.maximum(rot, 1 - smooth(.3, 1.3, np.sqrt(((u - .5) / .045) ** 2 + ((v - .41) / .06) ** 2) + (n1 - .5) * .5))
rot = np.maximum(rot, 1 - smooth(.3, 1.3, np.sqrt(((u - .5) / .10) ** 2 + ((v - .53) / .075) ** 2) + (n1 - .5) * .5))
col = col * (1 - rot[..., None] * .85) + np.array([.035, .03, .02]) * rot[..., None] * .85
# Split, cracked skin: thin dark fissures.
crack = (1 - smooth(0, .006, np.abs(fractal(rng, size, 12, 4) - .5))) * smooth(.4, .7, n2)
col *= 1 - crack[..., None] * .7
# Pale furred mould colonies and wet dark seepage.
mould = smooth(.68, .82, fractal(rng, size, 9)) * (.5 + .5 * n3)
col = col * (1 - mould[..., None] * .7) + np.array([.55, .57, .47]) * mould[..., None] * .7
seep = smooth(.62, .78, fractal(rng, size, 5)) * (v > .45)
col = col * (1 - seep[..., None] * .5) + np.array([.08, .05, .02]) * seep[..., None] * .5
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(OUT / 'corpse-face.png', optimize=True)
print(OUT / 'corpse-face.png')
