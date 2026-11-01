extends RefCounted

func run(game: Node3D, output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._main_menu();await author.settle(game);author.save(game,output,"00-main-menu")
 await author.run(game,output)
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.player.torch_body.show();game.player.lamp.show()
 for view in [
  {"id":"09-prep-station","p":Vector3(-13.0,0,-16.0)+ServiceAnnex.OFFSET,"look":Vector3(-13.3,1.35,-13.8)+ServiceAnnex.OFFSET},
  {"id":"10-clown-close","p":Vector3(-12.25,0,-18.65)+ServiceAnnex.OFFSET,"look":Vector3(-14.4,1.86,-19.25)+ServiceAnnex.OFFSET},
  {"id":"11-cinema-skull","p":Vector3(-4.7,0,-18.0)+ServiceAnnex.OFFSET,"look":Vector3(-1.9,2.3,-20.1)+ServiceAnnex.OFFSET},
  {"id":"12-clear-booth-approach","p":Vector3(12.6,0,14.25),"look":Vector3(13,1.3,16.3)}]:
  author.pose(game,view.p,view.look);await author.settle(game);author.save(game,output,view.id)
 var file:=FileAccess.open(output.path_join("v300-audit.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"layout":SceneAudit.inspect(game.world),"details":game.world.revamp.details,"adapter":RenderingServer.get_video_adapter_name()}," "))
 print("V300 RENDER COMPLETE")

func actors(game: Node3D, output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game.settings=game.DEFAULT_SETTINGS.duplicate(true);game.settings.volume=0;game._apply_settings()
 game._new_shift();game.intro.skip();game.player.set_physics_process(false)
 for view in [
  {"id":"cinema_aisle_rush","p":Vector3(-1,0,-29.65)},
  {"id":"wc_ceiling_guest","p":Vector3(22.4,0,7.1)},
  {"id":"party_guests","p":Vector3(12.4,0,-3)}]:
  game._build_world(view.id);game._resume();game.player.active=false;game.notice_time=0;game.notice.hide()
  var terror: NightTerrors=game.world.terrors
  author.pose(game,view.p,terror.focus_point())
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  terror.elapsed=.9;terror.tick(.01,true,game.player)
  await game.get_tree().create_timer(.18).timeout
  await RenderingServer.frame_post_draw;author.save(game,output,view.id)
 game._build_world("none");game._resume();game.player.active=false;author.pose(game,Vector3(-3.5,0,8.8),Vector3(4,2.5,0))
 await author.settle(game)
 var start:=Time.get_ticks_usec()
 for i in range(90): await game.get_tree().process_frame
 var report:={"fps":90./((Time.get_ticks_usec()-start)/1000000.),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"size":str(game.get_viewport().size),"layout":SceneAudit.inspect(game.world)}
 var file:=FileAccess.open(output.path_join("render-proof.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V300 ACTORS ",JSON.stringify(report))
