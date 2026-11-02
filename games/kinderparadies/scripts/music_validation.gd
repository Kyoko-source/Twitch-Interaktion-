extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false
 var hunt: HorseHunt=game.world.horse_hunt
 hunt.tick(.5,true,game.player)
 verify.call(not hunt.music.playing,"A normal round plays horse chase music")
 game._open_archive_lock();game.archive_input=HorseHunt.TEST_CODE;game._submit_archive_code();game.player.active=false
 hunt=game.world.horse_hunt;hunt.tick(.1,true,game.player)
 for i in range(10):await game.get_tree().physics_frame
 verify.call(hunt.music.playing and hunt.music.stream.resource_path==HorseHunt.MUSIC and (hunt.music.stream as AudioStreamMP3).loop,"Horse code does not start the requested looping MP3")
 hunt.music.seek(21.0);hunt.tick(.5,true,game.player)
 for i in range(5):await game.get_tree().physics_frame
 var position:=hunt.music.get_playback_position();hunt.tick(.1,false,game.player)
 for i in range(12):await game.get_tree().physics_frame
 verify.call(hunt.music.stream_paused and absf(hunt.music.get_playback_position()-position)<.12,"Pause does not freeze the chase song")
 game._save();game.has_session=false;game._continue();game.player.active=false;hunt=game.world.horse_hunt;hunt.tick(.05,true,game.player)
 for i in range(5):await game.get_tree().physics_frame
 print("MUSIC RESUME expected=",position," actual=",hunt.music.get_playback_position()," playing=",hunt.music.playing," paused=",hunt.music.stream_paused," snapshot=",JSON.stringify(hunt.snapshot()))
 verify.call(hunt.music.playing and not hunt.music.stream_paused and absf(hunt.music.get_playback_position()-position)<.5,"Saved hunt restarts the music instead of continuing its saved position")
 var gain: float=hunt.music.volume_db;var previous: String=hunt.phase;hunt.phase="catch";hunt._music(.6,true)
 verify.call(hunt.music.volume_db<gain-5,"Horse contact scream has no space in the music mix")
 hunt.phase=previous;hunt._music(1,true)
 verify.call(hunt.music.volume_db>gain-1,"Chase music stays quiet after the scare")
 hunt.phase="resolved";hunt.tick(1,true,game.player)
 verify.call(not hunt.music.playing,"Chase music continues after the horse is resolved")
 for ending in [1,2,3]:
  game._show_ending(ending)
  var credits: EndCredits=game.end_credits;credits.tick(credits.title_length()+1)
  for i in range(5):await game.get_tree().physics_frame
  verify.call(credits.music.playing and credits.music.stream.resource_path==EndCredits.MUSIC,"Ending "+str(ending)+" does not play Fern and Feather")
  verify.call(credits.music.stream.get_length()>100 and credits.music.volume_db> -12,"Credits MP3 is truncated or inaudible")
  await credits.wait_prepared();credits.finish_scroll();credits.tick(.3)
  verify.call(credits.afterglow!=null and credits.music.playing,"Skipping credits loses the new song during the closing shot")
  credits._finish_afterglow()
  verify.call(not credits.music.playing,"Finished credits leave a music loop running")
 game._main_menu();game.set_process(true)
