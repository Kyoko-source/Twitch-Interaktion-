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
 game.player.release();game.phase="menu"
 game.has_session=true;game.state.start(71);game._save();check(game._can_continue(),"Saved game cannot be continued")
 print("Validation checks: ",checks,"; failures: ",failures.size())
 return failures.is_empty()
