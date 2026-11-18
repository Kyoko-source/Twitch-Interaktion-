extends RefCounted

# Frame-time benchmark through the real playable scene (render QA: --perf-qa).
# Highest quality, no vsync, uncapped; the guard stands still while every
# system keeps ticking as in play. Reports median / p95 per view so changes to
# the renderer or the scripts can be compared run against run.
const VIEWS:=[
 {"id":"hauptsaal","p":Vector3(-3.5,0,8.8),"look":Vector3(4,2.5,0)},
 {"id":"empfang","p":Vector3(-7.0,0,8.65),"look":Vector3(-8.2,1.03,7.3)},
 {"id":"baellebad","p":Vector3(.9,0,9.6),"look":Vector3(2.8,1,4.5)},
 {"id":"partyraum","p":Vector3(7.2,0,-9),"look":Vector3(13,1.8,-4.3)},
 {"id":"stoffhase","p":Vector3(15.2,0,-4.7),"look":Vector3(17.9,2.25,.38)},
 {"id":"wartung","p":Vector3(-11.3,0,-4.55),"look":Vector3(-15.8,1.6,-5.6)},
 {"id":"kostuem","p":Vector3(17.6,.2,-13.5),"look":Vector3(13.2,1.7,-16.1)},
 {"id":"kueche","p":Vector3(-10.6,0,-17.4),"look":Vector3(-14.6,1.5,-19.8),"annex":true},
 {"id":"kino","p":Vector3(-5.5,0,-17.65),"look":Vector3(2.6,1.7,-17.65),"annex":true},
 {"id":"wc","p":Vector3(22.4,.03,7.1),"look":Vector3(24.,1.2,7.15)}]
const WARMUP:=40
const SAMPLES:=150

static func _stat(values: Array) -> Dictionary:
 var sorted:=values.duplicate();sorted.sort()
 return {"median":snappedf(sorted[sorted.size()/2],.01),"p95":snappedf(sorted[int(sorted.size()*.95)],.01)}

func run(game: Node3D, output: String) -> void:
 var size:=Vector2i(1920,1080)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--perf-size="): var parts:=arg.trim_prefix("--perf-size=").split("x");size=Vector2i(int(parts[0]),int(parts[1]))
 var quality:=2
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--perf-quality="): quality=int(arg.trim_prefix("--perf-quality="))
 game.get_window().mode=Window.MODE_WINDOWED;game.get_window().size=size
 game.settings=game.DEFAULT_SETTINGS.duplicate(true);game.settings.volume=0;game.settings.vsync=false;game.settings.fps=0;game.settings.quality=quality
 game._apply_settings();game._new_shift();game.intro.skip();game._resume()
 game.player.active=false;game.player.lamp_on=true;game.player.lamp.show();game.notice_time=0;game.notice.hide()
 for i in range(30):await game.get_tree().process_frame
 var rid:=game.get_viewport().get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
 var report:={"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"api":RenderingServer.get_video_adapter_api_version(),"renderer":RenderingServer.get_current_rendering_method(),"cpu":OS.get_processor_name(),"cores":OS.get_processor_count(),"size":[size.x,size.y],"quality":quality,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"views":{}}
 var all_frames: Array=[]
 for view in VIEWS:
  var p: Vector3=view.p;var look: Vector3=view.look
  if view.get("annex",false): p+=ServiceAnnex.OFFSET;look+=ServiceAnnex.OFFSET
  game.player.position=p;game.player.velocity=Vector3.ZERO;game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(look)
  for i in range(WARMUP):await game.get_tree().process_frame
  # --perf-capture: also save the warmed view, to compare looks run against run.
  if "--perf-capture" in OS.get_cmdline_user_args():
   var tag:="look"
   for arg in OS.get_cmdline_user_args():
    if arg.begins_with("--look-tag="):tag=arg.trim_prefix("--look-tag=")
   await RenderingServer.frame_post_draw
   game.get_viewport().get_texture().get_image().save_png(output.path_join(tag+"-"+str(view.id)+".png"))
  var frame: Array=[];var cpu: Array=[];var gpu: Array=[];var physics: Array=[]
  var last:=Time.get_ticks_usec()
  for i in range(SAMPLES):
   await game.get_tree().process_frame
   var now:=Time.get_ticks_usec();frame.append((now-last)/1000.);last=now
   cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)+RenderingServer.get_frame_setup_time_cpu())
   gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
   physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
  all_frames.append_array(frame)
  report.views[view.id]={"frame_ms":_stat(frame),"render_cpu_ms":_stat(cpu),"gpu_ms":_stat(gpu),"physics_ms":_stat(physics),
   "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
  print("PERF ",view.id," ",JSON.stringify(report.views[view.id])," pit_sleeping=",game.world.pit_physics.snapshot().sleeping)
 report.overall=_stat(all_frames)
 report.memory_mb={"static":snappedf(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.,.1),"static_peak":snappedf(OS.get_static_memory_peak_usage()/1048576.,.1),"video":snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.,.1),"textures":snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.,.1),"buffers":snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.,.1)}
 print("PERF MEMORY ",JSON.stringify(report.memory_mb))
 report.ball_pit=game.world.pit_physics.snapshot()
 print("PERF EXTRA ",JSON.stringify({"pit":report.ball_pit}))
 var file:=FileAccess.open(output.path_join("perf-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("PERF OVERALL ",JSON.stringify(report.overall)," adapter=",report.adapter," cpu=",report.cpu)
