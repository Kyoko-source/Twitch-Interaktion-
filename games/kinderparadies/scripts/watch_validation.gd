extends RefCounted

func press(game: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var watch: ReceptionWatch=game.world.watch
 verify.call(watch.photos.size()==6 and watch.board.get_node("FormerHappylandStaff")!=null,"Birthday wall is missing its six Polaroids or staff photograph")
 var layout:=SceneAudit.placement(game.world)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Reception additions intersect another object: "+JSON.stringify(layout))
 game.player.position=Vector3(-7.4,.02,5.45);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(watch.display.global_position)
 await game.get_tree().physics_frame
 verify.call(game._target()=="reception_cctv","CRT cannot be operated from the visitor side of the counter")
 press(game)
 verify.call(game.phase=="surveillance" and not game.player.active and watch.opened,"E does not open the voluntary live monitor")
 var patrol_before:=JSON.stringify(game.state.serialize())
 for i in range(ReceptionWatch.FEEDS.size()):
  watch._select(i)
  verify.call(watch.camera.position==ReceptionWatch.FEEDS[i].p and watch.viewport.world_3d==game.get_world_3d(),"Security camera shows a separate scene or wrong angle: "+str(i))
  var view_query:=PhysicsRayQueryParameters3D.create(watch.camera.position,watch.camera.position-watch.camera.basis.z*.6,1);view_query.exclude=[game.player.get_rid()]
  verify.call(game.get_world_3d().direct_space_state.intersect_ray(view_query).is_empty(),"Security lens faces a wall immediately in front of it: "+str(i))
 verify.call(JSON.stringify(game.state.serialize())==patrol_before,"Watching a security camera changes the anomaly decision")
 game._close_watch();game.player.active=false
 verify.call(game.phase=="play" and not watch.opened and watch.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closing CCTV leaves its second renderer running")
 game.player.position=Vector3(1.2,.02,14.7);game.player.camera.look_at(ReceptionWatch.WALL+Vector3(0,-.45,0))
 await game.get_tree().physics_frame
 verify.call(game._target()=="memory_wall","Memories wall is hidden behind the crawl tunnel")
 press(game);verify.call(game.phase=="help","E does not examine the birthday photographs")
 game._return_from_panel();game.player.active=false
 var pit: BallPitPhysics=game.world.pit_physics
 verify.call(pit.bodies.size()==360 and pit.bodies.all(func(b):return b is RigidBody3D and b.get_child(0).shape is SphereShape3D),"Ball pit does not contain 360 real spherical physics bodies")
 # Apply an actual impulse, let the physics server integrate it, and verify
 # the same body supplies the visible MultiMesh transform.
 var ball: RigidBody3D=pit.bodies[0]
 game.player.position=Vector3(-5,0,10)
 pit.tick(true,game.player);ball.global_position+=Vector3.UP*1.5;ball.sleeping=false;var from:=ball.global_position;ball.apply_central_impulse(Vector3(.05,.03,0))
 for i in range(25): await game.get_tree().physics_frame
 pit.tick(true,game.player)
 verify.call(ball.global_position.distance_to(from)>.12,"Physical ball ignores impulses or gravity")
 var rendered: Vector3=game.world.balls.to_global(game.world.ball_render_transforms[0].origin)
 verify.call(rendered.distance_to(ball.global_position)<.002,"Physical and rendered ball positions diverge")
 game._pause();await game.get_tree().process_frame
 var held:=ball.global_position
 for i in range(12): await game.get_tree().physics_frame
 verify.call(ball.freeze and held.distance_to(ball.global_position)<.001,"Ball physics continues while paused")
 game._resume();game.player.active=false
 game.player.position=pit.bodies[20].global_position-Vector3(.30,.16,0);game.player.velocity=Vector3(2.5,0,0);pit.tick(true,game.player)
 pit._physics_process(1.0/60)
 verify.call(pit.kicks>0,"Walking through the pit cannot displace any ball")
 game.player.velocity=Vector3.ZERO;game.player.position=Vector3(-5,0,10)
 game._build_world("balls_missing");game.player.active=false
 verify.call(not game.world.balls.visible and game.world.pit_physics.bodies.all(func(b):return b.collision_layer==0 and b.freeze),"Empty-pit anomaly leaves invisible physical balls")
 game._build_world("balls_float");game.player.active=false;game.world.tick(2,true);game.world.pit_physics.tick(true,game.player)
 pit=game.world.pit_physics
 verify.call(pit.bodies[0].freeze and pit.bodies[0].position.y>pit.starts[0].y+.9 and not pit.bodies[1].freeze,"Floating anomaly and physical balls conflict")
 # Inspect every physical encounter at its actual world anchor. Disabled
 # shapes are deliberate hanging heads/arms, not walking bodies.
 for id in NightTerrors.SCENARIOS:
  game._build_world(id);game.player.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var terror: NightTerrors=game.world.terrors
  var shape:=terror.actor.get_child(1) as CollisionShape3D
  if shape==null:
   for child in terror.actor.get_children():
    if child is CollisionShape3D: shape=child;break
  if shape and not shape.disabled:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=1;query.exclude=[terror.actor.get_rid(),game.player.get_rid()];query.margin=.001
   var hits:=game.get_world_3d().direct_space_state.intersect_shape(query,8)
   var blockers: Array[String]=[]
   for hit in hits: blockers.append(str(hit.collider.get_path()))
   verify.call(hits.is_empty(),"Encounter spawns inside solid geometry: "+id+" / "+str(blockers))
  var found:=false
  if terror.spec.mode in ["tube","window"]:
   game.player.set_crouch(true)
   game.player.camera.position.y=.8
   for offset in [-2.3,-1.4,1.4,2.3]:
    game.player.position=CrawlTubes.route(terror.path_s+offset)+Vector3(0,-.73,0);game.player.camera.look_at(terror.focus_point())
    if game.world.encounters.visible_to(game.player,terror.focus_point(),5.4): found=true;break
  else:
   game.player.set_crouch(false)
   game.player.camera.position.y=1.65
   for radius in [1.6,2.5,3.3]:
    if found: break
    for i in range(16):
     var feet:=terror.origin+Vector3(cos(i*TAU/16)*radius,0,sin(i*TAU/16)*radius)
     feet.y=.32 if id in ["frame_stalker","frame_drop"] else .03
     var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.7,feet-Vector3.UP*.4,1);floor_query.exclude=[game.player.get_rid(),terror.actor.get_rid()]
     var floor_hit:=game.get_world_3d().direct_space_state.intersect_ray(floor_query)
     if floor_hit.is_empty() or floor_hit.normal.y<.8: continue
     feet.y=floor_hit.position.y+.025
     var capsule_query:=PhysicsShapeQueryParameters3D.new();capsule_query.shape=game.player.capsule;capsule_query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*.85);capsule_query.collision_mask=1;capsule_query.exclude=[game.player.get_rid(),terror.actor.get_rid()];capsule_query.margin=.001
     if not game.get_world_3d().direct_space_state.intersect_shape(capsule_query,1).is_empty() or game.world.tubes.contains(feet): continue
     game.player.position=feet;game.player.camera.look_at(terror.focus_point())
     if game.world.encounters.visible_to(game.player,terror.focus_point(),3.5): found=true;break
  verify.call(found,"No walkable viewpoint can see the encounter trigger: "+id)
  if found:
   terror.elapsed=0;terror.triggered=false;terror.finished=false;terror.attack=0
   terror.tick(.9,true,game.player)
   verify.call(terror.triggered,"The real proximity/visibility trigger fails: "+id)
  if id=="vent_strike": verify.call(terror.marker.position.z< -30,"Vent scare remnant lost the cinema's offset")
 game.player.set_crouch(false)
 game._build_world("none");game._resume();game.player.active=false
