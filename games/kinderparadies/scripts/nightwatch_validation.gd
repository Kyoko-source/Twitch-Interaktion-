extends RefCounted

# --nightwatch-only: Nightwatch Protocol. 5.6.0: nights 1-5, room changes that
# are fixed with a left click, the status lines, the critical alarm, power,
# the generator, the blackout and 06:00. With --capture-dir=DIR it also saves
# every camera feed.
var dir:=""

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

# Where on screen to click to hit this change in the full-screen picture.
func aim(nw: Nightwatch, record: Dictionary) -> Vector2:
 var boxes: Array=nw.anomalies.targets(record)
 if boxes.is_empty():return Vector2(-999,-999)
 return nw.screen_point(nw.main_camera.unproject_position((boxes[0] as AABB).get_center()))

func run(game: Node3D, verify: Callable) -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):dir=arg.trim_prefix("--capture-dir=")
 # Configuration: five nights that get harder, anomalies that grow by the hour.
 var rising:=true
 for n in range(2,NightwatchConfig.NIGHTS+1):
  var a:=NightwatchConfig.night(n-1);var b:=NightwatchConfig.night(n)
  if int(b.crawler)<int(a.crawler) or int(b.clown)<int(a.clown) or float(b.interval)>float(a.interval) or float(b.drain)<float(a.drain):rising=false
 verify.call(NightwatchConfig.NIGHTS==5 and rising and int(NightwatchConfig.night(1).clown)==0,"Nights do not get harder from night 1 to 5")
 verify.call(NightwatchConfig.spawn_interval(1,0.)>NightwatchConfig.spawn_interval(1,NightwatchConfig.night_length()*.99)*1.8,"Anomalies do not come more often later in the night")
 verify.call(NightwatchConfig.STATUS[1]=="WARNING – UNUSUAL ACTIVITY DETECTED" and NightwatchConfig.STATUS[2]=="ALERT – ANOMALY LEVELS RISING" and NightwatchConfig.STATUS[3]=="CRITICAL – ANOMALY THRESHOLD EXCEEDED","Status lines differ from the design")
 var cams_ok:=true;var figure_kinds:=false;var balls:=false
 for room in NightwatchConfig.ROOMS:
  for area in room.areas:
   if NightwatchConfig.camera_index(area.camera)<0 or area.spots.is_empty():cams_ok=false
   if "balls" in area.get("special",[]):balls=area.camera=="baellebad"
   for row in area.objects:
    if "visitor" in row[2] or "apparition" in row[2]:figure_kinds=true
 verify.call(cams_ok,"An area has no camera or no spot")
 verify.call(not figure_kinds and not NightwatchConfig.KINDS.has("visitor") and not NightwatchConfig.KINDS.has("apparition"),"An anomaly is still a figure instead of a change in the room")
 verify.call(balls,"The ball pit has no floating balls")

 # The menu: night 1 is open, the others wait.
 var saved_night: int=game.achievements.nightwatch_night
 game.achievements.nightwatch_night=0
 game._main_menu();await game.get_tree().process_frame
 NightMenus.modes(game)
 var entry:=game.menu.find_child("Mode_nightwatch",true,false) as Button
 verify.call(entry!=null and not entry.disabled and entry.text.contains("Beta"),"Nightwatch entry is not open as a beta")
 NightMenus.open_mode(game,"nightwatch");await game.get_tree().process_frame
 var n1:=game.menu.find_child("NightwatchNight1",true,false) as Button
 var n2:=game.menu.find_child("NightwatchNight2",true,false) as Button
 verify.call(game.menu.find_child("NightwatchStart",true,false)!=null and n1!=null and not n1.disabled and n2!=null and n2.disabled,"Nightwatch menu does not offer night 1 and lock the rest")
 var endless_best: int=game.achievements.best_round
 game._start_nightwatch(1)
 while game.phase=="loading":await game.get_tree().process_frame
 var nw: Nightwatch=game.nightwatch
 verify.call(game.phase=="nightwatch" and nw.running and nw.cam.current and nw.night==1 and nw.clock_string()=="00:00","Night 1 does not start at 00:00 in the control room")
 verify.call(nw.feeds.size()==NightwatchConfig.CAMERAS.size() and nw.main_view.world_3d==game.get_world_3d(),"Feeds do not show the real world")
 verify.call(not game.player.active and not game.hud.visible,"The guard can still walk in Nightwatch")
 verify.call(nw.get("book")==null and nw.get("quick")==null,"The report book or quick report is still there")
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

 # Each kind appears, a left click on it in the full-screen picture puts it
 # right, nothing is left behind.
 var kinds_ok: Array=[]
 for kind in NightwatchConfig.KIND_ORDER:
  var placed:={}
  for room in NightwatchConfig.ROOMS:
   for area in room.areas:
    if not placed.is_empty():break
    if kind in NightwatchConfig.SPOT_KINDS:
     if kind=="balls" and not "balls" in area.get("special",[]):continue
     placed=nw.force(room.id,area.id,kind)
    else:
     for row in area.objects:
      if kind in row[2] and not row[0].ends_with("/*"):placed=nw.force(room.id,area.id,kind,row[0]);break
  if placed.is_empty():kinds_ok.append(kind+":none");continue
  var node: Node3D=placed.node
  var before: Transform3D=placed.restore.transform if node else Transform3D()
  var others: Array=placed.others.duplicate()
  nw.tick(.5)
  var changed:=true
  match kind:
   "missing":changed=not node.visible
   "floating":changed=node.transform.origin.y>before.origin.y+.6
   "moved":changed=node.transform.origin.distance_to(before.origin)>.5
   "extra","light","balls":changed=placed.added.size()>0
   "motion":changed=not node.transform.is_equal_approx(before)
   "room":changed=others.size()>=2 and not (others[0].node as Node3D).transform.is_equal_approx(others[0].transform)
  if not changed:kinds_ok.append(kind+":unchanged")
  var cam_index:=NightwatchConfig.camera_index(str(NightwatchConfig.area(placed.room,placed.area).camera))
  nw.open_fullscreen(cam_index);nw.miss_lock=0.
  await game.get_tree().process_frame
  if dir!="":nw.main_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;await feed_shot(game,"kind-"+kind)
  var added: Array=placed.added.duplicate()
  var fixed_before:=nw.fixed
  nw.fix_at(aim(nw,placed))
  if nw.fixed!=fixed_before+1 or nw.active.has(placed):kinds_ok.append(kind+":click")
  if node and (not node.transform.is_equal_approx(before) or not node.visible):kinds_ok.append(kind+":restore")
  for row in others:if not (row.node as Node3D).transform.is_equal_approx(row.transform):kinds_ok.append(kind+":room-restore")
  for item in added:if is_instance_valid(item) and (item as Node3D).visible and not (item as Node).is_queued_for_deletion():kinds_ok.append(kind+":leftover")
  nw.close_fullscreen()
  for i in range(6):await game.get_tree().process_frame
 verify.call(kinds_ok.is_empty(),"Nightwatch anomaly kinds fail: "+str(kinds_ok))

 # A click where nothing changed: locked for a moment, nothing fixed.
 nw.start(1,41);game.phase="nightwatch"
 var far:=nw.force("kino","popcorn","missing")
 nw.open_fullscreen(NightwatchConfig.camera_index("empfang"))
 var miss_before:=nw.misses
 verify.call(not nw.fix_at(Vector2(30,30)) and nw.misses==miss_before+1 and nw.miss_lock>0. and nw.active.has(far),"A click on nothing is not counted as a miss")
 nw.select_camera(NightwatchConfig.camera_index("kino"),false);await game.get_tree().process_frame
 verify.call(not nw.fix_at(aim(nw,far)) and nw.active.has(far),"Clicking is not locked right after a miss")
 nw.miss_lock=0.
 verify.call(nw.fix_at(aim(nw,far)) and not nw.active.has(far),"The change cannot be fixed once the lock is over")
 nw.close_fullscreen()

 # Status lines: one, two, three unfound changes.
 var lines_ok:=true
 var picks:=[["kino","sitze","floating"],["halle","auto","missing"],["baellebad","krokodil","balls"]]
 nw._tick_screens(.016)
 if (nw.banner_labels[0] as Label3D).text!="":lines_ok=false
 for i in range(3):
  nw.force(picks[i][0],picks[i][1],picks[i][2]);nw.seconds=0.;nw._tick_screens(.016)
  if nw.status()!=i+1 or (nw.banner_labels[0] as Label3D).text!=NightwatchConfig.STATUS[i+1]:lines_ok=false
 verify.call(lines_ok and nw.banner_labels.size()==NightwatchConfig.CAMERAS.size()+1,"The status line on the cameras does not follow the open changes")
 # Three open: the critical alarm runs and gets faster; fixing one stops it.
 verify.call(nw.critical(),"Three open changes do not start the critical alarm")
 for i in range(20):nw._tick_critical(.25)
 var early:=nw.alarm_clock_step(nw.critical_clock/NightwatchConfig.CRITICAL_TIME)
 verify.call(nw.critical_clock>4. and nw.siren.playing,"The critical alarm does not sound")
 for i in range(40):nw._tick_critical(.25)
 verify.call(nw.alarm_clock_step(nw.critical_clock/NightwatchConfig.CRITICAL_TIME)<early,"The critical alarm does not get faster")
 nw.critical_clock=NightwatchConfig.CRITICAL_TIME-1.;nw._tick_screens(.016)
 verify.call(nw.critical_flicker(),"The lights do not flicker before the threshold")
 nw.fix(nw.active[0]);var held:=nw.critical_clock;nw._tick_critical(.5)
 verify.call(not nw.critical() and nw.critical_clock<held and nw.beacon.light_energy==0.,"Fixing a change does not stop the alarm")
 # One left too long is enough for the alarm too.
 nw._clear_anomalies()
 var old:=nw.force("halle","auto","missing");old.left=0.
 verify.call(nw.critical() and nw.status()==3,"A change left too long does not start the alarm")
 nw.critical_clock=NightwatchConfig.CRITICAL_TIME-.05;nw.tick(.1)
 verify.call(nw.over and nw.reason=="missed","The critical alarm running out does not end the night")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",10.) and game.menu.find_child("NightwatchSummary",true,false)!=null,"No result screen after the threshold")
 verify.call(str(nw.results().title)=="ANOMALY THRESHOLD EXCEEDED" and not bool(nw.results().won),"The result does not name the threshold")
 verify.call(NightwatchAnomalies.resolve(game.world,"prop:car").visible,"A missed change stays in the world")
 game.set_process(false)

 # Power: always draining; shutter 20 %, torch 10 %; too little and they fail.
 nw.start(1,43);game.phase="nightwatch"
 var p0:=nw.power;nw.tick(2.)
 verify.call(nw.power<p0,"Power does not drain on its own")
 p0=nw.power;verify.call(nw.toggle_shutter() and is_equal_approx(nw.power,p0-NightwatchConfig.SHUTTER_COST) and nw.stalker.closed,"Closing the shutter does not cost 20 %")
 nw.toggle_shutter();nw.power=15.
 verify.call(not nw.toggle_shutter() and not nw.stalker.closed and is_equal_approx(nw.power,15.),"The shutter closes without enough power")
 nw.power=60.;verify.call(nw.toggle_torch() and is_equal_approx(nw.power,50.) and nw.torch_time>0.,"The torch does not cost 10 %")
 nw.toggle_torch();nw.power=5.
 verify.call(not nw.toggle_torch() and nw.torch_time==0.,"The torch lights without enough power")
 nw.power=60.;nw.tick(.1)
 verify.call(not nw.alarm_active() and nw.instability()==0.,"Power warning plays above 50 %")
 nw.power=19.;nw.tick(.1)
 verify.call(nw.alarm_active() and nw.instability()>.12,"No power alarm at 19 %")

 # Generator: type the words, the power is full again.
 nw.power=12.
 verify.call(nw.start_qte(),"The generator does not start")
 nw.type_key("#");verify.call(nw.qte.typed==0,"A wrong key counts as typed")
 for word in nw.qte.words.duplicate():
  for letter in str(word):nw.type_key(letter)
 verify.call(nw.qte.is_empty() and is_equal_approx(nw.power,100.) and nw.repairs==1,"A finished repair does not refill the power")
 nw.power=30.;nw.start_qte();nw.tick(float(nw.qte.time)+.5)
 verify.call(nw.qte.is_empty() and nw.failed_repairs==1 and nw.power<30. and nw.running,"A failed repair refills power or ends the night")

 # Blackout: everything dark, the shutter goes up; the generator still saves you.
 nw.toggle_shutter();nw.power=.01;nw.tick(.1)
 verify.call(nw.blackout and nw.running and not nw.stalker.closed and float(nw.lights[0][1])>0. and (nw.lights[0][0] as Light3D).light_energy==0.,"Empty power does not black out the room")
 verify.call(not nw.toggle_shutter() and not nw.toggle_torch(),"Shutter or torch still work in the dark")
 nw.start_qte()
 for word in nw.qte.words.duplicate():
  for letter in str(word):nw.type_key(letter)
 verify.call(not nw.blackout and is_equal_approx(nw.power,100.),"The generator does not end the blackout")
 nw.power=.01;nw.tick(.1);nw.blackout_clock=nw.blackout_wait-.05;nw.tick(.1)
 verify.call(nw.over and nw.reason=="power","Waiting in the dark does not end the night")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",10.),"No result screen after the blackout")
 game.set_process(false)

 # 06:00: the night is survived and the next one opens.
 nw.start(1,44);game.phase="nightwatch"
 nw.seconds=NightwatchConfig.night_length()-.05;nw.tick(.1)
 verify.call(nw.over and nw.won and nw.reason=="survived" and nw.clock_string()=="06:00","06:00 does not end the night as survived")
 verify.call(game.achievements.nightwatch_night==1 and game.achievements.best_round==endless_best,"Surviving night 1 does not open night 2 or touched the endless record")
 var stored: Variant=JSON.parse_string(game._persistent_text(game.achievements.path))
 verify.call(stored is Dictionary and int(stored.get("nightwatch_night",0))==1,"The night progress is not saved")
 game.set_process(true)
 verify.call(await wait_phase(game,"nightwatch_over",10.) and str(nw.results().title).contains("1"),"No result screen after 06:00")
 var again:=game.menu.find_child("NightwatchAgain",true,false) as Button
 verify.call(again!=null and again.text.contains("2"),"The result screen does not offer night 2")
 NightMenus.nightwatch(game)
 n2=game.menu.find_child("NightwatchNight2",true,false) as Button
 verify.call(n2!=null and not n2.disabled,"Night 2 stays locked after night 1")
 game.set_process(false)

 # Leaving undoes everything; the normal game is untouched.
 nw.start(2,45);game.phase="nightwatch";game.set_process(true)
 for i in range(6):await game.get_tree().process_frame
 nw.force("kino","sitze","floating");nw.force("baellebad","krokodil","balls");nw.force("party","tisch","room")
 for i in range(10):await game.get_tree().process_frame
 game._main_menu();await game.get_tree().process_frame
 verify.call(not nw.running and not nw.visible and game.menu_camera.current and nw.active.is_empty(),"Leaving Nightwatch keeps it running")
 verify.call(game.world.find_children("Nightwatch*","",true,false).filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"Nightwatch changes stay in the world after leaving")
 verify.call(game.world.find_child("WatchCrawler",true,false)==null,"A figure still walks the camera world")
 game.achievements.nightwatch_night=saved_night
 DirAccess.remove_absolute(game.achievements.path)
