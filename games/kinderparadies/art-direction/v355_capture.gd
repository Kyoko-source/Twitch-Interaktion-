extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-alter-holztuerrahmen","p":Vector3(-7.9,0,-8.9),"look":Vector3(-7.9,1.85,-12.5)},
  {"id":"02-tuerrahmen-detail","p":Vector3(-7.65,0,-10.7),"look":Vector3(-9.48,1.05,-12.0)},
  {"id":"03-snackbar-im-partyraum","p":Vector3(12.0,0,-3.0),"look":Vector3(12.0,1.35,.71)},
  {"id":"04-speisekarte-neben-der-bar","p":Vector3(9.1,0,-2.0),"look":Vector3(6.98,2.2,-.25)},
  {"id":"05-wartungswand-ohne-schild","p":Vector3(-6.5,0,-7.2),"look":Vector3(-9.98,2.15,-7.55)},
  {"id":"06-freier-alter-snackbarplatz","p":Vector3(16.4,0,12.8),"look":Vector3(16.8,1.4,16.4)}]
 for view in views:
  author.pose(game,view.p,view.look);game.player.lamp.show();game.prompt.hide()
  await author.settle(game);author.save(game,output,view.id)
 print("V355 RENDER COMPLETE ",JSON.stringify(SceneAudit.placement(game.world)))
