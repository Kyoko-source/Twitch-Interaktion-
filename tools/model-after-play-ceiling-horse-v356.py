"""Original head-only equine horror mask, sculpted lofts, cavities and torn skin.
Coordinates below use Godot's Y-up / -Z-forward convention. No external model.
Run with the portable Blender, then import the GLB into Godot.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/ceiling-horse-v356'
OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(356)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def cv(p): return Vector((p[0],-p[2],p[1]))
def gv(p): return Vector((p.x,p.z,-p.y))
def material(name,c,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*c,1);s.inputs['Roughness'].default_value=rough
 v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Decay';m.node_tree.links.new(v.outputs['Color'],s.inputs['Base Color'])
 return m
skin=material('Torn equine mask skin',(.38,.35,.28),.79)
bone=material('Damp exposed ivory',(.55,.48,.33),.67)
flesh=material('Wet torn tissue',(.18,.009,.014),.29)
void=material('Deep orbital darkness',(.009,.005,.004),.98)
hair=material('Matted black horse mane',(.018,.012,.009),.94)

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
 egg('EmptyEyeSocket',(side*.155,.15,-.13),(.064,.105,.12),void)
 egg('DeepNasalPassage',(side*.09,-.015,-1.105),(.035,.046,.08),void)
 # Lids and cheek tendons are asymmetrical torn strips, leaving the holes open.
 for j in range(3):
  strand('RaggedOrbitalRim',[(side*(.26+j*.006),.245-j*.035,-.30),(side*.285,.16-j*.026,-.20),(side*.245,.08-j*.025,-.04)],[.009,.013,.003],flesh if j==1 else skin,12)
 strand('ExposedCheekArch',[(side*.275,.005,-.12),(side*.255,-.045,-.36),(side*.15,-.085,-.76)],[.023,.027,.009],bone,12)
 strand('RupturedCheekTendon',[(side*.22,-.03,-.28),(side*.235,-.105,-.52),(side*.13,-.14,-.91)],[.008,.012,.003],flesh)
 # Long damaged ears remain narrow and folded rather than conical horns.
 ear=loft('SplitEquineEar',[(.14,.24,.04,.055),(.12,.34,.07,.085),(.11,.47,.052,.07),(.09,.58,.008,.013)],skin)
 for v in ear.data.vertices:
  p=gv(v.co);p.x+=side*.145+side*(p.y-.24)*.10;v.co=cv(p)
 cut(ear,egg('Ear hollow',(side*.17,.43,.065),(.037,.105,.057),flesh))
 strand('EarCartilage',[(side*.145,.26,.06),(side*.18,.39,.045),(side*.18,.52,.065)],[.016,.012,.003],flesh)
 # A lifted, ragged patch has a dark wet underside and a visible thickness.
 verts=[];faces=[]
 for j in range(13):
  t=j/12;z=-.37-t*.57
  for k in range(5):
   u=k/4;verts.append((side*(.185-.065*t+.026*u),.10-.06*t+.027*math.sin(t*9)*(u**2),z+.008*math.sin(k*6+j)))
 for j in range(12):
  for k in range(4):a=j*5+k;faces.append((a,a+1,a+6,a+5))
 flap=mesh('PeelingBloodiedMaskEdge',verts,faces,skin)
 thick=flap.modifiers.new('Torn mask thickness','SOLIDIFY');thick.thickness=.004
 bpy.context.view_layer.objects.active=flap;bpy.ops.object.modifier_apply(modifier=thick.name)

jaw_parts=[]
jaw=loft('BrokenLowerJaw',[(.10,-.095,.07,.06),(-.10,-.21,.225,.09),(-.45,-.30,.17,.06),(-.88,-.34,.115,.055),(-1.16,-.335,.17,.055),(-1.28,-.31,.12,.04),(-1.31,-.30,.025,.025)],skin)
jaw_parts.append(jaw)
for side in [-1,1]:
 strand('UpperBloodiedGum',[(side*.15,-.14,-1.20),(side*.12,-.13,-.88),(side*.20,-.12,-.45)],[.024,.018,.028],flesh,14)
 jaw_parts.append(strand('LowerBloodiedGum',[(side*.14,-.29,-1.20),(side*.095,-.285,-.86),(side*.16,-.24,-.4)],[.022,.016,.023],flesh,14))
 for i in range(6):
  z=-.42-i*.11;length=rng.uniform(.10,.17)
  strand('CrookedUpperMolar',[(side*(.185-i*.012),-.13,z),(side*(.18-i*.012),-.13-length*.68,z-.015),(side*(.174-i*.012),-.13-length,z-.007)],[.022,.018,.009],bone,12)
  if i!=2:
   jaw_parts.append(strand('UnevenLowerMolar',[(side*(.16-i*.011),-.285,z),(side*(.15-i*.011),-.205,z-.008)],[.022,.011],bone,12))
 for i in range(7):
  z=-.41-i*.11
  strand('DarkLipFilament',[(side*.19,-.13,z),(side*.185,-.20,z+.015),(side*.13,-.29,z-.02)],[.0035,.002,.0007],flesh,6)
for i in range(6):
 x=(i-2.5)*.046;z=-1.24+.14*(abs(x)/.14)**2
 length=.105+rng.uniform(-.025,.018)
 strand('HorseUpperIncisor',[(x,-.13,z),(x,-.13-length*.65,z-.017),(x*.97,-.13-length,z-.012)],[.024,.023,.019],bone,12)
 jaw_parts.append(strand('HorseLowerIncisor',[(x,-.30,z+.015),(x,-.24,z+.002)],[.023,.018],bone,12))
# Hair is actual tapered geometry, with an irregular hairline and matted clumps.
for i in range(100):
 x=rng.uniform(-.20,.20);z=rng.uniform(-.13,.22);y=.27+.015*math.sin(i)
 strand('MattedMane',[(x,y,z),(x+rng.uniform(-.04,.04),y+.02,z+.12),(x+rng.uniform(-.10,.10),y-rng.uniform(.1,.27),z+.27)],[rng.uniform(.0015,.004),.002,.0003],hair,5)
for i in range(28):
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
    blood=max(0,min(1,(wound+torn-.42)*2.4))
    bloody=(.095+fine*.025,.006+fine*.002,.009+fine*.003)
    col=[a*(1-blood)+b*blood for a,b in zip(col,bloody)]
   elif m==bone:
    root=max(0,min(1,(p.y+.20)*3));col=[col[0]*(1-root)+.24*root,col[1]*(1-root)+.045*root,col[2]*(1-root)+.026*root]
   attr.data[li].color=(*col,1)
 # A UV basis supports the in-game fine pore normal map after boolean cuts.
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)

root=bpy.data.objects.new('EquineMaskHeadOnly',None);bpy.context.collection.objects.link(root)
root['anatomy']='head_only_no_torso_or_limbs';root['design']='Original torn equine horror mask'
hinge=bpy.data.objects.new('JawHinge',None);bpy.context.collection.objects.link(hinge);hinge.parent=root;hinge.location=cv((0,-.09,.10))
parts=[o for o in list(bpy.data.objects) if o.type=='MESH']
for o in parts:
 paint(o)
 o.parent=hinge if o in jaw_parts else root
 if o in jaw_parts:o.location-=hinge.location
# Share one draw surface per material and articulation, including all mane hairs.
for parent in [root,hinge]:
 for mat in [skin,bone,flesh,void,hair]:
  group=[o for o in list(bpy.data.objects) if o.type=='MESH' and o.parent==parent and o.data.materials[0]==mat]
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
  group[0].name=('Jaw_' if parent==hinge else 'Mask_')+mat.name.replace(' ','_')
parts=[o for o in bpy.data.objects if o.type=='MESH']
bpy.ops.export_scene.gltf(filepath=str(OUT/'bloodied-equine-mask.glb'),export_format='GLB',export_yup=True,export_apply=True,export_attributes=True,export_extras=True,export_cameras=False,export_lights=False)
triangles=sum(sum(max(0,len(p.vertices)-2) for p in o.data.polygons) for o in parts)
(OUT/'provenance.json').write_text(json.dumps({'author':'Original project geometry','source':'tools/model-after-play-ceiling-horse-v356.py','external_assets':[],'anatomy':'head only; neck is animated in Godot','triangles':triangles},indent=2)+'\n')
(OUT/'LICENSE.txt').write_text('Original After Play project geometry and vertex colour painting. No third-party model or reference photograph is embedded.\n')
print('CEILING HORSE MODEL COMPLETE',len(parts),'meshes',triangles,'triangles',flush=True)
