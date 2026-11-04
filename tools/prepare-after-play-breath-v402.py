"""Prepare quiet, unpitched player breathing from the retained CC0 recording."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/art-source/audio-v180/breathing.wav'
OUT = ROOT / 'games/kinderparadies/assets/player-v402'
OUT.mkdir(parents=True, exist_ok=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == 'd077b2743eeeaa69f5f2f993ee16b4441d1cd32211774c22bc885c29150d2bb6'
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg, 'ffmpeg must be on PATH'
# Two complete, quieter nasal breath cycles, with edits in their natural pauses.
# Preserve both pitch and timing; remove close-microphone rumble and soften the
# nasal resonance rather than slowing the voice or applying horror processing.
filters = ('atrim=start=11.05:end=18.95,asetpts=PTS-STARTPTS,'
           'highpass=f=220,equalizer=f=520:t=o:w=1.4:g=-5,lowpass=f=6000,'
           'afade=t=in:d=0.12,afade=t=out:st=7.7:d=0.2')
subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', str(SOURCE), '-af', filters,
                '-ac', '1', '-ar', '24000', '-c:a', 'libvorbis', '-q:a', '4',
                str(OUT / 'breathing.ogg')], check=True)
(OUT / 'provenance.json').write_text(json.dumps({
    'file': 'breathing.ogg', 'author': 'Joseph SARDIN', 'license': 'CC0-1.0',
    'source': 'https://bigsoundbank.com/man-breathing-s2195.html',
    'original_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'processing': filters + '; mono 24 kHz Vorbis q4; original pitch and timing',
}, indent=2) + '\n', encoding='utf-8')
print('Prepared separate natural player breathing:', (OUT / 'breathing.ogg').stat().st_size, 'bytes')
