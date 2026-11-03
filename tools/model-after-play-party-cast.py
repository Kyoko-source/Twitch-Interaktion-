"""Clean, articulated version of the project's original sewn rabbit. Blender 4.5."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
source = Path(__file__).with_name('model-nachtwache-heroes.py')
exec(compile(source.read_text(encoding='utf-8').split("export('stitched-rabbit')")[0], str(source), 'exec'), globals())
destination = ROOT / 'games/kinderparadies/assets/celebration-v3813'
destination.mkdir(parents=True, exist_ok=True)

# Export geometry and simple materials only. Godot reuses existing cloth maps;
# do not embed duplicate textures in the already tightly sized web package.
for material in bpy.data.materials:
    if material.node_tree:
        for node in list(material.node_tree.nodes):
            if node.type == 'TEX_IMAGE': material.node_tree.nodes.remove(node)
    material.name = 'Party ' + material.name

def pivot(name, position):
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.location = position
    return empty

root = pivot('CelebrationRabbit', (0, 0, 0))
rigs = {'HeadRig': pivot('HeadRig', (0, -.025, .77)),
        'ArmL': pivot('ArmL', (-.255, -.01, .43)),
        'ArmR': pivot('ArmR', (.255, -.01, .43)),
        'LegL': pivot('LegL', (-.17, -.1, .10)),
        'LegR': pivot('LegR', (.17, -.1, .10))}
for rig in rigs.values(): rig.parent = root
bpy.context.view_layer.update()
objects = [o for o in bpy.context.scene.objects if o.type in {'MESH', 'CURVE'}]
for obj in objects:
    name = obj.name
    if any(part in name for part in ['head', 'ear', 'Button', 'button', 'Muzzle', 'nose', 'smile']):
        parent = rigs['HeadRig']
    elif 'Slumped arm' in name:
        parent = rigs['ArmL' if obj.location.x < 0 else 'ArmR']
    elif 'paw' in name:
        parent = rigs['LegL' if obj.location.x < 0 else 'LegR']
    else: parent = root
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()

# Join per joint, retaining material groups and the original toy's silhouette.
for parent in [root] + list(rigs.values()):
    children = [o for o in bpy.context.scene.objects if o.type in {'MESH', 'CURVE'} and o.parent == parent]
    if not children: continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in children: obj.select_set(True)
    bpy.context.view_layer.objects.active = children[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    mesh = bpy.context.view_layer.objects.active
    mesh.name = parent.name + 'Cloth'
    modifier = mesh.modifiers.new('Portable celebration mesh', 'DECIMATE')
    modifier.ratio = .30
    bpy.ops.object.modifier_apply(modifier=modifier.name)

bpy.ops.export_scene.gltf(filepath=str(destination / 'celebration-rabbit.glb'),
                          export_format='GLB', export_apply=True,
                          export_cameras=False, export_lights=False)
print('AUTHORED celebration-rabbit.glb', flush=True)
