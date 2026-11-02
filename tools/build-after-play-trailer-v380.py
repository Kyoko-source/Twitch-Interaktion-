"""Finish the 75-second, jump-scare-free native trailer; no generated footage."""
from pathlib import Path
import json, os, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'games/kinderparadies'
FFMPEG = ROOT / 'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'
SOURCE = Path(os.environ['TEMP']) / 'after-play-v380-native1080.avi'
HALL = Path(os.environ['TEMP']) / 'after-play-v380-hall1080.avi'
OUT = PROJECT / 'build/trailer/After-Play-Trailer-1080p.mp4'
OUT.parent.mkdir(parents=True, exist_ok=True)
with (OUT.parent / 'v380-encode.log').open('w', encoding='utf8') as log:
    subprocess.run([
        str(FFMPEG), '-hide_banner', '-y', '-ss', '2.4', '-i', str(SOURCE),
        '-ss', '2.4', '-i', str(HALL),
        '-i', str(PROJECT / 'assets/music-v371/music-box-chase.mp3'),
        '-stream_loop', '-1', '-i', str(PROJECT / 'assets/ambience/ventilation.ogg'),
        '-filter_complex',
        '[0:v]split=2[head][tail];'
        '[head]trim=start=0:end=6,setpts=PTS-STARTPTS[first];'
        '[1:v]trim=start=0:end=7,setpts=PTS-STARTPTS[hall];'
        '[tail]trim=start=13:end=75,setpts=PTS-STARTPTS[last];'
        '[first][hall][last]concat=n=3:v=1:a=0,scale=in_range=full:out_range=tv,setsar=1[v];'
        '[2:a]atrim=0:75,asetpts=PTS-STARTPTS,loudnorm=I=-18:TP=-2:LRA=8,'
        'afade=t=in:st=0:d=2.5,afade=t=out:st=70:d=5[music];'
        '[3:a]atrim=0:75,asetpts=PTS-STARTPTS,volume=0.07,'
        'afade=t=in:st=0:d=3,afade=t=out:st=70:d=5[air];'
        '[music][air]amix=inputs=2:normalize=0:duration=first,'
        'alimiter=limit=0.89:level=false[a]',
        '-map', '[v]', '-map', '[a]', '-t', '75', '-r', '30',
        '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-movflags', '+faststart',
        '-metadata', 'title=After Play — Official Trailer',
        '-metadata', 'comment=Native game footage. No jump scares or ending spoilers.',
        str(OUT)
    ], stdout=log, stderr=log, check=True)
public = ROOT / 'frontend/public/downloads/after-play-trailer-1080p.mp4'
shutil.copy2(OUT, public)
bundle = PROJECT / 'build/itch-media-v3.8.0'
bundle.mkdir(parents=True, exist_ok=True)
shutil.copy2(OUT, bundle / OUT.name)
(OUT.parent / 'v380-trailer-manifest.json').write_text(json.dumps({
    'version': '3.8.0', 'duration_seconds': 75, 'resolution': [1920,1080], 'fps': 30,
    'footage': 'Unmodified production scene and lights; cinematic camera paths.',
    'music': 'Music Box Chase', 'jump_scares': False, 'anomalies': False,
    'secret_ending_spoilers': False, 'warmup_trim_seconds': 2.4
}, ensure_ascii=False, indent=2), encoding='utf8')
print(OUT)
