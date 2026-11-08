"""Paint the two back-seat children's faces from the credited scan texture.
Run before model-after-play-backseat-children-v430.py (needs PIL + numpy).
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'drive-v430'
OUT.mkdir(parents=True, exist_ok=True)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def fractal(rng, size, base, octaves=5):
    total = np.zeros((size, size), np.float32); amp = 1.
    for o in range(octaves):
        cells = base * 2 ** o
        layer = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        total += np.asarray(layer, np.float32) / 255 * amp; amp *= .55
    total -= total.min(); return total / total.max()


def paint(kind):
    size = 1536; rng = np.random.default_rng(sum(map(ord, kind)) + 430)
    src = Image.open(ASSETS / 'detail-v310/clown-skin-albedo.png').convert('RGB').resize((size, size), Image.LANCZOS)
    base = np.asarray(src, np.float32) / 255; luma = base.mean(axis=2)
    soft = np.asarray(Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26)), np.float32) / 255
    # Children's skin: far less adult relief than the visitors, but grey-blue dead.
    relief = ((luma / soft.clip(.05)) ** 1.1).clip(.6, 1.3)[..., None]
    axis = (np.arange(size, dtype=np.float32) + .5) / size
    u, v = np.meshgrid(axis, axis)
    n1, n2 = fractal(rng, size, 5), fractal(rng, size, 30)
    tone = {'girl': (.66, .66, .66), 'boy': (.58, .58, .58)}[kind]
    col = np.array(tone, np.float32) * relief * (.86 + .22 * n1[..., None])
    col = col * np.array([.92, .97, 1.04])
    veins = (1 - smooth(0, .008, np.abs(fractal(rng, size, 16, 4) - .5))) * smooth(.35, .75, n1)
    col = col * (1 - veins[..., None] * .4) + np.array([.18, .22, .32]) * veins[..., None] * .4
    bruise = smooth(.6, .85, fractal(rng, size, 4))
    col = col * (1 - bruise[..., None] * .4) + np.array([.25, .17, .24]) * bruise[..., None] * .4
    # Deep black-purple rings around the eyes.
    for cu in (.424, .579):
        r = np.sqrt(((u - cu) / .052) ** 2 + ((v - .318) / .05) ** 2)
        sock = (1 - smooth(.2, 1.5, r + (n1 - .5) * .6)) * (.55 + .45 * n2)
        col = col * (1 - sock[..., None] * .8) + np.array([.10, .05, .08]) * sock[..., None] * .8
    blood = np.zeros_like(u); black = np.zeros_like(u)
    for cu in (.424, .579):
        # Black tears run from each eye down the cheeks.
        for k in range(3):
            x = cu + rng.uniform(-.018, .018)
            lane = np.abs(u - x - np.sin(v * 31 + k) * .004)
            run = (1 - smooth(.0015, .006, lane)) * smooth(.32, .36, v) * (1 - smooth(.5, .62 + rng.random() * .12, v))
            if kind == 'girl': black = np.maximum(black, run)
            else: blood = np.maximum(blood, run)
    if kind == 'girl':
        mouth = 1 - smooth(.55, 1.25, np.sqrt(((u - .5) / .10) ** 2 + ((v - .55) / .15) ** 2))
        blood = np.maximum(blood, mouth * .9)
        for x in rng.uniform(.45, .55, 14):
            lane = np.abs(u - x - np.sin(v * 37) * .003)
            blood = np.maximum(blood, (1 - smooth(.001, .005, lane)) * smooth(.55, .6, v) * (1 - smooth(.7, .82 + rng.random() * .1, v)))
    else:
        mouth = 1 - smooth(.6, 1.2, np.sqrt(((u - .5) / .07) ** 2 + ((v - .52) / .06) ** 2))
        blood = np.maximum(blood, mouth * .55)
        head = smooth(.62, .75, fractal(rng, size, 6)) * (v < .25)
        blood = np.maximum(blood, head * .8)
    col = col * (1 - black[..., None] * .9) + np.array([.02, .015, .02]) * black[..., None] * .9
    col = col * (1 - blood[..., None] * .85) + np.array([.14, .006, .01]) * (.6 + .6 * n2[..., None]) * blood[..., None] * .85
    path = OUT / f'{kind}-face.png'
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(path, optimize=True)
    return path


for kind in ('girl', 'boy'):
    print(paint(kind))
