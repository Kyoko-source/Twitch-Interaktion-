"""Party zombies for the wave survival mode, After Play 5.0.0.

Built on the visitor pipeline of 4.21 (scanned head, skinned skeleton, cloth
simulation, hands). The figure follows the reference: a thin, twisted party
child with a dotted cone hat and pompom, wild dark hair, a wide grin full of
teeth in hollow eyes, a frilled ruff with a bow, a torn party dress hung with
streamers, red-white striped stockings and oversized cracked boots.

Variants: party-zombie (mauve dress), party-zombie-b (faded teal smock,
shorter hair, crooked hat). Rig: PartyZombie > Torso, HeadRig, ArmL/ArmR
(shoulder pivots), LegL/LegR (hip pivots).

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b --python tools/model-after-play-party-zombie-v500.py
Output: games/kinderparadies/assets/zombies-v500/
"""
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.noise import noise

HERE = Path(__file__).resolve().parent
source = (HERE / 'model-after-play-visitors-v421.py').read_text(encoding='utf-8')
exec(compile(source.split('\nreport = {}')[0], 'visitors-v421-helpers', 'exec'))
OUT = ASSETS / 'zombies-v500'
OUT.mkdir(parents=True, exist_ok=True)
V = Vector


def save_png(name, img):
    h, w = img.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.pixels.foreach_set(np.flipud(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], 2)).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save(); return OUT / f'{name}.png'


def hat_texture(base, dot):
    """Faded party paper with polka dots, creases and grime."""
    s = 512; img = np.ones((s, s, 3)) * np.array(base)
    yy, xx = np.mgrid[0:s, 0:s]
    for cx in range(0, s, 64):
        for cy in range(0, s, 64):
            ox = cx + (32 if (cy // 64) % 2 else 0)
            m = (xx - ox) ** 2 + (yy - cy) ** 2 < 14 ** 2
            img[m] = np.array(dot)
    rng = np.random.default_rng(5)
    img *= (.78 + .22 * rng.random((s, s, 1)))
    for k in range(9):
        x = int(rng.integers(0, s)); img[:, max(0, x - 1):x + 1] *= .8
    return img


def build_grin_head(kind, mats):
    """The scanned head, starved, with hollow eyes and an ear-to-ear grin."""
    head = load_head()
    for m in mats: head.data.materials.append(m)
    SKIN, DARK, TOOTH, GLOW, THREAD = range(5)
    bm = bmesh.new(); bm.from_mesh(head.data); layer = bm.loops.layers.uv.active; bm.normal_update()
    uvs = uv_of(bm, layer); rng = random.Random(kind)
    for v, (u, w) in uvs.items():
        if v.co.y > .03: continue
        push = 0.
        for cu in (.424, .579):
            push -= .026 * math.exp(-(((u - cu) / .065) ** 2 + ((w - .31) / .055) ** 2))
        push -= .02 * (math.exp(-(((u - .34) / .05) ** 2 + ((w - .45) / .08) ** 2)) + math.exp(-(((u - .66) / .05) ** 2 + ((w - .45) / .08) ** 2)))
        # Cheeks pulled up and out by the grin.
        push += .012 * (math.exp(-(((u - .37) / .045) ** 2 + ((w - .42) / .04) ** 2)) + math.exp(-(((u - .63) / .045) ** 2 + ((w - .42) / .04) ** 2)))
        v.co += v.normal * push
    for cu in (.424, .579):
        cut(bm, layer, lambda u, w, cu=cu: ((u - cu) / .028) ** 2 + ((w - .312) / .018) ** 2 < 1)
        throat(bm, lambda p, cu=cu: abs(p.z - .03) < .06 and (p.x < -.005 if cu < .5 else p.x > -.005), DARK, .025)
        c = Vector(((cu - .5) * 1.0 - .007, -.08, .03))
        s = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=.0065)
        for vv in s['verts']: vv.co += c
        for f in {f for vv in s['verts'] for f in vv.link_faces}: f.material_index = GLOW

    def grin(u, w):
        # Ear-to-ear: corners pulled far up towards the cheeks, open wide.
        x = (u - .5) / .24
        if abs(x) >= 1: return False
        low = .505 + .02 * (1 - x * x) - .085 * x * x
        top = low - .045 * (1 - x * x) - .008
        return top < w < low
    cut(bm, layer, grin)
    rim = throat(bm, lambda p: abs(p.x + .007) < .19 and p.z < .01, DARK, .05)
    centre_z = sum(x.co.z for x in rim) / max(1, len(rim))
    for v in rim:
        if rng.random() < .8:
            up = v.co.z > centre_z
            fang(bm, v.co + Vector((0, .004, 0)), v.co + Vector((rng.uniform(-.002, .002), .003, (-1 if up else 1) * rng.uniform(.012, .024))), rng.uniform(.004, .0065), TOOTH)
    bm.to_mesh(head.data); bm.free()
    if 'custom_normal' in head.data.attributes: head.data.attributes.remove(head.data.attributes['custom_normal'])
    head.scale = (HEAD_SCALE,) * 3; head.location = HEAD_AT
    bpy.context.view_layer.objects.active = head; bpy.ops.object.select_all(action='DESELECT'); head.select_set(True)
    bpy.ops.object.transform_apply(location=True, scale=True)
    dec = head.modifiers.new('d', 'DECIMATE'); dec.ratio = .32
    bpy.ops.object.modifier_apply(modifier='d')
    for p in head.data.polygons: p.use_smooth = True
    head.name = 'Head'
    return head


def lathe(name, profile, mat, centre, segs=28, tilt=(0, 0)):
    """profile: (radius, height) pairs revolved around +Z, then tilted."""
    verts, faces = [], []
    for k in range(segs):
        a = k / segs * math.tau
        for r, h in profile:
            verts.append(V((math.cos(a) * r, math.sin(a) * r, h)))
    n = len(profile)
    for k in range(segs):
        for i in range(n - 1):
            a, b = k * n + i, ((k + 1) % segs) * n + i
            faces.append((a, b, b + 1, a + 1))
    o = new_obj(name, verts, faces, [mat])
    o.rotation_euler = (tilt[0], tilt[1], 0); o.location = centre
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True)
    # Cylindrical UVs so the dotted paper wraps the cone.
    bm = bmesh.new(); bm.from_mesh(o.data); uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        for loop in f.loops:
            p = loop.vert.co - centre; loop[uv].uv = ((math.atan2(p.y, p.x) / math.tau) % 1 * 3, p.z * 4)
    bm.to_mesh(o.data); bm.free()
    return o


def ribbon(name, start, direction, length, width, mat, seed, twist=3.):
    """A flat paper streamer hanging and curling under gravity."""
    rows = 18; verts, faces = [], []
    rng = random.Random(seed); d = direction.normalized()
    side = d.cross(V((0, 0, 1))); side = side.normalized() if side.length > .01 else V((1, 0, 0))
    p = start.copy()
    for r in range(rows + 1):
        t = r / rows
        ang = t * twist + rng.uniform(-.2, .2)
        s = side * math.cos(ang) + V((0, 0, 1)).cross(side) * math.sin(ang) * .6
        verts.append(p + s * width * .5); verts.append(p - s * width * .5)
        d = (d + V((0, 0, -.35)) + V((rng.uniform(-.1, .1), rng.uniform(-.1, .1), 0))).normalized()
        p = p + d * length / rows
    for r in range(rows):
        a = r * 2; faces.append((a, a + 1, a + 3, a + 2))
    o = new_obj(name, verts, faces, [mat]); solidify(o, .0015); return o


def striped_tube(name, points, mats, stripe=.045, rings=30, sides=14, shape=None):
    o = tube(name, points, mats[0], rings, sides, shape)
    for m in mats[1:]: o.data.materials.append(m)
    for poly in o.data.polygons:
        z = sum((o.data.vertices[i].co.z for i in poly.vertices)) / len(poly.vertices)
        poly.material_index = int(z / stripe) % 2
    return o


def boot(key, side, ankle, leather, sole, lace):
    x = ankle.x
    upper = tube(key + ' boot', [(x, ankle.y + .02, .2, .052, .05), (x, ankle.y + .015, .12, .06, .058), (x + side * .004, ankle.y - .03, .07, .07, .06),
                                 (x + side * .008, ankle.y - .13, .055, .075, .05), (x + side * .01, ankle.y - .22, .05, .068, .045)], leather, 16, 18,
                 lambda t, a: .05 * noise(V((t * 7, a * 2, side))) + (.06 if t > .7 else 0) * max(0, math.sin(a)))
    sole_o = tube(key + ' sole', [(x, ankle.y + .05, .018, .06, .016), (x + side * .006, ankle.y - .12, .018, .08, .018), (x + side * .01, ankle.y - .26, .02, .075, .016)], sole, 10, 14)
    parts = [upper, sole_o]
    for k in range(4):
        z = .17 - k * .03; yy = ankle.y - .045 - k * .012
        parts.append(tube(key + ' lace', [(x - .03, yy, z, .004, .004), (x, yy - .012, z + .006, .004, .004), (x + .03, yy, z, .004, .004)], lace, 6, 6))
    # A loose lace trailing on the floor.
    parts.append(tube(key + ' loose lace', [(x + .03, ankle.y - .05, .1, .003, .003), (x + side * .08, ankle.y - .1, .03, .003, .003), (x + side * .14, ankle.y - .2, .008, .003, .003)], lace, 10, 6))
    return parts


def build_party(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(kind)
    teal = kind == 'party-zombie-b'
    face = ASSETS / 'visitors-v421' / 'ragged-face.png'
    skin = material('Party zombie skin', (.66, .6, .57), .75)
    complexion = material('Party zombie complexion', (1, .96, .96), .65, texture=face)
    dark = material('Grin darkness', (.02, .004, .006), .4)
    tooth = material('Grin teeth', (.62, .56, .42), .35)
    glow = material('Pinpoint party eyes', (.9, .86, .8), .1, emission=(.8, .7, .55))
    thread = material('Party thread', (.02, .015, .01), .6)
    nail = material('Party nails', (.05, .03, .03), .3)
    dress = material('Torn party dress', (.25, .32, .31) if teal else (.42, .25, .28), .9)
    frill = material('Dirty party frill', (.68, .62, .58), .9)
    stream = material('Party streamer', (.62, .16, .2), .7)
    stream2 = material('Faded streamer', (.72, .52, .55), .75)
    red = material('Stocking red', (.48, .08, .08), .85)
    white = material('Stocking white', (.72, .68, .62), .85)
    leather = material('Cracked boot leather', (.16, .1, .07), .65)
    sole = material('Boot sole', (.05, .04, .035), .8)
    lace = material('Boot lace', (.6, .52, .4), .8)
    hair_m = material('Matted hair', (.06, .045, .04), .7)
    hat_img = save_png(kind + '-hat', hat_texture((.62, .55, .42) if not teal else (.42, .55, .52), (.55, .12, .16)))
    hat_m = material('Party hat paper', (1, 1, 1), .8, texture=hat_img)
    pom = material('Hat pompom', (.7, .2, .25), .95)

    head = build_grin_head(kind, [complexion, dark, tooth, glow, thread])
    head_parts = [head]
    # Party hat, pompom and its elastic.
    tilt = (math.radians(-14 if not teal else -8), math.radians(18 if not teal else -24))
    head_parts.append(lathe('hat', [(.075, 0), (.07, .02), (.05, .09), (.03, .16), (.01, .22), (.0, .235)], hat_m, V((-.02, -.04, 2.0)), 28, tilt))
    top = V((-.02, -.04, 2.0)) + V((math.sin(tilt[1]) * .23, -math.sin(tilt[0]) * .23, .22))
    pomp = []
    for k in range(9):
        d = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.2, 1))).normalized()
        pomp.append(ribbon('pompom', top, d, .06, .012, pom, k, 1.))
    head_parts += pomp
    head_parts.append(tube('hat elastic', [(-.095, -.03, 1.99, .002, .002), (-.08, -.09, 1.79, .002, .002), (0, -.11, 1.70, .002, .002), (.08, -.09, 1.79, .002, .002), (.095, -.03, 1.99, .002, .002)], thread, 16, 5, caps=False))
    # Wild matted hair from the crown, falling over the brow and the ears.
    strands = 260 if not teal else 190
    for k in range(strands):
        a = rng.uniform(0, math.tau); r0 = rng.uniform(.03, .11)
        root = V((math.cos(a) * r0, math.sin(a) * r0 * .9 + .01, 1.97 + rng.uniform(-.03, .02)))
        out = V((math.cos(a), math.sin(a) * .9, 0)).normalized()
        length = rng.uniform(.14, .3 if not teal else .2)
        front = math.sin(a) < -.35
        if front:
            # Short wild fringe: the face and the grin stay visible.
            length = rng.uniform(.04, .08); out = (out + V((0, 0, .9))).normalized()
        pts = [root]
        for s in range(4):
            pts.append(pts[-1] + (out * (.9 - s * .15) + V((rng.uniform(-.45, .45), rng.uniform(-.45, .45), -.25 - s * .2))).normalized() * length / 4)
        head_parts.append(tube('hair', [(p.x, p.y, p.z, .011 * (1 - i * .2), .006 * (1 - i * .2)) for i, p in enumerate(pts)], hair_m, 8, 5))

    thin = .82
    def skinned(name, points, edges, mat, levels=2):
        me = bpy.data.meshes.new(name); me.from_pydata([p for p, r in points], edges, []); me.update()
        o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
        o.modifiers.new('skin', 'SKIN')
        for i, (p, r) in enumerate(points): me.skin_vertices[0].data[i].radius = (r[0] * thin, r[1] * thin)
        me.skin_vertices[0].data[0].use_root = True
        sub = o.modifiers.new('sub', 'SUBSURF'); sub.levels = levels
        bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='skin'); bpy.ops.object.modifier_apply(modifier='sub')
        me.materials.clear(); me.materials.append(mat)
        for f in me.polygons: f.use_smooth = True
        return o

    body = skinned('body', [(V((0, .02, .95)), (.12, .085)), (V((0, .035, 1.10)), (.085, .062)), (V((0, .0, 1.30)), (.12, .08)),
                            (V((0, -.005, 1.46)), (.135, .08)), (V((0, .0, 1.585)), (.055, .05)), (V((0, -.02, 1.75)), (.038, .04)),
                            (V((-.2, .0, 1.545)), (.048, .043)), (V((.2, .0, 1.545)), (.048, .043)),
                            (V((-.095, .02, .90)), (.07, .065)), (V((.095, .02, .90)), (.07, .065))],
                   [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (3, 6), (3, 7), (0, 8), (0, 9)], skin, 3)

    def leg_points(side):
        x = side * .10
        return [(V((x, .02, .92)), (.06, .06)), (V((x + side * .01, -.01, .53)), (.042, .042)), (V((x + side * .008, .0, .30)), (.03, .032)), (V((x + side * .012, .02, .16)), (.028, .03))]

    def arm_points(side):
        sx = side * .22
        return [(V((sx, .0, 1.55)), (.04, .04)), (V((sx + side * .05, -.06, 1.35)), (.028, .028)), (V((sx + side * .08, -.12, 1.18)), (.03, .028)),
                (V((sx + side * .1, -.2, 1.05)), (.021, .018)), (V((sx + side * .11, -.27, .95)), (.016, .013))]

    def garment(name, rows, cols, topz, bottom, rx, ry, mat, colliders, tear, flare, frames=80, centre=None, pin_rows=2):
        centre = centre or V((0, 0, 0)); verts, faces = [], []
        for r in range(rows + 1):
            v = r / rows; z = topz + (bottom - topz) * v
            for c in range(cols):
                a = math.tau * c / cols; k = (.45 + .55 * min(1, v * 3.5)) * (1 + flare * v)
                verts.append(centre + V((math.sin(a) * rx * k * 1.35, -math.cos(a) * ry * k * 1.5, z + .05)))
        for r in range(rows):
            for c in range(cols):
                u, v = c / cols, r / rows
                if v > .5 and noise(V((u * 13, v * 5, len(name)))) > tear + (1 - v) * 1.2: continue
                if .25 < v < .8 and noise(V((u * 17, v * 9, 3.3))) > .58: continue
                a = r * cols + c; b = r * cols + (c + 1) % cols
                faces.append((a, b, b + cols, a + cols))
        o = new_obj(name, verts, faces, [mat])
        g = o.vertex_groups.new(name='pin'); g.add(list(range(cols * pin_rows)), 1., 'REPLACE')
        for col in colliders:
            if not col.modifiers.get('Collision'):
                col.modifiers.new('Collision', 'COLLISION'); col.collision.thickness_outer = .006
        cl = o.modifiers.new('Cloth', 'CLOTH'); cs = cl.settings
        cs.quality = 8; cs.mass = .25; cs.tension_stiffness = 12; cs.compression_stiffness = 12; cs.bending_stiffness = .2; cs.air_damping = 2
        cs.vertex_group_mass = 'pin'; cl.collision_settings.distance_min = .006
        scene = bpy.context.scene; scene.frame_start = 1; scene.frame_end = frames
        cl.point_cache.frame_start = 1; cl.point_cache.frame_end = frames
        for f in range(1, frames + 1): scene.frame_set(f)
        bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='Cloth'); scene.frame_set(1); o.vertex_groups.clear()
        solidify(o, .004)
        for f in o.data.polygons: f.use_smooth = True
        return o

    legs_temp = [skinned('legproxy', leg_points(side), [(0, 1), (1, 2), (2, 3)], skin, 1) for side in (-1, 1)]
    parts = [body, garment('party dress', 36, 64, 1.58, .55 if not teal else .68, .17, .11, dress, [body] + legs_temp, .15, .55)]
    for o in [body] + legs_temp:
        m = o.modifiers.get('Collision')
        if m: o.modifiers.remove(m)
    for o in legs_temp: bpy.data.objects.remove(o)
    # Frilled ruff collar with a bow at the throat.
    def ruff_place(u, v):
        a = math.tau * u; wave = .025 * math.sin(a * 18); r = .05 + v * (.15 + wave)
        return V((math.sin(a) * r, -math.cos(a) * r * .85 + .01, 1.72 - v * .1 + wave * .4))
    parts.append(torn_sheet('ruff', 5, 110, ruff_place, frill, .005, rng))
    def ruff2_place(u, v):
        a = math.tau * u; wave = .02 * math.sin(a * 22 + 1); r = .045 + v * (.11 + wave)
        return V((math.sin(a) * r, -math.cos(a) * r * .85 + .01, 1.765 - v * .07 + wave * .3))
    parts.append(torn_sheet('ruff top', 4, 96, ruff2_place, frill, .004, rng))
    parts.append(tube('neck wrap', [(0, -.005, 1.6, .05, .045), (0, -.01, 1.7, .046, .042), (0, -.015, 1.78, .042, .04)], dress, 10, 14))
    for side in (-1, 1):
        parts.append(tube('bow', [(0, -.09, 1.66, .014, .012), (side * .06, -.1, 1.69, .04, .014), (side * .09, -.095, 1.66, .024, .012)], stream, 10, 10))
    parts.append(ribbon('bow tail', V((0, -.1, 1.66)), V((.2, -.3, -1)), .26, .028, stream, 1, 2.))
    parts.append(ribbon('bow tail', V((0, -.1, 1.66)), V((-.2, -.3, -1)), .22, .028, stream, 2, -2.))
    # Paper buttons and streamers hanging off the dress.
    for k in range(3): parts.append(tube('button', [(0, -.115, 1.43 - k * .08, .012, .004), (0, -.12, 1.43 - k * .08, .012, .004)], material('Brass button', (.5, .4, .2), .4), 2, 10))
    for k in range(10):
        a = rng.uniform(-2.6, 2.6); z = rng.uniform(.75, 1.25)
        start = V((math.sin(a) * .2, -math.cos(a) * .14, z))
        parts.append(ribbon('dress streamer', start, V((math.sin(a), -math.cos(a), -1.5)), rng.uniform(.25, .5), rng.uniform(.018, .03), stream if k % 2 else stream2, 10 + k))
    torso = join(parts, 'Torso')

    arms = []
    for side, key in ((-1, 'ArmL'), (1, 'ArmR')):
        pts = arm_points(side); limb = skinned(key + ' limb', pts, [(0, 1), (1, 2), (2, 3), (3, 4)], skin, 2)
        bits = [limb]
        path = [(side * .19, -.005, 1.59, .06, .055)]
        for (p, r), extra in zip(pts[:3], (.022, .02, .018)):
            path.append((p.x, p.y, p.z, r[0] * thin + extra, r[1] * thin + extra))
        def crease(t, a, s=side):
            return .1 * math.sin(t * 40 + math.sin(a * 3) * 1.6) * (.3 + .7 * t) + (0 if t < .85 else (t - .85) / .15 * (.25 + .4 * noise(V((a * 6, 1.3, s)))))
        sleeve = tube(key + ' sleeve', path, dress, 28, 18, crease, caps=False); solidify(sleeve, .004)
        bits.append(sleeve)
        elbow = pts[2][0]
        def cuff_place(u, v, c=elbow):
            a = math.tau * u; r = .045 + v * .05 + .012 * math.sin(a * 14)
            return V((c.x + math.sin(a) * r, c.y - math.cos(a) * r, c.z - v * .04))
        bits.append(torn_sheet(key + ' cuff', 3, 60, cuff_place, frill, .003, rng))
        for k in range(3):
            bits.append(ribbon(key + ' streamer', pts[3][0], V((side * .4, -.2, -1)), rng.uniform(.25, .45), .02, stream if k else stream2, 40 + k + side * 5))
        bits += hand(key, side, skin, nail, pts[-1][0], .7)
        arm = join(bits, key)
        pivot = V((side * .23, 0, SHOULDER - .02))
        for v in arm.data.vertices: v.co -= pivot
        arm.location = pivot; arms.append(arm)

    legs = []
    for side, key in ((-1, 'LegL'), (1, 'LegR')):
        pts = leg_points(side); limb = skinned(key + ' limb', pts, [(0, 1), (1, 2), (2, 3)], skin, 2)
        stock = striped_tube(key + ' stocking', [(p.x, p.y, p.z, r[0] * thin + .006, r[1] * thin + .006) for p, r in pts[1:]] + [(pts[-1][0].x, pts[-1][0].y, .12, .03, .032)],
                             [red, white], .045, 30, 14, lambda t, a: .05 * noise(V((t * 9, a * 3, side))))
        bits = [limb, stock] + boot(key, side, pts[-1][0], leather, sole, lace)
        bits.append(ribbon(key + ' garter', V((pts[1][0].x, pts[1][0].y - .04, .62)), V((side * .3, -.3, -1)), .3, .02, stream, 70 + side))
        leg = join(bits, key)
        pivot = V((side * .10, .02, .92))
        for v in leg.data.vertices: v.co -= pivot
        leg.location = pivot; legs.append(leg)

    for o in [torso] + arms + head_parts:
        if o.name not in bpy.data.objects or o.type != 'MESH': continue
        d = o.modifiers.new('d', 'DECIMATE'); d.ratio = .34 if o in head_parts else .3
        bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='d')
    rig = bpy.data.objects.new('PartyZombie', None); bpy.context.collection.objects.link(rig)
    head_rig = bpy.data.objects.new('HeadRig', None); bpy.context.collection.objects.link(head_rig)
    head_rig.parent = rig; head_rig.location = (0, 0, 1.6)
    for o in head_parts:
        for v in o.data.vertices: v.co.z -= 1.6
        o.parent = head_rig
    head_parts_joined = join(head_parts, 'HeadMesh'); head_parts_joined.parent = head_rig
    for o in [torso] + arms + legs: o.parent = rig
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + '.glb')), export_format='GLB', use_selection=True, export_cameras=False, export_lights=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('ZOMBIE', kind, tris, flush=True)
    return {kind: tris}


report = {}
for kind in ('party-zombie', 'party-zombie-b'):
    report.update(build_party(kind))
(OUT / 'provenance.json').write_text(json.dumps({
    'head_base': 'Lee Perry-Smith head scan, CC BY 3.0, via the credited visitor derivative',
    'original': ['bodies', 'party dress', 'ruff', 'streamers', 'hat', 'hair', 'stockings', 'boots', 'grin'],
    'models': report}, indent=2), encoding='utf-8')
(OUT / 'LICENSE.txt').write_text('Heads: Infinite, 3D Head Scan by Lee Perry-Smith, CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/),\n'
                                 'reshaped, cut and repainted for After Play. Bodies, clothes and accessories are original.\n', encoding='utf-8')
