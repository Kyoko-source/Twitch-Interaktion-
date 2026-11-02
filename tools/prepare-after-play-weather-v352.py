"""Quiet looping roof rain from the existing CC0 rain; original distant rumbles."""
from pathlib import Path
import hashlib, json, subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/weather-v352'
OUT.mkdir(parents=True, exist_ok=True)
FFMPEG = ROOT / 'tools/art-source/media-ffmpeg/ffmpeg-compat.exe'
RATE = 24000
rng = np.random.default_rng(352)
report = {}

def encode(name, data):
    data = np.asarray(data, dtype='<f4')
    path = OUT / (name + '.ogg')
    subprocess.run([str(FFMPEG), '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2', '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '3', str(path)], input=data.tobytes(), check=True)
    report[name] = {'seconds': len(data)/RATE, 'peak_dbfs': float(20*np.log10(max(np.abs(data).max(), 1e-9))), 'rms_dbfs': float(20*np.log10(max(np.sqrt(np.mean(data**2)),1e-9))), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def level(data, rms, ceiling):
    data *= 10**(rms/20)/max(np.sqrt(np.mean(data**2)), 1e-9)
    data *= min(1, 10**(ceiling/20)/max(np.abs(data).max(), 1e-9))
    return data

source = ROOT / 'games/kinderparadies/assets/ambience/rain-muted.ogg'
raw = subprocess.check_output([str(FFMPEG), '-v', 'error', '-i', str(source), '-f', 'f32le', '-ar', str(RATE), '-ac', '1', 'pipe:1'])
rain = np.frombuffer(raw, dtype='<f4').astype(np.float64)[RATE:-RATE]
n = int(.8*RATE)
weight = np.linspace(0,1,n)
rain = np.concatenate([rain[n:-n], rain[-n:]*(1-weight)+rain[:n]*weight])
rain = np.tanh(rain/max(rain.std(),1e-9)*.45)
rain = level(np.column_stack([rain, rain]), -23, -9)
encode('soft-roof-rain', rain)

for i, seconds in enumerate([8.4,9.6,10.8]):
    t = np.arange(int(RATE*seconds))/RATE
    f = np.fft.rfftfreq(len(t), 1/RATE)
    def band(low, high):
        spectrum = np.fft.rfft(rng.standard_normal(len(t)))
        spectrum *= (1-np.exp(-(f/low)**4))*np.exp(-(f/high)**4)
        noise = np.fft.irfft(spectrum,n=len(t))
        return noise/max(noise.std(),1e-9)
    envelope = np.zeros_like(t)
    for delay, amount in [(0,.8),(.75+i*.1,.6),(2.1+i*.3,.45),(3.6+i*.25,.25)]:
        elapsed = np.maximum(t-delay,0)
        envelope += amount*(1-np.exp(-elapsed/.65))*np.exp(-elapsed/(1.3+i*.15))
    fade_in = np.clip(t/.8,0,1)
    fade_out = np.clip((seconds-t)/2.2,0,1)
    rumble = (.72*band(28,180)+.30*band(110,410)+.14*band(180,760)+.06*band(350,1100))*envelope*fade_in**2*fade_out**2
    stereo = np.column_stack([rumble, .92*np.roll(rumble,int(.027*RATE))+.035*band(40,190)*envelope*fade_in**2*fade_out**2])
    stereo = level(stereo,-20,-8)
    encode('distant-thunder-'+str(i+1),stereo)

(OUT/'audio-provenance.json').write_text(json.dumps({'rain_source':'Existing assets/ambience/rain-muted.ogg, Joseph SARDIN, CC0-1.0; original source https://bigsoundbank.com/rain-on-puddle-s1290.html. Trimmed and crossfaded to loop, level adjusted.','thunder':'Original procedural distant rolls; filtered noise and slow envelopes, no external samples.','tracks':report},indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('Roof rain: derivative of the existing CC0-1.0 rain recording by Joseph SARDIN / BigSoundBank. See assets/ambience/provenance.json and distribution/Quellen.txt.\nThunder: original procedural project audio, no third-party samples.\n',encoding='utf-8')
print(json.dumps(report,indent=2))
