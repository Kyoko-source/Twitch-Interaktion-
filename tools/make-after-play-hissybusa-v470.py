"""Hissybusa plush voice line for After Play 4.7.0.

The source is Hissybusa's own clip "NEW DINOSAUR HORROR GAME! Welcome to Sunnybrook" (60 s). Only the
line "Simon, you jerk! Move! Please move! Damn it!" (10.45 s .. 15.95 s; located with a local
faster-whisper pass and the loudness envelope, ending in the dip after "damn it") is used, with a
short fade in, a 0.2 s fade out, light rumble filter and loudness lift. The game sound under the
voice stays in, it is part of the moment.

Run: python tools/make-after-play-hissybusa-v470.py [path-to-clip.mp4]
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if len(sys.argv) > 1:
    SOURCE = Path(sys.argv[1])
else:
    SOURCE = next((Path.home() / 'Desktop' / 'Medien After Play und Stream' / '05 Streamer-Clips').glob('*Hissybusa*.mp4'))
OUT = ROOT / 'games/kinderparadies/assets/hissybusa-v470'
START, END = 10.45, 15.95

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / 'simon-move.ogg'
length = END - START
subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-ss', f'{START}', '-t', f'{length:.3f}', '-i', str(SOURCE), '-vn',
                '-af', f'highpass=f=80,afade=t=in:d=0.04,afade=t=out:st={length - .2:.3f}:d=0.2,loudnorm=I=-17:TP=-2.5:LRA=9,aresample=48000,alimiter=limit=0.7:level=false',
                '-ar', '48000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'line': 'Simon, you jerk! Move! Please move! Damn it!',
    'speaker': 'Hissybusa',
    'source_file': SOURCE.name,
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'cut_seconds': [START, END],
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'model': 'tools/model-after-play-hissybusa-v470.py',
}, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
