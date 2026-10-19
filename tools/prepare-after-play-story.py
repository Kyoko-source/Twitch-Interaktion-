"""Print original readable story props, aged paper and corroded door surfaces.

These are authored page layouts and procedural materials, not edits of supplied
images. The same catalog drives the in-game reader and every printed clipping.
"""
from pathlib import Path
import json, random, textwrap
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/story'
catalog=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
rng=np.random.default_rng(6428)
def font(size,bold=False):
 return ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf' if bold else 'C:/Windows/Fonts/georgia.ttf',size)
def paper(w=1024,h=1450):
 grain=rng.normal(0,2,(h,w));y,x=np.mgrid[:h,:w]
 edge=np.minimum.reduce([x/w,(w-1-x)/w,y/h,(h-1-y)/h])
 fox=np.maximum(0,np.sin(x*.018+np.cos(y*.012))*np.cos(y*.013+x*.009)-.6)*13
 crease=np.exp(-((x-w*.51)/7)**2)*9+np.exp(-((y-h*.48)/5)**2)*8
 age=np.maximum(0,.09-edge)*170+fox+crease
 a=np.stack([222+grain-age,208+grain-age*1.1,171+grain-age*1.4],axis=2).clip(0,255).astype('uint8')
 im=Image.fromarray(a,'RGB');d=ImageDraw.Draw(im)
 rand=random.Random(w+h)
 for _ in range(450):
  px,py=rand.randrange(w),rand.randrange(h);r=rand.choice([1,1,2,3]);d.ellipse((px-r,py-r,px+r,py+r),fill=(163,140,103))
 return im
def wrap(draw,text,face,width):
 lines=[]
 for para in text.split('\n'):
  line=''
  for word in para.split():
   candidate=(line+' '+word).strip()
   if draw.textlength(candidate,font=face)>width and line:lines.append(line);line=word
   else:line=candidate
  lines.append(line)
 return lines
def paragraph(d,text,x,y,width,face,leading,fill=(45,40,31)):
 for line in wrap(d,text,face,width):d.text((x,y),line,font=face,fill=fill);y+=leading
 return y

paper().save(OUT/'paper.png')
for id,item in catalog.items():
 im=paper();d=ImageDraw.Draw(im)
 if id=='note':
  d.line((90,120,930,120),fill=(151,126,91),width=2)
  paragraph(d,item['body'],105,320,810,font(48),77)
  d.line((120,1210,880,1194),fill=(148,124,89),width=2)
 else:
  d.text((512,38),'STADTBOTE' if id!='casefile' else 'HAPPYLAND · INTERN',font=font(69,True),fill=(34,31,25),anchor='mt')
  d.line((65,130,959,130),fill=(52,45,33),width=4)
  d.text((65,150),item['section'],font=font(20,True),fill=(59,49,35))
  y=paragraph(d,item['headline'],65,205,894,font(52,True),65)
  y+=22;d.line((65,y,959,y),fill=(68,57,38),width=2);y+=30
  # Two real typeset columns retain every clue without an unreadable tiny scan.
  face=font(25);lines=wrap(d,item['body'].replace('\n\n','\n'),face,426)
  midpoint=(len(lines)+1)//2
  for col in range(2):
   cy=y
   for line in lines[col*midpoint:(col+1)*midpoint]:
    d.text((65+col*468,cy),line,font=face,fill=(48,42,32));cy+=35
  d.line((512,y,512,1308),fill=(134,114,80),width=1)
  d.line((65,1332,959,1332),fill=(68,57,38),width=2)
  paragraph(d,item['footer'],65,1354,894,font(19),25,fill=(97,78,48))
 im.save(OUT/(id+'.png'))

for record in range(1,5):
 im=paper(640,900);d=ImageDraw.Draw(im)
 d.text((50,45),'HAPPYLAND',font=font(48,True),fill=(52,43,30))
 d.text((50,115),'INTERNE GÄSTELISTE',font=font(23),fill=(79,61,40))
 d.line((50,166,590,166),fill=(88,68,43),width=3)
 d.text((50,205),f'LISTENPLATZ  {record:02d}',font=font(28,True),fill=(47,40,30))
 d.rounded_rectangle((180,275,460,600),radius=3,fill=(142,126,94))
 d.ellipse((266,310,374,427),fill=(80,73,56));d.ellipse((217,430,423,670),fill=(80,73,56))
 d.rectangle((180,600,460,670),fill=(196,179,140))
 d.text((50,711),'VERBLEIB UNGEKLÄRT',font=font(30,True),fill=(107,31,23))
 d.text((50,794),'Abschlussvermerk: fehlt',font=font(22),fill=(79,61,40))
 im.save(OUT/f'record-{record}.png')

# Corrosion, flaking paint, rusty fasteners and a dried blood smear: original PBR albedo.
n=1024;y,x=np.mgrid[:n,:n];noise=rng.normal(0,1,(n,n))
rust=np.zeros((n,n))
for grid,weight in [(9,.36),(29,.28),(87,.20),(241,.10)]:
 layer=Image.fromarray(rng.integers(0,256,(grid,grid),dtype='uint8'),'L').resize((n,n),Image.Resampling.BICUBIC)
 rust+=np.asarray(layer)/255*weight
rust=np.clip((rust-.18)*1.6+noise*.035,0,1)
paint=np.clip((rust-.40)*5.8,0,1)
metal=np.stack([65+rust*94,32+rust*49,15+rust*23],axis=2)
base=np.array([51,65,56]);a=metal*paint[:,:,None]+base*(1-paint[:,:,None]);a+=noise[:,:,None]*5
Image.fromarray(a.clip(0,255).astype('uint8'),'RGB').save(OUT/'rust-metal.png')
stain=np.exp(-((x-n*.62)/(n*.13))**4-((y-n*.40)/(n*.17))**4)*.84
for dx,length in [(.52,.74),(.57,.90),(.64,.81),(.69,.68)]:
 stain=np.maximum(stain,np.exp(-((x-n*dx)/(n*.006))**2)*np.clip((n*length-y)/(n*.33),0,1)*(y>n*.42)*.96)
# A dragged palm impression and uneven finger streaks merge into the smear.
stain=np.maximum(stain,np.exp(-((x-n*.60)/(n*.055))**4-((y-n*.28)/(n*.045))**4)*.93)
for k in range(4):
 px=n*(.55+k*.029);py=n*(.20-abs(k-1.5)*.012)
 stain=np.maximum(stain,np.exp(-((x-px)/(n*.009))**4-((y-py)/(n*.066))**4)*.89)
stain*=np.clip(.82+rust*.25+noise*.06,0,1)
blood=np.array([72,9,10]);a=a*(1-stain[:,:,None])+blood*stain[:,:,None]
Image.fromarray(a.clip(0,255).astype('uint8'),'RGB').save(OUT/'rust-door.png')
rough=np.clip(180+paint*50+rng.normal(0,7,(n,n)),0,255).astype('uint8');Image.fromarray(rough,'L').save(OUT/'rust-roughness.png')
height=paint*.7+rust*.35+noise*.035;dy,dx=np.gradient(height);normal=np.stack([-dx*4,-dy*4,np.ones_like(dx)],axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
Image.fromarray(((normal*.5+.5)*255).astype('uint8'),'RGB').save(OUT/'rust-normal.png')
(OUT/'LICENSE.txt').write_text('Original project-authored fictional articles, page layouts and procedural paper/metal materials. Typography rendered to bitmap using installed system fonts; no font files are redistributed. No real newspaper scans, real missing-person cases or third-party photographs are used.\n',encoding='utf-8')
print('Printed',len(catalog),'original story props and door materials.')
