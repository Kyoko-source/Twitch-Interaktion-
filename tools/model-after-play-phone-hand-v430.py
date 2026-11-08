"""Phone hand for the lift intro, rebuilt (4.3.1). Blender 4.5 --background.

The old hand wrapped four thick, even tubes over the right edge onto the
glass. A real one-handed grip: the phone rests on the fingers behind it, the
finger pads only just curl round the right edge, the thumb braces the left
edge low down, and the little finger supports the bottom corner. Fingers are
tapered with three phalanges and knuckles. Coordinates: x right, y up the
phone, z towards the viewer (converted by gp()). Writes the desktop asset.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
helper = ROOT / 'tools/model-after-play-lift-v391.py'
exec(compile(helper.read_text(encoding='utf-8').split('\nclear()\nframe=')[0], str(helper), 'exec'), globals())
OUT = ROOT / 'games/kinderparadies/assets/quality-v410/desktop'
rng = random.Random(430)

clear()
skin = mat('Phone hand skin', (.50, .38, .31), .6)
p = skin.node_tree.nodes['Principled BSDF']; p.inputs['Subsurface Weight'].default_value = .12; p.inputs['Specular IOR Level'].default_value = .25
nail = mat('Fitted satin keratin plates', (.52, .40, .36), .45)
cloth = mat('Nightguard woven cuff', (.027, .043, .036), .97)

parts = []
# Palm and heel of the hand behind the lower right of the phone.
parts.append(egg('Palm behind handset', (.016, -.030, -.024), (.034, .050, .014), skin))
parts.append(egg('Hypothenar heel', (.026, -.062, -.020), (.020, .026, .013), skin))
parts.append(egg('Thenar pad', (-.006, -.058, -.021), (.022, .024, .014), skin))
parts.append(path('Wrist and forearm', [(.012, -.070, -.024), (.016, -.098, -.022), (.024, -.140, -.012), (.042, -.220, .016)], [.021, .020, .023, .028], skin))

# Index (top) to ring finger curl round the right edge; pads just over the rim.
fingers = [(.036, 1.0), (.014, 1.06), (-.008, .98), (-.030, .82)]
tips = []
for i, (y, length) in enumerate(fingers):
    k = length
    base = Vector((.020, y - .004, -.030))
    knuckle = Vector((.036, y - .001, -.027))
    pip = Vector((.0435 + .002 * k, y + .001, -.017))
    dip = Vector((.0445 + .001 * k, y + .002, -.005))
    tip = Vector((.0408, y + .0025, .0032 + .0008 * (i == 1)))
    pts = [base, knuckle, (knuckle + pip) / 2 + Vector((.0015, 0, -.001)), pip, (pip + dip) / 2 + Vector((.0012, 0, 0)), dip, tip]
    w = .0066 * (.92 if i == 3 else 1.)
    radii = [w * 1.12, w * 1.08, w * .98, w * 1.02, w * .9, w * .86, w * .62]
    parts.append(path('Curled finger %d' % (i + 1), [tuple(q) for q in pts], radii, skin))
    tips.append((tip, (tip - dip).normalized()))
# Thumb braces the left edge low down, its pad on the rim.
thumb = [Vector((-.004, -.060, -.024)), Vector((-.026, -.056, -.019)), Vector((-.041, -.048, -.010)), Vector((-.046, -.038, -.001)), Vector((-.043, -.027, .006))]
parts.append(path('Opposed thumb', [tuple(q) for q in thumb], [.0112, .0102, .0094, .0083, .0062], skin))
tips.append((thumb[-1], (thumb[-1] - thumb[-2]).normalized()))
# Little finger under the bottom corner.
little = [Vector((.024, -.064, -.026)), Vector((.034, -.080, -.020)), Vector((.033, -.086, -.008)), Vector((.028, -.0855, .002))]
parts.append(path('Supporting little finger', [tuple(q) for q in little], [.0068, .0062, .0056, .0044], skin))

bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join(); hand = bpy.context.object; hand.name = 'Gripping phone hand'
rem = hand.modifiers.new('Fused skin', 'REMESH'); rem.mode = 'VOXEL'; rem.voxel_size = .0006; rem.use_smooth_shade = True; bpy.ops.object.modifier_apply(modifier=rem.name)
sm = hand.modifiers.new('Relaxed skin', 'SMOOTH'); sm.factor = .45; sm.iterations = 5; bpy.ops.object.modifier_apply(modifier=sm.name)
# Knuckle creases and pore relief straight into the surface.
for v in hand.data.vertices:
    g = Vector((v.co.x, v.co.z, -v.co.y))
    crease = 0.
    for y, _ in fingers:
        crease += math.exp(-((g.y - y) / .006) ** 2) * (math.exp(-((g.x - .0445) / .002) ** 2) * .00045)
    grain = math.sin(g.x * 1900 + math.sin(g.y * 1300)) * math.sin(g.z * 1700) * .00005
    v.co -= v.normal * (crease - grain)
dec = hand.modifiers.new('Budget', 'DECIMATE'); dec.ratio = .35; bpy.ops.object.modifier_apply(modifier=dec.name)
for f in hand.data.polygons: f.use_smooth = True
# Warmer knuckles and fingertips, paler palm side, faint veins at the wrist.
attr = hand.data.color_attributes.new(name='SkinPigment', type='FLOAT_COLOR', domain='POINT')
for i, v in enumerate(hand.data.vertices):
    g = Vector((v.co.x, v.co.z, -v.co.y))
    flush = sum(math.exp(-((g - t).length / .009) ** 2) for t, _ in tips) * .06
    vein = math.exp(-((g.x - .02 - g.y * .1) / .002) ** 2) * (g.y < -.075) * .04
    n = math.sin(g.x * 700 + math.sin(g.y * 500)) * math.sin(g.z * 900) * .015
    attr.data[i].color = (.50 + flush + n, .37 + n - vein * .3, .30 + n * .7 + vein, 1)
node = skin.node_tree.nodes.new('ShaderNodeVertexColor'); node.layer_name = 'SkinPigment'; skin.node_tree.links.new(node.outputs['Color'], p.inputs['Base Color'])

# Nails on the backs of the curled fingertips and the thumb.
for i, (t, d) in enumerate(tips):
    side = Vector((0, 0, 1)) if i < 4 else Vector((-1, 0, 0))
    outward = Vector((1, 0, 0)) if i < 4 else Vector((-.6, 0, .8)).normalized()
    centre = t - d * .004 + outward * (.0058 if i < 4 else .0055)
    plate = egg('Nail plate %d' % i, tuple(centre), (.0012 if i < 4 else .0045, .0052, .0046 if i < 4 else .0012), nail)
box('Tailored dark uniform cuff', (.020, -.128, -.016), (.056, .044, .052), cloth, .011)
path('Folded uniform sleeve', [(.022, -.142, -.012), (.030, -.172, -.002), (.044, -.218, .018), (.060, -.265, .036)], [.028, .031, .034, .037], cloth)
seam = mat('Cuff seam thread', (.085, .10, .077), .97)
for i in range(16):
    box('Cuff topstitch', (-.006 + i * .0033, -.107, .010), (.0016, .0011, .00045), seam, .00015)

# One node per material keeps the close-up to a handful of draw calls.
export('phone-hand.glb')
print('PHONE HAND', len([o for o in bpy.context.scene.objects if o.type == 'MESH']), flush=True)
