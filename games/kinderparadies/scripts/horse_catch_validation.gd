extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 var driver=load("res://scripts/hunt_validation.gd").new()
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 var natural: PatrolState
 for seed_value in range(1,501):
  var patrol:=PatrolState.new();patrol.start(seed_value)
  for round_number in range(1,14):
   if patrol.current==HorseHunt.ID:natural=patrol;break
   patrol.decide(patrol.current!="none")
  if natural:break
 verify.call(natural!=null and not natural.horse_override and natural.streak+1 not in [1,3,5,8,11],"Horse hunt cannot be drawn naturally outside newspaper rounds")
 if not natural:return
 game.state=natural;game._build_world(natural.current);game._resume();game.player.active=false
 var hunt: HorseHunt=game.world.horse_hunt
 verify.call(hunt.enabled and hunt.red_locked() and not game.state.horse_override,"Ordinarily drawn horse does not enable the actual puzzle")
 game.archive.collected.assign(["note"]);var streak: int=game.state.streak;var rounds: int=game.state.rounds
 game.player.position=Vector3(-7.9,0,-25.5)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 for i in range(1200):
  hunt.tick(1.0/60.0,true,game.player)
  if hunt.phase=="catch":break
  if i%60==0:await game.get_tree().physics_frame
 verify.call(hunt.phase=="catch" and hunt.catch_count==1,"Horse stops near a stationary player instead of catching them")
 await driver.advance(game,.20)
 verify.call(hunt.catch_audio.playing and hunt.catch_audio.stream.resource_path.contains("horse-"),"Horse contact lacks its own creature scream")
 verify.call(hunt.catch_view.visible and hunt.catch_mask.visible and not hunt.horse.mask.visible and hunt.catch_view.global_position.distance_to(game.player.camera.global_position)<.001,"Horse close-up is missing or detached from the player's view")
 verify.call(hunt.shock>.7 and hunt.red_locked() and not game.world.annex.scare,"Contact opens red or incorrectly summons the kitchen clown")
 verify.call(hunt.injury_strength>.25 and hunt.injury_strength<=.36,"First contact has no subtle bloodshot injury")
 var first_injury:=hunt.injury_strength
 hunt.present_contact(false);verify.call(not hunt.catch_view.visible,"Horse close-up can cover a different ending or death scare")
 hunt.present_contact(true);verify.call(hunt.catch_view.visible,"Pausing/returning cannot restore the current contact picture")
 var frozen:=hunt.serialize().duplicate(true);var pose: Transform3D=hunt.catch_mask.transform
 hunt.tick(1,false,game.player)
 verify.call(hunt.phase_clock==frozen.phase_clock and hunt.catch_mask.transform==pose and hunt.catch_audio.stream_paused,"Pause advances the contact scare or its sound")
 game._save();game.has_session=false;game._continue();game.player.active=false;hunt=game.world.horse_hunt
 await driver.advance(game,.02)
 verify.call(hunt.phase=="catch" and hunt.catch_count==1 and hunt.catch_view.visible and hunt.catch_cooldown<6,"Reload loses the contact scare or repeats its trigger")
 verify.call(hunt.injury_strength>=first_injury,"Reload heals the bloodshot screen")
 verify.call(game.phase=="play" and game.state.streak==streak and game.state.rounds==rounds and game.archive.collected==["note"],"Contact kills the player, resets their round or loses collected papers")
 await driver.advance(game,1.0)
 verify.call(hunt.phase=="recoiling" and hunt.horse.mask.visible and not hunt.catch_view.visible,"Horse does not withdraw after its close-up")
 var recoil: Variant=JSON.parse_string(JSON.stringify(hunt.serialize()));var head:=hunt.head
 hunt.restore(recoil)
 verify.call(hunt.phase=="recoiling" and hunt.head.distance_to(head)<.001 and hunt.retreat_index==recoil.retreat_index,"Reload loses the short withdrawal route")
 await driver.advance(game,2.7)
 verify.call(hunt.phase=="following" and hunt.catch_count==1 and hunt.red_locked(),"Horse does not resume the same unresolved pursuit after contact")
 await driver.advance(game,.5)
 verify.call(hunt.catch_count==1,"Horse immediately repeats its jumpscare without a cooldown")
 await driver.advance(game,3)
 verify.call(hunt.catch_count==2 and game.phase=="play" and game.state.streak==streak,"Horse cannot catch again after the cooldown or a repeat catch becomes lethal")
 await driver.advance(game,.4);hunt.present_contact(true)
 verify.call(hunt.injury_strength>first_injury+.3 and hunt.injury_screen.visible,"Second injury does not visibly intensify the red border")
 var legacy:=hunt.serialize().duplicate(true);legacy.version=1;legacy.catch_count=9;legacy.phase="following";hunt.restore(legacy)
 verify.call(hunt.catch_count==2 and hunt.injury_strength>.7,"Old unlimited-contact saves do not migrate to two injuries")
 hunt._repel()
 for frame in range(900):
  hunt.tick(1./60.,true,game.player)
  if hunt.phase=="resolved":break
 hunt.tick(1.,true,game.player);hunt.present_contact(true)
 verify.call(hunt.phase=="resolved" and not hunt.red_locked() and not hunt.injury_screen.visible,"Clown resolution does not clear the injury and release red after two hits")
 # A wall must still occlude contact; proximity alone is insufficient.
 game._build_world(HorseHunt.ID);game.player.active=false;hunt=game.world.horse_hunt;hunt.phase="following"
 game.player.position=Vector3(-9.8,0,-27.8);hunt.head=Vector3(-9.0,2.03,-27.8)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 hunt.tick(.01,true,game.player)
 verify.call(hunt.catch_count==0,"Horse jumpscares through the closed kitchen wall")
 game.player.position=Vector3(-7.9,0,-25.5);hunt.head=Vector3(-7.9,2.03,-26.5)
 await game.get_tree().physics_frame
 hunt.tick(.1,false,game.player);verify.call(hunt.catch_count==0,"Paused horse can still catch the player")
 hunt.tick(.01,true,game.player);verify.call(hunt.catch_count==1,"Visible contact fails to trigger after resuming")
 game._build_world("none");hunt=game.world.horse_hunt;hunt.tick(30,true,game.player)
 verify.call(not hunt.enabled and hunt.catch_count==0 and not hunt.catch_audio.playing and hunt.horse.mask.visible,"Normal reference horse now attacks")
 hunt.present_contact(true);verify.call(not hunt.injury_screen.visible,"Normal round retains a bloodshot border")
 # Third contact is a distinct fatal attack, followed by the ordinary wake-up.
 game.state.current=HorseHunt.ID;game.state.streak=4;game._build_world(HorseHunt.ID);hunt=game.world.horse_hunt;game.player.active=false
 game.archive.collected.assign(["note"]);game.archive.parking_key_found=true;game._sync_parking_key()
 game.player.position=Vector3(-7.9,0,-25.5);hunt.head=Vector3(-7.9,2.03,-26.5)
 for hit in range(2):hunt._catch(game.player);hunt.tick(1.06,true,game.player)
 var damage:=hunt.serialize().duplicate(true);damage.injury_strength=INF;var previous:=hunt.catch_count;hunt.restore(damage)
 verify.call(hunt.catch_count==previous,"Invalid injury data mutates the live pursuit")
 hunt._catch(game.player);hunt.tick(.3,true,game.player);hunt.present_contact(true)
 verify.call(hunt.phase=="fatal" and hunt.catch_count==3 and game.phase=="horse_death" and not game.player.active,"Third contact does not lock the player into a fatal attack")
 verify.call(hunt.catch_jaw.rotation.x< -1.2 and hunt.catch_audio.playing and hunt.catch_audio.stream.resource_path==HorseHunt.FATAL_SCREAM,"Fatal horse lacks its wide-open jaw and distinct shrill scream")
 verify.call(game.state.streak==0 and game.archive.collected.is_empty() and not game.archive.parking_key_found and game.wake_pending and game.survived==4,"Fatal attack fails to reset the shift and inventory")
 var save=JSON.parse_string(game._persistent_text(game.SAVE))
 verify.call(save.wake_pending and save.patrol.streak==0 and save.horse_hunt.is_empty(),"Quitting during the fatal attack can revive the previous run")
 var count:=hunt.catch_count;hunt.tick(2.,false,game.player)
 verify.call(hunt.phase_clock<.31 and hunt.catch_audio.stream_paused and hunt.catch_count==count,"Suspended fatal attack continues its scream or animation")
 hunt.tick(.9,true,game.player)
 verify.call(hunt.phase=="dead" and game.phase=="death" and not hunt.music.playing and not hunt.catch_audio.playing,"Fatal impact does not stop chase audio and enter the death screen")
 hunt.tick(3.,true,game.player);verify.call(hunt.catch_count==3,"Dead horse damages the player repeatedly")
 await game.get_tree().create_timer(.7).timeout
 verify.call(game.death_label.visible and game.death_label.text=="4 Runden überlebt","Horse death omits the survived-round count")
 await game.get_tree().create_timer(2.2).timeout
 verify.call(game.phase=="arrival" and game.player.position.distance_to(Vector3(-8,0,19.35))<.1,"Horse victim does not wake in the original lift")
 game.intro.tick(1.2);game.player.active=false
 verify.call(game.phase=="play" and game.state.streak==0 and game.state.current=="none" and not game.world.horse_hunt.injury_screen.visible,"New patrol retains horse damage or starts after round one")
 game.player.set_physics_process(true);game.set_process(true)
