extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var w: PlayWorld=game.world
 var mismatch: Array[String]=[];var count:=0
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.has_meta("solid_visual"): continue
  count+=1
  var shape:=mesh.get_node("Solid").get_child(0) as CollisionShape3D
  if not shape.global_transform.is_equal_approx(mesh.global_transform): mismatch.append(str(mesh.get_path()))
 verify.call(count>150 and mismatch.is_empty(),"Box colliders are offset from their rendered objects: "+str(mismatch))
 # Rotate and translate an actual solid prop after creation, then cast against it.
 var probe:=w.box(w,Vector3(-4,1,12),Vector3(1,.2,.3),w.materials.wood,true)
 probe.rotation.z=.42;probe.position.x+=.3
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var ray:=PhysicsRayQueryParameters3D.create(probe.global_position+Vector3.UP,probe.global_position-Vector3.UP,1);ray.exclude=[game.player.get_rid()]
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
 verify.call(not hit.is_empty() and hit.collider.get_parent()==probe,"A moved/rotated prop leaves its collision behind")
 probe.queue_free();await game.get_tree().physics_frame
 var samples: Array[Dictionary]=[
  {"p":Vector3(-6,0,8),"type":"concrete"},
  {"p":Vector3(-3,0,-17.65),"type":"carpet"},
  {"p":Vector3(-12.2,0,-4.6),"type":"metal"},
  {"p":w.props.structure.to_global(Vector3(1,.3,-4.5)),"type":"rubber"},
  {"p":CrawlTubes.route(6.0)-Vector3.UP*.72,"type":"plastic"},
  {"p":Vector3(7.5,PlayGeometry.bridge_height((7.5-4.43)/6.07),3.6),"type":"wood"}]
 for sample in samples:
  game.player.position=sample.p;game.player.velocity=Vector3.ZERO
  await game.get_tree().physics_frame
  verify.call(FootSurfaces.at(game.player)==sample.type,"Wrong actual floor surface at "+str(sample.p)+": "+FootSurfaces.at(game.player))
  game.player.play_step();var previous: AudioStream=game.player.step_player.stream;game.player.play_step()
  verify.call(game.player.step_player.stream!=previous and game.player.step_player.stream.get_length()>.07,"Repeated/missing recorded step for "+sample.type)
  game.player.step_player.stop()
 game.player.position=Vector3(-6,0,8)
 game.player.capture();game.player.look_warmup=0.0
 var old_yaw: float=game.player.rotation.y;var old_pitch: float=game.player.camera.rotation.x
 game.player.apply_mouse_look(Vector2(800,400))
 verify.call(is_equal_approx(game.player.rotation.y,old_yaw) and is_equal_approx(game.player.camera.rotation.x,old_pitch),"Late pointer-lock recenter rotates the view after its warmup")
 game.player.apply_mouse_look(Vector2(10,5))
 verify.call(not is_equal_approx(game.player.rotation.y,old_yaw) and not is_equal_approx(game.player.camera.rotation.x,old_pitch),"Pointer-lock guard suppresses genuine mouse input")
 game.player.release()
 # Standing capsule traversal, at centre and both sides of every narrow doorway.
 var routes: Array[Dictionary]=[
  {"p":Vector3(5.8,0,-8.7),"yaw":-PI/2,"axis":0,"limit":7.4,"greater":true,"name":"party entry"},
  {"p":Vector3(7.8,0,-8.7),"yaw":PI/2,"axis":0,"limit":6.0,"greater":false,"name":"party exit"},
  {"p":Vector3(-8.0,0,-17.65),"yaw":PI/2,"axis":0,"limit":-10.4,"greater":false,"name":"kitchen entry"},
  {"p":Vector3(-10.5,0,-17.65),"yaw":-PI/2,"axis":0,"limit":-8.6,"greater":true,"name":"kitchen exit"},
  {"p":Vector3(-7.7,0,-17.65),"yaw":-PI/2,"axis":0,"limit":-5.5,"greater":true,"name":"cinema entry"},
  {"p":Vector3(-5.0,0,-17.65),"yaw":PI/2,"axis":0,"limit":-7.3,"greater":false,"name":"cinema exit"},
  {"p":Vector3(-8.8,0,-5.4),"yaw":PI/2,"axis":0,"limit":-11.3,"greater":false,"name":"server entry"},
  {"p":Vector3(-11.7,0,-5.4),"yaw":-PI/2,"axis":0,"limit":-9.6,"greater":true,"name":"server exit"}]
 for route in routes:
  for offset in [-.30,0,.30]:
   game.player.position=route.p+Vector3(0,0,offset);game.player.velocity=Vector3.ZERO;game.player.rotation.y=route.yaw;game.player.set_crouch(false);game.player.active=true
   Input.action_press("forward")
   for frame in range(78): await game.get_tree().physics_frame
   Input.action_release("forward");game.player.active=false
   var position: float=game.player.position[route.axis]
   verify.call(position>route.limit if route.greater else position<route.limit,"Standing player is trapped at "+route.name+" offset "+str(offset)+" ended at "+str(game.player.position))
   verify.call(game.player.position.y>-.05,"Door threshold drops the player below the floor: "+route.name)
 var party_bounds:=AABB()
 verify.call(w.polish.find_children("*MascotCorner","Node3D",true,false).size()==1 and not w.polish.has_node("MascotCorner"),"Giant rabbit must exist only once, in the party room")
 for visual in [w.polish.party_mascot]:
  var bounds:=AABB();var first:=true;var textile:=false
  for mesh in visual.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
   for i in range(mesh.mesh.get_surface_count()):
    var material:=mesh.get_active_material(i) as StandardMaterial3D
    if material and material.albedo_texture and material.resource_name.begins_with("Worn oatmeal") and material.roughness>.9: textile=true
  verify.call(bounds.size.y>4.5 and bounds.end.y<7.3 and bounds.end.x<19.65 and bounds.end.z<17.05 and textile,"Sewn mascot exceeds the room or is missing its approved plush surface: "+str(bounds))
  var corner:=visual.get_parent() as Node3D
  for point in [Vector3(.055,2.92,.091),Vector3(-1.0,1.28,.036),Vector3(1.0,1.28,.036)]:
   var query:=PhysicsRayQueryParameters3D.create(corner.to_global(point+Vector3(0,0,1)),corner.to_global(point-Vector3(0,0,1)),1)
   query.exclude=[game.player.get_rid()]
   var contact:=game.get_world_3d().direct_space_state.intersect_ray(query)
   verify.call(not contact.is_empty() and corner.is_ancestor_of(contact.collider),"Mascot head/arm has no matching collision at "+str(point))
  if visual==w.polish.party_mascot: party_bounds=bounds
 verify.call(w.polish.party_mascot.get_parent().position.distance_to(AfterPlayPolish.PARTY_MASCOT_POS)<.01,"Party mascot is not against the right-hand wall")
 for unit in w.find_children("*","Node3D",true,false):
  if str(unit.name) not in ["StockedShelf","PartySideboard"]: continue
  for mesh in unit.find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree(): continue
   verify.call(not party_bounds.grow(.03).intersects(mesh.global_transform*mesh.get_aabb()),"Party mascot overlaps a real shelf or sideboard: "+str(mesh.get_path()))
 verify.call(w.polish.get_node("MaintenancePipework").get_child_count()>10 and w.annex.get_node("CinemaRestoration").get_child_count()>25,"Expanded maintenance/cinema dressing failed to build")
 game._new_shift();game.intro.tick(1.4);await game.get_tree().process_frame
 verify.call(game.intro.display.viewport.size==Vector2i(360,760) and game.intro.display.state_label.text=="Eingehender Anruf","Phone does not show a legible live incoming-call interface")
 game.intro.accept();game.intro.tick(2.0)
 verify.call(game.intro.display.state_label.text=="Verbunden" and game.intro.display.timer_label.text=="00:02","Phone interface does not follow the actual chief call")
 game.intro.skip();game._pause()
 verify.call(not game.player.step_player.playing,"Footsteps continue under pause")
 game._new_shift();game.intro.skip()
