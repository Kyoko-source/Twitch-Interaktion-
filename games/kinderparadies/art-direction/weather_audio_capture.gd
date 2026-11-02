extends RefCounted

func run(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 AudioServer.set_bus_volume_db(0,-80)
 var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
 var index:=AudioServer.get_bus_index(HappylandWeather.BUS);AudioServer.add_bus_effect(index,recorder)
 # Warm the gentle room level, then capture the actual filtered weather submix.
 await game.get_tree().create_timer(3).timeout
 recorder.set_recording_active(true)
 await game.get_tree().create_timer(2).timeout
 game.weather.cue_thunder()
 await game.get_tree().create_timer(12).timeout
 recorder.set_recording_active(false)
 var stream:=recorder.get_recording();stream.save_to_wav(output.path_join("regen-und-fernes-gewitter.wav"))
 print("WEATHER AUDIO CAPTURE ",stream.data.size()," bytes ",JSON.stringify(game.weather.snapshot()))
 AudioServer.remove_bus_effect(index,AudioServer.get_bus_effect_count(index)-1)
