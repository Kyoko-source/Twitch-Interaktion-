"""Check the public release boundary: no author tooling, spoilers or prompts."""
import hashlib
import json
import os
import subprocess
import tempfile
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'games/kinderparadies/build'

def packed_paths(data, start=0):
    assert data[start:start + 4] == b'GDPC'
    directory = start + struct.unpack_from('<Q', data, start + 32)[0]
    count = struct.unpack_from('<I', data, directory)[0]
    cursor, names = directory + 4, set()
    for _ in range(count):
        length = struct.unpack_from('<I', data, cursor)[0]
        cursor += 4
        names.add(data[cursor:cursor + length].rstrip(b'\0'))
        cursor += length + 36
    return names

def verify_windows_icon(exe):
    # Inspect the real PE resources; a PNG in the PCK alone does not change
    # Explorer's executable icon. Godot embeds these six standard sizes.
    pe = struct.unpack_from('<I', exe, 60)[0]
    optional = pe + 24
    sections = optional + struct.unpack_from('<H', exe, pe + 20)[0]
    def offset(rva):
        for i in range(struct.unpack_from('<H', exe, pe + 6)[0]):
            size, base, raw_size, pointer = struct.unpack_from('<IIII', exe, sections + 40*i + 8)
            if base <= rva < base + max(size, raw_size):
                return pointer + rva - base
        raise AssertionError('PE resource RVA is outside sections')
    root = offset(struct.unpack_from('<I', exe, optional + 128)[0])
    def entries(at):
        count = sum(struct.unpack_from('<HH', exe, at + 12))
        return dict(struct.unpack_from('<II', exe, at + 16 + 8*i) for i in range(count))
    def child(at, key):
        return root + (entries(at)[key] & 0x7fffffff)
    def resource(kind, ident=None):
        at = child(root, kind)
        at = child(at, next(iter(entries(at))) if ident is None else ident)
        at = child(at, next(iter(entries(at))))
        rva, size = struct.unpack_from('<II', exe, at)
        return exe[offset(rva):offset(rva) + size]
    ico = (ROOT / 'games/kinderparadies/assets/branding-v386/after-play-icon.ico').read_bytes()
    originals = {}
    for i in range(struct.unpack_from('<H', ico, 4)[0]):
        size, start = struct.unpack_from('<II', ico, 14 + 16*i)
        originals[ico[6 + 16*i] or 256] = ico[start:start + size]
    group = resource(14)
    sizes = set()
    for i in range(struct.unpack_from('<H', group, 4)[0]):
        size = group[6 + 14*i] or 256
        ident = struct.unpack_from('<H', group, 18 + 14*i)[0]
        assert resource(3, ident) == originals[size], size
        sizes.add(size)
    assert sizes == {16, 32, 48, 64, 128, 256}, sizes

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
        sources = z.read('Lizenzen/Quellen.txt').decode('utf-8')
        assert 'Rolling Acid' in credits and 'Suno' in credits and 'https://suno.com/terms' in credits
        assert 'nichtkommerziell' in credits and 'Suno Free' in sources
        assert all(old not in credits + sources for old in ['Focus Fire', 'FFMirage', 'NoCopyrightSounds'])
        assert all(name in credits for name in ['Lee Perry-Smith', 'Joseph SARDIN', 'Axeline T.', 'A New Room', 'Poly Haven', 'turbulentmicrogenres466'])
        assert z.read('Lizenzen/Lee-Perry-Smith.txt') == (ROOT / 'games/kinderparadies/assets/props/Head-Attribution.txt').read_bytes()
        assert z.read('Lizenzen/Godot-COPYRIGHT.txt') == (BUILD / 'package/Godot-COPYRIGHT.txt').read_bytes()
        if platform == 'windows':
            assert z.read('AfterPlay.exe') == (BUILD / 'windows/AfterPlay.exe').read_bytes()
            executable = z.read('AfterPlay.exe')
            verify_windows_icon(executable)
            start = len(executable) - 12 - struct.unpack_from('<Q', executable, len(executable) - 12)[0]
            native_names = packed_paths(executable, start)
            for model in ['interaction-hand','torch-grip','phone-hand','clown','horse-mask','granny-head','passage-head','mascot-rabbit','desk-phone']:
                assert any(('assets/quality-v410/desktop/'+model+'.glb').encode() in name for name in native_names), model
            assert not any(b'quality-v410/' in name and b'provenance.json' in name for name in native_names)
            assert any(b'assets/party-v385/party.mp3' in name for name in native_names)
            assert not any(b'assets/party-v385/party-web.ogg' in name for name in native_names)
            assert any(b'assets/tactile-v400/interaction-hand.glb' in name for name in native_names)
            assert any(b'assets/encounter-v401/horse-final-scream.wav' in name for name in native_names)
            assert any(b'assets/player-v402/breathing.ogg' in name for name in native_names)
            assert any(b'assets/feedback-v403/granny-1.ogg' in name for name in native_names)
            for required in [b'assets/clown-v404/clown-hair-desktop.glb', b'assets/clown-v404/patched-costume-cap.glb', b'assets/clown-v404/patched-cap.gdshader']:
                assert any(required in name for name in native_names), required
            assert not any(b'assets/clown-v404/clown-hair-web.glb' in name for name in native_names)
            assert any(b'assets/encounter-v401/bloodshot.gdshader' in name for name in native_names)
            assert not any(b'assets/tactile-v400/interaction-hand-web.glb' in name for name in native_names)
            guide = z.read('STARTEN.txt').decode('utf-8')
            assert all(spoiler not in guide for spoiler in ['0712', '6428', 'clock_reverse', 'tube_watcher'])
        else:
            html = z.read('index.html').decode('utf-8')
            assert '<html lang="de">' in html and 'aria-label="After Play 3D-Spiel"' in html
            assert 'href="index.png"' in html
            assert len(names) < 1000
            assert sum(i.file_size for i in z.infolist()) < 500 * 1024**2
            assert max(i.file_size for i in z.infolist()) < 200 * 1024**2
            pck = z.read('index.pck')
            for required in [b'locales/ui_en.json', b'locales/story_en.json', b'locales/signs_en.json', b'locales/subtitles.json', b'scripts/language.gd', b'scripts/captions.gd', b'scripts/carved_timber.gd', b'assets/music-v371/fern-and-feather.mp3', b'assets/music-v371/music-box-chase.mp3', b'assets/intro/chef.mp3', b'assets/story/catalog.json', b'assets/presentation-v250/memories.json', b'assets/cinema-film/happyland-advert.ogv', b'assets/cinema-film/happyland-advert.ogg']:
                assert required in pck, required
            private_files = [str(p.relative_to(ROOT / 'games/kinderparadies')).replace('\\', '/').encode()
                             for p in (ROOT / 'games/kinderparadies/assets').rglob('*.json')
                             if p.name not in ['catalog.json', 'memories.json']]
            assert pck[:4] == b'GDPC' and struct.unpack_from('<I', pck, 4)[0] == 3
            packed_names = packed_paths(pck)
            for required in [b'scripts/quality_assets.gd',b'scripts/close_prop_craft.gd',b'scripts/creature_foley.gd',b'assets/quality-v410/guard-cloth.gdshader',b'assets/quality-v410/ceramic.gdshader',b'assets/quality-v410/audio/horse-4.ogg',b'assets/quality-v410/audio/granny-4.ogg',b'assets/quality-v410/audio/step-carpet-7.ogg']:
                assert any(required in name for name in packed_names), required
            assert not any(b'assets/quality-v410/desktop/' in name or b'scripts/quality_validation.gd' in name for name in packed_names)
            for required in [b'assets/encounter-v401/horse-final-scream.wav', b'assets/encounter-v401/bloodshot.gdshader']:
                assert any(required in name for name in packed_names), required
            assert any(b'assets/player-v402/breathing.ogg' in name for name in packed_names)
            for required in [b'scripts/guard_foley.gd',b'assets/quality-v410/audio/paper-1.ogg',b'assets/quality-v410/audio/switch-1.ogg',b'assets/quality-v410/audio/horse-1.ogg',b'assets/quality-v410/audio/granny-1.ogg',b'assets/quality-v410/audio/door-1.ogg']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/guard_actions.gd', b'scripts/guard_presence.gd', b'scripts/paper_craft.gd', b'scripts/tactile_world.gd', b'assets/tactile-v400/interaction-hand-web.glb']:
                assert any(required in name for name in packed_names), required
            assert not any(b'assets/tactile-v400/interaction-hand.glb' in name for name in packed_names)
            assert not any(b'scripts/tactile_validation.gd' in name for name in packed_names)
            for private in [b'scripts/routes_validation.gd', b'scripts/feedback_validation.gd', b'art-direction/QA-v403.md']:
                assert not any(private in name for name in packed_names), private
            for required in [b'assets/reception-v2120/birthday-memories.png', b'assets/reception-v2120/cctv.gdshader', b'scripts/ball_pit_physics.gd', b'scripts/reception_watch.gd', b'assets/life-v2110/photostrip-v2.png', b'assets/life-v2110/compressor.wav', b'assets/life-v2110/water-film.gdshader', b'scripts/room_acoustics.gd', b'scripts/exterior_window.gd', b'scripts/graphics_upgrade.gd', b'assets/atmosphere-v320/arcade-1.ogg', b'assets/atmosphere-v320/projector-mechanism.ogg', b'scripts/main_entrance.gd', b'scripts/arrival_design.gd', b'scripts/venue_craft.gd', b'scripts/venue_signage.gd', b'scripts/wrapped_present.gd', b'assets/restoration-v350/happyland-signs.jpg', b'assets/restoration-v350/wrapping-paper.gdshader', b'assets/restoration-v350/sign_index.gd', b'assets/craft-v340/floor-finish.gdshader', b'assets/craft-v340/service-wear.gdshader', b'assets/craft-v340/industrial-kitchen.glb', b'assets/arrival-v330/car-departure.ogg']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/horse_hunt.gd', b'scripts/horse_navigation.gd', b'assets/clown-v404/clown-hair-web.glb', b'assets/clown-v404/patched-costume-cap.glb', b'assets/clown-v404/patched-cap.gdshader', b'assets/encounter-v360/blond_hair.gdshader']:
                assert any(required in name for name in packed_names), required
            assert not any(b'assets/encounter-v360/clown-blond-hair.glb' in name or b'assets/clown-v404/clown-hair-desktop.glb' in name for name in packed_names)
            for private in [b'scripts/language_validation.gd', b'art-direction/trailer_v380.gd', b'art-direction/itch_v380_capture.gd', b'override.cfg', b'scripts/horse_catch_validation.gd', b'art-direction/v361_capture.gd']:
                assert not any(private in name for name in packed_names), private
            for required in [b'scripts/chalk_board.gd', b'scripts/child_drawings.gd', b'scripts/wall_decay.gd', b'assets/child-art-v382/crayon-atlas.png.import', b'assets/wall-v383/broken-plaster.gdshader', b'assets/wall-v383/web/albedo.jpg.import', b'assets/wall-v383/web/normal.jpg.import', b'assets/wall-v383/web/roughness.jpg.import']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/start_warning.gd', b'assets/branding-v386/after-play-icon.png.import']:
                assert any(required in name for name in packed_names), required
            assert not any(b'assets/wall-v383/desktop/' in name for name in packed_names)
            for required in [b'scripts/party_mode.gd', b'assets/party-v385/party-web.ogg', b'assets/party-v385/track_cues.gd', b'assets/croc-v385/crocodile.glb']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/patrol_party_outro.gd', b'scripts/celebration_cast.gd', b'scripts/celebration_tailoring.gd', b'assets/celebration-v3813/celebration-rabbit.glb']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/shift_album.gd', b'scripts/shift_ticket.gd', b'scripts/venue_touch.gd', b'scripts/happyland_mark.gd', b'scripts/scare_sculpt.gd', b'assets/shift-v390/granny-head.glb', b'assets/shift-v390/passage-head.glb', b'assets/shift-v390/aged_skin.gdshader']:
                assert any(required in name for name in packed_names), required
            for required in [b'scripts/lift_cabin.gd', b'scripts/lift_directory.gd', b'assets/lift-v391/nightguard-handset.glb', b'assets/lift-v391/nightguard-phone-hand.glb', b'assets/lift-v391/lift_surface.gdshader']:
                assert any(required in name for name in packed_names), required
            assert not any(b'scripts/lift_validation.gd' in name for name in packed_names)
            assert not any(b'scripts/shift_validation.gd' in name or b'assets/props/nightguard-torch.glb' in name or b'assets/passage-v280/passage-head' in name for name in packed_names)
            assert not any(b'assets/party-v385/party.mp3' in name or b'assets/creatures/night-crocodile-v4' in name for name in packed_names)
            for private in private_files + [b'scripts/hunt_validation.gd', b'art-direction/v360_capture.gd', b'ANOMALIEN.md', b'ITCH-SEITE.md', b'scripts/native_render_qa.gd', b'scripts/validation.gd', b'scripts/finale_validation.gd', b'scripts/endings_validation.gd', b'scripts/balance_validation.gd', b'scripts/revamp_validation.gd', b'scripts/venue_validation.gd', b'scripts/film_validation.gd', b'scripts/life_validation.gd', b'scripts/watch_validation.gd', b'assets/life-v2110/image-generation-provenance.json', b'art-direction/v300_capture.gd', b'art-direction/v310_capture.gd', b'art-direction/itch_capture.gd', b'art-direction/media_capture.gd', b'art-direction/media_capture.tscn']:
                assert not any(private in name for name in packed_names), private
            for private in [b'scripts/upgrade_validation.gd', b'art-direction/v320_capture.gd', b'art-direction/v320_audio_capture.gd', b'art-direction/v330_capture.gd', b'scripts/arrival_validation.gd', b'scripts/craft_validation.gd', b'scripts/signage_validation.gd', b'scripts/startup_validation.gd', b'art-direction/v350_capture.gd', b'art-direction/v340_capture.gd', b'assets/kitchen-v260/industrial-kitchen.glb']:
                assert not any(private in name for name in packed_names), private
            assert hashlib.sha256(pck).hexdigest() == manifest['web_pck_sha256']
            public = ROOT / 'frontend/public/standalone/kinderparadies'
            assert {str(p.relative_to(public)).replace('\\', '/') for p in public.rglob('*') if p.is_file()} == names
    print(f'{platform}: exact public file list, CRC, checksums, licenses and privacy boundary PASS')

# Source imports may deduplicate an unchanged texture into an older asset folder.
# A real exported executable catches missing dependencies hidden by source tests.
if os.name == 'nt':
    with tempfile.TemporaryDirectory(prefix='after-play-player-check-') as temp:
        log = Path(temp) / 'player.log'
        result = subprocess.run(
            [str(BUILD / 'player-package/AfterPlay.exe'), '--headless',
             '--quit-after', '30', '--log-file', str(log)],
            capture_output=True, timeout=90, creationflags=subprocess.CREATE_NO_WINDOW)
        output = log.read_text('utf-8') if log.exists() else ''
        assert result.returncode == 0 and 'Godot Engine' in output, output
        assert 'ERROR:' not in output and 'SCRIPT ERROR' not in output, output
        print('windows: exported player starts with no missing resources or script errors PASS')
