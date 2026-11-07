"""Long Horse head on a real skull scan.

Base: "Horse Skull" (https://skfb.ly/6EDDE) by Eric Bauer, CC BY 4.0, expected at
tools/art-source/horse-skull/horse_skull.glb (not committed; download from the
link). Skin, ears, eyes, jaw, lower lip, tongue, mane and painting are original.
Blender coordinates: muzzle +Y, up +Z. glTF export turns +Y into Godot -Z.

Run: blender -b --python tools/model-after-play-scanned-horse-v421.py [-- web] [-- OUT_DIR]
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.noise import noise, noise_vector

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'tools/art-source/horse-skull'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
WEB = 'web' in ARGS
OUT = next((Path(a) for a in ARGS if a != 'web'), ROOT / 'games/kinderparadies/assets/horse-v420')
OUT.mkdir(parents=True, exist_ok=True)
CACHE = SRC / 'skull-prepared.blend'
LENGTH = 1.44
rng = random.Random(421)


def material(name, color, rough, metal=0.):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1); p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    v = m.node_tree.nodes.new('ShaderNodeVertexColor'); v.layer_name = 'Decay'
    m.node_tree.links.new(v.outputs['Color'], p.inputs['Base Color'])
    return m


def active(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o


def apply(o, mod):
    active(o); bpy.ops.object.modifier_apply(modifier=mod.name)


def decimate(o, faces):
    if len(o.data.polygons) > faces:
        d = o.modifiers.new('Budget', 'DECIMATE'); d.ratio = faces / len(o.data.polygons); apply(o, d)


def remesh(o, voxel, smooth=4):
    active(o); o.data.remesh_voxel_size = voxel; o.data.remesh_voxel_adaptivity = 0; bpy.ops.object.voxel_remesh()
    if smooth:
        s = o.modifiers.new('Smooth', 'SMOOTH'); s.factor = .6; s.iterations = smooth; apply(o, s)


def duplicate(o, name):
    c = o.copy(); c.data = o.data.copy(); c.name = name; bpy.context.collection.objects.link(c); return c


def new_mesh(name, verts, faces):
    d = bpy.data.meshes.new(name); d.from_pydata(verts, [], faces); d.update()
    o = bpy.data.objects.new(name, d); bpy.context.collection.objects.link(o); return o


def recalc(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(o.data); bm.free()


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join(); objs[0].name = name; return objs[0]


# 1. The scan, joined, oriented and scaled once, then cached.
if CACHE.exists():
    bpy.ops.wm.open_mainfile(filepath=str(CACHE))
    skull = bpy.data.objects['ScannedSkull']
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC / 'horse_skull.glb'))
    parts = [o for o in bpy.data.objects if o.type == 'MESH']
    skull = join(parts, 'ScannedSkull'); active(skull)
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for o in [o for o in bpy.data.objects if o.type != 'MESH']: bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS'); skull.location = (0, 0, 0)
    s = LENGTH / max(skull.dimensions)
    skull.rotation_mode = 'XYZ'; skull.rotation_euler = (0, 0, math.radians(90)); skull.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Merge the scan's split chunks and seal tiny cracks before decimation.
    bm = bmesh.new(); bm.from_mesh(skull.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0004); bm.to_mesh(skull.data); bm.free()
    decimate(skull, 260000)
    bpy.ops.wm.save_as_mainfile(filepath=str(CACHE))

for o in list(bpy.data.objects):
    if o is not skull: bpy.data.objects.remove(o)
lo = Vector([min(v.co[i] for v in skull.data.vertices) for i in range(3)])
hi = Vector([max(v.co[i] for v in skull.data.vertices) for i in range(3)])
# Place the cranium like the previous head: back near y=-.22, teeth near z=-.13.
shift = Vector((-(lo.x + hi.x) / 2, -.22 - lo.y, -.13 - lo.z))
for v in skull.data.vertices: v.co += shift
lo += shift; hi += shift
skull.data.update()
print('SKULL', [round(x, 3) for x in lo], [round(x, 3) for x in hi])

skin_m = material('Torn equine mask skin', (.125, .118, .106), .62)
bone_m = material('Damp exposed ivory', (.46, .41, .31), .45)
flesh_m = material('Wet torn tissue', (.18, .009, .014), .29)
void_m = material('Deep orbital darkness', (.009, .005, .004), .98)
hair_m = material('Matted black horse mane', (.016, .011, .008), .94)
eye_m = material('Wet clouded eye', (.105, .11, .10), .08)

bvh = BVHTree.FromObject(skull, bpy.context.evaluated_depsgraph_get())


def find_orbit(side):
    """Rays from the side; the orbit is where they pass deep into the skull."""
    hits = []
    for iy in range(60):
        for iz in range(40):
            y = lo.y + (hi.y - lo.y) * iy / 59; z = lo.z + (hi.z - lo.z) * iz / 39
            start = Vector((side * 1.0, y, z))
            hit = bvh.ray_cast(start, Vector((-side, 0, 0)))
            if hit[0] is None: continue
            if y < lo.y + .55 * (hi.y - lo.y) and z > lo.z + .45 * (hi.z - lo.z) and abs(hit[0].x) < .07:
                hits.append(Vector((side * .0, y, z)))
    centre = sum(hits, Vector()) / max(1, len(hits))
    edge = bvh.ray_cast(Vector((side, centre.y, centre.z + .06)), Vector((-side, 0, 0)))[0]
    rim_x = abs(edge.x) if edge else (hi.x - .02)
    return Vector((side * (rim_x - .045), centre.y, centre.z)), len(hits)


orbits = {side: find_orbit(side) for side in (-1, 1)}
print('ORBITS', {k: ([round(c, 3) for c in v[0]], v[1]) for k, v in orbits.items()})
# The occipital processes hang lower than the teeth; measure the cheek-tooth row only.
row = sorted(v.co.z for v in skull.data.vertices if lo.y + .32 < v.co.y < .80 and abs(v.co.x) < .2)
tooth_z = row[len(row) // 200]
print('TOOTH ROW', round(tooth_z, 3), 'lowest', round(lo.z, 3))

# 2. Bone budget for this build.
bone = duplicate(skull, 'Mask_Damp_exposed_ivory')
decimate(bone, 40000 if WEB else 95000)

# 3. Skin: the skull's own envelope, pulled tight over the real bone.
skin = duplicate(skull, 'Mask_Torn_equine_mask_skin')
decimate(skin, 40000)
bm = bmesh.new(); bm.from_mesh(skin.data); bm.normal_update()
for v in bm.verts: v.co += v.normal * .028
bm.to_mesh(skin.data); bm.free()
# Long leaf-shaped ears at the poll, tilted back and out, hollow in front.
for side in (-1, 1):
    base = Vector((side * .085, lo.y + .11, hi.z - .06)); axis = Vector((side * .16, -.26, .22)).normalized(); length = .25
    across = Vector((1, 0, 0)).cross(axis).normalized(); side_dir = axis.cross(across).normalized()
    verts, faces = [], []; n = 20; rows = 9
    for i in range(rows + 1):
        t = i / rows; w = .060 * math.sin(min(1, t * 1.15 + .18) * math.pi) ** .8 + .004; d = .026 * (1 - t * .8) + .003
        c = base + axis * length * t + across * .03 * t * t
        for k in range(n):
            a = k * math.tau / n; front = math.sin(a) > 0
            verts.append(c + side_dir * math.cos(a) * w + across * math.sin(a) * d * (.25 if front else 1))
    for i in range(rows):
        for k in range(n): a = i * n + k; b = i * n + (k + 1) % n; faces.append((a, b, b + n, a + n))
    faces.append(tuple(reversed(range(n)))); faces.append(tuple(rows * n + k for k in range(n)))
    ear = new_mesh('Ear', verts, faces); recalc(ear); skin = join([skin, ear], 'Mask_Torn_equine_mask_skin')
remesh(skin, .0085 if WEB else .0055, 6)
sw = skin.modifiers.new('Taut over bone', 'SHRINKWRAP'); sw.target = skull; sw.wrap_method = 'NEAREST_SURFACEPOINT'; sw.offset = .012
sw.vertex_group = ''
# Ears must not collapse onto the skull: only wrap what is already near bone.
vg = skin.vertex_groups.new(name='wrap')
for v in skin.data.vertices:
    d = bvh.find_nearest(v.co)[3]
    vg.add([v.index], max(0., min(1., 1 - (d - .02) / .05)), 'REPLACE')
sw.vertex_group = 'wrap'; apply(skin, sw)
s = skin.modifiers.new('Relax', 'SMOOTH'); s.factor = .5; s.iterations = 3; apply(skin, s)

# Lips pulled back from the upper teeth; tears that open onto the bone.
def tear(p):
    t = 0.
    t += max(0, 1 - ((p.x / .055) ** 2 + ((p.y - .70) / .24) ** 2)) * 1.4 * (p.z > tooth_z + .20)
    for side in (-1, 1):
        t += max(0, 1 - (((p.x - side * .22) / .06) ** 2 + ((p.y - .36) / .17) ** 2 + ((p.z - .06) / .08) ** 2)) * (1.3 if side > 0 else .7)
    return t + noise(p * 22) * .45 + noise(p * 61) * .18

bm = bmesh.new(); bm.from_mesh(skin.data)
gone = [f for f in bm.faces if (lambda c: (c.z < tooth_z + .085 + .022 * noise(c * 14) and c.y > .05) or tear(c) > .62)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=gone, context='FACES')
bm.to_mesh(skin.data); bm.free()
solid = skin.modifiers.new('Hide thickness', 'SOLIDIFY'); solid.thickness = .007; solid.offset = -1; apply(skin, solid)
decimate(skin, 26000 if WEB else 70000)

# 4. Wet tissue lining the tears, just above the bone.
flesh = duplicate(skull, 'Mask_Wet_torn_tissue'); decimate(flesh, 60000)
bm = bmesh.new(); bm.from_mesh(flesh.data); bm.normal_update()
keep = set(f for f in bm.faces if .30 < tear(f.calc_center_median()) < .78)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f not in keep], context='FACES')
for v in bm.verts: v.co += v.normal * .004
bm.to_mesh(flesh.data); bm.free()
decimate(flesh, 8000 if WEB else 20000)

# 5. Eyes in the real orbits, with a dark socket lining.
dark = []
for side, (centre, count) in orbits.items():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=.040, location=centre)
    eye = bpy.context.object; eye.name = 'Eye'; eye.scale = (.85, 1.1, 1.0); eye.data.materials.append(eye_m)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=.012, location=centre + Vector((side * .032, .018, 0)))
    pupil = bpy.context.object; pupil.scale = (.6, 1.9, .55); pupil.data.materials.append(void_m)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=.075, location=centre - Vector((side * .03, 0, 0)))
    socket = bpy.context.object; socket.data.materials.append(void_m)
    dark += [eye, pupil, socket]
for o in dark: active(o); bpy.ops.object.transform_apply(scale=True)

# 6. Jaw: a skinned mandible carrying mirrored real cheek teeth and a tongue.
hinge_at = Vector((0, lo.y + .17, tooth_z + .11))
# Measure the real face width slice by slice, then loft one smooth mandible:
# a deep ramus up to the hinge, a long tapering body and a rounded chin.
coords = [v.co.copy() for v in skull.data.vertices if tooth_z < v.co.z < tooth_z + .12]
def width_at(y):
    near = [abs(c.x) for c in coords if abs(c.y - y) < .02]
    return (max(near) if near else .06) + .02
rows = []
for i in range(26):
    t = i / 25; y = lo.y + .10 + (hi.y - .02 - lo.y - .10) * t
    if t < .22:
        k = t / .22; w = .15 + .04 * math.sin(k * math.pi); top = tooth_z + .13 * (1 - k) + .00 * k; bottom = tooth_z + .03 - .23 * math.sin(min(1, k * 1.25) * math.pi / 2)
    else:
        k = (t - .22) / .78; w = min(width_at(y), .19) * (1 - .25 * k); top = tooth_z - .008; bottom = tooth_z - .20 + .12 * k ** 1.3
    rows.append((y, w, top, bottom))
verts, faces = [], []; n = 32
for y, w, top, bottom in rows:
    for k in range(n):
        a = k * math.tau / n; c = math.cos(a); q = math.sin(a)
        verts.append(Vector((math.copysign(abs(c) ** .65, c) * w, y, (top + bottom) / 2 + math.copysign(abs(q) ** .75, q) * (top - bottom) / 2)))
for i in range(len(rows) - 1):
    for k in range(n): a = i * n + k; b = i * n + (k + 1) % n; faces.append((a, b, b + n, a + n))
faces.append(tuple(reversed(range(n)))); faces.append(tuple((len(rows) - 1) * n + k for k in range(n)))
jaw = new_mesh('Jaw_Torn_equine_mask_skin', verts, faces); recalc(jaw)
remesh(jaw, .009 if WEB else .0065, 6)
bm = bmesh.new(); bm.from_mesh(jaw.data); bm.normal_update()
for v in bm.verts:
    p = v.co.copy()
    v.co += v.normal * (.003 * noise(p * 30) + .0015 * noise(p * 90) - .010 * max(0, noise(p * 5)))
gone = [f for f in bm.faces if (lambda c: c.z > tooth_z - .035 + .015 * noise(c * 16) and c.y > lo.y + .30 and abs(c.x) < .16)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=gone, context='FACES'); bm.to_mesh(jaw.data); bm.free()
solid = jaw.modifiers.new('Lip thickness', 'SOLIDIFY'); solid.thickness = .008; solid.offset = -1; apply(jaw, solid)
decimate(jaw, 12000 if WEB else 32000)

lower = duplicate(skull, 'Jaw_Damp_exposed_ivory'); decimate(lower, 120000)
bm = bmesh.new(); bm.from_mesh(lower.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not (v.co.z < tooth_z + .045 and lo.y + .30 < v.co.y < .86)], context='VERTS')
for v in bm.verts: v.co.z = 2 * (tooth_z - .006) - v.co.z
bmesh.ops.reverse_faces(bm, faces=bm.faces); bm.to_mesh(lower.data); bm.free()
decimate(lower, 8000 if WEB else 22000)

bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, radius=1, location=(0, .45, tooth_z - .07))
tongue = bpy.context.object; tongue.name = 'Jaw_Wet_torn_tissue'; tongue.scale = (.085, .34, .028)
active(tongue); bpy.ops.object.transform_apply(scale=True)
for v in tongue.data.vertices: v.co.z -= .03 * ((v.co.y - .45) / .34) ** 2 - .006 * noise(v.co * 20)

# 7. Mane: long wet clumps, curved by gravity instead of straight spikes.
verts, faces = [], []
for i in range(220 if WEB else 360):
    x = rng.uniform(-.09, .09); y = rng.uniform(lo.y - .02, lo.y + .32); z = hi.z - .02 - abs(x) * .3
    drop = rng.uniform(.18, .55); side = 1 if x > 0 else -1; width = rng.uniform(.004, .009)
    pts = [Vector((x, y, z))]
    for k in range(1, 7):
        t = k / 6
        pts.append(Vector((x + side * (.06 * t + rng.uniform(-.01, .01)), y - .10 * t + rng.uniform(-.015, .015), z + .02 * t - drop * t * t)))
    base = len(verts)
    for k, p in enumerate(pts):
        w = width * (1 - k / 7)
        verts += [p + Vector((0, w, 0)), p - Vector((0, w, 0))]
    for k in range(6):
        a = base + 2 * k; faces.append((a, a + 1, a + 3, a + 2))
mane = new_mesh('Mask_Matted_black_horse_mane', verts, faces)

# 8. Paint every part through the same 'Decay' vertex colours as before.
def paint(o, base, kind):
    print('PAINT', o.name, len(o.data.polygons), flush=True)
    assert len(o.data.polygons) > 0, o.name + ' is empty'
    o.data.materials.clear(); o.data.materials.append({'skin': skin_m, 'bone': bone_m, 'flesh': flesh_m, 'hair': hair_m}[kind] if kind in ('skin', 'bone', 'flesh', 'hair') else base)
    attr = o.data.color_attributes.new(name='Decay', type='BYTE_COLOR', domain='CORNER')
    m = o.data.materials[0]; tone = tuple(m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3])
    for poly in o.data.polygons:
        for li in poly.loop_indices:
            p = o.data.vertices[o.data.loops[li].vertex_index].co
            n1 = noise(p * 13); fine = noise(p * 76)
            col = [max(.004, c * (.84 + n1 * .24) + fine * .018) for c in tone]
            if kind == 'skin':
                mange = max(0, min(1, (noise(p * 5.5) + .05) * 3))
                col = [c * (1 - mange * .3) + g * mange * .3 for c, g in zip(col, (.21, .20, .18))]
                lip = abs(p.z - tooth_z - .02) < .11 and p.y > .05
                edge = max(0, min(1, (tear(p) - .40) * 3.2)) + (max(0, 1 - abs(p.z - (tooth_z + .07)) / .04) + max(0, 1 - abs(p.z - (tooth_z - .045)) / .03)) * lip
                blood = max(0, min(1, edge + max(0, noise(p * 9)) * .25))
                col = [a * (1 - blood) + b * blood for a, b in zip(col, (.095 + fine * .025, .006, .009))]
            elif kind == 'bone':
                grime = max(0, min(1, .5 + noise(p * 18) * .9))
                col = [c * (1 - grime * .55) + g * grime * .55 for c, g in zip(col, (.16, .11, .06))]
                if p.z < tooth_z + .03: col = [c * .92 + d * .08 for c, d in zip(col, (.25, .2, .09))]
            attr.data[li].color = (*col, 1)
    for f in o.data.polygons: f.use_smooth = kind != 'hair'
    active(o); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=.01); bpy.ops.object.mode_set(mode='OBJECT')

bpy.data.objects.remove(skull)
for o, kind in [(skin, 'skin'), (bone, 'bone'), (flesh, 'flesh'), (jaw, 'skin'), (lower, 'bone'), (tongue, 'flesh'), (mane, 'hair')]:
    paint(o, None, kind)
for o in dark:
    attr = o.data.color_attributes.new(name='Decay', type='BYTE_COLOR', domain='CORNER')
    tone = o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
    for li in range(len(o.data.loops)): attr.data[li].color = tuple(tone)
    for f in o.data.polygons: f.use_smooth = True
sockets = join(dark, 'Mask_Deep_orbital_darkness')

root = bpy.data.objects.new('EquineMaskHeadOnly', None); bpy.context.collection.objects.link(root)
root['anatomy'] = 'head_only_no_torso_or_limbs'; root['design'] = 'Rotting hide over a scanned horse skull'
hinge = bpy.data.objects.new('JawHinge', None); bpy.context.collection.objects.link(hinge); hinge.parent = root; hinge.location = hinge_at
for o in [skin, bone, flesh, sockets, mane]: o.parent = root
for o in [jaw, lower, tongue]:
    o.parent = hinge
    for v in o.data.vertices: v.co -= hinge_at
parts = [o for o in bpy.data.objects if o.type == 'MESH']
name = 'long-horse-head-web.glb' if WEB else 'long-horse-head.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', export_yup=True, export_apply=True,
                          export_attributes=True, export_extras=True, export_cameras=False, export_lights=False)
triangles = sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons) for o in parts)
(OUT / 'provenance.json').write_text(json.dumps({
    'credits': [{'author': 'Eric Bauer ("Horse Skull")', 'license': 'CC BY 4.0', 'url': 'https://skfb.ly/6EDDE'}],
    'modified': 'decimated, scaled, mirrored lower cheek teeth; original skin, ears, eyes, jaw, tongue, mane and painting',
    'source': 'tools/model-after-play-scanned-horse-v421.py', 'triangles': triangles}, indent=2) + '\n')
print('SCANNED HORSE COMPLETE', len(parts), 'meshes', triangles, 'triangles', flush=True)
