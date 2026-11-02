"""Original, scalp-rooted blond clown hair, in the existing head's local frame.

Exports only the new hair. The credited scanned face and its fitted eyes/teeth
remain unchanged. Deterministic curved fibre ribbons share one material.
"""
import bpy, math, random
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/encounter-v360'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'games/kinderparadies/assets/detail-v310/clown-v310.glb'))
head = bpy.data.objects['Head']
rng = random.Random(360)
scalp = [v for v in head.data.vertices
         if v.co.z > .045 and (v.co.y > -.025 or v.co.z > .155)
         and (abs(v.co.x) > .058 or v.co.z > .155) and v.normal.z > -.4]
assert len(scalp) > 150
verts, faces, tex = [], [], []
for strand in range(2100):
    root = rng.choice(scalp)
    p = root.co.copy()
    n = root.normal.normalized()
    side = 1 if p.x > 0 else -1
    # Long, greasy side locks; broken tufts swept up and backwards at the crown.
    crown = p.z > .145 and abs(p.x) < .075
    length = rng.uniform(.10, .25) if crown else rng.uniform(.15, .34)
    fan = rng.uniform(.045, .115)
    curl = rng.uniform(.008, .028)
    phase = rng.uniform(0, math.tau)
    width = rng.uniform(.0007, .0022)
    angle = rng.uniform(0, math.tau)
    previous = None
    for step in range(9):
        t = step / 8
        if crown:
            offset = Vector((side * fan * math.sin(t * 2.0), .055 * t,
                             length * t - .11 * t * t))
        else:
            offset = Vector((side * fan * math.sin(t * 2.2), .035 * t,
                             .050 * math.sin(t * math.pi) - length * t * t))
        offset += n * (.003 + .025 * math.sin(t * math.pi))
        offset += Vector((math.sin(phase+t*8), math.cos(phase+t*7),
                          math.sin(phase+t*6))) * curl * t * t
        c = p + offset
        tangent = (c - previous).normalized() if previous is not None else n
        ribbon = tangent.cross(Vector((math.cos(angle), math.sin(angle), .2)))
        if ribbon.length < .01:
            ribbon = Vector((1, 0, 0))
        ribbon.normalize()
        taper = max(.045, (1 - t) ** .6)
        start = len(verts)
        verts.extend([c - ribbon * width * taper, c + ribbon * width * taper])
        tex.extend([(0, t), (1, t)])
        if step:
            faces.append((start-2, start-1, start+1, start))
        previous = c
mesh = bpy.data.meshes.new('Curled blond fibres rooted in scanned scalp')
mesh.from_pydata(verts, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Fibre length')
for loop in mesh.loops:
    uv.data[loop.index].uv = tex[loop.vertex_index]
hair = bpy.data.objects.new('MattedBlondHair', mesh)
bpy.context.collection.objects.link(hair)
material = bpy.data.materials.new('Tarnished blond fibres')
material.diffuse_color = (.39, .29, .13, 1)
hair.data.materials.append(material)
for poly in mesh.polygons:
    poly.use_smooth = True
bpy.ops.object.select_all(action='DESELECT')
hair.select_set(True)
bpy.context.view_layer.objects.active = hair
bpy.ops.export_scene.gltf(filepath=str(OUT / 'clown-blond-hair.glb'),
    export_format='GLB', use_selection=True, export_cameras=False, export_lights=False)
print('V360 HAIR', len(scalp), 'scalp anchors;', len(verts), 'vertices;',
      tuple(min(v[i] for v in verts) for i in range(3)),
      tuple(max(v[i] for v in verts) for i in range(3)), flush=True)
