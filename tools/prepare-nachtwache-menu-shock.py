"""Original non-melodic menu scare sting; deterministic PCM, no borrowed recording."""
from pathlib import Path
import wave,numpy as np
out=Path(__file__).resolve().parents[1]/'games/kinderparadies/assets/intro/menu-shock.wav'
sr=48000;t=np.arange(int(sr*1.22))/sr;rng=np.random.default_rng(194)
noise=rng.normal(0,1,len(t));filtered=np.convolve(noise,np.ones(7)/7,mode='same')
phase=2*np.pi*np.cumsum(210*np.exp(-t*2.8)+38)/sr
voiced=sum(np.sin(phase*k+.3*k)*np.exp(-((k-5)/3.5)**2)/k for k in range(1,15))
env=(1-np.exp(-t*260))*np.exp(-t*3.8)
crack=noise*np.exp(-t*62)*.55
rasp=filtered*(.25+.75*np.maximum(0,np.sin(2*np.pi*t*37)))*env*.8
impact=np.sin(phase*.45)*env*.22
x=voiced*env*.9+rasp+crack+impact
pan=.2*np.sin(t*15);audio=np.stack([x*(1-pan),x*(1+pan)],axis=1)
audio*=.88/max(np.max(np.abs(audio)),1e-6)
assert np.max(np.abs(audio))<1
with wave.open(str(out),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((audio*32767).astype('<i2').tobytes())
print(out,len(t)/sr,'seconds, peak',np.max(np.abs(audio)))