extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-fenster-vorhaenge","p":Vector3(-6.4,0,1.7),"look":Vector3(-10.2,2.35,1.7)},
  {"id":"02-blick-durch-die-bretter","p":Vector3(-9.5,0,1.7),"look":Vector3(-22,1.65,1.7)},
  {"id":"03-barrikade-von-aussen","p":Vector3(-13.5,0,2.4),"look":Vector3(-10.2,2.55,1.7)}]
 for view in views:
  author.pose(game,view.p,view.look);game.player.lamp.show()
  await author.settle(game);author.save(game,output,view.id)
 print("V353 RENDER COMPLETE ",JSON.stringify(SceneAudit.placement(game.world)))
