"""Original metre-scale horror attraction, shared by WebGL and native Godot.
Run in Blender 4.5 background mode. Two mesh batches retain a hinged upper jaw.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/creatures'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(1311);body=[];jaw=[]

def material(name,color,roughness=.75,texture=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=roughness
    if texture:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(texture),check_existing=True)
        m.node_tree.links.new(t.outputs['Color'],s.inputs['Base Color'])
    return m

pvc=material('Worn olive PVC',(1,1,1),.73,OUT/'croc-scales-v3.png')
yellow=material('Faded ochre bed',(.36,.29,.115),.85,ROOT/'games/kinderparadies/assets/aged-plaster.png')
lip=material('Dirty heat welded lip',(.19,.18,.09),.74)
seam=material('Dark PVC weld',(.055,.07,.035),.9)
backing=material('Exposed woven backing',(.012,.019,.017),.98)
ivory=material('Yellowed tapered teeth',(.58,.49,.29),.76,ROOT/'games/kinderparadies/assets/aged-plaster.png')
stain=material('Dried reddish stains',(.115,.021,.014),.93)
eye=material('Amber inset eyes',(.26,.2,.075),.32)
pupil=material('Deep narrow pupils',(.004,.006,.005),.55)
glint=material('Dull ivory catchlight',(.59,.57,.4),.3)
metal=material('Tarnished attachment rings',(.1,.09,.06),.6)

def finish(obj,m,collection):
    obj.data.materials.append(m)
    if obj.type=='MESH':
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
        for f in obj.data.polygons:f.use_smooth=True
    collection.append(obj);return obj

def ellipsoid(name,pos,size,m,collection,wrinkle=.0,segments=24,rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=pos)
    obj=bpy.context.object;obj.name=name
    for vertex in obj.data.vertices:
        p=vertex.co.copy();w=1+wrinkle*math.sin(p.z*39+p.x*13)*math.sin(p.y*24)
        vertex.co=Vector((p.x*size[0]*w,p.y*size[1]*w,p.z*size[2]*w))
    return finish(obj,m,collection)

def line(name,points,radius,m,collection):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=1;data.bevel_depth=radius;data.bevel_resolution=2
    poly=data.splines.new('POLY');poly.points.add(len(points)-1)
    for p,xyz in zip(poly.points,points):p.co=(*xyz,1)
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(m);collection.append(obj);return obj

def loft(name,sections,m,collection,wrinkle=.012):
    samples=[]
    for j in range(len(sections)-1):
        for k in range(5):
            t=k/5;t=t*t*(3-2*t);samples.append([a*(1-t)+b*t for a,b in zip(sections[j],sections[j+1])])
    samples.append(sections[-1]);n=32;vertices=[];faces=[];uvs=[]
    for j,(x,y,z,rx,rz) in enumerate(samples):
        for i in range(n):
            a=i*math.tau/n;w=1+wrinkle*math.sin(a*11+y*9)*math.sin(a*5+y*4)
            vertices.append((x+math.cos(a)*rx*w,y,z+math.sin(a)*rz*w));uvs.append((i/n*2,j/(len(samples)-1)*3))
    for j in range(len(samples)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple((len(samples)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new()
    for polygon in mesh.polygons:
        crosses_seam=any(v%n==0 for v in polygon.vertices) and any(v%n==n-1 for v in polygon.vertices) and len(polygon.vertices)==4
        for li in polygon.loop_indices:
            vertex=mesh.loops[li].vertex_index;u,v=uvs[vertex]
            uv.data[li].uv=(2 if crosses_seam and vertex%n==0 else u,v)
    return finish(obj,m,collection)

def tooth(pos,length,radius,direction,collection,index):
    x,y,z=pos;vertices=[];faces=[];n=16;rows=10;uvs=[]
    for j in range(rows):
        t=j/(rows-1);r=radius*(1-t)**.7+.009
        for i in range(n):
            a=i*math.tau/n;vertices.append((x+math.cos(a)*r,y+math.sin(a)*r+t*t*.08,z+direction*t*length));uvs.append((i/n,t))
    for j in range(rows-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple((rows-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new('Soft tapered tooth');mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new('Irregular tapered tooth',mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new()
    for polygon in mesh.polygons:
        for li in polygon.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    finish(obj,ivory,collection)

# The attraction is still inflated vinyl, but the silhouette follows a real
# crocodilian: a long tapering rostrum, rear-set eyes and low splayed limbs.
ellipsoid('Continuous sewn floor',(0,.1,.33),(2.08,3.7,.32),pvc,body,.012)
for i in range(15):
    y=-3.45+i*.46
    ellipsoid('Quilted pneumatic floor',(0,y,.64),(1.67,.26,.16),yellow,body,.018)
    line('Floor chamber weld',[(-1.5,y-.225,.67),(0,y-.225,.75),(1.5,y-.225,.67)],.012,lip,body)
for side in [-1,1]:
    loft('Anatomical flank',[(side*1.58,-3.5,.68,.18,.27),(side*1.98,-1.5,.78,.31,.43),(side*1.96,1.1,.72,.36,.43),(side*1.4,3.3,.5,.3,.3)],pvc,body,.023)
    loft('Integrated muscular hinge',[(side*1.63,-3.0,1.25,.22,.62),(side*1.8,-2.4,1.7,.34,1.12),(side*1.76,-1.5,1.65,.36,1.08),(side*1.85,-.6,1.1,.3,.64),(side*1.98,.15,.79,.24,.39)],pvc,body,.025)
    line('Heat welded flank seam',[(side*(2.25-.11*max(0,i-22)/10),-2.5+i*.17,.77) for i in range(33)],.014,seam,body)
    for y in [-1.2,1.8]:
        limb=ellipsoid('Splayed bent forelimb',(side*2.13,y,.38),(.59,.58,.29),pvc,body,.025);limb.rotation_euler.z=side*.55
        ellipsoid('Webbed reptile foot',(side*2.61,y-.28,.19),(.4,.49,.15),pvc,body,.028)
        for k in range(4):
            toe=ellipsoid('Separate wrinkled toe',(side*(2.75+.04*k),y-.65+k*.22,.16),(.26,.095,.08),pvc,body,.03)
            toe.rotation_euler.z=-side*.2
            ellipsoid('Worn vinyl claw',(side*(2.95+.04*k),y-.68+k*.22,.135),(.12,.055,.045),ivory,body)
    for y in [-2.0,.7,2.7]:
        line('Tensioned webbing strap',[(side*2.15,y,.32),(side*2.57,y,.055)],.035,lip,body)
        bpy.ops.mesh.primitive_torus_add(major_radius=.075,minor_radius=.012,major_segments=16,minor_segments=6,location=(side*2.6,y,.07));finish(bpy.context.object,metal,body)
    for i in range(8):
        y=-2.5+i*.25
        line('Radial vinyl compression crease',[(side*1.85,y,1.08),(side*2.02,y+.06,1.33),(side*1.99,y+.11,1.57)],.012,lip,body)
# Continuous substantial hindquarters connect the throat to an armored back.
# The front half remains an open bouncy mouth; the rear is no longer a flat mat.
loft('Continuous shoulders haunches and tapering tail',[(0,-1.15,1.48,1.48,1.08),(0,-.4,1.42,1.77,1.0),(0,.7,1.29,1.92,.92),(0,1.6,1.14,1.65,.84),(0,2.65,.82,1.12,.57),(.15,3.6,.57,.79,.42),(.42,4.4,.39,.53,.29),(.82,5.35,.24,.28,.17),(1.18,6.35,.13,.025,.025)],pvc,body,.025)
for i in range(18):
    y=-.75+i*.38;x=max(0,(y-2.8)*.34)
    z=2.49-max(0,y+.2)*.39 if y<3.2 else .96-(y-3.2)*.24
    for side in [-1,1]:
        loft('Armored dorsal scute',[(x+side*.3,y-.15,z,.13,.025),(x+side*.3,y,z+.12,.15,.21),(x+side*.3,y+.17,z,.11,.025)],pvc,body)
for side in [-1,1]:
    for row in range(4):
        for col in range(7):
            y=-.3+col*.4;x=side*(1.6-row*.24);z=1.78+row*.15-max(0,y)*.2
            ellipsoid('Overlapping flank scale',(x,y,z),(.16,.23,.065),pvc,body,.02,16,8)
    line('Rear weld seam',[(side*(1.77-max(0,y)*.17),y,.94) for y in [i*.13 for i in range(25)]],.018,seam,body)

loft('Long tapered upper rostrum',[(0,-5.05,2.67,.77,.085),(0,-4.82,2.75,1.1,.22),(0,-4.15,2.89,1.3,.28),(0,-3.4,3.08,1.47,.34),(0,-2.65,3.24,1.65,.43),(0,-1.75,3.13,1.62,.4),(0,-1.15,2.98,1.2,.16)],pvc,jaw,.024)
loft('Dark recessed palate',[(0,-4.86,2.63,.83,.035),(0,-4.1,2.65,1.17,.07),(0,-3.2,2.78,1.32,.09),(0,-1.65,2.85,1.24,.06)],backing,jaw,.018)
loft('Tapered lower mandible',[(0,-5.05,.32,.76,.07),(0,-4.82,.38,1.12,.18),(0,-4,.44,1.4,.24),(0,-3.1,.48,1.66,.27),(0,-2.5,.46,1.74,.24)],pvc,body,.025)
for side in [-1,1]:
    line('Scalloped upper gum',[(side*(.79+.85*t),-4.98+t*3.45,2.61+.19*t+.045*math.sin(t*44)) for t in [k/48 for k in range(49)]],.06,lip,jaw)
    line('Scalloped lower gum',[(side*(.8+.98*t),-4.98+t*2.9,.5+.15*t+.025*math.sin(t*37)) for t in [k/40 for k in range(41)]],.055,lip,body)
    ellipsoid('Raised nostril ridge',(side*.62,-4.55,2.97),(.2,.33,.15),pvc,jaw,.02)
    ellipsoid('Deep nostril opening',(side*.64,-4.77,3.025),(.09,.115,.038),backing,jaw)
    brow=ellipsoid('Rear-set bony eye ridge',(side*1.21,-2.53,3.5),(.41,.64,.3),pvc,jaw,.028);brow.rotation_euler.z=side*.15
    ellipsoid('Recessed forward eye socket',(side*1.23,-3.05,3.54),(.22,.105,.13),backing,jaw)
    ellipsoid('Small amber glass iris',(side*1.23,-3.127,3.54),(.125,.044,.082),eye,jaw)
    ellipsoid('Vertical narrow pupil',(side*1.23,-3.169,3.54),(.016,.008,.071),pupil,jaw)
    ellipsoid('Pinpoint corneal highlight',(side*1.2,-3.177,3.57),(.014,.006,.013),glint,jaw)
    line('Heavy hooded eyelid',[(side*1.23+math.cos(a)*.18,-3.13,3.54+math.sin(a)*.105) for a in [k*math.pi/24 for k in range(25)]],.043,pvc,jaw)
    for k in range(12):
        t=k/11;xx=.87+.72*t;yy=-4.82+t*3.1
        tooth((side*xx,yy,2.6+.2*t),.22+rng.random()*.28+( .12 if k in [2,6] else 0),.065+rng.random()*.035,-1,jaw,k)
        if k%3!=1:tooth((side*(xx+.03),yy+.08,.6),.13+rng.random()*.2,.065,1,body,k)
    for k in range(6):
        y=-4.35+k*.35
        line('Longitudinal rostral crease',[(side*(.35+k*.13),y,3.13+k*.025),(side*(.38+k*.13),y+.25,3.17+k*.025)],.013,lip,jaw)
    for k in range(5):
        yy=-3.0+k*.32
        ellipsoid('Raised cheek scale',(side*1.59,yy,3.12),(.075,.13,.09),pvc,jaw,.02)
    # Superficial repairs and pigment stains, without tissue or open injuries.
    patch=ellipsoid('Woven repair patch',(side*2.225,-.35,.86),(.018,.3,.23),backing,body)
    for k in range(6):
        line('Repair stitch',[(side*2.25,-.61+k*.1,.73),(side*2.25,-.58+k*.1,.92)],.008,lip,body)
    for k in range(3):
        line('Old dark red vinyl smear',[(side*(1.42+k*.035),-3.7+k*.27,.65),(side*(1.46+k*.035),-3.65+k*.27,.41)],.015,stain,body)
for k in range(8):
    x=-.7+k*.2
    tooth((x,-4.96,2.62),.16+rng.random()*.1,.06,-1,jaw,k)
    if k%2==0:tooth((x,-4.94,.51),.1+rng.random()*.07,.05,1,body,k)
ellipsoid('Ribbed blower inlet',(1.45,3.2,.4),(.23,.65,.23),lip,body)
for k in range(10):
    bpy.ops.mesh.primitive_torus_add(major_radius=.225,minor_radius=.018,major_segments=20,minor_segments=6,location=(1.45,3.1+k*.065,.4),rotation=(math.pi/2,0,0));finish(bpy.context.object,seam,body)

def mesh_batch(objects,name,origin):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.context.scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bmesh.ops.triangulate(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
    return obj

main=mesh_batch(body,'Body',(0,0,0));top=mesh_batch(jaw,'UpperJaw',(0,-1.15,2.98))
pvc.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.1
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'night-crocodile-v4.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('AUTHORED night-crocodile-v4: anatomical head, two mesh batches and hinged jaw',flush=True)
