"""Original Happyland print layouts. Uses only the bundled OFL typefaces."""
from pathlib import Path
import math, random, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/restoration-v350'
OUT.mkdir(exist_ok=True)
FONT = ROOT / 'games/kinderparadies/assets/Oswald.ttf'
SERIF = ROOT / 'games/kinderparadies/assets/presentation-v250/BodoniModa.ttf'
# id, title, supporting copy, physical print category, pictogram
SIGNS = [
 ('hours','HEREINSPAZIERT!','Täglich 10:00 – 18:00|Dein Tag im Kinderparadies','poster','sun'),
 ('hours-wrong','HEREINSPAZIERT!','Täglich 03:33 – 03:33|Dein Tag im Kinderparadies','poster','sun'),
 ('rules','KLEINE FÜSSE. GROSSE ABENTEUER.','Nur mit Socken spielen.|Essen und Schuhe bleiben draußen.','poster','stars'),
 ('party','PARTY RAUM','Geburtstage / Feiern','enamel','balloon'),
 ('birthday','DEIN GROSSER TAG','Wir haben auf dich gewartet.','poster','balloon'),
 ('nursery','DIE KLEINEN','Spielen. Staunen. Träumen.','poster','stars'),
 ('pickup','LIEBE ELTERN','Bitte alle Kinder abholen.|Heute geht ein schöner Tag zu Ende.','poster','sun'),
 ('duty','NACHTDIENST','Keine Anomalie: GRÜN|Anomalie: ROT','warning','eye'),
 ('maintenance','WARTUNG','Zutritt nur für Personal','industrial','tools'),
 ('green','NORMAL','Keine Veränderung festgestellt','green','arrow'),
 ('red','ANOMALIE','Veränderung festgestellt','red','eye'),
 ('tower','WOLKENWERK','Softplay / ab 4 Jahren','enamel','stars'),
 ('croc','KROKO KLUB','Maximal 8 Kinder','enamel','stars'),
 ('blower','GEBLÄSE','Nicht abschalten!','warning','bolt'),
 ('monitor','NACHTDIENST','Happyland Sicherheit','industrial','eye'),
 ('film','HAPPYLAND FILM','Ein Tag voller Abenteuer','cinema','film'),
 ('found','FUNDSTÜCKE','Vermisst jemand noch etwas?','enamel','ticket'),
 ('tickets','EINTRITT','Bitte die Schuhe hier lassen.','enamel','ticket'),
 ('service','NACH DER LETZTEN FEIER','Geschirr abräumen.|Fundstücke bitte zum Empfang.','industrial','tools'),
 ('technical','TECHNISCHER DIENST','Ersatzteile / Reinigung|Zutritt nur für Personal','industrial','tools'),
 ('lift','03 / AUFZUG','Happyland / Personenaufzug','industrial','arrow'),
 ('exit','HAUPTEINGANG','Garderobe / Parkplatz|Bis bald im Happyland','enamel','arrow'),
 ('exit_changed','DU WARST SCHON DRAUSSEN.','Warum bist du zurückgekommen?','red','eye'),
 ('costumes','HINTER DER BÜHNE','Kostüme / Personal|Bitte alle Köpfe wieder aufhängen.','cinema','stars'),
 ('menu','KLEINE PAUSE, GROSSER HUNGER','Pommes  2,50 DM  /  Würstchen  3,00 DM|Slush  1,50 DM  /  Geburtstagsmenü  5,00 DM','poster','sun'),
 ('photo','DEIN HAPPYLAND-FOTO','4 Aufnahmen / 2 DM','cinema','film'),
 ('wc','KINDER-WC','Bitte Hände waschen.','enamel','water'),
 ('closed','BIS AUF WEITERES','GESCHLOSSEN','red','ticket'),
 ('soap','SEIFE','Happyland / Hände waschen','enamel','water'),
 ('cloakroom','GARDEROBE','Jacken / Schuhe / Fundstücke','enamel','hanger'),
 ('farewell','AUF WIEDERSEHEN','Bis bald im Happyland!','enamel','sun'),
 ('heater','HEIZKREIS 03','Technischer Dienst','industrial','tools'),
 ('annex','KÜCHE  /  KINO','Personalgang / Lichtspiel','enamel','film'),
 ('hall','GEBURTSTAGE  /  SAAL','Happyland / Feierbereich','enamel','balloon'),
 ('hygiene','PERSONAL / HYGIENE','Hände waschen. Arbeitskleidung tragen.','industrial','water'),
 ('last_show','LETZTE VORSTELLUNG','18:00 / Happyland Lichtspiel','cinema','film'),
 ('vent','LÜFTUNG 03','Wartung / nicht zustellen','industrial','tools'),
 ('staff_hall','PERSONALGANG','Happyland / nur für Mitarbeiter','industrial','arrow'),
 ('kitchen','KÜCHE','Personal / Speisenausgabe','enamel','cutlery'),
 ('cinema','LICHTSPIEL','Happyland / kleine Filmwelt','cinema','film'),
]
W,H=768,384

def text(d, value, xy, size, fill, max_width, serif=False):
    path=SERIF if serif else FONT
    font=ImageFont.truetype(str(path),size)
    while d.textbbox((0,0),value,font=font)[2]>max_width and size>10:
        size-=1; font=ImageFont.truetype(str(path),size)
    d.text(xy,value,font=font,fill=fill,anchor='mm',stroke_width=0)

def icon(d, kind, x, y, color, radius=28):
    if kind in ['sun','stars','balloon']:
        if kind=='sun':
            d.ellipse((x-15,y-15,x+15,y+15),outline=color,width=3)
            for i in range(10):
                a=i*math.tau/10
                d.line((x+math.cos(a)*21,y+math.sin(a)*21,x+math.cos(a)*30,y+math.sin(a)*30),fill=color,width=3)
        elif kind=='balloon':
            d.ellipse((x-19,y-27,x+19,y+13),outline=color,width=3)
            d.line((x,y+13,x-5,y+28,x+3,y+39),fill=color,width=2)
        else:
            pts=[]
            for i in range(10):
                a=i*math.pi/5-math.pi/2;r=27 if i%2==0 else 11
                pts.append((x+math.cos(a)*r,y+math.sin(a)*r))
            d.polygon(pts,outline=color,width=3)
    elif kind=='film':
        d.rounded_rectangle((x-30,y-24,x+30,y+24),radius=3,outline=color,width=3)
        for xx in [x-23,x+17]:
            for yy in range(y-17,y+18,11):d.rectangle((xx,yy,xx+6,yy+5),fill=color)
        d.polygon([(x-8,y-13),(x+14,y),(x-8,y+13)],fill=color)
    elif kind=='arrow':d.line((x-28,y,x+26,y),fill=color,width=6);d.line((x+7,y-20,x+28,y,x+7,y+20),fill=color,width=6)
    elif kind=='eye':
        d.arc((x-31,y-16,x+31,y+34),190,350,fill=color,width=4);d.arc((x-31,y-34,x+31,y+16),10,170,fill=color,width=4);d.ellipse((x-8,y-8,x+8,y+8),fill=color)
    elif kind=='bolt':d.polygon([(x+5,y-30),(x-22,y+7),(x-3,y+7),(x-8,y+31),(x+24,y-8),(x+4,y-8)],fill=color)
    elif kind=='cutlery':
        d.line((x-15,y-27,x-15,y+28),fill=color,width=5)
        for xx in [-24,-15,-6]:d.line((x+xx,y-28,x+xx,y-8),fill=color,width=4)
        d.line((x-24,y-8,x-6,y-8),fill=color,width=4);d.line((x+16,y-28,x+16,y+28),fill=color,width=5);d.polygon([(x+16,y-28),(x+27,y-7),(x+16,y+3)],fill=color)
    elif kind=='hanger':d.line((x,y-19,x,y-27,x+9,y-30,x+14,y-23,x+2,y-12,x+34,y+15,x-34,y+15,x,y-12),fill=color,width=3)
    elif kind=='water':
        d.polygon([(x,y-29),(x-16,y+6),(x-13,y+20),(x,y+26),(x+13,y+20),(x+16,y+6)],outline=color,width=4)
    elif kind=='ticket':
        d.rectangle((x-29,y-17,x+29,y+17),outline=color,width=3)
        for yy in range(y-13,y+14,8):d.line((x+12,yy,x+12,yy+3),fill=color,width=2)
    else:
        d.line((x-24,y+24,x+22,y-24),fill=color,width=9);d.arc((x+6,y-36,x+36,y-6),20,285,fill=color,width=5)
        d.line((x-22,y-26,x+24,y+23),fill=color,width=6)

def artwork(index, spec):
    key,title,copy,kind,picto=spec;rng=random.Random(3500+index)
    palette={'enamel':('#345c57','#e2ddc2','#ad9a67'),'industrial':('#465f56','#e7e6d7','#c0b280'),'cinema':('#383f50','#d7c08a','#9b5148'),'warning':('#c5a24f','#252d29','#793d31'),'green':('#3c655b','#e0dbc4','#b9a975'),'red':('#905045','#e2d5bb','#bca477'),'poster':('#c6b879','#365d56','#a65e55')}
    bg,ink,accent=palette[kind];im=Image.new('RGB',(W,H),bg);d=ImageDraw.Draw(im)
    if kind=='poster':
        for x in range(-100,900,110):d.polygon([(x,0),(x+52,0),(x+145,H),(x+93,H)],fill='#c0b27d')
        for i in range(30):
            x=rng.randrange(W);y=rng.randrange(H);d.arc((x-40,y-10,x+40,y+10),0,150,fill='#b9b082',width=2)
        d.rounded_rectangle((17,18,W-18,H-18),radius=25,outline=ink,width=4)
        text(d,'H A P P Y L A N D',(W/2,51),24,ink,W-80,True)
        icon(d,picto,W//2,106,accent)
        text(d,title,(W/2,179),49,ink,W-75,True)
        for i,line in enumerate(copy.split('|')):text(d,line,(W/2,252+i*53),37 if i==0 else 23,ink,W-90)
        d.line((55,216,W-55,216),fill=accent,width=2)
    else:
        d.rounded_rectangle((11,12,W-12,H-13),radius=21,outline=ink,width=3)
        d.rounded_rectangle((21,22,W-22,H-23),radius=15,outline=accent,width=2)
        if kind=='warning':
            for x in range(-H,W,64):d.polygon([(x,H-38),(x+27,H-38),(x+65,H-14),(x+38,H-14)],fill=ink)
        if kind=='cinema':
            for x in range(42,W-40,39):d.ellipse((x,35,x+5,40),fill=accent);d.ellipse((x,H-40,x+5,H-35),fill=accent)
        icon(d,picto,84,H//2,ink)
        text(d,'HAPPYLAND / '+('TECHNIK' if kind in ['industrial','warning'] else 'KINDERPARADIES'),(W/2+30,79),22,accent,W-120)
        text(d,title,(W/2+34,175),65,ink,W-205)
        for i,line in enumerate(copy.split('|')):text(d,line,(W/2+34,258+i*42),28 if len(copy)<45 else 24,ink,W-205)
    # Wear follows exposed edges and fasteners. Uneven bleaching leaves print
    # legible; no uniform brown noise is laid over the whole layout.
    wear=Image.new('RGBA',(W,H));wd=ImageDraw.Draw(wear)
    for i in range(290):
        edge=rng.randrange(4);x=rng.randrange(W) if edge<2 else rng.randrange(2,27) if edge==2 else rng.randrange(W-27,W-2);y=rng.randrange(2,24) if edge==0 else rng.randrange(H-24,H-2) if edge==1 else rng.randrange(H)
        r=rng.randrange(1,5);wd.ellipse((x-r,y-r,x+r,y+r),fill=(105,74,44,rng.randrange(70,180)))
    if kind=='poster':
        for i in range(3):
            yy=H*(i+1)/4;wd.line((18,yy,W-18,yy+rng.randrange(-3,4)),fill=(240,222,174,58),width=2)
        wd.polygon([(W-32,H-2),(W-2,H-35),(W-2,H-2)],fill=(87,72,48,150))
    else:
        for x in [33,W-33]:
            for y in [34,H-34]:
                wd.ellipse((x-9,y-7,x+11,y+11),fill=(111,73,43,105));wd.line((x+2,y+7,x+4,y+35),fill=(99,65,38,55),width=2)
    # Broad sun fade is separate from chips; the ink remains naturally patchy.
    fade=Image.new('RGBA',(W,H));fd=ImageDraw.Draw(fade)
    for i in range(10):
        x=rng.randrange(W);y=rng.randrange(H);r=rng.randrange(40,150);fd.ellipse((x-r,y-r,x+r,y+r),fill=(217,207,168,rng.randrange(5,17)))
    im=Image.alpha_composite(im.convert('RGBA'),fade.filter(ImageFilter.GaussianBlur(27)))
    return Image.alpha_composite(im,wear).convert('RGB')

atlas=Image.new('RGB',(2048,2560))
for i,spec in enumerate(SIGNS):
    image=artwork(i,spec).resize((512,256),Image.Resampling.LANCZOS)
    atlas.paste(image,((i%4)*512,(i//4)*256))
atlas.save(OUT/'happyland-signs.jpg',quality=91,subsampling=0)
for i,words in enumerate(['Für dich','Alles Liebe','Zum Geburtstag']):
    tag=Image.new('RGBA',(512,128),(0,0,0,0));draw=ImageDraw.Draw(tag)
    font=ImageFont.truetype(str(ROOT/'games/kinderparadies/assets/backstage-v270/Caveat.ttf'),72)
    draw.text((256,64),words,font=font,fill='#514936',anchor='mm')
    tag.save(OUT/f'parcel-tag-{i}.png')
(OUT/'LICENSE.txt').write_text('Original Happyland sign designs and procedural ageing, created for After Play.\nTypesetting uses Oswald and Bodoni Moda, bundled under the SIL OFL.\nParcel labels use the existing Caveat font under the SIL OFL.\nNo third-party photographs or symbols are included in these layouts.\n',encoding='utf-8')
ids=[s[0] for s in SIGNS];posters=[s[0] for s in SIGNS if s[3]=='poster']
(OUT/'sign_index.gd').write_text('extends RefCounted\nconst IDS='+json.dumps(ids,ensure_ascii=False)+'\nconst POSTERS='+json.dumps(posters,ensure_ascii=False)+'\n',encoding='utf-8')
print(f'Created {len(SIGNS)} original sign layouts in one shared atlas.')
