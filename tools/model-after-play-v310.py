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
# Weld coincident glTF UV/normal seams without changing the per-loop UVs.
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<-.95],context='VERTS')
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert not any(e.is_boundary for e in bm.edges),'Trimmed source scan is not closed'
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
eyes=[point(.425,.300),point(.575,.300)];mouth=point(.5,.477)
bm=bmesh.new();bm.from_mesh(head.data);tree=BVHTree.FromBMesh(bm)
for p in eyes:
 # The UV anchor is on the lower lid. Meet the actual lid crease with a 9 mm
 # adjustment, rather than the old 36 mm offset into the brow. The iris must
 # also share the eyeball's surface.
 p.z+=.009
 hit=tree.ray_cast(Vector((p.x,-1,p.z)),Vector((0,1,0)))
 if hit[0] is not None:p.y=hit[0].y
bm.free()
def material(name,color,rough=.7):
 m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;return m
skin=material('Photographic clown complexion',(.58,.52,.45),.69);head.data.materials.append(skin)
eye_white=material('Moist clouded sclera',(.14,.12,.10),.45)
iris=material('Small faded irises',(.044,.032,.018),.42)
black=material('Deep anatomical cavities',(.006,.003,.003),.7)
gums=material('Discoloured gum tissue',(.12,.024,.027),.58)
ivory=material('Worn irregular enamel',(.23,.18,.115),.62)
def sphere(name,p,size,mat,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=(0,0,0));o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
 o.location=p;o.data.materials.append(mat)
 if parent:o.parent=parent
 for f in o.data.polygons:f.use_smooth=True
 return o
def cut_at(p,size):
 # Open the dense scanned surface directly. A Boolean against this facial
 # scan can invert or discard whole shells; retaining its original UV loops
 # also keeps the painted lids and lips in place around each aperture.
 surface=bmesh.new();surface.from_mesh(head.data)
 uncut=BVHTree.FromBMesh(surface)
 patch=[]
 for f in surface.faces:
  c=f.calc_center_median()
  if c.y<p.y+size[1] and ((c.x-p.x)/size[0])**2+((c.z-p.z)/size[2])**2<1:patch.append(f)
 assert len(patch)>8,'Facial aperture missed the scanned surface'
 bmesh.ops.delete(surface,geom=patch,context='FACES')
 # Put the new boundary on a continuous contour instead of leaving a row of
 # triangular notches along the eyelids and lips.
 border={v for e in surface.edges if e.is_boundary for v in e.verts}
 for v in border:
  dx=(v.co.x-p.x)/size[0];dz=(v.co.z-p.z)/size[2];r=math.hypot(dx,dz)
  if .55<r<1.5 and v.co.y<p.y+size[1]:
   x=p.x+dx/r*size[0];z=p.z+dz/r*size[2]
   hit=uncut.ray_cast(Vector((x,-1,z)),Vector((0,1,0)))[0]
   if hit is not None:v.co=Vector((x,hit.y,z))
 surface.to_mesh(head.data);surface.free()
 check=bmesh.new();check.from_mesh(head.data);opening=BVHTree.FromBMesh(check)
 hit=opening.ray_cast(Vector((p.x,-1,p.z)),Vector((0,1,0)))[0]
 assert hit is not None and hit.y>p.y+size[1]*.7,'Facial opening is still closed'
 check.free()
for index,p in enumerate(eyes):
 cut_at(p+Vector((0,.005,0)),(.0185,.028,.0065))
 sphere('Inset eyeball '+str(index),p+Vector((0,.018,0)),(.0155,.012,.011),eye_white,head)
 sphere('Iris '+str(index),p+Vector((0,.0056,0)),(.0057,.00065,.0057),iris,head)
 sphere('Pupil '+str(index),p+Vector((0,.00495,0)),(.0026,.0003,.0027),black,head)
cut_at(mouth+Vector((0,.010,0)),(.033,.030,.009))
sphere('Recessed oral cavity',mouth+Vector((0,.035,0)),(.034,.008,.011),black,head)

def tooth(p,half_size,angle):
 bpy.ops.mesh.primitive_cube_add(size=2,location=(0,0,0));o=bpy.context.object;o.name='Individual rounded tooth'
 for v in o.data.vertices:v.co=Vector((v.co.x*half_size[0],v.co.y*half_size[1],v.co.z*half_size[2]))
 bevel=o.modifiers.new('Rounded enamel crown','BEVEL');bevel.width=.00085;bevel.segments=3
 bpy.ops.object.modifier_apply(modifier=bevel.name)
 o.location=p;o.rotation_euler.z=angle;o.rotation_euler.y=rng.uniform(-.07,.07);o.parent=head;o.data.materials.append(ivory)
 for f in o.data.polygons:f.use_smooth=True
 return o

# Dental arches sit behind the lips. Upper incisors overlap the smaller lower
# row; gum margins and roots remain covered by the scanned lip geometry.
for row in [-1,1]:
 sphere('Gum line',mouth+Vector((0,.014,row*.011)),(.030,.009,.003),gums,head)
 for i in range(8):
  x=[-.027,-.0205,-.0135,-.0045,.0045,.0135,.0205,.027][i];edge=abs(x)/.03
  height=(.0052 if row==1 else .0027)+rng.uniform(-.0006,.0006)
  z=(.0061 if row==1 else -.0105)+edge*.0007+rng.uniform(-.0004,.0004)
  width=(.0040 if i in [3,4] else .0030) if row==1 else .0031
  o=tooth(mouth+Vector((x,.009+edge*edge*.030,z)),(width,.0032,height),-x*5)
  shade=ivory.copy();shade.name='Aged enamel '+str(row)+' '+str(i)
  shade.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23*rng.uniform(.67,1),.18*rng.uniform(.67,1),.115,1)
  o.data.materials[0]=shade
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
