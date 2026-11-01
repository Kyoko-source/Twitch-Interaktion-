extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-kinoeingang","p":Vector3(-7.9,0,-28.8),"look":Vector3(-6.1,1.7,-29.65)},
  {"id":"02-kartenkontrolle","p":Vector3(-4.95,0,-31.65),"look":Vector3(-6.08,1.55,-33.1)},
  {"id":"03-kinobuehne","p":Vector3(-4.7,0,-29.65),"look":Vector3(3.34,1.75,-29.7),"torch":false},
  {"id":"04-musterteppich","p":Vector3(-5.2,0,-29.65),"look":Vector3(-3.3,.02,-29.65)},
  {"id":"05-kueche","p":Vector3(-11.5,0,-29.7),"look":Vector3(-16.5,1.1,-30.2)},
  {"id":"06-kuechengriffe","p":Vector3(-14.8,0,-29.0),"look":Vector3(-16.1,.59,-29.6)},
  {"id":"07-gummiboden","p":Vector3(-3.8,0,-4.9),"look":Vector3(-1.65,.05,-3.6)},
  {"id":"08-geburtstagslicht","p":Vector3(7.6,0,-10.1),"look":Vector3(10.2,1.,-7),"torch":false},
  {"id":"09-fundbaender","p":Vector3(-8.6,0,15.65),"look":Vector3(-9.85,1.82,16.2)},
  {"id":"10-hauptsaal","p":Vector3(-6.7,0,9),"look":Vector3(4.8,2.9,3.6)}]
 for view in views:
  author.pose(game,view.p,view.look);game.player.lamp.visible=view.get("torch",true)
  await author.settle(game);author.save(game,output,view.id)
 var report:={"layout":SceneAudit.inspect(game.world),"craft":game.world.craft.snapshot()}
 var file:=FileAccess.open(output.path_join("scene-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V340 RENDER COMPLETE ",JSON.stringify(report))
