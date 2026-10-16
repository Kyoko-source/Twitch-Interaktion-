extends RefCounted

var failures: Array[String]=[]
var checks := 0

func check(condition: bool, message: String) -> void:
 checks+=1
 if not condition: failures.append(message);push_error(message)

func run(game: Node3D) -> bool:
 var state:=PatrolState.new();state.start(42)
 check(state.current=="none","First round must be normal")
 check(not state.decide(false).accepted,"Must inspect all areas before choosing")
 check(state.rounds==0,"Blocked decision must not consume a round")
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
 if not OS.has_feature("web"):
  check(game.world.native_art!=null,"Windows art pipeline missing")
  check(game.world.native_art.model_count==36,"Native imported/hero models not instantiated")
  check(game.world.native_art.sources.size()==13,"Native model catalog is incomplete")
  for source in game.world.native_art.sources.values(): check(source is PackedScene,"Native production model failed to load")
  check(not game.world.props.floor_tiles[0].visible,"Native continuous floor was not selected")
  check(AudioServer.get_bus_index("Interior")>=0,"Native room acoustics bus missing")
 # Scene scale and real contact with the inflatable surface.
 var desk: MeshInstance3D=game.world.props.counter_top
 check(desk.get_aabb().size.x<1.1 and desk.get_aabb().size.z<3.1,"Reception desk is oversized")
 check(game.world.props.structure.scale.y>1.2,"Main climbing frame was not enlarged")
 game.player.position=Vector3(12.4,1.2,11.3);game.player.velocity=Vector3.ZERO;game.player.active=true
 for frame in range(30): await game.get_tree().physics_frame
 check(game.player.is_on_floor() and game.player.position.y>.65,"Inflatable bed collision is not walkable")
 check(game.player.bounce_speed>7.5,"Inflatable bed did not provide spring jump")
 jump.pressed=true;Input.parse_input_event(jump);var bounce_peak: float=game.player.position.y
 for frame in range(70):
  await game.get_tree().physics_frame;bounce_peak=maxf(bounce_peak,game.player.position.y)
  if frame==2: jump.pressed=false;Input.parse_input_event(jump)
 check(bounce_peak>2.1,"Inflatable bed jump has no extra height")
 game.player.position=Vector3(6.4,0,5.4);game.player.velocity=Vector3.ZERO;game.player.rotation.y=-PI/2
 Input.action_press("forward")
 for frame in range(135): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.y>1.9 and game.player.position.x>10.5,"East tower ground ramp is not walkable")
 game.player.position=Vector3(16.2,2.2,6.35);game.player.velocity=Vector3.ZERO;game.player.rotation.y=0
 Input.action_press("forward")
 for frame in range(135): await game.get_tree().physics_frame
 Input.action_release("forward")
 check(game.player.position.y>4 and game.player.position.z<2,"East tower upper ramp is obstructed")
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
 game._build_world("croc_breathes");game.world.encounters.tick(.8,true,game.player)
 check(game.world.props.inflatable_skin.scale.y>1.04,"Crocodile breathing is static")
 game._build_world("horse_rocks");game.world.encounters.tick(.5,true,game.player)
 check(absf(game.world.atmosphere.horrors.horse.rotation.x)>.1,"Rocking horse anomaly is static")
 game._build_world("none");game.player.release();game.phase="menu"
 game.has_session=true;game.state.start(71);game._save();check(game._can_continue(),"Saved game cannot be continued")
 print("Validation checks: ",checks,"; failures: ",failures.size())
 return failures.is_empty()
