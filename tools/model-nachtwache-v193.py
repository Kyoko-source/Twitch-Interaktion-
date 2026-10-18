"""Refine the credited clown scan/costume and author anatomical gripping hands.

Runs in Blender 4.5. The v180 generator retains its head-scan attribution;
hands, cloth, sleeves and first-person cuff below are original project geometry.
"""
from pathlib import Path
import bpy,bmesh,math,random
from mathutils import Vector
SOURCE=Path(__file__).with_name('model-nachtwache-props-v180.py')
text=SOURCE.read_text(encoding='utf8').split('clear();parts=[];optics=[];lens=[]')[0]
text=text.replace("(.47,.43,.32),(.72,.68,.55)","(.34,.33,.28),(.55,.54,.45)")
text=text.replace('((ax-.083)/.061)**4-((z-.048)/.059)**4','((ax-.095)/.055)**4-((z-.071)/.048)**4')
text=text.replace("grin=-.12+.065*(ax/.15)**1.7","grin=-.15+.055*(ax/.15)**1.7")
text=text.replace("c=mix(c,(.003,.004,.004),", "nose=math.exp(-(x/.048)**4-((z+.035)/.052)**4) if y<-.17 else 0\n    c=mix(c,(.21,.009,.018),nose*.9)\n    c=mix(c,(.003,.004,.004),")
ending="batch(body,'Body');batch(head,'Head',(0,0,1.96));export('kitchen-clown-v2.glb')"
assert ending in text
text=text.replace(ending,'')
exec(compile(text,str(SOURCE),'exec'),globals())
# Correct the oversized scan proportions without flattening its actual anatomy.
for o in head:
 if o.type=='MESH':
  for v in o.data.vertices:
   p=o.matrix_world@v.co;v.co=o.matrix_world.inverted()@(Vector((0,0,1.88))+(p-Vector((0,0,1.96)))*.66)
 elif o.type=='CURVE':
  for spline in o.data.splines:
   for p in spline.points:
    q=Vector(p.co[:3]);q=Vector((0,0,1.88))+(q-Vector((0,0,1.96)))*.66;p.co=(*q,1)
# Real overlapping apron cloth has an uneven hem, stitches and a tied waistband.
vs=[];fs=[]
for row in range(25):
 t=row/24;z=.86+t*.64
 for col in range(25):
  u=col/24;x=(u-.5)*(.48-.16*t);hem=(1-t)**12*(.015*math.sin(u*29)+.008*math.sin(u*65))
  vs.append((x,-.19-.014*math.sin(u*34+t*7),z+hem))
for j in range(24):
 for i in range(24):a=j*25+i;fs.append((a,a+1,a+26,a+25))
m=bpy.data.meshes.new('Folded apron cloth');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Bloodied stitched apron',m);bpy.context.collection.objects.link(o);finish(o,linen,body,cloth_colour)
for s in [-1,1]:
 line('Apron shoulder strap',[(s*.16,-.197,1.42),(s*.20,-.17,1.58),(s*.22,.08,1.58)],.015,linen,body)
 for i in range(17):
  z=.9+i*.032;x=s*(.24-.08*(z-.86)/.64)
  line('Apron stitch',[(x,-.209,z),(x-s*.008,-.21,z+.01)],.0016,brass,body)
for z in [1.0,1.15,1.30]:
 line('Apron wrinkle',[(-.19,-.215,z),(0,-.22,z+.015),(.19,-.215,z-.012)],.002,linen,body)
batch(body,'Body');batch(head,'Head',(0,0,1.88));export('kitchen-clown-v3.glb')

# Shared hand model in Godot-oriented local coordinates. A distinct thumb,
# metacarpals, three phalanges per finger and nails replace sphere/tube gloves.
clear();parts=[]
skin=mat('Mottled hand skin',(.32,.25,.19),.8,paint=True)
nail=mat('Dirty fingernails',(.33,.30,.21),.66)
crease=mat('Palm creases',(.12,.075,.049),.88)
cloth=mat('Stitched guard cuff',(.035,.052,.047),.96)
def gp(p):return Vector((p[0],-p[2],p[1]))
def hand_color(p):
 n=noise(*p);red=max(0,math.sin(p.x*95+p.z*65)-.48)*.18
 return (.26+n*.10+red,.22+n*.075-red*.4,.16+n*.06-red*.3)
def egg_g(name,pos,size,material=skin):
 return sphere(name,gp(pos),(size[0],size[2],size[1]),material,parts,hand_color if material==skin else None)
def finger(name,pts,radii):
 verts=[];faces=[];points=[gp(p) for p in pts]
 for j,p in enumerate(points):
  tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized();side=tangent.cross(Vector((1,0,0))).normalized();up=side.cross(tangent).normalized()
  for k in range(16):a=k*math.tau/16;verts.append(p+radii[j]*(math.cos(a)*side+math.sin(a)*up))
 for j in range(len(points)-1):
  for k in range(16):a=j*16+k;b=j*16+(k+1)%16;faces.append((a,b,b+16,a+16))
 faces.extend([tuple(reversed(range(16))),tuple((len(points)-1)*16+k for k in range(16))]);mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,skin,parts,hand_color)
egg_g('Palm',(0,0,0),(.04,.052,.021));egg_g('Thenar pad',(.027,.01,.01),(.025,.037,.023));egg_g('Wrist',(0,.065,0),(.026,.037,.019))
for k,x in enumerate([-.029,-.01,.010,.029]):
 length=[.042,.055,.052,.038][k]
 pts=[(x,-.033,0),(x,-.04-length*.45,.008),(x,-.04-length,.028),(x,-.023-length,.051),(x,-.008-length,.046)]
 finger('Articulated finger',pts,[.011,.010,.009,.008,.005])
 for p in pts[1:4]:egg_g('Knuckle',p,(.011,.010,.011))
 tip=pts[-1];egg_g('Fingernail',(tip[0],tip[1]-.001,tip[2]-.004),(.005,.009,.0015),nail)
finger('Opposing thumb',[(.03,.02,.0),(.055,-.005,.011),(.05,-.031,.036),(.026,-.043,.052)],[.015,.013,.011,.006])
egg_g('Thumbnail',(.028,-.043,.045),(.008,.01,.0015),nail)
# Unify the hand anatomy; skin folds remain separate, shallow sculpt details.
skin_parts=[o for o in parts if o.data.materials[0]==skin]
other_parts=[o for o in parts if o not in skin_parts]
hand=batch(skin_parts,'AnatomicalHand');parts=other_parts+[hand]
rem=hand.modifiers.new('Blend anatomical joints','REMESH');rem.mode='VOXEL';rem.voxel_size=.002;rem.use_smooth_shade=True;bpy.context.view_layer.objects.active=hand;bpy.ops.object.modifier_apply(modifier=rem.name)
sm=hand.modifiers.new('Skin relaxation','SMOOTH');sm.factor=.6;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
# Remesh reconstructs vertex colours, so repaint the unified hand explicitly.
for attr in list(hand.data.color_attributes):hand.data.color_attributes.remove(attr)
attr=hand.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
for i,v in enumerate(hand.data.vertices):attr.data[i].color=(*hand_color(hand.matrix_world@v.co),1)
for y in [-.018,.012,.044]:line('Palm fold',[gp((-.026,y,-.022)),gp((0,y-.006,-.023)),gp((.023,y+.003,-.019))],.0007,crease,parts)
for x in [-.029,-.01,.010,.029]:
 for y in [-.043,-.061]:line('Knuckle fold',[gp((x-.007,y,-.005)),gp((x+.007,y,-.005))],.0006,crease,parts)
export('anatomical-grip.glb')
# A unit-length sleeve is stretched by the existing shoulder/elbow animation.
clear();parts=[]
cloth=mat('Folded clown sleeve',(.21,.055,.046),.94)
vs=[];fs=[]
for j in range(49):
 t=j/48;y=t-.5;r=.085*(1-.22*t)*(1+.055*math.sin(t*36))
 for k in range(32):a=k*math.tau/32;fold=1+.03*math.sin(a*12+t*16);vs.append((math.cos(a)*r*fold,math.sin(a)*r*fold,y))
for j in range(48):
 for k in range(32):a=j*32+k;b=j*32+(k+1)%32;fs.append((a,b,b+32,a+32))
fs.extend([tuple(reversed(range(32))),tuple(48*32+k for k in range(32))]);m=bpy.data.meshes.new('Tailored sleeve surface');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Continuous sleeve',m);bpy.context.collection.objects.link(o);finish(o,cloth,parts)
batch(parts,'TailoredSleeve');export('clown-sleeve.glb')
print('Authored refined clown, anatomical hand and folded articulated sleeve.')
