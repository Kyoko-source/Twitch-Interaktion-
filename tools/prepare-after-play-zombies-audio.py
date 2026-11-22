"""Partynacht announcer lines from the owner's recordings, After Play 5.0.1 / 5.2.3.

Reads the recordings from the desktop folders "Ansagen Bonus" and
"Zombie Sounds" (5.2.3: the remaining eleven pickups), trims the
silence at the end (keeps a short tail with a fade), normalises loudness and
writes them as Ogg Vorbis under the announcer keys the game looks for.
The originals are never changed. New recordings: add a line to LINES.

Run: python tools/prepare-after-play-zombies-audio.py
Output: games/kinderparadies/assets/zombies-v500/audio/<key>.ogg
"""
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / 'Desktop' / 'Medien After Play und Stream' / '02 After Play Sounds und Stimmen' / 'Ansagen Bonus'
SOURCE_V523 = Path.home() / 'Desktop' / 'Medien After Play und Stream' / '02 After Play Sounds und Stimmen' / 'Zombie Sounds'
OUT = ROOT / 'games/kinderparadies/assets/zombies-v500/audio'
# recording file name -> announcer key (see scripts/zombies_announcer.gd)
LINES = {
    'Doppelte Punkte.mp3': 'pickup_double_points',
    'Glaufeschwindigkeitx2.mp3': 'pickup_speed',
    'Instakill.mp3': 'pickup_insta_kill',
    'Nuke alle sterben.mp3': 'pickup_nuke',
    'Unbegrenze Munition fuer 20sek.mp3': 'pickup_infinite_ammo',
    'doppelter Schaden.mp3': 'pickup_damage',
    'Runden beginn ganz am anfang.mp3': 'start',
}
# 5.2.3: the eleven pickups that still played the synthetic drone
LINES_V523 = {
    'Maximalmunition.mp3': 'pickup_max_ammo',
    'Kriechzeit.mp3': 'pickup_slowdown',
    'Plüschschild.mp3': 'pickup_shield',
    'Vergessen.mp3': 'pickup_invisible',
    'Kritische Nacht.mp3': 'pickup_crit',
    'Feuerkinder.mp3': 'pickup_fire_kills',
    'Kettenblitz.mp3': 'pickup_chain',
    'Schwerelos.mp3': 'pickup_gravity',
    'Alien-Segen.mp3': 'pickup_alien',
    'Zeitlupe.mp3': 'pickup_time',
    'Blutrausch.mp3': 'pickup_bloodrush',
}

def speech_end(path: Path) -> float:
    """End of the last speech: the start of the trailing silence."""
    log = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-af', 'silencedetect=noise=-40dB:d=0.25', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    duration = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(path)], capture_output=True, text=True).stdout)
    starts = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', log)]
    ends = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', log)]
    if starts and (not ends or ends[-1] >= duration - .05) and starts[-1] > .5:
        return starts[-1]
    return duration

def main() -> None:
    assert shutil.which('ffmpeg'), 'ffmpeg is needed'
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [(SOURCE / n, k) for n, k in LINES.items()] + [(SOURCE_V523 / n, k) for n, k in LINES_V523.items()]
    for src, key in jobs:
        name = src.name
        if not src.exists():
            print('missing', name); continue
        end = speech_end(src) + .35
        out = OUT / f'{key}.ogg'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-af',
                        f'atrim=0:{end:.3f},afade=t=out:st={max(end - .25, 0):.3f}:d=0.25,loudnorm=I=-16:TP=-1.5:LRA=11',
                        '-ac', '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '6', str(out)], check=True)
        print(f'{key:24s} <- {name}  ({end:.2f} s)')

main()
