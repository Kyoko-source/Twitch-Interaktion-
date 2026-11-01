extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-wartung-druckflaeche","p":Vector3(-7.0,0,-2.5),"look":Vector3(-9.94,2.7,-5.4),"floor":1},
  {"id":"02-party-schild","p":Vector3(3.5,0,-5.5),"look":Vector3(6.61,3.55,-8.7),"floor":1},
  {"id":"03-empfang-plakate","p":Vector3(-8.3,0,7.4),"look":Vector3(-9.96,2.1,7.6),"floor":1},
  {"id":"04-kinoflur","p":Vector3(-7.9,0,-15.3),"look":Vector3(-7.9,1.8,-27),"floor":1},
  {"id":"05-startfahrstuhl-etage-01","p":Vector3(-8,0,19.35),"look":Vector3(-8,2.57,17.384),"floor":1},
  {"id":"06-startfahrstuhl-etage-05","p":Vector3(-8,0,19.35),"look":Vector3(-8,2.57,17.384),"floor":5},
  {"id":"07-gruener-flur-etage-05","p":Vector3(-4.3,0,-18.0),"look":Vector3(-4.3,2.57,-19.63),"floor":5},
  {"id":"08-startfahrstuhl-etage-13","p":Vector3(-8,0,19.35),"look":Vector3(-8,2.57,17.384),"floor":13},
  {"id":"09-roter-flur-etage-13","p":Vector3(-2.15,0,-18.0),"look":Vector3(-2.15,2.57,-19.63),"floor":13}]
 for view in views:
  game.state.streak=view.floor-1;game._refresh_hud()
  author.pose(game,view.p,view.look);game.player.lamp.show()
  await author.settle(game);author.save(game,output,view.id)
 var report:={"layout":SceneAudit.inspect(game.world),"entrance":game.intro.snapshot(),"passages":game.world.passages.snapshot()}
 var file:=FileAccess.open(output.path_join("scene-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V351 RENDER COMPLETE ",JSON.stringify(report))
