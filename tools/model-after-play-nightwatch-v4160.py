"""Nightwatch control room hardware, After Play 4.16.0.

cctv-monitor.glb: a 4:3 security CRT monitor. Painted steel case with a
tapered tube housing, a separate cast front bezel with a rounded screen
opening, a gently bulged glass ("Screen", UV 0..1 over the picture), vent
slots on top and sides, brightness/contrast knobs, a power LED, bezel screws
and rubber feet.
video-switcher.glb: a camera switching desk. Sloped beige console with ten
raised keys (Key01..Key10, two rows of five), a joystick with a red ball, a
green segment display, a key switch and a label strip.

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b --python tools/model-after-play-nightwatch-v4160.py
Output: games/kinderparadies/assets/nightwatch-v4160/
Godot local (x, y, z) = Blender (x, -z, y). Origins: bottom centre, front +Z.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/nightwatch-v4160'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4160)
parts = []

# Shared with scripts/nightwatch.gd (MONITOR_SCREEN, SWITCH_KEYS).
SCREEN_C = (0.0, .2, .158)
SCREEN_W, SCREEN_H = .33, .2475
KEY_X0, KEY_DX, KEY_Z = -.235, .062, (.045, -.035)

def G(x, y, z): return Vector((x, -z, y))

def reset():
    global parts
    bpy.ops.wm.read_factory_settings(use_empty=True); parts = []

def save(name, img):
    h, w = img.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.pixels.foreach_set(np.flipud(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], 2)).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save(); return im

def grime(name, base, spots=.08, size=512):
    """Painted metal with soft dirt, scratches and darker edges."""
    img = np.ones((size, size, 3)) * np.array(base)
    n = rng.random((size // 16, size // 16)); n = np.kron(n, np.ones((16, 16)))
    from numpy.fft import fft2, ifft2
    k = np.exp(-((np.fft.fftfreq(size)[:, None] ** 2 + np.fft.fftfreq(size)[None] ** 2) * 900))
    soft = np.real(ifft2(fft2(rng.random((size, size))) * k)); soft = (soft - soft.min()) / (np.ptp(soft) + 1e-6)
    img *= (1 - spots * 1.6 * soft[..., None])
    for _ in range(140):
        x, y = rng.integers(0, size, 2); ln = rng.integers(6, 40); a = rng.uniform(0, math.pi)
        for t in range(ln):
            ix, iy = int(x + math.cos(a) * t) % size, int(y + math.sin(a) * t) % size
            img[iy, ix] = np.minimum(1, img[iy, ix] * 1.25 + .03)
    return save(name, img)

def material(name, color, rough=.5, metal=0., image=None, emit=None):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if image:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = image; nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if emit:
        b.inputs['Emission Color'].default_value = (*[c ** 2.2 for c in emit], 1); b.inputs['Emission Strength'].default_value = 2.0
    return m

def finish(o, mat, smooth=True, name=None):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = smooth
    if name: o.name = name; o.data.name = name
    parts.append(o); return o

def apply(o, kind, **kw):
    m = o.modifiers.new('m', kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='m')

def box(c, s, mat, bev=.004, seg=2, rot=(0, 0, 0), name=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(*c), rotation=rot); o = bpy.context.object
    o.scale = (s[0], s[2], s[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev: apply(o, 'BEVEL', width=bev, segments=seg)
    return finish(o, mat, seg > 2, name)

def cyl(c, r, d, mat, axis='y', verts=24, name=None):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=G(*c), rotation=rot)
    return finish(bpy.context.object, mat, True, name)

def ball(c, r, mat, name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=r, location=G(*c)); return finish(bpy.context.object, mat, True, name)

def export(name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(name, sum(len(o.data.polygons) for o in parts), 'faces')

# ---------------------------------------------------------------- monitor
def monitor():
    reset()
    case = material('MonitorCase', (1, 1, 1), .58, .35, grime('monitor-case', (.19, .2, .19)))
    bezel_m = material('MonitorBezel', (1, 1, 1), .5, .15, grime('monitor-bezel', (.075, .078, .08), .12))
    rubber = material('MonitorRubber', (.03, .03, .03), .9)
    steel = material('MonitorSteel', (.55, .56, .57), .35, .85)
    vent = material('MonitorVent', (.015, .016, .017), .8)
    led = material('MonitorLED', (.1, .5, .15), .3, 0, None, (.25, 1., .35))
    plate = material('MonitorPlate', (.62, .6, .55), .4, .6)
    glass = material('Screen', (.02, .035, .03), .08)
    # Body and the tapered tube housing behind it.
    box((0, .18, 0), (.44, .36, .30), case, .014, 3)
    box((0, .182, -.22), (.36, .3, .16), case, .03, 3)
    box((0, .186, -.33), (.24, .2, .08), case, .025, 3)
    box((0, .19, -.375), (.12, .09, .02), vent, .004)
    # Front bezel with a rounded opening.
    bez = box((0, .18, .162), (.432, .352, .03), bezel_m, .01, 3)
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(SCREEN_C[0], SCREEN_C[1], .162)); cut = bpy.context.object
    cut.scale = (SCREEN_W + .012, .12, SCREEN_H + .012); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply(cut, 'BEVEL', width=.022, segments=6)
    m = bez.modifiers.new('cut', 'BOOLEAN'); m.object = cut; m.operation = 'DIFFERENCE'
    bpy.context.view_layer.objects.active = bez; bpy.ops.object.modifier_apply(modifier='cut'); bpy.data.objects.remove(cut)
    # Inner recess around the glass.
    for (cx, cy, sx, sy) in [(0, SCREEN_C[1] + SCREEN_H / 2 + .009, SCREEN_W + .03, .012), (0, SCREEN_C[1] - SCREEN_H / 2 - .009, SCREEN_W + .03, .012),
                             (SCREEN_W / 2 + .009, SCREEN_C[1], .012, SCREEN_H + .03), (-SCREEN_W / 2 - .009, SCREEN_C[1], .012, SCREEN_H + .03)]:
        box((cx, cy, .148), (sx, sy, .02), vent, .002)
    # Bulged glass with UVs covering the picture.
    bm = bmesh.new(); uv = bm.loops.layers.uv.new(); nx, ny = 24, 18; grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny; x = (u - .5) * SCREEN_W; y = SCREEN_C[1] + (v - .5) * SCREEN_H
            bulge = .011 * (1 - (2 * u - 1) ** 2) * (1 - (2 * v - 1) ** 2)
            row.append((bm.verts.new(G(x, y, SCREEN_C[2] + bulge)), u, v))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            q = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            f = bm.faces.new([p[0] for p in q])
            for loop, p in zip(f.loops, q): loop[uv].uv = (p[1], p[2])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('Screen'); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('Screen', me); bpy.context.collection.objects.link(o)
    if o.data.polygons[0].normal.dot(Vector((0, -1, 0))) < 0: o.data.flip_normals()
    finish(o, glass, True, 'Screen')
    # Controls under the picture.
    for x in (.125, .168):
        cyl((x, .043, .18), .012, .016, rubber, 'z'); cyl((x, .043, .19), .006, .004, steel, 'z')
    ball((-.175, .043, .178), .0055, led, 'PowerLED')
    box((-.085, .043, .178), (.11, .018, .003), plate, .001)
    for x in (-.2, .2):
        for y in (.018, .342): cyl((x, y, .178), .005, .004, steel, 'z', 10)
    # Vents on top and on both sides.
    for k in range(9): box((0, .361, -.11 + k * .025), (.3, .004, .009), vent, .001)
    for side in (-1, 1):
        for k in range(6): box((side * .221, .24 - k * .028, -.05), (.004, .01, .16), vent, .001)
    for x in (-.18, .18):
        for z in (-.12, .12): box((x, .004, z), (.05, .008, .05), rubber, .002)
    export('cctv-monitor.glb')

# ---------------------------------------------------------------- switcher
def slope_y(z): return .03 + (.12 - z) / .24 * .045

def switcher():
    reset()
    shell = material('SwitcherShell', (1, 1, 1), .62, .05, grime('switcher-shell', (.44, .43, .39), .1))
    dark = material('SwitcherDark', (.05, .05, .055), .5)
    key = material('KeyCap', (.72, .71, .66), .45)
    red = material('JoystickBall', (.6, .06, .05), .35)
    steel = material('SwitcherSteel', (.6, .6, .62), .3, .9)
    display = material('SwitcherDisplay', (.05, .25, .08), .2, 0, None, (.2, 1., .3))
    label = material('SwitcherLabel', (.85, .82, .7), .7)
    # Sloped body from an extruded side profile.
    bm = bmesh.new(); prof = [(-.12, 0), (.12, 0), (.12, .03), (-.12, .075)]
    vs = [bm.verts.new(G(-.28, h, z)) for z, h in prof]; f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f]); bmesh.ops.translate(bm, verts=[e for e in r['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(.56, 0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); me = bpy.data.meshes.new('body'); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('SwitcherBody', me); bpy.context.collection.objects.link(o); apply(o, 'BEVEL', width=.008, segments=3); finish(o, shell, False)
    tilt = math.atan2(.045, .24)
    # Ten camera keys on the slope.
    n = 1
    for row, z in enumerate(KEY_Z):
        for c in range(5):
            x = KEY_X0 + c * KEY_DX
            box((x, slope_y(z) - .006, z), (.05, .014, .046), dark, .002, 2, (tilt, 0, 0))
            box((x, slope_y(z) + .004, z), (.044, .012, .04), key, .004, 3, (tilt, 0, 0), 'Key%02d' % n); n += 1
    # Label strip above the keys, display, key switch and joystick.
    box((KEY_X0 + 2 * KEY_DX, slope_y(-.09) + .001, -.09), (.3, .003, .018), label, .001, 2, (tilt, 0, 0))
    box((.17, slope_y(-.075) + .006, -.075), (.13, .016, .04), dark, .003, 2, (tilt, 0, 0))
    box((.17, slope_y(-.075) + .013, -.075), (.11, .003, .026), display, .001, 2, (tilt, 0, 0), 'SwitcherDisplay')
    cyl((.17, slope_y(.04) + .01, .04), .03, .02, dark)
    cyl((.17, slope_y(.04) + .05, .04), .006, .07, steel)
    ball((.17, slope_y(.04) + .09, .04), .016, red, 'JoystickBall')
    cyl((.235, slope_y(.08) + .006, .08), .009, .012, steel)
    box((0, .002, 0), (.54, .004, .22), dark, .002)
    export('video-switcher.glb')

monitor()
switcher()
