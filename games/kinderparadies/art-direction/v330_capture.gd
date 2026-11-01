extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-snackbar","p":Vector3(15.8,0,13.6),"look":Vector3(17.4,1.6,16.25)},
  {"id":"02-regale","p":Vector3(4.7,0,-8.1),"look":Vector3(4.4,1.5,-11.6)},
  {"id":"03-kinosteuerung","p":Vector3(-4.9,0,-27.83),"look":Vector3(-6.24,1.65,-27.83)},
  {"id":"04-verbindungsgang","p":Vector3(-7.9,0,-13.6),"look":Vector3(-7.9,1.45,-30.5)},
  {"id":"05-flur-zurueck","p":Vector3(-7.9,0,-27.0),"look":Vector3(-7.9,1.5,-15)},
  {"id":"06-haupteingang","p":Vector3(-9.1,0,9.4),"look":Vector3(-15.8,1.5,9.4)},
  {"id":"07-garderobe","p":Vector3(-12.4,0,9.6),"look":Vector3(-13,1.35,8.3)},
  {"id":"08-glastuer","p":Vector3(-14.1,0,9.4),"look":Vector3(-24,1.5,9.4)},
  {"id":"09-hauptsaal","p":Vector3(-6.7,0,9),"look":Vector3(4.8,2.9,3.6)}]
 for view in views:
  author.pose(game,view.p,view.look);await author.settle(game);author.save(game,output,view.id)
 game.world.backstage.exit_open=true
 author.pose(game,Vector3(-16.3,0,9.4),Vector3(-28,1.65,8.6));await author.settle(game);author.save(game,output,"10-parkplatzausgang")
 game._escape_happyland();game.end_credits.clock=3.1;await author.settle(game);author.save(game,output,"11-geheimes-ende")
 var report:={"layout":SceneAudit.inspect(game.world),"arrival":game.world.arrival_design.snapshot(),"ending":game.end_credits.snapshot()}
 var file:=FileAccess.open(output.path_join("scene-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V330 RENDER COMPLETE ",JSON.stringify(report))
