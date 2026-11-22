"""Partynacht zombie voices from the owner's Pixabay downloads, After Play 5.1.3.

Reads every .mp3/.wav/.ogg in the desktop folder "Zombie Sounds", cuts each
file at its silent gaps into separate calls (so one download can give several
moans), trims silence, normalises loudness and writes mono Ogg Vorbis files
named moan-0.ogg, moan-1.ogg, ... The originals are never changed.
The sounds come from Pixabay (Pixabay Content License, free for use in games).

Run: python tools/prepare-after-play-zombie-voices.py [--out DIR]
Output: games/kinderparadies/assets/zombies-v513/voice/moan-<n>.ogg and
        voice-sources.json (which call came from which file)
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / 'Desktop' / 'Medien After Play und Stream' / '02 After Play Sounds und Stimmen' / 'Zombie Sounds'
OUT = ROOT / 'games/kinderparadies/assets/zombies-v513/voice'
MIN_CALL = .55   # shorter pieces are dropped
MAX_CALL = 4.5   # longer pieces are faded out here


def duration(path: Path) -> float:
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(path)],
                         capture_output=True, text=True).stdout
    return float(out)


def calls(path: Path) -> list:
    """(start, end) of every sounding stretch between silences."""
    log = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-af', 'silencedetect=noise=-38dB:d=0.35', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    total = duration(path)
    starts = [float(x) for x in re.findall(r'silence_start: (-?[\d.]+)', log)]
    ends = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', log)]
    pieces, cursor = [], 0.
    for s, e in zip(starts, ends + [total] * (len(starts) - len(ends))):
        if s - cursor > 0:
            pieces.append((cursor, max(s, cursor)))
        cursor = e
    if total - cursor > 0:
        pieces.append((cursor, total))
    out = []
    for a, b in pieces:
        a = max(a - .04, 0.)
        b = min(b + .12, total)
        if b - a >= MIN_CALL:
            out.append((a, min(b, a + MAX_CALL)))
    return out or [(0., min(total, MAX_CALL))]


def main() -> None:
    assert shutil.which('ffmpeg'), 'ffmpeg is needed'
    out_dir = Path(sys.argv[sys.argv.index('--out') + 1]) if '--out' in sys.argv else OUT
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob('moan-*.ogg'):
        old.unlink()
    files = sorted(p for p in SOURCE.iterdir() if p.suffix.lower() in ('.mp3', '.wav', '.ogg'))
    index, sources = 0, []
    for src in files:
        for a, b in calls(src):
            length = b - a
            fade = min(.2, length * .3)
            target = out_dir / f'moan-{index}.ogg'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{a:.3f}', '-t', f'{length:.3f}', '-i', str(src), '-af',
                            f'afade=t=in:d=0.03,afade=t=out:st={length - fade:.3f}:d={fade:.3f},loudnorm=I=-17:TP=-1.5:LRA=11',
                            '-ac', '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', str(target)], check=True)
            sources.append({'file': target.name, 'source': src.name, 'start': round(a, 3), 'length': round(length, 3)})
            print(f'{target.name:12s} <- {src.name} {a:.2f}s +{length:.2f}s')
            index += 1
    (out_dir / 'voice-sources.json').write_text(json.dumps({'license': 'Pixabay Content License', 'calls': sources}, indent=1), encoding='utf-8')
    print('calls:', index)


main()
