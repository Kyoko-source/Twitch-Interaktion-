"""Derive collision-only meshes from the unchanged, authored crocodile."""
import bpy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'games/kinderparadies/assets/croc-v385'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(out / 'crocodile.glb'))
report = {}
keep = []
for name, budget in [('Body', 700), ('UpperJaw', 180)]:
    obj = bpy.data.objects[name]
    # Detach from imported hierarchy while preserving the exact asset pose.
    matrix = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = matrix
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    triangles = sum(len(face.vertices) - 2 for face in obj.data.polygons)
    modifier = obj.modifiers.new('Contact mesh only', 'DECIMATE')
    modifier.ratio = budget / triangles
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.clear()
    # Visual textures and decorative teeth do not belong in the contact asset.
    report[name] = {'source_triangles': triangles,
                    'collision_triangles': sum(len(face.vertices) - 2 for face in obj.data.polygons)}
    keep.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in keep:
    obj.select_set(True)
bpy.context.view_layer.objects.active = keep[0]
bpy.ops.export_scene.gltf(filepath=str(out / 'collision.glb'), export_format='GLB',
                           use_selection=True, export_materials='NONE',
                           export_normals=False, export_texcoords=False,
                           export_animations=False, export_cameras=False, export_lights=False)
print('CROC CONTACT MESH ' + json.dumps(report), flush=True)
