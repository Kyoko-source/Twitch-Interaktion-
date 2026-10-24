extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 game._help("play")
 var copy:=""
 for line in game.menu.find_children("*","Label",true,false): copy+=line.text+"\n"
 verify.call("13 Rundgänge. 13 mal der gleiche Raum...oder?..." in copy and "Sterueung" in copy and "E: interagieren" in copy and "F11: Vollbild" in copy,"Requested instruction copy is missing")
 verify.call("6428" not in copy and "Normal:" not in copy and "Küchenclown" not in copy,"Instructions still disclose story or anomaly solutions")
 game._resume();game.player.active=false
 var giants: Array=game.world.find_children("*","Node3D",true,false).filter(func(n):return n.get_meta("giant_mascot",false))
 verify.call(giants.size()==1 and giants[0].name=="PartyMascotCorner","The giant rabbit still appears outside the party room")
 var kit: Node3D=game.world.annex.find_child("ManufacturedKitchen",true,false)
 verify.call(is_instance_valid(kit) and kit.find_children("*","MeshInstance3D",true,false).size()>=7,"The manufactured kitchen mesh kit failed to load")
 # Finish the real final decision, keeping an already found story paper.
 game.archive.collected.append("opening")
 for i in range(12): game.state.decide(game.state.current!="none")
 await PassageChecks.travel(game,game.state.current!="none")
 var timeout:=0
 while game.phase!="play" and timeout<300: await game.get_tree().physics_frame;timeout+=1
 game.player.active=false
 verify.call(game.state.completed and game.state.streak==13 and game.phase=="play","The thirteenth door does not return to a playable room")
 verify.call(game.player.position.distance_to(Vector3(-8,0,19.35))<.15 and game.world.current=="none","Patrol completion does not restore the normal starting room")
 verify.call(game.world.archive.items.has("patrol_hint"),"The final hint newspaper is missing from the floor")
 game.player.camera.look_at(Vector3(-8,.038,17.95));await game.get_tree().physics_frame
 verify.call(game._target()=="paper:patrol_hint","The final floor newspaper cannot be collected with the real interaction ray")
 var spawned: Vector3=game.world.archive.items.patrol_hint.global_position
 verify.call(spawned.y>.02 and spawned.y<.08 and spawned.distance_to(game.player.position)<2,"The ending newspaper floats or is out of reach")
 game._save();game._main_menu();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.phase=="play" and game.state.completed and game.world.current=="none" and game.world.archive.items.has("patrol_hint"),"Save/resume loses the completed patrol or creates a new anomaly")
 game._collect_paper("patrol_hint");game._inventory()
 verify.call("patrol_hint" in game.archive.collected and not game.world.archive.items.has("patrol_hint") and game.archive_selected=="patrol_hint","The floor newspaper fails to enter the persistent inventory")
 var reader:=""
 for line in game.menu.find_children("*","RichTextLabel",true,false): reader+=line.text
 verify.call(reader==ArchiveState.document("patrol_hint").body and "3, 5, 8 und 11" in reader,"The final newspaper does not display the exact requested hint")
 game._archive_back();await PassageChecks.travel(game,false);game.player.active=false
 verify.call(not game.state.completed and game.state.streak==0 and "opening" in game.archive.collected and "patrol_hint" in game.archive.collected,"A new search deletes the surviving shift's papers")
 # Every new placement must have an actual sightline that activates its sting.
 for id in NightTerrors.SCENARIOS:
  if not NightTerrors.SCENARIOS[id].has("sound"): continue
  game._build_world(id);game._resume();game.player.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var terror: NightTerrors=game.world.terrors
  var triggered:=false
  if id=="tube_burst":
   game.player.position=CrawlTubes.route(8.5)-Vector3.UP*.72;game.player.set_crouch(true);game.player.camera.position.y=.8;game.player.camera.look_at(terror.focus_point());terror.tick(1,true,game.player);triggered=terror.triggered
  else:
   var target:=terror.focus_point()
   for offset in [Vector3(0,0,2.2),Vector3(2.2,0,0),Vector3(0,0,-2.2),Vector3(-2.2,0,0),Vector3(1.3,0,1.3)]:
    game.player.position=Vector3(target.x,terror.origin.y if terror.spec.mode=="crawl" else 0,target.z)+offset
    if terror.spec.mode=="drop": game.player.position.y=0
    game.player.set_crouch(false);game.player.camera.position.y=1.65;game.player.camera.look_at(target)
    terror.tick(1,true,game.player)
    if terror.triggered: triggered=true;break
  verify.call(triggered and terror.audio.stream.resource_path.begins_with("res://assets/scares-v260/"),"New encounter has no accessible visual trigger or dedicated sound: "+id)
  await game.get_tree().process_frame;await game.get_tree().process_frame
  game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame
  terror.tick(.2,false,game.player)
  verify.call(not terror.audio.playing or terror.audio.stream_paused,"New scare remains audible when paused: "+id)
 game._show_archive_ending();await game.get_tree().process_frame;await game.get_tree().process_frame
 var note: Label=game.end_credits.roll.find_child("KyokoNote",true,false)
 verify.call(note.text==EndCredits.KYOKO_NOTE and note.autowrap_mode!=TextServer.AUTOWRAP_OFF and note.size.x>1200,"Kyoko's final note is missing or cannot wrap in the credits")
 verify.call(game.end_credits.music.stream.resource_path==RoomHorror.MUSIC,"The added credits note replaced the requested music-box track")
 game._new_shift();game.intro.skip()
