"""Prepare Rolling Acid and its music-driven lighting cues for After Play.

Keep the supplied MP3 unchanged, including Suno's provenance metadata. The web
copy is an audio-only format conversion. This does not grant commercial rights.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / 'Desktop/Rolling Acid.mp3'
OUT = ROOT / 'games/kinderparadies/assets/party-v385'
FFMPEG = ROOT / 'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'

# Bass entrances and releases reviewed against the supplied recording's
# short-time spectrum. A replacement recording must be analysed again.
DROP_SPANS = [(59.25, 107.1), (111.90, 142.8), (164.40, 212.6),
              (217.05, 242.7), (243.35, 264.1)]
EXPECTED_SHA256 = 'a408765ec7a5dcaf299a682a99faf5ce3f457d05e13d68cf55bc1993a16dc03e'

def main():
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit('Recording changed: review its lighting section map first.')
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE, OUT / 'party.mp3')
    subprocess.run([str(FFMPEG), '-y', '-v', 'error', '-i', str(SOURCE),
                    '-map', '0:a:0', '-vn', '-map_metadata', '0', '-c:a', 'libvorbis',
                    '-q:a', '1.5', '-ar', '32000', str(OUT / 'party-web.ogg')], check=True)
    with tempfile.TemporaryDirectory(prefix='after-play-party-') as temp:
        pcm = Path(temp) / 'mono.f32'
        subprocess.run([str(FFMPEG), '-y', '-v', 'error', '-i', str(SOURCE),
                        '-map', '0:a:0', '-vn', '-ac', '1', '-ar', '11025',
                        '-f', 'f32le', str(pcm)], check=True)
        signal = np.fromfile(pcm, dtype='<f4')
    hop, window, rate = 220, 1100, 11025
    frames = np.lib.stride_tricks.sliding_window_view(signal, window)[::hop]
    rms = np.sqrt((frames**2).mean(axis=1))
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(window), axis=1))
    frequencies = np.fft.rfftfreq(window, 1 / rate)
    bass = np.sqrt((spectrum[:, (frequencies > 40) & (frequencies < 180)]**2).mean(axis=1))
    times = np.arange(len(rms)) * hop / rate
    # Local thresholds retain kicks in quieter passages instead of letting
    # the much louder final section hide their onsets.
    onset = np.maximum(0, bass - np.roll(bass, 2))
    onset[:2] = 0
    local = np.convolve(onset, np.ones(201) / 201, 'same')
    beats = []
    for i in range(2, len(onset) - 2):
        if (onset[i] > max(.15, local[i] * 1.45)
                and onset[i] == max(onset[i-2:i+3])
                and (not beats or times[i] + .05 - beats[-1] > .27)):
            beats.append(round(float(times[i] + .05), 3))
    duration = len(signal) / rate
    sample_times = np.arange(0, duration, .25)
    energy = np.interp(sample_times, times + .05, rms / np.quantile(rms, .85)).clip(0, 1)
    low = np.interp(sample_times, times + .05, bass / np.quantile(bass, .85)).clip(0, 1)
    cues = {
        'DURATION': round(duration, 5),
        'BEATS': beats,
        'ENERGY': [round(float(v), 3) for v in energy],
        'BASS': [round(float(v), 3) for v in low],
        'DROPS': [start for start, _ in DROP_SPANS],
        'DROP_ENDS': [end for _, end in DROP_SPANS],
    }
    body = 'extends RefCounted\n\n# Rolling Acid: amplitude/bass at 4 Hz, plus reviewed section boundaries.\n'
    body += '\n'.join(f'const {key}:={json.dumps(value, separators=(",", ":"))}' for key, value in cues.items()) + '\n'
    (OUT / 'track_cues.gd').write_text(body, encoding='utf-8')
    provenance = {
        'source': 'https://suno.com/song/7c0b0cbc-ee54-4941-874a-d8791fa7d477',
        'author': 'atomicmicrotone145 / Kyoko', 'title': 'Rolling Acid',
        'provider': 'Suno', 'plan_at_creation': 'Free (confirmed by creator)',
        'license': 'Suno Free: personal, non-commercial use only; no commercial license verified',
        'terms': {'source': 'https://suno.com/terms', 'author': 'Suno',
                  'license': 'Suno Terms of Service'},
        'provided_filename': SOURCE.name, 'sha256': digest,
        'duration_seconds': duration, 'beat_count': len(beats),
        'drop_spans_seconds': DROP_SPANS,
        'metadata': 'Original MP3 unchanged; Ogg conversion preserves source audio metadata.',
        'distribution_condition': 'Game must remain noncommercial, with payments and donations disabled.',
    }
    (OUT / 'party-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'duration': duration, 'beats': len(beats), 'drops': DROP_SPANS,
                      'sha256': digest, 'web_bytes': (OUT / 'party-web.ogg').stat().st_size}))

if __name__ == '__main__':
    main()
