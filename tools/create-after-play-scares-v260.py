"""Eight distinct original edits of the game's existing CC0 field recordings.
No oscillator soundtrack: layered creature voice, breath, chain and metal.
"""
import json, hashlib, subprocess, wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'games/kinderparadies/assets';OUT=A/'scares-v260';OUT.mkdir(exist_ok=True)
RATE=32000;DURATION=2.4;N=int(RATE*DURATION)
SOURCES={'voice':A/'finale/cook-scream.wav','chain':A/'ambience-v180/chain.wav','breath':A/'ambience-v180/breathing.wav','duct':A/'ambience-v193/duct-stress.wav','cutlery':A/'ambience-v193/dish-rattle.wav','motor':A/'ambience-v193/motor-stop.wav'}
def decode(path):
    data=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(RATE),'-'],capture_output=True,check=True).stdout
    return np.frombuffer(data,dtype='<f4').astype(float)
RAW={key:decode(path) for key,path in SOURCES.items()}
def layer(key,speed=1,at=0,gain=1,reverse=False):
    src=RAW[key];src=src[::-1] if reverse else src
    src=np.interp(np.arange(0,len(src)-1,speed),np.arange(len(src)),src)
    src=src/(np.max(np.abs(src))+.00001)*gain
    count=min(len(src),N-int(at*RATE));src=src[:count].copy()
    fade=min(250,count//3);src[:fade]*=np.linspace(0,1,fade);src[-min(5000,count//3):]*=np.linspace(1,0,min(5000,count//3))
    result=np.zeros(N);start=int(at*RATE);result[start:start+count]=src
    return result
RECIPES={
 'ragged-scream': [('voice',.78,0,1,False),('voice',1.13,.037,.35,False),('chain',1.4,.01,.45,False)],
 'metal-shriek': [('duct',1.4,0,.7,False),('voice',1.37,.035,1,False),('chain',.7,.06,.35,False)],
 'gasp-snap': [('breath',2.4,0,.4,True),('voice',1.0,.04,1,False),('cutlery',1.8,0,.55,False)],
 'crawl-scream': [('voice',.58,0,1,False),('chain',.85,0,.7,False),('breath',1.2,.08,.45,False)],
 'window-hit': [('cutlery',.8,0,.9,False),('voice',1.55,.02,.8,False),('duct',1.8,.03,.4,False)],
 'crowd-burst': [('voice',.73,0,.65,False),('voice',1.15,.045,.7,False),('voice',1.40,.13,.6,False),('chain',1.8,0,.45,False)],
 'bass-roar': [('voice',.46,0,.8,False),('voice',.91,.02,.8,False),('motor',1.5,0,.45,False)],
 'dry-impact': [('motor',2.0,0,.75,False),('chain',1.1,0,.75,False),('voice',1.2,.02,.9,False)]}
provenance={}
for name,recipe in RECIPES.items():
    raw=sum(layer(*part) for part in recipe)
    # Soft saturation and short room reflections, retaining clear initial attack.
    raw=np.tanh(raw*1.6);wet=raw.copy()
    for delay,gain in [(.043,.22),(.087,.13),(.137,.07)]:
        d=int(delay*RATE);wet[d:]+=raw[:-d]*gain
    right=wet.copy();right[53:]+=raw[:-53]*.11
    stereo=np.stack([wet,right],axis=1);stereo*=10**(-1.5/20)/(np.max(np.abs(stereo))+.00001)
    stereo[-6400:]*=np.linspace(1,0,6400)[:,None]
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes((stereo*32767).astype('<i2').tobytes())
    provenance[path.name]={'duration':DURATION,'peak_dbfs':round(float(20*np.log10(np.max(np.abs(stereo)))),2),'rms_dbfs':round(float(20*np.log10(np.sqrt(np.mean(stereo**2)))) ,2),'layers':[{'source':str(SOURCES[k].relative_to(A)),'source_sha256':hashlib.sha256(SOURCES[k].read_bytes()).hexdigest(),'speed':speed,'delay':at,'gain':gain,'reversed':reverse} for k,speed,at,gain,reverse in recipe]}
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('Original After Play layered sound edits. Source recordings CC0 1.0.\nCreature voice: A New Room, submitted by qubodup: https://opengameart.org/content/evil-creature\nField recordings: Joseph SARDIN / BigSoundBank. See assets/ambience-v180/provenance.json and assets/ambience-v193/provenance.json for original URLs and hashes.\nSee provenance.json for exact local input hashes, edits, measured peak and RMS.\n',encoding='utf-8')
print(json.dumps({k:{p:v[p] for p in ['peak_dbfs','rms_dbfs']} for k,v in provenance.items()},indent=2))
