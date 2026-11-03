extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false
 var guard: NightGuard=g.player;var attraction: Node3D=g.world.playground.inflatable
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 var body:=g.world.playground.inflatable_skin.get_node("CrocBodyContact") as StaticBody3D
 var collision: CollisionShape3D=body.get_child(0)
 verify.call(collision.shape is ConcavePolygonShape3D and collision.shape.get_faces().size()/3<=750,"Crocodile still uses its detailed visual mesh for contact")
 var jaw:=g.world.playground.croc_jaw.get_node("CrocJawContact") as StaticBody3D
 var rest:=jaw.global_transform;g.world.playground.set_croc_jaw(.3)
 verify.call(not jaw.global_transform.is_equal_approx(rest),"Simplified jaw collision no longer follows the hinge");g.world.playground.set_croc_jaw(0)
 for z in [-.5,-2.,-4.]:
  var top:=attraction.to_global(Vector3(0,4,z))
  var ray:=PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*4,1,[guard.get_rid()])
  var hit:=g.get_world_3d().direct_space_state.intersect_ray(ray)
  verify.call(not hit.is_empty() and hit.collider==body,"Crocodile back or tail has a collision hole at "+str(z))
  if hit.is_empty():continue
  guard.position=hit.position+Vector3.UP*.5;guard.velocity=Vector3.ZERO;guard.active=true
  for i in range(65):await g.get_tree().physics_frame
  verify.call(guard.is_on_floor() and absf(guard.position.y-hit.position.y)<.08,"Guard falls through the crocodile at "+str(z))
  guard.active=false
 guard.position=attraction.to_global(Vector3(0,2.8,-.5));guard.velocity=Vector3.ZERO;guard.active=true
 for i in range(45):await g.get_tree().physics_frame
 var landings:=0
 for jump in range(3):
  var height:=guard.position.y;var peak:=height
  var event:=InputEventAction.new();event.action="jump";event.pressed=true;guard._unhandled_input(event)
  for i in range(55):await g.get_tree().physics_frame;peak=maxf(peak,guard.position.y)
  if guard.is_on_floor() and peak>height+.65:landings+=1
 verify.call(landings==3 and FootSurfaces.at(guard)=="rubber","Repeated jumps on the crocodile fail to land or use the wrong surface")
 guard.active=false
 # Reproduce the skipped reveal using real movement, without turning the
 # camera away and back. Include crouching/backwards and an old outside save.
 for mode in ["forward","backwards_crouched","outside_save"]:
  g._new_shift();g.intro.skip();guard=g.player;guard.active=false
  g.archive.try_code("0712");g.archive.ending="armed";g.archive.recording_position=280.;g.world.archive.sync(g.archive,1)
  var finale: ArchiveFinale=g.world.archive.finale
  guard.position=Vector3(-11.3,0,-9.9);guard.velocity=Vector3.ZERO;guard.rotation.y=PI/2 if mode=="backwards_crouched" else -PI/2;guard.camera.rotation=Vector3.ZERO
  await g.get_tree().physics_frame;await g.get_tree().physics_frame
  if mode=="outside_save":
   guard.position=Vector3(-8.7,0,-9.9);g._save();g.has_session=false;g._continue();guard.active=false;finale=g.world.archive.finale
   finale.tick(.1,true)
  else:
   g._pause();finale.tick(.2,false);verify.call(finale.trigger_count==0,"Armed finale triggers while paused: "+mode)
   g._resume();guard.active=true
   var action:="back" if mode=="backwards_crouched" else "forward"
   Input.action_press(action);Input.action_press("crouch" if mode=="backwards_crouched" else "sprint")
   for i in range(100):
    await g.get_tree().physics_frame
    if g.phase=="archive_scare":break
   Input.action_release(action);Input.action_release("crouch");Input.action_release("sprint")
   verify.call(guard.position.x<LostArchive.ENTRY.x,"Guard crosses the archive doorway before the reveal: "+mode)
  verify.call(g.phase=="archive_scare" and g.archive.ending=="complete" and finale.trigger_count==1,"Finale can still be bypassed: "+mode)
  finale.tick(.1,true);verify.call(finale.trigger_count==1,"Finale repeats during its scare: "+mode)
  g.door_failure.tick(1.2);await g.get_tree().process_frame
  verify.call(g.phase=="ending" and g.end_credits.ending_number==2,"Exit fallback does not lead to ending 2: "+mode)
  await g.end_credits.wait_prepared()
 g._new_shift();g.intro.skip();g.player.active=false
