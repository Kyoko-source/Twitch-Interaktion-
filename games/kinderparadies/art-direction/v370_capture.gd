extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 game.notice.hide();game.notice_time=0;game.get_window().size=Vector2i(1600,900)
 for view in [
  {"id":"01-geruest-aussichtsturm","p":Vector3(-5.5,0,4.0),"look":Vector3(3.0,4.0,-2.2)},
  {"id":"02-roehre-partyraum","p":Vector3(8.3,0,-8.8),"look":Vector3(12,4.6,-.9)},
  {"id":"03-aussichtskasten-namen","p":Vector3(2.6,4.15,-3.95),"look":Vector3(2.6,4.6,-5.95)},
  {"id":"04-durchsichtige-roehre","p":Vector3(9.9,4.15,-2.1),"look":Vector3(13,4.85,-3.9)},
  {"id":"05-rueckweg-ostturm","p":Vector3(15.6,4.15,4.0),"look":Vector3(16.05,4.87,1.6)},
  {"id":"06-sauberer-rutscheneinstieg","p":Vector3(1.0,2.977,-.7),"look":Vector3(2.4,2.9,1.1)}]:
  author.pose(game,view.p,view.look)
  if view.id=="04-durchsichtige-roehre":game.player.camera.position.y=.8
  game.player.lamp.show();game.prompt.hide();await author.settle(game);author.save(game,output,view.id)
 print("V370 RENDER COMPLETE")
