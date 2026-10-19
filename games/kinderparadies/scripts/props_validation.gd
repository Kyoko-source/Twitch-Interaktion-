extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(ArchiveState.document("note").footer=="","Door note still contains its removed footer")
 var old: Dictionary=game.state.serialize();old.visited=["Partyraum"]
 var restored:=PatrolState.new()
 verify.call(restored.restore(old) and restored.visited==["Party Raum"],"Room rename discards an existing saved patrol")
 var levels: Dictionary={}
 for p in BallPacking.POSITIONS: levels[snappedf(p.y,.01)]=true
 verify.call(levels.size()>15,"Ball pile still consists of regular horizontal rows")
 var audit:=SceneAudit.inspect(game.world)
 verify.call(audit.ball_min_distance>.28,"Randomized ball pile intersects")
 game.world.set_anomaly("balls_float");game.world.tick(.6,true)
 verify.call(SceneAudit.inspect(game.world).ball_min_distance>.28,"Floating balls collide with one another")
 # Mesh triangles point into the cup on its inner wall. Looking into the pot
 # and bucket must show real textured material instead of back-face culling.
 for cup in [game.world.annex.get_node("CookingPot"),game.world.atmosphere.find_child("BucketCup",true,false)]:
  var mesh: MeshInstance3D=cup.get_node("Interior")
  var arrays: Array=mesh.mesh.surface_get_arrays(0);var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var inward:=0
  for i in range(vertices.size()):
   var horizontal:=Vector3(vertices[i].x,0,vertices[i].z)
   if horizontal.dot(normals[i])<-.01: inward+=1
  verify.call(inward>100 and mesh.material_override.albedo_texture!=null,"Cup has no textured inward-facing wall: "+str(cup.name))
 var cut:=PhysicsRayQueryParameters3D.create(Vector3(-16.63,1.6,-16.65),Vector3(-16.63,.88,-16.65),1)
 verify.call(game.get_world_3d().direct_space_state.intersect_ray(cut).is_empty(),"Countertop collision fills the recessed sink")
 var kitchen: Array=[]
 for bulb in game.world.room_horror.bulbs:
  if bulb.get("kitchen",false): kitchen.append(bulb)
 game.world.room_horror.clock=6.7;game.world.room_horror.tick(.01,true)
 verify.call(kitchen.size()==2 and kitchen.all(func(b):return b.light.light_energy<b.energy*.6),"Kitchen fixture and bounce light do not flicker together")
 game._build_world("none");game._resume()
 game.player.position=Vector3(-8.7,0,-5.4);game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO
 Input.action_press("forward")
 for frame in range(95): await game.get_tree().physics_frame
 Input.action_release("forward")
 verify.call(game.player.position.x< -12.0 and game.world.server_room.safe_pose(game.player.position),"Server room doorway cannot be entered by walking")
 game._pause();var pose: Vector3=game.player.position;game._main_menu();game.has_session=false;game._continue()
 verify.call(game.player.position.distance_to(pose)<.05,"Continue rejects a position inside the server room")
 game.player.rotation.y=-PI/2;Input.action_press("forward")
 for frame in range(110): await game.get_tree().physics_frame
 Input.action_release("forward")
 verify.call(game.player.position.x> -9.8,"Player cannot leave the server room")
 game._build_world("none");game._resume()
