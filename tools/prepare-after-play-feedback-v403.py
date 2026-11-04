"""Distinct creature voices and quiet contact foley from retained CC0 sources."""
from pathlib import Path
import hashlib, json, shutil, subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
A = ROOT / 'games/kinderparadies/assets'
OUT = A / 'feedback-v403'
OUT.mkdir(exist_ok=True)
RATE = 24000
FFMPEG = shutil.which('ffmpeg')
assert FFMPEG
sources = {
    'horse': ROOT / 'tools/art-source/v300/monster-3.wav',
    'granny': ROOT / 'tools/art-source/v300/monster-7.wav',
    'door': ROOT / 'tools/art-source/v300/monster-8.wav',
    'wood': A / 'surfaces/footstep_wood_002.ogg',
    'metal': A / 'ambience-v193/duct-stress.wav',
    'plastic': A / 'polish/impact-plastic.wav',
    'cloth': A / 'polish/impact-cloth.wav',
    'relay': A / 'ambience/relay-tick.wav',
}
def decode(path):
    raw = subprocess.run([FFMPEG, '-v', 'error', '-i', str(path), '-ac', '1',
        '-ar', str(RATE), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, '<f4').astype(float)
    return x / max(.001, np.max(abs(x)))
raw = {k: decode(p) for k, p in sources.items()}
def add(dst, src, at, gain, speed=1., offset=0.):
    x = np.interp(np.arange(int(offset*RATE), len(src)-1, speed), np.arange(len(src)), src)
    start = int(at*RATE); n = min(len(x), len(dst)-start)
    if n <= 0: return
    x = x[:n].copy(); fade = min(n//4, int(.045*RATE))
    x[:min(72,n)] *= np.linspace(0,1,min(72,n)); x[-fade:] *= np.linspace(1,0,fade)
    dst[start:start+n] += x*gain
def band(x, low, high):
    f = np.fft.rfftfreq(len(x),1/RATE)
    weight = f*f/(f*f+low*low) / np.sqrt(1+(f/high)**8)
    return np.fft.irfft(np.fft.rfft(x)*weight,len(x))
outputs = {}
def write(name,x,peak=-3.):
    # No repeated common scream, heavy saturation, room echo or loudness arms race.
    x *= 10**(peak/20)/max(.001,np.max(abs(x)))
    n = min(len(x)//4,1200); x[-n:] *= np.linspace(1,0,n)
    path = OUT/(name+'.ogg')
    subprocess.run([FFMPEG,'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1',
        '-i','-','-c:a','libvorbis','-q:a','4',str(path)],input=x.astype('<f4').tobytes(),check=True)
    outputs[name]={'duration':len(x)/RATE,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
for variant in range(1,4):
    x=np.zeros(round(RATE*(1.08+.06*variant)))
    add(x,raw['horse'],0,1.,1.48+.06*variant,.035*variant)
    add(x,raw['metal'],.045,.16,1.3+.1*variant)
    write(f'horse-{variant}',band(x,260,8500))
    x=np.zeros(round(RATE*(.95+.07*variant)))
    # A single dry vocal take: no pitch lowering, chorus, metallic layer or reverb.
    add(x,raw['granny'],0,1.,1.,.065*(variant-1))
    write(f'granny-{variant}',band(x,170,6100))
    x=np.zeros(round(RATE*(.70+.045*variant)))
    add(x,raw['wood'],0,.68,.8)
    add(x,raw['door'],.018,1.,.73+.04*variant,.025*variant)
    write(f'door-{variant}',band(x,65,4400))
# A paper fold: irregular, short broadband friction with quiet cloth body.
rng=np.random.default_rng(403)
x=np.zeros(round(RATE*.58));t=np.arange(len(x))/RATE
for at,width,gain in [(0.07,.045,.52),(.20,.065,.8),(.37,.045,.38)]:
    noise=band(rng.normal(0,1,len(x)),650,7800)
    x+=noise*np.exp(-.5*((t-at)/width)**2)*gain
add(x,raw['cloth'],.01,.12,1.2)
write('paper',x,-12.)
x=np.zeros(round(RATE*.16));add(x,raw['relay'],0,.6,1.6);add(x,raw['plastic'],.025,.38,1.5)
write('switch',band(x,650,7600),-10.)
manifest={'author':'Ogrebane; Joseph SARDIN; Kenney; original project paper foley',
 'license':'CC0-1.0 recordings; original project sound edits',
 'source':'https://opengameart.org/content/monster-sound-effects-pack',
 'processing':'Mono 24 kHz Vorbis q4; separate vocal recordings, dry granny at original pitch, short heavy door attack, shrill horse; finite fades; no common scream layer.',
 'inputs':{k:{'file':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for k,p in sources.items()},
 'outputs':outputs}
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Prepared',len(outputs),'feedback clips;',sum(p.stat().st_size for p in OUT.glob('*.ogg')),'bytes')
