extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false);game.notice.hide();game.notice_time=0
 game.get_window().content_scale_size=Vector2i(1920,1080);game.get_window().size=Vector2i(1920,1080)
 for view in [
  {"id":"01-clown-face","p":Vector3(-13.55,0,-31.1),"look":Vector3(-14.4,1.88,-31.25)},
  {"id":"02-clown-body","p":Vector3(-11.9,0,-29.6),"look":Vector3(-14.4,1.3,-31.25)},
  {"id":"03-cinema","p":Vector3(-5.35,0,-29.5),"look":Vector3(2.8,1.5,-30.4)},
  {"id":"04-seat-detail","p":Vector3(-.5,0,-30.0),"look":Vector3(-2.8,.70,-31.9)},
  {"id":"05-arcade","p":Vector3(8.0,0,13.8),"look":Vector3(8.4,1.65,16.4)},
  {"id":"06-croc-clearance","p":Vector3(17.8,0,14.2),"look":Vector3(12.4,1.9,10.4)},
  {"id":"07-hall","p":Vector3(-5.0,0,15.0),"look":Vector3(9.0,3.2,7.5)},
  {"id":"08-extinguisher","p":Vector3(-8.9,0,-7.2),"look":Vector3(-9.89,1.16,-7.5)}]:
  author.pose(game,view.p,view.look);await author.settle(game);author.save(game,output,view.id)
 var bounds:=AABB();var first:=true
 for mesh in game.world.playground.croc_visual.find_children("*","MeshInstance3D",true,false):
  var b: AABB=mesh.global_transform*mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
 var report:={"layout":SceneAudit.inspect(game.world),"details":game.world.venue.count,"croc_bounds":str(bounds)}
 var file:=FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V310 RENDER COMPLETE ",JSON.stringify(report))
