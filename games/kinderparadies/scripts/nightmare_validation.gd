extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 var ids: Array[String]=[];var zones: Dictionary={}
 for anomaly in PatrolState.ANOMALIES:
  ids.append(anomaly.id);zones[anomaly.zone]=zones.get(anomaly.zone,0)+1
 verify.call(ids.size()==66 and NightTerrors.SCENARIOS.size()==37,"Expanded catalog must provide 66 anomalies including 37 visitor placements")
 verify.call(zones.size()==8 and zones["Kinder-WC"]==2 and zones["Küche"]>=3 and zones["Kino"]>=3 and zones["Krabbelröhre"]>=2,"New encounters are not spread across the annex, WC and tunnel")
 var legacy:=PatrolState.new();legacy.start(21)
 for retired in PatrolState.REPLACEMENTS:
  verify.call(retired not in ids and PatrolState.REPLACEMENTS[retired] in ids,"A retired anomaly is still selectable or lacks a replacement")
  for streak in [3,4]:
   var data:=legacy.serialize();data.current=retired;data.bag=[retired];data.streak=streak
   var restored:=PatrolState.new();var expected: String=PatrolState.REPLACEMENTS[retired]
   verify.call(restored.restore(data) and restored.streak==streak and restored.current==expected and restored.bag==[PatrolState.REPLACEMENTS[retired]],"A legacy save loses progress or its replaced anomaly")
 for id in NightTerrors.SCENARIOS:
  game._build_world(id);game._resume();game.player.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var t: NightTerrors=game.world.terrors
  verify.call(t.id==id and is_instance_valid(t.actor) and t.visual.find_children("*","MeshInstance3D",true,false).size()>=5,"New physical visitor is missing: "+id)
  if t.spec.mode=="pursuit":
   var bounds:=AABB();var first:=true
   for mesh in t.visual.find_children("*","MeshInstance3D",true,false):
    var box: AABB=(t.actor.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
    bounds=box if first else bounds.merge(box);first=false
   verify.call(bounds.end.y<2.2 and bounds.end.y>1.8,"Visitor head hierarchy has a doubled transform: "+id)
  t.elapsed=0;t.triggered=false;t.finished=false;t.attack=0
  var pos: Vector3=t.actor.position
  game.player.position=pos+Vector3(0,0,2.8);game.player.rotation=Vector3.ZERO;game.player.camera.rotation=Vector3.ZERO
  t.tick(.3,false,game.player)
  verify.call(t.elapsed==0 and t.actor.position==pos and (not t.audio.playing or t.audio.stream_paused),"Pause changes an encounter or leaves its audio active: "+id)
  # Exercise the real pause/one-shot timeline for every distinct behavior.
  t.triggered=true;t.audio.play();t.tick(.15,true,game.player)
  # Audio playback is queued by Godot. Let the real game loop start it before
  # pausing, rather than asserting the backend's flags in the same call stack.
  await game.get_tree().process_frame;await game.get_tree().process_frame
  game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame
  var attack: float=t.attack;pos=t.actor.position;var visual: Transform3D=t.visual.transform
  t.tick(.6,false,game.player)
  verify.call(t.attack==attack and t.actor.position==pos and t.visual.transform==visual and (not t.audio.playing or t.audio.stream_paused) and (not t.footsteps.playing or t.footsteps.stream_paused),"A triggered scare moves or sounds while paused: "+id)
  game._resume();game.player.active=false;t.tick(6,true,game.player);var final_attack: float=t.attack;t.tick(1,true,game.player)
  verify.call(t.finished and t.attack==final_attack and is_instance_valid(t.marker),"Scare repeats or loses its lasting clue: "+id)
  verify.call(not t.actor.visible and (t.vanished or t.spec.mode=="vent"),"Visitor stays visible after its jumpscare: "+id)
  if t.spec.mode in ["tube","window"]:
   game.player.position=CrawlTubes.route(7.0)+Vector3(0,-.72,0);t.tick(0,false,game.player)
   verify.call(not t.actor.visible and t.marker.visible,"Tunnel visitor stays after its scare or its remnant is missing inside")
   game.player.position=Vector3(-1,0,12);t.tick(0,false,game.player)
   verify.call(not t.actor.visible and not t.marker.visible,"Tunnel visitor or its remnant leaks into the outside scene")
 # 4.8.0 ball-pit arms: real skeletal arms that burst out, reach for the guard
 # and are yanked back under, leaving two bony hands standing between the balls.
 game._build_world("pit_hands");game._resume();game.player.active=false
 var pit: NightTerrors=game.world.terrors
 var clues: Array=pit.marker.get_children().filter(func(c):return c.name.begins_with("BoneClue"))
 verify.call(pit.spec.mode=="pit" and pit.bones.size()==5 and clues.size()==2 and pit.visual.find_children("*","MeshInstance3D",true,false).size()>=60,"Ball-pit arms are not five articulated skeletal arms with two lasting bony hands")
 verify.call(not pit.actor.visible and pit.audio.get_meta("scare_family","")=="ossuary","Ball-pit arms show before the scare or fall back to the quiet whisper")
 for clue in clues:
  var top: float=clue.global_position.y+clue.get_aabb().end.y
  verify.call(top>pit._pit_surface(clue.global_position)+.3,"A lasting bony hand is buried in the balls instead of standing out")
 game.player.global_position=Vector3(3.3,.03,9.25);game.player.camera.look_at(pit.focus_point())
 pit.triggered=true;pit.attack=0.;var tallest:=0.
 for i in range(30):
  pit.tick(1./60.,true,game.player)
  for arm in pit.bones: tallest=maxf(tallest,(arm.root as Node3D).global_position.y)
 verify.call(pit.actor.visible and tallest>.6,"Ball-pit arms never burst out above the balls")
 var lead: Dictionary=pit.bones[0];var hand: Vector3=(lead.wrist as Node3D).global_position
 verify.call(hand.distance_to(game.player.camera.global_position)<1.6 and hand.distance_to(game.player.camera.global_position)>.25,"The long arm does not reach for the guard's face or reaches into the camera")
 for i in range(150): pit.tick(1./60.,true,game.player)
 verify.call(pit.vanished and not pit.actor.visible and clues.all(func(c):return c.is_visible_in_tree()),"Ball-pit arms stay up after the scare or take the lasting clue with them")
 game._build_world("tube_watcher");game.player.active=false
 game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);game.world.tubes.tick(0,true,game.player)
 verify.call(game.world.tubes.watcher.visible,"Window watcher must be visible through the roof from inside")
 game.player.position=Vector3(-1,0,12);game.world.tubes.tick(0,true,game.player)
 verify.call(not game.world.tubes.watcher.visible,"Window watcher is visible after leaving the tube")
 game._build_world("service_pursuit");game._resume();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var pursuer: NightTerrors=game.world.terrors;pursuer.actor.position=Vector3(-9.75,0,-7);pursuer.triggered=true;game.player.position=Vector3(-12,0,-7)
 for i in range(60): pursuer.tick(1.0/60,true,game.player)
 verify.call(pursuer.actor.position.x> -10.05,"Pursuer passes through the west wall")
 game._build_world("none");game._resume()
 verify.call(game.world.terrors.spec.is_empty() and not is_instance_valid(game.world.terrors.actor),"Normal reference round contains an anomalous visitor")
