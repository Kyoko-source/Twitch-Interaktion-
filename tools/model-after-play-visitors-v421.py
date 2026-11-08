"""Four rebuilt night visitors on the credited scanned head.

Run: blender -b --python tools/model-after-play-visitors-v421.py
Head base: the project's Lee Perry-Smith scan (CC BY 3.0) as already used for
the clown, with its UVs and repainted texture. Bodies, clothes, hands, teeth,
stitches and hoods are original geometry. Rig names match the old visitors:
NightVisitor > Torso, HeadRig, ArmL/ArmR (shoulder pivots), LegL/LegR.
Blender coordinates: up +Z, faces -Y.
"""
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.noise import noise

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'visitors-v421'
OUT.mkdir(parents=True, exist_ok=True)
HEAD_SCALE = .74
HEAD_AT = Vector((0, -.045, 1.835))
SHOULDER = 1.55


# ---------------------------------------------------------------- helpers
def material(name, color, rough=.85, emission=None, texture=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1); p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*emission, 1); p.inputs['Emission Strength'].default_value = 1
    if texture:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(str(texture))
        m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    return m


def new_obj(name, verts, faces, mats):
    d = bpy.data.meshes.new(name); d.from_pydata([tuple(v) for v in verts], [], faces); d.update()
    for m in mats: d.materials.append(m)
    o = bpy.data.objects.new(name, d); bpy.context.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(d); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(d); bm.free()
    for p in d.polygons: p.use_smooth = True
    return o


def curve(points, t):
    span = len(points) - 1; i = min(int(t * span), span - 1); f = t * span - i
    a, b, c, d = points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, span)]
    return [.5 * (2 * y + (z - x) * f + (2 * x - 5 * y + 4 * z - w) * f * f + (3 * y - x - 3 * z + w) * f ** 3) for x, y, z, w in zip(a, b, c, d)]


def tube(name, points, mat, rings=24, sides=16, shape=None, power=2., caps=True):
    """points: (x, y, z, half_width, half_depth). shape(t, angle) scales radius."""
    verts, faces = [], []
    for r in range(rings + 1):
        t = r / rings; x, y, z, w, d = curve(points, t)
        c = Vector((x, y, z))
        ahead = Vector(curve(points, min(1, t + .01))[:3]) - Vector(curve(points, max(0, t - .01))[:3])
        ahead.normalize()
        side = Vector((1, 0, 0)) if abs(ahead.x) < .9 else Vector((0, 1, 0))
        depth = ahead.cross(side).normalized(); side = depth.cross(ahead).normalized()
        for s in range(sides):
            a = math.tau * s / sides; ca, sa = math.cos(a), math.sin(a)
            k = 1 + (shape(t, a) if shape else 0)
            verts.append(c + side * math.copysign(abs(ca) ** (2 / power), ca) * w * k + depth * math.copysign(abs(sa) ** (2 / power), sa) * d * k)
    for r in range(rings):
        for s in range(sides):
            a, b = r * sides + s, r * sides + (s + 1) % sides; faces.append((a, b, b + sides, a + sides))
    if caps:
        for ring, flip in ((0, True), (rings, False)):
            ctr = sum((verts[ring * sides + s] for s in range(sides)), Vector()) / sides; verts.append(ctr); ci = len(verts) - 1
            for s in range(sides):
                a, b = ring * sides + s, ring * sides + (s + 1) % sides; faces.append((b, a, ci) if flip else (a, b, ci))
    return new_obj(name, verts, faces, [mat])


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join(); objs[0].name = name; return objs[0]


def solidify(o, thickness):
    m = o.modifiers.new('t', 'SOLIDIFY'); m.thickness = thickness
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=m.name)


def torn_sheet(name, rows, cols, place, mat, thickness=.006, rng=None):
    """place(u, v) -> Vector; hem rows are torn into ragged tongues."""
    verts, faces = [], []
    for r in range(rows + 1):
        for c in range(cols + 1):
            verts.append(place(c / cols, r / rows))
    for r in range(rows):
        for c in range(cols):
            a = r * (cols + 1) + c
            u = (c + .5) / cols; v = (r + .5) / rows
            if v > .78 and noise(Vector((u * 9, v * 3, 2.7))) > .25 - (v - .78) * 2:
                continue
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    o = new_obj(name, verts, faces, [mat]); solidify(o, thickness); return o


# ---------------------------------------------------------------- hands
def hand(name, side, skin, nail, wrist, claw=.5):
    """Long skeletal hand hanging along -Z: knuckled phalanges and black nails."""
    parts = [tube(name + ' palm', [(wrist.x, wrist.y, wrist.z, .030, .016), (wrist.x, wrist.y - .004, wrist.z - .06, .040, .017),
                                   (wrist.x, wrist.y - .006, wrist.z - .11, .043, .015)], skin, 10, 14)]
    for f in range(5):
        thumb = f == 0
        x0 = wrist.x + side * (-.034 + f * .019) if not thumb else wrist.x + side * -.040
        base = Vector((x0, wrist.y - (.03 if thumb else .006), wrist.z - (.05 if thumb else .11)))
        length = (.07 if thumb else (.13, .15, .145, .115)[f - 1]) * 1.25
        pts = [base]; direction = Vector((side * (-.5 if thumb else (f - 2.5) * .05), -.35 - claw * .2, -1)).normalized()
        for k in range(3):
            direction = (direction + Vector((0, -claw * .35, .0))).normalized()
            pts.append(pts[-1] + direction * length / 3)
        sec = []
        for k, p in enumerate(pts):
            r = (.0105 if not thumb else .012) * (1 - k * .18)
            sec.append((p.x, p.y, p.z, r * (1.18 if 0 < k < 3 else 1), r))
        parts.append(tube(name + ' finger', sec, skin, 18, 10))
        tip = pts[-1]; d = (pts[-1] - pts[-2]).normalized()
        parts.append(tube(name + ' nail', [(tip.x, tip.y, tip.z, .0065, .003), ((tip + d * .02).x, (tip + d * .02).y, (tip + d * .02).z, .004, .002),
                                           ((tip + d * .038 + Vector((0, -.006, 0))).x, (tip + d * .038).y - .006, (tip + d * .038).z, .0004, .0004)], nail, 6, 8))
    return parts


# ---------------------------------------------------------------- heads
def load_head():
    bpy.ops.import_scene.gltf(filepath=str(ASSETS / 'detail-v310/clown-v310.glb'))
    head = bpy.data.objects['Head']
    for o in list(bpy.data.objects):
        if o is not head: bpy.data.objects.remove(o)
    head.parent = None; head.location = (0, 0, 0)
    head.data.materials.clear()
    return head


def uv_of(bm, layer):
    out = {}
    for v in bm.verts:
        if v.link_loops:
            uv = v.link_loops[0][layer].uv; out[v] = (uv.x, 1 - uv.y)
    return out


def cut(bm, layer, test):
    faces = []
    for f in bm.faces:
        u = sum(l[layer].uv.x for l in f.loops) / len(f.loops); w = 1 - sum(l[layer].uv.y for l in f.loops) / len(f.loops)
        if f.calc_center_median().y < .03 and test(u, w): faces.append(f)
    bmesh.ops.delete(bm, geom=faces, context='FACES_ONLY')
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context='EDGES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.is_valid and not v.link_faces], context='VERTS')


def throat(bm, near, dark_index, depth=.05):
    """Extrude the cut rim into a sealed dark cavity."""
    edges = [e for e in bm.edges if e.is_boundary and all(v.co.y < .03 and near(v.co) for v in e.verts)]
    if not edges: return []
    rim = list({v for e in edges for v in e.verts}); centre = sum((v.co for v in rim), Vector()) / len(rim)
    ring = edges
    for inward, shrink in ((.012, .05), (depth, .3), (.02, .9)):
        res = bmesh.ops.extrude_edge_only(bm, edges=ring)
        fresh = [g for g in res['geom'] if isinstance(g, bmesh.types.BMVert)]
        for v in fresh: v.co = v.co.lerp(centre, shrink) + Vector((0, inward, 0))
        for f in {f for v in fresh for f in v.link_faces}: f.material_index = dark_index; f.smooth = True
        ring = [g for g in res['geom'] if isinstance(g, bmesh.types.BMEdge) and all(x in fresh for x in g.verts)]
    return rim


def fang(bm, root, tip, width, index):
    axis = tip - root; length = axis.length; axis.normalize()
    side = axis.cross(Vector((0, 1, 0)))
    if side.length < .1: side = axis.cross(Vector((1, 0, 0)))
    side.normalize(); depth = side.cross(axis).normalized(); rings = []
    for r in range(6):
        t = r / 5; rad = width * (1 - t ** 1.4)
        rings.append([bm.verts.new(root + axis * length * t + side * math.cos(a) * rad + depth * math.sin(a) * rad * .7) for a in [k * math.tau / 8 for k in range(8)]])
    tipv = bm.verts.new(root + axis * length * 1.04)
    for a, b in zip(rings, rings[1:]):
        for k in range(8):
            f = bm.faces.new((a[k], a[(k + 1) % 8], b[(k + 1) % 8], b[k])); f.material_index = index; f.smooth = True
    for k in range(8):
        f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 8], tipv)); f.material_index = index; f.smooth = True


def build_head(kind, mats):
    head = load_head()
    for m in mats: head.data.materials.append(m)
    SKIN, DARK, TOOTH, GLOW, THREAD = range(5)
    bm = bmesh.new(); bm.from_mesh(head.data); layer = bm.loops.layers.uv.active; bm.normal_update()
    uvs = uv_of(bm, layer); rng = random.Random(len(kind) * 7)

    # Emaciate every face: deep orbits, starved cheeks and temples.
    for v, (u, w) in uvs.items():
        if v.co.y > .03: continue
        push = 0.
        for cu in (.424, .579):
            push -= .022 * math.exp(-(((u - cu) / .06) ** 2 + ((w - .31) / .05) ** 2))
        push -= .024 * (math.exp(-(((u - .34) / .05) ** 2 + ((w - .45) / .08) ** 2)) + math.exp(-(((u - .66) / .05) ** 2 + ((w - .45) / .08) ** 2)))
        push -= .012 * (math.exp(-(((u - .28) / .05) ** 2 + ((w - .27) / .08) ** 2)) + math.exp(-(((u - .72) / .05) ** 2 + ((w - .27) / .08) ** 2)))
        v.co += v.normal * push

    # Hollow black eyes for all but the sewn and the milky-eyed corpse.
    if kind in ('split', 'hooded'):
        for cu in (.424, .579):
            cut(bm, layer, lambda u, w, cu=cu: ((u - cu) / .030) ** 2 + ((w - .312) / .019) ** 2 < 1)
            throat(bm, lambda p, cu=cu: abs(p.z - .03) < .06 and (p.x < -.005 if cu < .5 else p.x > -.005), DARK, .03)
            if kind == 'hooded':
                c = Vector(((cu - .5) * 1.0 - .007, -.075, .03))
                s = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=.0055)
                for vv in s['verts']: vv.co += c
                for f in {f for vv in s['verts'] for f in vv.link_faces}: f.material_index = GLOW

    if kind == 'split':
        # The face opens from brow to chin; both halves are pushed apart.
        def slit(u, w):
            if not .16 < w < .64: return False
            return abs(u - .5) < .006 + .028 * math.sin((w - .16) / .48 * math.pi)
        uvs = uv_of(bm, layer)
        for v, (u, w) in uvs.items():
            if v.co.y < .03 and .12 < w < .70:
                spread = .022 * math.sin(min(1, max(0, (w - .12) / .58)) * math.pi) * math.exp(-((u - .5) / .09) ** 2)
                v.co.x += math.copysign(spread, u - .5)
        cut(bm, layer, slit)
        rim = throat(bm, lambda p: abs(p.x + .007) < .07, DARK, .07)
        for v in rim:
            if rng.random() < .55:
                inward = Vector((-.7 if v.co.x > -.007 else .7, .6, 0)).normalized()
                fang(bm, v.co + Vector((0, .006, 0)), v.co + inward * rng.uniform(.018, .034) + Vector((0, 0, rng.uniform(-.006, .006))), rng.uniform(.0035, .0055), TOOTH)

    if kind in ('hooded', 'ragged', 'seated'):
        if kind == 'hooded':
            def mouth(u, w):
                top = .455 - .07 * ((u - .5) / .2) ** 2; return abs(u - .5) < .2 and top < w < top + .028 * (1 - ((u - .5) / .2) ** 2) + .004
        elif kind == 'ragged':
            def mouth(u, w): return ((u - .5) / .055) ** 2 + ((w - .52) / .085) ** 2 < 1
        else:
            def mouth(u, w): return ((u - .5) / .06) ** 2 + ((w - .50) / .055) ** 2 < 1
        if kind in ('ragged', 'seated'):
            # Dislocated jaw: everything under the mouth hangs far too low.
            drop = .085 if kind == 'ragged' else .04
            for v, (u, w) in uv_of(bm, layer).items():
                if v.co.y < .03 and w > .47:
                    k = min(1, (w - .47) / .08) * math.exp(-((u - .5) / .16) ** 2)
                    v.co.z -= drop * k; v.co.y += drop * .3 * k
        cut(bm, layer, mouth)
        rim = throat(bm, lambda p: abs(p.x + .007) < .14 and p.z < -.02, DARK, .06)
        for v in rim:
            if rng.random() < (.6 if kind == 'hooded' else .25):
                up = v.co.z > sum(x.co.z for x in rim) / len(rim)
                fang(bm, v.co + Vector((0, .005, 0)), v.co + Vector((rng.uniform(-.003, .003), .004, (-1 if up else 1) * rng.uniform(.012, .026))), rng.uniform(.003, .0045), TOOTH)

    if kind == 'ragged':
        # Thick black stitches pull both eyes shut.
        for cu in (.424, .579):
            cx = (cu - .5) * 1.0 - .007
            for k in range(7):
                x = cx - .035 + k * .0115
                a = Vector((x, -.115, .045)); b = Vector((x + .003, -.117, .015))
                s = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=.0022, radius2=.0022, depth=(b - a).length)
                for vv in s['verts']: vv.co = vv.co + (a + b) / 2
                for f in {f for vv in s['verts'] for f in vv.link_faces}: f.material_index = THREAD
    if kind == 'seated':
        for cu in (.424, .579):
            c = Vector(((cu - .5) * 1.0 - .007, -.085, .03))
            s = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=.024)
            for vv in s['verts']: vv.co += c
            for f in {f for vv in s['verts'] for f in vv.link_faces}: f.material_index = GLOW

    bm.to_mesh(head.data); bm.free()
    if 'custom_normal' in head.data.attributes: head.data.attributes.remove(head.data.attributes['custom_normal'])
    for p in head.data.polygons: p.use_smooth = True
    head.scale = (HEAD_SCALE,) * 3; head.location = HEAD_AT
    bpy.context.view_layer.objects.active = head; bpy.ops.object.select_all(action='DESELECT'); head.select_set(True)
    bpy.ops.object.transform_apply(location=True, scale=True)
    # The eye/mouth/throat surgery above roughly doubles the scanned head's
    # density; collapse it back down so four of these stay cheap to render.
    dec = head.modifiers.new('d', 'DECIMATE'); dec.ratio = .30
    bpy.ops.object.modifier_apply(modifier='d')
    for p in head.data.polygons: p.use_smooth = True
    head.name = 'Head'
    return head


# ---------------------------------------------------------------- bodies
def build(kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(kind)
    face = OUT / f'{kind}-face.png'
    skin = material('Desiccated visitor skin', (.52, .50, .45), .78)
    complexion = material('Visitor scanned complexion', (1, 1, 1), .7, texture=face)
    dark = material('Excavated mouth darkness', (.01, .006, .006), .4)
    tooth = material('Visitor enamel', (.52, .47, .33), .35)
    glow = material('Pinpoint eye glint', (.85, .82, .70), .1, emission=(.55, .52, .42)) if kind == 'hooded' else material('Milky dead eye', (.62, .64, .56), .12)
    thread = material('Black suture thread', (.02, .015, .01), .6)
    nail = material('Blackened nail', (.03, .025, .02), .3)
    cloth = {'split': ('Ragged funeral fabric', (.62, .60, .55)), 'hooded': ('Waxed black hood coat', (.035, .036, .04)),
             'ragged': ('Ragged funeral fabric', (.52, .46, .36)), 'seated': ('Rotten gown fabric', (.50, .48, .44))}[kind]
    garment_m = material(cloth[0], cloth[1], .93)
    under = material('Stained shirt fabric', (.70, .67, .58), .9)

    head = build_head(kind, [complexion, dark, tooth, glow, thread])
    head_parts = [head]

    seated = kind == 'seated'
    V = Vector

    # One organic body from a weighted skeleton (skin modifier + subdivision).
    def skinned(name, points, edges, mat, levels=2):
        me = bpy.data.meshes.new(name); me.from_pydata([p for p, r in points], edges, []); me.update()
        o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
        mod = o.modifiers.new('skin', 'SKIN')
        for i, (p, r) in enumerate(points):
            me.skin_vertices[0].data[i].radius = r
        me.skin_vertices[0].data[0].use_root = True
        sub = o.modifiers.new('sub', 'SUBSURF'); sub.levels = levels
        bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='skin'); bpy.ops.object.modifier_apply(modifier='sub')
        me.materials.clear(); me.materials.append(mat)
        for f in me.polygons: f.use_smooth = True
        return o

    body = skinned('body', [(V((0, .02, .95)), (.12, .085)), (V((0, .035, 1.10)), (.085, .062)), (V((0, .0, 1.30)), (.125, .085)),
                            (V((0, -.005, 1.46)), (.145, .085)), (V((0, .0, 1.585)), (.06, .055)), (V((0, -.02, 1.75)), (.04, .042)),
                            (V((-.205, .0, 1.545)), (.05, .045)), (V((.205, .0, 1.545)), (.05, .045)),
                            (V((-.095, .02, .90)), (.075, .07)), (V((.095, .02, .90)), (.075, .07))],
                   [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (3, 6), (3, 7), (0, 8), (0, 9)], skin, 3)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.normal_update()
    for v in bm.verts:
        p = v.co.copy()
        if 1.18 < p.z < 1.47 and abs(p.x) < .14:
            # Ribs and a sunken sternum under stretched skin.
            v.co += v.normal * (.0065 * max(0, math.sin((p.z - 1.18) * 62)) * (1 - abs(p.x) / .14) - .006 * math.exp(-(p.x / .02) ** 2) * (p.y < 0))
        if 1.0 < p.z < 1.15 and p.y < 0: v.co += v.normal * -.012
        if p.y > .03 and .95 < p.z < 1.55: v.co += v.normal * .006 * math.exp(-(p.x / .012) ** 2) * max(0, math.sin(p.z * 95))
        v.co += v.normal * .0025 * noise(p * 40)
    bm.to_mesh(body.data); bm.free()

    def leg_points(side):
        x = side * .10
        if seated:
            return [(V((x, .02, .92)), (.065, .065)), (V((x + side * .01, -.36, .86)), (.045, .045)), (V((x + side * .012, -.40, .48)), (.04, .04)), (V((x + side * .012, -.38, .05)), (.026, .028))]
        return [(V((x, .02, .92)), (.065, .065)), (V((x + side * .008, .0, .53)), (.045, .045)), (V((x + side * .006, .01, .30)), (.03, .032)), (V((x + side * .012, .03, .05)), (.026, .028))]

    def arm_points(side):
        sx = side * .23
        hand_z = .80 if not seated else .70
        return [(V((sx, .0, 1.55)), (.045, .043)), (V((sx + side * .028, -.02, 1.33)), (.03, .03)), (V((sx + side * .03, -.035, 1.14)), (.034, .03)),
                (V((sx + side * .03, -.06, .97)), (.022, .019)), (V((sx + side * .028, -.08, hand_z)), (.017, .014))]

    # Cloth falls over the real body in a short simulation; tears are cut first.
    def garment(name, rows, cols, top, bottom, rx, ry, mat, open_front=0., colliders=(), tear=.25, pin_rows=2, flare=.35, frames=90, centre=None):
        centre = centre or V((0, 0, 0))
        verts, faces = [], []
        for r in range(rows + 1):
            v = r / rows; z = top + (bottom - top) * v
            for c in range(cols):
                a = open_front + (math.tau - 2 * open_front) * c / (cols - (1 if open_front else 0))
                # Narrow at the collar, wide at the hem: gravity and collision make the folds.
                k = (.45 + .55 * min(1, v * 3.5)) * (1 + flare * v)
                verts.append(centre + V((math.sin(a) * rx * k * 1.35, -math.cos(a) * ry * k * 1.5, z + .05)))
        span = cols - 1 if open_front else cols
        for r in range(rows):
            for c in range(span):
                u, v = c / cols, r / rows
                if v > .55 and noise(V((u * 11, v * 4, len(name)))) > tear + (1 - v) * 1.4: continue
                if .2 < v < .8 and noise(V((u * 17, v * 9, 3.3))) > .62: continue
                a = r * cols + c; b = r * cols + (c + 1) % cols
                faces.append((a, b, b + cols, a + cols))
        o = new_obj(name, verts, faces, [mat])
        g = o.vertex_groups.new(name='pin')
        if pin_rows: g.add(list(range(cols * pin_rows)), 1., 'REPLACE')
        for col in colliders:
            if not col.modifiers.get('Collision'):
                col.modifiers.new('Collision', 'COLLISION'); col.collision.thickness_outer = .006
        cl = o.modifiers.new('Cloth', 'CLOTH'); cs = cl.settings
        cs.quality = 8; cs.mass = .3; cs.tension_stiffness = 15; cs.compression_stiffness = 15; cs.bending_stiffness = .25; cs.air_damping = 2
        cs.shrink_min = .04; cl.collision_settings.collision_quality = 4
        cs.vertex_group_mass = 'pin'; cl.collision_settings.distance_min = .006; cl.collision_settings.use_self_collision = False
        scene = bpy.context.scene; scene.frame_start = 1; scene.frame_end = frames
        cl.point_cache.frame_start = 1; cl.point_cache.frame_end = frames
        for f in range(1, frames + 1): scene.frame_set(f)
        bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='Cloth'); scene.frame_set(1)
        o.vertex_groups.clear()
        solidify(o, .005)
        for f in o.data.polygons: f.use_smooth = True
        return o

    def clear_collision(objs):
        for o in objs:
            m = o.modifiers.get('Collision')
            if m: o.modifiers.remove(m)

    legs_temp = [skinned('legproxy', leg_points(side), [(0, 1), (1, 2), (2, 3)], skin, 1) for side in (-1, 1)]
    parts = [body]
    if kind == 'hooded':
        parts.append(garment('long coat', 46, 72, 1.60, .20, .19, .12, garment_m, .30, [body] + legs_temp, .3))
    elif kind == 'split':
        parts.append(garment('open shirt', 26, 60, 1.60, 1.00, .17, .11, under, .45, [body], .45, flare=.12))
        parts.append(garment('funeral jacket', 30, 64, 1.62, .78, .19, .125, garment_m, .75, [body], .35, flare=.2))
    elif kind == 'ragged':
        parts.append(garment('sackcloth shift', 40, 64, 1.60, .42, .18, .115, garment_m, 0., [body] + legs_temp, .05))
    else:
        # Cloth sim tangles badly on a bent, seated pose; drape a static sheet
        # along the real hip/knee/shin centreline instead.
        seat_profile = [(0, 1.62, .19, .13), (0, 1.30, .21, .15), (0, .97, .22, .16), (-.17, .80, .205, .155),
                        (-.33, .62, .175, .14), (-.37, .42, .14, .12), (-.33, .22, .11, .10)]
        def seat_place(u, v):
            cy, z, w, d = curve(seat_profile, v); a = math.tau * u
            wob = noise(V((u * 9, v * 4, 11))) * .012
            return V((math.sin(a) * (w + wob), cy - math.cos(a) * d, z))
        parts.append(torn_sheet('rotten gown', 48, 72, seat_place, garment_m, .008, rng))
    clear_collision([body])
    for o in legs_temp: bpy.data.objects.remove(o)
    torso = join(parts, 'Torso')

    if kind == 'hooded':
        # A deep hood draped over the actual head, open only at the face.
        proxy = head.copy(); proxy.data = head.data.copy(); bpy.context.collection.objects.link(proxy)
        dec = proxy.modifiers.new('d', 'DECIMATE'); dec.ratio = .05
        bpy.context.view_layer.objects.active = proxy; bpy.ops.object.select_all(action='DESELECT'); proxy.select_set(True); bpy.ops.object.modifier_apply(modifier='d')
        verts, faces = [], []; rows, cols = 30, 56
        for r in range(rows + 1):
            t = r / rows
            for c in range(cols):
                a = c * math.tau / cols; rad = .17 * math.sin(min(1, .15 + t * 1.6) * math.pi / 2) + .02
                verts.append(V((math.sin(a) * rad, -math.cos(a) * rad + .02, 2.06 - .46 * t)))
        for r in range(rows):
            for c in range(cols):
                # Match the vertex placement's angle convention (forward = raw
                # angle 0, since position uses sin/-cos), not a shifted one.
                raw = (c + .5) * math.tau / cols
                a = raw if raw <= math.pi else raw - math.tau
                z = 2.06 - .46 * (r + .5) / rows
                if abs(a) < .75 and 1.70 < z < 1.98: continue
                faces.append((r * cols + c, r * cols + (c + 1) % cols, (r + 1) * cols + (c + 1) % cols, (r + 1) * cols + c))
        # A static tapered sock is far more predictable here than cloth sim,
        # which kept collapsing a free-hanging hood into the collar below it.
        hood = new_obj('hood', verts, faces, [garment_m])
        bpy.data.objects.remove(proxy)
        solidify(hood, .008)
        for f in hood.data.polygons: f.use_smooth = True
        head_parts.append(hood)

    arms = []
    for side, key in ((-1, 'ArmL'), (1, 'ArmR')):
        pts = arm_points(side); limb = skinned(key + ' limb', pts, [(0, 1), (1, 2), (2, 3), (3, 4)], skin, 2)
        bits = [limb]
        # Sleeves run down to near the wrist; ragged's left arm keeps a torn,
        # missing sleeve on purpose, everyone else is covered to the forearm.
        if kind != 'ragged' or side > 0:
            bottom = .92 if not seated else .82
            sleeve = garment(key + ' sleeve', 16, 28, 1.60, bottom, .075, .07, garment_m, 0., [limb], .12, flare=.22, frames=40, centre=V((side * .25, -.01, 0)))
            bits.append(sleeve)
        clear_collision([limb])
        bits += hand(key, side, skin, nail, pts[-1][0], .55 if not seated else .95)
        arm = join(bits, key)
        pivot = V((side * .25, 0, SHOULDER - .02))
        for v in arm.data.vertices: v.co -= pivot
        arm.location = pivot; arms.append(arm)

    legs = []
    for side, key in ((-1, 'LegL'), (1, 'LegR')):
        pts = leg_points(side); limb = skinned(key + ' limb', pts, [(0, 1), (1, 2), (2, 3)], skin, 2)
        ankle = pts[-1][0]; x = ankle.x
        bits = [limb, tube(key + ' foot', [(x, ankle.y + .03, .045, .032, .022), (x + side * .004, ankle.y - .08, .03, .04, .016), (x + side * .008, ankle.y - .16, .022, .045, .012)], skin, 10, 14)]
        for t in range(5):
            tx = x + side * .008 + (t - 2) * .016; ty = ankle.y - .16
            bits.append(tube(key + ' toe', [(tx, ty, .02, .007, .006), (tx, ty - .05, .012, .006, .005), (tx, ty - .075, .006, .002, .002)], skin, 6, 8))
            bits.append(tube(key + ' toenail', [(tx, ty - .06, .015, .005, .002), (tx, ty - .085, .008, .001, .001)], nail, 3, 6))
        if kind == 'split':
            trouser = garment(key + ' trouser', 22, 32, .98, .22, .075, .075, garment_m, 0., [limb], .3, pin_rows=2, flare=.15, frames=50, centre=V((side * .105, .01, 0)))
            bits.append(trouser)
        clear_collision([limb])
        leg = join(bits, key)
        for v in leg.data.vertices: v.co -= V((side * .10, -.085, .07))
        leg.location = V((side * .10, -.085, .07)); legs.append(leg)

    rig = bpy.data.objects.new('NightVisitor', None); bpy.context.collection.objects.link(rig)
    head_rig = bpy.data.objects.new('HeadRig', None); bpy.context.collection.objects.link(head_rig)
    head_rig.parent = rig; head_rig.location = (0, 0, 1.6)
    for o in head_parts:
        for v in o.data.vertices: v.co.z -= 1.6
        o.parent = head_rig
    for o in [torso] + arms + legs: o.parent = rig
    if kind == 'seated':
        # Slumped on a throne, head lolling back.
        head_rig.rotation_euler = (math.radians(-22), 0, math.radians(14))
    name = {'split': 'visitor-split', 'hooded': 'visitor-hooded', 'ragged': 'visitor-ragged', 'seated': 'seated-visitor'}[kind]
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB', use_selection=True, export_cameras=False, export_lights=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('VISITOR', name, tris, flush=True)
    return {name: tris}


report = {}
for kind in ('split', 'hooded', 'ragged', 'seated'):
    report.update(build(kind))
(OUT / 'provenance.json').write_text(json.dumps({
    'head_base': 'Lee Perry-Smith head scan, CC BY 3.0, via the existing credited clown derivative',
    'original': ['bodies', 'clothes', 'hands', 'feet', 'teeth', 'stitches', 'hood', 'face painting'],
    'models': report}, indent=2), encoding='utf-8')
(OUT / 'LICENSE.txt').write_text('Heads: Infinite, 3D Head Scan by Lee Perry-Smith, CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/),\n'
                                 'reshaped, cut and repainted for After Play. Bodies, clothes, hands, teeth and accessories are original.\n', encoding='utf-8')
