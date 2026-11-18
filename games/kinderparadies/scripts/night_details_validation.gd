extends RefCounted

# --night-details-only: flickering tubes, the guard's prints, the children's
# trail and cold-breath anomalies and the whispers in the stillness (4.12.0).
func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().physics_frame
 var night: NightDetails=game.world.night;night.set_process(false)
 verify.call(night.tubes.size()==2,"The two failing tubes are missing (%d)"%night.tubes.size())
 verify.call(night.snapshot().child_prints==0 and night.snapshot().frost==0 and night.puffs.is_empty(),"A normal round shows the footprint or cold-breath anomaly")
 # Tubes: a burst dims the light and the starter clicks.
 var tube: Dictionary=night.tubes[0];tube.wait=0.
 var dimmed:=false;var clicked:=false
 for i in range(120):
  night._flicker(1./60)
  if tube.light.light_energy<tube.energy*.5:dimmed=true
  if night.click.playing:clicked=true
 verify.call(dimmed and clicked,"A failing tube neither stutters nor clicks")
 for i in range(900):night._flicker(1./60)
 verify.call(is_equal_approx(tube.light.light_energy,tube.energy),"A tube stays dark after its burst")
 # The guard's prints: a real walk leaves them, alternating feet.
 game.player.position=Vector3(-6.,.05,6.);game.player.set_physics_process(false)
 for i in range(90):
  game.player.velocity=Vector3(2.,-1.,0.);game.player.move_and_slide()
  await game.get_tree().physics_frame
  night._footsteps(game.player)
 var made:int=night.snapshot().prints
 verify.call(made>=3,"Walking leaves no shoe prints in the dust (%d)"%made)
 # Whisper: only when standing still, from elsewhere.
 game.player.velocity=Vector3.ZERO
 for attempt in range(30):
  night.whisper_cooldown=0.;night.still=7.5;night._stillness(.1,game.player)
  if night.whispered>0:break
 verify.call(night.whispered>0 and night.whisper.global_position.distance_to(game.player.global_position)>5.,"Standing still never brings a whisper, or it comes from the guard's own spot")
 game.player.velocity=Vector3(2,0,0);var count: int=night.whispered;night.whisper.stop();night.whisper_cooldown=0.;night.still=9.;night._stillness(.1,game.player)
 verify.call(night.whispered==count,"Whispers come while the guard is walking")
 # Children's trail anomaly.
 game.state.current=NightDetails.FOOTPRINT_ID;game._build_world(NightDetails.FOOTPRINT_ID);game._resume();game.player.active=false
 var trail: int=game.world.night.snapshot().child_prints
 verify.call(trail>=18,"The children's trail is missing or too short (%d)"%trail)
 # Cold breath anomaly: only inside the kitchen.
 game.state.current=NightDetails.BREATH_ID;game._build_world(NightDetails.BREATH_ID);game._resume();game.player.active=false
 night=game.world.night;night.set_process(false)
 verify.call(night.snapshot().frost==10 and is_instance_valid(night.cold_light) and night.puffs.size()==3,"The cold kitchen has no frost, cold light or breath")
 game.player.position=Vector3(0,0,8);night.breath_clock=0.;night._breathe(.1,game.player)
 verify.call(not night.puffs.any(func(p):return p.emitting),"Breath shows outside the kitchen")
 game.player.position=Vector3(NightDetails.KITCHEN.get_center().x,0,NightDetails.KITCHEN.get_center().y);night.breath_clock=0.;night._breathe(.1,game.player)
 verify.call(night.puffs.any(func(p):return p.emitting),"The guard's breath does not show in the cold kitchen")
 game.state.current="none";game._build_world("none");game._resume()
