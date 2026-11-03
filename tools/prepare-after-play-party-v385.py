"""Analyse creator-supplied party music; export amplitude/beat cues, not lyrics."""
from pathlib import Path
import subprocess, tempfile, shutil, json, hashlib
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path.home()/'Desktop/party.mp3'
OUT=ROOT/'games/kinderparadies/assets/party-v385'
OUT.mkdir(parents=True,exist_ok=True)
FFMPEG=ROOT/'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'
shutil.copyfile(SOURCE,OUT/'party.mp3')
subprocess.run([str(FFMPEG),'-y','-v','error','-i',str(SOURCE),'-c:a','libvorbis','-q:a','1.5','-ar','32000',str(OUT/'party-web.ogg')],check=True)
with tempfile.TemporaryDirectory(prefix='after-play-party-') as temp:
 pcm=Path(temp)/'mono.f32'
 subprocess.run([str(FFMPEG),'-y','-v','error','-i',str(SOURCE),'-ac','1','-ar','11025','-f','f32le',str(pcm)],check=True)
 signal=np.fromfile(pcm,dtype='<f4')
hop=220;window=1100
frames=np.lib.stride_tricks.sliding_window_view(signal,window)[::hop]
rms=np.sqrt((frames**2).mean(axis=1))
spectrum=np.abs(np.fft.rfft(frames*np.hanning(window),axis=1))
frequencies=np.fft.rfftfreq(window,1/11025)
bass=np.sqrt((spectrum[:,(frequencies>40)&(frequencies<180)]**2).mean(axis=1))
time=np.arange(len(rms))*hop/11025
onset=np.maximum(0,bass-np.roll(bass,3));onset[:3]=0
threshold=np.quantile(onset,.70)
peaks=[]
for i in range(2,len(onset)-2):
 if onset[i]>threshold and onset[i]==max(onset[i-2:i+3]):
  if not peaks or time[i]-peaks[-1]>.26:peaks.append(float(time[i]))
norm=rms/max(float(np.quantile(rms,.95)),.001)
sample_time=np.arange(0,len(signal)/11025,.25)
energy=np.interp(sample_time,time,norm).clip(0,1)
# Sudden sustained increases after a quieter build/break identify drops. Keep
# actual energy and kick timing alongside them, including quieter breakdowns.
transitions=[]
for i,t in enumerate(sample_time):
 if i<24 or i+12>=len(energy):continue
 before=float(energy[i-20:i-4].mean());after=float(energy[i:i+12].mean())
 score=after-before
 if after>.65 and score>.23:transitions.append((score,float(t)))
drops=[]
for score,t in sorted(transitions,reverse=True):
 if all(abs(t-other)>14 for other in drops):drops.append(round(t,2))
drops.sort()
body='extends RefCounted\n\n# Analysed from creator-provided party.mp3, sampled at 4 Hz.\n'
body+='const DURATION:=%.4f\n'%(len(signal)/11025)
body+='const BEATS:='+json.dumps([round(t,3) for t in peaks],separators=(',',':'))+'\n'
body+='const ENERGY:='+json.dumps([round(float(v),3) for v in energy],separators=(',',':'))+'\n'
body+='const DROPS:='+json.dumps(drops)+'\n'
(OUT/'track_cues.gd').write_text(body,encoding='utf-8')
(OUT/'party-provenance.json').write_text(json.dumps({'source':'creator-provided:party.mp3','author':'Recording supplied by the game creator','sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'duration_seconds':len(signal)/11025,'beat_count':len(peaks),'drop_candidates_seconds':drops},indent=2),encoding='utf-8')
print(json.dumps({'duration':len(signal)/11025,'beats':len(peaks),'drops':drops,'web_bytes':(OUT/'party-web.ogg').stat().st_size}))
print('Energy every 4 s:',[(int(t),round(float(np.interp(t,sample_time,energy)),2)) for t in range(0,int(sample_time[-1]),4)])
