"""Rigs and animates the owner's generated party child avatar, After Play 5.1.0.

Input: the image-to-3D GLB the owner made from the reference picture (one
textured mesh in a lunging pose). It is turned to face forward, scaled to a
1.45 m child, given a 20-bone skeleton placed on its joints, skinned with
automatic weights (distance blend as fallback) and animated with Idle, Walk,
Run, Attack, Hit, Death and Crawl. Rotations are authored around the
armature's axes and converted to each bone's rest frame, so "leg forward"
means forward whatever the rest pose.

Run: blender -b --python tools/rig-after-play-party-avatar-v510.py -- <avatar.glb>
Output: games/kinderparadies/assets/zombies-v510/party-avatar.glb
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/zombies-v510'
SRC = sys.argv[sys.argv.index('--') + 1]
HEIGHT = 1.45

# Joints in the normalised pose (x right, -y forward, z up), metres.
J = {
    'pelvis': (0, .02, .62), 'spine': (0, .0, .78), 'chest': (0, -.01, .92), 'neck': (0, -.04, 1.0), 'head': (-.01, -.07, 1.07), 'crown': (-.02, -.06, 1.32),
    'shoulder.L': (-.12, -.02, .98), 'elbow.L': (-.18, -.22, .9), 'wrist.L': (-.24, -.38, .86), 'tip.L': (-.27, -.55, .88),
    'shoulder.R': (.12, .05, .98), 'elbow.R': (.17, .3, .86), 'wrist.R': (.21, .42, .76), 'tip.R': (.27, .46, .62),
    'hip.L': (-.07, .0, .62), 'knee.L': (-.12, -.18, .42), 'ankle.L': (-.18, -.38, .14), 'toe.L': (-.22, -.5, .03),
    'hip.R': (.06, .02, .62), 'knee.R': (.04, .27, .35), 'ankle.R': (.07, .5, .12), 'toe.R': (.1, .4, .03),
}
BONES = [('root', (0, 0, 0), (0, 0, .15), None), ('hips', J['pelvis'], J['spine'], 'root'), ('spine', J['spine'], J['chest'], 'hips'),
         ('chest', J['chest'], J['neck'], 'spine'), ('neck', J['neck'], J['head'], 'chest'), ('head', J['head'], J['crown'], 'neck')]
for s in ('L', 'R'):
    BONES += [(f'shoulder.{s}', J['chest'], J[f'shoulder.{s}'], 'chest'), (f'upperarm.{s}', J[f'shoulder.{s}'], J[f'elbow.{s}'], f'shoulder.{s}'),
              (f'forearm.{s}', J[f'elbow.{s}'], J[f'wrist.{s}'], f'upperarm.{s}'), (f'hand.{s}', J[f'wrist.{s}'], J[f'tip.{s}'], f'forearm.{s}'),
              (f'thigh.{s}', J[f'hip.{s}'], J[f'knee.{s}'], 'hips'), (f'shin.{s}', J[f'knee.{s}'], J[f'ankle.{s}'], f'thigh.{s}'),
              (f'foot.{s}', J[f'ankle.{s}'], J[f'toe.{s}'], f'shin.{s}')]


def load_mesh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
    for x in list(bpy.data.objects):
        if x is not o: bpy.data.objects.remove(x)
    o.parent = None; o.rotation_mode = 'XYZ'; o.rotation_euler = (0, 0, math.radians(-90)); bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for v in o.data.vertices: lo = Vector(map(min, lo, v.co)); hi = Vector(map(max, hi, v.co))
    s = HEIGHT / (hi.z - lo.z)
    for v in o.data.vertices: v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * s, (v.co.y - (lo.y + hi.y) / 2) * s, (v.co.z - lo.z) * s))
    o.name = 'PartyAvatarMesh'
    for p in o.data.polygons: p.use_smooth = True
    return o


def seg_dist(p, a, b):
    ab = b - a; t = max(0., min(1., (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def distance_weights(o):
    segs = {n: (Vector(h), Vector(t)) for n, h, t, _ in BONES if n != 'root'}
    groups = {n: o.vertex_groups.get(n) or o.vertex_groups.new(name=n) for n in segs}
    for v in o.data.vertices:
        scored = sorted(((1. / (seg_dist(v.co, *segs[n]) + .015) ** 5, n) for n in segs), reverse=True)[:3]
        total = sum(s for s, _ in scored)
        for s, n in scored: groups[n].add([v.index], s / total, 'REPLACE')


def build_armature(mesh):
    data = bpy.data.armatures.new('PartyAvatarSkeleton'); arm = bpy.data.objects.new('PartyZombie', data); bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for name, h, t, parent in BONES:
        b = data.edit_bones.new(name); b.head = Vector(h); b.tail = Vector(t)
        if parent: b.parent = data.edit_bones[parent]
        b.use_deform = name != 'root'
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        empty = sum(1 for v in mesh.data.vertices if not v.groups)
        print('AUTO WEIGHTS, unweighted verts:', empty)
        if empty > len(mesh.data.vertices) * .02: raise RuntimeError('bone heat left too many vertices')
    except Exception as e:
        print('FALLBACK distance weights:', e)
        for g in list(mesh.vertex_groups): mesh.vertex_groups.remove(g)
        distance_weights(mesh)
        if not mesh.parent: mesh.parent = arm
        if not mesh.modifiers.get('Armature'):
            m = mesh.modifiers.new('Armature', 'ARMATURE'); m.object = arm
    return arm


FPS = 30

def to_local(arm, bone, euler_deg):
    """Rotation authored around armature axes, expressed in the bone's rest frame."""
    rest = arm.data.bones[bone].matrix_local.to_quaternion()
    q = Euler([math.radians(a) for a in euler_deg], 'XYZ').to_quaternion()
    return rest.inverted() @ q @ rest


def loc_local(arm, bone, offset):
    rest = arm.data.bones[bone].matrix_local.to_quaternion()
    return rest.inverted() @ Vector(offset)


def action(arm, name, length, pose, loop=True, step=2):
    act = bpy.data.actions.new(name); act.use_fake_user = True
    arm.animation_data_create(); arm.animation_data.action = act
    frames = int(round(length * FPS))
    for f in list(range(0, frames, step)) + [frames]:
        t = f / frames
        for key, value in pose(t % 1. if loop else t).items():
            if key.endswith(':loc'):
                pb = arm.pose.bones[key[:-4]]; pb.location = loc_local(arm, key[:-4], value); pb.keyframe_insert('location', frame=f + 1)
            else:
                pb = arm.pose.bones[key]; pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = to_local(arm, key, value); pb.keyframe_insert('rotation_quaternion', frame=f + 1)


def twitch(t, seed, amount):
    k = int(t * 9 + seed * 3.7); return ((math.sin(k * 12.9898 + seed) * 43758.5453) % 1. - .5) * amount


def animate(arm):
    S = math.sin; P = math.tau
    # Forward is -Y: swinging a hanging limb forward is a negative X rotation.
    def walk(t):
        p = t * P
        return {'hips:loc': (0, 0, abs(S(p)) * .025), 'hips': (0, 4 * S(p), 6 * S(p)), 'spine': (4, 0, -4 * S(p)), 'chest': (2 * S(2 * p), 0, 0),
                'head': (twitch(t, 1, 20), twitch(t, 2, 26) + 10 * S(p * .5), twitch(t, 3, 22)),
                'thigh.L': (16 + 22 * S(p), 0, 0), 'thigh.R': (-14 - 22 * S(p), 0, 0),
                'shin.L': (14 * max(0., S(p + 1.6)), 0, 0), 'shin.R': (18 * max(0., S(p + 1.6 + math.pi)), 0, 0),
                'upperarm.L': (6 * S(p + 1), 0, 4 * S(p)), 'upperarm.R': (-40 - 6 * S(p), 0, 0), 'forearm.R': (-20, 0, 0)}
    def run(t):
        p = t * P
        return {'hips:loc': (0, 0, abs(S(p)) * .05 - .02), 'hips': (-12, 6 * S(p), 8 * S(p)), 'spine': (-10, 0, -6 * S(p)), 'chest': (-6, 0, 0),
                'head': (14 + twitch(t, 4, 16), twitch(t, 5, 20), twitch(t, 6, 24)),
                'thigh.L': (24 + 36 * S(p), 0, 0), 'thigh.R': (-22 - 36 * S(p), 0, 0),
                'shin.L': (40 * max(0., S(p + 1.4)), 0, 0), 'shin.R': (40 * max(0., S(p + 1.4 + math.pi)), 0, 0),
                'upperarm.L': (18 * S(p), 0, 0), 'upperarm.R': (-60 - 24 * S(p), 0, 0), 'forearm.R': (-30, 0, 0)}
    def attack(t):
        # Overhead claw: rear back, both arms high, lunge and rake down.
        lift = math.sin(min(t / .4, 1.) * math.pi * .5); slash = max(0., min((t - .4) / .16, 1.)); back = max(0., (t - .72) / .28)
        k = (1 - back)
        return {'hips:loc': (0, (.06 * lift - .3 * slash) * k, -.05 * slash * k), 'hips': ((8 * lift - 22 * slash) * k, 0, 0),
                'spine': ((18 * lift - 42 * slash) * k, 0, 0), 'chest': ((8 * lift - 18 * slash) * k, 0, 0), 'head': ((20 * lift - 14 * slash) * k, twitch(t, 7, 16), 0),
                'thigh.L': (-22 * slash * k, 0, 0), 'shin.L': (26 * slash * k, 0, 0), 'thigh.R': (14 * slash * k, 0, 0),
                'upperarm.L': ((-150 * lift + 175 * slash) * k, 0, 18 * lift * k), 'forearm.L': ((-60 * lift + 50 * slash) * k, 0, 0),
                'upperarm.R': ((-175 * lift + 190 * slash) * k, 0, -18 * lift * k), 'forearm.R': ((-60 * lift + 50 * slash) * k, 0, 0)}
    def attack2(t):
        # Double swipe: left then right across the body, stepping in.
        a = math.sin(min(t / .3, 1.) * math.pi); b = math.sin(max(0., min((t - .3) / .32, 1.)) * math.pi); back = max(0., (t - .75) / .25); k = 1 - back
        step = min(t / .3, 1.) * k
        return {'hips:loc': (0, -.22 * step, 0), 'hips': (0, 0, (28 * a - 28 * b) * k), 'spine': (-18 * step, 0, (22 * a - 22 * b) * k), 'head': (-10 * step, twitch(t, 14, 20), (-14 * a + 14 * b) * k),
                'thigh.L': (-18 * step, 0, 0), 'shin.L': (18 * step, 0, 0),
                'upperarm.L': ((-80 * a - 10) * k, (-50 * a) * k, (-60 * a) * k), 'forearm.L': (-30 * a * k, 0, 0),
                'upperarm.R': ((-80 * b - 40) * k, (50 * b) * k, (60 * b) * k), 'forearm.R': (-30 * b * k, 0, 0)}
    def hit(t):
        k = math.sin(min(t / .3, 1.) * math.pi) * (1 - t)
        return {'spine': (24 * k, 0, 10 * k), 'chest': (12 * k, 0, 0), 'head': (28 * k, 16 * k, 0), 'upperarm.L': (30 * k, 0, 0), 'upperarm.R': (30 * k, 0, 0)}
    def death(t):
        buckle = min(t / .35, 1.); fall = max(0., min((t - .25) / .45, 1.)) ** 1.6; settle = max(0., (t - .7) / .3)
        return {'hips:loc': (0, .25 * fall, -.12 * buckle - .42 * fall), 'hips': (75 * fall, 0, 14 * fall), 'spine': (14 * fall, 0, 0), 'neck': (20 * fall, 0, 18 * settle),
                'head': (22 * fall, 14 * settle, 26 * settle), 'thigh.L': (-30 * fall, 0, 0), 'thigh.R': (-40 * fall, 0, 0),
                'shin.L': (-50 * buckle + 30 * fall, 0, 0), 'shin.R': (-40 * buckle + 20 * fall, 0, 0),
                'upperarm.L': (-90 * fall * (1 - settle) - 30 * settle, 0, -30 * fall), 'upperarm.R': (-70 * fall * (1 - settle) - 20 * settle, 0, 40 * fall)}
    def idle(t):
        p = t * P
        return {'spine': (3 * S(p), 0, 3 * S(p * .5)), 'head': (twitch(t, 8, 30), twitch(t, 9, 40) + 14 * S(p), twitch(t, 10, 34)),
                'upperarm.L': (4 * S(p), 0, 0), 'upperarm.R': (-4 * S(p + 1), 0, 0)}
    def crawl(t):
        p = t * P
        return {'hips:loc': (0, -.15, -.38), 'hips': (-70, 4 * S(p), 6 * S(p)), 'spine': (-6, 0, 6 * S(p)), 'neck': (30, 0, 0), 'head': (30 + twitch(t, 11, 18), twitch(t, 12, 24), 0),
                'upperarm.L': (-40 + 40 * S(p), 0, 0), 'upperarm.R': (-110 - 40 * S(p), 0, 0), 'forearm.L': (20 * max(0., S(p)), 0, 0), 'forearm.R': (20 * max(0., -S(p)), 0, 0),
                'thigh.L': (40 + 12 * S(p), 0, 0), 'thigh.R': (20 - 12 * S(p), 0, 0)}
    for name, length, fn, loop in (('Idle', 2.4, idle, True), ('Walk', 1.15, walk, True), ('Run', .64, run, True), ('Attack', .9, attack, False), ('Attack2', .9, attack2, False),
                                   ('Hit', .36, hit, False), ('Death', 1.5, death, False), ('Crawl', 1.3, crawl, True)):
        action(arm, name, length, fn, loop)


mesh = load_mesh()
arm = build_armature(mesh)
animate(arm)
arm.animation_data.action = bpy.data.actions['Idle']
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); mesh.select_set(True)
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'party-avatar.glb'), export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
print('AVATAR', len(mesh.data.polygons), 'faces', len(BONES), 'bones', flush=True)
