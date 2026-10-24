extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 var ids: Array[String]=[];var zones: Dictionary={}
 for anomaly in PatrolState.ANOMALIES:
  ids.append(anomaly.id);zones[anomaly.zone]=zones.get(anomaly.zone,0)+1
 verify.call(ids.size()==61 and NightTerrors.SCENARIOS.size()==34,"Expanded catalog must provide 61 anomalies including 34 visitor placements")
 verify.call(zones.size()==7 and zones["Küche"]>=3 and zones["Kino"]>=3 and zones["Krabbelröhre"]>=2,"New encounters are not spread across the annex and tunnel")
 var legacy:=PatrolState.new();legacy.start(21)
 for retired in PatrolState.REPLACEMENTS:
  verify.call(retired not in ids and PatrolState.REPLACEMENTS[retired] in ids,"A retired anomaly is still selectable or lacks a replacement")
  for streak in [3,4]:
   var data:=legacy.serialize();data.current=retired;data.bag=[retired];data.streak=streak
   var restored:=PatrolState.new();var expected: String="none" if streak==4 else PatrolState.REPLACEMENTS[retired]
   verify.call(restored.restore(data) and restored.streak==streak and restored.current==expected and restored.bag==[PatrolState.REPLACEMENTS[retired]],"A legacy save loses progress or violates the newspaper-round rule")
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
  if t.spec.mode in ["tube","window"]:
   game.player.position=CrawlTubes.route(7.0)+Vector3(0,-.72,0);t.tick(0,false,game.player)
   verify.call(t.actor.visible,"Tunnel visitor is not visible from inside")
   game.player.position=Vector3(-1,0,12);t.tick(0,false,game.player)
   verify.call(not t.actor.visible and not t.marker.visible,"Tunnel visitor or its remnant leaks into the outside scene")
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
