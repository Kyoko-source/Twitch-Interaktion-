"""Weapons and stations for the wave survival mode, After Play 5.0.0.

Eight weapon frames (the thirty guns are variants of these in the game):
pistol, revolver, smg, rifle, shotgun, lmg, sniper, rift. Each has a grip at
the origin, the barrel along -Z and a "Muzzle" marker at the tip. Materials:
GunMetal, GunPolymer, GunWood, GunAccent (tinted per weapon), RiftGlow.
Stations: perk-machine (cursed vending shrine, PerkGlow tinted per perk),
ammo-crate (military supply crate, CrateGlow), chaos-box (birthday gift box
with a separate "Lid", BoxGlow), flesh-machine (the upgrade grinder,
MachineGlow), fence-panel (2 m construction fence with feet and sign).

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b --python tools/model-after-play-zombies-gear-v500.py
Output: games/kinderparadies/assets/zombies-v500/
Godot local (x, y, z) = Blender (x, -z, y).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/zombies-v500'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(500)
parts = []

def G(x, y, z): return Vector((x, -z, y))

def reset():
    global parts
    bpy.ops.wm.read_factory_settings(use_empty=True); parts = []

def save(name, img):
    h, w = img.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.pixels.foreach_set(np.flipud(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], 2)).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save(); return im

def worn(name, base, rust=0., size=256):
    img = np.ones((size, size, 3)) * np.array(base)
    k = np.exp(-((np.fft.fftfreq(size)[:, None] ** 2 + np.fft.fftfreq(size)[None] ** 2) * 600))
    soft = np.real(np.fft.ifft2(np.fft.fft2(rng.random((size, size))) * k)); soft = (soft - soft.min()) / (np.ptp(soft) + 1e-6)
    img *= (.82 + .18 * soft[..., None])
    if rust:
        mask = (soft > 1 - rust)[..., None]
        img = np.where(mask, img * .4 + np.array([.32, .14, .06]) * .6, img)
    for _ in range(90):
        x, y = rng.integers(0, size, 2); ln = rng.integers(4, 24); a = rng.uniform(0, math.pi)
        for t in range(ln):
            ix, iy = int(x + math.cos(a) * t) % size, int(y + math.sin(a) * t) % size
            img[iy, ix] = np.minimum(1, img[iy, ix] * 1.4 + .05)
    return save(name, img)

def material(name, color, rough=.5, metal=0., image=None, emit=None, strength=3.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if image:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = image; m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if emit:
        b.inputs['Emission Color'].default_value = (*[c ** 2.2 for c in emit], 1); b.inputs['Emission Strength'].default_value = strength
    return m

def finish(o, mat, smooth=True, name=None):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = smooth
    if name: o.name = name
    parts.append(o); return o

def apply(o, kind, **kw):
    m = o.modifiers.new('m', kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='m')

def box(c, s, mat, bev=.002, seg=2, rot=(0, 0, 0), name=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(*c), rotation=rot); o = bpy.context.object
    o.scale = (s[0], s[2], s[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev: apply(o, 'BEVEL', width=bev, segments=seg)
    return finish(o, mat, seg > 2, name)

def cyl(c, r, d, mat, axis='z', verts=20, name=None, r2=None):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=G(*c), rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d, location=G(*c), rotation=rot)
    return finish(bpy.context.object, mat, True, name)

def ball(c, r, mat, name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=10, radius=r, location=G(*c)); return finish(bpy.context.object, mat, True, name)

def torus(c, r, t, mat, axis='z', name=None):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=t, location=G(*c), rotation=rot, major_segments=28, minor_segments=8)
    return finish(bpy.context.object, mat, True, name)

def marker(name, c):
    o = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(o); o.location = G(*c); parts.append(o); return o

def export(name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = [o for o in parts if o.type == 'MESH'][0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print('GEAR', name, sum(len(o.data.polygons) for o in parts if o.type == 'MESH'), 'faces', flush=True)

def gun_materials():
    return (material('GunMetal', (1, 1, 1), .38, .85, worn('gun-metal', (.17, .17, .18))),
            material('GunPolymer', (1, 1, 1), .7, .05, worn('gun-polymer', (.07, .07, .075))),
            material('GunWood', (1, 1, 1), .55, 0, worn('gun-wood', (.36, .2, .1))),
            material('GunAccent', (.55, .12, .14), .45, .4))

# ---------------------------------------------------------------- weapons
def pistol(revolver=False):
    reset(); metal, poly, wood, accent = gun_materials()
    if revolver:
        box((0, .045, -.06), (.03, .035, .12), metal, .004, 3)
        cyl((0, .05, -.21), .009, .2, metal, 'z'); box((0, .066, -.2), (.012, .012, .19), metal, .002)
        cyl((0, .03, -.075), .024, .045, metal, 'z', 12);
        for k in range(6):
            a = k / 6 * math.tau; cyl((math.cos(a) * .015, .03 + math.sin(a) * .015, -.098), .0055, .004, poly, 'z', 8)
        box((0, -.01, .02), (.03, .11, .05), wood, .008, 3, (math.radians(-18), 0, 0))
        box((0, .02, -.03), (.006, .03, .02), metal, .002); box((0, .072, -.3), (.004, .01, .008), accent, .001)
        marker('Muzzle', (0, .05, -.315))
    else:
        box((0, .055, -.075), (.032, .03, .19), metal, .004, 3)
        for k in range(8): box((0, .071, -.03 - k * .012), (.03, .002, .004), poly, .0005)
        box((0, .033, -.07), (.028, .02, .16), poly, .004, 3)
        box((0, -.015, .0), (.03, .1, .045), poly, .008, 3, (math.radians(-16), 0, 0))
        box((0, .01, -.035), (.006, .025, .03), metal, .002); box((0, .072, -.16), (.004, .006, .006), accent, .001)
        box((0, .02, -.12), (.034, .014, .05), accent, .002)
        marker('Muzzle', (0, .055, -.175))
    export('weapon-revolver.glb' if revolver else 'weapon-pistol.glb')

def long_gun(kind):
    reset(); metal, poly, wood, accent = gun_materials()
    glow = material('RiftGlow', (.2, 1., .45), .2, 0, None, (.25, 1., .5), 6.)
    L = {'smg': .42, 'rifle': .7, 'shotgun': .78, 'lmg': .85, 'sniper': .95, 'rift': .8}[kind]
    # Receiver, barrel, stock, grip, magazine, sights.
    box((0, .055, -.12), (.05, .07, .26 if kind != 'smg' else .2), metal, .006, 3)
    bl = L - .2
    if kind == 'shotgun':
        cyl((0, .07, -.25 - bl / 2), .013, bl, metal, 'z'); cyl((0, .045, -.25 - bl / 2 + .05), .012, bl - .1, metal, 'z')
        box((0, .04, -.38), (.04, .035, .16), wood, .008, 3)
    elif kind == 'rift':
        cyl((0, .06, -.32), .045, .3, metal, 'z', 24, None, .028)
        for k in range(4): torus((0, .06, -.2 - k * .08), .05 - k * .006, .008, glow, 'z', 'RiftRing%d' % k)
        ball((0, .06, -.5), .03, glow, 'RiftCore'); box((0, .1, -.12), (.03, .03, .18), glow, .004)
    else:
        cyl((0, .065, -.25 - bl / 2), .009 if kind != 'lmg' else .013, bl, metal, 'z')
        box((0, .065, -.28), (.04, .045, .2 if kind != 'smg' else .1), poly if kind != 'sniper' else wood, .006, 3)
        if kind == 'lmg':
            cyl((0, .065, -.3), .022, .22, poly, 'z', 14)
            for k in range(10): box((0, .09, -.22 - k * .02), (.046, .004, .006), metal, .001)
    # Stock.
    if kind in ('rifle', 'lmg', 'sniper', 'shotgun'):
        mat = wood if kind in ('shotgun', 'sniper') else poly
        box((0, .03, .14), (.04, .07, .22), mat, .01, 3, (math.radians(4), 0, 0))
        box((0, .03, .25), (.042, .1, .02), poly, .004)
    elif kind == 'smg':
        box((0, .05, .1), (.012, .012, .16), metal, .002); box((0, .03, .18), (.03, .07, .015), metal, .003)
    elif kind == 'rift':
        box((0, .04, .12), (.05, .08, .2), metal, .012, 3)
    # Grip and trigger guard.
    box((0, -.02, -.02), (.032, .1, .04), poly, .007, 3, (math.radians(-14), 0, 0))
    torus((0, .0, -.06), .022, .004, metal, 'x')
    # Magazines.
    if kind in ('smg', 'rifle'):
        box((0, -.04, -.11), (.028, .12, .045), accent if kind == 'smg' else poly, .005, 3, (math.radians(12), 0, 0))
    elif kind == 'lmg':
        box((.0, -.03, -.12), (.09, .09, .1), metal, .01, 3); box((.0, -.03, -.12), (.092, .02, .102), accent, .002)
    elif kind == 'sniper':
        box((0, -.02, -.1), (.026, .06, .06), metal, .004)
    # Optics or iron sights.
    if kind in ('sniper',):
        cyl((0, .12, -.16), .022, .3, poly, 'z'); cyl((0, .12, -.315), .028, .03, poly, 'z'); cyl((0, .12, -.005), .024, .025, poly, 'z')
        box((0, .095, -.12), (.012, .03, .02), metal); box((0, .095, -.2), (.012, .03, .02), metal)
    elif kind in ('rifle', 'lmg'):
        box((0, .1, -.1), (.035, .03, .08), poly, .004, 3); box((0, .118, -.1), (.02, .01, .05), accent, .002)
    else:
        box((0, .095, -.04), (.01, .015, .01), metal); box((0, .095, -L + .02), (.006, .02, .008), accent)
    # Accent band and bipod or heat shield.
    box((0, .065, -.2), (.054, .018, .03), accent, .003)
    if kind == 'lmg':
        for side in (-1, 1): box((side * .03, -.04, -L + .15), (.008, .14, .008), metal, .001, 2, (0, 0, side * .3))
    if kind == 'shotgun':
        for k in range(5): box((0, .088, -.3 - k * .07), (.022, .004, .03), metal, .001)
    marker('Muzzle', (0, .065 if kind != 'rift' else .06, -L + .01))
    export('weapon-%s.glb' % kind)

# ---------------------------------------------------------------- stations
def perk_machine():
    reset()
    body = material('PerkBody', (1, 1, 1), .55, .5, worn('perk-body', (.45, .43, .4), .35))
    dark = material('PerkDark', (.04, .04, .045), .5, .3)
    glow = material('PerkGlow', (.9, .3, .3), .3, 0, None, (1, .35, .3), 4.)
    glass = material('PerkGlass', (.05, .07, .07), .05, .2)
    chrome = material('PerkChrome', (.7, .7, .72), .25, .9)
    flesh = material('PerkFlesh', (.45, .12, .12), .6)
    box((0, .95, 0), (.9, 1.9, .7), body, .03, 3)
    box((0, 1.15, .352), (.62, .9, .02), dark, .01)
    box((0, 1.18, .365), (.54, .78, .01), glass, .004, 2, (0, 0, 0), 'PerkWindow')
    for k in range(3):
        for j in range(4): cyl((-.18 + j * .12, .86 + k * .25, .3), .025, .14, glow, 'y', 12, 'PerkBottle')
    box((0, 1.98, .02), (.94, .2, .72), dark, .02, 3)
    box((0, 1.98, .37), (.86, .14, .02), glow, .006, 2, (0, 0, 0), 'PerkSign')
    box((0, .45, .355), (.36, .1, .02), dark, .006); box((0, .45, .368), (.24, .04, .01), glow, .003)
    box((.33, .95, .36), (.08, .28, .03), chrome, .006); cyl((.33, 1.0, .385), .018, .02, glow, 'z', 12)
    # Organic growth seeping out of the seams.
    for k in range(7):
        x = rng.uniform(-.45, .45); y = rng.uniform(.2, 1.8); ball((x if abs(x) > .4 else math.copysign(.45, x), y, rng.uniform(-.3, .3)), rng.uniform(.04, .09), flesh)
    for x in (-.38, .38):
        for z in (-.28, .28): box((x, .02, z), (.1, .04, .1), dark, .006)
    export('perk-machine.glb')

def ammo_crate():
    reset()
    wood = material('CrateWood', (1, 1, 1), .75, 0, worn('crate-wood', (.27, .3, .17)))
    metal = material('CrateMetal', (.25, .26, .24), .45, .8)
    glow = material('CrateGlow', (.9, .7, .2), .3, 0, None, (1, .75, .25), 3.)
    shell = material('CrateBrass', (.75, .55, .22), .3, .9)
    box((0, .22, 0), (.9, .44, .55), wood, .015, 3)
    box((0, .47, 0), (.94, .06, .59), wood, .012, 3, (0, 0, 0), 'CrateLid')
    for x in (-.4, .4): box((x, .25, 0), (.05, .5, .6), metal, .005)
    for x in (-.25, .25): box((x, .3, .285), (.06, .08, .02), metal, .004)
    box((0, .2, .282), (.5, .05, .01), glow, .002, 2, (0, 0, 0), 'CrateStrip')
    for k in range(8): cyl((-.28 + k * .08, .55, -.05), .012, .1, shell, 'y', 10)
    export('ammo-crate.glb')

def chaos_box():
    reset()
    paper = material('GiftPaper', (1, 1, 1), .7, 0, worn('gift-paper', (.42, .12, .2), .2))
    ribbon = material('GiftRibbon', (.85, .7, .25), .35, .6)
    glow = material('BoxGlow', (.5, .1, 1.), .2, 0, None, (.6, .2, 1.), 5.)
    flesh = material('BoxFlesh', (.4, .08, .12), .55)
    box((0, .35, 0), (1.4, .7, .8), paper, .02, 3)
    box((0, .35, 0), (1.42, .72, .12), ribbon, .005); box((0, .35, 0), (.12, .72, .82), ribbon, .005)
    box((0, .66, 0), (1.3, .02, .7), glow, .002, 2, (0, 0, 0), 'BoxGlowPlane')
    lid = []
    lid.append(box((0, .76, 0), (1.46, .14, .86), paper, .02, 3))
    lid.append(box((0, .76, 0), (1.48, .15, .12), ribbon, .005)); lid.append(box((0, .76, 0), (.12, .15, .88), ribbon, .005))
    for side in (-1, 1): lid.append(torus((side * .1, .9, 0), .09, .025, ribbon, 'z'))
    # One lid mesh hinged at the back edge.
    bpy.ops.object.select_all(action='DESELECT')
    for o in lid: o.select_set(True)
    bpy.context.view_layer.objects.active = lid[0]; bpy.ops.object.join()
    joined = bpy.context.object; joined.name = 'Lid'
    for o in lid[1:]:
        if o in parts: parts.remove(o)
    bpy.context.scene.cursor.location = G(0, .7, -.43); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    for k in range(6):
        ball((rng.uniform(-.7, .7), rng.uniform(.05, .6), .41 * (1 if k % 2 else -1)), rng.uniform(.03, .07), flesh)
    export('chaos-box.glb')

def flesh_machine():
    reset()
    steel = material('GrinderSteel', (1, 1, 1), .45, .8, worn('grinder-steel', (.32, .33, .34), .4))
    dark = material('GrinderDark', (.05, .04, .04), .5, .3)
    meat = material('GrinderMeat', (.45, .08, .1), .45)
    glow = material('MachineGlow', (1, .2, .15), .2, 0, None, (1, .15, .1), 5.)
    box((0, .5, 0), (1.1, 1.0, .9), steel, .03, 3)
    cyl((0, 1.3, -.05), .42, .6, steel, 'y', 28, None, .22)
    cyl((0, 1.62, -.05), .44, .05, dark, 'y', 28)
    cyl((0, 1.02, .5), .16, .3, steel, 'z', 20); cyl((0, 1.02, .66), .19, .04, dark, 'z', 20)
    torus((0, 1.02, .69), .15, .02, glow, 'z', 'GrinderMouth')
    for k in range(5): ball((rng.uniform(-.3, .3), 1.62, rng.uniform(-.3, .2)), rng.uniform(.06, .12), meat)
    box((0, .55, .455), (.6, .3, .02), dark, .01); box((0, .55, .468), (.5, .2, .01), glow, .003, 2, (0, 0, 0), 'GrinderPanel')
    for x in (-.62, .62):
        cyl((x, 1.1, 0), .05, .9, steel, 'y'); cyl((x, 1.55, .2), .05, .5, steel, 'z')
    cyl((.4, .25, .5), .05, .25, dark, 'z'); box((-.5, .1, .5), (.08, .2, .08), dark)
    export('flesh-machine.glb')

def fence_panel():
    reset()
    steel = material('FenceSteel', (1, 1, 1), .4, .8, worn('fence-steel', (.55, .56, .55), .45))
    concrete = material('FenceFoot', (.42, .41, .38), .9)
    sign = material('FenceSign', (.9, .75, .12), .6)
    stripe = material('FenceStripe', (.75, .1, .08), .6)
    for x in (-.98, .98): cyl((x, .95, 0), .02, 1.9, steel, 'y', 12)
    for y in (.08, 1.88): cyl((0, y, 0), .018, 1.96, steel, 'x', 12)
    for k in range(25): cyl((-.96 + k * .08, .98, 0), .004, 1.8, steel, 'y', 6)
    for k in range(11): cyl((0, .15 + k * .17, 0), .004, 1.94, steel, 'x', 6)
    for x in (-.98, .98): box((x, .06, 0), (.22, .12, .5), concrete, .015, 3)
    box((0, 1.2, .03), (.5, .32, .008), sign, .004, 2, (0, 0, 0), 'FenceSign')
    for k in range(4): box((-.18 + k * .12, 1.06, .036), (.06, .03, .004), stripe, .001)
    export('fence-panel.glb')

pistol(False); pistol(True)
for kind in ('smg', 'rifle', 'shotgun', 'lmg', 'sniper', 'rift'): long_gun(kind)
perk_machine(); ammo_crate(); chaos_box(); flesh_machine(); fence_panel()
