extends RefCounted

func run(game: Node3D,output: String) -> void:
 var author=load("res://art-direction/itch_capture.gd").new()
 game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
 game.notice.hide();game.notice_time=0;game.get_window().size=Vector2i(1600,900)
 var compat: bool="--wall-gl" in OS.get_cmdline_user_args()
 if compat:
  for pair in [["albedo_map","albedo"],["normal_map","normal"],["rough_map","roughness"]]:game.world.wall_decay.finish.set_shader_parameter(pair[0],load(WallDecay.ROOT+"web/"+pair[1]+".jpg"))
 for view in [
  {"id":"01-maintenance-plaster","p":Vector3(-13.95,0,-4.45),"look":Vector3(-16.35,1.3,-4.35)},
  {"id":"02-maintenance-masonry","p":Vector3(-14.2,0,-3.7),"look":Vector3(-12.8,.85,-6.85)},
  {"id":"03-corridor-left","p":Vector3(-7.9,0,-21.5),"look":Vector3(-9.31,2.1,-21.7)},
  {"id":"04-corridor-right","p":Vector3(-8.05,0,-24.1),"look":Vector3(-6.49,2.4,-24.3)},
  {"id":"05-cinema-wall","p":Vector3(-4.8,0,-32.4),"look":Vector3(-4.4,3.05,-34.45)},
  {"id":"06-hall-wall","p":Vector3(-1.0,0,-9.0),"look":Vector3(1.3,2.9,-12.05)},
  {"id":"07-party-wall","p":Vector3(9,0,-2.7),"look":Vector3(6.9,2.55,-2.7)}]:
  if compat and view.id!="03-corridor-left":continue
  author.pose(game,view.p,view.look);game.prompt.hide()
  if view.id=="01-maintenance-plaster":
   for wall in game.world.wall_decay.walls:wall.material_overlay=null
   await author.settle(game);author.save(game,output,"00-maintenance-before")
   for wall in game.world.wall_decay.walls:wall.material_overlay=game.world.wall_decay.finish
  await author.settle(game);author.save(game,output,view.id)
