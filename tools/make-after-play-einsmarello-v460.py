"""einsmarello plush voice line for After Play 4.6.0.

The source is einsmarello's own stream clip "Peak Gesang oder so" (29.9 s, sung). Only the line
"I'm a Barbie girl in a Barbie world" (12.95 s .. 16.85 s, after a short silence in the clip;
located with a local faster-whisper pass and the loudness envelope) is used, with a short fade
in, a gentle 0.25 s fade out, light rumble filter and loudness lift.

Run: python tools/make-after-play-einsmarello-v460.py [path-to-clip.mp3]
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Desktop' / 'Medien After Play und Stream' / '05 Streamer-Clips/Peak-Gesang-oder-so-einsmarello-_720p_.mp3'
OUT = ROOT / 'games/kinderparadies/assets/einsmarello-v460'
START, END = 12.95, 16.85

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / 'barbie-girl.ogg'
length = END - START
subprocess.run([shutil.which('ffmpeg'), '-v', 'error', '-y', '-ss', f'{START}', '-t', f'{length:.3f}', '-i', str(SOURCE),
                '-af', f'highpass=f=80,afade=t=in:d=0.04,afade=t=out:st={length - .25:.3f}:d=0.25,loudnorm=I=-17:TP=-2.5:LRA=9,aresample=48000,alimiter=limit=0.7:level=false',
                '-ar', '48000', '-ac', '1', '-c:a', 'libvorbis', '-q:a', '6', str(target)], check=True)
seconds = float(subprocess.run([shutil.which('ffprobe'), '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(target)],
                               capture_output=True, text=True, check=True).stdout)
(OUT / 'provenance.json').write_text(json.dumps({
    'line': "I'm a Barbie girl in a Barbie world (sung)",
    'speaker': 'einsmarello',
    'source_file': SOURCE.name,
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'cut_seconds': [START, END],
    'seconds': round(seconds, 3),
    'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
}, indent=2), encoding='utf-8')
print(f'{target.name}: {seconds:.2f} s')
