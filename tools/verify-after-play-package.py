"""Check the public release boundary: no author tooling, spoilers or prompts."""
import hashlib
import json
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'games/kinderparadies/build'
manifest = json.loads((BUILD / 'release.json').read_text('utf-8-sig'))
version = manifest['version']
assert manifest['packaging_revision'] == 2
notices = {'Lizenzhinweise.txt', 'Kenney.txt', 'Oswald-OFL.txt', 'BodoniModa-OFL.txt',
           'Caveat-OFL.txt', 'Lee-Perry-Smith.txt', 'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'Quellen.txt'}
runtime = {'index.html', 'index.js', 'index.wasm', 'index.pck', 'index.audio.worklet.js',
           'index.audio.position.worklet.js', 'index.png'}
for platform, key in [('windows', 'windows_sha256'), ('web', 'web_zip_sha256')]:
    archive = BUILD / f'after-play-{platform}-v{version}.zip'
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest[key]
    assert archive.read_bytes() == (ROOT / 'frontend/public/downloads' / archive.name).read_bytes()
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        names = {n.replace('\\', '/') for n in z.namelist() if not n.endswith('/')}
        top = {'AfterPlay.exe', 'STARTEN.txt'} if platform == 'windows' else runtime
        assert names == top | {'Lizenzen/' + n for n in notices}, names
        assert all('..' not in Path(n).parts and not n.startswith('/') for n in names)
        credits = z.read('Lizenzen/Lizenzhinweise.txt').decode('utf-8')
        assert all(name in credits for name in ['Lee Perry-Smith', 'Joseph SARDIN', 'Axeline T.', 'A New Room', 'Poly Haven', 'turbulentmicrogenres466'])
        assert z.read('Lizenzen/Lee-Perry-Smith.txt') == (ROOT / 'games/kinderparadies/assets/props/Head-Attribution.txt').read_bytes()
        assert z.read('Lizenzen/Godot-COPYRIGHT.txt') == (BUILD / 'package/Godot-COPYRIGHT.txt').read_bytes()
        if platform == 'windows':
            assert z.read('AfterPlay.exe') == (BUILD / 'windows/AfterPlay.exe').read_bytes()
            guide = z.read('STARTEN.txt').decode('utf-8')
            assert all(spoiler not in guide for spoiler in ['0712', '6428', 'clock_reverse', 'tube_watcher'])
        else:
            html = z.read('index.html').decode('utf-8')
            assert '<html lang="de">' in html and 'aria-label="After Play 3D-Spiel"' in html
            assert len(names) < 1000
            assert sum(i.file_size for i in z.infolist()) < 500 * 1024**2
            assert max(i.file_size for i in z.infolist()) < 200 * 1024**2
            pck = z.read('index.pck')
            for required in [b'assets/intro/chef.mp3', b'assets/story/catalog.json', b'assets/presentation-v250/memories.json', b'assets/cinema-film/happyland-advert.ogv', b'assets/cinema-film/happyland-advert.ogg']:
                assert required in pck, required
            private_files = [str(p.relative_to(ROOT / 'games/kinderparadies')).replace('\\', '/').encode()
                             for p in (ROOT / 'games/kinderparadies/assets').rglob('*.json')
                             if p.name not in ['catalog.json', 'memories.json']]
            assert pck[:4] == b'GDPC' and struct.unpack_from('<I', pck, 4)[0] == 3
            directory = struct.unpack_from('<Q', pck, 32)[0]
            count = struct.unpack_from('<I', pck, directory)[0]
            cursor = directory + 4
            packed_names = set()
            for _ in range(count):
                length = struct.unpack_from('<I', pck, cursor)[0]
                cursor += 4
                packed_names.add(pck[cursor:cursor + length].rstrip(b'\0'))
                cursor += length + 36
            for required in [b'assets/life-v2110/photostrip-v2.png', b'assets/life-v2110/compressor.wav', b'assets/life-v2110/water-film.gdshader']:
                assert any(required in name for name in packed_names), required
            for private in private_files + [b'ANOMALIEN.md', b'ITCH-SEITE.md', b'scripts/native_render_qa.gd', b'scripts/validation.gd', b'scripts/finale_validation.gd', b'scripts/film_validation.gd', b'scripts/life_validation.gd', b'assets/life-v2110/image-generation-provenance.json', b'art-direction/media_capture.gd', b'art-direction/media_capture.tscn']:
                assert not any(private in name for name in packed_names), private
            assert hashlib.sha256(pck).hexdigest() == manifest['web_pck_sha256']
            public = ROOT / 'frontend/public/standalone/kinderparadies'
            assert {str(p.relative_to(public)).replace('\\', '/') for p in public.rglob('*') if p.is_file()} == names
    print(f'{platform}: exact public file list, CRC, checksums, licenses and privacy boundary PASS')
