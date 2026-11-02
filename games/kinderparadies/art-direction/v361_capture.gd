extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 var driver=load("res://scripts/hunt_validation.gd").new()
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 game._force_horse_hunt();game.player.active=false
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 author.pose(game,Vector3(-7.9,0,-25.5),Vector3(-7.9,1.7,-29.65));game.prompt.hide();game.notice.hide();game.player.lamp.show()
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 for i in range(1500):
  game.world.horse_hunt.tick(1.0/60.0,true,game.player)
  if game.world.horse_hunt.phase=="catch":break
  if i%60==0:await game.get_tree().physics_frame
 await driver.advance(game,.21)
 await author.settle(game);author.save(game,output,"01-horse-contact-closeup")
 await driver.advance(game,1.15)
 await author.settle(game);author.save(game,output,"02-horse-withdraws")
 await driver.advance(game,2.8)
 await author.settle(game);author.save(game,output,"03-pursuit-resumes")
 print("V361 RENDER COMPLETE ",JSON.stringify(game.world.horse_hunt.snapshot()))
