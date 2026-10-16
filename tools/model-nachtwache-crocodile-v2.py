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

pvc=material('Worn olive PVC',(1,1,1),.73,OUT/'aged-croc-pvc.png')
yellow=material('Faded ochre bed',(.36,.29,.115),.85,ROOT/'games/kinderparadies/assets/aged-plaster.png')
lip=material('Dirty heat welded lip',(.19,.18,.09),.74)
seam=material('Dark PVC weld',(.055,.07,.035),.9)
backing=material('Exposed woven backing',(.012,.019,.017),.98)
ivory=material('Yellowed tapered teeth',(.58,.49,.29),.76,ROOT/'games/kinderparadies/assets/aged-plaster.png')
stain=material('Dried reddish stains',(.115,.021,.014),.93)
eye=material('Amber inset eyes',(.26,.2,.075),.32)
pupil=material('Deep narrow pupils',(.004,.006,.005),.55)
glint=material('Dull ivory catchlight',(.59,.57,.4),.3)
iris=material('Old amber iris',(1,1,1),.34,OUT/'croc-eye.png')
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

def inset_eye(side):
    # A convex UV-mapped corneal cap, not a flat picture or coplanar pupil.
    vertices=[];uvs=[];faces=[];rings=7;segments=40
    for j in range(rings+1):
        r=max(.001,j/rings)
        for i in range(segments):
            a=i*math.tau/segments
            vertices.append((side*1.52+math.cos(a)*r*.16,-4.13-math.sqrt(max(0,1-r*r))*.045,3.6+math.sin(a)*r*.105))
            uvs.append((.5+math.cos(a)*r*.5,.5+math.sin(a)*r*.5))
    for j in range(rings):
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    mesh=bpy.data.meshes.new('Convex iris lens');mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new('Inset glass eye',mesh);bpy.context.collection.objects.link(obj)
    uv=mesh.uv_layers.new()
    for polygon in mesh.polygons:
        for li in polygon.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    finish(obj,iris,jaw)

ellipsoid('Sealed lower mattress',(0,0,.34),(2.22,3.8,.33),pvc,body,.008)
for i in range(15):
    y=-3.4+i*.46
    ellipsoid('Padded pressure chamber',(0,y,.64),(1.67,.265,.17),yellow,body,.012)
    line('Chamber weld',[(-1.5,y-.235,.68),(0,y-.235,.75),(1.5,y-.235,.68)],.012,lip,body)
for side in [-1,1]:
    loft('Long inflated side',[(side*1.94,-3.5,.75,.24,.39),(side*2.02,-1.4,.78,.29,.43),(side*1.98,1.2,.78,.31,.43),(side*1.55,3.35,.56,.26,.28)],pvc,body)
    line('Long welded seam',[(side*2.23,-3.1+i*.19,.79+math.sin(i*.6)*.012) for i in range(34)],.015,seam,body)
    loft('Creased hinge pillar',[(side*1.9,-4.05,1.55,.12,.75),(side*2.02,-3.7,1.62,.29,1.24),(side*1.95,-2.9,1.64,.36,1.27),(side*1.95,-1.9,1.4,.3,1),(side*1.95,-.9,.9,.27,.49)],pvc,body,.025)
    for i in range(6):
        y=-3.55+i*.33;line('Inner pleated mouth seam',[(side*1.78,y,.78),(side*1.72,y,1.35),(side*1.78,y,2.5)],.025,lip,body)
    for y in [-1.45,1.85]:
        leg=ellipsoid('Flattened claw foot',(side*2.45,y,.3),(.72,.67,.24),pvc,body,.015);leg.rotation_euler.z=side*.27
        for i in range(3):ellipsoid('Rubber claw',(side*(2.9+i*.04),y-.36+i*.27,.21),(.22,.105,.1),lip,body)
    for y in [-2.4,.4,2.8]:
        line('Anchor strap',[(side*2.15,y,.3),(side*2.55,y,.07)],.04,lip,body)
        bpy.ops.mesh.primitive_torus_add(major_radius=.08,minor_radius=.012,major_segments=16,minor_segments=6,location=(side*2.6,y,.08));finish(bpy.context.object,metal,body)
loft('Bent tapered tail',[(0,2.75,.48,1.36,.4),(.2,3.5,.45,1,.35),(.55,4.2,.4,.63,.28),(1.05,4.8,.3,.28,.19),(1.5,5.2,.21,.015,.015)],pvc,body)
for i in range(10):
    y=.65+i*.43;x=max(0,(y-3)*.5)
    loft('Soft dorsal scute',[(x,y-.16,1.04-i*.035,.16,.02),(x,y,1.22-i*.045,.18,.24-i*.012),(x,y+.2,1.04-i*.035,.13,.02)],pvc,body)

loft('Broad upper crocodile muzzle',[(0,-4.65,3.01,1.5,.11),(0,-4.5,3.04,1.93,.24),(0,-3.9,3.12,2.03,.31),(0,-2.9,3.24,1.92,.35),(0,-1.9,3.15,1.66,.35),(0,-1.3,3,1.1,.2)],pvc,jaw,.018)
line('Rolled upper lip',[(-1.9,-3.9,2.84),(-1.77,-4.45,2.85),(-1,-4.63,2.87),(0,-4.68,2.88),(1,-4.63,2.87),(1.77,-4.45,2.85),(1.9,-3.9,2.84)],.065,lip,jaw)
loft('Lower heavy jaw',[(0,-4.65,.35,1.5,.07),(0,-4.5,.4,1.95,.22),(0,-3.7,.45,2.08,.27),(0,-2.8,.43,1.9,.28)],pvc,body,.018)
line('Lower rolled jaw edge',[(-1.96,-3.7,.64),(-1.78,-4.4,.62),(-1,-4.62,.6),(0,-4.67,.6),(1,-4.62,.6),(1.78,-4.4,.62),(1.96,-3.7,.64)],.07,lip,body)
for side in [-1,1]:
    ellipsoid('Nostril bolster',(side*.72,-4.07,3.37),(.28,.31,.11),pvc,jaw)
    ellipsoid('Recessed nostril',(side*.72,-4.22,3.435),(.14,.12,.019),backing,jaw)
    ellipsoid('Integrated brow ridge',(side*1.5,-3.48,3.46),(.44,.63,.34),pvc,jaw,.025)
    ellipsoid('Dark recessed eye socket',(side*1.52,-4.045,3.6),(.25,.1,.15),backing,jaw)
    inset_eye(side)
    hood=ellipsoid('Heavy creased eyelid',(side*1.51,-4.045,3.73),(.31,.2,.135),pvc,jaw,.025)
    hood.rotation_euler.y=side*.14
    line('Curved lower eyelid',[(side*1.52+math.cos(a)*.19,-4.12-math.sin(a)*.025,3.6-math.sin(a)*.12) for a in [i/20*math.pi for i in range(21)]],.027,pvc,jaw)
    for i in range(7):
        tooth((side*1.84,-4+i*.32,2.84),.43+rng.random()*.16,.095+rng.random()*.035,-1,jaw,i)
        tooth((side*1.82,-4+i*.32,.67),.23+rng.random()*.13,.09,1,body,i+3)
for i in range(13):
    x=-1.68+i*.28;y=-4.48-.13*(1-(x/1.8)**2)
    tooth((x,y,2.87),.22+abs(x)/1.8*.28+rng.random()*.08,.09+rng.random()*.03,-1,jaw,i)
    if i%2==0:tooth((x,y+.02,.61),.12+abs(x)/1.8*.15,.075,1,body,i)

line('Manufactured upper panel weld',[(-1.8,-3.8,3.34),(-1.1,-4.15,3.38),(0,-4.3,3.35),(1.1,-4.15,3.38),(1.8,-3.8,3.34)],.018,seam,jaw)
for side in [-1,1]:
    for i in range(7):
        y=-3.5+i*.24;line('Compressed seam wrinkle',[(side*2.2,y,.92),(side*2.26,y+.06,1.2),(side*2.21,y+.1,1.5)],.013,lip,body)
    points=[(side*2.31,-3.4,.88),(side*2.32,-3.55,1.1),(side*2.32,-3.42,1.35),(side*2.31,-3.19,1.46),(side*2.3,-3.07,1.22),(side*2.31,-3.18,.96)]
    mesh=bpy.data.meshes.new('Backing patch');mesh.from_pydata(points,[],[(0,1,2,3,4,5)]);mesh.update();obj=bpy.data.objects.new('Torn superficial PVC patch',mesh);bpy.context.collection.objects.link(obj);finish(obj,backing,body)
    line('Ragged patch edge',points+[points[0]],.02,lip,body)
    line('Peeling rubber corner',[(side*2.31,-3.19,1.46),(side*2.42,-3.15,1.5),(side*2.43,-3.09,1.4)],.035,pvc,body)
    for i in range(4):line('Old reddish jaw streak',[(side*(1.89+i*.025),-3.6+i*.3,.72),(side*(1.94+i*.025),-3.55+i*.3,.46)],.012,stain,body)
ellipsoid('Blower inlet',(1.5,3.35,.4),(.2,.6,.2),lip,body)

def mesh_batch(objects,name,origin):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.context.scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bmesh.ops.triangulate(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
    return obj

main=mesh_batch(body,'Body',(0,0,0));top=mesh_batch(jaw,'UpperJaw',(0,-1.3,2.95))
pvc.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.13
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'night-crocodile.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('AUTHORED night-crocodile: body and hinged upper jaw',flush=True)
