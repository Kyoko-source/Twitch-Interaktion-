"""Rosenyan plush voice line for After Play 4.5.0.

The source is RosenyanVT's own stream clip (13.8 s). Only the final words
"I am defeated" (12.70 s .. end, located with a local faster-whisper pass and the
loudness envelope) are used. The cut gets a short fade in/out, light rumble
filter and loudness lift; nothing else is changed.

Run: python tools/make-after-play-rosenyan-v450.py [path-to-clip.mp3]
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Desktop' / 'Medien After Play und Stream' / '05 Streamer-Clips/D= - RosenyanVT (1080p).mp3'
OUT = ROOT / 'games/kinderparadies/assets/rosenyan-v450'
START = 12.70

OUT.mkdir(parents=True, exist_ok=True)
ffmpeg = shutil.which('ffmpeg')
target = OUT / 'i-am-defeated.ogg'
subprocess.run([ffmpeg, '-v', 'error', '-y', '-ss', f'{START}', '-i', str(SOURCE),
                '-af', 'highpass=f=90,afade=t=in:d=0.03,areverse,afade=t=in:d=0.08,areverse,loudnorm=I=-16:TP=-1.5:LRA=7',
                '-ar', '48000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'line': 'I am defeated',
    'speaker': 'RosenyanVT (https://www.twitch.tv/rosenyanvt)',
    'source_file': SOURCE.name,
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'cut_from_seconds': START,
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
}, indent=2), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
