"""v4.2 rework of the original head-only equine horror: rotten dark hide, wet
eyes inside the sockets, more crooked teeth, hanging skin and a long wet mane.
Derived from model-after-play-ceiling-horse-v356.py. Y-up / -Z-forward coords.
Run: blender -b --python tools/model-after-play-long-horse-v420.py [-- OUT_DIR]
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector, noise

ROOT=Path(__file__).resolve().parents[1]
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
WEB='web' in ARGS
OUT=Path(ARGS[0]) if ARGS and ARGS[0]!='web' else ROOT/'games/kinderparadies/assets/horse-v420'
OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(420)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def cv(p): return Vector((p[0],-p[2],p[1]))
def gv(p): return Vector((p.x,p.z,-p.y))
def material(name,c,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*c,1);s.inputs['Roughness'].default_value=rough
 v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Decay';m.node_tree.links.new(v.outputs['Color'],s.inputs['Base Color'])
 return m
skin=material('Torn equine mask skin',(.125,.118,.106),.62)
bone=material('Damp exposed ivory',(.34,.31,.23),.42)
flesh=material('Wet torn tissue',(.18,.009,.014),.29)
void=material('Deep orbital darkness',(.009,.005,.004),.98)
hair=material('Matted black horse mane',(.016,.011,.008),.94)
eye=material('Wet clouded eye',(.105,.11,.10),.08)

def finish(obj,mat):
 obj.data.materials.clear();obj.data.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
 for p in obj.data.polygons:p.use_smooth=True
 return obj

def mesh(name,verts,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata([cv(v) for v in verts],[],faces);d.update()
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return finish(o,mat)

def egg(name,p,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=cv(p))
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co=Vector((v.co.x*scale[0],v.co.y*scale[2],v.co.z*scale[1]))
 return finish(o,mat)

def cut(o,c):
 bpy.context.view_layer.objects.active=o
 m=o.modifiers.new('Excavated anatomical opening','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=c
 bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(c,do_unlink=True)

def cat(a,b,c,d,t): return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
def loft(name,sections,mat,steps=5):
 src=[Vector(v) for v in sections];rows=[]
 for i in range(len(src)-1):
  for j in range(steps):rows.append(cat(src[max(0,i-1)],src[i],src[i+1],src[min(len(src)-1,i+2)],j/steps))
 rows.append(src[-1]);verts=[];faces=[];n=48
 for i,(z,cy,rx,ry) in enumerate(rows):
  for k in range(n):
   a=k*math.tau/n;rough=.0017*math.sin(k*3.3+i*1.77)+.002*math.sin(k*2.17-i*.63)
   x=math.sin(a)*max(.015,rx);y=cy+math.cos(a)*max(.015,ry)
   # Nasal ridge and cheek planes follow the skull instead of a rounded ball.
   y+=.018*math.exp(-(x/.065)**2)*max(0,math.cos(a))
   x+=rough;y+=rough*.65+.004*math.sin(z*49+a*5)*math.sin(a*7+z*31)
   verts.append((x,y,z))
 for i in range(len(rows)-1):
  for k in range(n):a=i*n+k;b=i*n+(k+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(reversed(range(n))),tuple((len(rows)-1)*n+k for k in range(n))])
 return mesh(name,verts,faces,mat)

def tooth(name,root,tip,width,depth,mat,taper=.72):
 # Superelliptic cross-section with a shallow groove, a crown wider than the
 # neck and a worn, slightly oblique chewing edge.
 a=Vector(root);b=Vector(tip);axis=(b-a);length=axis.length;axis.normalize()
 side=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized();front=side.cross(axis).normalized()
 verts=[];faces=[];rows=9;n=20
 for i in range(rows+1):
  t=i/rows;bulge=1+.18*math.sin(t*math.pi*.9)
  w=width*bulge*(1-(1-taper)*t);d=depth*bulge*(1-(1-taper)*.6*t)
  centre=a+axis*length*(t-.03*(1-t))
  for k in range(n):
   ang=k*math.tau/n;c=math.cos(ang);q=math.sin(ang)
   x=math.copysign(abs(c)**.5,c)*w;y=math.copysign(abs(q)**.5,q)*d
   y-=.0016*math.exp(-(c/.18)**2)*(q>0)
   verts.append(centre+side*x+front*y+axis*(.006*c*t*t))
 for i in range(rows):
  for k in range(n):i0=i*n+k;i1=i*n+(k+1)%n;faces.append((i0,i1,i1+n,i0+n))
 faces.extend([tuple(reversed(range(n))),tuple(rows*n+k for k in range(n))])
 return mesh(name,[tuple(v) for v in verts],faces,mat)

def strand(name,pts,radii,mat,n=10):
 points=[Vector(p) for p in pts];verts=[];faces=[]
 for i,p in enumerate(points):
  axis=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  side=axis.cross(Vector((0,1,0)) if abs(axis.y)<.93 else Vector((1,0,0))).normalized();up=side.cross(axis).normalized()
  for k in range(n):verts.append(p+radii[i]*(math.cos(k*math.tau/n)*side+math.sin(k*math.tau/n)*up))
 for i in range(len(points)-1):
  for k in range(n):a=i*n+k;b=i*n+(k+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(reversed(range(n))),tuple((len(points)-1)*n+k for k in range(n))])
 return mesh(name,verts,faces,mat)

head=loft('ContinuousHorseMask',[(.26,.08,.045,.09),(.15,.085,.22,.24),(-.04,.08,.30,.265),(-.28,.045,.265,.21),(-.48,.025,.20,.17),(-.76,.005,.145,.125),(-1.02,-.02,.195,.145),(-1.20,-.04,.19,.105),(-1.32,-.055,.045,.04)],skin)
for side in [-1,1]:
 cut(head,egg('Eye socket excavation',(side*.24,.15,-.14),(.14,.145,.185),void))
 cut(head,egg('Open nostril excavation',(side*.16,-.015,-1.115),(.075,.065,.125),void))
 egg('EmptyEyeSocket',(side*.165,.15,-.12),(.064,.105,.12),void)
 egg('WetClouded eye',(side*.192,.150,-.168),(.036,.040,.046),eye)
 egg('Slit pupil',(side*.214,.150,-.192),(.010,.006,.022),void)
 egg('DeepNasalPassage',(side*.09,-.015,-1.105),(.035,.046,.08),void)
 # Lids and cheek tendons are asymmetrical torn strips, leaving the holes open.
 for j in range(3):
  strand('RaggedOrbitalRim',[(side*(.26+j*.006),.245-j*.035,-.30),(side*.285,.16-j*.026,-.20),(side*.245,.08-j*.025,-.04)],[.011,.015,.006],skin,12)
 strand('ExposedCheekArch',[(side*.275,.005,-.12),(side*.255,-.045,-.36),(side*.15,-.085,-.76)],[.023,.027,.009],bone,12)
 strand('RupturedCheekTendon',[(side*.22,-.03,-.28),(side*.235,-.105,-.52),(side*.13,-.14,-.91)],[.008,.012,.003],flesh)
 # Long damaged ears remain narrow and folded rather than conical horns.
 ear=loft('SplitEquineEar',[(.14,.24,.04,.055),(.12,.34,.07,.085),(.11,.47,.052,.07),(.09,.58,.008,.013)],skin)
 for v in ear.data.vertices:
  p=gv(v.co);p.x+=side*.145+side*(p.y-.24)*.10;v.co=cv(p)
 cut(ear,egg('Ear hollow',(side*.17,.43,.065),(.037,.105,.057),flesh))
 strand('EarCartilage',[(side*.145,.26,.06),(side*.18,.39,.045),(side*.18,.52,.065)],[.016,.012,.006],skin)
 # A lifted, ragged patch has a dark wet underside and a visible thickness.
 verts=[];faces=[]
 for j in range(13):
  t=j/12;z=-.37-t*.57
  for k in range(5):
   u=k/4;verts.append((side*(.185-.065*t+.026*u),.10-.06*t+.027*math.sin(t*9)*(u**2),z+.008*math.sin(k*6+j)))
 for j in range(12):
  for k in range(4):a=j*5+k;faces.append((a,a+1,a+6,a+5))
 flap=mesh('PeelingBloodiedMaskEdge',verts,faces,skin)
 thick=flap.modifiers.new('Torn mask thickness','SOLIDIFY');thick.thickness=.010
 bpy.context.view_layer.objects.active=flap;bpy.ops.object.modifier_apply(modifier=thick.name)

jaw_parts=[]
jaw=loft('BrokenLowerJaw',[(.10,-.095,.07,.06),(-.10,-.21,.225,.09),(-.45,-.30,.17,.06),(-.88,-.34,.115,.055),(-1.16,-.335,.17,.055),(-1.28,-.31,.12,.04),(-1.31,-.30,.025,.025)],skin)
jaw_parts.append(jaw)
GUMS=[]
for side in [-1,1]:
 # Gums are fused into the skin and painted; their paths are kept for paint().
 upper=[(side*.15,-.14,-1.20),(side*.12,-.13,-.88),(side*.20,-.12,-.45)];GUMS.append((upper,.030))
 strand('UpperBloodiedGum',upper,[.024,.018,.028],skin,14)
 lower=[(side*.14,-.29,-1.20),(side*.095,-.285,-.86),(side*.16,-.24,-.4)];GUMS.append((lower,.028))
 jaw_parts.append(strand('LowerBloodiedGum',lower,[.022,.016,.023],skin,14))
 for i in range(7):
  z=-.40-i*.105;length=rng.uniform(.085,.15)*(1.25 if i in (1,4) else 1)
  tooth('CrookedUpperMolar',(side*(.180-i*.012),-.115,z),(side*(.176-i*.012)+rng.uniform(-.008,.008),-.115-length,z+rng.uniform(-.012,.012)),.020,.026,bone,.86)
  if i!=2:
   jaw_parts.append(tooth('UnevenLowerMolar',(side*(.155-i*.011),-.30,z),(side*(.15-i*.011),-.30+rng.uniform(.055,.10),z-.006),.019,.025,bone,.86))
 for i in range(7):
  z=-.41-i*.11
  strand('DarkLipFilament',[(side*.19,-.13,z),(side*.185,-.20,z+.015),(side*.13,-.29,z-.02)],[.0035,.002,.0007],flesh,6)
  # Torn shreds of the lower lip hang from the jaw and move with it.
  jaw_parts.append(strand('LowerLipShred',[(side*.15,-.33,z+.03),(side*.165,-.38,z+.05),(side*.15,-.43-.03*(i%3),z+.06)],[.006,.004,.001],flesh,6))
for i in range(8):
 x=(i-3.5)*.036;z=-1.24+.14*(abs(x)/.14)**2
 length=.11+rng.uniform(-.02,.05);lean=rng.uniform(-.02,.02)
 tooth('HorseUpperIncisor',(x,-.115,z+.01),(x+lean,-.115-length,z-.03),.017,.010,bone,.8)
 jaw_parts.append(tooth('HorseLowerIncisor',(x,-.315,z+.02),(x-lean*.5,-.315+.075+rng.uniform(0,.03),z-.012),.016,.010,bone,.8))
# Hair is actual tapered geometry, with an irregular hairline and matted clumps.
for i in range(320):
 x=rng.uniform(-.21,.21);z=rng.uniform(-.40,.24);y=.24+.04*math.cos(x*7)
 drop=rng.uniform(.22,.62);sway=rng.uniform(-.07,.07)
 strand('MattedMane',[(x,y,z),(x*1.1+sway*.3,y+.01,z+.09),(x*1.2+sway,y-drop*.55,z+.16),(x*1.25+sway*1.2,y-drop,z+.20)],[rng.uniform(.0025,.006),.004,.0025,.0004],hair,5)
for i in range(14):
 side=-1 if i%2 else 1;z=rng.uniform(-.75,-.12);x=side*rng.uniform(.17,.25);long=rng.uniform(.10,.26)
 verts=[];faces=[]
 for j in range(9):
  t=j/8;w=.026*(1-t*.75)
  for k in range(3):verts.append((x+side*.01*t+(k-1)*w,-.06-long*t,z+.03*math.sin(t*4+i)+.015*t))
 for j in range(8):
  for k in range(2):a=j*3+k;faces.append((a,a+1,a+4,a+3))
 rag=mesh('HangingHideStrip',verts,faces,skin)
 th=rag.modifiers.new('Hide thickness','SOLIDIFY');th.thickness=.010
 bpy.context.view_layer.objects.active=rag;bpy.ops.object.modifier_apply(modifier=th.name)
for i in range(40):
 side=-1 if i%2 else 1;z=rng.uniform(-.9,-.28)
 strand('DriedBloodThread',[(side*.20,-.07,z),(side*.22,-.15,z+.025),(side*.16,-.24-rng.random()*.08,z+.05)],[.002,.0013,.0003],flesh,5)

def paint(obj):
 m=obj.data.materials[0];base=tuple(m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3])
 attr=obj.data.color_attributes.new(name='Decay',type='BYTE_COLOR',domain='CORNER')
 for face in obj.data.polygons:
  for li in face.loop_indices:
   p=gv(obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co)
   n=noise_vector(p*13).x;fine=noise_vector(p*76).y
   col=[max(.004,c*(.84+n*.24)+fine*.018) for c in base]
   if m==skin:
    wound=math.exp(-((p.z+.27)/.14)**2-((p.y+.035)/.17)**2)+.9*math.exp(-((p.z+.90)/.25)**2-((p.y+.08)/.065)**2)
    wound+=max(0,.13-p.y)*1.3
    # A torn, blood-tracked brow and one ruptured nasal flank remain visible
    # when the long face hangs vertically towards the player's light.
    wound+=.95*math.exp(-((p.z+.19)/.14)**2-((p.x-.08)/.085)**2-((p.y-.26)/.13)**2)
    wound+=.84*math.exp(-((p.z+.67)/.28)**2-((p.x-.12)/.065)**2-((p.y-.09)/.11)**2)
    torn=math.sin(p.x*81+p.z*21)*.12+fine*.16
    blood=max(0,min(1,(wound+torn-.30)*2.6))
    mange=max(0,min(1,(noise_vector(p*5.5).z+.05)*3))
    col=[c*(1-mange*.30)+g*mange*.30 for c,g in zip(col,(.21,.20,.18))]
    bloody=(.095+fine*.025,.006+fine*.002,.009+fine*.003)
    col=[a*(1-blood)+b*blood for a,b in zip(col,bloody)]
    gum=0.
    for path,radius in GUMS:
     for a,b in zip(path,path[1:]):
      a=Vector(a);b=Vector(b);t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
      gum=max(gum,1-max(0,min(1,((p-(a+(b-a)*t)).length-radius)/.018)))
    wet=(.19+fine*.05,.025+fine*.01,.03+fine*.01)
    col=[a*(1-gum)+b*gum for a,b in zip(col,wet)]
   elif m==bone:
    root=max(0,min(1,(p.y+.20)*3));col=[col[0]*(1-root)+.24*root,col[1]*(1-root)+.045*root,col[2]*(1-root)+.026*root]
   attr.data[li].color=(*col,1)
 # A UV basis supports the in-game fine pore normal map after boolean cuts.
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)

root=bpy.data.objects.new('EquineMaskHeadOnly',None);bpy.context.collection.objects.link(root)
root['anatomy']='head_only_no_torso_or_limbs';root['design']='Original torn equine horror mask'
hinge=bpy.data.objects.new('JawHinge',None);bpy.context.collection.objects.link(hinge);hinge.parent=root;hinge.location=cv((0,-.09,.10))
def g(p,c,r):return math.exp(-sum(((p[i]-c[i])/r[i])**2 for i in range(3)))

def sculpt(obj):
 # Anatomy under the hide: hollow cheeks, temples and orbits, a heavy brow,
 # raised facial veins, nostril wrinkles and uneven skin.
 obj.data.update();mw=obj.matrix_world;inv=mw.inverted()
 for v in obj.data.vertices:
  w=mw@v.co;p=gv(w);n=gv(mw.to_3x3()@v.normal).normalized()
  d=0.
  for side in (-1,1):
   d-=.020*g(p,(side*.215,-.04,-.47),(.07,.07,.17))
   d-=.014*g(p,(side*.20,.20,.06),(.05,.07,.09))
   d+=.010*g(p,(side*.21,.245,-.22),(.07,.03,.08))
   d-=.010*g(p,(side*.12,.09,-.80),(.05,.05,.16))
  warp=Vector((noise(p*3.1),noise(p*3.1+Vector((5,1,2))),noise(p*3.1+Vector((1,7,3)))))*.35
  ridge=1-abs(noise(p*7.5+warp))
  d+=.0042*max(0,min(1,(ridge-.90)/.07))*min(1,abs(p.x)/.10)
  if p.z<-.82 and p.y>-.06:d+=.0028*math.sin(p.z*120+noise(p*14)*5)*min(1,(-.82-p.z)/.08)
  d+=.0018*noise(p*55)+.0010*noise(p*140)
  v.co=inv@(w+cv(n)*d-cv(Vector((0,0,0))))

def fuse(objs,name,voxel,target):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0];o.name=name
 o.data.remesh_voxel_size=voxel;o.data.remesh_voxel_adaptivity=0
 bpy.ops.object.voxel_remesh()
 sm=o.modifiers.new('Voxel step smoothing','SMOOTH');sm.factor=.6;sm.iterations=5
 bpy.ops.object.modifier_apply(modifier=sm.name)
 sculpt(o)
 if len(o.data.polygons)>target:
  dec=o.modifiers.new('Budget','DECIMATE');dec.ratio=target/len(o.data.polygons)
  bpy.ops.object.modifier_apply(modifier=dec.name)
 o.data.materials.clear();o.data.materials.append(skin)
 for f in o.data.polygons:f.use_smooth=True
 return o

parts=[o for o in list(bpy.data.objects) if o.type=='MESH']
for o in parts:
 o.parent=hinge if o in jaw_parts else root
 if o in jaw_parts:o.location-=hinge.location
bpy.context.view_layer.update()
voxel,budget=(.0080,24000) if WEB else (.0052,95000)
for parent,label in [(root,'Mask'),(hinge,'Jaw')]:
 skins=[o for o in list(bpy.data.objects) if o.type=='MESH' and o.parent==parent and o.data.materials[0]==skin]
 fused=fuse(skins,label+'_FusedHide',voxel,budget if parent==root else budget//3)
for o in [o for o in bpy.data.objects if o.type=='MESH']:
 paint(o)
# Share one draw surface per material and articulation, including all mane hairs.
for parent in [root,hinge]:
 for mat in [skin,bone,flesh,void,hair,eye]:
  group=[o for o in list(bpy.data.objects) if o.type=='MESH' and o.parent==parent and o.data.materials[0]==mat]
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
  group[0].name=('Jaw_' if parent==hinge else 'Mask_')+mat.name.replace(' ','_')
# Eyes share the dark socket draw object, so the head keeps eight meshes.
eyes=bpy.data.objects.get('Mask_Wet_clouded_eye');sockets=bpy.data.objects.get('Mask_Deep_orbital_darkness')
bpy.ops.object.select_all(action='DESELECT');eyes.select_set(True);sockets.select_set(True)
bpy.context.view_layer.objects.active=sockets;bpy.ops.object.join()
parts=[o for o in bpy.data.objects if o.type=='MESH']
for o in parts:
 if False:
  bpy.context.view_layer.objects.active=o;sub=o.modifiers.new('Close-up contour subdivision','SUBSURF');sub.levels=1
  bpy.ops.object.modifier_apply(modifier=sub.name)
bpy.ops.export_scene.gltf(filepath=str(OUT/('long-horse-head-web.glb' if WEB else 'long-horse-head.glb')),export_format='GLB',export_yup=True,export_apply=True,export_attributes=True,export_extras=True,export_cameras=False,export_lights=False)
triangles=sum(sum(max(0,len(p.vertices)-2) for p in o.data.polygons) for o in parts)
(OUT/'provenance.json').write_text(json.dumps({'author':'Original project geometry','source':'tools/model-after-play-long-horse-v420.py','external_assets':[],'anatomy':'head only; neck is animated in Godot','triangles':triangles},indent=2)+'\n')
(OUT/'LICENSE.txt').write_text('Original After Play project geometry and vertex colour painting. No third-party model or reference photograph is embedded.\n')
print('CEILING HORSE MODEL COMPLETE',len(parts),'meshes',triangles,'triangles',flush=True)
