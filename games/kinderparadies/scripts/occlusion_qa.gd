extends RefCounted

# Render QA (--occlusion-qa): proves occlusion culling hides nothing visible.
# The scene is frozen, then every view is captured with culling off and on and
# the two images are compared pixel by pixel.
const EXTRA:=[Vector3(-3.5,0,8.8),Vector3(.9,0,9.6),Vector3(7.2,0,-9),Vector3(15.2,0,-4.7),Vector3(-11.3,0,-4.55),Vector3(17.6,.2,-13.5),Vector3(22.4,.03,7.1),Vector3(4,0,0),Vector3(-6.5,0,-1),Vector3(12,0,4)]

func run(game: Node3D, output: String) -> void:
 game.get_window().size=Vector2i(1280,720)
 game.settings=game.DEFAULT_SETTINGS.duplicate(true);game.settings.volume=0;game.settings.grain=false;game._apply_settings()
 game._new_shift();game.intro.skip();game._resume()
 game.player.active=false;game.player.lamp_on=true;game.player.lamp.show();game.notice_time=0;game.notice.hide();game.hud.hide()
 for i in range(30):await game.get_tree().process_frame
 game.process_mode=Node.PROCESS_MODE_PAUSABLE;game.get_tree().paused=true
 var viewport:=game.get_viewport();viewport.use_taa=false
 var points: Array=[]
 for zone in game.world.zones: points.append(game.world.zones[zone])
 points.append_array(EXTRA)
 var worst:=0.;var failures:=[];var shots:=0
 print("OCCLUSION occluders=",game.world.occluder_count)
 for p in points:
  for k in range(4):
   var yaw:=k*PI*.5
   game.player.global_position=p;game.player.rotation=Vector3(0,yaw,0);game.player.camera.position=Vector3(0,1.65,0);game.player.camera.rotation=Vector3(-.08,0,0)
   viewport.use_occlusion_culling=false
   for f in range(6):await game.get_tree().process_frame
   await RenderingServer.frame_post_draw
   var control:=viewport.get_texture().get_image()
   for f in range(6):await game.get_tree().process_frame
   await RenderingServer.frame_post_draw
   var plain:=viewport.get_texture().get_image()
   var noise:=control.compute_image_metrics(plain,false)
   viewport.use_occlusion_culling=true
   for f in range(6):await game.get_tree().process_frame
   await RenderingServer.frame_post_draw
   var culled:=viewport.get_texture().get_image()
   var metrics:=plain.compute_image_metrics(culled,false);shots+=1
   worst=maxf(worst,float(metrics.max))
   # Flickering lamps and rain keep animating while paused: only a difference
   # well beyond the off/off control counts as something culled.
   if float(metrics.root_mean_squared)>float(noise.root_mean_squared)*2.5+.6:
    var tag:="occl-%d-%d"%[points.find(p),k]
    failures.append({"tag":tag,"p":str(p),"yaw":yaw,"max":metrics.max,"rmse":metrics.root_mean_squared,"noise_max":noise.max,"noise_rmse":noise.root_mean_squared})
    plain.save_png(output.path_join(tag+"-off.png"));culled.save_png(output.path_join(tag+"-on.png"))
 print("OCCLUSION QA shots=",shots," worst_max=",worst," failures=",JSON.stringify(failures))
