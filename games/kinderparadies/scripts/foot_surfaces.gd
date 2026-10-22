class_name FootSurfaces
extends RefCounted

const ROOT:="res://assets/surfaces/"
const TYPES:=["concrete","carpet","wood","metal","rubber","plastic"]

static func at(player: CharacterBody3D) -> String:
 var query:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.13,player.global_position-Vector3.UP*.30,1)
 query.exclude=[player.get_rid()]
 var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty() or hit.normal.y<.5: return "concrete"
 var node: Node=hit.collider
 while node!=null:
  if node.has_meta("foot_surface"): return str(node.get_meta("foot_surface"))
  if node is PlayWorld and node.polish: return node.polish.surface_at(hit.position)
  node=node.get_parent()
 return "concrete"

static func tag(w: PlayWorld) -> void:
 w.props.structure.set_meta("foot_surface","rubber")
 w.props.slide.set_meta("foot_surface","plastic")
 w.props.play_threshold.set_meta("foot_surface","rubber")
 w.playground.get_node("EastTower").set_meta("foot_surface","rubber")
 w.playground.get_node("ConnectingBridge").set_meta("foot_surface","wood")
 w.tubes.set_meta("foot_surface","plastic")
