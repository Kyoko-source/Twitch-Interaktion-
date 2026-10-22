"""Typeset original, physically mounted signs; no third-party illustrations."""
from pathlib import Path
import random
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/polish-v240'
FONT=ROOT/'games/kinderparadies/assets/Oswald.ttf'
rng=random.Random(240)

def paper(size,colour):
    im=Image.new('RGB',size,colour);d=ImageDraw.Draw(im)
    for i in range(size[0]*size[1]//80):
        x=rng.randrange(size[0]);y=rng.randrange(size[1]);v=rng.randrange(55,120);d.ellipse((x,y,x+1,y+1),fill=(v+25,v+17,v))
    d.rectangle((18,18,size[0]-19,size[1]-19),outline=(58,49,34),width=3)
    return im,d

def center(draw,value,y,size,width,colour=(39,34,26)):
    font=ImageFont.truetype(str(FONT),size);box=draw.textbbox((0,0),value,font=font)
    draw.text(((width-(box[2]-box[0]))/2,y),value,font=font,fill=colour)

OUT.mkdir(exist_ok=True)
im,d=paper((960,600),(179,165,126))
center(d,'HAPPY',50,124,960);center(d,'UNSER MASKOTTCHEN',220,51,960)
d.line((100,340,860,340),fill=(69,48,32),width=4)
center(d,'BITTE NICHT BEKLETTERN',378,50,960,(105,29,25));center(d,'Die Aufsicht endet am Ausgang.',474,30,960)
im.save(OUT/'mascot-sign.png')
im,d=paper((1200,600),(162,163,139))
center(d,'TECHNISCHER DIENST',43,77,1200)
for i,value in enumerate(['LUEFTUNG  /  FILTERWECHSEL AUSSTEHEND','KINO  /  PROJEKTOR NICHT ABSCHALTEN','SPIELANLAGE  /  POLSTER PRUEFEN','STOERUNGEN NUR SCHRIFTLICH MELDEN']):
    center(d,value,180+i*78,34,1200)
im.save(OUT/'maintenance-board.png')
im,d=paper((768,1024),(157,146,114))
center(d,'HAPPYLAND LICHTSPIEL',58,46,768)
for i,value in enumerate(['LETZTE','VORSTELLUNG']):center(d,value,205+i*112,89 if i==0 else 73,768,(88,21,25))
for x in [90,678]:
    d.rectangle((x-20,430,x+20,790),fill=(40,36,27))
    for y in range(445,790,43):d.rectangle((x-11,y,x+11,y+21),fill=(157,146,114))
center(d,'NOCH EINMAL.',512,67,768)
center(d,'FUER IMMER.',634,67,768,(88,21,25))
center(d,'Bitte bleiben Sie auf Ihren Plaetzen.',881,29,768)
im.save(OUT/'cinema-poster.png')
(OUT/'LICENSE.txt').write_text('Original After Play geometry: giant sewn rabbit mascot, fur tufts, phone-grip refinement, handset refinement and room dressing.\nOriginal typeset signage; font Oswald (OFL, bundled).\nFur, carpet and metal surface photographs: Poly Haven, CC0 1.0.\nDetailed source attribution and hashes: ../polyhaven-provenance.json.\nNo paid marketplace models or extracted game characters are included.\n',encoding='utf8')
