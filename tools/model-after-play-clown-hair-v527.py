"""Matted clump grooming for the kitchen clown (After Play 5.2.7).

The 4.0.4 grooming was 11 000 single strands, 0.7-3 mm wide and tapering to a
few hundredths of a millimetre, plus fly-away hairs sticking out of the
silhouette. On screen every strand was thinner than a pixel, so the hair broke
up into loose dots that crawled with every camera move: it read as sparkling
particles over and around the clown. This version grows a few hundred matted
locks instead. Each lock is two crossed ribbons, so it never turns edge-on,
and is 10-26 mm wide at the root and never under ~40 % of that at the tip,
which keeps it above a pixel at play distance. No fly-aways. The fibre look
comes from blond_hair.gdshader (stripes inside each lock, faded by screen
derivative), not from geometry.

UV.x runs from k to k+1 across a ribbon, where k is a per-lock random integer
(0-15) the shader uses as the lock's seed; UV.y runs root (0) to tip (1).

Run: blender --background --python tools/model-after-play-clown-hair-v527.py
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/clown-v527'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'games/kinderparadies/assets/detail-v310/clown-v310.glb'))
head=bpy.data.objects['Head']
# Same scalp region as 4.0.4, so the hair sits where the cap expects it.
scalp=[v for v in head.data.vertices if .015<v.co.z<.16 and
       (v.co.y>.015 or abs(v.co.x)>.105) and v.normal.z>-.35]
assert len(scalp)>150

def export(path,obj):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/path),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)

hair_material=bpy.data.materials.new('Dirty flax blond locks')
hair_material.use_nodes=True
hair_material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.42,.31,.14,1)

report={}
for platform,count,steps in [('desktop',1500,9),('web',700,7)]:
    rng=random.Random(527);verts=[];faces=[];tex=[]
    for lock in range(count):
        root=rng.choice(scalp);p=root.co.copy();n=root.normal.normalized()
        tangent_a=n.orthogonal().normalized();tangent_b=n.cross(tangent_a)
        p+=(tangent_a*rng.uniform(-1,1)+tangent_b*rng.uniform(-1,1))*.008
        side=1 if p.x>=0 else -1
        back=p.y>.08 and abs(p.x)<.095
        length=rng.uniform(.2,.4)
        fan=rng.uniform(.075,.16);phase=rng.uniform(0,math.tau)
        width=rng.uniform(.005,.009) if lock%4 else rng.uniform(.009,.013)  # half-width
        curl=rng.uniform(.004,.013)
        seed=rng.randrange(16)
        twist=rng.uniform(0,math.pi)
        spine=[]
        for step in range(steps):
            t=step/(steps-1)
            spread=math.sin(t*2.25)
            offset=Vector((side*fan*spread*(.35 if back else 1.),
                           (.075 if back else .023)*spread+.025*t,
                           .065*math.sin(t*math.pi)-length*t*t))
            # Locks lie on the scalp first and only lift a little, so their
            # roots stay under the cap and nothing floats above the head.
            offset+=n*(.004+.03*math.sin(math.pi*t))
            offset+=Vector((math.sin(phase+t*7),math.cos(phase+t*6),math.sin(phase+t*8)))*curl*t
            spine.append(p+offset)
        for ribbon_index in range(2):
            angle=twist+ribbon_index*math.pi/2
            for step,c in enumerate(spine):
                t=step/(steps-1)
                tangent=(spine[min(step+1,steps-1)]-spine[max(step-1,0)]).normalized()
                axis=n.cross(tangent)
                if axis.length<.01:axis=tangent_a.copy()
                axis.normalize();up=tangent.cross(axis).normalized()
                ribbon=(axis*math.cos(angle)+up*math.sin(angle)).normalized()
                taper=.42+.58*(1-t)**.8;start=len(verts)
                verts.extend([c-ribbon*width*taper,c+ribbon*width*taper])
                tex.extend([(seed,t),(seed+1,t)])
                if step:faces.append((start-2,start-1,start+1,start))
    mesh=bpy.data.meshes.new('MattedBlondHair');mesh.from_pydata(verts,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='Surface')
    for loop in mesh.loops:uv.data[loop.index].uv=tex[loop.vertex_index]
    for poly in mesh.polygons:poly.use_smooth=True
    mesh.materials.append(hair_material)
    obj=bpy.data.objects.new('MattedBlondHair',mesh);bpy.context.collection.objects.link(obj)
    export(f'clown-hair-{platform}.glb',obj)
    report[platform]={'locks':count,'ribbons_per_lock':2,'vertices':len(verts),'triangles':len(faces)*2,
                      'root_width_mm':[10,26],'min_tip_share':.42,'fly_aways':0}
    bpy.data.objects.remove(obj,do_unlink=True)

(OUT/'provenance.json').write_text(json.dumps({
    'author':'After Play original modelling',
    'license':'Original project geometry',
    'source_head':'Existing credited clown head used for scalp fitting only; not copied',
    'reason':'4.0.4 single-strand grooming aliased into sparkling dots; replaced by matted locks',
    'outputs':report},indent=2),encoding='utf-8')
print(json.dumps(report))
