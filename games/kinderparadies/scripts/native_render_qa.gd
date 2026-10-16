extends RefCounted

func run(game: Node3D) -> void:
 var output:=OS.get_environment("TEMP").path_join("NachtwacheNativeQA")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 game.settings.quality=2;game.settings.volume=0;game._apply_settings()
 await game.get_tree().create_timer(8).timeout
 await capture(game,output,"menu")
 game._new_shift()
 await game.get_tree().create_timer(6).timeout
 await capture(game,output,"main")
 var start:=Time.get_ticks_usec()
 for i in range(180): await game.get_tree().process_frame
 var fps:=180.0/((Time.get_ticks_usec()-start)/1000000.0)
 var positions: Array[Dictionary]=[
  {"name":"play","pos":Vector3(-3.5,.012,6.4),"yaw":-.72,"pitch":-.05},
  {"name":"rabbit","pos":Vector3(-4.15,.012,4.7),"yaw":-PI/2,"pitch":-.12},
  {"name":"party","pos":Vector3(7.1,.012,-5.4),"yaw":-.45,"pitch":-.1},
  {"name":"service","pos":Vector3(-7.2,.012,-6.4),"yaw":0,"pitch":0}]
 for shot in positions:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2).timeout
  await capture(game,output,shot.name)
 game.player.reset_pose();Input.action_press("forward")
 for i in range(30): await game.get_tree().physics_frame
 Input.action_release("forward")
 var walked: bool=game.player.position.z<8
 var jump:=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.pressed=true;Input.parse_input_event(jump)
 var peak:=0.0
 for i in range(55):
  await game.get_tree().physics_frame;peak=maxf(peak,game.player.position.y)
  if i==2: jump.pressed=false;Input.parse_input_event(jump)
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"fps_sample":fps,"models":game.world.native_art.model_count,"walked":walked,"jump_peak":peak,"quality":game.settings.quality,"resolution":[game.get_viewport().size.x,game.get_viewport().size.y]}
 game.settings.quality=0;game._apply_settings()
 var low_ok: bool=not game.world.environment.environment.sdfgi_enabled and not game.world.environment.environment.volumetric_fog_enabled
 game.settings.quality=2;game._apply_settings()
 report.quality_toggle=low_ok and game.world.environment.environment.sdfgi_enabled and game.world.environment.environment.ssr_enabled
 game._pause();await capture(game,output,"pause");game._settings("pause");await capture(game,output,"settings");game._resume()
 for id in ["blood_trail","bunny_ceiling","lights_red"]:
  game._build_world(id);game._resume();await game.get_tree().create_timer(3).timeout
  await capture(game,output,id)
 var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("NATIVE RENDER QA ",JSON.stringify(report))
 game._quit()

func capture(game: Node3D, output: String, name: String) -> void:
 await RenderingServer.frame_post_draw
 var image:=game.get_viewport().get_texture().get_image()
 var error:=image.save_png(output.path_join(name+".png"))
 assert(error==OK,"Native screenshot failed")
