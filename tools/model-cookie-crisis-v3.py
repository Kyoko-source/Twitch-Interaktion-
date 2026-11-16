"""Santa's Cookie Crisis – asset pass 3 (Blender 4.5): the hero pieces of the bakery.

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b -P tools/model-cookie-crisis-v3.py
Writes games/cookie-crisis/assets/models/bakery.glb with named nodes:
  OvenTunnel      2.4 m riveted red conveyor oven: arched mouths, brass trims, viewing window,
                  portholes, pressure gauge, chimney pipe, red valve wheel (belt runs through at y=0)
  OvenGlow        the glowing inside (separate so the game can pulse it)
  ConveyorFrame   1 m belt section: red side rails with bolts, end rollers, legs to the floor (y 0 = belt top,
                  legs reach 1.18 m down)
  DoughBowl       red ceramic bowl with white snowflakes;  BowlDough  the dough inside (scaled by amount)
  CoinCrate       wooden crate with iron corners and a brass Schokotaler emblem
  Coin            one Schokotaler (gold, cookie relief)
  Lantern, Mug, CandyJar, FlourDust
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[1]
helper = ROOT / "tools/model-cookie-crisis-v1.py"
exec(compile(helper.read_text(encoding="utf-8").split("\nbuild_world()\n")[0], str(helper), "exec"), globals())
OUT = ROOT / "games/cookie-crisis/assets/models"


def arch_profile(w, h, r_seg=16):
    """Outline of an arched opening (width w, height h) in the x/y plane, counter-clockwise."""
    pts = [(-w / 2, 0)]
    r = w / 2
    base = h - r
    for i in range(r_seg + 1):
        a = math.pi - i * math.pi / r_seg
        pts.append((math.cos(a) * r, base + math.sin(a) * r))
    pts.append((w / 2, 0))
    return pts


def arch_ring(x, w, h, depth, thick, m):
    """A thick arched frame (brass or red) around an opening, facing ±x."""
    outer = arch_profile(w + thick * 2, h + thick)
    inner = arch_profile(w, h)
    verts, faces = [], []
    n = len(outer)
    for side in (-depth / 2, depth / 2):
        for (u, v) in outer:
            verts.append(gp((x + side, v, u)))
        for (u, v) in inner:
            verts.append(gp((x + side, v, u)))
    def idx(side, ring, i):
        return side * 2 * n + ring * n + i
    for side in (0, 1):
        for i in range(n - 1):
            faces.append((idx(side, 0, i), idx(side, 0, i + 1), idx(side, 1, i + 1), idx(side, 1, i)))
    for ring in (0, 1):
        for i in range(n - 1):
            faces.append((idx(0, ring, i), idx(0, ring, i + 1), idx(1, ring, i + 1), idx(1, ring, i)))
    mesh = bpy.data.meshes.new("arch"); mesh.from_pydata(verts, [], faces); mesh.update()
    o = bpy.data.objects.new("arch", mesh); bpy.context.collection.objects.link(o)
    return finish(o, m, smooth=False)


def rivets(p0, p1, n, m, r=.012, axis_offset=(0, 0, 0)):
    out = []
    for i in range(n):
        t = i / max(1, n - 1)
        p = tuple(p0[k] + (p1[k] - p0[k]) * t + axis_offset[k] for k in range(3))
        out.append(sphere(p, (r, r, r), m, 8, 6))
    return out


def build_bakery():
    clear(); M = materials()
    red = mat("Oven red enamel", (.55, .06, .05), .38, .25)
    redDark = mat("Oven red shadow", (.32, .04, .03), .5, .3)
    brass = mat("Brass", (.85, .6, .25), .28, .9)
    iron = M["iron"]
    glow = mat("Oven glow", (1.0, .55, .15), .4, emit=(1.0, .45, .08), strength=6)
    glassWarm = mat("Oven window", (1.0, .7, .35), .05, emit=(1.0, .5, .15), strength=1.5, alpha=.45)
    stone = mat("Base stone", (.45, .42, .4), .9)
    L, H, D = 2.4, .5, .56            # length (x), inner height, depth (z)
    oven = []
    # shell: roof + walls with a slight barrel top
    oven.append(box((0, H + .06, 0), (L, .12, D + .14), red, bevel=.03))
    oven.append(box((0, H + .14, 0), (L - .1, .06, D - .05), redDark, bevel=.02))
    oven.append(box((0, H / 2 + .02, -D / 2 - .05), (L, H + .1, .08), red, bevel=.02))
    # front: lower plate, brass band, viewing window, upper plate with portholes
    oven.append(box((0, .06, D / 2 + .05), (L, .14, .08), red, bevel=.02))
    oven.append(box((0, .14, D / 2 + .09), (L - .05, .03, .02), brass))
    oven.append(box((0, .26, D / 2 + .06), (L - .3, .2, .02), glassWarm))
    for y in (.155, .365):
        oven.append(box((0, y, D / 2 + .09), (L - .26, .025, .03), brass))
    for x in (-(L - .28) / 2, (L - .28) / 2):
        oven.append(box((x, .26, D / 2 + .09), (.025, .23, .03), brass))
    oven.append(box((0, .45, D / 2 + .05), (L, .14, .08), red, bevel=.02))
    for i in range(5):
        x = -.8 + i * .4
        oven.append(cyl((x, .45, D / 2 + .1), .045, .02, glow, axis="z", verts=20))
        oven.append(torus((x, .45, D / 2 + .1), .05, .012, brass, axis="z"))
    oven += rivets((-L / 2 + .06, .02, D / 2 + .1), (L / 2 - .06, .02, D / 2 + .1), 14, brass)
    oven += rivets((-L / 2 + .06, H + .1, D / 2 + .08), (L / 2 - .06, H + .1, D / 2 + .08), 14, brass)
    # arched mouths at both ends
    for x in (-L / 2, L / 2):
        oven.append(arch_ring(x, D - .04, H - .02, .14, .07, red))
        oven.append(arch_ring(x + (.075 if x > 0 else -.075), D + .06, H + .04, .03, .03, brass))
    # gauge on top of the front, chimney pipe with elbow, valve wheel on the side
    oven.append(cyl((.35, H + .32, D / 2 - .02), .1, .05, brass, axis="z", verts=28))
    oven.append(cyl((.35, H + .32, D / 2 + .005), .085, .01, mat("Gauge face", (.97, .94, .86), .4), axis="z", verts=28))
    oven.append(box((.37, H + .34, D / 2 + .012), (.06, .008, .004), iron, rot=(0, 0, .6)))
    oven.append(cyl((.35, H + .21, D / 2 - .02), .02, .12, brass, verts=10))
    oven.append(tube([(-.75, H + .1, -.05), (-.75, H + .55, -.05), (-.75, H + .8, -.2), (-.75, 1.9, -.25)], [.08, .08, .08, .08], brass, sides=16, subdiv=1))
    oven.append(torus((L / 2 - .3, .25, -D / 2 - .12), .12, .015, mat("Valve red", (.7, .05, .05), .4, .3), axis="z"))
    for a in range(4):
        oven.append(box((L / 2 - .3, .25, -D / 2 - .12), (.24, .015, .015), iron, rot=(0, 0, a * math.pi / 4)))
    oven.append(tube([(L / 2 - .3, .25, -D / 2 - .06), (L / 2 - .3, .25, -D / 2 - .12)], [.02, .02], iron, sides=8, subdiv=0))
    join("OvenTunnel", oven)
    join("OvenGlow", [box((0, H / 2, -D / 2 + .02), (L - .2, H - .05, .02), glow), box((0, H - .02, 0), (L - .2, .02, D - .1), glow)])
    # conveyor frame: 1 m, belt top at y 0
    fr = []
    rail = mat("Rail red", (.5, .07, .06), .45, .35)
    for z in (-.12, .12):
        fr.append(box((0, -.04, z), (1.0, .08, .025), rail, bevel=.006))
        fr += rivets((-.45, -.04, z * 1.12), (.45, -.04, z * 1.12), 5, M["steel"], r=.008)
    fr.append(cyl((.49, -.03, 0), .03, .26, M["steel"], axis="z", verts=16))
    for x in (-.4, .4):
        for z in (-.12, .12):
            fr.append(box((x, -.6, z), (.05, 1.15, .05), iron))
        fr.append(box((x, -.9, 0), (.04, .04, .26), iron))
    join("ConveyorFrame", fr)
    # red ceramic bowl with white snowflakes
    pts = []
    for i in range(14):
        a = i / 13 * math.pi / 2
        pts.append((math.sin(a) * .24 + .03, .17 - math.cos(a) * .17))
    verts, faces = [], []
    seg = 40
    for i, (r, y) in enumerate(pts):
        for k in range(seg):
            a = k * math.tau / seg
            verts.append(gp((math.cos(a) * r, y, math.sin(a) * r)))
    for i in range(len(pts) - 1):
        for k in range(seg):
            a, b = i * seg + k, i * seg + (k + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    mesh = bpy.data.meshes.new("bowl"); mesh.from_pydata(verts, [], faces); mesh.update()
    bowl = bpy.data.objects.new("bowl", mesh); bpy.context.collection.objects.link(bowl)
    sol = bowl.modifiers.new("thick", "SOLIDIFY"); sol.thickness = .015
    bpy.context.view_layer.objects.active = bowl; bpy.ops.object.modifier_apply(modifier=sol.name)
    finish(bowl, vcol_mat("Bowl glaze", .25))
    def bowl_col(x, y, z):
        if y < .02 or math.hypot(x, z) < .2 and y < .16:
            return (.95, .93, .88)
        a = math.atan2(z, x); flake = 0.0
        for k in range(8):
            ca = k * math.tau / 8; d = math.hypot(a - ca if abs(a - ca) < math.pi else a - ca - math.copysign(math.tau, a - ca), (y - .1) * 4)
            if d < .12 and (abs(math.sin((a - ca) * 18)) > .6 or abs(y - .1) < .01):
                flake = 1
        return (.95, .95, .95) if flake else (.62, .05, .06)
    paint(bowl, bowl_col)
    join("DoughBowl", [bowl])
    dough = sphere((0, .12, 0), (.2, .07, .2), M["dough"], 28, 14)
    for v in dough.data.vertices:
        v.co += v.normal * noise.noise(v.co * 14) * .012
    join("BowlDough", [dough])
    # crate with Schokotaler emblem
    plank = mat("Crate wood", (.5, .3, .15), .8)
    cr = []
    for y in (.06, .18, .3, .42):
        for z in (-.31, .31):
            cr.append(box((0, y, z), (.8, .11, .03), plank, bevel=.005))
        for x in (-.39, .39):
            cr.append(box((x, y, 0), (.03, .11, .62), plank, bevel=.005))
    cr.append(box((0, .01, 0), (.8, .02, .62), plank))
    for x in (-.39, .39):
        for z in (-.31, .31):
            cr.append(box((x, .25, z), (.045, .5, .045), iron))
    cr.append(cyl((0, .26, .335), .09, .012, brass, axis="z", verts=28))
    cr.append(cyl((0, .26, .343), .06, .006, mat("Emblem cookie", (.55, .3, .12), .6, .2), axis="z", verts=20))
    join("CoinCrate", cr)
    coin = [cyl((0, 0, 0), .03, .008, mat("Coin gold", (1.0, .76, .25), .25, 1.0), verts=24), cyl((0, .0045, 0), .018, .002, mat("Coin relief", (.85, .55, .15), .35, 1.0), verts=10)]
    join("Coin", coin)
    # bench props
    lan = [box((0, .14, 0), (.16, .22, .16), mat("Lantern glass", (1, .85, .5), .1, emit=(1, .7, .3), strength=3, alpha=.5))]
    for x in (-.08, .08):
        for z in (-.08, .08):
            lan.append(box((x, .14, z), (.015, .24, .015), brass))
    lan += [box((0, .015, 0), (.2, .03, .2), brass), cyl((0, .29, 0), .12, .08, brass, r2=.03, verts=12), torus((0, .36, 0), .03, .006, brass, axis="z"),
            cyl((0, .1, 0), .025, .1, M["white"], verts=12), sphere((0, .17, 0), (.012, .022, .012), M["lamp"], 8, 6)]
    join("Lantern", lan)
    mug = [cyl((0, .055, 0), .045, .11, mat("Mug red", (.62, .05, .06), .3), verts=24), torus((.05, .06, 0), .028, .008, mat("Mug red", (.62, .05, .06), .3), axis="z"),
           cyl((0, .1, 0), .04, .005, mat("Cocoa", (.25, .12, .05), .3), verts=20)]
    for k in range(6):
        mug.append(box((math.cos(k) * 0, .06, .046), (.03, .004, .002), M["white"], rot=(0, 0, k * math.pi / 3)))
    join("Mug", mug)
    jar = [cyl((0, .09, 0), .06, .18, mat("Jar glass", (.85, .95, 1.0), .05, alpha=.35), verts=20), cyl((0, .19, 0), .062, .02, brass, verts=20)]
    for k in range(18):
        jar.append(sphere((math.cos(k * 2.1) * .035, .03 + (k // 4) * .03, math.sin(k * 2.1) * .035), (.012, .012, .012), [M["red"], M["white"], M["green"], M["gold"]][k % 4], 6, 4))
    join("CandyJar", jar)
    dust = []
    for k in range(60):
        a = k * 2.4; r = .05 + (k % 9) * .035
        dust.append(cyl((math.cos(a) * r * 1.6, .001, math.sin(a) * r), .02 + (k % 3) * .01, .002, mat("Flour", (.98, .97, .94), 1.0), verts=8))
    join("FlourDust", dust)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / "bakery.glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_materials="EXPORT", export_normals=True, export_attributes=True)
    print("wrote bakery.glb")


build_bakery()
