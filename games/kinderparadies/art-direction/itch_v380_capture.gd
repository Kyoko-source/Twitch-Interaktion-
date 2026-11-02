extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game.get_window().size=Vector2i(1920,1080)
 game.settings=game.DEFAULT_SETTINGS.duplicate(true);game.settings.volume=0;game._apply_settings()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 Input.mouse_mode=Input.MOUSE_MODE_HIDDEN;game.notice_time=0;game.notice.hide()
 for view in [
  {"id":"01-Empfang","p":Vector3(-3.1,0,10.5),"look":Vector3(-8.5,1.7,5.5)},
  {"id":"02-Spieleparadies","p":Vector3(-7.5,0,9.5),"look":Vector3(6,2.5,3)},
  {"id":"03-Krokodil","p":Vector3(6.4,0,10),"look":Vector3(12.1,1.3,11.6)},
  {"id":"04-Party-Raum","p":Vector3(7.3,0,-9),"look":Vector3(13,1.8,-4.3)},
  {"id":"05-Maskottchen","p":Vector3(15.2,0,-4.7),"look":Vector3(17.9,2.25,.38)},
  {"id":"06-Kueche","p":Vector3(-10.6,0,-17.4)+ServiceAnnex.OFFSET,"look":Vector3(-14.6,1.5,-19.8)+ServiceAnnex.OFFSET},
  {"id":"07-Kino","p":Vector3(-5.5,0,-17.65)+ServiceAnnex.OFFSET,"look":Vector3(2.6,1.7,-17.65)+ServiceAnnex.OFFSET},
  {"id":"08-Erinnerungswand","p":Vector3(-8.2,0,-16.6),"look":Vector3(-6.75,2.05,-18.7)},
  {"id":"09-Durchsichtige-Roehre","p":Vector3(9.9,4.15,-2.1),"look":Vector3(11.7,4.9,-.05)},
  {"id":"10-Wartungsraum","p":Vector3(-11.3,0,-4.55),"look":Vector3(-15.8,1.6,-5.6)},
  {"id":"11-Aussichtskasten","p":Vector3(3,4.15,-4.4),"look":Vector3(2.85,4.55,-6.16)},
  {"id":"12-Zwei-Tueren","p":Vector3(-3.2,0,-8.4),"look":Vector3(-3.2,1.8,-12.2)}]:
  if "--recapture-hall" in OS.get_cmdline_user_args() and not view.id.begins_with("01-") and not view.id.begins_with("02-"):continue
  author.pose(game,view.p,view.look)
  if view.id=="09-Durchsichtige-Roehre":game.player.camera.position.y=.8
  game.player.lamp.show();game.prompt.hide();game.captions.panel.hide()
  await author.settle(game);author.save(game,output,view.id)
 print("ITCH V380 SCREENSHOTS COMPLETE ",output)
