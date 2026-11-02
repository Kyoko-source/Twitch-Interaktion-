extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var helper=load("res://scripts/reception_validation.gd").new()
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 # Full standing capsule crosses the reported front edge without jump input,
 # including the old blocked approach in front of the birthday throne.
 for x in [12.0,12.4,14.9,15.6,17.3,17.85]:
  verify.call(await helper.walk(game,Vector3(x,.12,-9.1),Vector3(x,.2,-10.25),90),"Stage front blocks walking up at x="+str(x)+": "+str(game.player.position))
  verify.call(FootSurfaces.at(game.player)=="wood","Stage apron lost wood footsteps at x="+str(x))
  verify.call(await helper.walk(game,Vector3(x,.2,-10.25),Vector3(x,.03,-8.65),100),"Stage front blocks walking down at x="+str(x)+": "+str(game.player.position))
 verify.call(await helper.walk(game,Vector3(12,0,-8.0),Vector3(12,.2,-10.25),125),"Full floor-to-stage approach still requires a jump")
 verify.call(await helper.walk(game,Vector3(17.3,0,-8.3),Vector3(17.3,.2,-14),175),"Widened ramp blocks entering the costume room")
 verify.call(await helper.walk(game,Vector3(17.3,.2,-14),Vector3(17.3,0,-8.3),175),"Widened ramp blocks returning from the costume room")
 var clear:=true
 for mesh in game.world.props.car.find_children("*","MeshInstance3D",true,false):
  var bounds: AABB=mesh.global_transform*mesh.get_aabb()
  if bounds.end.z> -6.2 or bounds.end.x>5.8:clear=false
 verify.call(clear and game.world.props.car.position.z< -6.5,"Car is not beside the party-facing end of the play structure")
 verify.call(await helper.walk(game,Vector3(5.9,0,-8.7),Vector3(8.0,0,-8.7),100),"Moved car obstructs the party entrance")
 var report:=SceneAudit.placement(game.world)
 verify.call(report.doors.is_empty() and report.art.is_empty() and report.furniture.is_empty(),"Movement fix intersects furniture or a doorway: "+JSON.stringify(report))
 for id in ["car_giant","car_missing"]:
  game._build_world(id);game.player.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var car: Node3D=game.world.props.car
  verify.call(car.position==PlayWorld.CAR_POS and (car.scale.x>2.5 if id=="car_giant" else not car.visible),"Moved car anomaly has a stale origin: "+id)
  var overlap:=false
  if id=="car_giant":
   for mesh in car.find_children("*","MeshInstance3D",true,false):
    var bounds: AABB=mesh.global_transform*mesh.get_aabb()
    for wall in game.world.find_children("*","MeshInstance3D",true,false):
     if wall.has_meta("architecture_wall") and bounds.intersects(wall.global_transform*wall.get_aabb()):overlap=true
  verify.call(not overlap,"Giant car intersects a room wall")
  verify.call(await helper.walk(game,Vector3(5.9,0,-8.7),Vector3(8.0,0,-8.7),100),"Car anomaly obstructs the party doorway: "+id)
