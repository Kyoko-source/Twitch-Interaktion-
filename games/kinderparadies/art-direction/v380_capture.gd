extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 game.notice.hide();game.notice_time=0;game.get_window().size=Vector2i(1600,900)
 var w: PlayWorld=game.world
 for batch in w.find_children("*","MultiMeshInstance3D",true,false):
  if not batch.is_visible_in_tree():continue
  for i in range(batch.multimesh.instance_count):
   var pose: Transform3D=batch.global_transform*batch.multimesh.get_instance_transform(i)
   var bounds: AABB=pose*batch.multimesh.mesh.get_aabb()
   if bounds.intersects(AABB(Vector3(15.8,4.4,2.65),Vector3(.5,1,1))):print("MOUTH INSTANCE ",batch.get_path()," ",i," ",bounds," ",pose)
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.visible:continue
  var aabb: AABB=mesh.global_transform*mesh.get_aabb()
  if aabb.intersects(AABB(Vector3(15.35,4.35,2.5),Vector3(1.4,1.25,1.1))):
   print("MOUTH MESH ",mesh.get_path()," ",aabb)
 for view in [
  {"id":"01-west-entry","p":Vector3(-3.0,.38,-1.12),"look":Vector3(2,1.1,1.7)},
  {"id":"02-upper-pool-view","p":Vector3(-.5,2.977,1.5),"look":Vector3(-2,2,7)},
  {"id":"03-upper-slide","p":Vector3(1,2.977,-.7),"look":Vector3(2.4,2.9,1.1)},
  {"id":"04-tube-mouth","p":Vector3(16.05,4.15,3.8),"look":Vector3(16.05,4.9,1.3)},
  {"id":"05-cabin","p":Vector3(-4.5,0,1),"look":Vector3(2.5,4.8,-4.6)},
  {"id":"06-music-box","p":Vector3(17.0,0,-3.4),"look":Vector3(19.07,1.2,-2.63)},
  {"id":"07-bridge-opening","p":Vector3(5.8,2.80,3.6),"look":Vector3(-1.2,2.8,3.6)},
  {"id":"08-carved-timber","p":Vector3(2.85,4.15,-4.75),"look":Vector3(2.85,4.5,-6.16)},
  {"id":"09-integrated-lookout","p":Vector3(3.0,0,-10.1),"look":Vector3(3,4.8,-4.5)}]:
  author.pose(game,view.p,view.look)
  if view.id=="04-tube-mouth":game.player.camera.position.y=.8
  game.player.lamp.show();game.prompt.hide();await author.settle(game);author.save(game,output,view.id)
 game.settings.language="en";game._apply_settings();game._settings("menu");NightMenus.settings(game,"Sprache")
 await author.settle(game);author.save(game,output,"10-english-settings")
 game.archive.collected.assign(ArchiveState.ORDER);game.phase="inventory";ArchiveUI.inventory(game,"missing")
 await author.settle(game);author.save(game,output,"11-english-newspaper")
 game._resume();author.pose(game,Vector3(-8.17,.45,5.5),Vector3(-9.97,2.1,5.5));game.player.active=false;game.player.set_physics_process(false)
 game.captions.show_line(game.captions.read_sign(game,game.player.camera.get_viewport().get_visible_rect().size*.5),"sign")
 await RenderingServer.frame_post_draw;author.save(game,output,"12-english-sign")
 print("V380 RENDER COMPLETE")
