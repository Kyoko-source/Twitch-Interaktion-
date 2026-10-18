"""Original mottled skin surface, veins and pores; not a facial photograph."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import random
rng=np.random.default_rng(72);size=1024
field=np.zeros((size,size),dtype=float)
for res,weight in [(8,.38),(32,.3),(128,.2),(512,.12)]:
 grid=Image.fromarray(rng.integers(0,256,(res,res),dtype=np.uint8)).resize((size,size),Image.Resampling.BICUBIC)
 field+=np.asarray(grid)/255*weight
base=np.stack((112+field*74,127+field*69,103+field*67),axis=-1).astype(np.uint8)
im=Image.fromarray(base);veins=Image.new('RGBA',(size,size));draw=ImageDraw.Draw(veins);r=random.Random(13)
for i in range(45):
 x=r.randrange(size);y=r.randrange(size);path=[]
 for k in range(r.randrange(8,22)):
  path.append((x,y));x+=r.randrange(-12,13);y+=r.randrange(7,20)
 draw.line(path,fill=(48,32,35,r.randrange(65,125)),width=r.choice([1,1,2,3]))
 for j in range(2,len(path)-1,4):
  x,y=path[j];draw.line([(x,y),(x-12,y+7),(x-18,y+25)],fill=(55,39,35,65),width=1)
for i in range(8000):
 x=r.randrange(size);y=r.randrange(size);draw.point((x,y),fill=(37,40,29,r.randrange(20,110)))
im=Image.alpha_composite(im.convert('RGBA'),veins.filter(ImageFilter.GaussianBlur(.45))).convert('RGB')
out=Path(__file__).resolve().parents[1]/'games/kinderparadies/assets/creatures/dweller-skin.png'
im.save(out)
