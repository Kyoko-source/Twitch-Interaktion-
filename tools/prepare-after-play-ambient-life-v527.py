"""After Play 5.2.7: real field recordings for the venue's ambient life.

Every source is a Creative Commons 0 recording on freesound.org. The tool
opens each sound page, refuses it unless the page states CC0, keeps the page
and the preview it used under tools/art-source/ambient-v527 (git-ignored) and
writes mono 24 kHz Ogg Vorbis edits plus provenance.json to
games/kinderparadies/assets/ambient-v527.

Two kinds of edit:
  loop  - the steadiest window of the recording, its tail cross-faded into
          its head so it loops without a seam (room tones, hums, rain, wind)
  event - the N strongest moments, each cut around its peak with short fades
          (creaks, rats, toys, outside sounds)

Run: python tools/prepare-after-play-ambient-life-v527.py
Freesound rate-limits fast clients, so pages are fetched with pauses.
"""
from pathlib import Path
import hashlib, json, re, subprocess, time, urllib.request
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'tools/art-source/ambient-v527'
OUT = ROOT / 'games/kinderparadies/assets/ambient-v527'
RATE = 24000
AGENT = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

# name, freesound user, sound id, kind, seconds, variants, target RMS dBFS, low-pass Hz
SOURCES = [
    # Room tones and steady sources
    ('neon-buzz', 'kyles', 637729, 'loop', 12, 1, -26, 9000),
    ('fluorescent-hum', 'CHallSmith', 870708, 'loop', 12, 1, -27, 8000),
    ('wall-clock', 'se2001', 511967, 'raw', 0, 1, -27, 9000),
    ('entrance-wind', 'Kinoton', 815100, 'loop', 20, 1, -24, 6000),
    ('window-rain', 'SignatureSoundsOrg', 869851, 'loop', 16, 1, -25, 9000),
    ('boiler', 'rubberduck9999', 678449, 'loop', 14, 1, -25, 6000),
    ('vending-hum', 'jbierfeldt', 418793, 'loop', 14, 1, -26, 6000),
    ('sink-drip', 'martin-bn', 500310, 'loop', 16, 1, -28, 9000),
    ('cinema-static', 'jos-geusens', 875930, 'loop', 10, 1, -30, 7000),
    # Building
    ('room-creak-a', 'Greg_Surr', 590171, 'event', 2.9, 1, -21, 7000),
    ('room-creak-b', 'Greg_Surr', 590169, 'event', 2.4, 1, -21, 7000),
    ('wood-creak', 'Rudmer_Rotteveel', 506665, 'event', 1.2, 1, -21, 7000),
    ('floor-creak', 'edgardomoreno', 477959, 'event', 2.5, 3, -21, 7000),
    ('metal-creak', 'EagleStealthTeam', 172411, 'event', 4, 2, -22, 6000),
    ('radiator-knock', 'SamuelGremaud', 454857, 'event', 4, 2, -22, 6000),
    ('plastic-creak', 'felix.blume', 414151, 'event', 3, 2, -22, 7000),
    ('door-rattle', 'Profispiesser', 583058, 'event', 4, 2, -22, 6000),
    # Animals inside
    ('rat-gnaw', 'ulla_petersen', 333094, 'event', 4, 2, -23, 8000),
    ('rats', 'Sycoraxi', 134791, 'event', 5, 1, -23, 8000),
    ('mouse-squeak', 'shyguy014', 463789, 'event', 1.5, 2, -24, 9000),
    ('pigeon', 'Kinoton', 689998, 'event', 5, 1, -21, 8000),
    # Toys and play equipment
    ('squeak-toy', 'speedygonzo', 235722, 'event', 1.2, 2, -22, 9000),
    ('toy-car', 'domestophonics', 420403, 'event', 6, 1, -22, 8000),
    ('windup-car', 'simone_ds', 366083, 'event', 6, 1, -22, 8000),
    ('windup-toy', 'lmbubec', 118816, 'event', 5, 1, -22, 8000),
    ('music-box', 'davidou', 88453, 'event', 8, 1, -23, 9000),
    ('xylophone', 'JappeHallunken', 501300, 'event', 3, 2, -23, 9000),
    ('ball-bounce', 'Plexant', 128310, 'event', 4, 2, -22, 8000),
    ('ball-pit', 'elektromat', 553890, 'event', 3, 2, -22, 9000),
    ('talking-toy', 'Filmscore', 830450, 'event', 2.5, 1, -23, 8000),
    ('balloon-rub', 'carlSablowEdwards', 76802, 'event', 2, 2, -23, 9000),
    ('coin-slot', 'jinkybat', 877553, 'event', 3, 1, -23, 9000),
    # Washroom
    ('hand-dryer', 'deleted_user_7020630', 378390, 'event', 8, 1, -21, 8000),
    ('cistern', 'The_Sean_', 340297, 'event', 9, 1, -23, 8000),
    # Outside, heard through walls and the windows
    ('siren', 'kyles', 451068, 'event', 10, 1, -22, 5000),
    ('dogs', 'SoundEnsemble', 550848, 'event', 6, 2, -22, 5000),
    ('car-pass', 'bastiien', 571931, 'event', 7, 2, -22, 5000),
    ('owl', 'SyntaxSeed', 871240, 'event', 4, 1, -23, 6000),
]


def fetch(url):
    for attempt in range(5):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=60).read()
        except urllib.error.HTTPError as error:
            if error.code != 429:
                raise
            time.sleep(30 * (attempt + 1))
    raise RuntimeError('Rate limited: ' + url)


def source(user, sound):
    page_file = RAW / f'{sound}.html'
    audio_file = RAW / f'{sound}.mp3'
    page_url = f'https://freesound.org/people/{user}/sounds/{sound}/'
    if not page_file.exists():
        page_file.write_bytes(fetch(page_url)); time.sleep(8)
    page = page_file.read_text(encoding='utf8', errors='ignore')
    assert re.search(r'creativecommons\.org/publicdomain/zero/1\.0', page), f'{page_url} is not CC0'
    preview = re.search(r'https://cdn\.freesound\.org/previews/\d+/' + str(sound) + r'_\d+-hq\.mp3', page)
    if not preview:
        lq = re.search(r'https://cdn\.freesound\.org/previews/\d+/' + str(sound) + r'_\d+-lq\.mp3', page)
        assert lq, f'No preview on {page_url}'
        preview_url = lq.group(0).replace('-lq.mp3', '-hq.mp3')
    else:
        preview_url = preview.group(0)
    if not audio_file.exists():
        audio_file.write_bytes(fetch(preview_url)); time.sleep(3)
    return page_url, preview_url, audio_file


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(RATE), '-f', 'f32le', 'pipe:1'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype='<f4').astype(np.float64)


def shape(samples, cutoff):
    n = len(samples)
    freq = np.fft.rfftfreq(n, 1 / RATE)
    return np.fft.irfft(np.fft.rfft(samples) * np.minimum(1, freq / 60) ** 2 / (1 + (freq / cutoff) ** 6), n)


def level(samples, rms_db):
    rms = np.sqrt(np.mean(samples * samples))
    return samples * min(10 ** (rms_db / 20) / max(rms, 1e-9), .7 / max(np.abs(samples).max(), 1e-9))


def frames(samples, hop=.05):
    step = int(hop * RATE)
    count = len(samples) // step
    return np.sqrt(np.mean(samples[:count * step].reshape(count, step) ** 2, axis=1) + 1e-12)


def steady_loop(samples, seconds):
    fade = int(1.5 * RATE)
    need = int(seconds * RATE) + fade
    if len(samples) <= need:
        body = samples
    else:
        energy = frames(samples)
        span = int((seconds + 1.5) / .05)
        best, start = 1e9, 0
        for first in range(0, len(energy) - span, 10):
            window = energy[first:first + span]
            score = window.std() / window.mean() + (window.max() / window.mean() > 4) * 10
            if score < best:
                best, start = score, first
        body = samples[start * int(.05 * RATE):start * int(.05 * RATE) + need]
    head, tail = body[:fade], body[-fade:]
    curve = np.linspace(0, np.pi / 2, fade)
    looped = body[:-fade].copy()
    looped[:fade] = head * np.sin(curve) + tail * np.cos(curve)
    return looped


def events(samples, seconds, count):
    energy = frames(samples)
    span = int(seconds / .05)
    taken = np.zeros(len(energy), bool)
    cuts = []
    for _ in range(count):
        masked = np.where(taken, 0, energy)
        peak = int(masked.argmax())
        start = max(0, min(peak - span // 4, len(energy) - span))
        taken[max(0, start - span // 2):start + span + span // 2] = True
        cut = samples[start * int(.05 * RATE):start * int(.05 * RATE) + int(seconds * RATE)].copy()
        fade_in = min(int(.012 * RATE), len(cut) // 8)
        fade_out = int(len(cut) * .3)
        cut[:fade_in] *= np.linspace(0, 1, fade_in)
        cut[-fade_out:] *= np.linspace(1, 0, fade_out) ** 1.5
        cuts.append((start * .05, cut))
    return cuts


def write(name, samples):
    target = OUT / (name + '.ogg')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', 'pipe:0',
                    '-c:a', 'libvorbis', '-q:a', '3', str(target)],
                   input=np.clip(samples, -.9, .9).astype('<f4').tobytes(), check=True)
    return target


RAW.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
for name, user, sound, kind, seconds, variants, rms_db, cutoff in SOURCES:
    page_url, preview_url, audio = source(user, sound)
    samples = decode(audio)
    if kind == 'raw':
        outputs = [(name, 0., samples)]
    elif kind == 'loop':
        outputs = [(name, 0., steady_loop(samples, seconds))]
    else:
        cuts = events(samples, min(seconds, len(samples) / RATE), variants)
        outputs = [(name if variants == 1 else f'{name}-{index + 1}', start, cut) for index, (start, cut) in enumerate(cuts)]
    for file, start, cut in outputs:
        path = write(file, level(shape(cut, cutoff), rms_db))
        manifest.append({'file': path.name, 'kind': 'loop' if kind in ['loop', 'raw'] else 'event',
                         'author': user, 'license': 'CC0-1.0', 'source': page_url, 'preview': preview_url,
                         'preview_sha256': hashlib.sha256(audio.read_bytes()).hexdigest(),
                         'processing': f'Mono 24 kHz from the HQ preview, {kind} edit from {start:.2f}s, '
                                       f'{len(cut) / RATE:.2f}s, RMS {rms_db} dBFS, HP60Hz/LP{cutoff}Hz'})
    print('ok', name, len(outputs))
(OUT / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
(OUT / 'LICENSE.txt').write_text(
    'Field recordings from freesound.org, each released under Creative Commons 0 (public domain).\n'
    'https://creativecommons.org/publicdomain/zero/1.0/\n'
    'Authors, source pages, preview hashes and edits: provenance.json.\n', encoding='utf8')
print('Prepared', len(manifest), 'ambient edits')
