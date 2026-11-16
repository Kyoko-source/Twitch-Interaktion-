"""Santa's Cookie Crisis – asset pass 2 (Blender 4.5): rigged first-person elf arm, moving machine
parts and a cosy interior. Reuses the helpers of model-cookie-crisis-v1.py.

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b -P tools/model-cookie-crisis-v2.py
Writes to frontend/public/assets/cookie/:
  elf-arm.glb   armature "ElfRig" with bones wrist, palm, <finger>1-3 (index, middle, ring, little, thumb)
                and one skinned mesh (felt sleeve, fur cuff with bell, hand) – fingers curl in the game
  parts.glb     moving machine parts as separate nodes: PressFrame, PressStamp, PressLever, RollerFrame,
                Roller, ArmBase, ArmUpper, ArmClaw, HopperBody, Flywheel
  interior.glb  ChristmasTree (ornaments, lights, star), Presents, Rug, HangingLantern, BeamGarland,
                WallShelf, Stocking, Fireplace? no – the oven warms the room; CookieTin, Sack
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[1]
helper = ROOT / "tools/model-cookie-crisis-v1.py"
exec(compile(helper.read_text(encoding="utf-8").split("\nbuild_world()\n")[0], str(helper), "exec"), globals())


# ------------------------------------------------------------------------------------- rigged arm
FINGERS = [("index", -.026, .056), ("middle", -.009, .063), ("ring", .009, .059), ("little", .026, .047)]


def finger_points(x, ln):
    z0 = -.083
    return [(x, -.004, z0), (x * 1.03, -.008, z0 - ln * .42), (x * 1.06, -.013, z0 - ln * .74), (x * 1.08, -.018, z0 - ln)]


THUMB = [(-.034, -.006, -.035), (-.054, -.01, -.06), (-.064, -.014, -.084), (-.068, -.017, -.104)]


def build_rig_arm():
    clear(); M = materials()
    skin = M["skin"]
    sleeve = tube([(0, 0, .6), (0, 0, .38), (0, 0, .18), (0, 0, .05)], [.072, .068, .06, .056], M["green"], sides=22, subdiv=1)
    for v in sleeve.data.vertices:
        v.co += v.normal * noise.noise(v.co * 18) * .006
    cuff = torus((0, 0, .035), .06, .024, M["white"], axis="z")
    for v in cuff.data.vertices:
        v.co += v.normal * (noise.noise(v.co * 60) * .006 + .002)
    band = cyl((0, 0, .08), .064, .03, M["red"], axis="z", verts=24)
    bell = sphere((0, -.068, .075), (.016, .016, .016), M["gold"], 12, 8)
    hand = [sphere((0, -.004, -.045), (.041, .021, .05), skin), sphere((-.02, -.01, -.02), (.02, .016, .025), skin)]
    for name, x, ln in FINGERS:
        pts = finger_points(x, ln)
        r = .0102 if name != "little" else .0088
        hand.append(tube(pts, [r, r * .95, r * .85, r * .62], skin, sides=10, subdiv=1))
    hand.append(tube(THUMB, [.012, .011, .0095, .007], skin, sides=10, subdiv=1))
    h = join("ElfHandSkin", hand)
    rem = h.modifiers.new("weld", "REMESH"); rem.mode = "VOXEL"; rem.voxel_size = .0022; rem.use_smooth_shade = True
    bpy.context.view_layer.objects.active = h; bpy.ops.object.modifier_apply(modifier=rem.name)
    sm = h.modifiers.new("relax", "SMOOTH"); sm.factor = .5; sm.iterations = 4; bpy.ops.object.modifier_apply(modifier=sm.name)
    dec = h.modifiers.new("budget", "DECIMATE"); dec.ratio = .55; bpy.ops.object.modifier_apply(modifier=dec.name)
    for f in h.data.polygons:
        f.use_smooth = True
    mesh = join("ElfArmMesh", [sleeve, cuff, band, bell, h])
    # skeleton
    bpy.ops.object.armature_add(location=(0, 0, 0))
    rig = bpy.context.object; rig.name = "ElfRig"; rig.data.name = "ElfRig"
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    eb.remove(eb[0])
    segs = []
    def bone(name, a, b, parent=None):
        bn = eb.new(name); bn.head = gp(a); bn.tail = gp(b)
        if parent: bn.parent = eb[parent]
        segs.append((name, Vector(gp(a)), Vector(gp(b))))
    bone("wrist", (0, 0, .3), (0, 0, .0))
    bone("palm", (0, 0, 0), (0, -.004, -.075), "wrist")
    for name, x, ln in FINGERS:
        pts = finger_points(x, ln)
        for j in range(3):
            bone(f"{name}{j + 1}", pts[j], pts[j + 1], "palm" if j == 0 else f"{name}{j}")
    for j in range(3):
        bone(f"thumb{j + 1}", THUMB[j], THUMB[j + 1], "palm" if j == 0 else f"thumb{j}")
    bpy.ops.object.mode_set(mode="OBJECT")
    # weights: each vertex follows its nearest bone segment (soft blend between the two nearest)
    def dist(p, a, b):
        d = b - a; t = max(0, min(1, (p - a).dot(d) / d.length_squared)); return (p - a - d * t).length
    groups = {name: mesh.vertex_groups.new(name=name) for name, _, _ in segs}
    for v in mesh.data.vertices:
        p = mesh.matrix_world @ v.co
        if (-p.y) > .045:   # sleeve, cuff, band, bell (three z > 0.045) belong to the wrist
            groups["wrist"].add([v.index], 1.0, "REPLACE"); continue
        ds = sorted((dist(p, a, b), name) for name, a, b in segs if name != "wrist")
        (d1, n1), (d2, n2) = ds[0], ds[1]
        w1 = 1.0 if d2 - d1 > .006 else .5 + (d2 - d1) / .012
        groups[n1].add([v.index], w1, "REPLACE")
        if w1 < 1:
            groups[n2].add([v.index], 1 - w1, "REPLACE")
    mod = mesh.modifiers.new("rig", "ARMATURE"); mod.object = rig
    mesh.parent = rig
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / "elf-arm.glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_materials="EXPORT", export_normals=True, export_skins=True, export_animations=False)
    print("wrote elf-arm.glb")


# ------------------------------------------------------------------------------------- moving machine parts
def build_parts():
    clear(); M = materials()
    paint_ = mat("Press paint", (.45, .32, .26), .6)
    fr = []
    for x in (-.28, .28):
        fr.append(box((x, .32, 0), (.06, .64, .06), paint_, bevel=.01))
    fr.append(box((0, .66, 0), (.66, .08, .16), paint_, bevel=.02))
    fr.append(text((0, .66, .085), "STANZE", .05, M["label"]))
    join("PressFrame", fr)
    # stamp: origin at its top so it can slide down
    st = [box((0, -.12, 0), (.05, .24, .05), M["steel"]), box((0, -.25, 0), (.46, .05, .32), M["steel"], bevel=.01)]
    for i in range(4):
        sx = -.15 + i * .1
        pts = [(sx + math.cos(-math.pi / 2 + k * math.pi / 5) * (.035 if k % 2 == 0 else .017), -.29, math.sin(-math.pi / 2 + k * math.pi / 5) * (.035 if k % 2 == 0 else .017)) for k in range(10)]
        st.append(sphere((sx, -.282, 0), (.03, .012, .03), M["steel"], 10, 6))
    join("PressStamp", st)
    join("PressLever", [tube([(0, 0, 0), (.17, .1, 0), (.29, .02, 0)], [.018] * 3, M["iron"], sides=8, subdiv=0), sphere((.3, .02, 0), (.04, .04, .04), M["red"])])
    rf = []
    for z in (-.33, .33):
        rf.append(box((0, .12, z), (.18, .3, .04), M["iron"], bevel=.01))
    rf.append(box((0, .28, 0), (.2, .03, .7), M["iron"]))
    join("RollerFrame", rf)
    ro = [cyl((0, 0, 0), .045, .62, M["steel"], axis="z", verts=24)]
    for k in range(6):  # grooves make the rotation visible
        a = k * math.tau / 6
        ro.append(box((math.cos(a) * .045, math.sin(a) * .045, 0), (.006, .006, .6), M["iron"]))
    join("Roller", ro)
    join("Flywheel", [torus((0, 0, 0), .11, .015, M["iron"], axis="z")] + [box((0, 0, 0), (.22, .012, .012), M["iron"], rot=(0, 0, a)) for a in (0, math.pi / 3, 2 * math.pi / 3)] + [sphere((0, .11, .02), (.02, .02, .03), M["red"])])
    join("ArmBase", [cyl((0, .06, 0), .15, .12, M["iron"], verts=20), cyl((0, .2, 0), .07, .2, M["yellow"], verts=16)])
    join("ArmUpper", [tube([(0, 0, 0), (0, .12, -.15), (0, .14, -.38)], [.05, .045, .04], M["yellow"], sides=12, subdiv=1), sphere((0, .14, -.4), (.05, .05, .05), M["iron"])])
    join("ArmClaw", [box((0, 0, -.04), (.12, .05, .08), M["iron"]), box((-.05, -.05, -.07), (.02, .08, .03), M["steel"]), box((.05, -.05, -.07), (.02, .08, .03), M["steel"])])
    hb = [cyl((0, 0, 0), .24, .36, M["steel"], r2=.07, verts=28), torus((0, .18, 0), .24, .02, M["red"])]
    join("HopperBody", hb)
    export("parts.glb")


# ------------------------------------------------------------------------------------- cosy interior
def build_interior():
    clear(); M = materials()
    # Christmas tree with ornaments, lights and a star
    tree = fir(0, 0, 2.6, M)
    orn = [M["red"], M["gold"], mat("Ornament blue", (.15, .3, .8), .25, .5), mat("Ornament silver", (.8, .82, .86), .2, .9)]
    k = 0
    for ring, (y, r) in enumerate([(.6, .8), (1.0, .66), (1.4, .48), (1.8, .32)]):
        n = 10 - ring * 2
        for i in range(n):
            a = i * math.tau / n + ring * .4
            tree.append(sphere((math.cos(a) * r * .95, y, math.sin(a) * r * .95), (.05, .05, .05), orn[k % 4], 12, 8)); k += 1
            tree.append(sphere((math.cos(a + .3) * r * .9, y + .12, math.sin(a + .3) * r * .9), (.025, .03, .025), M["lamp"], 8, 6))
    st = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5; rr = .16 if i % 2 == 0 else .07
        st.append((math.cos(a) * rr, 2.72 + math.sin(a) * rr))
    mesh = bpy.data.meshes.new("star")
    verts = [gp((x, y, -.03)) for x, y in st] + [gp((x, y, .03)) for x, y in st] + [gp((0, 2.72, -.05)), gp((0, 2.72, .05))]
    faces = [(i, (i + 1) % 10, 20) for i in range(10)] + [((i + 1) % 10 + 10, i + 10, 21) for i in range(10)] + [(i, i + 10, (i + 1) % 10 + 10, (i + 1) % 10) for i in range(10)]
    mesh.from_pydata(verts, [], faces); mesh.update()
    o = bpy.data.objects.new("star", mesh); bpy.context.collection.objects.link(o); finish(o, mat("Star gold", (1, .8, .2), .2, .8, emit=(1, .75, .2), strength=4), smooth=False)
    tree += [o, cyl((0, .15, 0), .32, .3, M["red"], r2=.28, verts=20)]
    join("ChristmasTree", tree)
    pres = []
    for i, (x, z, s, c) in enumerate([(.5, .3, .32, "paper"), (-.45, .4, .26, "red"), (.1, .6, .22, "paper"), (-.2, -.5, .3, "red"), (.55, -.35, .2, "paper")]):
        pres.append(box((x, s / 2, z), (s, s, s * 1.1), M[c], bevel=.01, rot=(0, i * .4, 0)))
        pres.append(box((x, s / 2, z), (s + .01, s + .01, .05), M["ribbon"], rot=(0, i * .4, 0)))
        pres.append(sphere((x, s + .02, z), (.05, .03, .05), M["ribbon"], 8, 6))
    join("Presents", pres)
    rug = [cyl((0, .005, 0), 1.3, .01, M["red"], verts=48)]
    rug.append(torus((0, .012, 0), 1.25, .025, M["gold"]))
    rug.append(cyl((0, .011, 0), .9, .01, M["green"], verts=48))
    join("Rug", rug)
    lan = [cyl((0, .5, 0), .008, 1.0, M["iron"], verts=6), box((0, -.05, 0), (.22, .28, .22), M["iron"]), box((0, -.05, 0), (.17, .22, .17), M["lamp"]),
           cyl((0, .12, 0), .16, .08, M["iron"], r2=.03, verts=8)]
    join("HangingLantern", lan)
    gar = []
    pts = [(-7, 0, 0)] + [(-7 + i * 1, -.25 * abs(math.sin(i * .7)), 0) for i in range(1, 14)] + [(7, 0, 0)]
    gar.append(tube(pts, [.07] * len(pts), M["pine"], sides=8, subdiv=0))
    for i in range(28):
        x = -6.8 + i * .5; y = -.25 * abs(math.sin((x + 7) * .7)) - .06
        gar.append(sphere((x, y, .07), (.03, .04, .03), [M["red"], M["gold"], M["lamp"], M["purple"]][i % 4], 8, 6))
    join("BeamGarland", gar)
    sh = [box((0, 0, 0), (1.8, .05, .3), M["woodDark"]), box((-.85, -.15, 0), (.04, .3, .28), M["woodDark"]), box((.85, -.15, 0), (.04, .3, .28), M["woodDark"])]
    for i, c in enumerate([M["red"], M["green"], M["gold"], M["red"]]):
        sh.append(cyl((-.6 + i * .4, .16, 0), .1, .26, mat("Tin", (.7, .72, .75), .3, .8), verts=18))
        sh.append(cyl((-.6 + i * .4, .3, 0), .105, .04, c, verts=18))
    join("WallShelf", sh)
    stock = []
    for i, c in enumerate(["red", "green", "red"]):
        x = i * .4
        stock.append(tube([(x, 0, 0), (x, -.32, 0), (x + .02, -.4, .06), (x + .12, -.42, .1)], [.07, .065, .06, .05], M[c], sides=12, subdiv=1))
        stock.append(torus((x, -.02, 0), .07, .025, M["white"], axis="y"))
    join("Stockings", stock)
    sack = sphere((0, .35, 0), (.35, .4, .3), mat("Burlap", (.55, .42, .25), .95), 20, 14)
    for v in sack.data.vertices:
        v.co += v.normal * noise.noise(v.co * 8) * .02
    join("FlourSack", [sack, text((0, .38, .29), "MEHL", .1, M["label"])])
    export("interior.glb")


build_rig_arm()
build_parts()
build_interior()
