"""Verified CC0 Poly Haven models for the Nightwatch control room, After Play 4.16.0.

CRT televisions for the monitor wall, a portable generator, a leather binder as
the report book, desk clutter, a radio, ceiling fluorescents, a rack and a bin.
Run: python tools/fetch-after-play-nightwatch-v4160.py
"""
import importlib.util, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
spec = importlib.util.spec_from_file_location('art', Path(__file__).with_name('fetch-nachtwache-art.py'))
art = importlib.util.module_from_spec(spec); spec.loader.exec_module(art)
MODELS = ['Television_01', 'portable_generator', 'binder_notebook', 'clipboard', 'office_notepads',
          'vintage_radio_transceiver', 'mounted_fluorescent_lights', 'worn_metal_rack', 'metal_trash_can',
          'retro_multimeter']
manifest = json.loads((A / 'polyhaven-provenance.json').read_text('utf-8'))
for name in MODELS:
    entry = art.fetch_asset(('model', name))
    manifest = [x for x in manifest if x['id'] != name] + [entry]
(A / 'polyhaven-provenance.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
