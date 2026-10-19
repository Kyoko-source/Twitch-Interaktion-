"""Bake original worn signage and quiet material foley; no external samples.

The painted atlas is generated separately with image_gen (see art/PROMPTS-POLISH.md).
Run with Python + Pillow. Assets are shared by native and Web exports.
"""
import math, random, struct, wave
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/polish'
OUT.mkdir(exist_ok=True)
FONT = ROOT / 'games/kinderparadies/assets/Oswald.ttf'
SIGNS = {
    'hours': ('KINDERPARADIES', 'GEÖFFNET', '10:00 – 18:00'),
    'hours-wrong': ('KINDERPARADIES', 'GEÖFFNET', '03:33 – 03:33'),
    'rules': ('SPIELREGELN', 'SOCKENPFLICHT', 'KEIN ESSEN · KEINE SCHUHE'),
    'party': ('PARTY RAUM', 'HIER WERDEN ERINNERUNGEN GEMACHT'),
    'birthday': ('DEIN GROSSER TAG', 'WIR HABEN AUF DICH GEWARTET'),
    'nursery': ('DIE KLEINEN', 'SPIELEN · STAUNEN · TRÄUMEN'),
    'pickup': ('LIEBE ELTERN', 'BITTE ALLE KINDER ABHOLEN'),
    'duty': ('NACHTDIENST', 'KEINE ANOMALIE → GRÜN', 'ANOMALIE → ROT'),
    'maintenance': ('WARTUNG', 'NUR FÜR PERSONAL'),
    'green': ('NORMAL',), 'red': ('ANOMALIE',),
    'tower': ('WOLKENWERK', 'SOFTPLAY · AB 4 JAHREN'),
    'croc': ('KROKO KLUB', 'MAXIMAL 8 KINDER'),
    'blower': ('GEBLÄSE', 'NICHT ABSCHALTEN'),
    'monitor': ('NACHTDIENST',),
}
for index, (name, lines) in enumerate(SIGNS.items()):
    rng = random.Random(1400 + index)
    image = Image.new('RGB', (768, 384), '#b1a98a')
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((13, 13, 755, 371), 8, fill='#c5bda0', outline='#3a4d49', width=6)
    draw.line((46, 90, 722, 90), fill='#766c4e', width=2)
    for n, text in enumerate(lines):
        font_size = 62 if n == 0 else 50 if 'hours' in name and n == 2 else 35
        font = ImageFont.truetype(str(FONT), font_size)
        while draw.textbbox((0, 0), text, font=font)[2] > 665:
            font_size -= 1; font = ImageFont.truetype(str(FONT), font_size)
        y = (155 if len(lines) == 1 else 110 + n * 77 if len(lines) == 2 else 62 + n * 104)
        draw.text((384, y), text, font=font, anchor='mm', fill='#293e3b')
    for _ in range(3500):
        x, y = rng.randrange(768), rng.randrange(384)
        image.putpixel((x, y), tuple(max(0, c-rng.randrange(4, 24)) for c in image.getpixel((x,y))))
    for x in (29, 739):
        for y in (29, 355):
            draw.ellipse((x-5, y-5, x+5, y+5), fill='#655c43')
            draw.line((x-3,y-2,x+3,y+2), fill='#2a302c',width=2)
    image.save(OUT / (name+'.png'))

RATE = 24000
for name, duration, modes, noisy in [
    ('impact-rubber', .21, [(84,.32,22),(145,.07,35)], .13),
    ('impact-wood', .16, [(310,.22,39),(870,.07,55)], .18),
    ('impact-plastic', .24, [(190,.20,23),(460,.08,32)], .11),
    ('impact-cloth', .18, [], .23),
]:
    rng = random.Random(1407); samples=[]; filtered=0.0
    for i in range(round(RATE*duration)):
        t=i/RATE; filtered=.78*filtered+.22*rng.uniform(-1,1)
        value=sum(math.sin(math.tau*f*t)*a*math.exp(-d*t) for f,a,d in modes)
        value+=filtered*noisy*math.exp(-t*25)
        value*=min(1,t/.003)*min(1,(duration-t)/.025)
        samples.append(struct.pack('<h',round(max(-.8,min(.8,value))*32767)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as file:
        file.setnchannels(1);file.setsampwidth(2);file.setframerate(RATE);file.writeframes(b''.join(samples))
print('Baked 15 opaque signs and four original material impact sounds.')
