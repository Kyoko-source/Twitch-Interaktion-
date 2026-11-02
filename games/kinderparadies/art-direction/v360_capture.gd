extends RefCounted

func shot(game: Node3D,author: RefCounted,output: String,id: String,p: Vector3,target: Vector3) -> void:
 author.pose(game,p,target);game.player.lamp.show();game.prompt.hide();game.notice.hide()
 await author.settle(game);author.save(game,output,id)

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 var driver=load("res://scripts/hunt_validation.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.set_process(false)
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 game.player.set_physics_process(false)
 await shot(game,author,output,"01-clown-blond-front",Vector3(-13.65,.2,-31.25),Vector3(-14.4,1.94,-31.25))
 await shot(game,author,output,"02-clown-blond-in-room",Vector3(-11.9,0,-29.6),Vector3(-14.4,1.65,-31.25))
 await shot(game,author,output,"03-horse-static",Vector3(-2.6,0,-30.25),Vector3(-1.5,2.25,-32.15))
 game._force_horse_hunt();game.player.active=false
 await shot(game,author,output,"04-red-door-clue",Vector3(-2.15,0,-10.7),Vector3(-2.15,1.94,-12.08))
 game.player.position=Vector3(-7.9,0,-25.5);await game.get_tree().physics_frame
 await driver.advance(game,11)
 await shot(game,author,output,"05-horse-in-corridor",game.player.position,game.world.horse_hunt.head)
 game.player.set_physics_process(true)
 for p in [Vector3(-7.9,0,-10.7),Vector3(5.7,0,-10.7),Vector3(5.7,0,-8.7),Vector3(8.1,0,-8.7),Vector3(8.1,0,-10.05),Vector3(9.6,0,-10.05)]:
  assert(await driver.walk(game,p),"Capture walk blocked")
 await driver.advance(game,4);game.player.set_physics_process(false)
 await shot(game,author,output,"06-followed-into-party",game.player.position,game.world.horse_hunt.head)
 game.player.set_physics_process(true)
 for p in [Vector3(8.1,0,-10.05),Vector3(8.1,0,-8.7),Vector3(5.7,0,-8.7),Vector3(5.7,0,-10.7),Vector3(-7.9,0,-10.7),Vector3(-7.9,0,-29.65),Vector3(-12.3,0,-29.65)]:
  assert(await driver.walk(game,p),"Capture kitchen walk blocked")
 for i in range(1200):
  game.world.horse_hunt.tick(1.0/60.0,true,game.player)
  if game.world.horse_hunt.phase=="clown":break
  if i%60==0:await game.get_tree().physics_frame
 await driver.advance(game,.78);game.player.set_physics_process(false)
 await shot(game,author,output,"07-clown-attacks-horse",Vector3(-12.2,0,-27.9),Vector3(-11.8,2.0,-29.65))
 await driver.advance(game,4)
 await shot(game,author,output,"08-neck-retracts",Vector3(-7.9,0,-25.5),game.world.horse_hunt.head)
 await driver.advance(game,80)
 await shot(game,author,output,"09-red-door-released",Vector3(-2.15,0,-10.7),Vector3(-2.15,1.94,-12.08))
 print("V360 RENDER COMPLETE ",JSON.stringify(game.world.horse_hunt.snapshot()))
