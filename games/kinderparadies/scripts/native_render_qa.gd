extends RefCounted

func run(game: Node3D) -> void:
 var output:=OS.get_environment("TEMP").path_join("NachtwacheNativeQA")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 game.settings.quality=2;game.settings.volume=0;game._apply_settings()
 if "--v180-qa" in OS.get_cmdline_user_args():
  await v180_views(game,output);game._quit();return
 if "--annex-qa" in OS.get_cmdline_user_args():
  await annex_views(game,output);game._quit();return
 if "--tubes-qa" in OS.get_cmdline_user_args():
  await tube_views(game,output);game._quit();return
 if "--geometry-qa" in OS.get_cmdline_user_args():
  await geometry_views(game,output);game._quit();return
 if "--polish-qa" in OS.get_cmdline_user_args():
  await polish_views(game,output);game._quit();return
 if "--croc-qa" in OS.get_cmdline_user_args():
  await croc_views(game,output);game._quit();return
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

func annex_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"annex-corridor","pos":Vector3(-7.9,0,-13.6),"yaw":0,"pitch":.03},
  {"name":"annex-kitchen","pos":Vector3(-10.8,0,-16.7),"yaw":1.02,"pitch":-.01},
  {"name":"annex-clown","pos":Vector3(-12.2,0,-18.0),"yaw":1.1,"pitch":.09},
  {"name":"annex-pot","pos":Vector3(-12.2,0,-18.6),"yaw":1.03,"pitch":-.36},
  {"name":"annex-cinema","pos":Vector3(-4.6,0,-17.65),"yaw":-PI/2,"pitch":.1},
  {"name":"crocodile-v3","pos":Vector3(4.8,0,13.8),"yaw":-1.25,"pitch":.13},
  {"name":"crocodile-profile","pos":Vector3(8.3,0,7.4),"yaw":-2.35,"pitch":.11}]
 for shot in shots:
  game.player.position=shot.pos;game.player.velocity=Vector3.ZERO;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2.5).timeout;await capture(game,output,shot.name)
 game._build_world("clown_lunge");game._resume();game.player.position=Vector3(-12.2,0,-18);game.player.rotation.y=1.1;game.player.camera.rotation.x=.09
 var wait:=0.0
 while not game.world.encounters.triggered and wait<4:
  await game.get_tree().process_frame;wait+=game.get_process_delta_time()
 var triggered: bool=game.world.encounters.triggered
 game._pause();var time: float=game.world.encounters.attack_time
 await game.get_tree().create_timer(.25).timeout
 var frozen: bool=time==game.world.encounters.attack_time
 game._resume();await game.get_tree().create_timer(.32).timeout;await capture(game,output,"annex-clown-lunge")
 await game.get_tree().create_timer(1.6).timeout
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"clown_triggered":triggered,"pause_frozen":frozen,"clown_finished":game.world.encounters.finished,"clown_settled":game.world.annex.settled,"clown_position":str(game.world.annex.clown.root.position),"audit":SceneAudit.inspect(game.world)}
 game._build_world("tube_watcher");game._resume();game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);game.player.rotation.y=0;game.player.camera.rotation.x=1.3;Input.action_press("crouch")
 await game.get_tree().create_timer(2).timeout;await capture(game,output,"watcher-stained");Input.action_release("crouch")
 var file:=FileAccess.open(output.path_join("annex-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("ANNEX RENDER QA ",JSON.stringify(report))

func v180_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"reception-pc","pos":Vector3(-9.65,0,5.2),"yaw":-1.87,"pitch":-.32},
  {"name":"torch","pos":Vector3(-6.2,0,7.5),"yaw":-.55,"pitch":-.22},
  {"name":"kitchen","pos":Vector3(-10.8,0,-17),"yaw":1.0,"pitch":.04},
  {"name":"clown-front","pos":Vector3(-12.4,0,-19.25),"yaw":PI/2,"pitch":.1},
  {"name":"clown-profile","pos":Vector3(-14.4,0,-17.5),"yaw":0,"pitch":.14}]
 for shot in shots:
  game.player.position=shot.pos;game.player.velocity=Vector3.ZERO;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2.3).timeout;await capture(game,output,shot.name)
 game.player.torch_body.trigger()
 await game.get_tree().create_timer(.03).timeout
 var flickered: bool=game.player.lamp.light_energy<4
 game._pause();var torch_clock: float=game.player.torch_body.clock
 await game.get_tree().create_timer(.3).timeout
 var frozen: bool=torch_clock==game.player.torch_body.clock
 game._resume();await game.get_tree().create_timer(.7).timeout
 var recovered: bool=is_equal_approx(game.player.lamp.light_energy,4.2)
 game._build_world("none");game._resume();game.state.start(1800)
 game._decide(true)
 var limit:=0.0
 while game.phase=="failure" and game.door_failure.clock<.35 and limit<4:
  await game.get_tree().process_frame;limit+=game.get_process_delta_time()
 await capture(game,output,"wrong-door-scare")
 while game.phase!="play" and limit<12:
  await game.get_tree().process_frame;limit+=game.get_process_delta_time()
 var automatic_wrong: bool=game.phase=="play" and game.state.streak==0 and game.state.errors==1 and game.door_failure.shown==1
 game._decide(game.state.current!="none");limit=0
 while game.phase!="play" and limit<12:
  await game.get_tree().process_frame;limit+=game.get_process_delta_time()
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"flickered":flickered,"flicker_pause":frozen,"flicker_recovered":recovered,"automatic_wrong":automatic_wrong,"automatic_correct":game.phase=="play" and game.state.streak==1,"failure_count":game.door_failure.shown,"ambience":game.world.soundscape.snapshot(),"audit":SceneAudit.inspect(game.world)}
 var file:=FileAccess.open(output.path_join("v180-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V180 RENDER QA ",JSON.stringify(report))

func tube_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"tubes-exterior","pos":Vector3(-6.8,0,9.8),"yaw":-2.45,"pitch":-.03},
  {"name":"tube-entry","pos":Vector3(-5.5,0,10.9),"yaw":PI,"pitch":-.45},
  {"name":"tube-interior","pos":CrawlTubes.route(6)+Vector3(0,-.72,0),"yaw":-PI/2,"pitch":.05},
  {"name":"tube-window-normal","pos":CrawlTubes.route(7.4)+Vector3(0,-.72,0),"yaw":0.0,"pitch":1.3}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  Input.action_press("crouch") if shot.name.begins_with("tube-i") or shot.name.begins_with("tube-window") else Input.action_release("crouch")
  await game.get_tree().create_timer(2).timeout;await capture(game,output,shot.name)
 game._build_world("tube_watcher");game._resume();game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);game.player.rotation.y=0;game.player.camera.rotation.x=1.3;Input.action_press("crouch")
 await game.get_tree().create_timer(2).timeout;await capture(game,output,"tube-window-watcher")
 Input.action_release("crouch")
 print("TUBE RENDER QA ",JSON.stringify({"watcher":game.world.tubes.watcher.visible,"ambience":game.world.soundscape.snapshot()}))

func polish_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"reception","pos":Vector3(-6.4,0,6.7),"yaw":1.2,"pitch":.03},
  {"name":"hours","pos":Vector3(-8.1,0,7.4),"yaw":PI/2,"pitch":.14},
  {"name":"party","pos":Vector3(11.8,0,-3.8),"yaw":.65,"pitch":-.12},
  {"name":"gallery","pos":Vector3(14,0,-9.3),"yaw":0,"pitch":.22},
  {"name":"pit","pos":Vector3(0,0,9.6),"yaw":0,"pitch":-.46},
  {"name":"tower","pos":Vector3(6.1,0,4.7),"yaw":-PI/2,"pitch":.3},
  {"name":"fog-normal","pos":Vector3(-1,0,12),"yaw":-.95,"pitch":.09}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2).timeout;await capture(game,output,shot.name)
 var report:=SceneAudit.inspect(game.world)
 report.renderer=RenderingServer.get_current_rendering_method();report.normal_fog=game.world.environment.environment.fog_density
 report.native_fog=game.world.environment.environment.volumetric_fog_density
 var start:=Time.get_ticks_usec()
 for frame in range(120): await game.get_tree().process_frame
 report.fps_sample=120.0/((Time.get_ticks_usec()-start)/1000000.0)
 game._build_world("heavy_mist");game._resume();game.player.position=Vector3(-1,0,12);game.player.rotation.y=-.95;game.player.camera.rotation.x=.09
 await game.get_tree().create_timer(2).timeout;await capture(game,output,"fog-red")
 var file:=FileAccess.open(output.path_join("polish-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("POLISH RENDER QA ",JSON.stringify(report))

func geometry_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"door-front","pos":Vector3(4.87,0,-5.6),"yaw":-PI/2,"pitch":.16},
  {"name":"door-corner","pos":Vector3(5.4,0,-3.1),"yaw":-.49,"pitch":.1},
  {"name":"slide","pos":Vector3(5.9,0,9.7),"yaw":.57,"pitch":.08},
  {"name":"slide-profile","pos":Vector3(5.8,0,4.3),"yaw":PI/2,"pitch":.16},
  {"name":"upper-play","pos":Vector3(-.535,2.99,2.9),"yaw":0,"pitch":-.06},
  {"name":"clown","pos":Vector3(-6.5,0,12.5),"yaw":PI/2,"pitch":.28},
  {"name":"moon","pos":Vector3(-7,0,-.1),"yaw":PI/2,"pitch":.45},
  {"name":"party-mural","pos":Vector3(16.1,0,-7.3),"yaw":-PI/2,"pitch":.22},
  {"name":"hall","pos":Vector3(-1,0,12),"yaw":-.95,"pitch":.09}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2).timeout;await capture(game,output,shot.name)
 var report:=SceneAudit.inspect(game.world);report.renderer=RenderingServer.get_current_rendering_method()
 var file:=FileAccess.open(output.path_join("geometry-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("GEOMETRY RENDER QA ",JSON.stringify(report))

func croc_views(game: Node3D, output: String) -> void:
 game._new_shift()
 var shots: Array[Dictionary]=[
  {"name":"croc-front","pos":Vector3(3.9,0,11.3),"yaw":-PI/2,"pitch":.12},
  {"name":"croc-three-quarter","pos":Vector3(3.5,0,13.7),"yaw":-1.2,"pitch":.12},
  {"name":"croc-close","pos":Vector3(5.7,0,13.1),"yaw":-1.65,"pitch":.6},
  {"name":"croc-side","pos":Vector3(12.4,0,16),"yaw":0,"pitch":.12}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(3).timeout;await capture(game,output,shot.name)
 game._build_world("croc_snap");game._resume()
 await game.get_tree().create_timer(1.2).timeout
 game.player.position=Vector3(6.8,0,11.3);game.player.rotation.y=-PI/2;game.player.camera.rotation.x=.12
 for frame in range(90):
  await game.get_tree().process_frame
  if game.world.encounters.triggered: break
 game._pause();var angle: float=game.world.playground.croc_jaw.rotation.x
 await game.get_tree().create_timer(.25).timeout
 var paused: bool=game.world.playground.croc_jaw.rotation.x==angle
 game._resume();await game.get_tree().create_timer(.24).timeout;await capture(game,output,"croc-snap")
 await game.get_tree().create_timer(.8).timeout
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"shared_mesh":is_instance_valid(game.world.playground.croc_visual),"jaw_triggered":game.world.encounters.triggered,"jaw_finished":game.world.encounters.finished,"jaw_pause":paused,"jaw_angle":game.world.playground.croc_jaw.rotation.x}
 var file:=FileAccess.open(output.path_join("croc-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("CROCODILE QA ",JSON.stringify(report))
