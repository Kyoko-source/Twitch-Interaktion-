extends RefCounted

func run(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 var w: PlayWorld=game.world;var acoustic:=w.acoustics
 # Record the acoustic submix before the muted master. This never plays loud
 # test tones through the user's speakers and never changes player save files.
 AudioServer.set_bus_volume_db(0,-80)
 for source in w.find_children("*","AudioStreamPlayer3D",true,false):source.volume_db=-80
 game.room_audio.stop();game.menu_music.stop();game.effect.stop()
 var source: AudioStreamPlayer3D=w.annex.sources[1]
 source.global_position=Vector3(-11.9,1.4,9.4);source.volume_db=0;source.stream_paused=false;source.play()
 game.player.position=Vector3(-9,0,9.4);game.player.camera.position=Vector3(0,1.65,0)
 var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
 var index:=AudioServer.get_bus_index("AP.Room");AudioServer.add_bus_effect(index,recorder)
 for open in [false,true]:
  w.backstage.exit_open=open;w.backstage.exit_leaf.rotation.y=PI*.49 if open else 0.
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  for i in range(10):acoustic.tick(.1,true,game.player);await game.get_tree().create_timer(.1).timeout
  recorder.set_recording_active(true)
  await game.get_tree().create_timer(2.5).timeout
  recorder.set_recording_active(false)
  var stream:=recorder.get_recording()
  stream.save_to_wav(output.path_join("door-open.wav" if open else "door-closed.wav"))
  print("ACOUSTIC SIGNAL ","open" if open else "closed"," bytes=",stream.data.size()," ",JSON.stringify(acoustic.solve(source,game.player.camera.global_position,[game.player.get_rid()])))
 AudioServer.remove_bus_effect(index,AudioServer.get_bus_effect_count(index)-1)
 print("V320 AUDIO CAPTURE COMPLETE")
