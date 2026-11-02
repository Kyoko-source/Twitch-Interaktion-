extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var decay: WallDecay=game.world.wall_decay
 verify.call(decay.walls.size()>=7,"Plaster treatment does not reach the selected rooms")
 verify.call(decay.find_children("*","MeshInstance3D",true,false).is_empty() and decay.find_children("*","CollisionShape3D",true,false).is_empty(),"Wall damage adds floating planes or changes collision")
 var intact:=true
 for wall in decay.walls:
  if wall.material_overlay!=decay.finish or wall.material_override!=decay.original_materials[wall.get_instance_id()]:intact=false
 verify.call(intact,"Wall treatment replaces the base wall material")
 var rooms: Dictionary={}
 for spec in WallDecay.PATCHES:
  rooms[spec.room]=true
  var covered:=false
  for wall in decay.walls:
   var bounds: AABB=wall.global_transform*wall.get_aabb()
   var face: float=bounds.end.x if spec.n.x>0 else bounds.position.x if spec.n.x<0 else bounds.end.z
   var target: float=spec.p.x if absf(spec.n.x)>.5 else spec.p.z
   if bounds.grow(.015).has_point(spec.p) and absf(face-target)<.015:covered=true
  verify.call(covered,"Damage is not attached to the visible wall face: "+str(spec.p))
 verify.call(rooms.size()==5,"The whole venue receives the same damage instead of selected areas")
 for channel in ["albedo_map","normal_map","rough_map"]:
  var texture: Texture2D=decay.finish.get_shader_parameter(channel)
  verify.call(texture!=null and texture.resource_path.contains("/desktop/"),"Missing photographed PBR map: "+channel)
 var count: int=decay.finish.get_shader_parameter("patch_count")
 game.world.tick(80,true)
 verify.call(count==WallDecay.PATCHES.size() and game.world.current=="none","Reference damage behaves like an anomaly")
 var placement:=SceneAudit.placement(game.world)
 verify.call(placement.doors.is_empty() and placement.art.is_empty() and placement.furniture.is_empty(),"Wall treatment blocks a door, artwork or furniture")
 print("WALL FINISH ",decay.walls.size()," meshes / ",WallDecay.PATCHES.size()," patches / ",rooms.size()," rooms")
