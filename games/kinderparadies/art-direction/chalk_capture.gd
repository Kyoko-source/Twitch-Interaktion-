extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 game.notice.hide();game.notice_time=0;game.get_window().size=Vector2i(1600,900)
 var board: ChalkBoard=game.world.chalk
 for path in [PackedVector2Array([Vector2(150,150),Vector2(177,127),Vector2(177,230)]),PackedVector2Array([Vector2(225,135),Vector2(263,127),Vector2(281,143),Vector2(269,169),Vector2(244,177),Vector2(270,183),Vector2(285,206),Vector2(267,229),Vector2(229,231)])]:
  board.begin_stroke(path[0])
  for point in path:board.extend_stroke(point)
  board.finish_stroke()
 author.pose(game,Vector3(17.25,.20,-15),Vector3(19.4,1.73,-15))
 await author.settle(game);author.save(game,output,"01-chalk-board")
 game.world.chalk.open(game)
 await author.settle(game);author.save(game,output,"02-chalk-ui")
 game._close_chalk();game.player.active=false
 for view in [
  {"id":"03-cinema-photo","p":Vector3(-2.6,0,-31.8),"look":Vector3(-1.3,2.,-34.39)},
  {"id":"04-cinema-horse","p":Vector3(-4.7,0,-30.5),"look":Vector3(-1.3,2.6,-33.6)}]:
  author.pose(game,view.p,view.look);game.prompt.hide()
  await author.settle(game);author.save(game,output,view.id)
