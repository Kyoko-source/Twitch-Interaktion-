"""After Play 5.2.8: develop the anomaly album photos.

Input: the raw in-game renders from
  Godot --path games/kinderparadies --resolution 1200x900 -- --render-qa --album-photos-qa --capture-dir=<dir>
Output: games/kinderparadies/assets/album-v528/<anomaly id>.jpg, 640x480.

The renders are true to the game and therefore very dark. A polaroid look
lifts the shadows, warms the highlights a touch, adds a soft vignette and a
little grain, so the scene reads at thumbnail size without looking edited.

Run: python tools/develop-after-play-album-photos-v528.py <capture dir>
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/album-v528'
SIZE = (640, 480)


def develop(path: Path) -> Image.Image:
    image = Image.open(path).convert('RGB').resize(SIZE, Image.LANCZOS)
    rgb = np.asarray(image).astype(np.float32) / 255
    # Lift the shadows (gamma) and set the white point from the bright end.
    white = max(np.percentile(rgb, 99.4), .35)
    rgb = np.clip(rgb / white, 0, 1) ** .62
    # Faded instant film: raised blacks, warm highlights, cool shadows.
    luma = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * .9 + .045
    rgb += (luma - .5) * np.array([.05, .015, -.05])
    h, w = rgb.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    r = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    rgb *= (1 - .32 * np.clip(r - .55, 0, 1) ** 1.4)[..., None]
    rgb += np.random.default_rng(528).normal(0, .012, rgb.shape)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))


source = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
count = 0
for render in sorted(source.glob('*.png')):
    develop(render).save(OUT / (render.stem + '.jpg'), quality=84, optimize=True)
    count += 1
print('Developed', count, 'album photos into', OUT)
