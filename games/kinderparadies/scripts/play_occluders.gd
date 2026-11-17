class_name PlayOccluders
extends RefCounted

# 4.8.0 performance: walls and other big solid, opaque boxes become occluders,
# so the renderer stops issuing draw calls for whole rooms hidden behind them.
# Occlusion culling only skips what is truly covered; every occluder is shrunk
# a little inside its box so edges, doorways and gaps can never hide anything
# that is actually visible. Occluders follow their box: hidden or moved boxes
# take their occluder with them.

const INSET:=.03
const MIN_FACE:=.9

static func _opaque(mesh: MeshInstance3D) -> bool:
 if mesh.transparency>0. or mesh.material_overlay: return false
 var m:=mesh.get_active_material(0)
 if not (m is BaseMaterial3D): return false
 var b:=m as BaseMaterial3D
 return b.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and b.albedo_color.a>=.999 and not b.next_pass

static func candidate(mesh: MeshInstance3D) -> bool:
 if not (mesh.get_meta("architecture_wall",false) or mesh.get_meta("solid_visual",false)): return false
 if mesh.mesh==null or mesh.mesh.get_surface_count()!=1 or not _opaque(mesh): return false
 var size:=mesh.get_aabb().size
 var dims:=[size.x,size.y,size.z];dims.sort()
 return dims[1]>=MIN_FACE and dims[0]>INSET*2.5

static func apply(root: Node3D) -> int:
 var made:=0
 for node in root.find_children("*","MeshInstance3D",true,false):
  var mesh:=node as MeshInstance3D
  if not candidate(mesh): continue
  var box:=mesh.get_aabb();var shape:=BoxOccluder3D.new();shape.size=box.size-Vector3.ONE*INSET*2.
  var occluder:=OccluderInstance3D.new();occluder.name="Occluder";occluder.occluder=shape;occluder.position=box.get_center()
  mesh.add_child(occluder);made+=1
 return made
