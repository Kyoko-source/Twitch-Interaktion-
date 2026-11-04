"""Distinct, finite sound edits from already credited project/CC0 recordings."""
import numpy as np
import subprocess,shutil,json,hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1];A=ROOT/'games/kinderparadies/assets'
OUT=A/'quality-v410/audio';OUT.mkdir(parents=True,exist_ok=True)
FF=shutil.which('ffmpeg');assert FF
RATE=32000;rng=np.random.default_rng(410);report={}

def read(path):
    result=subprocess.run([FF,'-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-f','f32le','-'],capture_output=True,check=True)
    x=np.frombuffer(result.stdout,'<f4').astype(float)
    return x/max(.001,np.max(abs(x)))

def band(x,low,high):
    f=np.fft.rfftfreq(len(x),1/RATE)
    return np.fft.irfft(np.fft.rfft(x)*(f*f/(f*f+low*low))/np.sqrt(1+(f/high)**8),len(x))

def add(dst,src,time,gain,speed=1.,offset=0.):
    src=np.interp(np.arange(offset*RATE,len(src)-1,speed),np.arange(len(src)),src)
    start=round(time*RATE);n=min(len(src),len(dst)-start)
    if n<1:return
    src=src[:n].copy();fade=min(n//4,round(.035*RATE))
    if fade:src[:fade]*=np.linspace(0,1,fade);src[-fade:]*=np.linspace(1,0,fade)
    dst[start:start+n]+=src*gain

def write(name,x,peak=-5.):
    # Fixed headroom and short fades; spectral variety does not depend on volume.
    x=band(x,45,11500)
    fade=min(len(x)//4,round(.02*RATE));x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
    if name.startswith('step-'):
        # Match the original and new takes to one crest factor; mixing quiet
        # fresh edits with old over-full-scale Vorbis made alternating steps jump.
        x=np.tanh(x/max(.001,np.sqrt(np.mean(x*x))*4.))
    x*=10**(peak/20)/max(.001,np.max(abs(x)))
    path=OUT/(name+'.ogg')
    subprocess.run([FF,'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-c:a','libvorbis','-q:a','5',str(path)],input=x.astype('<f4').tobytes(),check=True)
    report[name]={'seconds':len(x)/RATE,'peak_dbfs':peak,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

voices={i:read(ROOT/f'tools/art-source/v300/monster-{i}.wav') for i in range(1,11)}
cloth=read(A/'polish/impact-cloth.wav');metal=read(A/'ambience-v193/duct-stress.wav')
wood=read(A/'surfaces/footstep_wood_002.ogg');plastic=read(A/'polish/impact-plastic.wav')
keys=read(A/'backstage-v270/keys.wav');relay=read(A/'ambience/relay-tick.wav')
sources={'horse':3,'granny':7,'door':8,'rabbit':1,'clown':5,'ossuary':10,'crawler':9,'window':2,'fall':4,'crowd':6,'charge':8,'whisper':7,'crocodile':10}
for family,number in sources.items():
    for variant in range(1,5):
        x=np.zeros(round(RATE*(1.12 if family=='horse' else 1.0 if family=='granny' else .82 if family=='door' else 1.30)))
        offset=.035*(variant-1)
        if family=='granny':
            # Preserve an uncomfortable human voice: no lowered pitch or chorus.
            add(x,voices[number],0,1.,1.,offset);x=band(x,170,6300)
        elif family=='horse':
            add(x,voices[number],0,1.,1.54+variant*.035,offset)
            add(x,metal,.05,.08,1.4);x=band(x,280,9800)
        elif family=='door':
            add(x,wood,0,.8,.9);add(x,voices[number],.025,1.,.87+variant*.03,offset);add(x,cloth,.11,.18)
        elif family=='rabbit':
            add(x,cloth,0,.48,.7);add(x,voices[number],.065,1.,1.10+variant*.02,offset);add(x,plastic,.18,.12)
        elif family=='clown':
            add(x,voices[number],.015,1.,.98+variant*.025,offset);add(x,metal,.10,.12,1.8);add(x,cloth,.025,.20)
        elif family=='crocodile':
            add(x,voices[number],0,1.,.79+variant*.025,offset);add(x,wood,.06,.45);add(x,plastic,.02,.3)
        else:
            add(x,voices[number],0,1.,.90+variant*.055,offset)
            add(x,cloth if family in ['crawler','whisper','crowd'] else metal,.06,.16,.8+variant*.06)
        write(f'{family}-{variant}',x,-5.)
    lead=np.zeros(round(RATE*.72));add(lead,cloth,.01,.5,.7);add(lead,metal,.13,.15,1.1)
    if family in ['horse','ossuary','window']:add(lead,voices[number],.2,.09,1.,.2)
    write(f'{family}-lead',lead,-15.)

for kind,src in [('keys',keys),('paper',cloth),('switch',relay),('hinge',wood),('fabric',cloth),('mask',plastic),('joint',metal)]:
    for variant in range(1,5):
        x=np.zeros(round(RATE*(.18 if kind=='switch' else .75)))
        if kind=='paper':
            t=np.arange(len(x))/RATE
            for at,width,gain in [(.08,.035,.4),(.23+.01*variant,.055,.7),(.47,.045,.32)]:
                x+=band(rng.normal(0,1,len(x)),700,10000)*np.exp(-.5*((t-at)/width)**2)*gain
            add(x,cloth,.03,.13)
        else:
            add(x,src,0,1.,.91+variant*.045,.006*variant)
            if kind=='hinge':add(x,metal,.08,.15,.68+variant*.025)
        write(f'{kind}-{variant}',x,-12. if kind in ['fabric','joint','mask'] else -8.)
for surface in ['concrete','carpet','wood','metal','rubber','plastic']:
    for variant in range(8):
        x=np.zeros(round(RATE*.55))
        add(x,read(A/f'surfaces/footstep_{surface}_{variant%5:03}.ogg'),0,1.,1. if variant<5 else .95+.015*variant,.003*max(0,variant-5))
        if variant>=5:add(x,read(A/f'surfaces/footstep_{surface}_{(variant-3)%5:03}.ogg'),.035,.12,1.05)
        write(f'step-{surface}-{variant}',x,-7.)
(OUT.parent/'audio-provenance.json').write_text(json.dumps({'author':'Ogrebane; Joseph SARDIN; Kenney; original project edits','license':'Existing credited CC0 recordings and original project sound design','source':'https://opengameart.org/content/monster-sound-effects-pack','processing':'32 kHz mono Vorbis q5; finite fades and fixed peak headroom; dry unpitched Granny; separate material and character families','clips':report},indent=2),encoding='utf-8')
print('QUALITY AUDIO',len(report),'prepared clips',flush=True)
