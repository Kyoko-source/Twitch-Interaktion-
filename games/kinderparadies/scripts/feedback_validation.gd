extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 var hashes: Dictionary={}
 var speaker:=AudioStreamPlayer3D.new();g.add_child(speaker)
 var flat:=AudioStreamPlayer.new();g.add_child(flat)
 for character in ScareBank.VOICES:
  for variant in range(1,ScareBank.VARIANTS+1):
   var path:=ScareBank.track(character,variant);var stream: AudioStream=load(path)
   verify.call(stream!=null and stream.get_length()>.6 and stream.get_length()<1.5,"Missing complete character voice: "+path)
   var digest:=FileAccess.get_sha256(path)
   verify.call(not hashes.has(digest),"Characters or voice variants use identical audio: "+path);hashes[digest]=true
  var id: String={"granny":"granny_wc_stall_watcher","horse":"horse_contact","door":"door_death"}[character]
  var previous:=""
  for i in range(5):
   ScareBank.select(speaker,id);ScareBank.play(speaker)
   verify.call(speaker.stream.resource_path!=previous and speaker.get_meta("scare_family")==character,"3D voice repeats or selects the wrong character: "+character)
   previous=speaker.stream.resource_path
   flat.stream=ScareBank.flat(id);ScareBank.play_flat(flat)
   verify.call(flat.stream.resource_path!=previous,"Flat and positional voices repeat the same take consecutively: "+character)
   previous=flat.stream.resource_path
 g._new_shift();g.intro.skip();g.set_process(false);g.player.active=false
 g._build_world("wc_stall_watcher")
 verify.call(g.world.terrors.audio.get_meta("scare_family")=="granny","Actual granny encounter uses a generic sound family")
 var failure:=DoorFailure.new();g.player.camera.add_child(failure);failure.start_patrol(g.world,g.player.camera)
 verify.call(failure.audio.stream.resource_path.contains("/door-"),"Wrong-door attacker reuses another creature's voice")
 failure.tick(.42);verify.call(failure.audio.playing,"A slow frame skips the wrong-door attack sound")
 var voice_path:=failure.audio.stream.resource_path;failure.tick(.02)
 verify.call(failure.audio.stream.resource_path==voice_path and failure.sound_started,"Door attack repeats its voice within one lunge")
 failure.tick(1.2);verify.call(not failure.running and not failure.audio.playing,"Door attack voice remains after the scare")
 failure.queue_free();speaker.queue_free();flat.queue_free()
 g._build_world(HorseHunt.ID)
 verify.call(g.world.horse_hunt.catch_audio.stream.resource_path.contains("/horse-"),"Actual horse still uses the ossuary sting")
 verify.call(g.world.horse_hunt.FATAL_SCREAM.ends_with("horse-final-scream.wav"),"Fatal third strike lost its separate escalation")
 g._interact_target("cinema_projector");verify.call(g.player.foley.last=="switch" and not g.world.film.playing,"Empty projector has no button click or starts without a reel")
 g._interact_target("archive_recording");verify.call(g.player.foley.last=="switch","Recording button has no contact click")
 g.set_process(true)
