extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 var unique: Dictionary={}
 for family in ScareBank.FAMILIES:
  var last:=0
  for i in range(12):
   var next:=ScareBank.next_variant(family)
   verify.call(next>=1 and next<=ScareBank.VARIANTS and next!=last,"Scare variant repeats immediately: "+family);last=next
  for i in range(1,ScareBank.VARIANTS+1):
   var path: String=ScareBank.track(family,i)
   var sound: AudioStream=load(path)
   verify.call(sound!=null and sound.get_length()>1.2 and sound.get_length()<3.5,"Missing complete new sound: "+path)
   var digest:=FileAccess.get_sha256(path);verify.call(not unique.has(digest),"Distinct scare families share the same audio bytes: "+path);unique[digest]=true
 verify.call(ScareBank.family("bunny_lunge")!=ScareBank.family("clown_lunge") and ScareBank.family("vent_strike")!=ScareBank.family("croc_snap"),"Hero creatures share a sound family")
 var speaker:=AudioStreamPlayer3D.new();game.add_child(speaker);var previous:=""
 for i in range(8):
  for unused in range(4): ScareBank.flat("costume_wakes")
  ScareBank.select(speaker,"wc_stall_watcher","peek");ScareBank.play(speaker)
  verify.call(speaker.stream.resource_path!=previous,"Unplayed scene preparation allows the same audible scare twice")
  previous=speaker.stream.resource_path
 speaker.queue_free()
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world
 verify.call(w.annex.clown.has("root") and w.annex.food!=null,"Kitchen cooking scene is incomplete")
 var food: MeshInstance3D=w.annex.get_node("PorousSpoiledFood")
 var normals: PackedVector3Array=food.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 verify.call(normals.size()>3000 and normals[10].y>.8,"New pot surface faces downward or has insufficient actual geometry")
 verify.call(w.revamp.details>=100,"Large scene restoration did not build")
 verify.call(w.revamp.has_node("KitchenRestoration/KitchenPrepStation") and w.revamp.has_node("KitchenRestoration/PhotographicKitchenTiles"),"Kitchen restoration lost its fitted prep station or tiled backsplash")
 verify.call(not w.revamp.clear_pose(Vector3(-13.3,.1,-14.0)+ServiceAnnex.OFFSET) and w.revamp.clear_pose(Vector3(-8,0,19)),"Old save can embed the guard inside the new fitted kitchen")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"New detail intrudes on architecture or circulation: "+JSON.stringify(layout))
 for panel in w.revamp.find_children("*","MeshInstance3D",true,false):
  if not panel.get_meta("new_acoustic_panel",false): continue
  var bounds: AABB=panel.global_transform*panel.get_aabb()
  for art in w.annex.find_children("*","MeshInstance3D",true,false):
   if art.get_meta("mounted_art",false):verify.call(not bounds.grow(.04).intersects(art.global_transform*art.get_aabb()),"A new cinema absorber covers an existing poster")
 var helper=load("res://scripts/validation.gd").new()
 await game.get_tree().physics_frame
 verify.call(helper.cast(game,Vector3(13,1.6,14.3),Vector3(13,1.6,15.25)).is_empty(),"Crocodile blocks the photo-booth approach")
 for mode in ["pursuit","ceiling","rush"]:
  var model: Node3D=(load(CharacterFinish.visitor("test",mode)) as PackedScene).instantiate();game.add_child(model)
  verify.call(model.find_child("HeadRig",true,false)!=null and model.find_child("ArmL",true,false)!=null,"Visitor variation lost its articulated anatomy: "+mode)
  model.queue_free()
 for id in ["bunny_lunge","croc_snap","clown_lunge","party_burst"]:
  game._build_world(id);game.player.active=false
  var e: NightEncounters=game.world.encounters
  verify.call(e.audio.stream.resource_path.begins_with(ScareBank.SOUND_ROOT) and e.anticipation!=null,"Hero scare uses its old shared recording: "+id)
  game._resume();game.player.active=false;e.anticipation.play();await game.get_tree().process_frame;await game.get_tree().process_frame
  game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame;e.tick(.1,false,game.player)
  verify.call(not e.anticipation.playing or e.anticipation.stream_paused,"Anticipation continues while paused: "+id)
 game._build_world("none");game._resume();game.player.active=false
 verify.call(game.world.terrors.spec.is_empty() and game.state.current=="none","Scene restoration introduces an anomaly into the reference round")
