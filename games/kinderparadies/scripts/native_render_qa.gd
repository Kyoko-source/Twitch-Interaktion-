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
  {"name":"rabbit","pos":Vector3(-5.15,.012,4.85),"yaw":-PI/2,"pitch":-.12},
  {"name":"counter","pos":Vector3(-6.4,.012,5.8),"yaw":PI/2,"pitch":-.1},
  {"name":"hall","pos":Vector3(-1,.012,12),"yaw":-.95,"pitch":.09},
  {"name":"crocodile","pos":Vector3(3.5,.012,13.7),"yaw":-1.2,"pitch":.04},
  {"name":"party","pos":Vector3(7.2,.012,-5.4),"yaw":-1.05,"pitch":-.05},
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
 game._build_world("bunny_lunge");game._resume()
 await game.get_tree().create_timer(1.4).timeout
 game.player.position=Vector3(-5.7,0,4.85);game.player.rotation.y=-PI/2;game.player.camera.rotation.x=-.08
 var timeout:=0.0
 while not game.world.encounters.triggered and timeout<3:
  await game.get_tree().process_frame;timeout+=game.get_process_delta_time()
 report.bunny_triggered=game.world.encounters.triggered
 game._pause();var scare_time: float=game.world.encounters.attack_time
 await game.get_tree().create_timer(.35).timeout
 report.scare_pause=game.world.encounters.attack_time==scare_time
 game._resume();await game.get_tree().create_timer(.26).timeout
 await capture(game,output,"bunny_jump")
 await game.get_tree().create_timer(1.5).timeout
 report.bunny_finished=game.world.encounters.finished
 game._build_world("croc_breathes");game._resume();game.player.position=Vector3(3.5,0,13.7);game.player.rotation.y=-1.2
 await game.get_tree().create_timer(1.1).timeout;await capture(game,output,"croc_breathes")
 var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("NATIVE RENDER QA ",JSON.stringify(report))
 game._quit()

func capture(game: Node3D, output: String, name: String) -> void:
 await RenderingServer.frame_post_draw
 var image:=game.get_viewport().get_texture().get_image()
 var error:=image.save_png(output.path_join(name+".png"))
 assert(error==OK,"Native screenshot failed")
