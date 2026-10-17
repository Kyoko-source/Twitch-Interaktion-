"""Credited CC0 field recordings, restrained mono edits and mounted kitchen art."""
from pathlib import Path
import hashlib,json,re,urllib.request,wave
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'games/kinderparadies/assets/ambience-v180';RAW=ROOT/'tools/art-source/audio-v180'
OUT.mkdir(exist_ok=True);RAW.mkdir(parents=True,exist_ok=True)
sources=[('fridge','fridge-s1157.html',14,-28,1200),('cutlery','cutlery-manipulations-on-plate-s1193.html',8,-26,4300),('chain','heavy-chain-s0359.html',4,-25,3200),('breathing','man-breathing-s2195.html',9,-25,3500),('floor-creak','squeaking-parquet-7-s3057.html',1.6,-25,3800),('fly','fly-and-glass-s0759.html',9,-30,2200)]
processed={};manifest=[];rate=24000
def write(name,data):
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((np.clip(data,-.85,.85)*32767).astype('<i2').tobytes())
for name,page,duration,loudness,cutoff in sources:
    url='https://bigsoundbank.com/'+page;html=urllib.request.urlopen(url).read().decode('utf8')
    assert re.search(r'CC0\s*\(public domain\)',html),url
    (RAW/(name+'-license.html')).write_text(html,encoding='utf8')
    link=re.search(r'(/UPLOAD/(?:bwf-en|wav)/\d+\.wav)',html).group(1);original=RAW/(name+'.wav')
    if not original.exists():original.write_bytes(urllib.request.urlopen('https://bigsoundbank.com'+link).read())
    with wave.open(str(original),'rb') as f:
        width=f.getsampwidth();channels=f.getnchannels();hz=f.getframerate();raw=f.readframes(min(f.getnframes(),round(hz*duration)))
    if width==3:
        b=np.frombuffer(raw,dtype=np.uint8).reshape(-1,3);samples=(b[:,0].astype(np.int32)|(b[:,1].astype(np.int32)<<8)|(b[:,2].astype(np.int32)<<16));samples=np.where(samples&0x800000,samples-0x1000000,samples)/8388608
    else:
        assert width in [2,4];samples=np.frombuffer(raw,dtype='<i2' if width==2 else '<i4').astype(np.float64)/(32768 if width==2 else 2147483648)
    samples=samples.reshape(-1,channels).mean(axis=1);n=round(len(samples)*rate/hz);samples=np.interp(np.arange(n)*hz/rate,np.arange(len(samples)),samples)
    spectrum=np.fft.rfft(samples);freq=np.fft.rfftfreq(n,1/rate);spectrum*=np.clip(freq/60,0,1)**2/(1+(freq/cutoff)**6);samples=np.fft.irfft(spectrum,n)
    rms=np.sqrt(np.mean(samples*samples));samples*=min(10**(loudness/20)/max(rms,1e-8),.65/max(abs(samples).max(),1e-8))
    fade=min(round(.06*rate),n//4);samples[:fade]*=np.linspace(0,1,fade);samples[-fade:]*=np.linspace(1,0,fade)
    write(name,samples);processed[name]=samples
    manifest.append(dict(file=name+'.wav',author='Joseph SARDIN',license='CC0-1.0',source=url,original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),processing=f'Mono 24 kHz, 60 Hz highpass, {cutoff} Hz lowpass, RMS target {loudness} dBFS, edge fades; duration {n/rate:.2f}s'))
# A short layered sting uses the credited recordings plus an original low impact.
n=round(rate*1.16);t=np.arange(n)/rate
metal=np.interp(np.arange(n)*1.6,np.arange(len(processed['chain'])),processed['chain'],right=0)
breath=np.interp(np.arange(n)*1.3,np.arange(len(processed['breathing'])),processed['breathing'],right=0)
rng=np.random.default_rng(1800);impact=(np.sin(2*np.pi*(48*t+18*(1-np.exp(-t*12))))*.65+rng.uniform(-1,1,n)*.12)*np.exp(-t*7)
data=metal*3+breath*4+impact;data*=np.minimum(1,t/.008)*np.minimum(1,(1.16-t)/.08);data*=.76/max(abs(data).max(),1e-8);write('door-shock',data)
manifest.append(dict(file='door-shock.wav',author='Aviary / Joseph SARDIN',license='Original mix; source recordings CC0-1.0',processing='Layered chain, breathing and original low impact; peak -2.4 dBFS, 1.16 seconds'))
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
(OUT/'LICENSE.txt').write_text('Field recordings: Joseph SARDIN / BigSoundBank, CC0 1.0. https://creativecommons.org/publicdomain/zero/1.0/\nIndividual source pages, source hashes and processing: provenance.json.\nOriginal door impact and mix: Aviary project.\n',encoding='utf8')
# Opaque typographic props belong on real wall boards, never floating text.
FONT=ROOT/'games/kinderparadies/assets/Oswald.ttf';ART=ROOT/'games/kinderparadies/assets/annex'
for filename,title,lines in [('hygiene-board','KÜCHENDIENST',['07:00  LIEFERUNG PRÜFEN','12:00  TÖPFE REINIGEN','18:00  KÜCHE SCHLIESSEN','','LETZTE KONTROLLE:  -- / --']),('old-menu','HEUTE IM KINDERPARADIES',['KROKO-NUDELN','GEBURTSTAGSPIZZA','BUNTE TELLER','','NUR FÜR UNSERE KLEINEN GÄSTE'])]:
    image=Image.new('RGB',(1024,768),(137,126,97));d=ImageDraw.Draw(image)
    for i in range(1600):
        x=int(rng.integers(0,1024));y=int(rng.integers(0,768));d.ellipse((x,y,x+int(rng.integers(1,10)),y+int(rng.integers(1,9))),fill=(115,105,80))
    d.rectangle((22,22,1001,745),outline=(45,51,43),width=9);d.text((512,100),title,font=ImageFont.truetype(str(FONT),53),anchor='mm',fill=(37,48,43))
    for i,line in enumerate(lines):d.text((80,210+i*80),line,font=ImageFont.truetype(str(FONT),38),fill=(47,45,35))
    image.save(ART/(filename+'.png'))
image=Image.new('RGB',(640,380),(8,18,15));d=ImageDraw.Draw(image)
for i,line in enumerate(['KINDERPARADIES  /  TERMINAL 01','EMPFANG - NACHTDIENST','','NETZWERK: NICHT VERBUNDEN','LETZTE ANMELDUNG: 18:03','> _']):
    d.text((25,24+i*52),line,font=ImageFont.truetype(str(FONT),24),fill=(112,157,113))
for y in range(0,380,4):d.line((0,y,640,y),fill=(7,17,13))
image.save(ART/'terminal.png')
print('Prepared six CC0 recordings, layered door sting and two mounted kitchen boards.')
