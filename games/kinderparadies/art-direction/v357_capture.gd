extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 for view in [
  {"id":"01-flacher-podestaufgang","p":Vector3(15.6,0,-8.8),"look":Vector3(13.6,.35,-10.0)},
  {"id":"02-spielauto-am-klettergeruest","p":Vector3(2.7,0,-10.0),"look":Vector3(4.15,.6,-7.45)},
  {"id":"03-freier-zugang-partyraum","p":Vector3(4.8,0,-9.7),"look":Vector3(6.8,1.5,-8.7)}]:
  author.pose(game,view.p,view.look);game.player.lamp.show();game.prompt.hide()
  await author.settle(game);author.save(game,output,view.id)
 print("V357 RENDER COMPLETE ",JSON.stringify(game.world.backstage.snapshot()))
