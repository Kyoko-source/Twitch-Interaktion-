"""Rebuild the clown's face from the credited scan, retaining its real UVs.

The old merged head had vertex-painted blocks, closed eyes and oversized square
teeth. This derivative has scanned skin, actual eye openings and small teeth.
"""
import bpy, bmesh, math, random
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'games/kinderparadies/assets'; OUT=A/'detail-v310'
rng=random.Random(310)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(A/'revamp-v300/kitchen-clown-v300.glb'))
old=bpy.data.objects['Head']; pivot=old.location.copy()
for o in list(old.children): bpy.data.objects.remove(o,do_unlink=True)
bpy.data.objects.remove(old,do_unlink=True)
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'tools/art-source/anatomy/LeePerrySmith.glb'))
imported=[o for o in bpy.context.scene.objects if o not in before]
head=next(o for o in imported if o.type=='MESH')
for o in imported:
 if o!=head: bpy.data.objects.remove(o,do_unlink=True)
head.name='Head'
for v in head.data.vertices: v.co=head.matrix_world@v.co
head.matrix_world.identity()
bm=bmesh.new();bm.from_mesh(head.data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<-.95],context='VERTS')
bm.to_mesh(head.data);bm.free()
for v in head.data.vertices:
 p=v.co.copy();v.co=Vector((p.x*.0858,p.y*.0792+.0231,1.7612+p.z*.0858))-pivot
head.location=pivot
head.data.materials.clear()
for attr in list(head.data.color_attributes): head.data.color_attributes.remove(attr)
uv=head.data.uv_layers.active.data
# The scan's provided image uses the opposite V origin to Blender. Keeping the
# old coordinates put neck detail on the forehead. Correct it explicitly.
for value in uv: value.uv.y=1-value.uv.y
sub=head.modifiers.new('Scanned facial contours','SUBSURF');sub.levels=1
bpy.context.view_layer.objects.active=head;bpy.ops.object.modifier_apply(modifier=sub.name)
uv=head.data.uv_layers.active.data
def point(u,v):
 l=min(head.data.loops,key=lambda l:(uv[l.index].uv.x-u)**2+(1-uv[l.index].uv.y-v)**2)
 return head.data.vertices[l.vertex_index].co.copy()
eyes=[point(.415,.332),point(.585,.332)];mouth=point(.5,.477)
bm=bmesh.new();bm.from_mesh(head.data);tree=BVHTree.FromBMesh(bm)
for p in eyes:
 p.z+=.036
 hit=tree.ray_cast(Vector((p.x,-1,p.z)),Vector((0,1,0)))
 if hit[0] is not None:p.y=hit[0].y
bm.free()
def material(name,color,rough=.7):
 m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;return m
skin=material('Photographic clown complexion',(.58,.52,.45),.69);head.data.materials.append(skin)
eye_white=material('Moist clouded sclera',(.028,.023,.019),.21)
iris=material('Small faded irises',(.009,.008,.007),.2)
black=material('Deep anatomical cavities',(.006,.003,.003),.7)
gums=material('Discoloured gum tissue',(.12,.024,.027),.58)
ivory=material('Worn irregular enamel',(.47,.40,.27),.43)
def sphere(name,p,size,mat,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,0,0));o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
 o.location=p;o.data.materials.append(mat)
 if parent:o.parent=parent
 for f in o.data.polygons:f.use_smooth=True
 return o
def cut_at(p,size):
 cutter=sphere('Temporary anatomical opening',p+pivot,size,black)
 bpy.context.view_layer.objects.active=head
 mod=head.modifiers.new('Open eyelids and mouth','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
for index,p in enumerate(eyes):
 cut_at(p+Vector((0,.004,0)),(.021,.027,.010))
 sphere('Inset eyeball '+str(index),p+Vector((0,.014,0)),(.018,.014,.009),eye_white,head)
 sphere('Iris '+str(index),p+Vector((.001,-.001,-.003)),(.005,.0018,.005),iris,head)
 sphere('Pupil '+str(index),p+Vector((.001,-.0025,-.003)),(.0023,.0012,.0030),black,head)
cut_at(mouth+Vector((0,.006,0)),(.040,.035,.016))
sphere('Recessed oral cavity',mouth+Vector((0,.015,0)),(.041,.025,.018),black,head)
for row in [-1,1]:
 sphere('Gum line',mouth+Vector((0,-.005,row*.012)),(.036,.007,.004),gums,head)
 for i in range(8):
  if row==-1 and i==5:continue
  x=(i-3.5)*.0089
  o=sphere('Individual rounded tooth',mouth+Vector((x,-.011+abs(x)*.08,row*.009+math.sin(i*.8)*.0015)),(.0037,.004,.0045+rng.random()*.002),ivory,head)
  o.rotation_euler.y=rng.uniform(-.13,.13)
for f in head.data.polygons:f.use_smooth=True
# Sparse, genuinely attached dark hairs replace the old solid hair panels.
hair=material('Sparse greasy hair',(.025,.012,.008),.95)
bpy.context.view_layer.update()
scalp=[v for v in head.data.vertices if v.co.z>.075 and v.co.y>-.025 and abs(v.co.x)>.065]
verts=[];faces=[]
for v in rng.sample(scalp,min(650,len(scalp))):
 p=v.co.copy();n=v.normal.normalized();tip=p+n*.001+Vector((rng.uniform(-.008,.008),.003,-rng.uniform(.015,.055)))
 a=len(verts);verts.extend([p+Vector((-.0006,0,0)),p+Vector((.0006,0,0)),tip]);faces.append((a,a+1,a+2))
mesh=bpy.data.meshes.new('Attached individual hair strands');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('MattedHairStrands',mesh);bpy.context.collection.objects.link(o);o.parent=head;o.data.materials.append(hair)
# The remaining neck material is replaced in Godot; do not export its old
# shared face normal-map dependency into the new stand-alone model.
for mat in bpy.data.materials:
 if 'Cracked greasepaint' in mat.name and mat.use_nodes:
  for node in list(mat.node_tree.nodes):
   if node.type=='TEX_IMAGE':mat.node_tree.nodes.remove(node)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(OUT/'clown-v310.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('V310 face landmarks',[(tuple(p)) for p in eyes],tuple(mouth),flush=True)
