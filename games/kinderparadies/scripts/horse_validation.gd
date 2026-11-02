extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var horse: CeilingHorse=w.room_horror.creature;horse.debug_hold=true
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(horse.jaw!=null and horse.mask.find_children("*","MeshInstance3D",true,false).size()==8,"Horse mask lost its articulated head or joined surfaces")
 var bounds:=horse.head_bounds()
 verify.call(bounds.size.x<.7 and bounds.size.z>1.5 and bounds.size.y<1.5,"Equine model has a torso or incorrect anatomical scale")
 verify.call(horse.find_children("*","CollisionShape3D",true,false).is_empty(),"Atmospheric ceiling creature blocks the player")
 var missing:=true
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.get_meta("mounted_art",false) and (mesh.global_position.distance_to(Vector3(-10.65,2.25,-34.385))<.15 or mesh.global_position.distance_to(Vector3(-7.9,2.3,-34.425))<.15): missing=false
 verify.call(missing,"Marked kitchen or end-wall notice remains mounted")
 var panels: Array[MeshInstance3D]=[]
 for mesh in w.room_horror.find_children("*","MeshInstance3D",true,false):
  if mesh.get_meta("ceiling_panel",false):panels.append(mesh)
 var complete:=true
 for i in range(81):
  var point:=Vector3(-7.9,3.535,lerpf(-34.2,-12.3,i/80.0));var covered:=false
  for mesh in panels:
   if (mesh.global_transform*mesh.get_aabb()).grow(.018).has_point(point):covered=true;break
  if not covered:complete=false
 verify.call(complete,"Corridor ceiling changes height or leaves an untiled gap")
 var fixed:=horse.to_global(CeilingHorse.SOURCE);var clearance:=true;var issue:="";var neck_inside:=true
 var movements:=PackedVector3Array()
 for step in range(41):
  horse.pose(step/40.0);movements.append(horse.mask.global_position)
  if horse.to_global(Vector3(horse.samples[0].x,horse.samples[0].y,horse.samples[0].z)).distance_to(fixed)>.001:neck_inside=false
  for p in horse.samples:
   var point:=horse.to_global(Vector3(p.x,p.y,p.z))
   if point.y+p.w>3.50 and not RoomHorror.SHAFT.grow(-.12).has_point(Vector2(point.x,point.z+12)):clearance=false;issue="Neck leaves ceiling aperture at "+str(point)
   if absf(point.x+6.4)<.18 and (point.y+p.w>2.54 or point.z-p.w< -30.6 or point.z+p.w> -28.7):clearance=false;issue="Neck crosses cinema lintel at "+str(point)
  # Test real deformed jaw/head vertices at the wall, not a conservative AABB.
  for mesh in horse.mask.find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:
     var point: Vector3=mesh.to_global(vertex)
     if absf(point.x+6.4)<.11 and (point.y>2.54 or point.z< -30.6 or point.z> -28.7):clearance=false;issue="Mask crosses cinema wall at "+str(point)+" progress "+str(step/40.0)
 verify.call(neck_inside and fixed.y>3.9,"Neck is not anchored inside the dark shaft")
 verify.call(clearance,"Creature clips the ceiling or doorway: "+issue)
 verify.call(movements[0].distance_to(movements[-1])>5 and movements[-1].x< -7,"Horse never travels from the shaft into the corridor")
 horse.debug_hold=false;horse.clock=26;horse.tick(.1,true)
 verify.call(horse.progress==1 and horse.mask.global_position.x< -7,"Natural animation never peeks out of the cinema")
 var transform:=horse.mask.transform;var jaw_angle:=horse.jaw.rotation.x;var time:=horse.clock
 horse.tick(2,false)
 verify.call(horse.mask.transform==transform and horse.jaw.rotation.x==jaw_angle and horse.clock==time,"Ceiling creature ignores pause")
 verify.call(w.current=="none" and w.terrors.spec.is_empty(),"Normal horse motion introduces an anomaly into a newspaper round")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Scene corrections obstruct circulation or wall artwork: "+JSON.stringify(layout))
 game._build_world("vent_strike");game.player.active=false;horse=game.world.room_horror.creature
 horse.clock=26;horse.tick(.1,true);var home:=horse.mask.position
 horse.attack_gain=1;horse.tick(.1,true)
 verify.call(horse.progress==0 and horse.mask.position.y<home.y-.4 and horse.position==Vector3(-1.3,3.4,-20.15),"Vent attack drags the entire neck out of the shaft")
 horse.attack_gain=0;horse.tick(.1,true)
 verify.call(horse.mask.position.distance_to(home)<.02,"Horse attack does not recover its home pose")
 print("HORSE GEOMETRY ",bounds," SOURCE ",fixed," CLEARANCE ",clearance," ",issue)
