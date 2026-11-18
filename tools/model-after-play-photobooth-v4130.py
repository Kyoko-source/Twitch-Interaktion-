"""Photo booth and token changer of the Happyland arcade, After Play 4.13.0.

photo-booth.glb: a 70s photo booth on the old footprint (1.62 x 2.39 x 1.32 m):
two-tone cabin (faded red lower body, cream upper body) with rounded edges, a
chrome belt line, a rounded roof cap, a dark kick plinth; the closed left front
holds a round camera window with the lens behind, a frosted flash panel, a
chrome coin validator and a photo output slot with tray; the open right side
shows a pleated grey backdrop and a round swivel stool. On the outer right
side hangs a framed panel of sample photo strips.
token-changer.glb: a red change machine: rounded steel cabinet, lit header
(the game's "JETONS" text stays), bill acceptor with a green lit mouth, coin
slot, instruction plate, key lock and a deep coin cup with a few tokens left.

Run: blender -b --python tools/model-after-play-photobooth-v4130.py   (Blender 5.0)
Output: games/kinderparadies/assets/booth-v4130/
Godot local (x, y, z) = Blender (x, -z, y); the front is Godot +Z.
"""
import math
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/kinderparadies/assets/booth-v4130'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4130)
parts = []

def G(x, y, z): return (x, -z, y)

def material(name, color, rough=.5, metal=0., image=None, emit=None, strength=2.):
    m = bpy.data.materials.new(name)
    if not m.node_tree: m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if image:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = image; nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    return m

def finish(o, mat, smooth=False):
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

def cyl(c, r, d, mat, axis='y', verts=32, r2=None):
    rot = {'y': (0, 0, 0), 'z': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0)}[axis]
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=G(*c), rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d, location=G(*c), rotation=rot)
    return finish(bpy.context.object, mat, True)

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

def sample_strips():
    # Four strips of four frames: pastel backdrops, a child's head-and-shoulder
    # silhouette in different poses, faded and yellowed behind old perspex.
    h, w = 512, 512; img = np.ones((h, w, 3), np.float32) * np.array([.12, .1, .09])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    pastel = [np.array(c) for c in ((.75, .62, .6), (.6, .7, .78), (.78, .74, .55), (.62, .74, .62))]
    for s in range(4):
        x0 = 28 + s * 122; img[16:496, x0:x0 + 100] = np.array([.93, .9, .82])
        for f in range(4):
            y0 = 24 + f * 118; fx, fy = x0 + 6, y0 + 4
            frame = (xx >= fx) & (xx < fx + 88) & (yy >= fy) & (yy < fy + 106)
            img[frame] = pastel[(s + f) % 4]
            cx = fx + 44 + rng.uniform(-8, 8); cy = fy + 46 + rng.uniform(-4, 6); tilt = rng.uniform(-.25, .25)
            head = ((xx - cx) * math.cos(tilt) + (yy - cy) * math.sin(tilt)) ** 2 / 17 ** 2 + ((yy - cy) * math.cos(tilt) - (xx - cx) * math.sin(tilt)) ** 2 / 21 ** 2 < 1
            body = (((xx - cx) / 36) ** 2 + ((yy - (fy + 112)) / 40) ** 2 < 1)
            img[frame & (head | body)] = np.array([.22, .18, .17])
    img = img * np.array([1., .95, .8]) * (.85 + .15 * rng.random((h, w, 1)))
    return img

# ---------------------------------------------------------------- photo booth
bpy.ops.wm.read_factory_settings(use_empty=True); parts = []
red = material('BoothRedEnamel', (.58, .2, .16), .45, .15)
cream = material('BoothCream', (.86, .8, .66), .5, .05)
chrome = material('BoothChrome', (.82, .82, .84), .16, 1.)
black = material('BoothBlack', (.03, .03, .035), .5)
glass = material('BoothCameraGlass', (.02, .03, .03), .05)
frost = material('BoothFlashFrost', (.92, .92, .9), .6, emit=(.9, .95, 1.), strength=.3)
backdrop = material('BoothBackdrop', (.45, .46, .47), .95)
vinyl = material('BoothStoolVinyl', (.55, .1, .08), .35)
strips = material('BoothSampleStrips', (1, 1, 1), .3, image=save('sample-strips', sample_strips()))
# Body: back, sides (lower red, upper cream), roof cap, plinth.
box((0, 1.21, -.60), (1.62, 2.22, .10), red, .02, 3)
for x in (-.77, .77):
    box((x, .66, 0), (.09, 1.12, 1.30), red, .03, 4)
    box((x, 1.77, 0), (.09, 1.10, 1.30), cream, .03, 4)
    box((x, 1.22, 0), (.1, .035, 1.31), chrome, .008, 3)
box((0, 2.33, 0), (1.70, .14, 1.38), cream, .05, 5)
box((0, 2.255, 0), (1.66, .025, 1.34), chrome, .008, 2)
box((0, .1, 0), (1.62, .20, 1.30), black, .015, 3)
# Closed left front: lower red, upper cream, chrome belt line.
box((-.44, .66, .63), (.76, 1.12, .07), red, .02, 3)
box((-.44, 1.77, .63), (.76, 1.10, .07), cream, .02, 3)
box((-.44, 1.22, .66), (.77, .035, .02), chrome, .006, 2)
# Camera window, lens and flash panel.
cyl((-.48, 1.47, .667), .11, .02, chrome, 'z', 40)
cyl((-.48, 1.47, .672), .092, .02, glass, 'z', 40)
cyl((-.48, 1.47, .62), .045, .08, black, 'z', 24)
cyl((-.48, 1.47, .655), .03, .01, material('BoothLensCoat', (.1, .15, .3), .05, .5), 'z', 24)
box((-.48, 1.86, .668), (.46, .14, .02), chrome, .006, 2)
box((-.48, 1.86, .675), (.42, .11, .01), frost, 0)
# Coin validator, buttons, photo output slot and tray.
box((-.48, 1.02, .668), (.24, .3, .02), chrome, .008, 3)
box((-.48, 1.1, .68), (.012, .06, .01), black, 0)
cyl((-.42, .95, .68), .018, .014, material('BoothReturnButton', (.75, .12, .1), .3), 'z', 20)
for x in (-.58, -.38): cyl((x, .79, .675), .024, .02, chrome, 'z', 20)
box((-.48, .55, .67), (.3, .04, .03), chrome, .006, 2)
box((-.48, .55, .688), (.22, .012, .01), black, 0)
box((-.48, .49, .72), (.3, .015, .1), chrome, .004, 2, rot=(math.radians(10), 0, 0))
# Interior: pleated backdrop and the round swivel stool.
for i in range(14):
    x = -.06 + i * .057
    box((x, 1.2, -.53 + (i % 2) * .018), (.06, 1.9, .012), backdrop, .004, 2, rot=(0, 0, (.35 if i % 2 else -.35)))
cyl((.28, .58, -.18), .2, .07, vinyl, 'y', 40)
cyl((.28, .545, -.18), .205, .015, chrome, 'y', 40)
cyl((.28, .37, -.18), .028, .32, chrome, 'y', 20)
cyl((.28, .215, -.18), .17, .02, chrome, 'y', 32)
# Sample photo strips panel on the outer right side (local +x).
box((.82, 1.5, .1), (.012, .62, .62), chrome, .004, 2)
bpy.ops.mesh.primitive_plane_add(size=1, location=G(.828, 1.5, .1), rotation=(math.pi / 2, 0, math.pi / 2)); pl = bpy.context.object
pl.scale = (.56, .56, 1); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); finish(pl, strips)
export('photo-booth.glb')

# ---------------------------------------------------------------- token changer
bpy.ops.wm.read_factory_settings(use_empty=True); parts = []
red = material('ChangerRed', (.6, .14, .12), .4, .2)
steel = material('ChangerSteel', (.75, .76, .76), .28, .9)
black = material('ChangerBlack', (.03, .03, .035), .5)
lit = material('ChangerHeader', (.95, .85, .55), .4, emit=(1., .82, .45), strength=.6)
green = material('ChangerBillLight', (.1, .6, .2), .3, emit=(.15, 1., .3), strength=2.)
gold = material('ChangerToken', (.8, .62, .25), .3, 1.)
plate = material('ChangerPlate', (.85, .82, .7), .5)
box((0, .73, 0), (.64, 1.46, .54), red, .04, 4)
box((0, 1.33, .265), (.56, .17, .02), lit, .006, 2)
box((0, 1.33, .258), (.6, .21, .01), steel, .004, 2)
box((0, 1.08, .28), (.5, .3, .02), steel, .008, 3)
for x in (-.14, .14): box((x, 1.09, .292), (.05, .12, .01), black, .002, 2)
box((-.14, 1.09, .296), (.04, .006, .006), green, 0)
cyl((.14, .93, .295), .03, .012, steel, 'z', 24); box((.14, .93, .302), (.006, .03, .004), black, 0)
box((-.12, .9, .292), (.18, .1, .006), plate, .002, 2)
for k in range(4): box((-.12, .925 - k * .02, .296), (.14, .004, .002), black, 0)
cyl((.2, .78, .29), .016, .012, steel, 'z', 20)
# Coin cup with a few tokens left.
box((0, .5, .29), (.42, .2, .08), black, .02, 3)
box((0, .41, .35), (.44, .03, .16), steel, .008, 3)
for i in range(4):
    cyl((-.08 + i * .05 + rng.uniform(-.01, .01), .43, .33 + rng.uniform(-.03, .03)), .016, .004, gold, 'y', 20)
box((0, .06, .2), (.62, .12, .14), black, .01, 2)
export('token-changer.glb')
