"""Old Happyland stereo for the party room, After Play 4.11.0.

A 1970s hi-fi wall: two walnut floor speakers with woven grille cloth, the left
grille fallen off and leaning against the cabinet so its woofer, mid-range and
tweeter show; a rack of amplifier and tuner with brushed aluminium faces,
knurled knobs, a tuning dial behind smoked glass and toggle switches; a record
deck with platter, record and tone arm; a low cabinet with a smoked glass door.
The party mode's VU lamps and the printed label stay from the game and sit on
these front plates, so the layout follows the old fitted hulls exactly.

Run: blender -b --python tools/model-after-play-stereo-v4110.py   (Blender 5.0)
Output: games/kinderparadies/assets/party-v4110/party-stereo.glb (+ textures)
Coordinates: Blender (x, y, z) = Godot stereo-local (x, -z, y); front faces -Y.
"""
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'games/kinderparadies'
OUT = GAME / 'assets/party-v4110'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4111)

bpy.ops.wm.read_factory_settings(use_empty=True)
PARTS = []

def image_from(array, name):
    h, w = array.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.concatenate([array, np.ones((h, w, 1), np.float32)], axis=2)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    img.filepath_raw = str(OUT / (name + '.png')); img.file_format = 'PNG'; img.save()
    return img

def brushed(size=512):
    streak = rng.normal(0, 1, (1, size)).repeat(size, 0)
    streak = np.cumsum(rng.normal(0, .02, (size, size)), axis=1) * .1 + streak * .04
    base = .72 + streak + rng.normal(0, .015, (size, size))
    return image_from(np.clip(base, 0, 1)[..., None].repeat(3, 2).astype(np.float32), 'stereo-brushed-aluminium')

def record(size=512):
    yy, xx = np.mgrid[0:size, 0:size] / size - .5
    r = np.hypot(xx, yy) * 2
    grooves = .045 + .02 * np.sin(r * 900) + .015 * (np.sin(r * 37) > .95)
    img = np.stack([grooves] * 3, -1)
    label = r < .33
    img[label] = np.array([.62, .16, .14])
    img[r < .03] = .02
    return image_from(img.astype(np.float32), 'stereo-record')

ALU_IMG = brushed(); REC_IMG = record()
WOOD_IMG = bpy.data.images.load(str(GAME / 'assets/wood.png'))
CLOTH_IMG = bpy.data.images.load(str(GAME / 'assets/pbr/fabric_pattern_07/albedo.jpg'))
CLOTH_NRM = bpy.data.images.load(str(GAME / 'assets/pbr/fabric_pattern_07/normal.jpg')); CLOTH_NRM.colorspace_settings.name = 'Non-Color'

def material(name, color, rough=.5, metal=0., image=None, normal=None, scale=1.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    bsdf.inputs['Roughness'].default_value = rough; bsdf.inputs['Metallic'].default_value = metal
    coord = nt.nodes.new('ShaderNodeTexCoord'); mapping = nt.nodes.new('ShaderNodeMapping'); mapping.inputs['Scale'].default_value = (scale, scale, scale)
    nt.links.new(coord.outputs['UV'], mapping.inputs['Vector'])
    if image:
        tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = image; nt.links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.
        mix.inputs['A'].default_value = (*[c ** 2.2 for c in color], 1); nt.links.new(tex.outputs['Color'], mix.inputs['B'])
        nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
    if normal:
        nt2 = nt.nodes.new('ShaderNodeTexImage'); nt2.image = normal; nt.links.new(mapping.outputs['Vector'], nt2.inputs['Vector'])
        nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = .8
        nt.links.new(nt2.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    return m

WALNUT = material('StereoWalnutVeneer', (.55, .36, .22), .42, image=WOOD_IMG, scale=1.)
GRILLE = material('StereoGrilleCloth', (.2, .18, .16), .95, image=CLOTH_IMG, normal=CLOTH_NRM, scale=4.)
ALU = material('StereoBrushedAluminium', (.86, .86, .84), .32, .9, image=ALU_IMG)
BLACK = material('StereoBlackPlastic', (.05, .05, .055), .55)
RUBBER = material('StereoRubber', (.03, .03, .03), .9)
CHROME = material('StereoChrome', (.9, .9, .9), .12, 1.)
GLASS = material('StereoSmokedGlass', (.06, .07, .07), .05, .3)
CONE = material('StereoPaperCone', (.12, .115, .11), .85)
DIAL = material('StereoDialFace', (.86, .78, .55), .5)
RECORD = material('StereoRecord', (1, 1, 1), .35, image=REC_IMG)

def done(o, mat):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = True
    PARTS.append(o); return o

def box(center, size, mat, bevel=.008, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center); o = bpy.context.object
    o.scale = size; bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = segments; b.limit_method = 'ANGLE'
        bpy.ops.object.modifier_apply(modifier='b')
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.); bpy.ops.object.mode_set(mode='OBJECT')
    return done(o, mat)

def cyl(center, radius, depth, mat, axis='Y', verts=40, bevel=0.):
    rot = {'Y': (math.pi / 2, 0, 0), 'Z': (0, 0, 0), 'X': (0, math.pi / 2, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center, rotation=rot); o = bpy.context.object
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 2; bpy.ops.object.modifier_apply(modifier='b')
    return done(o, mat)

def torus(center, major, minor, mat, axis='Y'):
    rot = (math.pi / 2, 0, 0) if axis == 'Y' else (0, 0, 0)
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=48, minor_segments=10, location=center, rotation=rot)
    return done(bpy.context.object, mat)

def cone(center, r1, r2, depth, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=r1, radius2=r2, depth=depth, location=center, rotation=(math.pi / 2, 0, 0))
    return done(bpy.context.object, mat)

def knob(center, r=.022):
    cyl(center, r, .022, ALU, verts=24, bevel=.003)
    for k in range(18):
        a = k / 18 * math.tau
        box((center[0] + math.cos(a) * r, center[1], center[2] + math.sin(a) * r), (.003, .02, .003), CHROME, bevel=0)
    box((center[0], center[1] - .012, center[2] + r * .6), (.003, .002, .008), BLACK, bevel=0)

def driver(center, r):
    """Woofer or mid-range: chassis ring, rubber surround, paper cone, dust cap."""
    x, y, z = center
    torus((x, y - .004, z), r, .012, BLACK)
    torus((x, y - .006, z), r * .86, r * .07, RUBBER)
    cone((x, y + .03, z), r * .8, r * .25, .06, CONE)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * .26, location=(x, y + .005, z)); cap = bpy.context.object; cap.scale = (1, .45, 1); done(cap, CONE)

# ---------------------------------------------------------------- speakers
for sx in (-1, 1):
    X = sx * 1.2
    box((X, 0, 1.0), (.86, .68, 1.85), WALNUT, bevel=.02)
    for fx in (-1, 1): box((X + fx * .32, .02, .055), (.11, .5, .09), RUBBER, bevel=.01)
    box((X, -.336, 1.0), (.78, .02, 1.74), BLACK, bevel=.004)                    # baffle
    if sx < 0:
        # Grille gone: three drivers and a brand badge on the baffle.
        driver((X, -.35, .57), .25); driver((X, -.35, 1.24), .17)
        torus((X, -.35, 1.66), .06, .01, CHROME); bpy.ops.mesh.primitive_uv_sphere_add(radius=.04, location=(X, -.35, 1.66)); t = bpy.context.object; t.scale = (1, .5, 1); done(t, BLACK)
        # The fallen grille leans against the cabinet's outer side, cloth facing out.
        for o in (box((0, 0, 0), (.76, .03, 1.7), WALNUT, bevel=.01), box((0, -.016, 0), (.7, .006, 1.62), GRILLE, bevel=0)):
            o.data.transform(__import__('mathutils').Matrix.Rotation(math.radians(90), 4, 'Z'))
            o.rotation_euler = (0, math.radians(9), 0); o.location = (X - .57, -.02, .84)
    else:
        box((X, -.35, 1.0), (.8, .03, 1.76), WALNUT, bevel=.01)                    # grille frame
        box((X, -.367, 1.0), (.74, .006, 1.68), GRILLE, bevel=0)
    box((X + .22, -.372, .2), (.19, .006, .07), CHROME, bevel=.002)               # badge

# ---------------------------------------------------------------- rack: low cabinet, amplifier, tuner, record deck
box((0, -.015, .43), (1.27, .65, .82), WALNUT, bevel=.015)
for fx in (-1, 1): box((fx * .56, -.015, .06), (.1, .55, .1), RUBBER, bevel=.01)
box((0, -.344, .47), (1.17, .012, .64), GLASS, bevel=.003)                       # smoked glass door
for fx in (-1, 1): cyl((fx * .08, -.36, .61), .012, .03, CHROME, verts=16)        # door knobs
for z, kind in ((.98, 'amp'), (1.23, 'tuner')):
    box((0, -.03, z), (1.19, .66, .23), BLACK, bevel=.01)
    box((0, -.37, z), (1.15, .02, .2), ALU, bevel=.004)                          # front plate, in front of the VU lamps' wall
    for fx in (-1, 1): box((fx * .59, -.36, z), (.02, .035, .22), WALNUT, bevel=.005)   # wood cheeks
    if kind == 'amp':
        for k, x in enumerate((-.48, .4, .48)): knob((x, -.392, z), .028 if k == 0 else .02)
        for x in (.1, .16, .22): box((x, -.388, z - .06), (.012, .012, .03), CHROME, bevel=.003)   # toggles
    else:
        box((-.05, -.383, z + .01), (.62, .006, .1), GLASS, bevel=.002)          # dial window
        box((-.05, -.379, z + .01), (.58, .002, .07), DIAL, bevel=0)
        for k in range(16): box((-.33 + k * .037, -.385, z + .03), (.002, .002, .018), BLACK, bevel=0)
        box((.08, -.387, z + .01), (.004, .003, .085), material('TunerNeedle', (.9, .25, .1), .4), bevel=0)
        knob((-.48, -.392, z), .03); knob((.48, -.392, z), .026)
box((0, -.03, 1.41), (1.18, .65, .11), WALNUT, bevel=.01)                         # record deck plinth
box((0, -.36, 1.41), (1.12, .01, .06), ALU, bevel=.003)
cyl((-.12, -.04, 1.475), .16, .02, ALU, axis='Z', verts=64, bevel=.003)           # platter
cyl((-.12, -.04, 1.488), .152, .004, RECORD, axis='Z', verts=64)
cyl((-.12, -.04, 1.496), .006, .02, CHROME, axis='Z', verts=12)
cyl((.38, .15, 1.5), .03, .05, CHROME, axis='Z', verts=24)                         # tone arm pivot
arm = cyl((.27, .07, 1.53), .006, .3, CHROME, axis='X', verts=12); arm.rotation_euler = (0, math.radians(90), math.radians(-38))
box((.15, -.01, 1.52), (.035, .075, .02), BLACK, bevel=.004)                       # headshell
# Cables down the back to the speakers.
for sx in (-1, 1):
    bpy.ops.curve.primitive_bezier_curve_add(location=(0, 0, 0)); c = bpy.context.object; sp = c.data.splines[0]
    sp.bezier_points.add(1)
    for bp, co in zip(sp.bezier_points, ((sx * .4, .27, .05), (sx * 1.2, .27, .25))):
        bp.co = co; bp.handle_left_type = bp.handle_right_type = 'AUTO'
    c.data.bevel_depth = .007; c.data.bevel_resolution = 3; bpy.ops.object.convert(target='MESH'); done(bpy.context.object, RUBBER)

for o in bpy.data.objects: o.select_set(o in PARTS)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.export_scene.gltf(filepath=str(OUT / 'party-stereo.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
tris = sum(len(p.vertices) - 2 for o in PARTS for p in o.data.polygons)
print(f'party stereo: {tris} triangles, {len(PARTS)} parts')
