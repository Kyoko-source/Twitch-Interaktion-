"""Scalp-fitted blond grooming and an original patched faux-leather costume cap.

No new anatomy or scanned body material. Exports use the existing head frame.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/clown-v404'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'games/kinderparadies/assets/detail-v310/clown-v310.glb'))
head=bpy.data.objects['Head']
scalp=[v for v in head.data.vertices if .015<v.co.z<.16 and
       (v.co.y>.015 or abs(v.co.x)>.105) and v.normal.z>-.35]
assert len(scalp)>150

def mesh_object(name,verts,faces,tex=None,material=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    if tex:
        uv=mesh.uv_layers.new(name='Surface')
        for loop in mesh.loops:uv.data[loop.index].uv=tex[loop.vertex_index]
    for p in mesh.polygons:p.use_smooth=True
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    if material:mesh.materials.append(material)
    return obj

def material(name,color,roughness=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=roughness
    return m

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/path),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)

hair_material=material('Dirty flax blond fibres',(.42,.31,.14))
report={}
for platform,count,steps in [('desktop',11000,7),('web',4500,6)]:
    rng=random.Random(404);verts=[];faces=[];tex=[]
    for strand in range(count):
        root=rng.choice(scalp);p=root.co.copy();n=root.normal.normalized()
        # Hundreds of strands share a handful of scalp vertices; starting every
        # one of them at the exact same point z-fights into a flickering mess
        # under a moving flashlight. Spread the roots a little.
        tangent_a=n.orthogonal().normalized();tangent_b=n.cross(tangent_a)
        p+=(tangent_a*rng.uniform(-1,1)+tangent_b*rng.uniform(-1,1))*.006
        side=1 if p.x>=0 else -1
        back=p.y>.08 and abs(p.x)<.095
        length=rng.uniform(.21,.43)
        fan=rng.uniform(.075,.17);phase=rng.uniform(0,math.tau)
        width=rng.uniform(.0007,.0017) if strand%5 else rng.uniform(.0017,.0032)
        fly=strand%13==0
        curl=rng.uniform(.006,.019)
        previous=None;angle=rng.uniform(0,math.tau)
        for step in range(steps):
            t=step/(steps-1)
            spread=math.sin(t*2.25)
            offset=Vector((side*fan*spread*(.35 if back else 1.),
                           (.075 if back else .023)*spread+.025*t,
                           .065*math.sin(t*math.pi)-length*t*t))
            offset+=n*(.003+.035*math.sin(math.pi*t))
            offset+=Vector((math.sin(phase+t*9),math.cos(phase+t*8),math.sin(phase+t*10)))*curl*t
            if fly:offset.z+=.08*math.sin(t*2.5);offset.x+=side*.035*t
            c=p+offset
            tangent=(c-previous).normalized() if previous is not None else n
            ribbon=tangent.cross(Vector((math.cos(angle),math.sin(angle),.25)))
            if ribbon.length<.01:ribbon=Vector((1,0,0))
            ribbon.normalize();taper=max(.025,(1-t)**.72);start=len(verts)
            verts.extend([c-ribbon*width*taper,c+ribbon*width*taper]);tex.extend([(0,t),(1,t)])
            if step:faces.append((start-2,start-1,start+1,start))
            previous=c
    hair=mesh_object('MattedBlondHair',verts,faces,tex,hair_material)
    export(f'clown-hair-{platform}.glb',[hair])
    report[platform]={'strands':count,'vertices':len(verts),'triangles':len(faces)*2}
    bpy.data.objects.remove(hair,do_unlink=True)

# Hand-cut six-panel cap. Its folded point sags backwards, leaving the brow
# and eyes exposed. Adjacent panels share a position but have their own UVs.
def cap_point(t,a):
    radius=(1-t)**.78
    bend=Vector((-.18*t*t,.075*t*t,.137+.62*t-.43*t*t))
    r=1+.032*math.sin(a*11+t*9)+.018*math.sin(a*23-t*14)
    z=.005*math.sin(a*3+.8)*(1-t)+.003*math.sin(a*7+t*17)*math.sin(math.pi*t)
    return bend+Vector((math.cos(a)*.151*radius*r,math.sin(a)*.157*radius*r,z))

panels=[]
colors=[(.43,.32,.24),(.52,.40,.31),(.37,.30,.25),(.49,.37,.29),(.46,.35,.30),(.56,.44,.34)]
for panel in range(6):
    verts=[];faces=[];tex=[];rows=23;cols=13
    for i in range(rows+1):
        t=.992*i/rows
        for j in range(cols+1):
            a=(panel+j/cols)*math.tau/6
            verts.append(cap_point(t,a));tex.append((j/cols,t))
    for i in range(rows):
        for j in range(cols):
            k=i*(cols+1)+j;faces.append((k,k+1,k+cols+2,k+cols+1))
    obj=mesh_object(f'FauxLeatherPanel{panel}',verts,faces,tex,material(f'Patched faux leather {panel}',colors[panel]))
    solid=obj.modifiers.new('Turned leather thickness','SOLIDIFY');solid.thickness=.0025
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=solid.name)
    panels.append(obj)

verts=[];faces=[]
def tube(points,radius,sides=6):
    start=len(verts)
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        side=tangent.cross(Vector((0,1,0)))
        if side.length<.01:side=tangent.cross(Vector((1,0,0)))
        side.normalize();up=tangent.cross(side).normalized()
        for j in range(sides):verts.append(p+radius*(side*math.cos(j*math.tau/sides)+up*math.sin(j*math.tau/sides)))
        if i:
            for j in range(sides):
                a=start+(i-1)*sides+j;b=start+(i-1)*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))

# Recessed seam welts and a rolled, uneven lower edge.
for panel in range(6):tube([cap_point(i/42*.985,panel*math.tau/6) for i in range(43)],.0023)
patch_levels=[.33,.52,.45,.58,.38,.64]
for panel,t in enumerate(patch_levels):
    tube([cap_point(t,(panel+j/24)*math.tau/6) for j in range(25)],.0017)
brim=[]
for i in range(145):
    p=cap_point(0,i/144*math.tau);p.z-=.003;brim.append(p)
tube(brim,.006,8)
welts=mesh_object('RolledHemAndSeamWelts',verts,faces,material=material('Aged leather edges',(.19,.12,.075)))
panels.append(welts)

verts=[];faces=[]
for panel in range(6):
    a=panel*math.tau/6
    for i in range(1,34):
        t=i/36*.98
        # Each thick waxed stitch is a little bridge across a real seam.
        width=.022/max(.25,(1-t)**.6)
        p=cap_point(t-.006,a-width);q=cap_point(t+.006,a+width)
        center=(p+q)*.5;out=Vector((math.cos(a),math.sin(a),.35)).normalized()
        tube([p+out*.002,p.lerp(center,.55)+out*.006,q.lerp(center,.55)+out*.006,q+out*.002],.00095,5)
for i in range(83):
    a=i/83*math.tau;p=cap_point(.022,a-.012);q=cap_point(.043,a+.012)
    out=Vector((math.cos(a),math.sin(a),0));tube([p+out*.003,(p+q)*.5+out*.006,q+out*.003],.00085,5)
for panel,t in enumerate(patch_levels):
    for j in range(1,18):
        a=(panel+j/18)*math.tau/6;p=cap_point(t-.009,a-.008);q=cap_point(t+.009,a+.008)
        out=Vector((math.cos(a),math.sin(a),.3)).normalized()
        tube([p+out*.002,(p+q)*.5+out*.005,q+out*.002],.0009,5)
stitches=mesh_object('IndividualWaxedStitches',verts,faces,material=material('Dirty waxed thread',(.11,.075,.041)))
panels.append(stitches)

# A small, dull costume bell hangs from the folded tip; no animation or collider.
tip=cap_point(.993,0)
bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=tip+Vector((-.006,.008,-.004)),scale=(.014,.014,.016))
bell=bpy.context.object;bell.name='TarnishedCostumeBell';bell.data.materials.append(material('Tarnished brass',(.21,.16,.075),.53));panels.append(bell)
export('patched-costume-cap.glb',panels)
report['cap']={'panels':6,'seam_stitches':198,'hem_stitches':83,'top_height':round(float(tip.z),4),'material':'Original patched faux leather; no human anatomy'}
(OUT/'provenance.json').write_text(json.dumps({'author':'After Play original modelling','license':'Original project geometry','source_head':'Existing credited clown head used for fitting only; not copied into these accessories','outputs':report},indent=2)+'\n',encoding='utf-8')
print('CLOWN V404',json.dumps(report),flush=True)
