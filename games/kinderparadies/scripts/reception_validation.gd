extends RefCounted

func walk(game: Node3D,from: Vector3,to: Vector3,frames: int=120) -> bool:
 var guard: NightGuard=game.player;guard.position=from;guard.velocity=Vector3.ZERO
 guard.rotation.y=atan2(-(to.x-from.x),-(to.z-from.z));guard.active=true
 Input.action_press("forward")
 for i in range(frames):
  await game.get_tree().physics_frame
  if guard.position.distance_to(to)<.18:break
 Input.action_release("forward");guard.active=false
 return guard.position.distance_to(to)<.24

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var guard: NightGuard=game.player
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var desk: Node3D=w.props.counter;var chair: Node3D=w.props.reception_chair
 verify.call(desk.global_basis.x.dot(Vector3.BACK)>.99,"The customer side of reception does not face the entrance")
 verify.call(chair.position.z<desk.position.z-.8 and chair.position.distance_to(desk.position)<1.4,"Office chair is not behind the counter")
 verify.call(chair.get_node("SimpleOfficeChairCollision").get_child_count()==2,"Office chair uses detailed snagging collisions")
 var pc: Node3D=desk.get_node("ReceptionPC")
 verify.call(pc.global_basis.z.dot(Vector3.FORWARD)>.99,"Monitor faces visitors instead of the staff chair")
 verify.call(desk.is_ancestor_of(w.find_child("ReceptionDeskLight",true,false)),"The desk lamp's light remains at the old counter location")
 verify.call(w.props.clock.position.y>3 and absf(w.props.clock.position.z-w.props.reception_noticeboard.position.z)<.1 and absf(w.props.hours.position.z-5.5)<.1,"Wall items did not follow the annotated arrangement")
 verify.call(not w.graphics.clear_pose(PlayWorld.RECEPTION_POS) and not w.graphics.clear_pose(chair.position) and w.graphics.clear_pose(Vector3(-8.8,0,9.4)),"Saved positions accept the newly occupied counter/chair or reject the entrance")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"New reception obstructs architecture: "+JSON.stringify(layout))
 verify.call(await walk(game,Vector3(-11.3,0,9.4),Vector3(-6.3,0,9.4)),"The counter blocks entering from the main entrance")
 verify.call(await walk(game,Vector3(-6.3,0,9.4),Vector3(-6.3,0,6.75)),"The counter blocks walking around its end")
 verify.call(await walk(game,Vector3(-6.3,0,6.75),Vector3(-7.4,0,6.75)),"The staff side cannot be reached without jumping")
 await walk(game,Vector3(-8.15,0,9.4),Vector3(-8.15,0,6.72),65)
 verify.call(guard.position.z>8.5,"Walking into the counter penetrates its moved collision")
 guard.position=Vector3(-7.4,.02,6.75);guard.velocity=Vector3.ZERO;guard.camera.look_at(w.watch.display.global_position)
 await game.get_tree().physics_frame
 verify.call(game._target()=="reception_cctv","The relocated monitor cannot be used beside the staff chair")
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)
 verify.call(game.phase=="surveillance" and w.watch.opened,"E does not open the relocated live monitor")
 game._close_watch();guard.active=false
 # Inspect the three relocated encounters against actual physics, then find a
 # reachable, unobstructed viewpoint that activates each real trigger.
 for id in ["reception_counter_burst","reception_peeker","reception_queue"]:
  game._build_world(id);game.player.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var terror: NightTerrors=game.world.terrors;var shape:=terror.actor.get_child(1) as CollisionShape3D
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=1;query.exclude=[guard.get_rid(),terror.actor.get_rid()]
  verify.call(game.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"Reception encounter spawns inside furniture: "+id)
  var found:=false
  for offset in [Vector3(1.5,0,0),Vector3(0,0,-1.5),Vector3(0,0,2.2),Vector3(2.2,0,.5)]:
   guard.position=terror.origin+offset;guard.position.y=.02
   var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=guard.capsule;capsule.transform=Transform3D(Basis.IDENTITY,guard.position+Vector3.UP*.85);capsule.collision_mask=1;capsule.exclude=[guard.get_rid(),terror.actor.get_rid()]
   if not game.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty():continue
   guard.camera.look_at(terror.focus_point());terror.elapsed=0;terror.tick(1,true,guard)
   if terror.triggered:found=true;break
  verify.call(found,"No walkable viewpoint triggers the relocated encounter: "+id)
