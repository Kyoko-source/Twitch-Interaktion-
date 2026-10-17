"""Fetch credited CC0 field recordings and bake restrained game edits.

Requires ffmpeg on PATH; originals stay in ignored tools/art-source.
License pages and download hashes are retained for reproducibility.
"""
import hashlib, json, math, random, re, shutil, struct, subprocess, urllib.request, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'tools/art-source/nachtwache-audio'
OUT = ROOT / 'games/kinderparadies/assets/ambience'
RAW.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
FFMPEG = shutil.which('ffmpeg')
assert FFMPEG, 'ffmpeg must be installed'
SOURCES = [
    ('children-laugh', 'laughter-of-children-s1660.html', 4.8, 4800, -22),
    ('children-cry', '5-year-old-child-crying-5-s2552.html', 8, 3600, -24),
    ('door-creak', 'creaking-door-2-s3205.html', 3.8, 3300, -25),
    ('ventilation', 'ventilation-5-s3598.html', 16, 1200, -28),
    ('rain-muted', 'rain-on-puddle-s1290.html', 14, 650, -31),
]
manifest=[]
for name, page, duration, cutoff, loudness in SOURCES:
    url='https://bigsoundbank.com/'+page
    html=urllib.request.urlopen(url).read().decode('utf8')
    assert re.search(r'CC0\s*\(public domain\)', html), 'Missing CC0 declaration: '+url
    (RAW/(name+'-license.html')).write_text(html, encoding='utf8')
    link=re.search(r'["\'](/UPLOAD/ogg/\d+\.ogg[^"\']*)',html).group(1)
    original=RAW/(name+'.ogg')
    if not original.exists(): original.write_bytes(urllib.request.urlopen('https://bigsoundbank.com'+link).read())
    filters=f'highpass=f=65,lowpass=f={cutoff},loudnorm=I={loudness}:TP=-5:LRA=8,afade=t=in:d=0.12,afade=t=out:st={duration-.5}:d=0.5'
    subprocess.run([FFMPEG,'-v','error','-y','-i',str(original),'-t',str(duration),'-af',filters,'-ac','1','-ar','24000','-c:a','libvorbis','-q:a','5',str(OUT/(name+'.ogg'))],check=True)
    manifest.append(dict(file=name+'.ogg',author='Joseph SARDIN'+(' & Axeline T.' if name=='door-creak' else ''),license='CC0-1.0',source=url,original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),processing=filters))

# Original quiet plastic contact, pipe contractions and fluorescent relay ticks.
for name, duration in [('crawl-contact',.4),('pipe-knock',1.2),('relay-tick',.45)]:
    rng=random.Random(1600);rate=24000;data=[];low=0.0
    for i in range(round(rate*duration)):
        t=i/rate;low=low*.9+rng.uniform(-1,1)*.1
        if name=='crawl-contact': value=low*.36*(math.sin(math.pi*t/duration)**2)
        elif name=='relay-tick': value=(low*.25+math.sin(t*math.tau*720)*.06)*math.exp(-t*45)
        else: value=(low*.1+math.sin(t*math.tau*110)*.16+math.sin(t*math.tau*293)*.07)*math.exp(-t*9)
        value*=min(1,t/.004)*min(1,(duration-t)/.04)
        data.append(struct.pack('<h',round(max(-.8,min(.8,value))*32767)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(data))
    manifest.append(dict(file=name+'.wav',author='Aviary project',license='Original project sound',processing='Deterministic material foley; no music'))
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
(OUT/'LICENSE.txt').write_text('Field recordings: Joseph SARDIN / BigSoundBank (door creak also Axeline T.).\nCC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/\nSource pages, edits and source hashes: provenance.json.\nOriginal plastic/pipe/relay foley: Aviary project.\nwindow-watcher-face.png: original generated project artwork; see art/PROMPTS-WATCHER.md.\n',encoding='utf8')
print('Prepared eight ambience assets with provenance.')
