"""Arcade cabinets of the Happyland lounge, After Play 4.12.0.

Same side profile as the old in-code cabinet (plinth, control overhang,
sloping CRT, marquee), now with printed, sun-faded side art (scratched, the
paint kicked off near the floor), T-moulding along every edge, a screen
bezel, a printed control panel with joystick and three concave buttons, a
chrome coin door with two lit coin slots and a return flap, and a vented kick
plate. Two themes: "arcade" (teal, comet and stars) and "orbit" (red, ringed
planet).

Run: blender -b --python tools/model-after-play-arcade-v4120.py   (Blender 5.0)
Output: games/kinderparadies/assets/arcade-v4120/arcade-cabinet-{arcade,orbit}.glb
Godot local (x, y, z) = Blender (x, -y, z); front is Godot +Z = Blender -Y.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/arcade-v4120'
OUT.mkdir(parents=True, exist_ok=True)
PROFILE = [(-.37, 0), (.36, 0), (.42, .88), (.49, .94), (.45, 1.05), (.20, 1.10), (.10, 1.69), (.33, 1.77), (.33, 1.99), (-.37, 1.99)]
U0, U1, H = -.37, .49, 1.99
parts = []

def G(x, y, z): return (x, -z, y)  # Godot local -> Blender

def material(name, color, rough=.5, metal=0., image=None, emit=None):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if image:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = image; nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 2.
    return m

def save(name, img):
    h, w = img.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.pixels.foreach_set(np.flipud(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], 2)).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save(); return im

def fbm(shape, rng, octaves=5):
    out = np.zeros(shape, np.float32)
    for o in range(octaves):
        s = 2 ** (o + 2); g = rng.random((s + 1, s + 1)).astype(np.float32)
        ys = np.linspace(0, s, shape[0]); xs = np.linspace(0, s, shape[1])
        yi = np.minimum(ys.astype(int), s - 1); xi = np.minimum(xs.astype(int), s - 1); fy = (ys - yi)[:, None]; fx = (xs - xi)[None, :]
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
        a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
        out += ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy) / 2 ** o
    return out / 1.9

def side_art(theme, rng, size=(1024, 512)):
    h, w = size  # v = height (rows, top = high), u = depth
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32); u = xx / w; v = 1 - yy / h
    px = U0 + u * (U1 - U0); py = v * H  # metres on the side
    if theme == 'arcade':
        base, a1, a2, a3 = np.array([.07, .12, .2]), np.array([.2, .62, .58]), np.array([.98, .72, .2]), np.array([.95, .35, .25])
    else:
        base, a1, a2, a3 = np.array([.22, .05, .07]), np.array([.9, .3, .2]), np.array([.98, .78, .35]), np.array([.35, .6, .75])
    img = np.ones((h, w, 3), np.float32) * base
    # Diagonal speed stripes, bottom-front to top-back.
    d = (py - px * 1.6)
    for k, col in enumerate((a1, a2, a3)):
        band = np.abs(d - (.35 + k * .16)) < .045
        img[band] = col
    if theme == 'arcade':
        # Comet: a bright head with a long tapering tail along the stripes.
        cx, cy = .02, 1.55
        head = np.hypot(px - cx, py - cy)
        img[head < .11] = a2; img[head < .07] = np.array([1, .95, .8])
        t = (cx - px) * .55 + (cy - py) * .83; n = np.abs((px - cx) * .83 - (py - cy) * .55)
        tail = (t > 0) & (t < 1.1) & (n < .1 * (1 - t / 1.1))
        img[tail] = img[tail] * .3 + a2 * .7
        for _ in range(90):
            sx, sy = rng.uniform(U0, U1), rng.uniform(.9, 1.99); r = rng.uniform(.004, .012)
            img[np.hypot(px - sx, py - sy) < r] = np.array([1, 1, .9])
    else:
        # Ringed planet with an orbit ellipse and two moons.
        cx, cy = .0, 1.5
        r = np.hypot(px - cx, py - cy)
        img[r < .25] = a1; shade = (r < .25) & ((px - cx) + (py - cy) > .12); img[shade] = a1 * .6
        ring = np.abs(np.hypot((px - cx) / 1., (py - cy) / .28) - .38) < .03
        img[ring & ~((r < .25) & (py > cy))] = a2
        orbit = np.abs(np.hypot((px - cx) / 1.2, (py - cy - .05) / .55) - .4) < .007
        img[orbit] = np.array([.95, .9, .8])
        for mx, my, mr in ((.32, 1.85, .05), (-.28, 1.12, .035)):
            img[np.hypot(px - mx, py - my) < mr] = a3
    # Sun fading, scratches, kicked-off paint near the floor showing raw board.
    img = img * .8 + .12 * img.mean(2, keepdims=True) + .03
    grime = fbm((h, w), rng)[..., None]; img *= .85 + .2 * grime
    for _ in range(140):
        x0, y0 = rng.integers(0, w), rng.integers(0, h); ang = rng.uniform(0, math.pi); ln = rng.integers(10, 60)
        for t in range(ln):
            x, y = int(x0 + math.cos(ang) * t), int(y0 + math.sin(ang) * t)
            if 0 <= x < w and 0 <= y < h: img[y, x] = np.minimum(1, img[y, x] * .6 + .35)
    chip = (fbm((h, w), rng) > .74 - (.12 - py) * 1.6) & (py < .12)
    img[chip] = np.array([.55, .43, .3])
    return img

def panel_art(rng):
    h, w = 256, 640
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.ones((h, w, 3), np.float32) * np.array([.08, .08, .1])
    img[(np.abs(yy - h * .5) < 3)] = np.array([.85, .7, .25])
    for cx, col in ((w * .27, (.85, .2, .2)),):
        img[np.abs(np.hypot(xx - cx, yy - h * .5) - 60) < 4] = col
    for i, col in enumerate(((.9, .8, .2), (.2, .6, .9), (.9, .3, .3))):
        img[np.abs(np.hypot(xx - (w * .57 + i * 48), yy - h * .5) - 26) < 3] = col
    img *= (.8 + .3 * fbm((h, w), rng))[..., None]
    burn = np.hypot(xx - w * .85, yy - h * .3) < 9; img[burn] = np.array([.03, .02, .02])
    return img

def finish(o, mats, smooth=False):
    o.data.materials.clear()
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]): o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = smooth
    parts.append(o); return o

def box(c, s, mat, bev=.004, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); o = bpy.context.object; o.scale = s; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev:
        m = o.modifiers.new('b', 'BEVEL'); m.width = bev; m.segments = 2; bpy.ops.object.modifier_apply(modifier='b')
    if rot is not None: o.rotation_euler = rot
    return finish(o, mat)

def cyl(c, r, d, mat, rot=(0, 0, 0), verts=24, r2=None):
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=c, rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d, location=c, rotation=rot)
    return finish(bpy.context.object, mat, True)

def poly_curve(pts, r, mat):
    cu = bpy.data.curves.new('c', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1); sp.use_cyclic_u = True
    for p, q in zip(sp.points, pts): p.co = (*q, 1)
    ob = bpy.data.objects.new('c', cu); bpy.context.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); bpy.data.objects.remove(ob)
    o = bpy.data.objects.new('TMoulding', me); bpy.context.collection.objects.link(o); return finish(o, mat, True)

def build(theme, paint_color, seed):
    global parts
    bpy.ops.wm.read_factory_settings(use_empty=True); parts = []
    rng = np.random.default_rng(seed)
    art = material('CabinetSideArt', (1, 1, 1), .55, image=save(f'side-{theme}', side_art(theme, rng)))
    paint = material('CabinetPaint', paint_color, .6)
    trim = material('CabinetTMoulding', (.85, .75, .3) if theme == 'arcade' else (.9, .9, .88), .35, .3)
    black = material('CabinetBlack', (.03, .03, .035), .45)
    chrome = material('CabinetChrome', (.8, .8, .82), .2, 1.)
    lit = material('CoinSlotLit', (.9, .15, .1), .4, emit=(1., .12, .05))
    panel = material('ControlPanelArt', (1, 1, 1), .4, image=save(f'panel-{theme}', panel_art(rng)))
    red = material('JoystickBall', (.8, .08, .06), .25)
    buttons = [material(f'Button{i}', c, .3) for i, c in enumerate(((.95, .85, .2), (.2, .55, .95), (.9, .25, .25)))]
    # Shell: profile extruded across the width; sides carry the art.
    bm = bmesh.new(); vs = [bm.verts.new(G(-.37, h, d)) for d, h in PROFILE]; f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f]); bmesh.ops.translate(bm, verts=[e for e in r['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(.74, 0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.new()
    for face in bm.faces:
        side = abs(face.normal.x) > .9; face.material_index = 0 if side else 1
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = (((-co.y) - U0) / (U1 - U0), co.z / H) if side else (co.x, co.z)
    me = bpy.data.meshes.new('shell'); bm.to_mesh(me); bm.free(); shell = bpy.data.objects.new('Shell', me); bpy.context.collection.objects.link(shell)
    bpy.context.view_layer.objects.active = shell
    m = shell.modifiers.new('b', 'BEVEL'); m.width = .006; m.segments = 2; bpy.ops.object.modifier_apply(modifier='b')
    finish(shell, [art, paint])
    for x in (-.375, .375): poly_curve([G(x, h, d) for d, h in PROFILE], .01, trim)
    # Screen bezel in the screen's frame (Godot pos (0,1.42,.174), tilt -0.16).
    bez = []
    for c, s in (((0, .2475, .035), (.66, .065, .02)), ((0, -.2475, .035), (.66, .065, .02)), ((-.3, 0, .035), (.06, .43, .02)), ((.3, 0, .035), (.06, .43, .02))):
        bez.append(box(G(*c), (s[0], s[2], s[1]), black, .006))
    bez.append(box(G(0, 0, .0), (.68, .05, .58), black, .01))
    from mathutils import Euler
    tilt = Euler((-.16, 0, 0))
    for o in bez:
        local = Vector(o.location); local.rotate(tilt)
        o.location = Vector(G(0, 1.42, .174)) + local; o.rotation_euler = tilt
    # Control panel: printed overlay on the sloped deck, joystick, buttons.
    a, b = Vector(G(0, 1.05, .45)), Vector(G(0, 1.10, .20)); mid = (a + b) / 2; slope = math.atan2(b.z - a.z, b.y - a.y)
    plate = box(mid + Vector((0, 0, .008)), (.7, (a - b).length, .012), panel, .003, rot=(slope, 0, 0))
    bm = bmesh.new(); bm.from_mesh(plate.data); uvl = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops: loop[uvl].uv = (loop.vert.co.x / .7 + .5, loop.vert.co.y / (a - b).length + .5)
    bm.to_mesh(plate.data); bm.free()
    def on_deck(x, d):
        t = (.45 - d) / .25; base = a.lerp(b, t); return Vector((x, base.y, base.z + .015))
    p = on_deck(-.16, .31)
    cyl(p + Vector((0, 0, .004)), .03, .008, black, verts=20)
    cyl(p + Vector((0, 0, .06)), .007, .11, chrome, verts=12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=.034, location=p + Vector((0, 0, .125))); finish(bpy.context.object, red, True)
    for i in range(3):
        q = on_deck(.05 + i * .075, .32)
        cyl(q + Vector((0, 0, .005)), .025, .01, chrome, verts=24)
        cyl(q + Vector((0, 0, .009)), .02, .01, buttons[i], verts=24, r2=.018)
    # Coin door on the sloped front, two lit slots, return flap, lock.
    lean = math.atan2(.06, .88)
    door_c = Vector(G(0, .60, .36 + .06 * .60 / .88 + .006))
    box(door_c, (.25, .012, .32), chrome, .004, rot=(lean, 0, 0))
    for x in (-.055, .055):
        box(door_c + Vector((x, -.008, .07)), (.05, .01, .07), lit, .002, rot=(lean, 0, 0))
        box(door_c + Vector((x, -.013, .07)), (.006, .006, .04), black, 0, rot=(lean, 0, 0))
    box(door_c + Vector((0, -.012, -.08)), (.12, .012, .06), black, .003, rot=(lean, 0, 0))
    cyl(door_c + Vector((.09, -.012, -.08)), .012, .008, chrome, rot=(math.pi / 2, 0, 0), verts=16)
    # Kick plate with vents.
    box(Vector(G(0, .07, .362)), (.72, .008, .14), black, .002, rot=(lean, 0, 0))
    for i in range(7): box(Vector(G(-.2 + i * .066, .2, .372 + .004)), (.026, .006, .11), black, 0, rot=(lean, 0, 0))
    # Speaker grille under the marquee.
    sa, sb = Vector(G(0, 1.69, .10)), Vector(G(0, 1.77, .33)); sm = (sa + sb) / 2
    grille = box(sm + Vector((0, 0, -.004)), (.5, (sa - sb).length * .8, .006), black, .002, rot=(math.atan2(sb.z - sa.z, sb.y - sa.y) + math.pi, 0, 0))
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / f'arcade-cabinet-{theme}.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(theme, sum(len(o.data.polygons) for o in parts), 'faces')

build('arcade', (.2, .45, .42), 41201)
build('orbit', (.62, .2, .16), 41202)
