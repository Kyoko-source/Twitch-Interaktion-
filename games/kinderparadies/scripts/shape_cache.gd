class_name ShapeCache
extends RefCounted

# 4.8.1 load time: triangle collision shapes were rebuilt from the same
# geometry on every round change. Geometry that is identical across rounds
# (imported models, primitive meshes with the same parameters, the world's
# shared bevel boxes) now reuses its shape. One-off geometry is still built
# fresh, so the cache cannot grow from round to round.
static var trimeshes:={}
static var keep:={}

static func _key(mesh: Mesh) -> String:
 if not mesh.resource_path.is_empty(): return mesh.resource_path
 if mesh is PrimitiveMesh:
  var parts:=[mesh.get_class()]
  for property in mesh.get_property_list():
   if property.usage & PROPERTY_USAGE_STORAGE and property.type in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_STRING]:
    parts.append("%s=%s"%[property.name,mesh.get(property.name)])
  return "|".join(parts)
 if mesh in PlayWorld.shared_bevels.values(): keep[mesh.get_instance_id()]=mesh;return "bevel:%d"%mesh.get_instance_id()
 return ""

static func trimesh(mesh: Mesh) -> Shape3D:
 var key:=_key(mesh)
 if key.is_empty(): return mesh.create_trimesh_shape()
 if not trimeshes.has(key): trimeshes[key]=mesh.create_trimesh_shape()
 return trimeshes[key]
