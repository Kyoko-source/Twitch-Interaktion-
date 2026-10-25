extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var details: AfterPlayDetails=game.world.details
 var audit:=SceneAudit.placement(game.world)
 verify.call(audit.doors.is_empty(),"New dressing obstructs a doorway: "+JSON.stringify(audit.doors))
 verify.call(audit.art.is_empty(),"New dressing overlaps mounted artwork")
 verify.call(audit.furniture.is_empty(),"New dressing penetrates a wall: "+JSON.stringify(audit.furniture))
 # A collider-only test missed both reported regressions. The visible-geometry
 # audit must also detect a transparent overlay and a non-solid imported prop.
 var overlay: MeshInstance3D=game.world.atmosphere.decal(game.world,2,Vector3(-4.3,1.6,-12.035),Vector2(1.5,3.2))
 verify.call(not SceneAudit.placement(game.world).doors.is_empty(),"Door audit misses a transparent overlay across the opening")
 overlay.free()
 var obstruction: MeshInstance3D=game.world.box(game.world,Vector3(-7.9,.5,-21.5),Vector3(2,1,.9),game.world.materials.wood)
 verify.call(not SceneAudit.placement(game.world).doors.is_empty(),"Door audit misses non-solid furniture in the middle of a hall")
 obstruction.free()
 game.world.passages.restore({"chosen":-1,"open":[true,true]})
 verify.call(SceneAudit.placement(game.world).doors.is_empty(),"Open decision doors obstruct the walkable passage")
 game.world.passages.restore({"chosen":-1,"open":[false,false]})
 if game.world.native_art:
  var roots: Dictionary={}
  for mesh in game.world.native_art.find_children("*","MeshInstance3D",true,false):
   if mesh.get_meta("native_model","")!="cardboard_box_01": continue
   var pivot: Node3D=mesh
   while pivot.get_parent()!=game.world.native_art: pivot=pivot.get_parent()
   roots[pivot.get_instance_id()]=pivot
  for pivot in roots.values():
   var support_ray:=PhysicsRayQueryParameters3D.create(pivot.global_position+Vector3(0,.05,0),pivot.global_position-Vector3(0,1.2,0),1)
   verify.call(not game.get_world_3d().direct_space_state.intersect_ray(support_ray).is_empty(),"Native storage box has no supporting floor: "+str(pivot.global_position))
 verify.call(details.screens.size()==2 and details.clusters.size()>=17,"Detailed arcade and room groups failed to build")
 verify.call(not details.clear_pose(Vector3(7.5,0,16.4)),"Old saves can spawn inside a new arcade cabinet")
 verify.call(details.clear_pose(Vector3(-6.2,0,8.5)) and details.clear_pose(Vector3(-8,0,19.35)),"Safe patrol/elevator saves are rejected")
 for x in [7.5,9.0,11.0]:
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,1.2,14.5),Vector3(x,1.2,16.8),1)
  verify.call(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Arcade cabinet/glass has no collision at "+str(x))
 var crate: Node3D=game.world.annex.find_child("KitchenProduceCrate",true,false)
 var ray:=PhysicsRayQueryParameters3D.create(crate.global_position+Vector3(0,.2,1),crate.global_position+Vector3(0,.2,0),1)
 verify.call(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Produce crate can be walked through")
 game._resume();game.player.position=Vector3(5.8,0,14.5);game.player.velocity=Vector3.ZERO;game.player.rotation.y=0;game.player.camera.rotation.x=0
 Input.action_press("forward");Input.action_press("sprint")
 for frame in range(390): await game.get_tree().physics_frame
 Input.action_release("forward");Input.action_release("sprint")
 verify.call(game.player.position.z< -10.8 and game.player.position.y>-.05,"New furniture blocks the main patrol route")
 game.player.active=false
 var poses: Array=details.clusters.map(func(n):return n.global_transform)
 game.world.set_anomaly("clock_fast")
 verify.call(details.clusters.map(func(n):return n.global_transform)==poses,"Reference dressing changes during an anomaly")
 game._pause();await game.get_tree().process_frame
 var time: float=details.clock
 await game.get_tree().create_timer(.12).timeout
 verify.call(is_equal_approx(time,details.clock) and details.hum.stream_paused,"Arcade screens or hum continue during pause")
 game._resume();await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(details.clock>time and not details.hum.stream_paused,"Arcade atmosphere fails to resume")
 for id in ArchiveState.PAPERS:
  game.world.archive.sync(game.archive,int(ArchiveState.document(id).stage))
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var item: Node3D=game.world.archive.items[id]
  var paper_ray:=PhysicsRayQueryParameters3D.create(item.global_position+Vector3(0,.65,0),item.global_position-Vector3(0,.05,0),5)
  var hit:=game.get_world_3d().direct_space_state.intersect_ray(paper_ray)
  verify.call(not hit.is_empty() and hit.collider.get_meta("interaction","")=="paper:"+id,"Dressing covers a collectible newspaper: "+id)
 game._new_shift();game.intro.skip();game.player.active=false
 verify.call(game.world.details.clusters.map(func(n):return n.global_transform)==poses,"Room dressing is not stable across rounds")
 game.player.position=Vector3(7.5,0,16.4);game._pause();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.player.position.distance_to(Vector3(-6.2,0,8.5))<.1 and game.state.streak==0,"Continue leaves the player inside new furniture or changes the round")
