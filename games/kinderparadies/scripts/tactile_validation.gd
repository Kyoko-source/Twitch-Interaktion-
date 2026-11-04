extends RefCounted

func press(g: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;g._unhandled_input(event)

func run(g: Node3D,verify: Callable) -> void:
 var original: Dictionary=g.settings.duplicate(true)
 g._new_shift();g.intro.skip();g.set_process(false);g.player.active=false
 var guard: NightGuard=g.player;var hand: GuardActions=guard.hands;var presence: GuardPresence=guard.presence
 var w: PlayWorld=g.world
 verify.call(hand.skeleton.get_bone_count()==17,"Interaction hand has no articulated fingers")
 verify.call(hand.find_children("*","CollisionShape3D",true,false).is_empty() and w.tactile.find_children("*","CollisionShape3D",true,false).is_empty(),"Close-up detail adds expensive walking collision")
 for id in ["red","green"]:
  var lever: Node3D=w.tactile.levers[id][0]
  w.tactile.touch(id);w.tactile.tick(.2,true)
  verify.call(absf(lever.rotation.z)>.3,"Door handle does not depress: "+id)
  var angle:=lever.rotation.z;w.tactile.tick(1.,false)
  verify.call(lever.rotation.z==angle,"Paused handle keeps moving")
  w.tactile.tick(.3,true);verify.call(absf(lever.rotation.z)<.001,"Handle fails to spring back")
 var control: Node3D=w.party.control
 guard.position=control.global_position+control.global_basis.z*.9;guard.position.y=.2;guard.camera.look_at(control.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 g.party_reboot_until=0;w.party.reboot_until=0
 verify.call(g._target()=="party_control","Refined button blocks its interaction ray")
 press(g);verify.call(not w.party.enabled and hand.kind=="party_control","Party toggles before the hand reaches its button")
 press(g);verify.call(hand.count==1,"Repeated E starts overlapping hands")
 hand.tick(.2,true);verify.call(w.party.enabled,"Button contact never starts the existing party")
 verify.call(guard.foley.last=="switch" and guard.foley.sound.playing,"Party button has no mechanical contact click")
 hand.tick(1.,true);verify.call(not hand.visible and not hand.sleeve.visible and not hand.fill.visible,"Hand or sleeve remains after interaction")
 hand.begin("party_control",control.global_position);hand.on_contact=func():w.party.interact()
 g._pause();hand.tick(2.,false)
 verify.call(hand.kind.is_empty() and w.party.enabled,"Pause executes an unfinished interaction")
 g._resume();guard.active=false;g.set_process(false)
 var key: Node3D=w.details.parking_key
 guard.position=key.global_position+key.global_basis.z*.9;guard.position.y=0;guard.camera.look_at(key.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="parking_key","Close-up hand changes key pickup targeting")
 press(g);verify.call(not g.archive.parking_key_found and hand.held.get_child_count()==1,"Key disappears before the pickup reaches it")
 hand.tick(.31,true);verify.call(g.archive.parking_key_found and not key.visible and w.backstage.exit_key_owned,"Key contact does not grant the parking key")
 verify.call(guard.foley.last=="keys" and guard.foley.sound.stream.resource_path.ends_with("keys.wav"),"Key pickup plays a door or cloth sound instead of keyring foley")
 var key_sounds:=guard.foley.count;g._interact_target("parking_key")
 verify.call(guard.foley.count==key_sounds,"An already collected key repeats its pickup sound")
 hand.tick(1.,true)
 var lock: Node3D=w.tactile.contact.delivery_exit
 guard.position=lock.global_position+lock.global_basis.z*.8;guard.position.y=0.;guard.camera.look_at(lock.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="delivery_exit","New key cylinder blocks the glass door target")
 press(g);verify.call(not w.backstage.exit_open and hand.kind=="delivery_exit","Parking door opens before key insertion")
 hand.tick(.26,true);verify.call(w.backstage.exit_open,"Turning the key fails to unlock the existing door")
 verify.call(guard.foley.last=="keys","Using the parking key has no physical feedback")
 hand.tick(1.,true)
 # Pick up a real newspaper through E, then read its existing inventory entry.
 g.state.streak=2;w.archive.sync(g.archive,3)
 guard.position=Vector3(10.2,0,-4.95);guard.camera.look_at(Vector3(10.2,.853,-6.05))
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="paper:opening","Refined newspaper cannot be targeted")
 var paper: MeshInstance3D=w.archive.items.opening.get_child(0)
 verify.call(paper.mesh.get_surface_count()==3 and paper.material_override==null,"Newspaper lacks its printed face, back and thin edge")
 press(g);verify.call("opening" not in g.archive.collected,"Paper collection commits before reaching it")
 hand.tick(.31,true);verify.call("opening" in g.archive.collected and not w.archive.items.has("opening"),"Visible paper pickup loses the real inventory item")
 verify.call(guard.foley.last=="paper","Newspaper collection has no paper rustle at hand contact")
 hand.tick(.34,true);verify.call(hand.world_item!=null and hand.held.visible,"Paper is not visible while being brought into the hand")
 hand.tick(1.,true)
 # The disabled animation option performs the same action immediately.
 g.settings.hand_actions=false;g._apply_settings();g.state.streak=4;w.archive.sync(g.archive,5)
 var cinema: Node3D=w.archive.items.missing
 guard.position=cinema.global_position+Vector3(0,-cinema.global_position.y,1.0);guard.camera.look_at(cinema.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="paper:missing","Cinema newspaper is obstructed after the surface update")
 press(g);verify.call("missing" in g.archive.collected and hand.kind.is_empty(),"Disabling hand animations prevents collection")
 verify.call(guard.foley.last=="paper","Disabling hand animations also disables paper feedback")
 g.archive_selected="opening";g._inventory();verify.call(guard.foley.last=="paper" and guard.foley.sound.playing,"Reading an owned newspaper has no paper movement sound")
 g._resume();guard.active=false;g.set_process(false)
 guard.toggle_lamp();verify.call(guard.foley.last=="switch","Flashlight switch is silent")
 guard.foley.tick(false);verify.call(guard.foley.sound.stream_paused,"Pause leaves interaction foley playing")
 guard.foley.tick(true);verify.call(not guard.foley.sound.stream_paused,"Interaction foley cannot resume")
 # Real grounded physics supplies the sprint fatigue; recovering does not need movement.
 guard.position=Vector3(-3.,.03,12.);guard.velocity=Vector3.ZERO
 for i in range(12):
  await g.get_tree().physics_frame;guard.velocity=Vector3(0,-3.,0);guard.move_and_slide()
 presence.reset();presence.set_active(true);guard.velocity=Vector3(4.5,-.1,0)
 for i in range(360):presence.tick(1./60.)
 verify.call(presence.effort>.95 and presence.breath.playing,"Sprinting fails to create audible effort")
 verify.call(is_equal_approx(presence.breath.pitch_scale,1.) and presence.breath.volume_db<=-10.,"Sprinting distorts or overamplifies the player's breathing")
 verify.call(presence.breath.stream.resource_path=="res://assets/player-v402/breathing.ogg" and presence.breath.stream.loop,"Player breathing reuses the horror ambience or loses its continuous breath cycles")
 var fatigue:=presence.effort;presence.set_active(false);presence.tick(20.)
 verify.call(presence.effort==fatigue and presence.breath.stream_paused,"Pause advances fatigue or leaves breathing audible")
 presence.set_active(true);guard.velocity=Vector3.ZERO
 for i in range(120):presence.tick(1./60.)
 verify.call(presence.effort<fatigue and presence.effort>.7,"Breathing recovery stops abruptly instead of settling")
 verify.call(is_equal_approx(presence.breath.pitch_scale,1.),"Recovery lowers the player's voice unnaturally")
 for i in range(1200):presence.tick(1./60.)
 verify.call(presence.effort==0 and not presence.breath.playing,"Breathing never settles after sprinting")
 presence.reset();presence.set_active(true);guard.velocity=Vector3(4.5,0,0);presence.tick(.016);guard.velocity=Vector3.ZERO;presence.tick(.016)
 verify.call(presence.offset.length()>0 and presence.offset.length()<.04,"Stopping has no bounded equipment follow-through")
 g.settings.body_motion=0.;g.settings.body_audio=0.;g._apply_settings();presence.effort=1.;presence.tick(.016)
 verify.call(presence.offset==Vector3.ZERO and not presence.breath.playing,"Zero body settings leave motion or breathing enabled")
 g.settings.body_audio=.55;g._apply_settings();presence.cloth_clock=0;guard.set_crouch(true)
 guard.position=CrawlTubes.route(5.);guard.velocity=Vector3(1.,0,0);w.tubes.inside=true;var cloth_count:=presence.cloth_count;presence.tick(.02)
 verify.call(presence.cloth_count==cloth_count+1,"Moving in the crawl tube has no clothing contact")
 w.tubes.inside=false;presence.cloth_clock=0.;guard.position=w.climbing.sky.route(2.);guard.position.y=SkyTube.FLOOR;presence.tick(.02)
 verify.call(presence.cloth_count==cloth_count+2,"Elevated plastic tube loses the clothing contact")
 guard.velocity=Vector3.ZERO;presence.cloth_clock=0.;presence.tick(1.)
 verify.call(presence.cloth_count==cloth_count+2,"Stationary crawling repeats clothing sounds")
 presence.reset();verify.call(not presence.breath.playing and not presence.cloth.playing and presence.effort==0.,"New-shift reset retains player audio or effort")
 guard.set_crouch(false)
 g.settings.hand_actions=false;g.settings.body_motion=.2;g.settings.body_audio=.35;g._write_settings();g.settings=g.DEFAULT_SETTINGS.duplicate(true);g._read_settings();g._apply_settings()
 verify.call(not hand.enabled and is_equal_approx(g.settings.body_motion,.2) and is_equal_approx(g.settings.body_audio,.35),"Body and hand preferences do not survive reload")
 AfterPlayLanguage.choose("en")
 verify.call(AfterPlayLanguage.t("Handanimationen")=="Hand animations" and AfterPlayLanguage.t("Körperbewegungen")=="Body movement","New comfort controls are untranslated")
 g.settings=original;g._apply_settings();g._write_settings();g.set_process(true);g._main_menu()
