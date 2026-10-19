extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 for seed_value in range(1,17):
  var patrol:=PatrolState.new();patrol.start(seed_value)
  for stage in range(1,14):
   if stage in [3,5,8,11]: verify.call(patrol.current=="none","Newspaper round has an anomaly: seed %d, round %d"%[seed_value,stage])
   var before:=patrol.serialize().duplicate(true)
   patrol.decide(patrol.current!="none")
   if stage+1 in [3,5,8,11]:
    verify.call(patrol.bag==before.bag and patrol.deck==before.deck and str(patrol.rng.state)==before.rng,"Newspaper round consumes a random event")
 for stage in [3,5,8,11]:
  var previous:=PatrolState.new();previous.start(42);previous.streak=stage-1;previous.current="clown_lunge"
  var saved:=previous.serialize().duplicate(true)
  var migrated:=PatrolState.new()
  verify.call(migrated.restore(JSON.parse_string(JSON.stringify(saved))) and migrated.current=="none" and migrated.streak==stage-1,"Old newspaper save keeps its anomaly or loses progress")
  verify.call(migrated.decide(false).correct,"Green door is not correct on a restored newspaper round")
 var ordinary:=PatrolState.new();ordinary.start(42);ordinary.streak=3;ordinary.current="clown_lunge"
 var ordinary_restore:=PatrolState.new()
 verify.call(ordinary_restore.restore(ordinary.serialize()) and ordinary_restore.current=="clown_lunge","Ordinary round loses its saved anomaly")
 var story:=ArchiveState.new()
 verify.call(not story.try_code("6428"),"Knowing the code must not skip the four newspapers")
 verify.call(story.take("note",1) and not story.take("note",1),"The note must be collectible exactly once")
 var stages:={"opening":3,"missing":5,"coverup":8,"closure":11}
 for id in stages:
  verify.call(not story.take(id,stages[id]-1),"A paper was awarded on an incorrect round")
  verify.call(story.take(id,stages[id]),"A scheduled newspaper could not be collected")
 verify.call(not story.try_code("7428") and not story.unlocked,"The obsolete seventh-of-June code is still accepted")
 verify.call(story.try_code("6428") and story.unlocked,"The corrected June-sixth code does not unlock the archive")
 var restored:=ArchiveState.new();verify.call(restored.restore(JSON.parse_string(JSON.stringify(story.serialize()))) and restored.serialize()==story.serialize(),"Lore does not survive a save round trip")
 verify.call(not restored.restore({"version":1,"collected":["opening"],"unlocked":true}) and restored.collected.is_empty(),"A forged archive save unlocks the room")
 verify.call(not restored.restore({"version":1,"collected":["note","note"],"unlocked":false}),"Duplicate document IDs are accepted")
 verify.call("6. Juni" in str(ArchiveState.document("opening").body) and "7. Juni" not in str(ArchiveState.document("opening").body),"Opening article contradicts the confirmed 6428 solution")
 game._new_shift();game.intro.skip()
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var door_hit:=cast(game,Vector3(-8.8,.9,-9.9),Vector3(-12.0,.9,-9.9))
 verify.call(not door_hit.is_empty() and door_hit.collider.get_meta("interaction","")=="archive_door","The locked archive can be walked through")
 game.player.position=Vector3(-8.7,0,-9.9);game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(65): await game.get_tree().physics_frame
 Input.action_release("forward");verify.call(game.player.position.x> -10.0,"Movement bypasses the locked archive door")
 for stage in range(1,14):
  game.world.archive.sync(game.archive,stage)
  var spawned: Array[String]=[]
  for id in game.world.archive.items:
   if id in ArchiveState.PAPERS: spawned.append(id)
  var expected: Array[String]=[]
  for id in stages:
   if stages[id]==stage: expected.append(id)
  verify.call(spawned==expected,"Wrong newspaper spawn schedule at round "+str(stage))
  await game.get_tree().process_frame
 game.world.archive.sync(game.archive,1);game._collect_paper("note")
 verify.call(game.archive.collected==["note"],"Collecting the physical note does not update the inventory")
 game._inventory();var frozen: float=game.world.room_horror.clock
 await game.get_tree().create_timer(.15).timeout
 verify.call(game.phase=="inventory" and not game.player.active and game.world.room_horror.clock==frozen,"Reading the inventory fails to pause the room and movement")
 var tab:=InputEventKey.new();tab.physical_keycode=KEY_TAB;tab.pressed=true;game._input(tab)
 verify.call(game.phase=="play","TAB does not close the inventory before focus navigation")
 game._open_archive_lock();game.archive_input="64";game._inventory("code");game._input(tab)
 verify.call(game.phase=="code" and game.archive_input=="64","Opening documents from the lock discards the partial code or back context")
 game._resume()
 for id in stages:
  var stage: int=stages[id];game.state.streak=stage-1;game._build_world("none");game._resume()
  verify.call(game.world.archive.items.has(id),"Scheduled physical newspaper is missing: "+id)
  game._collect_paper(id);await game.get_tree().process_frame
  verify.call(id in game.archive.collected and not game.world.archive.items.has(id),"Collected newspaper leaves a visible duplicate/hitbox: "+id)
  game.world.archive.sync(game.archive,stage)
  verify.call(not game.world.archive.items.has(id),"A collected newspaper respawns in the same shift")
 game._save();game.has_session=false;game.archive.clear();game._continue()
 verify.call(game.archive.has_all_papers() and "note" in game.archive.collected and game.state.streak==10,"Continue loses collected papers or patrol progress")
 game._open_archive_lock();game.archive_input="0000";game._submit_archive_code()
 verify.call(game.phase=="code" and not game.archive.unlocked,"An incorrect code opens the archive")
 game.archive_input="6428";game._submit_archive_code()
 verify.call(game.phase=="play" and game.archive.unlocked,"Submitting the correct code fails to resume the round")
 game.world.archive.tick(3,true);await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(cast(game,Vector3(-8.8,.9,-9.9),Vector3(-12.0,.9,-9.9)).is_empty(),"The opened archive has an invisible wall or door collider")
 game.player.position=Vector3(-8.7,0,-9.9);game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(90): await game.get_tree().physics_frame
 Input.action_release("forward");verify.call(game.player.position.x< -11.5 and game.player.position.y>-.1,"The guard cannot physically enter the opened archive")
 game._save();game.has_session=false;game.archive.clear();game._continue()
 verify.call(game.archive.unlocked and game.player.position.x< -11.5 and game.world.archive.safe_pose(game.player.position),"Continue rejects a valid position inside the archive")
 game._collect_paper("casefile");verify.call("casefile" in game.archive.collected,"The optional archive record is not collectible")
 game.player.position=Vector3(-12.8,0,-9.9);game.player.rotation.y=-PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(105): await game.get_tree().physics_frame
 Input.action_release("forward");verify.call(game.player.position.x> -9.8,"The archive exit traps the guard")
 game.state.current="none";await game._decide(true)
 verify.call(game.phase=="intro" and game.archive.collected.is_empty() and not game.archive.unlocked and game.state.streak==0,"Death does not reset the lore collection together with the shift")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.SAVE))
 verify.call(saved.archive.collected.is_empty() and not saved.archive.unlocked and saved.intro_pending,"A death save resurrects collected newspapers or skips the intro")
 game.intro.skip();game._pause()

func cast(game: Node3D, a: Vector3, b: Vector3) -> Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(a,b,1);query.exclude=[game.player.get_rid()]
 return game.get_world_3d().direct_space_state.intersect_ray(query)
