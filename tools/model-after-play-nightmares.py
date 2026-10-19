"""Original skeletal duct animal and articulated visitor. Blender 4.5, metres.

The duct animal uses an equine cranium, open nasal passages and a segmented
neck; it is an original sculpt inspired by long-necked equine folklore.
"""
import bpy, bmesh, math, random
from mathutils import Vector
from mathutils.noise import noise_vector
from pathlib import Path

OUT=Path(__file__).resolve().parents[1]/'games/kinderparadies/assets/creatures'
rng=random.Random(20261019)

def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def mat(name,c,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*c,1);s.inputs['Roughness'].default_value=rough
 return m

def finish(o,m):
 o.data.materials.append(m)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 for p in o.data.polygons:p.use_smooth=True
 return o

def egg(name,p,scale,m,segments=24):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=16,location=p)
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co=Vector((v.co.x*scale[0],v.co.y*scale[1],v.co.z*scale[2]))
 return finish(o,m)

def strand(name,points,radii,m,n=12):
 pts=[Vector(p) for p in points];verts=[];faces=[]
 for j,p in enumerate(pts):
  tangent=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
  axis=Vector((1,0,0)) if abs(tangent.x)<.95 else Vector((0,1,0))
  side=tangent.cross(axis).normalized();up=side.cross(tangent).normalized()
  for k in range(n):
   a=k*math.tau/n;verts.append(p+radii[j]*(math.cos(a)*side+math.sin(a)*up))
 for j in range(len(pts)-1):
  for k in range(n):a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
 faces.extend([tuple(reversed(range(n))),tuple((len(pts)-1)*n+k for k in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,m)

def cut(o,cutter):
 bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('True excavated cavity','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

def join(parts,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name=name;return parts[0]

def pigment(o,base):
 m=o.data.materials[0];v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Decay'
 m.node_tree.links.new(v.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 attr=o.data.color_attributes.new(name='Decay',type='BYTE_COLOR',domain='CORNER')
 for p in o.data.polygons:
  for li in p.loop_indices:
   co=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co
   age=noise_vector(co*17).x*.10+noise_vector(co*73).y*.025
   attr.data[li].color=(*[max(.012,c+age) for c in base],1)

def export(name):
 bpy.ops.export_scene.gltf(filepath=str(OUT/name),export_format='GLB',export_yup=True,export_apply=True,export_attributes=True,export_extras=True)

reset()
ivory=mat('Excavated weathered ivory',(.58,.53,.39));dark=mat('Unlit bone cavities',(.011,.009,.007));sinew=mat('Dried exposed sinew',(.13,.058,.046))
enamel=mat('Cracked irregular molars',(.48,.40,.26));mane=mat('Black filament mane',(.018,.015,.012))
# Continuous lofted cranium. Nasal end is angular and narrow, with a high crest.
sections=[(-.59,-1.18,.055,.07),(-.66,-1.18,.14,.18),(-.78,-1.21,.205,.22),(-.96,-1.27,.17,.16),(-1.15,-1.32,.115,.13),(-1.37,-1.37,.105,.115),(-1.57,-1.42,.13,.10),(-1.65,-1.42,.09,.075)]
verts=[];faces=[];n=48
for j,(y,z,rx,rz) in enumerate(sections):
 for k in range(n):
  a=k*math.tau/n;ridge=1+.045*math.cos(a*3+j*.8)
  verts.append((math.sin(a)*rx*ridge,y,z+math.cos(a)*rz*ridge))
for j in range(len(sections)-1):
 for k in range(n):a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
faces.extend([tuple(reversed(range(n))),tuple((len(sections)-1)*n+k for k in range(n))])
mesh=bpy.data.meshes.new('Equine bone vault');mesh.from_pydata(verts,[],faces);mesh.update()
skull=bpy.data.objects.new('Head',mesh);bpy.context.collection.objects.link(skull);finish(skull,ivory)
bpy.context.view_layer.objects.active=skull;sub=skull.modifiers.new('Bone contour','SUBSURF');sub.levels=1;bpy.ops.object.modifier_apply(modifier=sub.name)
for s in [-1,1]:
 cut(skull,egg('Excavation cutter',(s*.165,-.84,-1.21),(.12,.145,.155),dark))
 cut(skull,egg('Nasal cutter',(s*.062,-1.56,-1.40),(.058,.20,.085),dark))
 egg('Deep orbital void',(s*.105,-.84,-1.22),(.055,.10,.10),dark)
 strand('Zygomatic arch',[(s*.18,-.72,-1.23),(s*.23,-.89,-1.32),(s*.14,-1.12,-1.40)],[.024,.033,.017],ivory,16)
 strand('Split nasal rim',[(s*.06,-1.65,-1.32),(s*.10,-1.42,-1.26),(s*.075,-1.2,-1.21)],[.013,.022,.012],ivory)
 # The broken jaw consists of exposed thin mandibular rami, not a rubber mouth.
 strand('Broken mandibular ramus',[(s*.15,-.77,-1.34),(s*.17,-1.02,-1.70),(s*.095,-1.50,-1.76)],[.029,.024,.018],ivory,16)
 for k in range(8):
  y=-1.05-k*.065;length=.08+rng.random()*.13
  strand('Worn tooth',[(s*.10,y,-1.43),(s*.098,y-.01,-1.43-length*.7),(s*.085,y-.02,-1.43-length)],[.017,.012,.003],enamel,8)
 for k in range(4):
  y=-1.12-k*.09
  strand('Hanging tendon',[(s*.17,y,-1.32),(s*.19,y+.03,-1.52),(s*.12,y-.06,-1.72)],[.008,.005,.002],sinew,8)
strand('Incisive arch',[(-.09,-1.6,-1.46),(0,-1.67,-1.47),(.09,-1.6,-1.46)],[.017,.024,.017],ivory)
for k in range(5):strand('Broken front tooth',[(-.075+k*.034,-1.64,-1.46),(-.075+k*.034,-1.67,-1.55-rng.random()*.05)],[.015,.004],enamel,8)
strand('Raised sagittal crest',[(0,-.60,-1.14),(0,-.77,-.98),(0,-1.02,-1.10),(0,-1.35,-1.23)],[.018,.03,.018,.008],ivory)
# Impossible articulated neck descends from ABOVE the dark duct, bending twice.
points=[]
for i in range(39):
 t=i/38;points.append(Vector((.13*math.sin(t*math.tau)*math.sin(t*math.pi),-.58*t+.18*math.sin(t*math.pi*1.4),.98-2.14*t)))
strand('Exposed spinal cord',points,[.042]*len(points),sinew,16)
for i,p in enumerate(points):
 tangent=(points[min(i+1,38)]-points[max(0,i-1)]).normalized();rotation=Vector((0,0,1)).rotation_difference(tangent)
 b=egg('Cervical vertebra',p,(.10+.018*math.sin(i*.7),.075,.037),ivory,16);b.rotation_mode='QUATERNION';b.rotation_quaternion=rotation
 for s in [-1,1]:
  a=p+Vector((s*.07,0,0));strand('Vertebral process',[a,a+Vector((s*.085,.04,.025)),a+Vector((s*.10,.08,.015))],[.022,.014,.002],ivory,8)
for k in range(34):
 i=k%35;p=points[i];strand('Straggling black mane',[p+Vector((0,.05,0)),p+Vector((.035*math.sin(k),.14,-.10)),p+Vector((.07*math.sin(k*2),.19,-.22-rng.random()*.2))],[.004,.003,.0005],mane,5)
# Fine fracture seams on the face stay actual recessed-looking geometry.
for s in [-1,1]:
 for k in range(5):
  y=-.74-k*.15;strand('Cranial fracture',[(s*.07,y,-1.035-k*.055),(s*.10,y-.035,-1.055-k*.055),(s*.08,y-.065,-1.07-k*.055)],[.002,.003,.001],dark,5)
for material in [ivory,enamel,sinew,mane,dark]:
 parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0]==material]
 if parts:
  o=join(parts,material.name.replace(' ',''));pigment(o,tuple(material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3]))
root=bpy.data.objects.new('DuctOssuary',None);bpy.context.collection.objects.link(root);root['anatomy']='head_and_neck_only';root['design']='original equine ossuary'
for o in list(bpy.data.objects):
 if o!=root:o.parent=root
export('vent-ossuary-v21.glb')

reset()
cloth=mat('Ragged funeral fabric',(.038,.043,.041),.99);skin=mat('Desiccated visitor skin',(.34,.29,.22));void=mat('Excavated face',(.005,.004,.003));tooth=mat('Visitor enamel',(.52,.44,.32))
# Tapered ragged shroud, with folded silhouette instead of a primitive torso.
verts=[];faces=[];rings=[(.18,.31),(.4,.29),(.8,.25),(1.2,.27),(1.5,.32),(1.63,.18)]
for j,(z,r) in enumerate(rings):
 for k in range(36):
  a=k*math.tau/36;rr=r*(1+.09*math.sin(k*2.9+j*.4));verts.append((math.sin(a)*rr,math.cos(a)*rr*.62,z+(.05*math.sin(k*3.4) if j==0 else 0)))
for j in range(5):
 for k in range(36):a=j*36+k;b=j*36+(k+1)%36;faces.append((a,b,b+36,a+36))
faces.extend([tuple(reversed(range(36))),tuple(5*36+k for k in range(36))])
mesh=bpy.data.meshes.new('Tattered shroud');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Torso',mesh);bpy.context.collection.objects.link(o);finish(o,cloth)
head=egg('Head',(0,-.015,1.85),(.145,.13,.245),skin,32)
for s in [-1,1]:
 cut(head,egg('Eye cutter',(s*.067,-.115,1.91),(.058,.065,.065),void))
 egg('Hollow eyes',(s*.067,-.085,1.91),(.041,.045,.043),void)
 strand('Cheek ridge',[(s*.11,-.09,1.87),(s*.10,-.14,1.80),(s*.043,-.14,1.73)],[.022,.02,.011],skin)
cut(head,egg('Mouth cutter',(0,-.118,1.74),(.068,.07,.09),void));egg('Mouth darkness',(0,-.084,1.74),(.049,.04,.072),void)
strand('Nasal bone',[(0,-.12,1.91),(0,-.19,1.83),(0,-.17,1.81)],[.017,.025,.014],skin)
for k in range(6):strand('Teeth',[(-.045+k*.018,-.145,1.79),(-.044+k*.018,-.15,1.76)],[.006,.003],tooth,6)
for s in [-1,1]:
 before=set(bpy.data.objects)
 strand('Upper sleeve',[(s*.26,0,1.53),(s*.35,-.02,1.18),(s*.34,-.11,.96)],[.087,.066,.045],cloth,16)
 strand('Bony forearm',[(s*.34,-.11,.98),(s*.36,-.15,.69)],[.036,.024],skin)
 egg('Palm',(s*.36,-.16,.64),(.06,.028,.085),skin)
 for k in range(4):
  x=s*(.32+k*.025);strand('Jointed elongated finger',[(x,-.16,.62),(x+s*.017,-.19,.52),(x+s*.015,-.25,.46)],[.012,.008,.004],skin,8)
 strand('Thumb',[(s*.31,-.16,.67),(s*.28,-.21,.62),(s*.30,-.25,.58)],[.016,.012,.006],skin,8)
 parts=[o for o in bpy.data.objects if o not in before];arm=join(parts,'ArmL' if s<0 else 'ArmR')
 pivot=Vector((s*.26,0,1.53))
 for vertex in arm.data.vertices:vertex.co-=pivot
 arm.location=pivot
 before=set(bpy.data.objects)
 strand('Calf',[(s*.12,0,.4),(s*.14,.015,.10)],[.061,.033],cloth,12);egg('Bare foot',(s*.14,-.085,.07),(.065,.15,.05),skin)
 join([o for o in bpy.data.objects if o not in before],'LegL' if s<0 else 'LegR')
for o in bpy.data.objects:
 if o.type=='MESH' and o.data.materials[0] in [skin,cloth]:pigment(o,(.30,.25,.20) if o.data.materials[0]==skin else (.035,.04,.037))
head_rig=bpy.data.objects.new('HeadRig',None);bpy.context.collection.objects.link(head_rig);head_rig.location=(0,0,1.6)
bpy.context.view_layer.update()
for o in list(bpy.data.objects):
 if o.type=='MESH' and not o.name.startswith(('Arm','Leg','Torso')):
  world=o.matrix_world.copy();o.parent=head_rig;o.matrix_parent_inverse=head_rig.matrix_world.inverted();o.matrix_world=world
root=bpy.data.objects.new('NightVisitor',None);bpy.context.collection.objects.link(root)
for o in list(bpy.data.objects):
 if o!=root and o.parent is None:o.parent=root
export('night-visitor-v21.glb')
print('Exported original ossuary and visitor meshes')
