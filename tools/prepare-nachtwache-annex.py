"""Original screen masks, mounted signs and quiet mechanical annex foley."""
from pathlib import Path
import math, random, struct, wave
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/annex'
OUT.mkdir(exist_ok=True)
FONT=ROOT/'games/kinderparadies/assets/Oswald.ttf'
for filename,text in [('no-signal','NO SIGNAL'),('kitchen-sign','KÜCHE'),('cinema-sign','LICHTSPIEL')]:
    image=Image.new('RGB',(1024,512),(0,0,0) if filename=='no-signal' else (94,111,98))
    draw=ImageDraw.Draw(image);font=ImageFont.truetype(str(FONT),90 if filename=='no-signal' else 125)
    draw.text((512,256),text,font=font,anchor='mm',fill=(245,245,245) if filename=='no-signal' else (213,202,171))
    if filename!='no-signal':draw.rectangle((20,20,1003,491),outline=(33,47,43),width=10)
    image.save(OUT/(filename+'.png'))
rate=24000
for name,duration in [('stir-pot',7),('projector',8),('clown-sting',1.6)]:
    rng=random.Random(1701);samples=[];low=0.0
    for i in range(round(rate*duration)):
        t=i/rate;noise=rng.uniform(-1,1);low=.91*low+.09*noise
        if name=='stir-pot':
            phase=t*math.tau*.24
            value=low*(.1+.16*math.sin(phase)**6)+math.sin(t*math.tau*1190)*.035*max(0,math.sin(phase*2))**40
        elif name=='projector':
            value=low*.13+(math.sin(t*math.tau*84)+.2*math.sin(t*math.tau*168))*.019
            value+=noise*.045*max(0,math.sin(t*math.tau*12))**24
        else:
            value=(low*.9+noise*.18)*math.exp(-t*4)+math.sin(math.tau*(55*t+35*(1-math.exp(-t*8))))*.4*math.exp(-t*5)
        value*=min(1,t/.01)*min(1,(duration-t)/.06)
        samples.append(struct.pack('<h',round(max(-.9,min(.9,value))*32767)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as file:
        file.setnchannels(1);file.setsampwidth(2);file.setframerate(rate);file.writeframes(b''.join(samples))
(OUT/'LICENSE.txt').write_text('Original project screen/sign artwork and deterministic foley.\nClown facial albedo: generated original project artwork; see art/PROMPTS-ANNEX.md.\n',encoding='utf8')
print('Prepared annex screen, signs and three original sound files.')
