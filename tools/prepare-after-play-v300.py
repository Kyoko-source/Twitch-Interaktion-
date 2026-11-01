"""Verified CC0 materials and thirty distinct creature edits for After Play 3.0."""
from pathlib import Path
import importlib.util, json, hashlib, zipfile, subprocess, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'games/kinderparadies/assets'
OUT=A/'revamp-v300';OUT.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('art',Path(__file__).with_name('fetch-nachtwache-art.py'))
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
manifest=json.loads((A/'polyhaven-provenance.json').read_text('utf-8'))
for name in ['rusty_painted_metal','dirty_tiles','metal_plate']:
 entry=art.fetch_asset(('material',name));manifest=[x for x in manifest if x['id']!=name]+[entry]
for name in ['painted_wooden_cabinet_02']:
 entry=art.fetch_asset(('model',name));manifest=[x for x in manifest if x['id']!=name]+[entry]
(A/'polyhaven-provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
cache=ROOT/'tools/art-source/v300';cache.mkdir(parents=True,exist_ok=True)
archive=cache/'monster_sfx_pack.zip'
if not archive.exists():archive.write_bytes(art.get('https://opengameart.org/sites/default/files/monster_sfx_pack.zip'))
z=zipfile.ZipFile(archive)
for name in z.namelist():
 if name.startswith('monster_sfx_pack/') and name.endswith('.wav'):
  (cache/Path(name).name).write_bytes(z.read(name))
RATE=32000
def decode(p):
 b=subprocess.run(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar',str(RATE),'-f','f32le','-'],capture_output=True,check=True).stdout
 a=np.frombuffer(b,dtype='<f4').astype(float)
 a=a/(max(np.max(np.abs(a)),.001));return a
raw={i:decode(cache/f'monster-{i}.wav') for i in range(1,11)}
field={k:decode(A/p) for k,p in {'cloth':'surfaces/footstep_carpet_000.ogg','metal':'ambience-v193/duct-stress.wav','glass':'ambience-v193/dish-rattle.wav','breath':'ambience-v180/breathing.wav','chain':'ambience-v180/chain.wav','wood':'surfaces/footstep_wood_002.ogg','motor':'ambience-v193/motor-stop.wav'}.items()}
families={'rabbit':(1,'cloth',.91),'clown':(2,'glass',1.06),'ossuary':(3,'metal',.68),'crawler':(4,'cloth',.77),'window':(5,'glass',1.12),'fall':(6,'chain',.90),'crowd':(7,'wood',.86),'charge':(8,'motor',.83),'whisper':(9,'breath',1.07),'crocodile':(10,'motor',.61)}
def stretch(a,speed):return np.interp(np.arange(0,len(a)-1,speed),np.arange(len(a)),a)
def add(dst,src,delay,gain):
 start=int(delay*RATE);n=min(len(src),len(dst)-start)
 if n<=0:return
 b=src[:n].copy();f=min(160,n//8);b[:f]*=np.linspace(0,1,f)
 f=min(3200,n//4);b[-f:]*=np.linspace(1,0,f);dst[start:start+n]+=b*gain
def write(name,x):
 x=np.tanh(x*1.15);x*=10**(-2.0/20)/max(np.max(np.abs(x)),.001)
 fade=min(4800,len(x)//4);x[-fade:]*=np.linspace(1,0,fade)
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((x*32767).astype('<i2').tobytes())
 return {'duration':round(len(x)/RATE,3),'peak_dbfs':round(float(20*np.log10(np.max(np.abs(x)))),2),'rms_dbfs':round(float(20*np.log10(np.sqrt(np.mean(x*x)))) ,2),'sha256':hashlib.sha256((OUT/(name+'.wav')).read_bytes()).hexdigest()}
report={}
for index,(family,(voice,foley,speed)) in enumerate(families.items()):
 for variant in range(3):
  n=int(RATE*(1.45+index*.075+variant*.17));x=np.zeros(n)
  primary=stretch(raw[voice],speed*(1+variant*.07))
  # Each family has its own vocal recording; variants change edit, rhythm and
  # physical secondary source as well as speed. No common cook scream layer.
  if variant==1:primary=primary[int(len(primary)*.10):]
  add(x,primary,0 if variant!=2 else .065,.92)
  add(x,stretch(field[foley],.88+variant*.16),.012,.50)
  if variant==2:add(x,stretch(raw[(voice+3)%10+1],1.17),.31,.30)
  if family=='crowd':add(x,stretch(raw[voice],1.31),.17,.42)
  if family=='ossuary':add(x,stretch(field['chain'],.7),.28,.38)
  dry=x.copy()
  for delay,gain in [(.049,.15),(.103,.08)]:
   d=int(delay*RATE);x[d:]+=dry[:-d]*gain
  key=f'{family}-{variant+1}';report[key]=write(key,x)
  report[key].update({'voice':f'Ogrebane monster-{voice}.wav','foley':foley,'variant':variant+1})
 lead=np.zeros(int(RATE*.58));add(lead,stretch(field[foley],.7),0,.65)
 add(lead,stretch(field['breath'],1.2+index*.04),.08,.3)
 report[family+'-lead']=write(family+'-lead',lead)
(OUT/'provenance.json').write_text(json.dumps({'author':'Ogrebane; recorded Foley by Joseph SARDIN and Kenney; original edits for After Play','license':'CC0-1.0','source':'https://opengameart.org/content/monster-sound-effects-pack','archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'recording_sha256':{str(i):hashlib.sha256((cache/f'monster-{i}.wav').read_bytes()).hexdigest() for i in raw},'outputs':report},indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('After Play 3.0: original models, shaders and sound edits.\nMonster voice recordings: Ogrebane, Monster Sound Effects Pack, CC0 1.0.\nhttps://opengameart.org/content/monster-sound-effects-pack\nFoley: Joseph SARDIN / BigSoundBank and Kenney Impact Sounds, CC0.\nSee existing Ambience-v180, Ambience-v193 and Footsteps notices.\nRusty Painted Metal, Dirty Tiles, Metal Plate and Painted Wooden Cabinet: Poly Haven, CC0 1.0.\nhttps://polyhaven.com/a/rusty_painted_metal\nhttps://polyhaven.com/a/dirty_tiles\nhttps://polyhaven.com/a/metal_plate\nhttps://polyhaven.com/a/painted_wooden_cabinet_02\nOriginal source URLs, archive hash and edit measurements: private provenance.json.\n',encoding='utf-8')
print('V300 prepared:',len(report),'audio clips, ten independent voice recordings and three verified PBR materials plus one scanned cabinet',flush=True)
