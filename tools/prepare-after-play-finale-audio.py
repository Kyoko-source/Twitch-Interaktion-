"""Prepare the supplied full narration and a CC0 vocal scare, without editing sources."""
from pathlib import Path
import hashlib,json,struct,subprocess,zipfile,wave,shutil,os
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/finale'
SOURCE=Path.home()/'Desktop/Horror Audio Marelle.wma'
ARCHIVE=ROOT/'tools/art-source/evil-creature-cc0.zip'
OUT.mkdir(exist_ok=True)
FFMPEG=shutil.which('ffmpeg')
if not FFMPEG:
 candidates=list((Path(os.environ.get('LOCALAPPDATA',''))/'Microsoft/WinGet/Packages').glob('Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe'))
 FFMPEG=str(sorted(candidates)[-1]) if candidates else 'ffmpeg'
subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(SOURCE),'-vn','-c:a','libvorbis','-q:a','5',str(OUT/'marelle.ogg')],check=True)
with zipfile.ZipFile(ARCHIVE) as z:
    data=z.read('Sound FX_data/b00035.au')
offset=struct.unpack_from('<I',data,4)[0]
samples=np.frombuffer(data,dtype='<i2',offset=offset).copy()
assert len(samples)==250128
# Retain the strongest sustained vocal attack, with a tiny lead-in and tail.
window=round(44100*1.65)
energy=np.convolve((samples.astype(float)/32768)**2,np.ones(2205)/2205,'valid')
peak=int(np.argmax(energy));start=max(0,min(len(samples)-window,peak-round(44100*.25)))
source=ROOT/'tools/art-source/evil-vocal-crop.wav'
with wave.open(str(source),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(44100);f.writeframes(samples[start:start+window].tobytes())
subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(source),'-af','asetrate=50715,aresample=48000,highpass=f=110,lowpass=f=8400,acompressor=threshold=0.05:ratio=5:attack=1:release=50:makeup=3,loudnorm=I=-14:TP=-2:LRA=7,afade=t=in:d=0.004,atrim=duration=1.01,afade=t=out:st=0.89:d=0.12','-ar','48000','-ac','1','-c:a','pcm_s16le',str(OUT/'cook-scream.wav')],check=True)
provenance={
    'marelle.ogg':{'source_filename':SOURCE.name,'source_sha256':hashlib.file_digest(SOURCE.open('rb'),'sha256').hexdigest(),'processing':'Full-length WMA decoded to Ogg Vorbis q5. No crop, no pitch/time change. User-supplied game recording.'},
    'cook-scream.wav':{'author':'A New Room','submitted_by':'qubodup','license':'CC0-1.0','source':'https://opengameart.org/content/evil-creature','archive_sha256':hashlib.file_digest(ARCHIVE.open('rb'),'sha256').hexdigest(),'processing':f'Audacity AU PCM block b00035, crop at {start/44100:.6f}s; 1.15x pitch/speed, filtering, compression, -14 LUFS / -2 dBTP, short fades.'}
}
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('Archive skeletal model and recorder/chain geometry: original project-authored assets. Marelle recording: supplied by the game creator for inclusion in After Play; not licensed as CC0. Cook vocal: A New Room, submitted by qubodup, CC0, https://opengameart.org/content/evil-creature . Original archive https://opengameart.org/sites/default/files/ambient%20sound%20fx.zip . Processing and checksums: provenance.json.\n',encoding='utf-8')
print('Prepared complete Marelle recording and processed CC0 vocal scare.')
