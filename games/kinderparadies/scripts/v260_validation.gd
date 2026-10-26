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
 # Completion now ends at ENDE 1/2 instead of returning to a playable room.
 # Both endings and their saves are exercised in endings_validation.gd.
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
