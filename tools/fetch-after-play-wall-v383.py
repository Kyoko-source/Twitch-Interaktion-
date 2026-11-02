"""Fetch a CC0 photographed plaster/brick material, verifying provider hashes.

Fab's original listing is a style reference only; its files were not acquired.
Godot imports the identical source maps at separate desktop/web resolutions.
"""
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/wall-v383'
SOURCE = 'https://polyhaven.com/a/damaged_plaster'
HEADERS = {'User-Agent': 'AfterPlayGameDevelopment/3.8.3'}

def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=45) as r:
        return r.read()

def main():
    metadata = json.loads(get('https://api.polyhaven.com/files/damaged_plaster'))
    def fetch(job):
        channel, resolution, filename = job
        spec = metadata[channel][resolution]['jpg']
        raw = get(spec['url'])
        assert len(raw) == spec['size'] and hashlib.md5(raw).hexdigest() == spec['md5'], filename
        for variant in ['desktop', 'web']:
            folder = OUT / variant
            folder.mkdir(parents=True, exist_ok=True)
            (folder / filename).write_bytes(raw)
        print('Verified', filename, len(raw), flush=True)
        return {'name': filename, 'url': spec['url'], 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    with ThreadPoolExecutor(max_workers=3) as pool:
        files = list(pool.map(fetch, [('Diffuse', '2k', 'albedo.jpg'), ('nor_gl', '2k', 'normal.jpg'), ('Rough', '1k', 'roughness.jpg')]))
    manifest = {
        'source': SOURCE, 'author': 'Amal Kumar / Poly Haven', 'license': 'CC0-1.0', 'license_url': 'https://polyhaven.com/license',
        'style_reference_only': 'https://www.fab.com/listings/62579cbe-2670-4050-bd3b-4caf8a376a59',
        'files': files
    }
    (OUT / 'wall-provenance.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')

if __name__ == '__main__':
    main()
