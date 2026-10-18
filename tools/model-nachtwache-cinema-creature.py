"""Original ceiling-dweller sculpt. Run with Blender 4.5 in background mode.

Metre-scale, closed organic meshes; no face cards or photo textures. Vertex
pigmentation, inset eyes, individual curved teeth and a continuous S-neck.
"""
import bpy, bmesh, math, random
from mathutils import Vector
from mathutils.noise import noise_vector
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/creatures'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(213)

def material(name,color,rough=.7):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough
 return m
skin=material('Mottled cadaver skin',(.38,.31,.24),.72)
v=skin.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Pigment';skin.node_tree.links.new(v.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
bone=material('Yellow rotten enamel',(.53,.43,.24),.53)
gum=material('Split burgundy gums',(.105,.018,.021),.58)
black=material('Deep wet sockets',(.006,.005,.004),.78)
eye=material('Clouded blind eyes',(.38,.42,.32),.22)
hair=material('Sparse greasy mane',(.019,.015,.009),.93)
blood=material('Old clotted wounds',(.09,.012,.009),.88)
all_parts=[]

def smooth(obj,mat):
 obj.data.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
 for p in obj.data.polygons:p.use_smooth=True
 all_parts.append(obj);return obj

def egg(name,pos,size,mat=skin):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=pos)
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
 return smooth(o,mat)

def curve(name,points,radii,mat=skin,n=16):
 pts=[Vector(p) for p in points];verts=[];faces=[]
 for j,p in enumerate(pts):
  tangent=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
  side=tangent.cross(Vector((1,0,0))).normalized();up=side.cross(tangent).normalized()
  for k in range(n):
   a=k*math.tau/n;rr=radii[j]*(1+.026*math.sin(k*3+j*.8))
   verts.append(p+rr*(math.cos(a)*side+math.sin(a)*up))
 for j in range(len(pts)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(reversed(range(n))),tuple((len(pts)-1)*n+k for k in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return smooth(o,mat)

def interpolate(points,radii,steps=6):
 p=[Vector(x) for x in points];out=[];rs=[]
 for j in range(len(p)-1):
  a=p[max(0,j-1)];b=p[j];c=p[j+1];d=p[min(len(p)-1,j+2)]
  for k in range(steps):
   t=k/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t));rs.append(radii[j]*(1-t)+radii[j+1]*t)
 out.append(p[-1]);rs.append(radii[-1]);return out,rs

def organic_join(name,parts,voxel=.018):
 bpy.ops.object.select_all(action='DESELECT')
 for p in parts:p.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=parts[0];o.name=name
 rem=o.modifiers.new('Unified sculpt surface','REMESH');rem.mode='VOXEL';rem.voxel_size=voxel;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=o.modifiers.new('Sculpt relaxation','SMOOTH');sm.factor=.65;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
 for p in o.data.polygons:p.use_smooth=True
 return o

start=len(all_parts)
torso=egg('Emaciated thorax',(0,.3,-.22),(.3,.48,.22))
egg('Crooked pelvis',(0,.65,-.17),(.28,.24,.18))
for s in [-1,1]:
 # Limbs folded against the ceiling, articulated rather than floating below it.
 curve('Elongated arm',[(s*.23,.09,-.19),(s*.56,-.1,-.36),(s*.76,-.48,-.18),(s*.83,-.65,-.035)],[.1,.075,.047,.033])
 egg('Knuckle hand',(s*.83,-.64,-.025),(.11,.13,.045))
 curve('Reverse bent leg',[(s*.19,.56,-.18),(s*.5,.95,-.33),(s*.68,1.16,-.13),(s*.64,1.34,-.03)],[.12,.085,.05,.04])
 for k in range(4):
  x=s*(.76+k*.055)
  curve('Grasping finger',[(x,-.67,-.02),(x+s*.018,-.83,-.035),(x+s*.024,-.91,-.009)],[.019,.012,.004],n=10)
  curve('Ceiling toes',[(s*(.57+k*.045),1.31,-.025),(s*(.57+k*.045),1.48,-.03)],[.018,.006],n=10)
body=organic_join('CeilingBody',[p for p in all_parts[start:] if p.name in bpy.data.objects],.019)
# Muscular continuous neck descends and then hooks forwards into the skull.
p,r=interpolate([(0,.02,-.23),(.08,-.2,-.28),(.14,-.46,-.73),(.07,-.58,-1.25),(0,-.81,-1.32)],[.16,.13,.11,.12,.16],9)
neck=curve('LongNeck',p,r,n=32)
start=len(all_parts)
egg('Elongated skull',(0,-.93,-.93),(.19,.31,.23))
bridge=egg('Nasal bridge',(.018,-1.19,-1.01),(.12,.35,.145));bridge.rotation_euler.x=-.13
egg('Long muzzle',(.025,-1.47,-1.10),(.17,.20,.12))
for s in [-1,1]:
 egg('Zygomatic arch',(s*.19,-1.04,-1.005),(.085,.21,.11))
 egg('Heavy orbital ridge',(s*.19,-1.06,-.82),(.092,.14,.065))
 # Tall torn pointed equine ears, leaning sideways asymmetrically.
 curve('Torn horse ear',[(s*.13,-.77,-.78),(s*.22,-.7,-.54),(s*.25,-.75,-.38)],[.075,.057,.004],n=16)
head=organic_join('HorseHead',[p for p in all_parts[start:] if p.name in bpy.data.objects],.012)
# Lower jaw is separated by a real open mouth with rows of narrow crooked teeth.
jaw=egg('Dislocated lower jaw',(.015,-1.32,-1.355),(.165,.31,.055),skin)
egg('Wet mouth cavity',(.02,-1.28,-1.225),(.145,.255,.13),black)
for s in [-1,1]:
 egg('Sunken eye socket',(s*.19,-1.074,-.904),(.024,.075,.054),black)
 egg('Dead side eye',(s*.211,-1.10,-.90),(.011,.025,.022),eye)
 egg('Slit pupil',(s*.221,-1.108,-.899),(.003,.005,.018),black)
 egg('Flared empty nostril',(s*.117,-1.595,-1.075),(.052,.014,.034),black)
 curve('Upper gum',[(s*.13,-1.1,-1.14),(s*.145,-1.35,-1.16),(s*.13,-1.54,-1.18)],[.026,.029,.021],gum)
 curve('Lower gum',[(s*.13,-1.1,-1.32),(s*.14,-1.32,-1.32),(s*.11,-1.54,-1.32)],[.025,.027,.019],gum)
 for k in range(9):
  y=-1.1-k*.052;x=s*(.132+.014*math.sin(k*.5));length=.17+rng.random()*.16
  curve('Long upper tooth',[(x,y,-1.15),(x*.9,y-.017,-1.15-length*.65),(x*.68,y-.03,-1.15-length)],[.012,.007,.0008],bone,n=10)
  if k%2==0:curve('Hooked lower tooth',[(x,y,-1.32),(x*.9,y+.01,-1.24),(x*.8,y+.005,-1.16)],[.011,.006,.001],bone,n=10)
for k in range(7):
 x=-.11+k*.035
 curve('Front incisor',[(x,-1.615,-1.15),(x*.8,-1.63,-1.23-rng.random()*.08)],[.016,.001],bone,n=10)
# Ribs, tendons, mane strands and attached scars retain close-up detail.
for k in range(7):
 for s in [-1,1]:
  curve('Raised rib',[(s*.09,.03+k*.067,-.395),(s*.21,.04+k*.067,-.36),(s*.28,.08+k*.067,-.24)],[.018,.022,.012])
for k in range(16):
 t=k/15;curve('Matted mane',[(.025,-.70+t*.75,-.54+t*.35),(.045+math.sin(k)*.03,-.68+t*.72,-.43+t*.3),(.065,-.56+t*.7,-.52+t*.32)],[.008,.005,.001],hair,n=6)
for i in range(13):
 y=-.11+i*.061;egg('Spinal vertebra',(.005,y,-.035),(.047,.028,.022),skin)
for i in range(11):
 x=.14*math.sin(i*2.3);y=-.96-i*.037
 curve('Muzzle laceration',[(x,y,-.813-i*.013),(x+.03,y-.04,-.83-i*.014)],[.007,.002],blood,n=6)

# Lengthen the pendant head independently of the ceiling-clinging torso.
for obj in list(bpy.data.objects):
 if obj.type=='MESH' and obj.name not in ['LongNeck','CeilingBody']:
  center=sum((obj.matrix_world@Vector(c) for c in obj.bound_box),Vector())/8
  if center.y<-.73 and center.z<-.32:obj.location.z-=.38;obj.location.y-=.03
# Fine surface irregularities and muted diffuse pigmentation avoid plastic skin.
# Exported glTF supports vertex pigments; procedural Blender nodes are not used.
for obj in list(bpy.data.objects):
 if obj.type!='MESH' or skin not in list(obj.data.materials):continue
 attr=obj.data.color_attributes.new(name='Pigment',type='BYTE_COLOR',domain='CORNER')
 for poly in obj.data.polygons:
  if obj.data.materials[poly.material_index]!=skin:continue
  for li in poly.loop_indices:
   co=obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co
   n=noise_vector(co*13).x;fine=noise_vector(co*87).y
   stain=max(0,noise_vector(co*8).z-.36)*.24
   c=(.105+n*.035+fine*.016+stain,.12+n*.035-stain*.25,.09+n*.027-stain*.25)
   attr.data[li].color=(*c,1)

# Batch rigid sculpt parts by material, avoiding a separate draw per tooth.
groups={}
for obj in list(bpy.data.objects):
 if obj.type=='MESH':groups.setdefault(obj.data.materials[0].name,[]).append(obj)
for name,parts in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for part in parts:part.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name=name.replace(' ','')
root=bpy.data.objects.new('VentDweller',None);bpy.context.collection.objects.link(root)
for obj in list(bpy.data.objects):
 if obj!=root:obj.parent=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'vent-dweller.glb'),export_format='GLB',export_yup=True,export_apply=True,export_attributes=True)
print('Exported original vent dweller',sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'),'faces')
