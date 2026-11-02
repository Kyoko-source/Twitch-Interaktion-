extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-empfang-vom-saal","p":Vector3(-6.6,0,11.2),"look":Vector3(-9.2,1.55,7.3)},
  {"id":"02-eintritt-an-der-kasse","p":Vector3(-11.2,0,9.4),"look":Vector3(-8.25,1.18,7.85)},
  {"id":"03-buerostuhl-und-arbeitsplatz","p":Vector3(-6.3,0,4.5),"look":Vector3(-8.6,1.10,7.5)},
  {"id":"04-wandanordnung","p":Vector3(-6.6,0,6.65),"look":Vector3(-9.98,2.35,6.7)}]
 for view in views:
  author.pose(game,view.p,view.look);game.player.lamp.show()
  await author.settle(game);author.save(game,output,view.id)
 print("V354 RENDER COMPLETE ",JSON.stringify(SceneAudit.placement(game.world)))
