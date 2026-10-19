"""Original tailored clown body and bevelled handheld telephone, Blender 4.5.
Keeps the attributed scan from v193; no new external assets or character sprites.
"""
from pathlib import Path
import bpy,bmesh,math,random
from mathutils import Vector
source=Path(__file__).with_name('model-nachtwache-v193.py')
base=source.read_text(encoding='utf-8').split("batch(body,'Body');batch(head,'Head',(0,0,1.88));export('kitchen-clown-v3.glb')")[0]
exec(compile(base,str(source),'exec'),globals())
for obj in body:
 if obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
body=[]
def surface(name,sections,material,group,painter=None,folds=12):
 # z, width, depth, x centre, y centre. Dense continuous rings with sewn folds.
 dense=[]
 for a,b in zip(sections,sections[1:]):
  for k in range(6):dense.append(tuple(x+(y-x)*k/6 for x,y in zip(a,b)))
 dense.append(sections[-1]);vs=[];fs=[];n=64
 for j,(z,rx,ry,x,y) in enumerate(dense):
  for k in range(n):
   a=k*math.tau/n;fold=1+.022*math.sin(a*folds+z*9)+.014*math.sin(a*7-z*27)
   vs.append((x+math.cos(a)*rx*fold,y+math.sin(a)*ry*fold,z))
 for j in range(len(dense)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend([tuple(reversed(range(n))),tuple((len(dense)-1)*n+k for k in range(n))]);m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,material,group,painter);return o
surface('Hunched tailored jacket',[(.78,.21,.135,.015,.03),(.92,.235,.14,.0,.03),(1.07,.225,.155,-.015,.025),(1.24,.225,.17,-.018,.01),(1.39,.265,.17,-.025,.0),(1.49,.32,.135,-.015,-.015),(1.55,.265,.12,0,-.01),(1.61,.11,.083,0,-.005)],cloth,body,cloth_colour,19)
surface('Lean continuous neck',[(1.57,.084,.075,0,0),(1.67,.075,.07,0,-.01),(1.79,.079,.071,0,-.015)],skin,body,face_colour,4)
for side in [-1,1]:
 surface('Articulated folded trousers',[(.09,.078,.085,side*.14,.025),(.22,.079,.09,side*.14,.01),(.4,.09,.105,side*.145,-.03),(.48,.105,.115,side*.15,-.02),(.58,.11,.113,side*.14,.01),(.75,.115,.13,side*.125,.025),(.86,.12,.14,side*.12,.02)],cloth,body,cloth_colour,14)
 boot=box('Worn leather boot',(side*.145,-.06,.075),(.195,.32,.13),hair,body,.052)
 sole=box('Layered worn sole',(side*.145,-.075,.021),(.203,.34,.032),black,body,.012)
 surface('Laced leather ankle',[(.08,.09,.11,side*.145,.025),(.2,.075,.09,side*.145,.025),(.25,.071,.083,side*.145,.025)],hair,body,folds=5)
 for k in range(5):
  y=-.15+k*.033;line('Crossed boot laces',[(side*.145-.05,y,.147),(side*.145+.045,y+.028,.153)],.0025,linen,body)
 for k in range(3):
  z=.4+k*.035;line('Knee fabric crease',[(side*.145-.075,-.12,z),(side*.145,-.145,z+.014),(side*.145+.072,-.12,z+.005)],.003,cloth,body)
 line('Jacket shoulder seam',[(side*.10,-.055,1.60),(side*.22,-.10,1.55),(side*.30,-.04,1.47)],.0025,linen,body)
 line('Trouser outer seam',[(side*.23,.01,.82),(side*.25,-.01,.48),(side*.22,.01,.18)],.002,linen,body)
# Thick folded lapels, overlapping sewn apron and a sagging bloody hem.
for side in [-1,1]:
 line('Costume lapel',[(side*.1,-.095,1.60),(side*.17,-.153,1.43),(side*.08,-.173,1.24)],.012,cloth,body)
 line('Apron neck strap',[(side*.14,-.165,1.45),(side*.13,-.12,1.58),(side*.09,.065,1.62)],.012,linen,body)
vs=[];fs=[]
for row in range(37):
 t=row/36;z=.75+t*.74
 for col in range(37):
  u=col/36;x=(u-.5)*(.47-.16*t);hem=(1-t)**16*(.025*math.sin(u*24)+.012*math.sin(u*67))
  y=-.165-.024*math.cos((u-.5)*math.pi)-.012*math.sin(u*37+t*8)
  vs.append((x,y,z+hem))
for j in range(36):
 for k in range(36):a=j*37+k;fs.append((a,a+1,a+38,a+37))
m=bpy.data.meshes.new('Heavy torn apron cloth');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Bloody work apron',m);bpy.context.collection.objects.link(o);finish(o,linen,body,cloth_colour)
bpy.context.view_layer.objects.active=o;solid=o.modifiers.new('Real cloth thickness','SOLIDIFY');solid.thickness=.003;bpy.ops.object.modifier_apply(modifier=solid.name)
for side in [-1,1]:
 for k in range(24):
  t=k/24;x=side*(.235-.08*t);z=.78+t*.70;line('Apron edge stitching',[(x,-.191,z),(x-side*.006,-.194,z+.012)],.0009,brass,body)
for z in [1.0,1.2,1.39]:cylinder('Old sewn button',(0,-.188,z),.013,.008,brass,body,'Y',24)
# An irregular pleated ruff meets the actual neck, with no stacked spheres.
vs=[];fs=[]
for j in range(5):
 t=j/4
 for k in range(192):
  a=k*math.tau/192;r=.084+t*.155;vs.append((math.cos(a)*r,math.sin(a)*(r*.85)-.008,1.67-t*.04+math.sin(a*27)*(.002+t*.012)))
for j in range(4):
 for k in range(192):a=j*192+k;fs.append((a,j*192+(k+1)%192,(j+1)*192+(k+1)%192,a+192))
m=bpy.data.meshes.new('Stained sewn ruff');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Stained sewn ruff',m);bpy.context.collection.objects.link(o);finish(o,linen,body,cloth_colour)
# Open the actual scanned mouth and expose an uneven row of teeth inside it.
face=next(o for o in head if o.type=='MESH' and 'anatomical base' in o.name)
cutter=sphere('Mouth sculpt cutter',(0,-.125,1.78),(.065,.06,.025),black,[])
bpy.context.view_layer.objects.active=face
cut=face.modifiers.new('Cut open smile','BOOLEAN');cut.operation='DIFFERENCE';cut.object=cutter;bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(cutter,do_unlink=True)
sphere('Deep open mouth',(0,-.105,1.779),(.061,.026,.023),black,head)
for side in [-1,1]:
 line('Split mouth corner',[(side*.055,-.132,1.78),(side*.078,-.12,1.797),(side*.085,-.106,1.815)],.0024,lip,head)
for i in range(9):
 if i==6:continue
 x=-.048+i*.012
 box('Uneven exposed tooth',(x,-.131,1.788-rng.random()*.003),(.009,.008,.013+rng.random()*.007),tooth,head,.002)
batch(body,'Body');batch(head,'Head',(0,0,1.88));export('kitchen-clown-v4.glb')
# Phone dimensions in metres; front faces Blender -Y / Godot +Z.
clear();parts=[]
frame=mat('Brushed phone titanium',(.16,.175,.16),.32,.88)
glass=mat('Smudged black glass',(.008,.012,.013),.21,.12)
screen=mat('OLED screen',(.012,.035,.033),.3)
black=mat('Speaker perforations',(.002,.003,.003),.93)
box('Rounded metal frame',(0,0,0),(.079,.009,.165),frame,parts,.008)
box('Curved front glass',(0,-.005,0),(.075,.002,.160),glass,parts,.007)
box('Lit OLED face',(0,-.0062,-.002),(.069,.0007,.146),screen,parts,.006)
box('Rear camera island',(-.019,.006,.052),(.032,.004,.036),frame,parts,.008)
for x,z in [(-.026,.058),(-.013,.046),(-.026,.04)]:
 cylinder('Rear lens bezel',(x,.01,z),.006,.003,frame,parts,'Y',32);cylinder('Optical rear lens',(x,.012,z),.0048,.001,glass,parts,'Y',32)
box('Earpiece',(0,-.007,.07),(.017,.001,.002),black,parts,.0007)
sphere('Front camera',(.014,-.007,.069),(.0018,.0007,.0018),glass,parts)
for x in [-.04,.04]:box('Side key',(x,0,.024),(.0018,.003,.019),frame,parts,.0007)
for x in [-.023,-.018,-.013,.013,.018,.023]:sphere('Speaker grille',(x,0,-.082),(.001,.001,.0008),black,parts)
box('Charging port',(0,0,-.082),(.009,.003,.001),black,parts,.0007)
line('Hairline glass crack',[(-.035,-.007,-.065),(-.027,-.007,-.053),(-.032,-.007,-.045)],.00015,frame,parts)
batch(parts,'Phone');export('guard-phone.glb')
# Hand authored specifically around the phone edge, not a torch grip reused sideways.
clear();parts=[]
skin=mat('Nightguard hand skin',(.31,.255,.19),.82,paint=True)
nails=mat('Natural fingernails',(.35,.30,.23),.62)
def gp(p):return Vector((p[0],-p[2],p[1]))
def skin_colour(p):
 n=noise(*p);return (.27+n*.065,.22+n*.055,.16+n*.045)
def egg_g(name,pos,size,material=skin):
 return sphere(name,gp(pos),(size[0],size[2],size[1]),material,parts,skin_colour if material==skin else None)
def finger(name,pts,radii):
 points=[gp(p) for p in pts];vs=[];fs=[];n=20
 for j,p in enumerate(points):
  tangent=(points[min(j+1,len(points)-1)]-points[max(j-1,0)]).normalized();side=tangent.cross(Vector((0,0,1))).normalized();up=side.cross(tangent).normalized()
  for k in range(n):a=k*math.tau/n;vs.append(p+radii[j]*(math.cos(a)*side+math.sin(a)*up))
 for j in range(len(points)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend([tuple(reversed(range(n))),tuple((len(points)-1)*n+k for k in range(n))]);m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,skin,parts,skin_colour)
egg_g('Palm behind phone',(0,-.013,-.026),(.030,.048,.014))
egg_g('Thenar anatomy',(-.021,-.027,-.022),(.015,.027,.015))
finger('Narrow wrist',[(0,-.038,-.026),(0,-.061,-.023),(.004,-.087,-.018)],[.021,.020,.019])
for i,y in enumerate([.039,.018,-.003,-.024]):
 x=.023-(.002 if i==3 else 0)
 finger('Phone gripping finger',[(x-.004,y,-.032),(.037,y,-.024),(.044,y,-.011),(.044,y,.003),(.035,y,.010)],[.0072,.007,.0065,.006,.0046])
 egg_g('Inset fingernail',(.035,y,.0144),(.0045,.006,.0009),nails)
finger('Opposing phone thumb',[(-.021,-.037,-.025),(-.036,-.027,-.018),(-.038,-.007,-.002),(-.025,.001,.009)],[.010,.009,.0075,.0055])
egg_g('Thumb nail',(-.025,.001,.014),(.006,.007,.0009),nails)
# Blend the skin into one continuous hand, retaining separate thin nail plates.
skin_parts=[o for o in parts if o.data.materials[0]==skin];other=[o for o in parts if o not in skin_parts]
hand=batch(skin_parts,'Hand');parts=other+[hand];bpy.context.view_layer.objects.active=hand
rem=hand.modifiers.new('Continuous skin','REMESH');rem.mode='VOXEL';rem.voxel_size=.0014;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
sm=hand.modifiers.new('Skin relaxation','SMOOTH');sm.factor=.55;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
for attr in list(hand.data.color_attributes):hand.data.color_attributes.remove(attr)
attr=hand.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
for i,v in enumerate(hand.data.vertices):attr.data[i].color=(*skin_colour(hand.matrix_world@v.co),1)
export('phone-grip.glb')
print('Authored continuous tailored clown body, physical phone and dedicated hand.')