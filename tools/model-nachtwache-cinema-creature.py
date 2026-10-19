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
bone=material('Yellow rotten enamel',(.34,.29,.17),.64)
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

# No torso or limbs: the neck begins well inside the shaft above the ceiling.
p,r=interpolate([(0,.05,.95),(0,.05,.24),(.12,-.12,-.42),(.16,-.38,-.96),(.06,-.58,-1.27),(0,-.81,-1.32)],[.14,.135,.103,.085,.095,.13],10)
neck=curve('LongNeck',p,r,n=40)
# Long attached tendons follow the neck's actual centreline.
for side in [-1,1]:
 points=[(p.x+side*r[i]*.82,p.y-r[i]*.47,p.z) for i,p in enumerate(p)]
 curve('Neck tendon',points,[.006+.003*math.sin(i*.07)**2 for i in range(len(points))],skin,n=8)
start=len(all_parts)
# A continuous, tapered equine skull, rather than a stack of round primitives.
sections=[(-.70,.025,-.96,.07),(-.78,.13,-.93,.18),(-.91,.18,-.93,.205),(-1.07,.155,-.96,.16),(-1.24,.095,-1.02,.12),(-1.43,.085,-1.07,.105),(-1.62,.117,-1.10,.08),(-1.75,.08,-1.10,.045),(-1.78,.008,-1.10,.01)]
verts=[];faces=[];rings=64
for j,(y,width,z,height) in enumerate(sections):
 for k in range(rings):
  angle=k*math.tau/rings
  # Slightly uneven bilateral bone landmarks and sunken temples.
  x=math.sin(angle)*width*(1+.035*math.sin(j*1.3+k*.25))
  verts.append((x,y,z+math.cos(angle)*height))
for j in range(len(sections)-1):
 for k in range(rings):
  a=j*rings+k;b=j*rings+(k+1)%rings;faces.append((a,b,b+rings,a+rings))
faces.extend([tuple(reversed(range(rings))),tuple((len(sections)-1)*rings+k for k in range(rings))])
mesh=bpy.data.meshes.new('Gaunt equine cranium');mesh.from_pydata(verts,[],faces);mesh.update()
sculpt=bpy.data.objects.new('Gaunt equine cranium',mesh);bpy.context.collection.objects.link(sculpt);smooth(sculpt,skin)
bpy.context.view_layer.objects.active=sculpt
sub=sculpt.modifiers.new('Organic cranial contour','SUBSURF');sub.levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
for s in [-1,1]:
 curve('Exposed cheekbone',[(s*.157,-.94,-.98),(s*.174,-1.06,-1.005),(s*.102,-1.24,-1.09)],[.025,.028,.012],skin,n=16)
 # Tall torn pointed equine ears, leaning sideways asymmetrically.
 curve('Torn horse ear',[(s*.13,-.77,-.78),(s*.22,-.7,-.54),(s*.25,-.75,-.38)],[.075,.057,.004],n=16)
head=organic_join('HorseHead',[p for p in all_parts[start:] if p.name in bpy.data.objects],.012)
# Carve deep orbital hollows into the sculpt instead of painting black eyes on it.
for side in [-1,1]:
 cutter=egg('Orbital cavity cutter',(side*.143,-1.035,-.91),(.085,.115,.10),black)
 bpy.context.view_layer.objects.active=head
 mod=head.modifiers.new('Excavated orbit','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
# Asymmetrically dropped jaw and an actual gap behind the crooked teeth.
jaw=curve('Dislocated lower jaw',[(-.095,-1.09,-1.32),(-.12,-1.46,-1.44),(-.08,-1.72,-1.43),(.06,-1.73,-1.42),(.11,-1.43,-1.4),(.10,-1.09,-1.3)],[.02,.026,.027,.025,.02,.02],skin,n=20)
egg('Wet mouth cavity',(.01,-1.34,-1.257),(.105,.29,.137),black)
for s in [-1,1]:
 egg('Sunken eye socket',(s*.107,-1.025,-.914),(.031,.065,.062),black)
 egg('Recessed cloudy eye',(s*.111,-1.074,-.913),(.010,.010,.013),eye)
 egg('Needle pupil',(s*.111,-1.083,-.913),(.002,.002,.009),black)
 egg('Empty nostril',(s*.078,-1.723,-1.08),(.04,.018,.026),black)
 # Split cheek edges descend towards the mouth, leaving the orbital hollow exposed.
 curve('Torn cheek seam',[(s*.172,-1.05,-.97),(s*.144,-1.14,-1.07),(s*.124,-1.22,-1.16)],[.009,.006,.002],blood,n=8)
 curve('Upper gum',[(s*.102,-1.1,-1.14),(s*.116,-1.4,-1.16),(s*.105,-1.7,-1.18)],[.014,.015,.012],gum)
 curve('Lower gum',[(s*.102,-1.1,-1.39),(s*.111,-1.4,-1.39),(s*.09,-1.69,-1.39)],[.012,.014,.011],gum)
 for k in range(11):
  if (s==1 and k in [2,7]) or (s==-1 and k in [4,9]):continue
  y=-1.1-k*.056;x=s*(.104+.012*math.sin(k*.5));length=.13+rng.random()*.22
  curve('Long upper tooth',[(x,y,-1.15),(x*.9,y-.017,-1.15-length*.65),(x*.68,y-.03,-1.15-length)],[.009+rng.random()*.005,.005,.0007],bone,n=10)
  if k%2==0:curve('Hooked lower tooth',[(x,y,-1.39),(x*.9,y+.01,-1.31),(x*.8,y+.005,-1.23)],[.011,.006,.001],bone,n=10)
for k in range(5):
 x=-.082+k*.039
 curve('Front incisor',[(x,-1.735,-1.15),(x*.8,-1.75,-1.23-rng.random()*.08)],[.016,.001],bone,n=10)
# Sparse tangled strands cling to the back of the neck, without a body silhouette.
for k in range(19):
 t=k/18
 curve('Matted mane',[(.015,-.12-t*.59,.05-t*1.18),(.035+math.sin(k)*.025,-.08-t*.58,-.03-t*1.18),(.06,-.04-t*.55,-.17-t*1.18)],[.006,.004,.0007],hair,n=6)
for i in range(11):
 x=.14*math.sin(i*2.3);y=-.96-i*.037
 curve('Muzzle laceration',[(x,y,-.813-i*.013),(x+.03,y-.04,-.83-i*.014)],[.007,.002],blood,n=6)

# Every head detail gets the same pendant offset; the neck is authored to meet it.
for obj in list(bpy.data.objects):
 if obj.type=='MESH' and obj.name not in ['LongNeck'] and not obj.name.startswith(('Neck tendon','Matted mane')):
  obj.location.z-=.38;obj.location.y-=.03
# Sculpt fine folds and small irregularities into the silhouette as well as its colour.
for obj in list(bpy.data.objects):
 if obj.type!='MESH' or skin not in list(obj.data.materials):continue
 for vertex in obj.data.vertices:
  world=obj.matrix_world@vertex.co
  grain=noise_vector(world*46).x*.0017+noise_vector(world*15).y*.0024
  vertex.co+=vertex.normal*grain
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
root['anatomy']='head_and_neck_only'
root['neck_origin_above_ceiling_m']=.95
for obj in list(bpy.data.objects):
 if obj!=root:obj.parent=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'vent-dweller.glb'),export_format='GLB',export_yup=True,export_apply=True,export_attributes=True,export_extras=True)
print('Exported original vent dweller',sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'),'faces')
