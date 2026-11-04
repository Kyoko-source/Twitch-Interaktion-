extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var weather: HappylandWeather=game.weather
 verify.call(weather.rain.stream is AudioStreamOggVorbis and weather.rain.stream.loop,"Weather rain has no looping audio")
 verify.call(weather.rain.bus==HappylandWeather.BUS and AudioServer.get_bus_send(AudioServer.get_bus_index(HappylandWeather.BUS))=="NightAmbience","Weather bypasses ambience settings")
 for i in range(30):weather.tick(.1,true,"entrance")
 var near:=weather.rain.volume_db
 for i in range(30):weather.tick(.1,true,"cinema")
 verify.call(near>weather.rain.volume_db+8. and near< -12.,"Rain is not quiet or does not become muffled indoors")
 var clock:=weather.clock;var timer:=weather.next_roll
 game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame
 clock=weather.clock;timer=weather.next_roll
 await game.get_tree().create_timer(.2).timeout
 verify.call(weather.clock==clock and weather.next_roll==timer and weather.rain.stream_paused,"Pause advances weather or leaves rain audible")
 game._resume();game.player.active=false
 # A long combined suite may arrive during an existing roll. Exercise an idle
 # scheduler deliberately, rather than depending on its random prior timing.
 weather.thunder.stop()
 var count:=weather.count;weather.next_roll=0;weather.tick(.1,true,"hall")
 verify.call(weather.count==count+1 and weather.thunder.playing and weather.next_roll>=40 and weather.next_roll<=70,"Distant thunder has no spaced random scheduler")
 for i in range(30):weather.tick(.1,true,"hall")
 verify.call(weather.thunder.volume_db> -9 and weather.thunder.volume_db< -7,"Distant thunder is buried under the ordinary room ambience")
 var previous:=weather.last_variant;weather.thunder.stop();weather.cue_thunder()
 verify.call(weather.last_variant!=previous,"Consecutive thunder rolls repeat the same recording")
 for i in range(1,4):
  var stream:=load(HappylandWeather.ROOT+"distant-thunder-%d.ogg"%i) as AudioStreamOggVorbis
  verify.call(stream!=null and stream.get_length()>8 and stream.get_length()<12,"A distant thunder variant is missing or truncated")
 count=weather.count;weather.next_roll=0;weather.tick(.1,true,"archive",false)
 verify.call(weather.count==count and not weather.thunder.playing,"Thunder interrupts the archive recording")
 var amount: float=game.settings.ambience;game.settings.ambience=0;game._apply_settings()
 verify.call(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("NightAmbience"))< -70 and weather.rain.bus==HappylandWeather.BUS,"Ambience mute does not include weather")
 game.settings.ambience=amount;game._apply_settings()
 var identity:=weather.get_instance_id();var buses:=AudioServer.bus_count
 game._new_shift();game.intro.skip();game.player.active=false;await game.get_tree().process_frame
 verify.call(game.weather.get_instance_id()==identity and AudioServer.bus_count==buses,"A round rebuild duplicates or restarts the weather mixer")
 verify.call(game.state.current=="none" and game.world.current=="none","Ordinary weather counts as an anomaly")
 weather.thunder.stop();weather.next_roll=40
