"""Production derivatives: detailed hero meshes and three articulated visitors.
Original After Play geometry; existing Lee Perry-Smith scan attribution retained.
"""
import bpy,bmesh,math,random,itertools
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'games/kinderparadies/assets';OUT=A/'revamp-v300'
rng=random.Random(300)
def reset(path):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(A/path))
def material(name,color,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;return m
def curve(name,pts,radius,mat,parent=None):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=radius;c.bevel_resolution=2
 s=c.splines.new('POLY');s.points.add(len(pts)-1)
 for p,co in zip(s.points,pts):p.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mat);o.parent=parent;return o
def export(name):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
 bpy.ops.export_scene.gltf(filepath=str(OUT/name),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False,export_attributes=True)
 print('V300 MODEL',name,flush=True)

# Keep the existing physically scanned face and its pivot. Geometry is deformed
# coherently, including lips/teeth, rather than laying a face image on a sphere.
reset('props/kitchen-clown-v4.glb')
head=bpy.data.objects['Head']
for v in head.data.vertices:
 p=v.co
 if p.z<-.015:
  weight=math.exp(-((p.z+.08)/.10)**2)*max(0,min(1,(-p.y+.015)*7))
  p.x+=.016*weight;p.z-=.018*weight;p.y-=.009*weight
head.data.update();bpy.context.view_layer.update()
bm=bmesh.new();bm.from_mesh(head.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);tree=BVHTree.FromBMesh(bm)
dark=material('Dried split greasepaint',(.065,.009,.012),.66)
for index,(x,z) in enumerate([(-.072,.09),(.060,.08),(.10,-.02)]):
 pts=[]
 for i in range(19):
  zz=z-i*.008;xx=x+.004*math.sin(i*.7+index)
  hit=tree.ray_cast(Vector((xx,-1,zz)),Vector((0,1,0)))
  if hit[0] is not None:pts.append(hit[0]+hit[1]*.0009)
 if len(pts)>2:curve('Blood collected in face crack',pts,.0011,dark,head)
bm.free()
export('kitchen-clown-v300.glb')

# Dense short, clumped textile pile follows actual cloth surface triangles.
# Millimetre-scale geometry, not long grass-like spikes or a flesh wound.
reset('mascot-v251/mascot-rabbit.glb')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH');body.data.calc_loop_triangles()
eligible=[t for t in body.data.loop_triangles if t.material_index==0 and t.area>1e-7]
weights=list(itertools.accumulate(t.area for t in eligible));verts=[];faces=[]
pile=material('Short matted plush pile',(.29,.205,.13),1)
for i in range(18000):
 tri=rng.choices(eligible,cum_weights=weights,k=1)[0];vs=[body.data.vertices[n] for n in tri.vertices]
 u=rng.random();v=rng.random()
 if u+v>1:u=1-u;v=1-v
 p=vs[0].co+(vs[1].co-vs[0].co)*u+(vs[2].co-vs[0].co)*v
 n=tri.normal.normalized();t=n.cross(Vector((0,0,1)))
 if t.length<.1:t=n.cross(Vector((1,0,0)))
 t.normalize();down=Vector((0,0,-1));down-=n*down.dot(n)
 if down.length>.01:down.normalize()
 length=rng.uniform(.0025,.0075);end=p+n*length*.75+down*length*.6
 for side in [t,t.cross(n).normalized()]:
  a=len(verts);verts.extend([p-side*.00065,p+side*.00065,end]);faces.append((a,a+1,a+2))
mesh=bpy.data.meshes.new('Short flattened textile fibres');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Directional matted cloth pile',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(pile)
export('mascot-rabbit-v300.glb')

# Three readable silhouettes retain the established articulated node names.
for variant in ['ragged','hooded','split']:
 reset('creatures/night-visitor-v21.glb')
 torso=bpy.data.objects.get('Torso');rig=bpy.data.objects.get('HeadRig')
 if torso:
  for v in torso.data.vertices:
   p=v.co;p.y+=.018*math.sin(p.z*27+p.x*19)
   if variant=='ragged':p.x*=1.04+.06*math.sin(p.z*8)
 if rig:
  for o in list(rig.children):
   if o.type!='MESH':continue
   for v in o.data.vertices:
    p=v.co
    if variant=='split':p.x+=.025*math.sin(p.z*12);p.y-=.015*math.exp(-p.x*p.x*200)
    if variant=='ragged':p.z*=1.10
 if variant=='hooded' and rig:
  cloth=material('Heavy torn burial hood',(.021,.025,.021),.99);vs=[];fs=[]
  for j in range(13):
   t=j/12;z=.02+t*.52;r=.21*math.sin(t*math.pi*.62)+.09
   for k in range(28):
    a=.28+k/27*(math.tau-.56);vs.append((math.sin(a)*r,math.cos(a)*r*.83,.05+z))
  for j in range(12):
   for k in range(27):a=j*28+k;fs.append((a,a+1,a+29,a+28))
  m=bpy.data.meshes.new('Open folded fabric hood');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('BurialHood',m);bpy.context.collection.objects.link(o);o.parent=rig;o.data.materials.append(cloth)
 export('visitor-'+variant+'.glb')

reset('creatures/vent-ossuary-v21.glb')
bone=material('Flaking exposed bone lamina',(.46,.405,.29),.86)
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 for v in o.data.vertices:
  p=v.co;p+=v.normal*(.0013*math.sin(p.x*119+p.y*67)*math.sin(p.z*83))
export('vent-ossuary-v300.glb')

reset('props/anatomical-grip.glb')
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data)
 edges=[e for e in bm.edges if e.is_boundary]
 if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=64)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
export('anatomical-grip-v300.glb')
