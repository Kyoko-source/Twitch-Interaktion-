extends RefCounted

# 5.6.0: the crawler at the door and the clown in the vent. They do not walk
# the cameras; they are simply there when you look. The arrows at the screen
# edges, the shutter, the torch and both ways of being caught.
func run(game: Node3D, verify: Callable) -> void:
 game._start_nightwatch(3)
 while game.phase=="loading":await game.get_tree().process_frame
 var nw: Nightwatch=game.nightwatch
 game.set_process(false)
 var st: NightwatchStalker=nw.stalker;var vt: NightwatchVent=nw.vent
 verify.call(st!=null and st.shutter!=null and st.guest!=null and vt!=null and vt.clown!=null,"Control room has no door, vent or figures")
 if st==null or vt==null:return
 # Arrows: left to the door, right to the vent, back again.
 nw._tick_view(.05)
 verify.call(nw.arrow_left.visible and nw.arrow_right.visible,"The monitor view shows no arrows")
 nw.click_at(nw.arrow_left.get_global_rect().get_center());for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="door" and absf(nw.yaw-Nightwatch.LEFT.x)<.1 and not nw.arrow_left.visible and nw.arrow_right.visible,"The left arrow does not turn to the door")
 nw.click_at(nw.arrow_right.get_global_rect().get_center());nw.click_at(nw.arrow_right.get_global_rect().get_center());for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="right" and absf(nw.yaw-Nightwatch.RIGHT.x)<.1 and nw.arrow_left.visible and not nw.arrow_right.visible,"The right arrow does not turn to the vent")
 nw.handle(_key(KEY_A));nw.handle(_key(KEY_A));for i in range(40):nw._tick_view(.05)
 verify.call(nw.view=="door","A does not reach the door")
 # The door: nothing for a while, then it simply stands there.
 st.start()
 for i in range(10):st.tick(1.,0,float(i))
 verify.call(st.state=="idle" and not st.guest.visible,"The crawler comes on a night it should stay away")
 var t:=0.
 while st.state=="idle" and t<200.:st.tick(.5,9,t);t+=.5
 verify.call(st.state=="door" and st.guest.visible and t>=NightwatchConfig.first_visit(9)-1.,"The crawler does not come to the door")
 # Shutter down in time: it waits, bangs, goes; the shutter goes up by itself.
 nw.power=80.;verify.call(nw.handle(_key(KEY_SPACE)) and st.closed and is_equal_approx(nw.power,60.),"Space does not drop the shutter for 20 %")
 for i in range(20):st.tick(.05,9,0.)
 verify.call(absf(st.shutter.position.y-NightwatchStalker.SHUTTER_CLOSED_Y)<.05,"The shutter does not come down")
 t=0.
 while st.state=="door" and t<15.:st.tick(.1,9,0.);t+=.1
 verify.call(st.state=="idle" and st.repelled==1 and not st.guest.visible,"The shutter does not keep it out")
 t=0.
 while st.closed and t<5.:st.tick(.1,9,0.);t+=.1
 verify.call(not st.closed,"The shutter does not go up again after it left")
 # Too slow: it gets in after its grace time and the night is over.
 st._arrive()
 var result:="";t=0.
 while result=="" and t<12.:result=st.tick(.1,9,0.);t+=.1
 verify.call(result=="caught" and t>=NightwatchConfig.grace(9)-.2,"An open door does not let it in after the grace time")
 # The vent: it sits in the opening, barely lit; the torch drives it back.
 st.state="idle";st.guest.hide();st.clock=0.;st.next=999.
 vt.start()
 for i in range(10):vt.tick(1.,0,float(i),false)
 verify.call(vt.state=="idle" and not vt.clown.visible,"The clown comes on night 1")
 t=0.
 while vt.state=="idle" and t<200.:vt.tick(.5,9,t,false);t+=.5
 verify.call(vt.at_opening() and vt.clown.visible and vt.glow.light_energy>0.,"The clown does not come to the vent")
 # The torch only counts while you look into the vent.
 nw.look("door");for i in range(40):nw._tick_view(.05)
 nw.power=80.;nw.handle(_key(KEY_F))
 verify.call(nw.torch_time>0. and is_equal_approx(nw.power,70.) and not nw.torch_on_vent(),"F does not switch the torch on, or it reaches the vent from the door")
 vt.tick(.2,9,0.,nw.torch_on_vent())
 verify.call(vt.at_opening(),"The torch at the door scares the clown in the vent")
 nw.look("right");for i in range(40):nw._tick_view(.05)
 verify.call(nw.torch_on_vent(),"The torch does not reach the vent when looking right")
 t=0.
 while vt.at_opening() and t<3.:vt.tick(.1,9,0.,nw.torch_on_vent());t+=.1
 verify.call(not vt.at_opening() and vt.repelled==1 and not vt.clown.visible and t>=NightwatchConfig.TORCH_REPEL-.15,"The torch does not drive the clown back")
 nw.handle(_key(KEY_F))
 verify.call(nw.torch_time==0.,"F does not switch the torch off")
 nw._tick_torch(.1);verify.call(nw.torch.light_energy==0.,"The torch light stays on")
 # Left in the dark: it comes through.
 vt._arrive();result="";t=0.
 while result=="" and t<12.:result=vt.tick(.1,9,0.,false);t+=.1
 verify.call(result=="caught" and t>=NightwatchConfig.grace(9)-.2,"The clown does not come through after its grace time")
 # Caught through the vent: its own reason and the lunge.
 vt._arrive();vt.clock=99.;nw.torch_time=0.
 game.set_process(true);game.phase="nightwatch"
 var waited:=0
 while game.phase=="nightwatch" and waited<120:await game.get_tree().process_frame;waited+=1
 verify.call(nw.reason=="vent" and Nightwatch.REASONS.has("vent"),"Being caught through the vent does not end the night")
 var limit:=0
 while game.phase!="nightwatch_over" and limit<600:await game.get_tree().process_frame;limit+=1
 verify.call(nw.results().get("reason","")=="vent" and str(nw.results().title)=="ES KAM DURCH DEN SCHACHT","Results do not say it came through the vent")
 # Caught at the door.
 game._start_nightwatch(3)
 while game.phase=="loading":await game.get_tree().process_frame
 st._arrive();st.clock=99.
 limit=0
 while game.phase!="nightwatch_over" and limit<700:await game.get_tree().process_frame;limit+=1
 verify.call(nw.results().get("reason","")=="caught","Results do not say it got in at the door")
 # 5.6.1: the rabbit. Not out in nights 1-2; from night 3 it walks the cameras.
 game._start_nightwatch(2)
 while game.phase=="loading":await game.get_tree().process_frame
 var bn: NightwatchBunny=nw.bunny
 verify.call(not bn.active() and not is_instance_valid(bn.body),"The rabbit is out before night 3")
 game._start_nightwatch(3)
 while game.phase=="loading":await game.get_tree().process_frame
 game.set_process(false);game.phase="nightwatch"
 verify.call(bn.stage==0 and is_instance_valid(bn.body) and bn.body.visible and bn.camera_id()=="kostuem","The rabbit does not start in the costume store")
 # Watched on the main monitor it does not move.
 nw.look("monitors");nw.select_camera(NightwatchConfig.camera_index("kostuem"),false)
 for i in range(400):bn.tick(.5,nw.level_bunny)
 verify.call(bn.stage==0 and bn.watched(),"The rabbit moves while it is watched")
 # Looking away (other camera, or at the door) lets it walk.
 nw.select_camera(NightwatchConfig.camera_index("kino"),false)
 for i in range(200):bn.tick(.5,nw.level_bunny)
 verify.call(bn.stage>0,"The rabbit does not move while nobody watches it")
 nw.look("door")
 var guard:=0
 while not bn.at_door() and guard<2000:bn.tick(.5,nw.level_bunny);guard+=1
 verify.call(bn.at_door() and bn.door_body.visible and not bn.body.visible,"The rabbit never reaches the stair door")
 # A click on it in full screen is no missed click.
 bn._place(2);nw.look("monitors");nw.open_fullscreen(NightwatchConfig.camera_index(bn.camera_id()));nw.miss_lock=0.
 var head:=nw.main_camera.unproject_position(bn.body.global_position+Vector3(0,.55*NightwatchBunny.SCALE,0))
 var before:=nw.misses
 verify.call(not nw.fix_at(nw.screen_point(head)) and nw.misses==before,"A click on the rabbit counts as a missed click")
 nw.close_fullscreen()
 # At the door: the shutter sends it back to the start.
 bn._place(NightwatchBunny.ROUTE.size());nw.power=100.;nw.toggle_shutter()
 for i in range(10):bn.tick(.3,nw.level_bunny)
 verify.call(bn.stage==0 and bn.repelled==1,"The shutter does not send the rabbit back")
 st.set_shutter(false)
 # With the shutter up it comes in.
 bn._place(NightwatchBunny.ROUTE.size());var res:="";t=0.
 while res=="" and t<20.:res=bn.tick(.1,nw.level_bunny);t+=.1
 verify.call(res=="caught" and t>=NightwatchConfig.bunny_door(nw.level_bunny)-.2,"The rabbit does not come in with the shutter up")
 bn._place(NightwatchBunny.ROUTE.size());bn.door_clock=99.
 game.set_process(true)
 limit=0
 while game.phase!="nightwatch_over" and limit<700:await game.get_tree().process_frame;limit+=1
 verify.call(nw.results().get("reason","")=="bunny" and str(nw.results().title)=="DER HASE IST HEREINGEKOMMEN","Results do not say the rabbit got in")
 # The wall clock: the second hand jumps once a second, the hands show the night.
 game._start_nightwatch(1)
 while game.phase=="loading":await game.get_tree().process_frame
 game.set_process(false)
 nw.seconds=NightwatchConfig.HOUR*3.+.5;nw._tick_wall_clock()
 verify.call(absf(nw.clock_hour.rotation.z+TAU*3./12.)<.01 and absf(nw.clock_minute.rotation.z)<.06,"The wall clock does not show 03:00")
 var step_before:=nw.clock_step;nw.seconds+=1.;nw._tick_wall_clock()
 verify.call(nw.clock_step==step_before+1 and nw.clock_tick.playing,"The wall clock does not tick")
 game.set_process(true)
 game._main_menu();await game.get_tree().process_frame
 verify.call(not st.guest.visible and not vt.clown.visible and not is_instance_valid(bn.body) and not bn.door_body.visible,"A figure stays visible after leaving")
 print("Nightwatch door and vent checks done")

func _key(code: Key) -> InputEventKey:
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true;return e
