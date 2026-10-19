extends RefCounted

var failures: Array[String]=[]
var checks := 0

func check(condition: bool, message: String) -> void:
 checks+=1
 if not condition: failures.append(message);push_error(message)

func run(game: Node3D) -> bool:
 var state:=PatrolState.new();state.start(42)
 check(state.current=="none","First round must be normal")
 check(state.visited.is_empty() and state.decide(false).accepted,"Green door must work without visiting any area")
 check(state.rounds==1 and state.streak==1,"Immediate green decision must advance the round")
 state.start(42)
 check(state.visited.is_empty() and state.decide(true).accepted and state.errors==1,"Immediate red decision must be accepted and evaluated normally")
 state.start(42)
 check(state.inspect("Empfang"),"First inspection accepted")
 check(not state.inspect("Empfang"),"Duplicate checkpoint ignored")
 check(not state.inspect("Unknown"),"Unknown checkpoint ignored")
 for zone in PatrolState.ZONES: state.inspect(zone)
 check(state.decide(false).correct and state.streak==1,"Correct green door advances series")
 for zone in PatrolState.ZONES: state.inspect(zone)
 check(not state.decide(state.current=="none").correct and state.streak==0,"Wrong door resets series")
 var seen: Array[String]=[]
 for i in range(13):
  for zone in PatrolState.ZONES: state.inspect(zone)
  var result:=state.decide(state.current!="none")
  check(result.correct,"Correct answer rejected")
 check(state.completed and state.streak==13,"Exactly thirteen consecutive answers must win")
 check(not state.decide(true).accepted,"Won game cannot consume additional decisions")
 state.start(99)
 for i in range(400):
  if state.current!="none": seen.append(state.current)
  for zone in PatrolState.ZONES: state.inspect(zone)
  state.decide(state.current=="none") # Deliberately keep the sequence alive for catalog coverage.
 check(seen.size()>100,"Anomaly distribution unexpectedly sparse")
 for anomaly in PatrolState.ANOMALIES: check(anomaly.id in seen,"Unreachable anomaly: "+anomaly.id)
 var restored:=PatrolState.new();var serialized: Dictionary=JSON.parse_string(JSON.stringify(state.serialize()))
 check(restored.restore(serialized),"Saved state could not be restored")
 check(restored.serialize()==state.serialize(),"Restored state differs from saved state")
 check(not restored.restore({"version":1,"current":"invalid","streak":0}),"Corrupt save must be rejected")
 var corrupt: Dictionary=serialized.duplicate(true);corrupt.history="broken";check(not restored.restore(corrupt),"Non-array history must be rejected")
 corrupt=serialized.duplicate(true);corrupt.seconds=-1;check(not restored.restore(corrupt),"Negative elapsed time must be rejected")
 corrupt=serialized.duplicate(true);corrupt.streak="broken";check(not restored.restore(corrupt),"Non-numeric series must be rejected")
 for zone in PatrolState.ZONES: state.inspect(zone);restored.inspect(zone)
 state.decide(state.current!="none");restored.decide(restored.current!="none")
 check(state.current==restored.current,"Reload rerolled the next anomaly")
 # Instantiate every real anomaly and run animation paths, including normal recovery.
 for anomaly in PatrolState.ANOMALIES:
  game._build_world(anomaly.id)
  await game.get_tree().process_frame
  game.world.tick(.5,true)
  check(game.world.current==anomaly.id,"World anomaly mismatch")
  check(game.world.get_child_count()>50,"World failed to build")
 game._build_world("none")
 await game.get_tree().physics_frame
 check(game.world.balls.visible,"Normal round did not restore ball pit")
 check(game.world.props.mural.visible,"Normal round did not restore mural")
 check(game.world.props.chairs.visible,"Normal round did not restore chairs")
 var audit:=SceneAudit.inspect(game.world)
 check(audit.wall_intersections.is_empty(),"Climbing geometry intersects architecture: "+str(audit.wall_intersections))
 check(audit.net_intrusions.is_empty(),"Play obstacles penetrate intact safety nets: "+str(audit.net_intrusions))
 check(audit.net_panels==8 and audit.wall_paintings==5,"Shared safety panels or painted wall motifs are missing")
 var padded:=game.get_tree().get_nodes_in_group("padded_obstacles").filter(func(body): return game.world.is_ancestor_of(body))
 check(padded.size()==10,"Padded rollers do not have matching physical shapes")
 var slide_mesh: MeshInstance3D=game.world.props.slide.get_node("MouldedSlide")
 check(slide_mesh.mesh.get_faces().size()>4200,"Moulded slide shell is incomplete")
 var slide_normals: PackedVector3Array=slide_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 # Inspect the central riding surface, away from the rounded lip/end cap.
 check(slide_normals[504].y>.9,"Slide riding surface normals face into the shell")
 await game.get_tree().physics_frame
 check(cast(game,Vector3(5.8,1.5,-8.7),Vector3(7.4,1.5,-8.7)).is_empty(),"Party doorway is physically obstructed")
 var play_frame: Node3D=game.world.props.structure
 for body in padded:
  var center: Vector3=body.global_position
  var hit:=cast(game,center+Vector3(0,0,.6),center-Vector3(0,0,.6))
  check(not hit.is_empty() and hit.collider==body,"A padded roller's collision does not match its visible mesh")
 var bridge_hit:=cast(game,Vector3(7.5,4,3.6),Vector3(7.5,1,3.6))
 check(not bridge_hit.is_empty() and bridge_hit.normal.y>.9,"Bridge walking surface faces away from the player")
 check(cast(game,play_frame.to_global(Vector3(-.7,1.2,-1)),play_frame.to_global(Vector3(.1,1.2,-1))).is_empty(),"Ground entrance net has an invisible collision")
 check(not cast(game,play_frame.to_global(Vector3(2,1,-5)),play_frame.to_global(Vector3(2,1,-5.9))).is_empty(),"Intact rear safety net does not block passage")
 check(cast(game,play_frame.to_global(Vector3(3.65,3.2,3.4)),play_frame.to_global(Vector3(3.65,3.2,4.3))).is_empty(),"Slide opening has an invisible net or beam")
 check(cast(game,play_frame.to_global(Vector3(5.3,3,3.2)),play_frame.to_global(Vector3(5.8,3,3.2))).is_empty(),"Bridge opening has an invisible net or beam")
 check(audit.ball_min_distance>.28,"Decorative pit balls intersect each other")
 var threshold: AABB=game.world.props.play_threshold.global_transform*game.world.props.play_threshold.get_aabb()
 check(threshold.end.z<4.78,"Play entrance threshold cuts through the ball pit rim")
 for offset in [-.4,0,.4]:
  for outward in [true,false]:
   game.player.active=true;game.player.position=play_frame.to_global(Vector3(.2,.31,-1+offset)) if outward else play_frame.to_global(Vector3(-1.9,0,-1+offset));game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI/2 if outward else -PI/2
   Input.action_press("forward")
   for frame in range(90): await game.get_tree().physics_frame
   Input.action_release("forward")
   var local: Vector3=play_frame.to_local(game.player.position)
   check(local.x< -1.8 if outward else local.x>.8,"Play entrance traps a standing player at offset "+str(offset))
 check(audit.chair_back_dot>.95,"A chair back faces the birthday table")
 check(audit.mounted_art>=20 and audit.floating_labels<=8,"Wall art/signage was not mounted as opaque physical surfaces")
 var normal_fog: Color=game.world.environment.environment.fog_light_color
 check(game.world.environment.environment.fog_density>=.065,"Dense fog must be present in a normal round")
 game._build_world("heavy_mist")
 check(game.world.environment.environment.fog_light_color.r>normal_fog.r and game.world.environment.environment.fog_light_color.g<normal_fog.g,"Fog anomaly must be visibly red, not ordinary dense mist")
 game._build_world("balls_float");game.world.tick(4,true)
 check(SceneAudit.inspect(game.world).ball_min_distance>.28,"Floating ball anomaly causes overlapping balls")
 game._build_world("none")
 # Exercise the real CharacterBody3D movement and collision world.
 game.player.reset_pose();game.player.active=true
 var initial: Vector3=game.player.position
 Input.action_press("forward")
 for frame in range(45): await game.get_tree().physics_frame
 Input.action_release("forward");game.player.release()
 check(game.player.position.z<initial.z-.5,"WASD movement did not move player")
 check(game.player.position.y>-.2,"Player fell through floor")
 game.player.position=Vector3(-4.3,0,-10.1);game.player.rotation.y=0;game.player.camera.rotation.x=0
 await game.get_tree().physics_frame
 check(game._target()=="green","Green door raycast failed")
 game.player.position.x=-2.15
 await game.get_tree().physics_frame
 check(game._target()=="red","Red door raycast failed")
 # Real jump input, airborne re-press, landing, spring carry, impulse throw and pause.
 game.player.reset_pose();game._resume()
 for frame in range(8): await game.get_tree().physics_frame
 var jump:=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.pressed=true;Input.parse_input_event(jump)
 var peak:=0.0
 for frame in range(70):
  await game.get_tree().physics_frame
  peak=maxf(peak,game.player.position.y)
  if frame==1: jump.pressed=false;Input.parse_input_event(jump)
  if frame==15: jump.pressed=true;Input.parse_input_event(jump)
  if frame==17: jump.pressed=false;Input.parse_input_event(jump)
 check(peak>.65,"Jump never left the floor")
 check(peak<1.1,"Airborne jump allowed a second jump")
 check(game.player.is_on_floor() and absf(game.player.position.y)<.12,"Jump did not land on floor")
 var body: NightProp=game.world.atmosphere.loose[0]
 body.global_position=Vector3(-6.2,.17,6.55);body.linear_velocity=Vector3.ZERO;body.sleeping=false
 game.player.camera.rotation.x=-.67
 for frame in range(8): await game.get_tree().physics_frame
 check(game.player.prop_target()==body,"Loose object was not physically targetable")
 game.player.grab_prop()
 check(game.player.carried==body and body.held,"Object was not picked up")
 body.cooldown=0;body.previous_speed=8;body._impact(game.world)
 check(body.impact_count==0 and not body.impact.playing,"Held object generated a collision sound")
 for frame in range(40): await game.get_tree().physics_frame
 check(body.global_position.distance_to(game.player.camera.global_position)<2.1,"Spring carry failed to lift object")
 game.player.camera.rotation.x=0;game.player.drop_prop(true)
 check(not body.held and game.player.carried==null,"Throw did not release held object")
 for frame in range(5): await game.get_tree().physics_frame
 check(body.linear_velocity.length()>3,"Throw did not apply a physical impulse")
 game._pause();var frozen_position:=body.position
 for frame in range(10): await game.get_tree().physics_frame
 check(body.freeze and body.position.is_equal_approx(frozen_position),"Paused objects kept simulating")
 game._resume()
 check(not body.freeze,"Objects failed to resume after pause")
 game.player.grab_prop();game._build_world("none")
 check(not is_instance_valid(game.player.carried),"World replacement kept a freed held prop")
 check(game.world.atmosphere.loose.size()==28,"Physical toy budget unexpectedly changed")
 check(game.world.environment.environment.fog_density>.02,"Atmosphere fog was not applied")
 check(is_instance_valid(game.world.playground.croc_visual),"Shared crocodile mesh was not instantiated")
 check(is_instance_valid(game.world.playground.croc_jaw),"Shared crocodile upper jaw is missing")
 check(ResourceLoader.exists(ExpandedPlayground.CROCODILE_PATH),"Shared crocodile asset was excluded")
 if not OS.has_feature("web"):
  check(game.world.native_art!=null,"Windows art pipeline missing")
  check(game.world.native_art.model_count>=25,"Native imported/hero models not instantiated")
  for required in ["hero/stitched-rabbit","hanging_industrial_lamp","hero/waiting-bench","metal_office_desk"]:
   check(game.world.native_art.sources.keys().any(func(path): return required in path),"Required native model missing: "+required)
  check(game.world.find_children("*","Node3D",true,false).filter(func(node): return node.has_meta("stocked_shelf")).size()==3,"Stocked shelving was not created in all three positions")
  for source in game.world.native_art.sources.values(): check(source is PackedScene,"Native production model failed to load")
  check(not game.world.props.floor_tiles[0].visible,"Native continuous floor was not selected")
  check(AudioServer.get_bus_index("Interior")>=0,"Native room acoustics bus missing")
 # Scene scale and real contact with the inflatable surface.
 var desk: MeshInstance3D=game.world.props.counter_top
 check(desk.get_aabb().size.x<1.1 and desk.get_aabb().size.z<3.1,"Reception desk is oversized")
 check(game.world.props.structure.scale.y>1.2,"Main climbing frame was not enlarged")
 game.player.position=Vector3(10.0,1.2,11.3);game.player.velocity=Vector3.ZERO;game.player.active=true
 for frame in range(30): await game.get_tree().physics_frame
 check(game.player.is_on_floor() and game.player.position.y>.65,"Inflatable bed collision is not walkable")
 check(game.player.bounce_speed>7.5,"Inflatable bed did not provide spring jump")
 jump.pressed=true;Input.parse_input_event(jump);var bounce_peak: float=game.player.position.y
 for frame in range(70):
  await game.get_tree().physics_frame;bounce_peak=maxf(bounce_peak,game.player.position.y)
  if frame==2: jump.pressed=false;Input.parse_input_event(jump)
 check(bounce_peak>2.1,"Inflatable bed jump has no extra height")
 game.player.position=Vector3(6.4,0,7.5);game.player.velocity=Vector3.ZERO;game.player.rotation.y=-PI/2
 Input.action_press("forward")
 for frame in range(135): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.y>1.9 and game.player.position.x>10.5,"East tower ground ramp is not walkable")
 game.player.position=Vector3(16.2,2.2,8.45);game.player.velocity=Vector3.ZERO;game.player.rotation.y=0
 Input.action_press("forward")
 for frame in range(135): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.y>4 and game.player.position.z<4.1,"East tower upper ramp is obstructed")
 game.player.position=Vector3(5.8,0,-8.7);game.player.velocity=Vector3.ZERO;game.player.rotation.y=-PI/2
 Input.action_press("forward")
 for frame_index in range(45): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.x>7.3,"Cannot walk through the party doorway")
 check(game.world.room_horror.panels>100,"Kitchen/cinema have no visible ceiling panels")
 for p in [Vector3(-13.5,3.3,-18),Vector3(-2,3.3,-18)]: check(not cast(game,p,p+Vector3.UP*.6).is_empty(),"Annex ceiling has no collision")
 check(game.world.room_horror.creature!=null,"Ceiling dweller mesh is missing")
 var dweller: Dictionary=game.world.room_horror.creature_geometry()
 check(dweller.width<.8 and dweller.rear>-.3,"Ceiling dweller still has a torso or spread limbs")
 check(dweller.top>.85 and dweller.bottom< -1.7,"Pendant neck must start inside the shaft and hang into the room")
 check(cast(game,Vector3(-1.3,3.3,-19.95),Vector3(-1.3,4.4,-19.95)).is_empty(),"Roof slab blocks the actual ventilation shaft opening")
 var ceiling_area:=0.0
 for part in RoomHorror.outside_shaft(Rect2(-17.3,-22.55,21,10.5)):
  check(not part.intersection(RoomHorror.SHAFT).has_area(),"Ceiling patch crosses the shaft aperture")
  ceiling_area+=part.get_area()
 check(is_equal_approx(ceiling_area,21*10.5-RoomHorror.SHAFT.get_area()),"Shaft cutout removes unrelated ceiling area")
 check(game.world.room_horror.music.stream is AudioStreamMP3,"User music-box recording is missing")
 game.world.room_horror.tick(.1,true)
 check(game.world.room_horror.music.playing,"Music box never starts")
 game.world.room_horror.tick(.1,false)
 check(game.world.room_horror.music.stream_paused,"Music box ignores pause")
 game.world.room_horror.tick(.1,true)
 game.world.room_horror.clock=11.75;game.world.room_horror.tick(0,true)
 check(game.world.room_horror.bulbs[0].light.light_energy<.5,"Bulb contact failure never dims the real light")
 game.world.room_horror.clock=12.5;game.world.room_horror.tick(0,true)
 check(game.world.room_horror.bulbs[0].light.light_energy>.5,"Bulb failed to recover after flicker")
 game.player.position=Vector3(4.1,3.01,3.6);game.player.velocity=Vector3.ZERO;game.player.rotation.y=-PI/2
 Input.action_press("forward")
 for frame_index in range(165): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.x>10.7 and game.player.position.y>2,"Bridge path does not pass through both safety apertures")
 game.player.position=game.world.props.structure.to_global(Vector3(3.65,2.32,.74));game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI
 Input.action_press("forward")
 for frame_index in range(155): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.z>6.5 and game.player.position.y<1,"Slide descent is blocked by floor, beam or safety net")
 # Enter, crawl around both physical bends, fail safe stand-up under the roof,
 # then stand again outside. Voices must also play in a normal round.
 game._build_world("none");game._resume();game.player.position=Vector3(-5.5,0,10.7);game.player.rotation.y=PI
 Input.action_press("forward")
 for frame_index in range(70): await game.get_tree().physics_frame
 check(game.player.position.z<12,"Standing player passes through the low tube roof")
 Input.action_press("crouch")
 for frame_index in range(95): await game.get_tree().physics_frame
 Input.action_release("forward");Input.action_release("crouch")
 for frame_index in range(20): await game.get_tree().physics_frame
 check(game.world.tubes.contains(game.player.position),"Crouched player cannot enter the tube")
 check(game.player.crouching and game.player.camera.position.y<1,"Releasing crouch pushes the player through the tube roof")
 check(game.world.soundscape.voice_count>0 and game.world.current=="none","Normal tube atmosphere does not play children's voices")
 game.world.soundscape.voice.stop();game.world.soundscape.voice_index=1;game.world.soundscape.cue_voice(game.player)
 check(game.world.soundscape.last_voice=="children-cry.ogg" and game.world.current=="none","Crying voice is treated as an anomaly or fails to play")
 game._pause();await game.get_tree().process_frame
 var sound_clock: float=game.world.soundscape.clock;var voice_timer: float=game.world.soundscape.voice_timer
 for frame_index in range(12): await game.get_tree().physics_frame
 check(game.world.soundscape.clock==sound_clock and game.world.soundscape.voice_timer==voice_timer and game.world.soundscape.voice.stream_paused,"Pause does not freeze ambient audio and timers")
 game._resume();Input.action_press("crouch");Input.action_press("forward")
 for frame_index in range(1000):
  var n:=CrawlTubes.nearest(game.player.position)
  var destination:=CrawlTubes.route(minf(CrawlTubes.LENGTH,n.s+.45))
  if n.s>CrawlTubes.LENGTH-.3: destination+=Vector3(0,0,-1.2)
  var direction: Vector3=destination-game.player.position
  game.player.rotation.y=atan2(-direction.x,-direction.z)
  await game.get_tree().physics_frame
  if game.player.position.x>3.4 and game.player.position.z<11.3: break
 Input.action_release("forward");Input.action_release("crouch")
 for frame_index in range(25): await game.get_tree().physics_frame
 check(game.player.position.x>3.4 and game.player.position.z<11.3,"Tube traversal is blocked by a bend, window or old room prop: "+str(game.player.position))
 check(not game.player.crouching and game.player.camera.position.y>1.5,"Player cannot stand after leaving the tube")
 check(not game.world.tubes.watcher.visible,"Window figure appears in a normal round")
 game.state.start(1600);game.has_session=true
 game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);game.player.set_crouch(true);game._save();game._continue()
 for frame_index in range(8): await game.get_tree().physics_frame
 check(game.player.crouching and game.world.tubes.contains(game.player.position),"Reloading a tube save restores a standing player inside the roof")
 game._build_world("tube_watcher")
 game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);game.world.tubes.tick(0,true,game.player)
 check(game.world.tubes.watcher.visible,"Window watcher anomaly does not appear inside the tube")
 game._build_world("none")
 check(not game.world.tubes.watcher.visible,"Window watcher is not removed in the next normal round")
 # Normal comparison has no proximity scare. The anomaly requires actual
 # proximity, a forward-facing view and unobstructed line of sight.
 game._build_world("none");game._resume();game.player.position=Vector3(-5.7,0,4.85);game.player.rotation.y=-PI/2
 game.world.encounters.tick(2,true,game.player)
 check(not game.world.encounters.triggered,"Normal reference round triggered a scare")
 game._build_world("bunny_lunge");game._resume();game.player.position=Vector3(-6.2,0,9)
 game.world.encounters.tick(2,true,game.player)
 check(not game.world.encounters.triggered,"Bunny triggered outside proximity")
 game.player.position=Vector3(-5.7,0,4.85);game.player.rotation.y=PI/2
 await game.get_tree().physics_frame;game.world.encounters.tick(.01,true,game.player)
 check(not game.world.encounters.triggered,"Bunny triggered behind the player")
 game.player.rotation.y=-PI/2;game.player.camera.rotation.x=-.08
 await game.get_tree().physics_frame;game.world.encounters.tick(.02,true,game.player)
 check(game.world.encounters.triggered,"Approaching and looking at bunny did not trigger scare")
 var attack_position: Vector3=game.world.atmosphere.horrors.bunny.position
 var attack_time: float=game.world.encounters.attack_time
 game.world.encounters.tick(.5,false,game.player)
 check(game.world.encounters.attack_time==attack_time and game.world.atmosphere.horrors.bunny.position==attack_position,"Pause did not freeze the scare")
 game.world.encounters.tick(.3,true,game.player)
 check(game.world.atmosphere.horrors.bunny.position.distance_to(attack_position)>1,"Bunny did not physically leap")
 game.world.encounters.tick(2,true,game.player)
 check(game.world.encounters.finished,"Bunny scare did not finish")
 game.world.encounters.tick(2,true,game.player)
 check(game.world.encounters.attack_time<3,"One-shot scare replayed")
 game._build_world("horse_rocks");game.world.encounters.tick(.5,true,game.player)
 check(absf(game.world.atmosphere.horrors.horse.rotation.x)>.1,"Rocking horse anomaly is static")
 game._build_world("croc_snap");game._resume()
 game.world.encounters.tick(1.1,true,game.player)
 game.player.position=Vector3(6.8,0,11.3);game.player.rotation.y=-PI/2;game.player.camera.rotation.x=.12
 await game.get_tree().physics_frame
 game.world.encounters.tick(.01,true,game.player)
 check(game.world.encounters.triggered,"Crocodile approach did not trigger")
 game.world.encounters.tick(.22,true,game.player)
 var jaw_angle: float=game.world.playground.croc_jaw.rotation.x
 check(jaw_angle>.3,"Crocodile upper jaw did not close")
 game.world.encounters.tick(.4,false,game.player)
 check(is_equal_approx(jaw_angle,game.world.playground.croc_jaw.rotation.x),"Crocodile jaw moved during pause")
 game.world.encounters.tick(1,true,game.player)
 check(game.world.encounters.finished and is_equal_approx(game.world.playground.croc_jaw.rotation.x,.12),"Crocodile jaw failed to settle after snap")
 # Walk the new annex through both real doorways, never through geometry.
 game._build_world("none");game._resume();game.player.position=Vector3(-7.9,0,-10.3);game.player.velocity=Vector3.ZERO
 for destination in [Vector3(-7.9,0,-17.65),Vector3(-12.0,0,-17.65),Vector3(-7.9,0,-17.65),Vector3(1.7,0,-17.65)]:
  Input.action_press("forward")
  for frame in range(500):
   var direction: Vector3=destination-game.player.position;direction.y=0
   if direction.length()<.16: break
   game.player.rotation.y=atan2(-direction.x,-direction.z)
   await game.get_tree().physics_frame
  Input.action_release("forward")
  check(Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<.3,"Annex walkway blocked: "+str(destination)+" actual "+str(game.player.position))
 check(game.player.position.y>-.1 and game.player.position.y<.2,"Annex floor has a gap or obstructing step")
 check(game.world.annex.clock>0 and not game.world.annex.settled,"Normal kitchen clown must stir")
 check(not game.world.encounters.triggered,"Normal kitchen or NO SIGNAL cinema caused an anomaly scare")
 game._pause();await game.get_tree().process_frame
 var annex_clock: float=game.world.annex.clock;var hand_pose: Vector3=game.world.annex.clown.hand.position
 for frame in range(12): await game.get_tree().physics_frame
 check(game.world.annex.clock==annex_clock and game.world.annex.clown.hand.position==hand_pose,"Pause does not freeze projector and spoon")
 check(game.world.annex.sources.all(func(source): return source.stream_paused),"Annex audio continues in pause")
 game._resume()
 # Both new rooms must support a real persisted save, not only main-hall bounds.
 for pose in [Vector3(-12,0,-17.65),Vector3(1.7,0,-17.65)]:
  game.state.start(1700);game.has_session=true;game.player.position=pose;game._save();game.has_session=false;game._continue()
  check(game.player.position.distance_to(pose)<.1,"Annex saved position was discarded")
 game._build_world("clown_lunge");game._resume();game.player.position=Vector3(-12.2,0,-18);game.player.rotation.y=-2.0;game.player.camera.rotation.x=.09
 await game.get_tree().physics_frame;game.world.encounters.tick(2,true,game.player)
 check(not game.world.encounters.triggered,"Clown triggered behind player")
 game.player.rotation.y=1.1
 await game.get_tree().physics_frame;game.world.encounters.tick(.01,true,game.player)
 check(game.world.encounters.triggered,"Visible nearby clown did not trigger")
 var clown_start: Vector3=game.world.annex.clown.root.position
 var clown_time: float=game.world.encounters.attack_time
 game.world.encounters.tick(.4,false,game.player)
 check(game.world.encounters.attack_time==clown_time and game.world.annex.clown.root.position==clown_start,"Clown moves during pause")
 game.world.encounters.tick(.3,true,game.player)
 check(game.world.annex.clown.root.position.distance_to(clown_start)>1,"Clown scare is not a physical lunge")
 game.world.encounters.tick(2,true,game.player)
 check(game.world.encounters.finished and game.world.annex.settled,"Clown does not settle after one scare")
 check(game.world.annex.clown.root.position.distance_to(game.world.annex.clown_origin)<.01,"Clown fails to return to cooker")
 game.world.tick(.1,true)
 check(game.world.annex.sources[0].stream_paused,"Stirring sound continues after clown stops stirring")
 game._build_world("none")
 check(not game.world.annex.settled and not game.world.annex.scare,"Next normal round failed to restore kitchen clown")
 game.player.release();game.phase="menu"
 game.has_session=true;game.state.start(71);game.state.decide(false);game._save();check(game._can_continue(),"Saved game cannot be continued")
 var legacy:=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE)) as Dictionary
 legacy.erase("layout_version");legacy.pose=[13,1,1.6,0,0]
 var expected:=PatrolState.new();expected.restore(legacy.patrol)
 var legacy_file:=FileAccess.open(game.SAVE,FileAccess.WRITE);legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
 game.has_session=false;game._continue()
 check(game.player.position.is_equal_approx(Vector3(-6.2,0,8.5)),"Old layout save restored the player inside relocated geometry")
 check(game.state.serialize()==expected.serialize(),"Layout migration changed patrol progress")
 game._new_shift();game.intro.skip();game.player.lamp_on=true;game.player.lamp.show()
 game.player.torch_body.trigger();game.player.torch_body.tick(.025,true,0)
 check(game.player.lamp.light_energy<2,"Torch contact failure did not dim the real light")
 game._pause();var flicker_clock: float=game.player.torch_body.clock
 for frame in range(10): await game.get_tree().physics_frame
 check(game.player.torch_body.clock==flicker_clock,"Torch flicker continues in pause")
 game._resume()
 for frame in range(50): await game.get_tree().physics_frame
 check(is_equal_approx(game.player.lamp.light_energy,4.2),"Torch failed to recover from a short contact failure")
 check(game.world.soundscape.beds.size()>=6 and game.world.soundscape.events.size()>=11,"New spatial field recordings are missing")
 game.world.soundscape.ghost_count=0;game.world.soundscape.cue_steps(game.player);var ghost_start: Vector3=game.world.soundscape.ghost.position
 game.world.soundscape.tick(.7,true,game.player)
 check(game.world.soundscape.ghost.position.distance_to(ghost_start)>.1,"Invisible footsteps do not move along their aisle")
 check(game.world.soundscape.ghost_track=="ghost-walk.wav","First phantom walk recording is missing")
 await game.get_tree().physics_frame
 game._pause();await game.get_tree().physics_frame;await game.get_tree().process_frame
 check(game.world.soundscape.ghost.stream_paused,"Invisible footsteps ignore pause")
 game._resume()
 game.world.soundscape.cue_steps(game.player)
 check(game.world.soundscape.ghost_track=="ghost-run.wav","Phantom running variation is missing")
 var sculpt: Node3D=game.world.annex.clown.head
 var head_faces:=0
 for mesh in sculpt.find_children("*","MeshInstance3D",true,false)+([sculpt] if sculpt is MeshInstance3D else []):
  head_faces+=mesh.mesh.get_faces().size()
  for surface in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   check(material!=null and material.albedo_texture==null,"Clown head still uses a portrait texture")
 check(head_faces>20000,"Clown head lacks real sculpted geometry")
 game._decide(false)
 check(game.phase=="transition" and game.state.streak==1,"Correct door did not begin an automatic transition")
 var limit:=0
 while game.phase!="play" and limit<900:
  await game.get_tree().physics_frame;limit+=1
 check(game.phase=="play" and game.state.rounds==1,"Correct door still needs a confirmation")
 game._decide(game.state.current=="none")
 check(game.phase=="failure" and game.door_failure.running and not game.player.active,"Wrong door failed to start the real 3D scare")
 var rounds_before: int=game.state.rounds
 game._decide(false)
 check(game.state.rounds==rounds_before,"Repeated input during a scare counted another decision")
 limit=0
 while game.phase!="intro" and limit<900:
  await game.get_tree().physics_frame;limit+=1
 check(game.phase=="intro" and game.state.streak==0 and game.state.rounds==0 and game.intro_pending,"Death did not restart the whole shift with the intro")
 check(game.door_failure.shown==1 and not game.door_failure.running,"Wrong door scare replayed or remained visible")
 check(not game.player.active and game.intro.stage=="ringing","Intro does not lock gameplay until the phone sequence ends")
 var saved_intro: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE))
 check(saved_intro.intro_pending,"Closing during intro would bypass it on reload")
 game.intro.tick(1.3);game.intro.accept()
 check(game.intro.stage=="call","Accepting the chief call failed")
 var intro_clock: float=game.intro.clock
 game.intro.paused=true;game.intro.tick(2)
 check(game.intro.clock==intro_clock,"Intro and voice are not frozen in pause")
 game.intro.paused=false
 Input.action_press("jump");game.intro.tick(.6)
 check(game.phase=="intro","A short Space press skipped the entire intro")
 game.intro.tick(.8);Input.action_release("jump")
 check(game.phase=="play" and not game.intro_pending,"Holding Space failed to skip intro and start patrol")
 check(game.player.position.z>17,"Skipped intro teleported the guard instead of leaving him in the cabin")
 game._new_shift();game.intro.tick(1.3);game.intro.accept();game.intro.tick(game.intro.call_length+.1)
 check(game.intro.stage=="arrival","Chief call did not hang up and ring the lift chime")
 game.intro.tick(2.5)
 check(game.phase=="play" and absf(game.intro.doors[0].position.x)>1.8,"Lift doors failed to open after the chief finished")
 Input.action_press("forward")
 for frame in range(220): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.z<10.8 and game.player.position.y>-.1,"The full route from the elevator into the hall is obstructed")
 await game.get_tree().create_timer(.35).timeout
 game._pause()
 # Every added setting drives real engine state; the menu prank stays nonlethal.
 var original_settings: Dictionary=game.settings.duplicate()
 NightMenus.changed(game,"fov",89.0);NightMenus.changed(game,"invert_y",true);NightMenus.changed(game,"ambience",0.0);NightMenus.changed(game,"voice",0.0)
 game._resume();await game.get_tree().physics_frame
 check(is_equal_approx(game.player.camera.fov,89.0),"User FOV is overwritten by the movement camera")
 check(game.player.invert_y,"Invert Y does not reach the guard input")
 check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("NightAmbience"))< -70,"Ambience slider does not mute its bus")
 check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("NightVoice"))< -70,"Voice slider does not mute its bus")
 check(game.intro.voice.bus=="NightVoice" and game.room_audio.bus=="NightAmbience","Added audio buses are disconnected")
 game._pause();game._settings("pause");NightMenus.settings(game,"Spiel")
 var prank_patrol:=JSON.stringify(game.state.serialize());var prank_settings:=JSON.stringify(game.settings)
 var save_before:=FileAccess.get_file_as_string(game.SAVE)
 game._menu_jump();check(game.phase=="menu_scare" and game.menu_scare.running,"Menu toggle never starts its scare")
 game.menu_scare.tick(.35);check(game.menu_scare.audio.playing,"Menu scare sound never starts")
 game.menu_scare.tick(1.0)
 check(game.phase=="settings" and not game.menu_scare.running and game.return_phase=="pause","Menu scare fails to return to the correct settings context")
 check(prank_patrol==JSON.stringify(game.state.serialize()) and prank_settings==JSON.stringify(game.settings),"Menu prank mutates patrol difficulty or user settings")
 check(save_before==FileAccess.get_file_as_string(game.SAVE),"Menu prank changes the patrol save")
 check(not game.settings.has("jumpscares"),"Prank toggle became a real gameplay setting")
 var stored_settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SETTINGS))
 check(stored_settings.fov==89 and stored_settings.invert_y,"New options are not persisted")
 game.settings=original_settings;game._apply_settings();game._write_settings()
 await load("res://scripts/archive_validation.gd").new().run(game,check)
 await load("res://scripts/nightmare_validation.gd").new().run(game,check)
 await load("res://scripts/props_validation.gd").new().run(game,check)
 await load("res://scripts/finale_validation.gd").new().run(game,check)
 await load("res://scripts/presentation_validation.gd").new().run(game,check)
 print("Validation checks: ",checks,"; failures: ",failures.size())
 return failures.is_empty()

func cast(game: Node3D, a: Vector3, b: Vector3) -> Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(a,b,1);query.exclude=[game.player.get_rid()]
 return game.get_world_3d().direct_space_state.intersect_ray(query)
