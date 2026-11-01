extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 var views: Array[Dictionary]=[
  {"id":"01-geschenke","p":Vector3(17.2,0,-8.3),"look":Vector3(18.9,.55,-8.6)},
  {"id":"02-paketfalten","p":Vector3(17.45,0,-3.0),"look":Vector3(19.1,1.,-3.9)},
  {"id":"03-partyraum-stuehle","p":Vector3(11.9,0,-8.9),"look":Vector3(9.3,.65,-7)},
  {"id":"04-fototafel-im-flur","p":Vector3(-8.65,0,-17.7),"look":Vector3(-6.66,2.,-18.75)},
  {"id":"05-haengeschild","p":Vector3(-7.9,0,-12.7),"look":Vector3(-7.9,2.94,-14.8)},
  {"id":"06-oeffnungszeiten","p":Vector3(-8.3,0,7.4),"look":Vector3(-9.96,2.1,7.6)},
  {"id":"07-technikschilder","p":Vector3(-8.4,0,-6.9),"look":Vector3(-9.975,2.,-7.55)},
  {"id":"08-entscheidungstueren","p":Vector3(-3.5,0,-8.0),"look":Vector3(-3.5,3.2,-12.2)},
  {"id":"09-snackbar","p":Vector3(16.4,0,13.8),"look":Vector3(17.0,1.8,16.2)},
  {"id":"10-personalgang","p":Vector3(-7.9,0,-15.3),"look":Vector3(-7.9,1.8,-27)}]
 for view in views:
  author.pose(game,view.p,view.look);game.player.lamp.visible=view.get("torch",true)
  await author.settle(game);author.save(game,output,view.id)
 var report:={"layout":SceneAudit.inspect(game.world),"craft":game.world.craft.snapshot()}
 var file:=FileAccess.open(output.path_join("scene-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V350 RENDER COMPLETE ",JSON.stringify(report))
