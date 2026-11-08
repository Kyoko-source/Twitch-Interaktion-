"""Closed, welded crocodile attraction; Blender metres, Z-up; glTF exports Y-up."""
import bpy, bmesh, math, json, random
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/croc-v385'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(385);body=[];jaw=[];details=[]

def mat(name,color,rough=.8,metal=0,texture=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if texture:
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(texture),check_existing=True);m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 return m
skin=mat('Worn olive PVC',(.30,.34,.16),.77,texture=ROOT/'games/kinderparadies/assets/creatures/croc-scales-v3.png')
gum=mat('Recessed olive gum',(.15,.14,.075),.88)
mouth=mat('Worn burgundy mouth lining',(.17,.065,.047),.88)
toothmat=mat('Aged ivory teeth',(.65,.57,.39),.65)
black=mat('Recessed nostril and pupil',(.009,.014,.009),.72)
amber=mat('Amber glass eye',(.43,.25,.055),.26)
patchmat=mat('Old stitched repair fabric',(.16,.19,.12),.96)
thread=mat('Dark welded seams',(.06,.085,.038),.92)
blood=mat('Dried blood streak',(.12,.013,.010),.42)
wetblood=mat('Wet blood pool',(.17,.014,.011),.18)
mold=mat('Black mildew bloom',(.045,.045,.038),.97)
gash=mat('Torn PVC cavity',(.03,.025,.018),.96)

def finish(o,name,material,target):
 o.name=name;o.data.materials.append(material)
 for f in o.data.polygons:f.use_smooth=True
 target.append(o);return o

def ell(name,p,scale,material,target,seg=32,rings=20):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=p)
 o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,material,target)

def loft(name,sections,material,target,steps=40):
 # Each station is x,y,z,horizontal radius,vertical radius. Both ends are capped.
 verts=[];faces=[]
 for x,y,z,rx,rz in sections:
  for j in range(steps):
   a=j*math.tau/steps;verts.append((x+rx*math.cos(a),y,z+rz*math.sin(a)))
 for i in range(len(sections)-1):
  for j in range(steps):faces.append((i*steps+j,i*steps+(j+1)%steps,(i+1)*steps+(j+1)%steps,(i+1)*steps+j))
 for i in (0,len(sections)-1):
  center=len(verts);verts.append(sections[i][:3])
  for j in range(steps):faces.append((center,i*steps+(j+1)%steps,i*steps+j))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,material,target)

def line(name,points,radius,material,target):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=2;curve.resolution_u=2;curve.use_fill_caps=True
 spl=curve.splines.new('POLY');spl.points.add(len(points)-1)
 for v,p in zip(spl.points,points):v.co=(*p,1)
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
 target.append(o);return o

def weld(objects,name,voxel=None):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 if voxel:
  mod=o.modifiers.new('Watertight fused shell','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Smooth welded transitions','SMOOTH');mod.factor=.6;mod.iterations=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Game topology','DECIMATE');mod.ratio=.38;bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=True
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
 boundary=[e for e in bm.edges if e.is_boundary]
 if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 return o

# Broad abdomen, substantial shoulders and a single continuous tapering tail.
TORSO=[(0,-1.5,1.23,1.30,.96),(0,-.6,1.32,1.80,1.18),(0,.7,1.28,2.0,1.23),(0,1.8,1.10,1.80,1.02),(0,2.8,.79,1.28,.68),(.12,3.8,.52,.84,.43),(.38,4.8,.32,.54,.28),(.70,5.8,.20,.29,.17),(1.02,6.8,.12,.035,.04)]
loft('Torso and tail',TORSO,skin,body)
loft('Lower jaw and continuous mouth floor',[(0,-5.2,.32,.80,.13),(0,-4.7,.35,1.16,.22),(0,-3.8,.37,1.42,.25),(0,-2.8,.39,1.65,.27),(0,-1.65,.50,1.52,.43),(0,-.8,.84,1.40,.69)],skin,body)
for side in (-1,1):
 # Recessed jaw hinges grow from the shoulders; no freestanding cheek slabs.
 ell('Connected cheek and hinge',(side*1.40,-1.18,1.63),(.45,.75,1.12),skin,body)
 for y,offset in ((.15,0),(2.0,-.05)):
  ell('Shoulder thigh',(side*1.65,y,.69),(.66,.76,.61),skin,body)
  arm=ell('Splayed foreleg',(side*2.12,y-.30,.36),(.65,.36,.29),skin,body);arm.rotation_euler.z=side*.25
  ell('Flattened foot',(side*2.35,y-.58,.18),(.57,.55,.17),skin,body)
  for toe in range(3):
   tx=side*(2.0+toe*.29)
   ell('Webbed toe',(tx,y-.96,.17),(.15,.37,.14),skin,body)
   ell('Dark blunt claw',(tx,y-1.25,.14),(.10,.15,.06),thread,details,16,10)
main=weld(body,'Body',.044)
# Fixed lining closes the entire lower mouth; no underside/back holes.
loft('Padded mouth floor',[(0,-5.05,.48,.72,.035),(0,-4.4,.58,1.07,.06),(0,-3.5,.62,1.29,.07),(0,-2.4,.67,1.38,.08),(0,-1.5,.92,1.18,.18)],mouth,details)
for i in range(10):
 y=-4.6+i*.27;width=.95+(y+4.6)*.17
 line('Moulded floor ribs',[(-width,y,.65),(0,y,.69),(width,y,.65)],.025,gum,details)

loft('Closed upper skull',[(0,-5.25,2.82,.82,.16),(0,-4.75,2.93,1.17,.28),(0,-3.8,3.02,1.39,.33),(0,-2.8,3.12,1.60,.42),(0,-1.8,3.09,1.66,.53),(0,-.8,2.87,1.23,.43),(0,-.4,2.60,.70,.20)],skin,jaw)
for side in (-1,1):
 ell('Welded orbital brow',(side*1.2,-2.1,3.45),(.43,.64,.31),skin,jaw)
 ell('Nostril cushion',(side*.60,-4.68,3.16),(.25,.36,.16),skin,jaw)
top=weld(jaw,'UpperJaw',.035)
upper_details=[]
loft('Closed recessed palate',[(0,-5.08,2.67,.70,.035),(0,-4.2,2.67,1.16,.055),(0,-3.2,2.71,1.35,.07),(0,-2.0,2.62,1.40,.12),(0,-.85,2.50,.85,.12)],mouth,upper_details)
for side in (-1,1):
 ell('Inset nostril',(side*.60,-4.84,3.26),(.13,.16,.035),black,upper_details)
 ell('Recessed eye socket',(side*1.40,-2.54,3.48),(.20,.18,.15),thread,upper_details)
 ell('Small embedded amber eye',(side*1.44,-2.61,3.49),(.13,.13,.10),amber,upper_details)
 ell('Vertical pupil',(side*1.46,-2.72,3.49),(.018,.021,.085),black,upper_details,20,12)
 for i in range(20):
  t=i/19;y=-5.0+t*3.55;x=.80+.76*math.sin(t*math.pi*.55)
  # Teeth curve inward and stay rooted inside the gums at both jaws. Longer,
  # more jagged and uneven than a toy mouth: a few snapped off mid-shaft.
  length=.24+.30*math.sin((t+.12)*math.pi)+rng.uniform(-.05,.07)
  broken=rng.random()<.22
  for upper,target,base,direction in [(True,upper_details,2.67,-1),(False,details,.64,1)]:
   length_value=length*(1 if upper else .74)*(.45 if broken else 1)
   tip_radius=.013 if broken else .003
   loft('Rooted ivory tooth',[(side*x,y,base,.072,.072),(side*(x-.025),y-.025,base+direction*length_value*.5,.044,.044),(side*(x-.065),y-.06,base+direction*length_value,tip_radius,tip_radius)],toothmat,target,16)
  ell('Upper gum socket',(side*x,y,2.69),(.12,.12,.055),gum,upper_details,16,10)
  ell('Lower gum socket',(side*x,y,.62),(.10,.10,.05),gum,details,16,10)
 # Fine weld seams sit on the flanks rather than crossing empty space.
 line('Long flank weld',[(side*(1.70-.10*j),.1+j*.5,.89-.04*j) for j in range(5)],.014,thread,details)
 ell('Worn fabric repair',(side*1.91,.4,1.0),(.018,.30,.22),patchmat,details)
 for j in range(6):line('Repair stitching',[(side*1.93,.15+j*.09,.88),(side*1.94,.18+j*.09,1.10)],.006,gum,details)
# Small front teeth complete the curved dental arcade.
for x in [-.60,-.36,-.12,.12,.36,.60]:
 loft('Front upper tooth',[(x,-5.12,2.73,.055,.06),(x,-5.17,2.61,.035,.035),(x*.96,-5.2,2.49,.004,.004)],toothmat,upper_details,16)
 loft('Front lower tooth',[(x,-5.06,.45,.045,.045),(x,-5.08,.53,.025,.03),(x*.96,-5.1,.61,.003,.003)],toothmat,details,16)

def back_surface(y,side):
 a,b=next((a,b) for a,b in zip(TORSO,TORSO[1:]) if a[1]<=y<=b[1])
 t=(y-a[1])/(b[1]-a[1]);cx=a[0]+(b[0]-a[0])*t;z=a[2]+(b[2]-a[2])*t;rx=a[3]+(b[3]-a[3])*t;rz=a[4]+(b[4]-a[4])*t
 return cx+side*rx*.22,z+rz*math.sqrt(1-.22**2)
# Armour follows the actual tapering tail surface, with embedded closed bases.
for i in range(20):
 y=-.3+i*.34
 for side in (-1,1):
  x,z=back_surface(y,side);xa,za=back_surface(y-.16,side);xb,zb=back_surface(y+.16,side)
  width=max(.045,.14-i*.004);height=max(.07,.18-i*.005)
  loft('Low dorsal armour',[(xa,y-.16,za-.06,width*.8,.06),(x,y,z+.03,width,height),(xb,y+.16,zb-.06,width*.8,.06)],skin,details,16)

# A worn-out, mould-blotched attraction rather than a clean balloon: dried
# blood dripping from the dental arcade and torn, discoloured PVC.
ell('Pooled blood on the mouth floor',(0,-3.2,.68,),(.62,.46,.02),wetblood,details,24,12)
for side in (-1,1):
 for i in range(5):
  t=rng.uniform(.08,.85);y=-5.0+t*3.3;x=side*(.84+.72*math.sin(t*math.pi*.55))
  drop=rng.uniform(.45,1.05)
  line('Dried blood drip',[(x,y,2.65),(x+rng.uniform(-.03,.03),y,2.65-drop*.6),(x,y,2.65-drop)],rng.uniform(.012,.028),blood,upper_details)
 for i in range(4):
  t=rng.uniform(.1,.7);y=-4.6+t*2.8
  x0=side*(1.1+.5*t)
  line('Jaw corner blood streak',[(x0*.78,y,.95),(x0*.86,y-.05,.6),(x0*.9,y-.02,.32)],rng.uniform(.02,.04),blood,details)
for i in range(22):
 t=rng.uniform(0,1);y=-.4+6.6*t;side=rng.choice([-1,1])
 x,z=back_surface(y,side)
 bloom=rng.uniform(.14,.34)
 ell('Mildew bloom',(x*.92,y+rng.uniform(-.15,.15),z*.95),(bloom,bloom*1.5,bloom*.32),mold,details,14,8)
for i in range(4):
 y=rng.uniform(-.6,3.4);side=rng.choice([-1,1])
 x,z=back_surface(y,side)
 rim=rng.uniform(.22,.36)
 ell('Torn PVC rim',(x,y,z),(rim,rim*.75,rim*.5),thread,details,16,10)
 ell('Torn PVC cavity',(x*1.03,y,z*1.02),(rim*.68,rim*.5,rim*.4),gash,details,14,8)

fixed=weld(details,'AttachedScutesFeetAndMouth');moving=weld(upper_details,'UpperJawDetails')
bpy.context.scene.cursor.location=(0,-.70,2.68)
bpy.context.view_layer.objects.active=top;top.select_set(True);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');top.select_set(False)
moving.parent=top;moving.matrix_parent_inverse=top.matrix_world.inverted()
fixed.parent=main;fixed.matrix_parent_inverse=main.matrix_world.inverted()
report={}
for o in (main,top,fixed,moving):
 bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);bm.free()
 report[o.name]={'vertices':len(o.data.vertices),'faces':len(o.data.polygons),'non_manifold_edges':bad}
 if bad:raise RuntimeError(f'Open or invalid geometry: {o.name}: {bad}')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'crocodile.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
(OUT/'topology-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report),flush=True)
