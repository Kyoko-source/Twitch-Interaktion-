extends RefCounted

func stats(values: Array[float]) -> Dictionary:
 values.sort()
 return {"median_ms":values[values.size()/2],"p95_ms":values[floori((values.size()-1)*.95)],"max_ms":values.back()}

func run(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var guard: NightGuard=game.player;guard.position=Vector3(12.7,0,-8.05);guard.rotation.y=PI/2;guard.camera.rotation=Vector3(-.60,0,0);guard.camera.position.y=1.65
 game.get_window().size=Vector2i(1920,1080);game.settings.motion=false;game._apply_settings()
 await game.get_tree().create_timer(2.).timeout
 var report: Dictionary={}
 for mode in ["idle","chair_contact"]:
  var frame_times: Array[float]=[];var physics_times: Array[float]=[];var last:=Time.get_ticks_usec()
  guard.active=mode=="chair_contact"
  if guard.active:Input.action_press("forward")
  for i in range(100):
   await game.get_tree().process_frame
   var now:=Time.get_ticks_usec();frame_times.append(float(now-last)/1000.);last=now
   physics_times.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.)
  Input.action_release("forward")
  report[mode]={"frames":stats(frame_times),"physics":stats(physics_times),"position":[guard.position.x,guard.position.y,guard.position.z],"contacts":guard.get_slide_collision_count()}
 guard.active=false
 var file:=FileAccess.open(output.path_join("chair-profile.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("CHAIR PROFILE ",JSON.stringify(report));game._quit()
