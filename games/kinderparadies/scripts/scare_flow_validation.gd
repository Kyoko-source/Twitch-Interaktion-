extends RefCounted

# 4.7.0: plays every running visitor's whole jumpscare frame by frame from real
# approach positions in the level. A ground visitor must reach the guard's face
# (never stall a metre out), and every visitor must be gone afterwards.
func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 for id in NightTerrors.SCENARIOS:
  var mode: String=NightTerrors.SCENARIOS[id].mode
  if mode not in NightTerrors.CHARGE and mode!="crossing": continue
  var reached:=0;var tried:=0;var slowest:=0.0;var report: Array[String]=[]
  for ring in [3.2,5.0]:
   for step in range(8):
    game._build_world(id);game._resume();game.player.active=false
    await game.get_tree().physics_frame;await game.get_tree().physics_frame
    var t: NightTerrors=game.world.terrors
    var focus:=t.focus_point();var angle:=step*TAU/8.
    var spot:=Vector3(focus.x+cos(angle)*ring,0,focus.z+sin(angle)*ring)
    if not _standable(game,spot): continue
    game.player.position=spot;game.player.rotation=Vector3.ZERO;game.player.set_crouch(false)
    game.player.camera.position.y=1.65;game.player.camera.rotation=Vector3.ZERO;game.player.camera.look_at(focus)
    if not game.world.encounters.visible_to(game.player,focus,ring+3.): continue
    tried+=1
    var start:=t.actor.global_position;var time:=0.0;var lunge_time:=-1.0
    for frame in range(60*6):
     t.tick(1./60,true,game.player);time+=1./60
     if t.lunged and lunge_time<0: lunge_time=t.attack
     if t.finished: break
    verify.call(t.triggered,"Visitor never triggers from an open approach: %s at %.1f m"%[id,ring])
    verify.call(t.finished and not t.actor.visible,"Visitor is still visible after its scare: %s"%id)
    if t.lunged: reached+=1;slowest=maxf(slowest,lunge_time)
    else: report.append("%.1fm/%d moved %.2f"%[ring,step,start.distance_to(t.actor.global_position)])
  print("SCARE FLOW ",id," ",mode," reached ",reached,"/",tried," slowest lunge ",snappedf(slowest,.01),"s ",report)
  # The server aisle and the climbing frame leave no free standing ring.
  verify.call(tried>=2 or id in ["server_rush","frame_stalker"],"Too few open approach positions to test: "+id)
  if mode!="crossing":
   verify.call(reached*10>=tried*7,"Ground visitor stalls instead of reaching the guard: %s %d/%d"%[id,reached,tried])
   verify.call(slowest<1.6,"Ground visitor takes too long to reach the guard: %s %.2fs"%[id,slowest])
 game._build_world("none");game._resume()

func _standable(game: Node3D, spot: Vector3) -> bool:
 var space: PhysicsDirectSpaceState3D=game.player.get_world_3d().direct_space_state
 var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis(),spot+Vector3(0,.95,0));query.collision_mask=1;query.exclude=[game.player.get_rid(),game.world.terrors.actor.get_rid()]
 if not space.intersect_shape(query,1).is_empty(): return false
 var down:=PhysicsRayQueryParameters3D.create(spot+Vector3(0,.5,0),spot-Vector3(0,.3,0),1);down.exclude=[game.player.get_rid()]
 return not space.intersect_ray(down).is_empty()
