"""Paint corpse-grey visitor faces from the credited scan texture (needs PIL).
Run before model-after-play-visitors-v421.py.
"""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'visitors-v421'
OUT.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------- textures
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def fractal(rng, size, base, octaves=5):
    total = np.zeros((size, size), np.float32); amp = 1.
    for o in range(octaves):
        cells = base * 2 ** o
        layer = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        total += np.asarray(layer, np.float32) / 255 * amp; amp *= .55
    total -= total.min(); return total / total.max()


def paint_face(kind):
    """Corpse-grey versions of the credited scan texture, one per visitor."""
    size = 1536; rng = np.random.default_rng(sum(map(ord, kind)))
    src = Image.open(ASSETS / 'detail-v310/clown-skin-albedo.png').convert('RGB').resize((size, size), Image.LANCZOS)
    base = np.asarray(src, np.float32) / 255
    luma = base.mean(axis=2)
    soft = np.asarray(Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(20)), np.float32) / 255
    relief = ((luma / soft.clip(.05)) ** 2.2).clip(.3, 1.6)[..., None]
    axis = (np.arange(size, dtype=np.float32) + .5) / size
    u, v = np.meshgrid(axis, axis)
    n1, n2 = fractal(rng, size, 5), fractal(rng, size, 30)
    tone = {'split': (.47, .45, .40), 'hooded': (.62, .60, .55), 'ragged': (.44, .42, .36), 'seated': (.36, .29, .21)}[kind]
    col = np.array(tone, np.float32) * relief * (.82 + .3 * n1[..., None])
    # Bruised, blood-starved patches and dark veins.
    veins = (1 - smooth(0, .010, np.abs(fractal(rng, size, 14, 4) - .5))) * smooth(.3, .7, n1)
    col = col * (1 - veins[..., None] * .35) + np.array([.16, .17, .22]) * veins[..., None] * .35
    bruise = smooth(.62, .85, fractal(rng, size, 4))
    col = col * (1 - bruise[..., None] * .45) + np.array([.22, .14, .17]) * bruise[..., None] * .45
    # Sunken dark eye sockets on every variant.
    for cu in (.424, .579):
        r = np.sqrt(((u - cu) / .07) ** 2 + ((v - .312) / .058) ** 2)
        sock = 1 - smooth(.45, 1.15, r + (n1 - .5) * .3)
        col = col * (1 - sock[..., None] * .82) + np.array([.04, .03, .03]) * sock[..., None] * .82
    blood = np.zeros_like(u)
    if kind == 'split':
        edge = 1 - smooth(.004, .05, np.abs(u - .5) - .018 * np.sin((v - .17) / .45 * math.pi).clip(0))
        blood = np.maximum(blood, edge * smooth(.14, .2, v) * (1 - smooth(.62, .7, v)))
        for x in rng.uniform(.47, .53, 18):
            lane = np.abs(u - x - np.sin(v * 40) * .003)
            blood = np.maximum(blood, (1 - smooth(.001, .004, lane)) * smooth(.4, .5, v) * (1 - smooth(.6, .78 + rng.random() * .1, v)))
    if kind == 'ragged':
        mouth = 1 - smooth(.6, 1.2, np.sqrt(((u - .5) / .09) ** 2 + ((v - .53) / .13) ** 2))
        blood = np.maximum(blood, mouth * .8)
        for cu in (.424, .579):
            for k in range(7):
                x = cu - .04 + k * .0135
                stitch = (1 - smooth(.0015, .004, np.abs(u - x))) * (1 - smooth(.0, .03, np.abs(v - .314)))
                col = col * (1 - stitch[..., None]) + np.array([.02, .015, .01]) * stitch[..., None]
    if kind == 'hooded':
        grin = 1 - smooth(.004, .03, np.abs(v - (.47 - .09 * ((u - .5) / .2) ** 2)) - .006)
        blood = np.maximum(blood, grin * (np.abs(u - .5) < .21) * .9)
    if kind == 'seated':
        dry = smooth(.4, .8, n2)
        col = col * (1 - dry[..., None] * .3) + np.array([.18, .12, .07]) * dry[..., None] * .3
        mouth = 1 - smooth(.6, 1.2, np.sqrt(((u - .5) / .08) ** 2 + ((v - .52) / .09) ** 2))
        blood = np.maximum(blood, mouth * .5)
    col = col * (1 - blood[..., None] * .85) + np.array([.12, .008, .012]) * (.6 + .6 * n2[..., None]) * blood[..., None] * .85
    path = OUT / f'{kind}-face.png'
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(path, optimize=True)
    return path



for kind in ('split', 'hooded', 'ragged', 'seated'):
    print(paint_face(kind))
