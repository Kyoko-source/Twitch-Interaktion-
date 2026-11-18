"""Cinema, washroom and popcorn cart upgrade, After Play 4.13.0.

cinema-seat.glb / cinema-seat-torn.glb: a tip-up cinema seat with cast-iron
side standards, wooden arm pads, a padded seat cushion with a rolled front, a
channel-tufted back on a dark shell and hinge brackets; the torn variant has a
split cushion with yellow foam pushing out.
child-toilet.glb: a children's porcelain toilet: lathed pedestal and bowl, a
limescale ring at the water line, faded teal seat, upright lid, rounded tank
with lid and chrome lever.
washbasin.glb / washbasin-cracked.glb: a wall-hung porcelain basin with a deck,
chrome pillar tap with cross handles, drain and P-trap; rust stain at the
drain, the second one cracked.
soap-dispenser.glb: wall soap dispenser, white case, smoked window with pink
soap inside, push bar.
popcorn-cart.glb: red popcorn wagon with two spoked wheels, push handle,
drawer apron with gold pinstripe, glass cabinet, copper kettle under a domed
roof with a gold finial; the old label and the popcorn heap stay in the game.
(cubicle-graffiti.png comes from tools/make-after-play-cubicle-graffiti-v4130.py)

Run: blender -b --python tools/model-after-play-annex-v4130.py   (Blender 5.0)
Output: games/kinderparadies/assets/annex-v4130/
Godot local (x, y, z) = Blender (x, -z, y).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/annex-v4130'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4130)
parts = []

def G(x, y, z): return Vector((x, -z, y))

def reset():
    global parts
    bpy.ops.wm.read_factory_settings(use_empty=True); parts = []

def material(name, color, rough=.5, metal=0., image=None):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if image:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = image; nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    return m

def finish(o, mat, smooth=True):
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth = smooth
    parts.append(o); return o

def apply(o, kind, **kw):
    m = o.modifiers.new('m', kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.context.view_layer.objects.active = o; bpy.ops.object.modifier_apply(modifier='m')

def box(c, s, mat, bev=.004, seg=2, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=G(*c), rotation=rot); o = bpy.context.object
    o.scale = (s[0], s[2], s[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev: apply(o, 'BEVEL', width=bev, segments=seg)
    return finish(o, mat, seg > 2)

def cyl(c, r, d, mat, axis='y', verts=24, r2=None):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=G(*c), rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d, location=G(*c), rotation=rot)
    return finish(bpy.context.object, mat)

def ball(c, r, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=G(*c)); o = bpy.context.object
    o.scale = (scale[0], scale[2], scale[1]); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); return finish(o, mat)

def tube(points, r, mat, cyclic=False):
    cu = bpy.data.curves.new('c', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(points) - 1); sp.use_cyclic_u = cyclic
    for p, q in zip(sp.points, points): p.co = (*G(*q), 1)
    ob = bpy.data.objects.new('c', cu); bpy.context.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); bpy.data.objects.remove(ob)
    o = bpy.data.objects.new('tube', me); bpy.context.collection.objects.link(o); return finish(o, mat)

def lathe(profile, center, mat, zscale=1., segs=48):
    """profile: (radius, height) pairs, revolved around the Godot Y axis."""
    bm = bmesh.new(); rings = []
    for k in range(segs):
        a = k / segs * math.tau
        rings.append([bm.verts.new(G(center[0] + math.cos(a) * r, center[1] + h, center[2] + math.sin(a) * r * zscale)) for r, h in profile])
    uv = bm.loops.layers.uv.new()
    for k in range(segs):
        r1, r2 = rings[k], rings[(k + 1) % segs]
        for i in range(len(profile) - 1):
            try:
                f = bm.faces.new((r1[i], r1[i + 1], r2[i + 1], r2[i]))
                for loop, (u, v) in zip(f.loops, ((k, i), (k, i + 1), (k + 1, i + 1), (k + 1, i))):
                    loop[uv].uv = (u / segs, v / (len(profile) - 1))
            except ValueError: pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('lathe'); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('lathe', me); bpy.context.collection.objects.link(o); return finish(o, mat)

def save(name, img):
    h, w = img.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    im.pixels.foreach_set(np.flipud(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], 2)).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / f'{name}.png'); im.file_format = 'PNG'; im.save(); return im

def export(name):
    for o in bpy.data.objects: o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / name), export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print(name, sum(len(o.data.polygons) for o in parts), 'faces')

def place_local(objs, pivot, rot_x):
    """Rotate objects built around the origin by rot_x (Godot X) and move to pivot."""
    e = Euler((rot_x, 0, 0))
    for o in objs:
        me = o.data; me.transform(e.to_matrix().to_4x4()); me.update()
        o.location = G(*pivot)

# ---------------------------------------------------------------- cinema seat
def cinema_seat(torn):
    reset()
    velvet = material('SeatVelvet', (.47, .16, .2), .95)
    iron = material('SeatIron', (.06, .06, .065), .55, .6)
    wood = material('SeatArmWood', (.22, .12, .07), .5)
    shell = material('SeatShell', (.08, .07, .07), .6)
    for x in (-.40, .40):
        prof = [(-.33, 0), (.27, 0), (.27, .05), (.2, .1), (.19, .6), (.25, .66), (.25, .70), (-.3, .70), (-.33, .62), (-.3, .12)]
        bm = bmesh.new(); vs = [bm.verts.new(G(x - .02, h, z)) for z, h in prof]; f = bm.faces.new(vs)
        r = bmesh.ops.extrude_face_region(bm, geom=[f]); bmesh.ops.translate(bm, verts=[e for e in r['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(.04, 0, 0))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces); me = bpy.data.meshes.new('std'); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new('Standard', me); bpy.context.collection.objects.link(o); apply(o, 'BEVEL', width=.008, segments=2); finish(o, iron, False)
        box((x, .715, -.02), (.075, .03, .56), wood, .012, 3)
        box((x * .9, .45, -.06), (.02, .08, .1), iron, .003)
    box((0, .48, .03), (.6, .13, .56), velvet, .05, 5)
    cyl((0, .48, .3), .065, .6, velvet, 'x', 24)
    if torn:
        # Split cushion: ragged foam lumps pushing out between curled fabric flaps.
        foam = material('SeatFoam', (.74, .6, .3), .95)
        tex = bpy.data.textures.new('foam', 'CLOUDS'); tex.noise_scale = .012
        for k, (dx, dz, r) in enumerate(((.08, .06, .045), (.13, .1, .035), (.05, .13, .03), (.15, .03, .028))):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=G(dx, .54, dz)); o = bpy.context.object
            o.scale = (r, r * .9, r * .55); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            apply(o, 'DISPLACE', texture=tex, strength=.012); finish(o, foam)
        for s, ang in ((-1, .5), (1, -.6)):
            box((.1 + s * .06, .552, .08), (.02, .006, .2), velvet, .002, 2, rot=(0, s * ang, .25))
    back = [box((0, 0, .02), (.6, .78, .1), velvet, .045, 5), box((0, 0, -.045), (.63, .81, .05), shell, .015, 3)]
    for x in (-.1, .1): back.append(box((x, .02, .072), (.012, .66, .01), shell, .003, 2))
    place_local(back, (0, .87, -.27), .12)
    export('cinema-seat-torn.glb' if torn else 'cinema-seat.glb')

# ---------------------------------------------------------------- washroom
def stain_image(cracked):
    h, w = 256, 512; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.ones((h, w, 3), np.float32) * np.array([.88, .88, .84]); v = yy / h
    img *= (.97 + .03 * rng.random((h, w, 1)))
    rust = np.clip((v - .72) / .28, 0, 1) * (.5 + .5 * np.sin(xx / w * math.tau * 3 + 1)) ** 4
    img = img * (1 - rust[..., None] * .6) + np.array([.45, .25, .1]) * rust[..., None] * .6
    if cracked:
        for _ in range(3):
            x, y = rng.uniform(0, w), rng.uniform(h * .1, h * .5); a = rng.uniform(.6, 2.4)
            for t in range(160):
                a += rng.normal(0, .25); x += math.cos(a); y += abs(math.sin(a)) + .3
                ix, iy = int(x) % w, int(y)
                if iy >= h: break
                img[iy, max(ix - 1, 0):ix + 1] = np.array([.25, .22, .18])
    return img

def toilet():
    reset()
    porcelain = material('Porcelain', (.9, .9, .86), .12)
    scale = material('Limescale', (.55, .48, .32), .7)
    water = material('ToiletWater', (.15, .2, .16), .02)
    seat = material('ToiletSeat', (.35, .55, .52), .35)
    chrome = material('WashChrome', (.8, .8, .82), .15, 1.)
    prof = [(.15, 0), (.155, .015), (.13, .06), (.12, .18), (.17, .30), (.225, .38), (.24, .41), (.235, .425), (.205, .425), (.18, .40), (.12, .32), (.07, .25), (.045, .2), (0, .2)]
    lathe(prof, (0, 0, -.02), porcelain, 1.28)
    cyl((0, .245, -.02), .075, .004, water, verts=32).scale = (1, 1.28, 1)
    bpy.ops.mesh.primitive_torus_add(major_radius=.078, minor_radius=.005, location=G(0, .25, -.02)); t = bpy.context.object; t.scale = (1, 1.28, 1); finish(t, scale)
    bpy.ops.mesh.primitive_torus_add(major_radius=.19, minor_radius=.028, major_segments=48, minor_segments=12, location=G(0, .44, -.02)); t = bpy.context.object
    t.scale = (1, 1.28, .4); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); finish(t, seat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.2, depth=.02, location=G(0, .66, .16), rotation=(math.radians(-82), 0, 0)); lid = bpy.context.object
    lid.scale = (1, 1.25, 1); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); finish(lid, seat)
    for x in (-.1, .1): cyl((x, .45, .15), .018, .05, seat, 'x', 16)
    box((0, .62, .28), (.46, .48, .18), porcelain, .04, 4)
    box((0, .875, .28), (.5, .035, .21), porcelain, .015, 3)
    tube([(-.2, .78, .18), (-.26, .78, .16), (-.26, .76, .12)], .008, chrome)
    cyl((-.2, .78, .19), .022, .02, chrome, 'z', 20)
    for x in (-.13, .13): ball((x, .015, .12), .022, porcelain, (1, .6, 1))
    export('child-toilet.glb')

def basin(cracked):
    reset()
    porcelain = material('BasinPorcelain', (1, 1, 1), .12, image=save('basin-cracked' if cracked else 'basin', stain_image(cracked)))
    chrome = material('WashChrome', (.8, .8, .82), .15, 1.)
    dark = material('BasinDark', (.05, .05, .05), .6)
    prof = [(.12, .56), (.2, .6), (.27, .69), (.285, .725), (.28, .742), (.255, .742), (.245, .715), (.2, .655), (.1, .605), (.03, .588), (0, .588)]
    lathe(prof, (0, 0, 0), porcelain, .78)
    box((0, .705, -.27), (.5, .075, .14), porcelain, .02, 3)
    cyl((0, .748, -.18), .03, .01, chrome, verts=24)
    tube([(0, .75, -.18), (0, .9, -.18), (0, .93, -.15), (0, .925, -.07), (0, .89, -.03)], .013, chrome)
    for x in (-.08, .08):
        cyl((x, .755, -.18), .016, .03, chrome, verts=16)
        for a in range(4):
            ang = a * math.pi / 2 + .4
            tube([(x, .78, -.18), (x + math.cos(ang) * .035, .785, -.18 + math.sin(ang) * .035)], .005, chrome)
        ball((x, .785, -.18), .01, chrome)
    cyl((0, .589, 0), .026, .004, chrome, verts=24)
    cyl((0, .589, 0), .012, .005, dark, verts=16)
    tube([(0, .58, 0), (0, .4, 0), (0, .34, -.04), (0, .36, -.1), (0, .38, -.12), (0, .38, -.42)], .02, chrome)
    export('washbasin-cracked.glb' if cracked else 'washbasin.glb')

def soap():
    reset()
    case = material('SoapCase', (.88, .87, .82), .35)
    smoke = material('SoapWindow', (.15, .14, .15), .1)
    pink = material('SoapPink', (.85, .45, .55), .3)
    grey = material('SoapPush', (.55, .56, .57), .4)
    box((0, 0, 0), (.2, .32, .12), case, .03, 4)
    box((0, .02, .061), (.06, .18, .004), smoke, .002)
    box((0, -.03, .055), (.05, .08, .004), pink, 0)
    box((0, -.13, .06), (.16, .05, .03), grey, .01, 3)
    cyl((0, -.17, .03), .006, .02, grey, verts=12)
    ball((0, -.185, .03), .006, pink)
    cyl((0, .16, 0), .008, .005, grey, verts=12)
    export('soap-dispenser.glb')

# ---------------------------------------------------------------- popcorn cart
def popcorn_cart():
    reset()
    red = material('CartRed', (.62, .16, .13), .45, .1)
    gold = material('CartGold', (.85, .65, .28), .3, .9)
    steel = material('CartSteel', (.75, .76, .76), .3, .9)
    glass = material('CartGlass', (.8, .85, .85), .05)
    copper = material('CartCopper', (.75, .42, .25), .3, .95)
    black = material('CartBlack', (.04, .04, .04), .7)
    box((0, .25, 0), (.86, .04, .58), steel, .006, 2)
    box((0, .83, 0), (.9, .05, .62), red, .01, 3)
    box((0, .94, 0), (.86, .17, .58), red, .015, 3)
    box((0, .94, .292), (.8, .006, .004), gold, 0); box((0, .88, .292), (.8, .004, .004), gold, 0)
    ball((0, .94, .3), .016, gold)
    for x in (-.37, .37):
        for z in (-.22, .22): cyl((x, .54, z), .016, .58, steel, verts=12)
    for x in (-.5, .5):
        bpy.ops.mesh.primitive_torus_add(major_radius=.25, minor_radius=.018, major_segments=48, minor_segments=8, location=G(x, .27, -.1), rotation=(0, math.pi / 2, 0)); finish(bpy.context.object, red)
        cyl((x, .27, -.1), .25, .012, black, 'x', 48).scale = (1, 1, 1)
        bpy.data.objects.remove(parts.pop())
        cyl((x, .27, -.1), .04, .07, gold, 'x', 20)
        for k in range(10):
            a = k / 10 * math.tau; tube([(x, .27, -.1), (x, .27 + math.sin(a) * .24, -.1 + math.cos(a) * .24)], .007, red)
        bpy.ops.mesh.primitive_torus_add(major_radius=.262, minor_radius=.012, major_segments=48, minor_segments=8, location=G(x, .27, -.1), rotation=(0, math.pi / 2, 0)); finish(bpy.context.object, black)
    cyl((0, .27, -.1), .015, 1.0, steel, 'x', 12)
    for x in (-.32, .32): cyl((x, .1, .22), .02, .2, steel, verts=12)
    tube([(-.3, .86, -.31), (-.3, .9, -.45), (-.3, 1.0, -.52), (.3, 1.0, -.52), (.3, .9, -.45), (.3, .86, -.31)], .014, steel)
    box((0, 1.035, 0), (.84, .02, .56), steel, .004)
    for x in (-.42, .42):
        for z in (-.28, .28): box((x, 1.22, z), (.03, .38, .03), red, .006)
        box((x, 1.22, 0), (.006, .37, .53), glass, 0)
    for z in (-.28, .28): box((0, 1.22, z), (.81, .37, .006), glass, 0)
    box((0, 1.47, 0), (.92, .12, .65), red, .02, 3)
    box((0, 1.405, 0), (.94, .012, .67), gold, .003)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1, location=G(0, 1.53, 0)); dome = bpy.context.object
    dome.scale = (.42, .3, .14); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new(); bm.from_mesh(dome.data); bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -.001], context='VERTS'); bm.to_mesh(dome.data); bm.free(); finish(dome, red)
    cyl((0, 1.7, 0), .012, .06, gold, verts=12); ball((0, 1.75, 0), .03, gold)
    lathe([(.0, 1.2), (.1, 1.2), (.12, 1.22), (.12, 1.32), (.13, 1.33), (.0, 1.33)], (0, 0, 0), copper)
    tube([(0, 1.33, 0), (0, 1.41, 0)], .008, steel)
    for s in (-1, 1): tube([(s * .12, 1.3, 0), (s * .16, 1.3, 0), (s * .16, 1.26, 0)], .006, black)
    export('popcorn-cart.glb')

cinema_seat(False); cinema_seat(True)
toilet(); basin(False); basin(True); soap(); popcorn_cart()
