extends RefCounted

# 5.5.0: the crawler that comes to the control room, the rolling shutter, the
# door view and the quick report from the full-screen picture.
func run(game: Node3D, verify: Callable) -> void:
 game._start_nightwatch()
 while game.phase=="loading":await game.get_tree().process_frame
 var nw: Nightwatch=game.nightwatch
 game.set_process(false)
 var st: NightwatchStalker=nw.stalker
 verify.call(st!=null and st.shutter!=null and st.guest!=null,"Control room has no stair door or crawler")
 if st==null:return
 # Three directions: door, monitors, generator.
 nw.look("door");for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="door" and absf(nw.yaw-Nightwatch.LEFT.x)<.1,"The view cannot turn to the door")
 nw.handle(_key(KEY_D));for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="monitors","D does not turn back from the door")
 nw.handle(_key(KEY_D));for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="generator","D does not reach the generator")
 nw.handle(_key(KEY_A));nw.handle(_key(KEY_A));for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="door","A does not reach the door")
 # Shutter: space toggles, it costs power, the panel is clickable.
 nw.handle(_key(KEY_SPACE))
 verify.call(st.closed,"Space does not drop the shutter")
 for i in range(20):st.tick(.05,1,0.)
 verify.call(absf(st.shutter.position.y-NightwatchStalker.SHUTTER_CLOSED_Y)<.05,"The shutter does not come down")
 verify.call(st.drain()>0.,"A closed shutter costs no power")
 var p0:=nw.power;nw.tick(1.);var with_door:=p0-nw.power
 st.set_shutter(false);p0=nw.power;nw.tick(1.);var without:=p0-nw.power
 verify.call(with_door>without+.3,"The shutter does not drain power faster")
 # The crawler: starts after the first minute, walks its route on camera.
 nw.seconds=NightwatchConfig.STALKER_START+1.;st.clock=999.;st.tick(.1,3,nw.seconds)
 verify.call(st.state=="room" and is_instance_valid(st.body) and st.body.visible and st.camera()!="","The crawler does not set out")
 var cam_index:=NightwatchConfig.camera_index(st.camera())
 var spec: Dictionary=NightwatchConfig.CAMERAS[cam_index]
 var probe:=Camera3D.new();probe.keep_aspect=Camera3D.KEEP_WIDTH;probe.fov=Nightwatch.feed_fov(spec);nw.main_view.add_child(probe);probe.global_position=spec.p;probe.look_at(spec.at)
 var on_screen:=not probe.is_position_behind(st.body.global_position+Vector3.UP*.4)
 if on_screen:
  var px:=probe.unproject_position(st.body.global_position+Vector3.UP*.4)
  on_screen=px.x>=0 and px.y>=0 and px.x<=nw.main_view.size.x and px.y<=nw.main_view.size.y
 probe.queue_free()
 verify.call(on_screen,"The crawler stands outside its camera picture: "+st.camera())
 # Watching it on the main monitor slows it down.
 nw.select_camera(cam_index,false);nw.look("monitors");nw.view="monitors"
 st.clock=0.;st.tick(1.,3,nw.seconds)
 var watched_step:=st.clock
 nw.select_camera((cam_index+1)%10,false);st.clock=0.;st.tick(1.,3,nw.seconds)
 verify.call(watched_step<st.clock*.5,"Watching the crawler does not slow it down")
 # Out of the route: stairs (heard), then the door.
 st.index=st.route.size()-1;st.clock=st.step_time;st.tick(.01,3,nw.seconds)
 verify.call(st.state=="stairs" and not st.body.visible,"The crawler does not go to the stairs")
 st.clock=st.step_time;st.tick(.01,3,nw.seconds)
 verify.call(st.state=="door" and st.guest.visible,"The crawler does not reach the door")
 # Shutter down in time: it waits, bangs and goes away.
 st.set_shutter(true)
 var t:=0.
 while st.state=="door" and t<15.:st.tick(.1,3,nw.seconds);t+=.1
 verify.call(st.state=="idle" and st.repelled==1 and not st.guest.visible,"The shutter does not keep it out")
 # Shutter up while it waits: it gets in.
 st.set_shutter(false);st.state="door";st.clock=0.;st.wait=8.;st.guest.show()
 var result:=""
 t=0.
 while result=="" and t<6.:result=st.tick(.1,3,nw.seconds);t+=.1
 verify.call(result=="caught" and t>=NightwatchConfig.DOOR_GRACE-.2,"An open door does not let it in after the grace time")
 st.state="idle";st.guest.hide()
 # Quick report from the full-screen picture.
 var fx:=nw.force("kino","sitze","visitor")
 verify.call(not fx.is_empty(),"Could not force a test anomaly")
 # Let the engine take the new figure's materials before it is reported.
 for i in range(6):await game.get_tree().process_frame
 nw.open_fullscreen(NightwatchConfig.camera_index("kino"))
 await game.get_tree().process_frame
 var spot: Vector3=NightwatchConfig.area("kino","sitze").spots[0]+Vector3(0,1.,0)
 var feed_px:=nw.main_camera.unproject_position(spot)
 var view_size:=nw.full_image.size;var tex:=Vector2(nw.main_view.size);var s:=minf(view_size.x/tex.x,view_size.y/tex.y)
 var screen:=feed_px*s+(view_size-tex*s)*.5+nw.full_image.global_position
 nw.open_quick(screen)
 verify.call(nw.quick_open and nw.quick.visible and nw.quick_choice.room=="kino" and nw.quick_choice.area=="sitze","Click into the picture does not preselect the area")
 var before:=nw.reports
 (nw.quick.find_child("QuickKind_visitor",true,false) as Button).emit_signal("pressed")
 verify.call(nw.reports==before+1 and not nw.quick_open and nw.fullscreen,"Quick report does not report")
 for i in range(6):await game.get_tree().process_frame
 nw.open_quick(screen);nw.handle(_click(MOUSE_BUTTON_RIGHT))
 verify.call(not nw.quick_open and nw.fullscreen,"Right click does not cancel the quick report")
 var wrong_before:=nw.wrong
 nw.open_quick(screen);(nw.quick.find_child("QuickKind_light",true,false) as Button).emit_signal("pressed")
 verify.call(nw.wrong==wrong_before+1,"A wrong quick report is not counted")
 nw.close_fullscreen()
 for i in range(6):await game.get_tree().process_frame
 # Caught: the run ends with its own reason and the jumpscare.
 nw.wrong=0;st.state="door";st.clock=NightwatchConfig.DOOR_GRACE+1.;st.set_shutter(false)
 game.set_process(true);game.phase="nightwatch"
 var waited:=0
 while game.phase=="nightwatch" and waited<120:await game.get_tree().process_frame;waited+=1
 verify.call(nw.reason=="caught" and Nightwatch.REASONS.has("caught"),"Being caught does not end the shift")
 var limit:=0
 while game.phase!="nightwatch_over" and limit<600:await game.get_tree().process_frame;limit+=1
 verify.call(nw.results().get("reason","")=="caught","Results do not say it got in")
 game._main_menu();await game.get_tree().process_frame
 verify.call(not is_instance_valid(st.body) or not st.body.visible,"The crawler stays visible in the world after leaving")
 print("Nightwatch crawler checks done")

func _key(code: Key) -> InputEventKey:
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true;return e

func _click(button: MouseButton) -> InputEventMouseButton:
 var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=true;return e
