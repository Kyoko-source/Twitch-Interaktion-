extends RefCounted

func stats(values: Array[float]) -> Dictionary:
 values.sort()
 return {"median_ms":values[values.size()/2],"p95_ms":values[floori((values.size()-1)*.95)],"max_ms":values.back()}

func run(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var guard: NightGuard=game.player;var attraction: Node3D=game.world.playground.inflatable
 game.settings.motion=false;game._apply_settings()
 var report: Dictionary={"renderer":RenderingServer.get_current_rendering_method()}
 for mode in ["floor","back_jumping","side_contact"]:
  guard.position=attraction.to_global(Vector3(0,0,4.1) if mode=="floor" else Vector3(0,3.2,-.5) if mode=="back_jumping" else Vector3(3.25,0,-.5))
  guard.velocity=Vector3.ZERO;guard.rotation.y=attraction.rotation.y+PI/2;guard.camera.rotation=Vector3(-.2,0,0);guard.active=true
  for i in range(50):await game.get_tree().physics_frame
  var frames: Array[float]=[];var physics: Array[float]=[];var last:=Time.get_ticks_usec();var contacts:=0;var jumps:=0
  if mode=="side_contact":Input.action_press("forward")
  for i in range(150):
   if mode!="floor" and guard.is_on_floor() and i%40==0:
    var event:=InputEventAction.new();event.action="jump";event.pressed=true;guard._unhandled_input(event);jumps+=1
   await game.get_tree().physics_frame
   var now:=Time.get_ticks_usec();frames.append(float(now-last)/1000.);last=now
   physics.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.);contacts=maxi(contacts,guard.get_slide_collision_count())
  Input.action_release("forward");guard.active=false
  report[mode]={"frames":stats(frames),"physics":stats(physics),"contacts":contacts,"jumps":jumps,"position":[guard.position.x,guard.position.y,guard.position.z]}
 var file:=FileAccess.open(output.path_join("croc-profile.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("CROC PROFILE ",JSON.stringify(report));game._quit()
