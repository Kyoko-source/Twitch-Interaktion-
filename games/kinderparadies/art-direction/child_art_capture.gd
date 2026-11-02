extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 game.notice.hide();game.notice_time=0;game.get_window().size=Vector2i(1600,900)
 for view in [
  {"id":"01-hall-drawings","p":Vector3(-.45,0,-9.7),"look":Vector3(0,.75,-12.03)},
  {"id":"02-party-drawings","p":Vector3(8.9,0,-6.2),"look":Vector3(6.943,.75,-6.2)},
  {"id":"03-corridor-drawings","p":Vector3(-7.95,0,-22.1),"look":Vector3(-6.575,.76,-22.15)},
  {"id":"04-reception-drawing","p":Vector3(-8.0,0,4.4),"look":Vector3(-10.04,.78,4.4)}]:
  author.pose(game,view.p,view.look);game.prompt.hide()
  await author.settle(game);author.save(game,output,view.id)
