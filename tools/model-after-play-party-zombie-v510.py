"""Rigged and animated party zombies, After Play 5.1.0.

Takes the party child of 5.0.0 (tools/model-after-play-party-zombie-v500.py)
and makes it a real skinned character: one mesh on an 18-bone skeleton with
distance-blended skin weights, and baked actions Idle, Walk, Run, Attack,
Hit, Death and Crawl. The face gets the painted reference look
(tools/paint-after-play-party-zombie-v510.py), the dress a real fabric with
dots or stripes, dirt and blood, and a second torn frill at the hem.

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b --python tools/model-after-play-party-zombie-v510.py
Output: games/kinderparadies/assets/zombies-v510/party-zombie.glb, party-zombie-b.glb
"""
import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
ART = HERE.parent / 'games/kinderparadies/assets/zombies-v510'
source = (HERE / 'model-after-play-party-zombie-v500.py').read_text(encoding='utf-8').split('\nreport = {}')[0]

# Reuse the 5.0.0 builder, swapping the face, the dress fabric and the ending.
swaps = [
    ("    face = ASSETS / 'visitors-v421' / 'ragged-face.png'", "    face = ART / 'party-face.png'"),
    ("    dress = material('Torn party dress', (.25, .32, .31) if teal else (.42, .25, .28), .9)",
     "    dress = material('Torn party dress', (1, 1, 1), .9, texture=ART / ('party-dress-b.png' if teal else 'party-dress-a.png'))"),
    ("        o = new_obj(name, verts, faces, [mat])\n        g = o.vertex_groups.new(name='pin')",
     "        o = new_obj(name, verts, faces, [mat]); grid_uv(o, rows, cols)\n        g = o.vertex_groups.new(name='pin')"),
    ("    for o in [body] + legs_temp:\n        m = o.modifiers.get('Collision')",
     "    def hem_place(u, v):\n        a = math.tau * u; wave = .03 * math.sin(a * 16); r = .26 + v * (.09 + wave)\n        return V((math.sin(a) * r, -math.cos(a) * r * .8 + .02, (.7 if not teal else .82) - v * .1 + wave))\n    parts.append(torn_sheet('hem frill', 6, 120, hem_place, frill, .004, rng))\n    for o in [body] + legs_temp:\n        m = o.modifiers.get('Collision')"),
    ("    rig = bpy.data.objects.new('PartyZombie', None); bpy.context.collection.objects.link(rig)", "    return rig_and_export(kind, torso, arms, legs, head_parts)\n    rig = None"),
]
for a, b in swaps:
    assert a in source, a[:60]
    source = source.replace(a, b)


def grid_uv(o, rows, cols):
    """UVs for the garment grids (vertex index = row * cols + col)."""
    me = o.data
    uv = me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index; r, c = divmod(vi, cols)
            uv.data[li].uv = (c / cols * 3., 1 - r / rows)


# ---------------------------------------------------------------- skeleton
def bones_spec():
    out = [('root', (0, 0, 0), (0, 0, .2), None), ('hips', (0, .02, .9), (0, .02, 1.05), 'root'),
           ('spine', (0, .02, 1.05), (0, 0, 1.28), 'hips'), ('chest', (0, 0, 1.28), (0, -.005, 1.5), 'spine'),
           ('neck', (0, -.005, 1.5), (0, -.02, 1.68), 'chest'), ('head', (0, -.02, 1.68), (0, -.02, 2.0), 'neck')]
    for side, s in (('L', -1), ('R', 1)):
        sx = s * .22
        out += [(f'shoulder.{side}', (s * .05, 0, 1.5), (s * .2, 0, 1.55), 'chest'),
                (f'upperarm.{side}', (sx, 0, 1.55), (sx + s * .08, -.12, 1.18), f'shoulder.{side}'),
                (f'forearm.{side}', (sx + s * .08, -.12, 1.18), (sx + s * .11, -.27, .95), f'upperarm.{side}'),
                (f'hand.{side}', (sx + s * .11, -.27, .95), (sx + s * .115, -.31, .82), f'forearm.{side}'),
                (f'thigh.{side}', (s * .1, .02, .92), (s * .11, -.01, .53), 'hips'),
                (f'shin.{side}', (s * .11, -.01, .53), (s * .112, .02, .16), f'thigh.{side}'),
                (f'foot.{side}', (s * .112, .02, .16), (s * .12, -.2, .03), f'shin.{side}')]
    return out


def seg_dist(p, a, b):
    ab = b - a; t = max(0., min(1., (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def weigh(o, candidates, spec, top=3, power=4.):
    heads = {n: (Vector(h), Vector(t)) for n, h, t, _ in spec}
    groups = {n: o.vertex_groups.get(n) or o.vertex_groups.new(name=n) for n in candidates}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        scored = sorted(((1. / (seg_dist(p, *heads[n]) + .02) ** power, n) for n in candidates), reverse=True)[:top]
        total = sum(s for s, _ in scored)
        for s, n in scored: groups[n].add([v.index], s / total, 'REPLACE')


def apply_location(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ---------------------------------------------------------------- actions
FPS = 30

def pose_action(arm, name, length, pose, loop=True, step=2):
    """pose(t) -> {bone: (x, y, z degrees) or ('loc', Vector)}; baked keys."""
    act = bpy.data.actions.new(name); act.use_fake_user = True
    arm.animation_data_create(); arm.animation_data.action = act
    frames = int(round(length * FPS))
    for f in list(range(0, frames, step)) + [frames]:
        t = (f / frames) if frames else 0.
        for bone, value in pose(t % 1. if loop else t).items():
            if bone.endswith(':loc'):
                pb = arm.pose.bones[bone[:-4]]; pb.location = value; pb.keyframe_insert('location', frame=f + 1)
            else:
                pb = arm.pose.bones[bone]; pb.rotation_mode = 'QUATERNION'
                pb.rotation_quaternion = Euler([math.radians(a) for a in value], 'XYZ').to_quaternion()
                pb.keyframe_insert('rotation_quaternion', frame=f + 1)
    for fc in act.fcurves if hasattr(act, 'fcurves') else []:
        for k in fc.keyframe_points: k.interpolation = 'BEZIER'
    return act


def twitch(t, seed, amount):
    k = int(t * 9 + seed * 3.7); r = (math.sin(k * 12.9898 + seed) * 43758.5453) % 1.
    return (r - .5) * amount


def make_actions(arm):
    S = math.sin; P = math.tau
    def walk(t):
        p = t * P
        return {'hips:loc': Vector((0, abs(S(p)) * .03 - .01, 0)), 'hips': (0, 6 * S(p), 4 * S(p)), 'spine': (16 + 3 * S(2 * p), 0, -3 * S(p)), 'chest': (6, 0, 0),
                'neck': (-8, 0, 0), 'head': (-6 + twitch(t, 1, 22), twitch(t, 2, 30), 14 * S(p * .5) + twitch(t, 3, 26)),
                'thigh.L': (-26 * S(p), 0, 0), 'thigh.R': (26 * S(p), 0, 0),
                'shin.L': (32 * max(0., S(p + 1.6)), 0, 0), 'shin.R': (32 * max(0., S(p + 1.6 + math.pi)), 0, 0),
                'foot.L': (-10 * S(p), 0, 0), 'foot.R': (10 * S(p), 0, 0),
                'upperarm.L': (-70 - 8 * S(p + 1), 0, -8), 'upperarm.R': (-74 - 8 * S(p), 0, 8),
                'forearm.L': (-14, 0, 0), 'forearm.R': (-20 + 6 * S(p * 2), 0, 0)}
    def run(t):
        p = t * P
        return {'hips:loc': Vector((0, abs(S(p)) * .06 - .03, 0)), 'hips': (0, 8 * S(p), 6 * S(p)), 'spine': (30, 0, -5 * S(p)), 'chest': (10, 0, 0), 'neck': (-18, 0, 0),
                'head': (-12 + twitch(t, 4, 18), twitch(t, 5, 24), twitch(t, 6, 30)),
                'thigh.L': (-48 * S(p), 0, 0), 'thigh.R': (48 * S(p), 0, 0),
                'shin.L': (70 * max(0., S(p + 1.4)), 0, 0), 'shin.R': (70 * max(0., S(p + 1.4 + math.pi)), 0, 0),
                'foot.L': (-20 * S(p), 0, 0), 'foot.R': (20 * S(p), 0, 0),
                'upperarm.L': (-80 + 28 * S(p), 0, -14), 'upperarm.R': (-80 - 28 * S(p), 0, 14),
                'forearm.L': (-30, 0, 0), 'forearm.R': (-30, 0, 0)}
    def attack(t):
        lift = math.sin(min(t / .45, 1.) * math.pi * .5); slash = max(0., min((t - .45) / .2, 1.)); back = max(0., (t - .7) / .3)
        arm_x = -70 - 95 * lift + 150 * slash - (-15) * back * 0
        arm_x = arm_x * (1 - back) + (-70) * back
        return {'spine': (16 + 26 * slash * (1 - back) - 10 * lift * (1 - slash), 0, 0), 'chest': (6 + 12 * slash * (1 - back), 0, 0), 'neck': (-10, 0, 0),
                'head': (-12 * lift + 10 * slash * (1 - back), 0, twitch(t, 7, 20)),
                'upperarm.L': (arm_x, 0, -18 * lift * (1 - back)), 'upperarm.R': (arm_x - 6, 0, 18 * lift * (1 - back)),
                'forearm.L': (-50 * lift * (1 - slash) - 14, 0, 0), 'forearm.R': (-50 * lift * (1 - slash) - 18, 0, 0),
                'thigh.L': (-14 * slash * (1 - back), 0, 0), 'thigh.R': (10 * slash * (1 - back), 0, 0), 'shin.L': (18 * slash * (1 - back), 0, 0), 'shin.R': (6, 0, 0)}
    def hit(t):
        k = math.sin(min(t / .3, 1.) * math.pi) * (1 - t)
        return {'spine': (16 - 26 * k, 0, 8 * k), 'chest': (6 - 12 * k, 0, 0), 'head': (-30 * k, 14 * k, 0), 'neck': (-8, 0, 0),
                'upperarm.L': (-60 + 30 * k, 0, -30 * k), 'upperarm.R': (-64 + 30 * k, 0, 30 * k), 'forearm.L': (-14, 0, 0), 'forearm.R': (-20, 0, 0)}
    def death(t):
        buckle = min(t / .35, 1.); fall = max(0., min((t - .25) / .45, 1.)) ** 1.6; settle = max(0., (t - .7) / .3)
        return {'hips:loc': Vector((0, -.55 * fall - .2 * buckle, .05 * fall)), 'hips': (-78 * fall, 0, 12 * fall), 'spine': (16 - 30 * fall, 0, 0), 'chest': (-10 * fall, 0, 0),
                'neck': (-30 * fall, 0, 20 * settle), 'head': (-25 * fall, 18 * settle, 30 * settle),
                'thigh.L': (-40 * buckle + 30 * fall, 0, -10 * fall), 'thigh.R': (-30 * buckle + 40 * fall, 0, 12 * fall),
                'shin.L': (70 * buckle - 40 * fall, 0, 0), 'shin.R': (60 * buckle - 20 * fall, 0, 0),
                'upperarm.L': (-70 + 40 * fall - 80 * fall * (1 - settle), 0, -40 * fall), 'upperarm.R': (-70 + 10 * fall - 90 * fall * (1 - settle), 0, 50 * fall),
                'forearm.L': (-14 - 30 * fall, 0, 0), 'forearm.R': (-20 - 10 * fall, 0, 0)}
    def idle(t):
        p = t * P
        return {'hips:loc': Vector((0, 0, 0)), 'spine': (10 + 4 * S(p), 0, 4 * S(p * .5)), 'chest': (4, 0, 0), 'neck': (-4, 0, 0),
                'head': (6 + twitch(t, 8, 34), twitch(t, 9, 44), 20 * S(p) + twitch(t, 10, 40)),
                'upperarm.L': (-12 - 6 * S(p), 0, -10), 'upperarm.R': (-14 - 6 * S(p + 1), 0, 10), 'forearm.L': (-20, 0, 0), 'forearm.R': (-26, 0, 0),
                'thigh.L': (0, 0, 0), 'thigh.R': (0, 0, 0), 'shin.L': (4, 0, 0), 'shin.R': (4, 0, 0)}
    def crawl(t):
        p = t * P
        return {'hips:loc': Vector((0, -.62, -.25)), 'hips': (-82, 4 * S(p), 6 * S(p)), 'spine': (-6, 0, 6 * S(p)), 'chest': (-6, 0, 0), 'neck': (40, 0, 0),
                'head': (34 + twitch(t, 11, 20), twitch(t, 12, 30), twitch(t, 13, 30)),
                'upperarm.L': (-150 + 40 * S(p), 0, -16), 'upperarm.R': (-150 - 40 * S(p), 0, 16),
                'forearm.L': (-30 + 30 * max(0., S(p)), 0, 0), 'forearm.R': (-30 + 30 * max(0., -S(p)), 0, 0),
                'thigh.L': (10 + 14 * S(p), 0, -8), 'thigh.R': (10 - 14 * S(p), 0, 8), 'shin.L': (30, 0, 0), 'shin.R': (30, 0, 0)}
    acts = [pose_action(arm, 'Idle', 2.4, idle), pose_action(arm, 'Walk', 1.1, walk), pose_action(arm, 'Run', .62, run),
            pose_action(arm, 'Attack', .9, attack, False), pose_action(arm, 'Hit', .36, hit, False),
            pose_action(arm, 'Death', 1.5, death, False), pose_action(arm, 'Crawl', 1.3, crawl)]
    return acts


def rig_and_export(kind, torso, arms, legs, head_parts):
    spec = bones_spec()
    head = join(head_parts, 'HeadMesh')
    for o in [torso, head] + arms + legs: apply_location(o)
    centre = ['hips', 'spine', 'chest', 'neck']
    weigh(head, ['head', 'neck'], spec, 2, 6.)
    weigh(torso, centre + ['thigh.L', 'thigh.R', 'shoulder.L', 'shoulder.R', 'upperarm.L', 'upperarm.R'], spec, 3, 4.)
    for o, side in zip(arms, ('L', 'R')): weigh(o, [f'shoulder.{side}', f'upperarm.{side}', f'forearm.{side}', f'hand.{side}', 'chest'], spec, 2, 5.)
    for o, side in zip(legs, ('L', 'R')): weigh(o, [f'thigh.{side}', f'shin.{side}', f'foot.{side}', 'hips'], spec, 2, 5.)
    mesh = join([torso, head] + arms + legs, 'PartyZombieMesh')
    data = bpy.data.armatures.new('PartyZombieSkeleton'); arm = bpy.data.objects.new('PartyZombie', data); bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm; bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, h, t, parent in spec:
        b = data.edit_bones.new(name); b.head = Vector(h); b.tail = Vector(t); b.roll = 0.
        if parent: b.parent = data.edit_bones[parent]
        b.use_deform = name != 'root'
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.parent = arm
    mod = mesh.modifiers.new('Skin', 'ARMATURE'); mod.object = arm
    bpy.ops.object.mode_set(mode='POSE') if False else None
    make_actions(arm)
    arm.animation_data.action = bpy.data.actions['Walk']
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ART / (kind + '.glb')), export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_skins=True, export_apply=False, export_cameras=False, export_lights=False)
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print('RIGGED', kind, tris, 'tris', len(spec), 'bones', flush=True)
    return {kind: tris}


exec(compile(source, 'party-zombie-v500', 'exec'))
OUT = ART
for kind in ('party-zombie', 'party-zombie-b'):
    build_party(kind)
