extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-fenster","p":Vector3(-7.1,0,2.4),"look":Vector3(-13,2.2,1.7)},
  {"id":"02-parkplatz","p":Vector3(-9.1,.2,1.3),"look":Vector3(-22,2.2,2.6)},
  {"id":"03-hauptsaal","p":Vector3(-6.7,0,9.0),"look":Vector3(4.8,2.9,3.6)},
  {"id":"04-automaten","p":Vector3(8.0,0,13.8),"look":Vector3(8.4,1.65,16.4)},
  {"id":"05-kueche","p":Vector3(-11.9,0,-27.8),"look":Vector3(-15,1.6,-30.8)},
  {"id":"06-kino","p":Vector3(-5.35,0,-29.5),"look":Vector3(2.8,1.5,-30.4)},
  {"id":"07-partyraum","p":Vector3(7.6,0,-8.7),"look":Vector3(13.3,1.5,-5.0)},
  {"id":"08-wartung","p":Vector3(-11.3,0,-4.55),"look":Vector3(-15.8,1.6,-5.6)},
  {"id":"09-kostuemraum","p":Vector3(17.6,.2,-13.5),"look":Vector3(13.2,1.7,-16.1)},
  {"id":"10-toiletten","p":Vector3(20.8,0,8.0),"look":Vector3(24.5,1.1,6.0)}]
 var timings: Dictionary={}
 for view in views:
  author.pose(game,view.p,view.look);await author.settle(game);author.save(game,output,view.id)
  timings[view.id]={"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
 var report:={"layout":SceneAudit.inspect(game.world),"graphics":game.world.graphics.snapshot(),"acoustics":game.world.acoustics.snapshot(),"views":timings}
 var file:=FileAccess.open(output.path_join("scene-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V320 RENDER COMPLETE ",JSON.stringify(report))
