extends RefCounted

# --nightwatch-only: Nightwatch Protocol (4.15.0). With --capture-dir=DIR it
# also saves every camera feed and the control room screens.
var dir:=""

func shot(game: Node3D, title: String) -> void:
 if dir=="":return
 for i in range(4):await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png(dir.path_join("nightwatch-%s.png"%title))

func feed_shot(game: Node3D, title: String) -> void:
 if dir=="":return
 for i in range(6):await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.nightwatch.main_view.get_texture().get_image().save_png(dir.path_join("nightwatch-%s.png"%title))

func wait_phase(game: Node3D, wanted: String, limit: float) -> bool:
 var clock:=0.
 while game.phase!=wanted and clock<limit:
  await game.get_tree().process_frame;clock+=game.get_process_delta_time()
 return game.phase==wanted

# Seen by the camera: inside the picture and not hidden behind a wall.
# Returns "" or why not.
func blocked(game: Node3D, spec: Dictionary, point: Vector3, own: Node) -> String:
 var probe:=Camera3D.new();probe.keep_aspect=Camera3D.KEEP_WIDTH;probe.fov=Nightwatch.feed_fov(spec);game.nightwatch.main_view.add_child(probe);probe.global_position=spec.p;probe.look_at(spec.at)
 var why:=""
 if probe.is_position_behind(point):why="behind"
 else:
  var uv:=probe.unproject_position(point)/Vector2(game.nightwatch.main_view.size)
  if uv.x<.04 or uv.x>.96 or uv.y<.05 or uv.y>.97:why="frame %.2f,%.2f"%[uv.x,uv.y]
 # Climbing nets are see-through on screen, so the ray passes them.
 var from: Vector3=spec.p
 for attempt in range(8):
  if why!="":break
  var query:=PhysicsRayQueryParameters3D.create(from,point,1)
  var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty() or from.distance_to(hit.position)>=from.distance_to(point)-.4:break
  var body: Node=hit.collider
  if own!=null and (own==body or own.is_ancestor_of(body)):break
  var label:=str(body.get_parent().name if body.get_parent() else "")+str(body.name)
  if label.containsn("net"):from=hit.position+(point-from).normalized()*.05;continue
  why="wall %s at %.1f of %.1f"%[label,(spec.p as Vector3).distance_to(hit.position),(spec.p as Vector3).distance_to(point)]
 probe.queue_free()
 return why

func run(game: Node3D, verify: Callable) -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):dir=arg.trim_prefix("--capture-dir=")
 # Configuration matches the design table.
 var table:=[[1,20.],[2,18.],[2,15.],[3,14.],[4,12.],[5,10.]]
 var table_ok:=true
 for i in range(table.size()):
  var row:=NightwatchConfig.qte(i+1)
  if int(row.words)!=table[i][0] or not is_equal_approx(float(row.time),table[i][1]):table_ok=false
 verify.call(table_ok,"Generator QTE stages differ from the design table")
 verify.call(NightwatchConfig.stage(1).active==1 and NightwatchConfig.stage(99).active>=4 and float(NightwatchConfig.stage(1).detect)>float(NightwatchConfig.stage(12).detect),"Difficulty does not rise from stage 1")
 var cams_ok:=true
 for room in NightwatchConfig.ROOMS:
  for area in room.areas:
   if NightwatchConfig.camera_index(area.camera)<0 or area.spots.is_empty():cams_ok=false
 verify.call(cams_ok,"An area has no camera or no spot")
 var rng:=RandomNumberGenerator.new();rng.seed=5
 verify.call(NightwatchConfig.words_for(1,rng).size()==1 and NightwatchConfig.words_for(6,rng).size()==5,"Generator word count does not follow the stage")

 # Start through the main menu entry.
 game._main_menu();await game.get_tree().process_frame
 NightMenus.modes(game)
 var entry:=game.menu.find_child("Mode_nightwatch",true,false) as Button
 verify.call(entry!=null and entry.text.contains("Nightwatch"),"Modes menu has no Nightwatch Protocol")
 # 5.5.0: open as a beta (it was greyed out "In Development" since 5.2.4).
 verify.call(not entry.disabled and entry.text.contains("Beta"),"Nightwatch entry is not open as a beta")
 NightMenus.open_mode(game,"nightwatch");await game.get_tree().process_frame
 verify.call(game.menu.find_child("NightwatchStart",true,false)!=null,"Nightwatch Protocol does not open from the modes menu")
 NightMenus.nightwatch(game)
 verify.call(game.menu.find_child("NightwatchStart",true,false)!=null and game.menu.find_child("NightwatchHighscore",true,false)!=null,"Nightwatch menu misses start or highscore")
 await shot(game,"menu")
 var endless_best: int=game.achievements.best_round
 game._start_nightwatch()
 while game.phase=="loading":await game.get_tree().process_frame
 var nw: Nightwatch=game.nightwatch
 verify.call(game.phase=="nightwatch" and nw.running and nw.cam.current,"Nightwatch does not start in the control room")
 verify.call(nw.feeds.size()==NightwatchConfig.CAMERAS.size() and nw.feeds.size()>=9,"Not every camera has a feed")
 verify.call(nw.main_view.world_3d==game.get_world_3d() and (nw.feeds[0] as SubViewport).world_3d==game.get_world_3d(),"Feeds do not show the real world")
 verify.call(not game.player.active and not game.hud.visible,"The guard can still walk in Nightwatch")
 game.set_process(false)

 # Every target and every spot is visible from its camera.
 var hidden: Array=[];var missing: Array=[]
 for room in NightwatchConfig.ROOMS:
  for area in room.areas:
   var spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(area.camera)]
   for spot in area.spots:
    var why_spot:=blocked(game,spec,spot+Vector3(0,1.2,0),null)
    if why_spot!="":hidden.append(str(area.id)+":spot "+why_spot)
   for row in area.objects:
    var count:=NightwatchAnomalies.group_size(game.world,row[0])
    for i in range(maxi(count,1)):
     var node:=NightwatchAnomalies.resolve(game.world,row[0],i)
     if node==null:missing.append(row[0]);continue
     if row[0].ends_with("/*") and i>=3:break
     var why_node:=blocked(game,spec,NightwatchAnomalies.bounds(node).get_center(),node)
     if why_node!="":hidden.append(str(area.id)+":"+str(row[0])+" "+why_node)
 verify.call(missing.is_empty(),"Nightwatch targets missing in the world: "+str(missing))
 verify.call(hidden.is_empty(),"Nightwatch targets not visible on their camera: "+str(hidden))

 # Each kind appears and is undone exactly.
 var kinds_ok: Array=[]
 for kind in NightwatchConfig.KIND_ORDER:
  var placed:={}
  for room in NightwatchConfig.ROOMS:
   for area in room.areas:
    if not placed.is_empty():break
    if kind in NightwatchConfig.SPOT_KINDS:placed=nw.force(room.id,area.id,kind)
    else:
     for row in area.objects:
      if kind in row[2] and not row[0].ends_with("/*"):placed=nw.force(room.id,area.id,kind,row[0]);break
  if placed.is_empty():kinds_ok.append(kind+":none");continue
  var node: Node3D=placed.node
  var before: Transform3D=placed.restore.transform if node else Transform3D()
  var extras: int=placed.added.size()
  nw.tick(.5)
  var changed:=true
  match kind:
   "missing":changed=not node.visible
   "floating":changed=node.transform.origin.y>before.origin.y+.6
   "moved":changed=node.transform.origin.distance_to(before.origin)>.5
   "extra","visitor","apparition","light":changed=extras>0
   "motion":changed=not node.transform.is_equal_approx(before)
  if not changed:kinds_ok.append(kind+":unchanged")
  if dir!="":
   nw.select_camera(NightwatchConfig.camera_index(str(NightwatchConfig.area(placed.room,placed.area).camera)),false)
   nw.main_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
   await feed_shot(game,"kind-"+kind)
  var result:=nw.report(placed.room,placed.area,kind)
  if not result.get("correct",false):kinds_ok.append(kind+":report")
  if node and (not node.transform.is_equal_approx(before) or not node.visible):kinds_ok.append(kind+":restore")
  for added in placed.added:if is_instance_valid(added) and not (added as Node).is_queued_for_deletion():kinds_ok.append(kind+":leftover")
 verify.call(kinds_ok.is_empty(),"Nightwatch anomaly kinds fail: "+str(kinds_ok))
 verify.call(nw.reports==NightwatchConfig.KIND_ORDER.size() and nw.score()>=NightwatchConfig.POINTS_REPORT*nw.reports and nw.combo==nw.reports,"Correct reports do not score with a streak")

 # Camera screenshots of the plain world.
 if dir!="":
  for i in range(NightwatchConfig.CAMERAS.size()):
   nw.select_camera(i,false);await feed_shot(game,"cam-%02d"%(i+1))
  nw.select_camera(1,false);game.set_process(true)
  await shot(game,"control-room")
  nw.open_book();nw._choose("room","halle");nw._choose("area","auto");nw._choose("kind","missing");await shot(game,"book");nw.close_book()
  Input.warp_mouse(game.get_viewport().get_visible_rect().size*.5)
  nw.look("generator");for i in range(40):await game.get_tree().process_frame
  verify.call(nw.view=="generator" and absf(nw.yaw-Nightwatch.RIGHT.x)<.2,"The view does not turn to the generator")
  await shot(game,"generator")
  nw.start_qte();await shot(game,"qte");nw.qte={};nw.qte_panel.hide()
  nw.look("monitors");game.set_process(false)

 # Left click on a monitor fills the screen; right click returns.
 nw.open_fullscreen(4)
 verify.call(nw.fullscreen and nw.full.visible and nw.selected==4 and nw.full_image.texture==nw.main_view.get_texture(),"A monitor does not open full screen")
 if dir!="":game.set_process(true);await shot(game,"fullscreen");game.set_process(false)
 var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
 verify.call(nw.handle(right) and not nw.fullscreen and not nw.full.visible,"Right click does not leave full screen")
 var cam_env: Environment=(nw.feeds[0] as SubViewport).get_child(0).environment
 verify.call(cam_env!=null and cam_env.tonemap_exposure>=NightwatchConfig.FEED_EXPOSURE*.9,"Camera feeds have no night-vision exposure")

 # A wrong report counts; the third ends the watch once.
 nw.start(41)
 verify.call(nw.wrong==0 and is_equal_approx(nw.power,100.) and nw.active.is_empty() and nw.score()==0,"Nightwatch does not reset on restart")
 var wrong_one:=nw.report("kino","popcorn","light")
 verify.call(wrong_one.accepted and not wrong_one.correct and nw.wrong==1 and nw.running,"A wrong report is not counted")
 nw.report("kino","popcorn","light")
 verify.call(nw.running and nw.wrong==2,"Two wrong reports already end the watch")
 var third:=nw.report("kino","popcorn","light")
 verify.call(third.get("over",false) and nw.over and nw.reason=="wrong" and not nw.report("kino","popcorn","light").accepted,"Third wrong report does not end the watch exactly once")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",8.) and game.menu.find_child("NightwatchSummary",true,false)!=null,"No result screen after the third wrong report")
 verify.call(game.menu.find_child("NightwatchSummary",true,false)!=null and str(nw.results().title)=="ZU VIELE FEHLMELDUNGEN","Result screen does not name the reason")
 await shot(game,"summary")
 game.set_process(false)

 # An anomaly that runs out ends the watch at once.
 nw.start(42);game.phase="nightwatch"
 var late:=nw.force("halle","auto","missing")
 late.left=.05;nw.tick(.1)
 verify.call(nw.over and nw.reason=="missed" and late.state=="expired","An expired anomaly does not end the watch")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",10.),"No result screen after a missed anomaly")
 verify.call(game.world.find_children("NightwatchVisitor*","",true,false).is_empty() and NightwatchAnomalies.resolve(game.world,"prop:car").visible,"A missed anomaly stays in the world")
 game.set_process(false)

 # Power: quiet above 20 %, alarm below, black out at 0 %.
 nw.start(43);game.phase="nightwatch"
 nw.power=60.;nw.tick(.1)
 verify.call(not nw.alarm_active() and not nw.beep.playing and nw.instability()==0.,"Power warning plays above 50 %")
 nw.power=35.;nw.tick(.1)
 verify.call(not nw.alarm_active() and nw.instability()>0.,"Screens do not flicker at half power")
 nw.power=19.;nw.tick(.1)
 verify.call(nw.alarm_active() and nw.beep_clock>0. and nw.instability()>.12,"No alarm at 19 % power")
 var slow:=nw.beep_clock;nw.power=5.;nw.beep_clock=0.;nw.tick(.01)
 verify.call(nw.beep_clock<slow,"The alarm does not get faster below 10 %")

 # Generator: anomaly timers and spawns wait, power keeps falling.
 nw.power=40.
 var waiting:=nw.force("empfang","theke","visitor")
 var left_before: float=waiting.left;var spawn_before:=nw.spawn_clock
 verify.call(nw.start_qte(),"The generator does not start")
 nw.tick(1.)
 verify.call(is_equal_approx(float(waiting.left),left_before) and is_equal_approx(nw.spawn_clock,spawn_before) and nw.power<40.,"Generator time does not pause anomalies or still spares the power")
 nw.type_key("#")
 verify.call(nw.qte.typed==0,"A wrong key counts as typed")
 for word in nw.qte.words.duplicate():
  for letter in str(word):nw.type_key(letter)
 verify.call(nw.qte.is_empty() and is_equal_approx(nw.power,100.) and nw.repairs==1 and not nw.alarm_active(),"A finished repair does not refill the power")
 nw.power=30.;nw.start_qte();nw.tick(float(nw.qte.time)+.5)
 verify.call(nw.qte.is_empty() and nw.failed_repairs==1 and nw.power<30. and nw.running,"A failed repair refills power or ends the watch")
 verify.call(nw.start_qte(),"A repair cannot be retried after a failure");nw.qte={};nw.qte_panel.hide()
 nw.power=.01;nw.tick(.1)
 verify.call(nw.over and nw.reason=="power","Empty power does not end the watch")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",10.),"No result screen after the blackout")
 game.set_process(false)

 # Spawns follow the stage and never during a repair.
 nw.start(44);game.phase="nightwatch"
 for i in range(200):nw.tick(.25)
 verify.call(nw.active.size()>=1 and nw.active.size()<=int(NightwatchConfig.stage(NightwatchConfig.stage_of(nw.seconds)).active),"Anomalies do not spawn within the stage limit")
 nw._clear_anomalies();nw.spawn_clock=0;nw.next_spawn=1.
 nw.start_qte();for i in range(12):nw.tick(.25)
 verify.call(nw.active.is_empty(),"An anomaly spawned during a generator repair")
 nw.qte={};nw.qte_panel.hide()

 # Highscore is separate from the endless record.
 verify.call(game.achievements.nightwatch_best>0 and game.achievements.best_round==endless_best,"Nightwatch highscore is missing or touched the endless record")
 var stored: Variant=JSON.parse_string(game._persistent_text(game.achievements.path))
 verify.call(stored is Dictionary and int(stored.get("nightwatch_best",0))==game.achievements.nightwatch_best,"Nightwatch highscore is not saved")

 # Leaving undoes everything; the normal game is untouched.
 game.set_process(true);for i in range(10):await game.get_tree().process_frame
 nw.force("kino","sitze","visitor");nw.force("party","tisch","floating")
 for i in range(10):await game.get_tree().process_frame
 game._main_menu();await game.get_tree().process_frame
 verify.call(not nw.running and not nw.visible and game.menu_camera.current and nw.active.is_empty(),"Leaving Nightwatch keeps it running")
 verify.call(game.world.find_children("Nightwatch*","",true,false).filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"Nightwatch figures stay in the world after leaving")
 verify.call(game.door_failure.get_parent()==game.player.camera and nw.scare.get_parent()==nw.cam and not nw.scare.running,"Nightwatch uses or keeps the shift jumpscare")
 DirAccess.remove_absolute(game.achievements.path)
