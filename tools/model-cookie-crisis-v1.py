"""Santa's Cookie Crisis – original 3D assets, built in Blender 4.5 and exported as GLB for three.js.

Run: tools/blender-portable/blender-4.5.9-windows-x64/blender.exe -b -P tools/model-cookie-crisis-v1.py
Writes to frontend/public/assets/cookie/:
  world.glb     snowy clearing, log-cabin bakery (open door, windows, snowy roof, chimney), firs,
                fence, lanterns, sled with presents, signpost
  mountain.glb  the 25 t dough mountain (scaled down in the game as it is used up) + its sign
  props.glb     named nodes: Workbench, RollingPin, StarCutter, Tray, Bucket, Wheelbarrow, DoughBlob,
                OvenModule, Shelf, Candle, Stool
  machines.glb  named nodes: Hopper, Pump, RollerMachine, Press, ControlPanel, RobotArm, Extruder,
                Portal, Generator, Gear
  arm.glb       the elf's right arm in first person: felt sleeve, fur cuff, hand (mirrored for the left)
Coordinates in the helpers are three.js style (x right, y up, z towards the viewer), metres.
"""
import bpy, bmesh, math, random
from mathutils import Vector, noise
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "games/cookie-crisis/assets/models"
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(1225)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def gp(p):
    return Vector((p[0], -p[2], p[1]))


MATS = {}


def mat(name, col, rough=.6, metal=0, emit=None, strength=1.0, alpha=1.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha < 1:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    MATS[name] = m
    return m


def vcol_mat(name, rough=.8):
    """Material that takes its colour from the 'Col' vertex colours."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    m.node_tree.links.new(vc.outputs["Color"], p.inputs["Base Color"])
    MATS[name] = m
    return m


def finish(o, m, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(m)
    for f in o.data.polygons:
        f.use_smooth = smooth
    return o


def box(p, size, m, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=gp(p))
    o = bpy.context.object
    o.scale = (size[0], size[2], size[1])
    o.rotation_euler = (rot[0], -rot[2], rot[1])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        b = o.modifiers.new("bevel", "BEVEL"); b.width = bevel; b.segments = 3
        bpy.ops.object.modifier_apply(modifier=b.name)
    return finish(o, m, smooth=False)


def cyl(p, r, h, m, axis="y", r2=None, verts=24, smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=h, location=gp(p))
    o = bpy.context.object
    if axis == "x":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "z":
        o.rotation_euler = (math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(o, m, smooth)


def sphere(p, size, m, segs=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, location=gp(p))
    o = bpy.context.object
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, m)


def torus(p, R, r, m, axis="y"):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=32, minor_segments=10, location=gp(p))
    o = bpy.context.object
    if axis == "z":
        o.rotation_euler = (math.pi / 2, 0, 0)
    elif axis == "x":
        o.rotation_euler = (0, math.pi / 2, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(o, m)


def tube(pts, radii, m, sides=16, subdiv=1):
    points = [gp(p) for p in pts]
    verts, faces = [], []
    for j, p in enumerate(points):
        t = (points[min(j + 1, len(points) - 1)] - points[max(j - 1, 0)]).normalized()
        u = t.cross(Vector((0, 0, 1)))
        if u.length < .1:
            u = t.cross(Vector((1, 0, 0)))
        u.normalize(); v = t.cross(u).normalized()
        for k in range(sides):
            a = k * math.tau / sides
            verts.append(p + (math.cos(a) * u + math.sin(a) * v) * radii[j])
    for j in range(len(points) - 1):
        for k in range(sides):
            a = j * sides + k; b = j * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points) - 1) * sides + k for k in range(sides))])
    mesh = bpy.data.meshes.new("tube"); mesh.from_pydata(verts, [], faces); mesh.update()
    o = bpy.data.objects.new("tube", mesh); bpy.context.collection.objects.link(o)
    finish(o, m)
    if subdiv:
        bpy.context.view_layer.objects.active = o
        s = o.modifiers.new("sub", "SUBSURF"); s.levels = subdiv
        bpy.ops.object.modifier_apply(modifier=s.name)
    return o


def text(p, body, size, m, depth=.01, rot_y=0.0):
    bpy.ops.object.text_add(location=gp(p))
    o = bpy.context.object
    o.data.body = body; o.data.size = size; o.data.extrude = depth; o.data.align_x = "CENTER"; o.data.align_y = "CENTER"
    o.rotation_euler = (math.pi / 2, 0, rot_y)
    bpy.ops.object.convert(target="MESH")
    return finish(bpy.context.object, m, smooth=False)


def join(name, objs):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    # origin at the world origin, so the game can place the node by its own coordinates
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return o


def paint(o, fn):
    """Vertex colours from a function of the (three.js style) position."""
    col = o.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    for i, v in enumerate(o.data.vertices):
        q = o.matrix_world @ v.co
        col.data[i].color = (*fn(q.x, q.z, -q.y), 1)


def export(file):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / file), export_format="GLB", use_selection=True, export_yup=True,
                              export_materials="EXPORT", export_normals=True, export_texcoords=True, export_attributes=True)
    print("wrote", OUT / file)


# ------------------------------------------------------------------------------------- shared materials
def materials():
    MATS.clear()
    return dict(
        log=mat("Log wood", (.36, .2, .1), .85), logDark=mat("Dark beam", (.2, .11, .05), .9),
        plank=mat("Floor planks", (.42, .26, .14), .8), snow=mat("Snow", (.93, .96, 1.0), .55),
        stone=mat("Chimney stone", (.42, .4, .38), .9), glass=mat("Warm window", (1.0, .72, .35), .2, emit=(1.0, .6, .25), strength=2.5),
        pine=mat("Fir needles", (.05, .2, .1), .9), bark=mat("Bark", (.22, .13, .07), .95),
        red=mat("Christmas red", (.62, .05, .07), .55), gold=mat("Gold trim", (1.0, .75, .25), .3, .9),
        lamp=mat("Lantern light", (1.0, .8, .45), .3, emit=(1.0, .7, .3), strength=6), iron=mat("Black iron", (.06, .06, .07), .5, .6),
        wood=mat("Bench wood", (.55, .34, .18), .7), woodDark=mat("Dark wood", (.28, .16, .08), .8),
        steel=mat("Steel", (.6, .63, .66), .35, .8), rubber=mat("Rubber", (.05, .05, .05), .8), brick=mat("Oven brick", (.5, .17, .1), .9),
        dough=mat("Cookie dough", (.95, .83, .6), .85), ceramic=mat("Ceramic", (.92, .9, .85), .35),
        green=mat("Elf felt", (.06, .36, .15), .95), white=mat("Fur white", (.97, .95, .92), 1.0),
        skin=mat("Elf skin", (.93, .68, .52), .65), blue=mat("Machine blue", (.15, .35, .6), .45, .3),
        purple=mat("Magic purple", (.45, .2, .85), .3, emit=(.6, .3, 1.0), strength=3), crystal=mat("Ice crystal", (.6, .9, 1.0), .1, emit=(.35, .8, 1.0), strength=4),
        paper=mat("Present paper", (.1, .45, .25), .6), ribbon=mat("Ribbon", (.95, .8, .2), .4, .3),
        label=mat("Sign letters", (.98, .95, .88), .6), ember=mat("Oven glow", (1.0, .45, .1), .4, emit=(1.0, .4, .05), strength=5),
        yellow=mat("Warning yellow", (.95, .7, .1), .5),
    )


# ------------------------------------------------------------------------------------- world.glb
def fir(x, z, h, M):
    parts = [cyl((x, h * .12, z), h * .045, h * .24, M["bark"], verts=10)]
    for i, (y, r) in enumerate([(.3, .36), (.52, .28), (.72, .19), (.88, .1)]):
        cone = cyl((x, h * y, z), h * r, h * .32, M["pine"], r2=0, verts=14)
        parts.append(cone)
        snow = cyl((x, h * y + h * .06, z), h * r * .7, h * .12, M["snow"], r2=h * r * .25, verts=14)
        parts.append(snow)
    return parts


def build_world():
    clear(); M = materials()
    # snowy ground with soft hills, flattened around the bakery and the path
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=90, y_subdivisions=90, size=90, location=(0, 0, 0))
    g = bpy.context.object
    for v in g.data.vertices:
        x, z = v.co.x, -v.co.y
        flat = min(1, max(0, (math.hypot(x, z - 4) - 13) / 10))
        v.co.z = (noise.noise(Vector((x * .06, z * .06, .3))) * 1.6 + noise.noise(Vector((x * .2, z * .2, 1.7))) * .25) * flat - .02
    finish(g, vcol_mat("Snow ground", .7))
    paint(g, lambda x, y, z: (.86 + y * .03, .9 + y * .02, .98) if (abs(x) > 1.4 or z < 4 or z > 15) else (.78, .8, .86))
    g.name = "Ground"
    # the bakery: interior x -7..7, z -6..4, walls 4.5 m, door in the front wall at x 1.6..3.4
    W, D0, D1, H = 7.0, -6.0, 4.0, 4.5
    logs = []
    def wall_x(z, x0, x1, y0=0.0, y1=H):
        y = y0
        while y < y1 - .01:
            logs.append(cyl(((x0 + x1) / 2, y + .14, z), .15, (x1 - x0) + .3, M["log"], axis="x", verts=12))
            y += .28
    def wall_z(x, z0, z1, y0=0.0, y1=H):
        y = y0
        while y < y1 - .01:
            logs.append(cyl((x, y + .14, (z0 + z1) / 2), .15, (z1 - z0) + .3, M["log"], axis="z", verts=12))
            y += .28
    # back wall with two windows (holes between 1.6 and 3.0 m)
    wall_x(D0, -W, W, 0, 1.6); wall_x(D0, -W, W, 3.0, H)
    for a, b in [(-W, -4.6), (-2.4, 2.4), (4.6, W)]:
        wall_x(D0, a, b, 1.6, 3.0)
    # side walls with one window each
    for x in (-W, W):
        wall_z(x, D0, D1, 0, 1.6); wall_z(x, D0, D1, 3.0, H)
        wall_z(x, D0, -2.5, 1.6, 3.0); wall_z(x, -0.5, D1, 1.6, 3.0)
    # front wall with the door (x 1.6..3.4, up to 2.6 m) and a window left
    wall_x(D1, -W, 1.6, 0, 1.6); wall_x(D1, 3.4, W, 0, H); wall_x(D1, -W, 1.6, 3.0, H); wall_x(D1, 1.6, 3.4, 2.6, H)
    wall_x(D1, -W, -4.6, 1.6, 3.0); wall_x(D1, -2.4, 1.6, 1.6, 3.0)
    walls = join("BakeryWalls", logs)
    # window glass glowing warm + frames + snowy sills
    win = []
    for (x, z, rot) in [(-3.5, D0, 0), (3.5, D0, 0), (-W, -1.5, 1), (W, -1.5, 1), (-3.5, D1, 0)]:
        size = (2.2, 1.4, .05) if not rot else (.05, 1.4, 2.0)
        win.append(box((x, 2.3, z), size, M["glass"]))
        fr = (2.4, .12, .2) if not rot else (.2, .12, 2.2)
        win.append(box((x, 1.55, z + (0 if rot else .12)), fr, M["logDark"]))
        win.append(box((x + (.12 if rot and x > 0 else -.12 if rot else 0), 1.5, z + (0 if rot else .2)), (fr[0], .08, fr[2]) if not rot else (.3, .08, 2.2), M["snow"]))
        win.append(box((x, 2.3, z), (2.4, .08, .12) if not rot else (.12, .08, 2.2), M["logDark"]))
        win.append(box((x, 2.3, z), (.08, 1.4, .12) if not rot else (.12, 1.4, .08), M["logDark"]))
    join("Windows", win)
    # door frame + open door leaf + wreath
    door = [box((1.55, 1.3, D1), (.16, 2.6, .36), M["logDark"]), box((3.45, 1.3, D1), (.16, 2.6, .36), M["logDark"]), box((2.5, 2.65, D1), (2.06, .16, .36), M["logDark"])]
    door.append(box((3.55, 1.25, D1 + .85), (.08, 2.4, 1.7), M["red"], bevel=.02))
    door.append(torus((2.5, 3.2, D1 + .22), .32, .09, M["pine"], axis="z"))
    door.append(box((2.5, 3.5, D1 + .26), (.25, .12, .05), M["red"]))
    join("Door", door)
    # floor (inside) and porch
    floor = [box((0, -.02, -1), (2 * W, .06, D1 - D0), M["plank"])]
    for x in range(-7, 8):
        floor.append(box((x, .012, -1), (.02, .01, D1 - D0), M["logDark"]))
    floor.append(box((2.5, .04, D1 + 1.0), (3.4, .12, 2.0), M["plank"]))
    join("Floor", floor)
    # gable roof with a thick snow cover, overhang, chimney
    roof = []
    half = W + .8; ridge = H + 2.4; span = math.hypot(half, 2.4)
    ang = math.atan2(2.4, half)
    for s in (-1, 1):
        roof.append(box((s * half / 2, H + 1.2, -1), (span + .2, .22, D1 - D0 + 1.6), M["logDark"], rot=(0, 0, -s * ang)))
        roof.append(box((s * half / 2 - s * .02, H + 1.43, -1), (span + .25, .26, D1 - D0 + 1.7), M["snow"], bevel=.1, rot=(0, 0, -s * ang)))
    for z in (D0 - .05, D1 + .05):
        tri = bpy.data.meshes.new("gable"); tri.from_pydata([gp((-W, H, z)), gp((W, H, z)), gp((0, ridge, z))], [], [(0, 1, 2)]); tri.update()
        o = bpy.data.objects.new("gable", tri); bpy.context.collection.objects.link(o); finish(o, M["log"], smooth=False); roof.append(o)
    roof.append(box((-4, H + 2.2, -3), (.9, 2.6, .9), M["stone"]))
    roof.append(box((-4, H + 3.55, -3), (1.05, .25, 1.05), M["snow"], bevel=.08))
    join("Roof", roof)
    # fairy lights along the eaves
    lights = []
    for i in range(30):
        x = -W + i * (2 * W / 29)
        lights.append(sphere((x, H - .05 - abs(math.sin(i * .9)) * .12, D1 + .5), (.06, .08, .06), [M["red"], M["gold"], M["lamp"], M["purple"]][i % 4] if i % 4 != 2 else M["lamp"]))
    join("EaveLights", lights)
    # trees around the clearing (not on the path to the mountain)
    trees = []
    for i in range(46):
        a = rng.random() * math.tau; r = 16 + rng.random() * 22
        x, z = math.cos(a) * r, math.sin(a) * r + 4
        if abs(x) < 6 and z > 0:
            continue
        trees += fir(x, z, 4 + rng.random() * 5, M)
    for x, z, h in [(-9, 7, 5.5), (9.5, 9, 6), (-10, -3, 6.5), (10, -6, 5), (-6, 14, 4), (8, 18, 5)]:
        trees += fir(x, z, h, M)
    join("Firs", trees)
    # fence along the path, lantern posts, sled with presents, signpost
    fence = []
    for z in range(6, 14, 2):
        for x in (-1.3, 4.6):
            fence.append(box((x, .5, z), (.12, 1.0, .12), M["woodDark"]))
            fence.append(box((x, .7, z + 1), (.06, .08, 2.0), M["woodDark"]))
            fence.append(box((x, .38, z + 1), (.06, .08, 2.0), M["woodDark"]))
            fence.append(box((x, 1.03, z), (.16, .06, .16), M["snow"]))
    join("Fence", fence)
    lamps = []
    for x, z in [(0.6, 5.2), (4.4, 5.2), (-1.0, 10), (4.4, 12), (1.5, 15.5)]:
        lamps.append(cyl((x, 1.1, z), .05, 2.2, M["iron"], verts=8))
        lamps.append(box((x, 2.35, z), (.28, .34, .28), M["iron"]))
        lamps.append(box((x, 2.35, z), (.22, .26, .22), M["lamp"]))
        lamps.append(cyl((x, 2.6, z), .2, .14, M["snow"], r2=.05, verts=8))
    join("Lanterns", lamps)
    sled = [box((-3.2, .3, 7.5), (1.0, .08, 1.8), M["red"], bevel=.03)]
    for x in (-3.6, -2.8):
        sled.append(tube([(x, .05, 6.5), (x, .05, 8.2), (x, .2, 8.6), (x, .45, 8.5)], [.03] * 4, M["gold"], sides=8, subdiv=0))
    for i, (dx, dz, s) in enumerate([(-.2, .3, .45), (.25, -.2, .38), (0, -.55, .3), (-.25, -.3, .26)]):
        sled.append(box((-3.2 + dx, .34 + s / 2, 7.5 + dz), (s, s, s), [M["paper"], M["red"], M["paper"], M["red"]][i]))
        sled.append(box((-3.2 + dx, .34 + s / 2, 7.5 + dz), (s + .01, s + .01, .06), M["ribbon"]))
    join("Sled", sled)
    sign = [box((5.6, .9, 6.4), (.12, 1.8, .12), M["woodDark"]), box((5.6, 1.75, 6.5), (1.6, .45, .06), M["wood"]),
            text((5.6, 1.75, 6.55), "Zum Teigberg", .22, M["label"]), box((5.6, 2.02, 6.5), (1.7, .07, .12), M["snow"])]
    join("Signpost", sign)
    export("world.glb")


# ------------------------------------------------------------------------------------- mountain.glb
def build_mountain():
    clear(); M = materials()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=6, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        p = v.co.copy()
        n = noise.noise(p * 2.2) * .12 + noise.noise(p * 5.5 + Vector((3, 1, 2))) * .05 + noise.noise(p * 13) * .015
        p *= 1 + n
        p.z = max(p.z, -.05)
        v.co = Vector((p.x * 4.2, p.y * 3.8, p.z * 2.6))
    finish(o, vcol_mat("Dough mountain", .9))
    def col(x, y, z):
        flour = max(0, min(1, (y - 1.2) / 1.2)) * (.5 + .5 * noise.noise(Vector((x * 2, y * 2, z * 2))))
        dark = .04 * noise.noise(Vector((x * 4, y * 4, z * 4 + 9)))
        base = (.93 + dark, .8 + dark, .56 + dark)
        return tuple(base[i] * (1 - flour) + (.98, .97, .94)[i] * flour for i in range(3))
    paint(o, col)
    o.name = "Mountain"; o.data.name = "Mountain"
    # loose chunks around the foot
    chunks = []
    for i in range(14):
        a = rng.random() * math.tau; r = 4.3 + rng.random() * .8
        chunks.append(sphere((math.cos(a) * r, .12, math.sin(a) * r * .9), (.25 + rng.random() * .2, .18, .22 + rng.random() * .15), M["dough"], 12, 8))
    join("Chunks", chunks)
    sign = [box((-3.6, .7, 3.8), (.1, 1.4, .1), M["woodDark"]), box((-3.6, 1.35, 3.85), (1.5, .55, .05), M["wood"]),
            text((-3.6, 1.42, 3.89), "25 t KEKSTEIG", .2, M["label"]), text((-3.6, 1.18, 3.89), "vom Weihnachtsmann", .11, M["label"])]
    join("MountainSign", sign)
    # the dough blob the elf carries
    # (the blob is centred on its own origin, so the game can hold and place it)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=.09, location=(0, 0, 0))
    b = bpy.context.object
    for v in b.data.vertices:
        v.co = v.co * (1 + noise.noise(v.co * 25 + Vector((7, 3, 1))) * .12)
    finish(b, M["dough"]); b.name = "DoughBlob"; b.data.name = "DoughBlob"
    export("mountain.glb")


# ------------------------------------------------------------------------------------- props.glb
def build_props():
    clear(); M = materials()
    # workbench 3.4 × 1.1, top at 0.9
    wb = [box((0, .86, 0), (3.4, .08, 1.1), M["wood"], bevel=.015)]
    for i in range(7):
        wb.append(box((-1.7 + i * .5 + .25, .902, 0), (.01, .004, 1.1), M["woodDark"]))
    for x, z in [(-1.6, -.45), (1.6, -.45), (-1.6, .45), (1.6, .45)]:
        wb.append(box((x, .41, z), (.1, .82, .1), M["woodDark"], bevel=.01))
    wb.append(box((0, .22, 0), (3.3, .04, .95), M["woodDark"]))
    wb.append(box((0, .76, .52), (3.3, .12, .04), M["woodDark"]))
    join("Workbench", wb)
    rp = [cyl((0, 0, 0), .04, .5, mat("Pin wood", (.85, .6, .35), .55), axis="x", verts=20)]
    for s in (-1, 1):
        rp.append(cyl((s * .31, 0, 0), .018, .13, M["woodDark"], axis="x", verts=12))
        rp.append(sphere((s * .38, 0, 0), (.024, .024, .024), M["woodDark"], 10, 8))
    join("RollingPin", rp)
    # star cutter: a thin metal star outline with a red grip
    pts = []
    for i in range(10):
        r = .06 if i % 2 == 0 else .03; a = -math.pi / 2 + i * math.pi / 5
        pts.append((math.cos(a) * r, 0, math.sin(a) * r))
    ring = []
    for i in range(10):
        a, b = pts[i], pts[(i + 1) % 10]
        mid = ((a[0] + b[0]) / 2, .02, (a[2] + b[2]) / 2); ln = math.hypot(b[0] - a[0], b[2] - a[2]); ang = math.atan2(b[2] - a[2], b[0] - a[0])
        ring.append(box(mid, (ln, .04, .004), M["steel"], rot=(0, -ang, 0)))
    ring.append(box((0, .045, 0), (.05, .012, .05), M["red"], bevel=.004))
    join("StarCutter", ring)
    tr = [box((0, 0, 0), (.64, .012, .44), M["steel"])]
    for w, d, x, z in [(.64, .016, 0, .22), (.64, .016, 0, -.22), (.016, .44, .32, 0), (.016, .44, -.32, 0)]:
        tr.append(box((x, .018, z), (w, .036, d), M["steel"]))
    join("Tray", tr)
    bk = [cyl((0, .17, 0), .17, .34, M["wood"], r2=.14, verts=20), torus((0, .3, 0), .165, .012, M["iron"]), torus((0, .08, 0), .145, .012, M["iron"])]
    bk.append(tube([(-.16, .32, 0), (-.1, .48, 0), (.1, .48, 0), (.16, .32, 0)], [.006] * 4, M["iron"], sides=6, subdiv=1))
    join("Bucket", bk)
    wh = [box((0, .45, 0), (.6, .3, .8), M["red"], bevel=.05), cyl((0, .2, -.55), .2, .07, M["rubber"], axis="x", verts=20)]
    for s in (-1, 1):
        wh.append(tube([(s * .22, .4, -.45), (s * .25, .45, .2), (s * .27, .6, .85)], [.022] * 3, M["woodDark"], sides=8, subdiv=0))
        wh.append(box((s * .2, .17, .25), (.04, .34, .04), M["iron"]))
    join("Wheelbarrow", wh)
    # oven module: 1 m long, belt runs through at y 0.04; glass front left open for the shader in three
    ov = [box((0, .44, 0), (1.0, .06, .5), M["brick"]), box((0, .22, -.25), (1.0, .46, .06), M["brick"]),
          box((0, .4, 0), (.96, .03, .03), M["ember"])]
    for x in (-.5, .5):
        ov.append(box((x, .22, 0), (.02, .48, .52), M["iron"]))
    ov.append(box((0, .47, .26), (1.0, .06, .04), M["gold"]))
    join("OvenModule", ov)
    sh = [box((0, 0, 0), (1.6, .05, .35), M["woodDark"])]
    for i, c in enumerate([M["red"], M["green"], M["gold"]]):
        sh.append(cyl((-.5 + i * .5, .17, 0), .11, .28, mat("Jar glass", (.85, .95, 1.0), .05, alpha=.35), verts=18))
        sh.append(cyl((-.5 + i * .5, .33, 0), .12, .05, c, verts=18))
        for k in range(3):
            sh.append(cyl((-.5 + i * .5 + (k - 1) * .04, .08 + k * .05, 0), .04, .012, mat("Baked cookie", (.8, .5, .2), .7), verts=10))
    join("Shelf", sh)
    join("Candle", [cyl((0, .08, 0), .03, .16, M["white"], verts=14), cyl((0, .005, 0), .06, .01, M["gold"], verts=14)])
    join("Stool", [cyl((0, .6, 0), .2, .05, M["wood"], verts=20)] + [box((math.cos(a) * .14, .3, math.sin(a) * .14), (.04, .6, .04), M["woodDark"]) for a in (0, 2.1, 4.2)])
    export("props.glb")


# ------------------------------------------------------------------------------------- machines.glb
def gear(p, r, m, teeth=14, depth=.05):
    parts = [cyl(p, r, depth, m, axis="z", verts=32)]
    for i in range(teeth):
        a = i * math.tau / teeth
        parts.append(box((p[0] + math.cos(a) * r, p[1] + math.sin(a) * r, p[2]), (r * .35, r * .25, depth), m, rot=(0, 0, a)))
    parts.append(cyl(p, r * .3, depth + .02, mat("Gear hub", (.2, .2, .22), .5, .7), axis="z", verts=16))
    return parts


def build_machines():
    clear(); M = materials()
    hp = [cyl((0, 0, 0), .24, .36, M["steel"], r2=.07, verts=28)]
    hp.append(torus((0, .18, 0), .24, .02, M["red"]))
    for x in (-.25, .25):
        hp.append(box((x, -.3, -.2), (.04, .9, .04), M["iron"]))
    hp.append(box((0, .15, -.2), (.6, .04, .04), M["iron"]))
    join("Hopper", hp)
    pm = [box((0, .35, 0), (.7, .7, .55), M["blue"], bevel=.04), cyl((0, .35, .3), .18, .06, M["steel"], axis="z"),
          box((0, .82, 0), (.3, .24, .3), M["steel"], bevel=.02), cyl((.42, .3, 0), .08, .3, M["steel"], axis="x", verts=16)]
    pm += [text((0, .5, .29), "TEIGPUMPE", .07, M["label"])]
    join("Pump", pm)
    rm = []
    for y in (.05, .15):
        rm.append(cyl((0, y, 0), .045, .62, M["steel"], axis="z", verts=24))
    for z in (-.33, .33):
        rm.append(box((0, .12, z), (.18, .3, .04), M["iron"], bevel=.01))
    rm.append(box((0, .27, .37), (.03, .16, .03), M["iron"]))
    rm.append(sphere((0, .2, .42), (.035, .035, .035), M["red"]))
    join("RollerMachine", rm)
    pr = []
    for x in (-.28, .28):
        pr.append(box((x, .32, 0), (.06, .64, .06), mat("Press paint", (.45, .32, .26), .6), bevel=.01))
    pr.append(box((0, .66, 0), (.66, .08, .16), mat("Press paint", (.45, .32, .26), .6), bevel=.02))
    pr.append(box((0, .5, 0), (.05, .3, .05), M["steel"]))
    pr.append(box((0, .34, 0), (.46, .05, .32), M["steel"], bevel=.01))
    pr.append(tube([(.33, .6, 0), (.5, .7, 0), (.62, .62, 0)], [.018] * 3, M["iron"], sides=8, subdiv=0))
    pr.append(sphere((.63, .62, 0), (.04, .04, .04), M["red"]))
    join("Press", pr)
    cp = [box((0, .6, 0), (.8, 1.2, .45), mat("Panel", (.14, .15, .18), .5, .3), bevel=.03), box((0, 1.25, .08), (.8, .1, .6), M["yellow"])]
    for i in range(12):
        cp.append(sphere((-.27 + (i % 4) * .18, .85 + (i // 4) * .13, .23), (.03, .03, .02), [mat("Lamp green", (.2, 1, .4), .3, emit=(.2, 1, .4), strength=4), M["lamp"], mat("Lamp red", (1, .2, .2), .3, emit=(1, .15, .1), strength=4)][i % 3]))
    cp.append(box((0, .45, .23), (.5, .25, .02), mat("Screen", (.1, .4, .3), .2, emit=(.1, .6, .4), strength=1.5)))
    cp.append(text((0, 1.25, .39), "STEUERUNG", .08, M["label"]))
    join("ControlPanel", cp)
    ra = [cyl((0, .06, 0), .15, .12, M["iron"], verts=20), cyl((0, .2, 0), .07, .2, M["yellow"], verts=16),
          tube([(0, .3, 0), (0, .55, -.15), (0, .62, -.45)], [.05, .045, .04], M["yellow"], sides=12, subdiv=1),
          box((0, .58, -.5), (.12, .05, .1), M["iron"])]
    join("RobotArm", ra)
    ex = [box((0, .45, 0), (.9, .9, .7), mat("Extruder paint", (.4, .45, .52), .4, .5), bevel=.05), cyl((.5, .3, 0), .12, .2, M["steel"], axis="x"),
          box((0, .95, 0), (.5, .1, .5), M["yellow"]), text((0, .6, .36), "EXTRUDER", .09, M["label"])]
    join("Extruder", ex)
    join("Portal", [torus((0, 0, 0), .32, .04, M["purple"], axis="z")] + [sphere((math.cos(a) * .32, math.sin(a) * .32, .03), (.035, .035, .035), M["crystal"]) for a in [i * math.tau / 8 for i in range(8)]])
    gen = [cyl((0, .25, 0), .32, .5, mat("Generator base", (.2, .15, .35), .4, .4), verts=24), torus((0, .5, 0), .3, .03, M["gold"])]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=.22, location=gp((0, .9, 0)))
    gen.append(finish(bpy.context.object, M["crystal"], smooth=False))
    for s in (-1, 1):
        gen.append(tube([(s * .15, .9, 0), (s * .35, 1.25, 0), (s * .55, 1.35, 0)], [.025, .02, .012], M["gold"], sides=8, subdiv=0))
        gen.append(tube([(s * .33, 1.22, 0), (s * .3, 1.45, 0)], [.018, .01], M["gold"], sides=8, subdiv=0))
    join("Generator", gen)
    join("Gear", gear((0, 0, 0), .15, M["steel"]))
    export("machines.glb")


# ------------------------------------------------------------------------------------- arm.glb (first person)
def build_arm():
    clear(); M = materials()
    # right arm pointing forward (-z): sleeve from the shoulder towards the wrist
    sleeve = tube([(0, 0, .55), (0, 0, .35), (0, 0, .16), (0, 0, .04)], [.075, .07, .062, .058], M["green"], sides=20, subdiv=1)
    for v in sleeve.data.vertices:  # soft felt folds
        v.co += v.normal * noise.noise(v.co * 18) * .006
    cuff = torus((0, 0, .03), .062, .024, M["white"], axis="z")
    for v in cuff.data.vertices:
        v.co += v.normal * (noise.noise(v.co * 60) * .006 + .002)
    band = cyl((0, 0, .075), .066, .03, M["red"], axis="z", verts=24)
    bell = sphere((0, -.07, .07), (.016, .016, .016), M["gold"], 12, 8)
    # hand: palm + four fingers + thumb, slightly cupped
    skin = M["skin"]
    hand = [sphere((0, -.005, -.045), (.042, .022, .05), skin)]
    for i, x in enumerate([-.026, -.009, .009, .026]):
        ln = [.055, .062, .058, .046][i]
        hand.append(tube([(x, -.004, -.085), (x * 1.05, -.01, -.085 - ln * .55), (x * 1.08, -.022, -.085 - ln)], [.0105, .0095, .0075], skin, sides=10, subdiv=1))
    hand.append(tube([(-.035, -.006, -.04), (-.058, -.012, -.07), (-.064, -.02, -.1)], [.012, .01, .008], skin, sides=10, subdiv=1))
    h = join("Hand", hand)
    rem = h.modifiers.new("weld", "REMESH"); rem.mode = "VOXEL"; rem.voxel_size = .0025; rem.use_smooth_shade = True
    bpy.context.view_layer.objects.active = h; bpy.ops.object.modifier_apply(modifier=rem.name)
    sm = h.modifiers.new("relax", "SMOOTH"); sm.factor = .5; sm.iterations = 4; bpy.ops.object.modifier_apply(modifier=sm.name)
    dec = h.modifiers.new("budget", "DECIMATE"); dec.ratio = .5; bpy.ops.object.modifier_apply(modifier=dec.name)
    join("ElfArm", [sleeve, cuff, band, bell, h])
    export("arm.glb")


build_world()
build_mountain()
build_props()
build_machines()
build_arm()
