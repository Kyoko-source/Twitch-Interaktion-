extends RefCounted

func press(game: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)

func walk_aisles(game: Node3D, verify: Callable) -> void:
 game.player.active=true;game.player.rotation=Vector3.ZERO;game.player.set_crouch(false)
 for x in [-5.15,-3.55,-2.05,-.55,1.15]:
  game.player.position=Vector3(x,.03,-14.0)+ServiceAnnex.OFFSET;game.player.velocity=Vector3.ZERO
  Input.action_press("forward")
  for frame in range(240):
   await game.get_tree().physics_frame
   if game.player.position.z< -21.65+ServiceAnnex.OFFSET.z: break
  Input.action_release("forward")
  verify.call(game.player.position.z< -21.6+ServiceAnnex.OFFSET.z and absf(game.player.position.x-x)<.10,"Cinema seat aisle snags the walking guard at x="+str(x))
  Input.action_press("back")
  for frame in range(240):
   await game.get_tree().physics_frame
   if game.player.position.z> -14.15+ServiceAnnex.OFFSET.z: break
  Input.action_release("back")
  verify.call(game.player.position.z> -14.2+ServiceAnnex.OFFSET.z and absf(game.player.position.x-x)<.10,"Cinema seat aisle snags the returning guard at x="+str(x))
 game.player.active=false;game.player.velocity=Vector3.ZERO

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var film: CinemaFilm=game.world.film
 verify.call(ResourceLoader.exists(CinemaFilm.MOVIE) and ResourceLoader.exists(CinemaFilm.SOUND),"Archive film assets are absent")
 verify.call(not film.owned and not film.playing and film.video.stream==null,"Optional film decodes before being inserted")
 verify.call(SceneAudit.placement(game.world).doors.is_empty() and SceneAudit.placement(game.world).art.is_empty(),"Film dressing obstructs a route or overlaps a poster")
 verify.call(not film.start(),"Projector starts without collecting a reel")
 await walk_aisles(game,verify)
 game.player.position=Vector3(-5.15,0,-14.1)+ServiceAnnex.OFFSET;game.player.camera.look_at(film.reel.global_position+Vector3(0,.04,0))
 await game.get_tree().physics_frame
 verify.call(game._target()=="film_reel","The physical reel cannot be collected from the aisle")
 press(game)
 verify.call(game.archive.film_found and film.owned and not film.reel.visible,"E does not collect and hide the reel")
 var stored:=ArchiveState.new();verify.call(stored.restore(game.archive.serialize()) and stored.film_found,"Film collection is not saved")
 var invalid: Dictionary=game.archive.serialize();invalid.film_found="bad"
 verify.call(not stored.restore(invalid),"Malformed film ownership is accepted")
 game.player.position=Vector3(-5.05,0,-15.83)+ServiceAnnex.OFFSET;game.player.camera.look_at(Vector3(-6.245,1.27,-15.83)+ServiceAnnex.OFFSET)
 await game.get_tree().physics_frame
 verify.call(game._target()=="cinema_projector","Wall projector control cannot be reached while standing")
 press(game)
 verify.call(film.playing and film.screen.material_override==film.picture and film.spools.all(func(n):return n.visible),"E does not project the film and spin its reels")
 await game.get_tree().create_timer(1.2).timeout
 verify.call(film.video.stream_position>.75 and film.audio.get_playback_position()>.75,"Movie or spatial soundtrack does not advance")
 verify.call(absf(film.video.stream_position-film.audio.get_playback_position())<.3,"Film picture and sound are out of sync")
 game._pause();await game.get_tree().process_frame
 var at:=film.video.stream_position
 await game.get_tree().create_timer(.25).timeout
 verify.call(absf(film.video.stream_position-at)<.04 and film.audio.stream_paused,"Movie or soundtrack advances during pause")
 game._resume();game.player.active=false;await game.get_tree().create_timer(.3).timeout
 verify.call(film.video.stream_position>at+.15 and not film.audio.stream_paused,"Movie does not resume with the shift")
 press(game)
 verify.call(not film.playing and film.screen.material_override==film.original and not film.audio.playing,"Stopping the film does not restore NO SIGNAL")
 verify.call(film.start(),"Collected reel cannot be replayed")
 film.stop();game._pause();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.archive.film_found and game.world.film.owned and not game.world.film.reel.visible and not game.world.film.playing,"Continue loses the reel or resumes an unrelated projection")
 game._new_shift();game.intro.skip();game.player.active=false
 verify.call(not game.archive.film_found and game.world.film.reel.visible,"A fresh shift keeps the collected reel")
 game.archive.film_found=true;game.world.film.sync(true);game._decide(true);game.player.position=Vector3(PatrolPassage.CENTERS[1],0,PatrolPassage.ENTRY_Z-2.8)
 game.world.passages.tick(.01,true,game.player,false,false)
 verify.call(game.phase=="failure" and not game.archive.film_found,"Death keeps the previous shift's film reel")
 game._new_shift();game.intro.skip();game.player.active=false
