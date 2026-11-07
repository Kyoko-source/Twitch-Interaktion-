"""Rebuild the kitchen clown: stooped original body, fitted sleeves, opened face.

Run: blender -b --python tools/model-after-play-clown-v420.py
The head keeps the credited scan and its UVs; body, sleeves, eyes, teeth and
mouth are original geometry. The Head node is exported at life-like scale, so
the hair and cap parented to it in the game follow without being refitted.
"""
import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'clown-v420'
LAYOUT = json.loads((OUT / 'face-layout.json').read_text(encoding='utf-8'))
HEAD_SCALE = .66
HEAD_POSITION = Vector((0, -.60, 1.84))
GAPE_DROP = .062


def material(name, color, roughness=.8, metallic=0., emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    if emission:
        p.inputs['Emission Color'].default_value = (*emission, 1)
        p.inputs['Emission Strength'].default_value = 1
    return m


def smoothstep(a, b, x):
    t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def curve(points, t):
    """Catmull-Rom through tuples, t in 0..1."""
    span = len(points) - 1
    i = min(int(t * span), span - 1)
    f = t * span - i
    p0, p1, p2, p3 = (points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, span)])
    out = []
    for a, b, c, d in zip(p0, p1, p2, p3):
        out.append(.5 * (2 * b + (c - a) * f + (2 * a - 5 * b + 4 * c - d) * f * f + (3 * b - a - 3 * c + d) * f ** 3))
    return out


def noise(a, b, seed=0.):
    return (math.sin(a * 2.1 + seed) * math.cos(b * 3.3 + seed * 1.7) + math.sin(a * 5.3 + b * 4.1 + seed * .6) * .5) / 1.5


def add_mesh(name, verts, faces, mats):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for m in mats:
        mesh.materials.append(m)
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def loft(name, sections, rings, sides, mat, shape=None, caps=True):
    """Sections: (x, y, z, half_width, half_depth, power). shape deforms radius."""
    verts, faces = [], []
    previous = None
    for r in range(rings + 1):
        t = r / rings
        x, y, z, w, d, power = curve(sections, t)
        centre = Vector((x, y, z))
        ahead = Vector(curve(sections, min(1, t + .01))[:3]) - Vector(curve(sections, max(0, t - .01))[:3])
        ahead.normalize()
        side = Vector((1, 0, 0))
        depth = ahead.cross(side).normalized()
        side = depth.cross(ahead).normalized()
        for s in range(sides):
            a = math.tau * s / sides
            c, n = math.cos(a), math.sin(a)
            px = math.copysign(abs(c) ** (2 / power), c) * w
            py = math.copysign(abs(n) ** (2 / power), n) * d
            scale = 1 + (shape(t, a) if shape else 0)
            verts.append(centre + side * px * scale + depth * py * scale)
    for r in range(rings):
        for s in range(sides):
            a, b = r * sides + s, r * sides + (s + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if caps:
        for ring, flip in ((0, True), (rings, False)):
            centre = sum((verts[ring * sides + s] for s in range(sides)), Vector()) / sides
            verts.append(centre)
            c = len(verts) - 1
            for s in range(sides):
                a, b = ring * sides + s, ring * sides + (s + 1) % sides
                faces.append((b, a, c) if flip else (a, b, c))
    obj = add_mesh(name, verts, faces, [mat])
    fix_normals(obj)
    return obj


def fix_normals(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def solidify(obj, thickness):
    mod = obj.modifiers.new('Cloth thickness', 'SOLIDIFY')
    mod.thickness = thickness
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join(target, parts):
    bpy.ops.object.select_all(action='DESELECT')
    for part in [target, *parts]:
        part.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def ruff(name, centre, tilt, inner, outer, pleats, sides, mat, lift, seed):
    verts, faces = [], []
    rows = 6
    for row in range(rows + 1):
        t = row / rows
        for s in range(sides):
            a = math.tau * s / sides
            torn = 1 + (noise(a * 3, seed, seed) * .10 + (.07 if math.sin(a * 7 + seed) > .72 else 0)) * t
            wave = math.sin(a * pleats) * (.006 + .036 * t ** 1.2)
            radius = lerp(inner, outer, t) * torn
            x, y = math.cos(a) * radius, math.sin(a) * radius
            verts.append(Vector((x, y, wave + lift * (1 - t) - .05 * t * t)))
    for row in range(rows):
        for s in range(sides):
            a, b = row * sides + s, row * sides + (s + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    matrix = tilt.to_matrix()
    verts = [matrix @ v + centre for v in verts]
    obj = add_mesh(name, verts, faces, [mat])
    solidify(obj, .0045)
    return obj


def build_body(detail):
    costume = material('Blood stained woven costume', (.36, .10, .09), .95)
    linen = material('Dirty pleated linen', (.56, .52, .42), .92)
    neck_skin = material('Cracked greasepaint and blood', (.55, .51, .45), .72)
    leather = material('Cracked oxblood leather', (.075, .018, .016), .46)
    brass = material('Tarnished buttons', (.27, .20, .10), .5, .75)
    rings, sides = int(90 * detail), int(112 * detail)

    def torso_folds(t, a):
        drag = math.sin(a * 9 + t * 3) * .018 + math.sin(a * 17 - t * 9) * .009
        ribs = math.sin(t * 34) * .010 * smoothstep(.5, .72, t) * (1 - smoothstep(.8, 1, t)) * (1 if math.sin(a) < 0 else 0)
        return drag * (1 - smoothstep(.72, .95, t)) + ribs + noise(a * 2, t * 8, 4) * .022

    torso = loft('Body', [
        (0, .07, .90, .165, .125, 2.4),
        (0, .05, 1.02, .172, .128, 2.4),
        (0, .00, 1.18, .130, .096, 2.3),
        (0, -.09, 1.32, .158, .106, 2.4),
        (0, -.23, 1.46, .215, .130, 2.7),
        (0, -.36, 1.55, .262, .118, 2.9),
        (0, -.45, 1.61, .165, .090, 2.4),
        (0, -.49, 1.64, .060, .060, 2),
    ], rings, sides, costume, torso_folds)

    def neck_tendons(t, a):
        return math.sin(a * 5) * .05 * math.sin(t * math.pi) + math.sin(a * 11 + 1) * .018

    neck = loft('Sinewed neck', [
        (0, -.45, 1.58, .056, .054, 2),
        (0, -.50, 1.65, .047, .046, 2),
        (0, -.55, 1.72, .043, .044, 2),
        (0, -.59, 1.80, .052, .054, 2),
    ], int(30 * detail), int(40 * detail), neck_skin, neck_tendons)

    parts = [neck]
    from mathutils import Euler
    tilt = Euler((math.radians(34), 0, 0))
    centre = Vector((0, -.50, 1.665))
    ruff_sides = int(420 * detail)
    parts.append(ruff('Lower ruff tier', centre, tilt, .05, .228, 21, ruff_sides, linen, .012, 2.))
    parts.append(ruff('Upper ruff tier', centre + Vector((0, -.016, .024)), tilt, .046, .162, 17, ruff_sides, linen, .018, 7.))

    # Stilted, slightly bent legs in loose trousers.
    for side in (-1, 1):
        def trouser(t, a, side=side):
            sag = math.sin(a * 7 + t * 12 + side) * .05 + math.sin(a * 13 - t * 22) * .022
            return sag * (.55 + .45 * math.sin(t * math.pi)) + smoothstep(.9, 1, t) * (.34 + math.sin(a * 11) * .09)
        parts.append(loft('Trouser leg', [
            (side * .092, .07, .98, .105, .112, 2),
            (side * .112, .03, .76, .086, .092, 2),
            (side * .124, -.045, .53, .070, .076, 2),
            (side * .126, .00, .31, .070, .074, 2),
            (side * .128, .075, .105, .076, .078, 2),
        ], int(58 * detail), int(52 * detail), costume, trouser))
        parts.append(loft('Long clown shoe', [
            (side * .135, .17, .055, .058, .050, 2.2),
            (side * .138, .07, .067, .071, .062, 2.2),
            (side * .146, -.09, .070, .066, .058, 2.2),
            (side * .160, -.24, .080, .094, .074, 2.1),
            (side * .166, -.335, .080, .084, .067, 2.1),
            (side * .166, -.385, .080, .020, .018, 2),
        ], int(36 * detail), int(36 * detail), leather, lambda t, a: noise(a * 2, t * 7, 2) * .05))

    # Butcher apron: one heavy sheet hanging from the chest past the knees.
    columns, rows = int(92 * detail), int(92 * detail)
    points = [(-.255, 1.455, .13), (-.170, 1.30, .155), (-.150, 1.16, .205), (-.180, 1.00, .245), (-.200, .78, .285), (-.195, .50, .30)]
    verts, faces = [], []
    for row in range(rows + 1):
        t = row / rows
        y, z, half = curve(points, t)
        for column in range(columns + 1):
            c = column / columns * 2 - 1
            hem = noise(c * 5, 3, 5) * .035 + (.03 if math.sin(c * 19) > .8 else 0)
            zz = lerp(z, points[-1][1] + hem, smoothstep(.72, 1, t) * t)
            pleat = math.sin(c * 15 + noise(t, c, 1) * .8) * (.005 + .026 * smoothstep(.2, 1, t))
            wrap = (c * c) * half * .66
            verts.append(Vector((c * half + math.sin(t * 7 + c * 3) * .005, y + wrap - pleat, zz)))
    for row in range(rows):
        for column in range(columns):
            a = row * (columns + 1) + column
            faces.append((a, a + 1, a + columns + 2, a + columns + 1))
    apron = add_mesh('Butcher apron', verts, faces, [linen])
    solidify(apron, .005)
    parts.append(apron)

    body = join(torso, parts)
    body.name = 'Body'
    # Tangents for the cloth normal map need a UV set; the shaders tile by position.
    uv = body.data.uv_layers.new(name='Cloth')
    for loop in body.data.loops:
        p = body.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x + p.y, p.z)
    return body


def eyeball(bm, centre, radius, mats, look):
    """Sclera, iris and pinprick pupil as nested caps around the look axis."""
    sclera, iris, pupil = mats

    def sphere(c, r, mat_index, squash=1.):
        result = bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=r)
        for v in result['verts']:
            offset = v.co.copy()
            offset.y *= squash
            v.co = c + offset
        faces = {f for v in result['verts'] for f in v.link_faces}
        for f in faces:
            f.material_index = mat_index
            f.smooth = True
    sphere(centre, radius, sclera)
    sphere(centre + look * radius * .86, radius * .36, iris, .32)
    sphere(centre + look * radius * .985, radius * .15, pupil, .30)


def tooth(bm, root, tip, width, mat_index, jaw_layer, jaw, rng):
    axis = (tip - root)
    length = axis.length
    axis.normalize()
    side = axis.cross(Vector((0, 1, 0))).normalized()
    depth = side.cross(axis).normalized()
    rows, sides = 7, 9
    rings = []
    bend = Vector((rng.uniform(-.1, .1), rng.uniform(-.04, .08), 0)) * length
    for r in range(rows + 1):
        t = r / rows
        radius = width * (1 - t ** 1.45) * (1 + .22 * math.sin(t * math.pi))
        ring = []
        for s in range(sides):
            a = math.tau * s / sides
            p = root + axis * length * t + bend * t * t + side * math.cos(a) * radius + depth * math.sin(a) * radius * .72
            ring.append(bm.verts.new(p))
        rings.append(ring)
    tip_vertex = bm.verts.new(root + axis * length * 1.02 + bend)
    for a_ring, b_ring in zip(rings, rings[1:]):
        for s in range(sides):
            face = bm.faces.new((a_ring[s], a_ring[(s + 1) % sides], b_ring[(s + 1) % sides], b_ring[s]))
            face.material_index = mat_index
            face.smooth = True
    for s in range(sides):
        face = bm.faces.new((rings[-1][s], rings[-1][(s + 1) % sides], tip_vertex))
        face.material_index = mat_index
        face.smooth = True
    for v in [tip_vertex] + [v for ring in rings for v in ring]:
        v[jaw_layer] = jaw


def mouth_edges(u):
    m = LAYOUT['mouth']
    left, right = m['left'], m['right']
    span = min(1, max(0, (u - left[0]) / (right[0] - left[0])))
    corner = left[1] + (right[1] - left[1]) * span
    arch = 1 - (span * 2 - 1) ** 2
    return corner + (m['upper'] - corner) * arch ** .62, corner + (m['lower'] - corner) * arch ** .72


def in_mouth(u, v):
    m = LAYOUT['mouth']
    if not m['left'][0] < u < m['right'][0]:
        return False
    upper, lower = mouth_edges(u)
    return upper < v < lower


def in_eye(u, v, eye):
    dx, dy = u - eye['center'][0], v - eye['center'][1]
    c, s = math.cos(eye['tilt']), math.sin(eye['tilt'])
    rx, ry = dx * c + dy * s, -dx * s + dy * c
    return (rx / eye['radius'][0]) ** 2 + (ry / eye['radius'][1]) ** 2 < 1


def gauss(u, v, cu, cv, ru, rv):
    return math.exp(-(((u - cu) / ru) ** 2 + ((v - cv) / rv) ** 2))


def smooth_loop(edges, rounds):
    neighbours = {}
    for e in edges:
        a, b = e.verts
        neighbours.setdefault(a, []).append(b)
        neighbours.setdefault(b, []).append(a)
    for _ in range(rounds):
        moved = {v: sum((n.co for n in near), Vector()) / len(near) for v, near in neighbours.items()}
        for v, p in moved.items():
            v.co = v.co.lerp(p, .6)
    return list(neighbours)


def rebuild_head(head):
    enamel = material('Rotten pointed enamel', (.50, .42, .25), .36)
    gum = material('Raw inner mouth', (.13, .012, .016), .34)
    cavity = material('Deep anatomical cavities', (.028, .004, .005), .62)
    tongue_skin = material('Swollen tongue', (.20, .030, .036), .30)
    sclera = material('Bloodshot staring sclera', (.25, .155, .10), .22, emission=(.012, .006, .004))
    iris = material('Milky pale iris', (.62, .63, .50), .16, emission=(.085, .088, .066))
    pupil = material('Pinprick pupil', (.002, .002, .002), .12)
    socket = material('Sunken eyelid tissue', (.018, .010, .010), .55)
    mats = [enamel, gum, cavity, tongue_skin, sclera, iris, pupil, socket]
    first = len(head.data.materials)
    for m in mats:
        head.data.materials.append(m)
    index = {m.name: first + i for i, m in enumerate(mats)}

    bm = bmesh.new()
    bm.from_mesh(head.data)
    bm.verts.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active
    jaw = bm.verts.layers.float.new('jaw')
    bm.normal_update()
    uvs = {}
    for v in bm.verts:
        if v.link_loops:
            uv = v.link_loops[0][uv_layer].uv
            uvs[v] = (uv.x, 1 - uv.y)

    # Skull under the paint: deep orbits, starved cheeks, heavy brow, long chin.
    mouth_centre_v = (LAYOUT['mouth']['upper'] + LAYOUT['mouth']['lower']) / 2
    for v, (u, w) in uvs.items():
        if v.co.y > .03:
            continue
        push = 0.
        for eye in LAYOUT['eyes']:
            cu, cv = eye['center']
            push -= .017 * gauss(u, w, cu, cv, .058, .050)
            push += .0065 * gauss(u, w, cu + (cu - .5) * .05, cv - .056, .054, .017)
        push -= .021 * gauss(u, w, .345, .445, .052, .075) + .021 * gauss(u, w, .655, .445, .052, .075)
        push -= .009 * gauss(u, w, .29, .28, .05, .08) + .009 * gauss(u, w, .71, .28, .05, .08)
        v.co += v.normal * push
        # Narrow the jaw and pull the whole lower face downward.
        low = smoothstep(.43, .60, w) * (1 - smoothstep(.62, .72, w)) * smoothstep(.20, .34, u) * (1 - smoothstep(.66, .80, u))
        v.co.x = lerp(v.co.x, -.007, low * .13)
        v.co.z -= low * .026
        _, lower = mouth_edges(u)
        if w > lower - .004:
            near = smoothstep(.33, .42, u) * (1 - smoothstep(.58, .67, u))
            v[jaw] = near * (1 - smoothstep(.60, .69, w))

    def cut(test):
        faces = []
        for f in bm.faces:
            loops = f.loops
            u = sum(l[uv_layer].uv.x for l in loops) / len(loops)
            w = 1 - sum(l[uv_layer].uv.y for l in loops) / len(loops)
            if f.calc_center_median().y < .03 and test(u, w):
                faces.append(f)
        bmesh.ops.delete(bm, geom=faces, context='FACES_ONLY')
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context='EDGES')
        loose = [v for v in bm.verts if not v.link_faces and v.is_valid]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')

    def boundary(test):
        return [e for e in bm.edges if e.is_boundary and all(v.co.y < .03 and test(uv_of(v)) for v in e.verts)]

    def uv_of(v):
        return uvs.get(v, (0, 0))

    def near_mouth(p):
        return .33 < p[0] < .68 and .37 < p[1] < .56

    cut(in_mouth)
    edges = boundary(near_mouth)
    lip_verts = smooth_loop(edges, 14)
    centre = sum((v.co for v in lip_verts), Vector()) / len(lip_verts)

    # The raw lip rolls inward. Jaw weights travel with the extruded lower lip.
    def extrude_ring(ring_edges, inward, shrink, mat_index):
        result = bmesh.ops.extrude_edge_only(bm, edges=ring_edges)
        fresh = [g for g in result['geom'] if isinstance(g, bmesh.types.BMVert)]
        for f in {f for v in fresh for f in v.link_faces}:
            f.material_index = mat_index
            f.smooth = True
        for v in fresh:
            source = next((e.other_vert(v) for e in v.link_edges if e.other_vert(v) not in fresh), None)
            if source is not None:
                v[jaw] = source[jaw]
            v.co = v.co.lerp(centre, shrink) + inward
        return fresh, [g for g in result['geom'] if isinstance(g, bmesh.types.BMEdge) and all(x in fresh for x in g.verts)]

    _, ring = extrude_ring(edges, Vector((0, .010, 0)), .05, index['Raw inner mouth'])
    _, ring = extrude_ring(ring, Vector((0, .034, 0)), .12, index['Raw inner mouth'])
    # The throat closes the extruded walls, so nothing can pierce the cheeks.
    _, ring = extrude_ring(ring, Vector((0, .026, 0)), .55, index['Deep anatomical cavities'])
    extrude_ring(ring, Vector((0, .012, 0)), .96, index['Deep anatomical cavities'])

    tongue = bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=1)
    for v in tongue['verts']:
        unit = v.co.copy()
        droop = -.016 * (unit.y + 1) ** 2 * .25
        v.co = centre + Vector((unit.x * .040, .040 + unit.y * .056, -.024 + unit.z * .011 - droop))
        v[jaw] = .82
    for f in {f for v in tongue['verts'] for f in v.link_faces}:
        f.material_index = index['Swollen tongue']
        f.smooth = True

    # Two irregular rows of long teeth following the actual torn edge.
    rng = random.Random(420)
    ordered = sorted(lip_verts, key=lambda v: v.co.x)
    left_x, right_x = ordered[0].co.x, ordered[-1].co.x
    for upper_row in (True, False):
        count = 25
        for i in range(count):
            t = (i + .5) / count
            x = lerp(left_x, right_x, lerp(.055, .945, t))
            band = [v for v in lip_verts if abs(v.co.x - x) < .012 and (v.co.z > centre.z - .006 if upper_row else v.co.z < centre.z + .006)]
            if not band:
                continue
            anchor = sum((v.co for v in band), Vector()) / len(band)
            middle = 1 - abs(t * 2 - 1)
            length = (.022 + .030 * middle) * rng.uniform(.72, 1.28)
            if i % 5 == 2:
                length *= 1.34
            if rng.random() < .11:
                length *= .42
            sign = -1 if upper_row else 1
            root = anchor + Vector((0, .018, sign * -.012))
            tip = root + Vector((rng.uniform(-.008, .008), rng.uniform(-.006, .005), sign * length))
            tooth(bm, root, tip, rng.uniform(.0072, .0104), index['Rotten pointed enamel'], jaw, 0 if upper_row else 1, rng)

    # Lidless eyes staring out of the sockets.
    eye_mats = (index['Bloodshot staring sclera'], index['Milky pale iris'], index['Pinprick pupil'])
    for number, eye in enumerate(LAYOUT['eyes']):
        def test(u, w, eye=eye):
            return in_eye(u, w, eye)
        cut(test)

        def near_eye(p, eye=eye):
            return abs(p[0] - eye['center'][0]) < .062 and abs(p[1] - eye['center'][1]) < .05
        rim_edges = boundary(near_eye)
        rim = smooth_loop(rim_edges, 12)
        rim_centre = sum((v.co for v in rim), Vector()) / len(rim)
        result = bmesh.ops.extrude_edge_only(bm, edges=rim_edges)
        fresh = [g for g in result['geom'] if isinstance(g, bmesh.types.BMVert)]
        for f in {f for v in fresh for f in v.link_faces}:
            f.material_index = index['Sunken eyelid tissue']
            f.smooth = True
        for v in fresh:
            v.co = v.co.lerp(rim_centre, .08) + Vector((0, .024, 0))
        look = Vector(((.05 if number == 0 else -.05), -1, -.10)).normalized()
        eyeball(bm, rim_centre + Vector((0, .0225, 0)), .0265, eye_mats, look)

    bm.to_mesh(head.data)
    weights = [v[jaw] for v in bm.verts]
    bm.free()
    mesh = head.data
    if 'custom_normal' in mesh.attributes:
        mesh.attributes.remove(mesh.attributes['custom_normal'])
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.update()

    # One morph opens the mouth during attacks; the jaw swings down and back.
    head.shape_key_add(name='Basis', from_mix=False)
    gape = head.shape_key_add(name='Gape', from_mix=False)
    for i, weight in enumerate(weights):
        if weight:
            gape.data[i].co += Vector((0, .026, -GAPE_DROP)) * weight


def build_sleeve(path, profile, ruffle_end, detail):
    """Unit-length along Z: the game stretches it between two fixed joints."""
    cloth = material('Clown sleeve cloth', (.36, .10, .09), .95)
    rings, sides = int(64 * detail), int(52 * detail)
    verts, faces = [], []
    for r in range(rings + 1):
        t = r / rings
        radius = curve([(p,) for p in profile], t)[0]
        for s in range(sides):
            a = math.tau * s / sides
            gather = math.sin(a * 9 + math.sin(t * 7)) * .055 * math.sin(t * math.pi) + noise(a * 2, t * 5, 3) * .06
            flare = smoothstep(1 - ruffle_end, 1, t) * math.sin(a * 11) * .16 if ruffle_end else 0
            rr = radius * (1 + gather + flare)
            verts.append(Vector((math.cos(a) * rr, math.sin(a) * rr, t - .5)))
    for r in range(rings):
        for s in range(sides):
            a, b = r * sides + s, r * sides + (s + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    verts += [Vector((0, 0, -.5)), Vector((0, 0, .5))]
    for s in range(sides):
        faces.append(((s + 1) % sides, s, len(verts) - 2))
        faces.append((rings * sides + s, rings * sides + (s + 1) % sides, len(verts) - 1))
    obj = add_mesh('Fitted sleeve', verts, faces, [cloth])
    fix_normals(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / path), export_format='GLB', use_selection=True,
                              export_cameras=False, export_lights=False)
    bpy.data.objects.remove(obj)


def build_claws(source, target):
    """Keep the credited project hand, and grow a long black nail from each nail."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ASSETS / source))
    horn = material('Blackened claw', (.022, .017, .014), .30)
    for nail in [o for o in bpy.data.objects if o.type == 'MESH' and 'nail' in o.name.lower()]:
        points = [nail.matrix_world @ v.co for v in nail.data.vertices]
        centre = sum(points, Vector()) / len(points)
        # Claws run from the nail plate outward past the fingertip.
        direction = Vector((centre.x * .35, -.40, -1)).normalized()
        side = Vector((1, 0, 0))
        depth = direction.cross(side).normalized()
        verts, faces = [], []
        rows, sides = 8, 10
        for r in range(rows + 1):
            t = r / rows
            radius = .0058 * (1 - t) ** .75 + .00015
            middle = centre + direction * .052 * t + depth * .012 * t * t
            for s in range(sides):
                a = math.tau * s / sides
                verts.append(middle + side * math.cos(a) * radius + depth * math.sin(a) * radius * .55)
        for r in range(rows):
            for s in range(sides):
                a, b = r * sides + s, r * sides + (s + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        claw = add_mesh('Black claw', verts, faces, [horn])
        fix_normals(claw)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / target), export_format='GLB', use_selection=True,
                              export_cameras=False, export_lights=False)


def build(source, target, detail):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ASSETS / source))
    head = bpy.data.objects['Head']
    for obj in list(bpy.data.objects):
        if obj is not head:
            bpy.data.objects.remove(obj)
    head.parent = None
    build_body(detail)
    rebuild_head(head)
    head.location = HEAD_POSITION
    head.scale = (HEAD_SCALE,) * 3
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / target), export_format='GLB', use_selection=True,
                              export_apply=False, export_morph=True, export_morph_normal=False,
                              export_cameras=False, export_lights=False)
    return {obj.name: {'vertices': len(obj.data.vertices), 'triangles': sum(len(p.vertices) - 2 for p in obj.data.polygons)}
            for obj in bpy.data.objects if obj.type == 'MESH'}


def main():
    report = {
        'desktop': build('quality-v410/desktop/clown.glb', 'clown-desktop.glb', 1),
        'web': build('detail-v310/clown-v310.glb', 'clown-web.glb', .55),
    }
    build_claws('quality-v410/desktop/torch-grip.glb', 'clown-hand-desktop.glb')
    build_claws('revamp-v300/anatomical-grip-v300.glb', 'clown-hand-web.glb')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_sleeve('sleeve-upper.glb', [.062, .078, .080, .070, .056, .048, .047], .0, 1)
    build_sleeve('sleeve-forearm.glb', [.050, .047, .041, .036, .032, .032, .052], .16, 1)
    (OUT / 'provenance.json').write_text(json.dumps({
        'author': 'After Play original modelling',
        'sources': ['Lee Perry-Smith head scan, CC BY 3.0, retained and modified as the existing credited clown head'],
        'original': ['body', 'costume', 'ruff', 'apron', 'shoes', 'sleeves', 'eyes', 'teeth', 'mouth interior'],
        'models': report,
    }, indent=2), encoding='utf-8')
    print('CLOWN V420', json.dumps(report))


main()
