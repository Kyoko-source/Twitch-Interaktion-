extends RefCounted

# --endless-only: endless mode, detail anomalies and achievements (4.14.0).
# With --capture-dir=DIR it also saves screenshots of the new screens.
func shot(game: Node3D, title: String) -> void:
 var dir:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):dir=arg.trim_prefix("--capture-dir=")
 if dir=="":return
 for i in range(4):await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png(dir.path_join("endless-%s.png"%title))

func run(game: Node3D,verify: Callable) -> void:
 # Pure state: tiers, lives, timer, save round trip.
 var run_state:=PatrolState.new();run_state.begin_endless(4140)
 verify.call(run_state.endless and run_state.lives==3 and run_state.round_number()==1,"Endless run does not start at round 1 with three lives")
 var early_ok:=true
 for i in range(5):
  if run_state.current!="none" and PatrolState.tier_of(run_state.current)!=1:early_ok=false
  run_state.decide(run_state.current!="none")
 verify.call(early_ok,"The first five endless rounds use quiet anomalies")
 verify.call(run_state.round_number()==6 and run_state.lives==3 and run_state.flawless==5,"Correct endless rounds do not advance")
 var wrong:=run_state.decide(run_state.current=="none")
 verify.call(not wrong.correct and run_state.lives==2 and run_state.round_number()==6 and run_state.flawless==0,"A wrong door must cost a life and keep the round")
 verify.call(not run_state.timed(),"Timer runs before round 15")
 run_state.streak=14
 verify.call(run_state.timed() and is_equal_approx(run_state.time_left(),300.),"Timer does not start at round 15 with five minutes")
 var all_ids:=PatrolState.ANOMALIES.map(func(a):return a.id)
 verify.call(PatrolState.TIER_1.all(func(id):return id in all_ids) and PatrolState.TIER_3.all(func(id):return id in all_ids),"Tier lists name unknown anomalies")
 verify.call(PatrolState.tier_weights(1)[0]==1. and PatrolState.tier_weights(31)[3]>0 and PatrolState.tier_weights(400)[3]>=.7,"Difficulty does not ramp from obvious to details")
 verify.call(PatrolState.detail_strength(31)>.99 and PatrolState.detail_strength(500)<.1 and PatrolState.detail_strength(200)<PatrolState.detail_strength(100),"Detail anomalies do not shrink with the rounds")
 var late:=PatrolState.new();late.begin_endless(77);late.streak=300
 var details:=0;var normals:=0
 for i in range(200):
  late._next()
  if late.current=="detail":details+=1
  elif late.current=="none":normals+=1
 verify.call(details>70 and normals>40,"Late rounds are not mostly detail anomalies (%d details, %d normal)"%[details,normals])
 run_state.round_time=42.5;run_state.current="detail";run_state.detail={"seed":9,"strength":.5}
 var copy:=PatrolState.new()
 verify.call(copy.restore(JSON.parse_string(JSON.stringify(run_state.serialize()))) and copy.endless and copy.lives==2 and copy.streak==14 and copy.current=="detail" and is_equal_approx(copy.round_time,42.5),"Endless save does not survive a round trip")
 var tampered:=run_state.serialize();tampered.lives=7
 verify.call(not PatrolState.new().restore(tampered),"Tampered endless lives are accepted")
 var normal_detail:=PatrolState.new();normal_detail.start(1);var normal_data:=normal_detail.serialize();normal_data.current="detail"
 verify.call(not PatrolState.new().restore(normal_data),"Normal shift accepts a detail anomaly")
 run_state.lives=1
 var last:=run_state.miss("timer")
 verify.call(last.accepted and last.over and run_state.over and not run_state.decide(true).accepted,"Losing the last life does not end the run")

 # Detail anomalies on the real world.
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 var applied_targets:={}
 game._build_world("none")
 for seed_value in range(1,60):
  var result:=EndlessDetails.apply(game.world,{"seed":seed_value,"strength":1.})
  if result.is_empty():continue
  applied_targets[result.target]=true
  if seed_value<4:verify.call(str(result.text).contains(":") and result.node.has_meta("endless_detail"),"Detail anomaly has no description")
 verify.call(applied_targets.size()>=10,"Detail anomalies only reach %d object types"%applied_targets.size())
 game._build_world("none");var a:=EndlessDetails.apply(game.world,{"seed":12,"strength":.3})
 var first_text: String=a.text;var first_transform: Transform3D=a.node.transform
 game._build_world("none");var b:=EndlessDetails.apply(game.world,{"seed":12,"strength":.3})
 verify.call(b.text==first_text and b.node.transform.is_equal_approx(first_transform),"The same seed does not rebuild the same detail")
 for target in EndlessDetails.TARGETS:
  verify.call(EndlessDetails.nodes(game.world,target[0]).size()>0,"Detail target %s is missing in the world"%target[0])

 # Game flow: separate save, HUD, a correct round, a wrong one, the timer.
 var normal_save: String=game.NORMAL_SAVE
 game._save()
 var normal_before: String=game._persistent_text(normal_save)
 game._start_endless()
 while game.phase=="loading":await game.get_tree().process_frame
 game.intro.skip();game.player.active=false
 verify.call(game.state.endless and game.SAVE==game.ENDLESS_SAVE and game.SAVE!=normal_save,"Endless run does not use its own save")
 game._resume();game.player.active=false
 verify.call(game.round_label.text.contains("ENDLOS") and game.round_label.text.contains("LEBEN 3/3"),"Endless HUD missing: "+game.round_label.text)
 game.phase="lift";var answer:bool=game.state.current!="none"
 game._finish_lift(answer)
 verify.call(game.state.round_number()==2 and game.state.lives==3,"Correct lift does not move to endless round 2")
 game.intro.skip();game._resume();game.player.active=false
 verify.call(game._persistent_text(normal_save)==normal_before,"Endless run overwrote the normal shift save")
 verify.call(not game.endless_save_info().is_empty(),"Endless menu does not offer to continue")
 game.phase="lift";game._finish_lift(game.state.current=="none")
 verify.call(game.phase=="failure" and game.state.lives==2,"Wrong door does not cost a life")
 while game.phase=="failure":
  game.door_failure.tick(1.0/30);await game.get_tree().process_frame
 while game.phase=="death":await game.get_tree().process_frame
 verify.call(game.phase=="arrival" and game.state.lives==2 and game.state.round_number()==2,"Endless run does not continue after a lost life")
 game.intro.skip();game._resume();game.player.active=false
 game.state.streak=20;game.state.round_time=PatrolState.ROUND_SECONDS-.01;game.set_process(true)
 for i in range(10):
  await game.get_tree().process_frame
  if game.phase!="play":break
 game.set_process(false)
 verify.call(game.phase=="failure" and game.state.lives==1 and game.last_result.get("reason","")=="timer","Expired timer does not grab the guard")
 while game.phase=="failure":
  game.door_failure.tick(1.0/30);await game.get_tree().process_frame
 while game.phase=="death":await game.get_tree().process_frame
 game.intro.skip();game._resume();game.player.active=false
 verify.call(game.round_label.text.contains("LEBEN 1/3") and game.round_label.text.contains(":"),"Timed HUD missing: "+game.round_label.text)
 game.player.camera.current=true;await shot(game,"hud")
 game.phase="lift";game._finish_lift(game.state.current=="none")
 while game.phase=="failure":
  game.door_failure.tick(1.0/30);await game.get_tree().process_frame
 while game.phase=="death":await game.get_tree().process_frame
 verify.call(game.phase=="endless_over" and game.menu.find_child("EndlessSummary",true,false)!=null and game.endless_save_info().is_empty(),"Losing the third life does not end the run")
 verify.call(game.achievements.has("round_10") and game.achievements.best_round>=20,"Round achievements are not recorded")
 await shot(game,"summary")

 # Achievements: unlock once, persist, menu lists every entry.
 var count: int=game.achievements.unlocked.size()
 verify.call(game.achievements.unlock("blitz") or game.achievements.has("blitz"),"Achievement does not unlock")
 verify.call(not game.achievements.unlock("blitz") and not game.achievements.unlock("no_such_id"),"Achievement unlocks twice")
 var reloaded:=AfterPlayAchievements.new();game.add_child(reloaded);reloaded.build(game)
 verify.call(reloaded.has("blitz") and reloaded.unlocked.size()>=count,"Achievements are not saved");reloaded.queue_free()
 game.achievements.show_menu(game._main_menu)
 verify.call(game.menu.find_children("Achievement_*","PanelContainer",true,false).size()==AfterPlayAchievements.LIST.size(),"Achievement list is incomplete")
 await shot(game,"achievements")
 NightMenus.endless(game);await shot(game,"menu")
 game._main_menu()
 verify.call(game.menu.find_child("MainMenuAction2",true,false).text.contains("Weitere Spielmodi") and (func():NightMenus.modes(game);return game.menu.find_child("Mode_endless",true,false)!=null).call(),"Main menu has no endless mode")
 await shot(game,"home")
 # Back to a normal shift: its own save comes back.
 game._request_shift()
 while game.phase=="loading":await game.get_tree().process_frame
 game.intro.skip()
 verify.call(not game.state.endless and game.SAVE==normal_save,"Normal shift stays in endless mode")
 DirAccess.remove_absolute(game.ENDLESS_SAVE);DirAccess.remove_absolute(game.achievements.path)
 game.set_process(true)
