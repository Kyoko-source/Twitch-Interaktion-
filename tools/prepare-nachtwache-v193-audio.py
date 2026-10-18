"""Verified CC0 field recordings, short mono edits and quiet secondary details."""
from pathlib import Path
import hashlib,json,re,urllib.request,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'tools/art-source/audio-v193';RAW.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'games/kinderparadies/assets/ambience-v193';OUT.mkdir(exist_ok=True)
rate=24000;manifest=[]
sources=[('ghost-walk','steps-on-a-wooden-floor-4-s1518.html',2,7,-22,4300),('ghost-run','fast-steps-on-concrete-s1319.html',3,6,-23,3800),('leak','drops-of-water-3-s1386.html',0,11,-30,4000),('metal-door','creaking-metallic-door-s0616.html',0,5,-26,3200)]
def read(path,start=0,duration=8):
 with wave.open(str(path),'rb') as f:
  width=f.getsampwidth();channels=f.getnchannels();hz=f.getframerate();f.setpos(min(round(start*hz),f.getnframes()));raw=f.readframes(round(duration*hz))
 if width==3:
  b=np.frombuffer(raw,dtype=np.uint8).reshape(-1,3);n=b[:,0].astype(np.int32)|(b[:,1].astype(np.int32)<<8)|(b[:,2].astype(np.int32)<<16);n=np.where(n&0x800000,n-0x1000000,n)/8388608
 else:n=np.frombuffer(raw,dtype='<i2' if width==2 else '<i4').astype(float)/(32768 if width==2 else 2147483648)
 n=n.reshape(-1,channels).mean(axis=1);return np.interp(np.arange(round(len(n)*rate/hz))*hz/rate,np.arange(len(n)),n)
def save(name,samples,loudness,cutoff):
 n=len(samples);freq=np.fft.rfftfreq(n,1/rate);data=np.fft.irfft(np.fft.rfft(samples)*np.minimum(1,freq/65)**2/(1+(freq/cutoff)**6),n)
 data*=min(10**(loudness/20)/max(np.sqrt(np.mean(data*data)),1e-8),.7/max(abs(data).max(),1e-8))
 fade=min(round(.12*rate),n//4);data[:fade]*=np.linspace(0,1,fade);data[-fade:]*=np.linspace(1,0,fade)
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((np.clip(data,-.85,.85)*32767).astype('<i2').tobytes())
for name,page,start,duration,loudness,cutoff in sources:
 url='https://bigsoundbank.com/'+page;html=urllib.request.urlopen(url,timeout=30).read().decode('utf8');assert re.search(r'CC0\s*\(public domain\)',html),url
 (RAW/(name+'-license.html')).write_text(html,encoding='utf8');link=re.search(r'(/UPLOAD/(?:bwf-en|wav)/\d+\.wav)',html).group(1);original=RAW/(name+'.wav')
 if not original.exists():original.write_bytes(urllib.request.urlopen('https://bigsoundbank.com'+link,timeout=60).read())
 save(name,read(original,start,duration),loudness,cutoff)
 manifest.append(dict(file=name+'.wav',author='Joseph SARDIN',license='CC0-1.0',source=url,original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),processing=f'Mono 24 kHz, cropped from {start}s, {duration}s maximum, RMS {loudness}dBFS, HP65Hz/LP{cutoff}Hz, fades'))
# Additional quiet edits retain the original source provenance beside the release.
old=ROOT/'tools/art-source/audio-v180'
for name,source,start,duration,level,cutoff in [('dish-rattle','cutlery',2,2.1,-28,3000),('duct-stress','chain',.4,2.5,-29,1300),('motor-stop','fridge',4,4,-31,900)]:
 samples=read(old/(source+'.wav'),start,duration)
 if name=='motor-stop':samples*=np.linspace(1,.05,len(samples))
 save(name,samples,level,cutoff)
 manifest.append(dict(file=name+'.wav',author='Joseph SARDIN',license='CC0-1.0',source_provenance='../ambience-v180/provenance.json',source_file=source+'.wav',processing=f'Alternate crop at {start}s, filtered quiet edit'))
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
(OUT/'LICENSE.txt').write_text('Field recordings by Joseph SARDIN / BigSoundBank, CC0 1.0.\nhttps://creativecommons.org/publicdomain/zero/1.0/\nSources, hashes and edits: provenance.json; alternate edits also retain ambience-v180 provenance.\n',encoding='utf8')
print('Prepared',len(manifest),'field-recording edits with provenance.')
