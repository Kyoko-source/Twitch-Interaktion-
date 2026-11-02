extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var horse: CeilingHorse=game.world.room_horror.creature;horse.debug_hold=true
 var views: Array[Dictionary]=[
  {"id":"01-pferdemaske","p":Vector3(-2.6,0,-30.25),"look":Vector3(-1.5,2.25,-32.15),"progress":0.0},
  {"id":"02-an-der-decke","p":Vector3(-4.9,0,-27.5),"look":Vector3(-3.4,2.9,-30.9),"progress":.58},
  {"id":"03-blick-in-den-flur","p":Vector3(-7.9,0,-25.5),"look":Vector3(-7.1,2,-29.65),"progress":1.0},
  {"id":"04-flurdecke","p":Vector3(-7.9,0,-14),"look":Vector3(-7.9,3.2,-28),"progress":0.0},
  {"id":"05-ohne-kuechendienst","p":Vector3(-12.8,0,-32.1),"look":Vector3(-10.7,2,-34.3),"progress":0.0},
  {"id":"06-freie-stirnwand","p":Vector3(-7.9,0,-31.8),"look":Vector3(-7.9,2.1,-34.4),"progress":0.0}]
 for view in views:
  horse.pose(view.progress);author.pose(game,view.p,view.look);game.player.lamp.show();game.prompt.hide()
  await author.settle(game);author.save(game,output,view.id)
 print("V356 RENDER COMPLETE ",JSON.stringify(horse.snapshot())," ",horse.head_bounds())
