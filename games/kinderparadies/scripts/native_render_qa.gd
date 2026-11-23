extends RefCounted

func run(game: Node3D) -> void:
 var output:=OS.get_environment("TEMP").path_join("NachtwacheNativeQA")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 game.settings.quality=2;game.settings.volume=0;game._apply_settings()
 if "--mp-qa" in OS.get_cmdline_user_args():
  game._main_menu();NightMenus.multiplayer(game)
  for i in range(600):
   await game.get_tree().process_frame
   if game.mp.status!="connecting":break
  await capture(game,output,"mp-00-code")
  var f:=FileAccess.open(output.path_join("mp-code.txt"),FileAccess.WRITE);f.store_string(game.mp.code);f.close()
  print("MPQA code ",game.mp.code," status ",game.mp.status)
  var waited:=0.
  while game.mp.status!="playing" and waited<60.:
   await game.get_tree().create_timer(.25).timeout;waited+=.25
  print("MPQA plan ",game.mp.plan," phase ",game.phase)
  while game.world_loading or game.phase=="loading":await game.get_tree().process_frame
  game.intro.skip();game.player.active=false
  print("MPQA current ",game.state.current," plan0 ",game.state.plan[0] if game.state.plan.size() else "")
  await game.get_tree().create_timer(4.).timeout
  await capture(game,output,"mp-01-playing")
  var plan_map:=MultiplayerLink.outline(game.world);print("MPQA map walls ",plan_map.walls.size()," bounds ",plan_map.bounds," sent ",game.mp.map_sent)
  game.get_tree().quit();return
 if "--rosenyan-qa" in OS.get_cmdline_user_args():
  game._build_world("none");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  for id in ["rosenyan","einsmarello","hissybusa","jule","theraidenlena"]:
   var plush: Node3D=game.world.atmosphere.find_child(CreatorPlush.PLUSHES[id].node,true,false)
   var at: Vector3=plush.global_position;var front: Vector3=plush.global_basis.z
   for shot in [[front*1.15,id+"-00-front"],[front.rotated(Vector3.UP,.7)*1.6,id+"-01-corner"],[front*2.6+Vector3(1.2,0,0),id+"-02-room"]]:
    game.player.global_position=at+shot[0]+Vector3(0,-.225,0);game.player.lamp.show()
    game.player.look_at(Vector3(at.x,game.player.global_position.y,at.z));game.player.camera.look_at(at,Vector3.UP)
    await capture(game,output,shot[1])
  game.get_tree().quit();return
 if "--plush-ending-qa" in OS.get_cmdline_user_args():
  # 4.10.0 secret ending: the seated plushes, the shine returning, the children.
  game._new_shift();game.intro.skip();game._build_world("none");game._resume()
  game.plushes_found.assign(CreatorPlush.PLUSHES.keys());game.plush_call="answered";game.plush_ending.open_chairs()
  game.player.global_position=Vector3(7.6,0,-7.0);game.player.look_at(Vector3(10.2,game.player.global_position.y,-7.),Vector3.UP);game.player.camera.look_at(Vector3(10.2,.7,-7.),Vector3.UP)
  for i in range(5):game.plush_ending.seat(i,game.plushes_found)
  await capture(game,output,"secret-00-table")
  game._start_plush_finale()
  var ending: SecretPlushEnding=game.plush_ending
  for shot in [[2.5,"secret-01-rise"],[8.,"secret-02-dark-venue"],[16.,"secret-03-half-shine"],[28.5,"secret-04-all-shine"],[33.,"secret-05-door"],[38.,"secret-06-children"],[46.,"secret-07-playing"],[55.5,"secret-08-fade"]]:
   while ending.clock<shot[0] and not ending.done:await game.get_tree().process_frame
   await capture(game,output,shot[1])
  var close:=Camera3D.new();game.world.add_child(close);close.global_position=Vector3(2.,3.2,12.5);close.look_at(Vector3(2.,.6,7.),Vector3.UP);close.make_current()
  await capture(game,output,"secret-09-pit-close")
  close.global_position=Vector3(13.,2.2,-2.5);close.look_at(Vector3(10.2,.7,-7.),Vector3.UP)
  await capture(game,output,"secret-10-table-close")
  game.get_tree().quit();return
 if "--nets-qa" in OS.get_cmdline_user_args():
  game._build_world("none");var w: PlayWorld=game.world
  print("NETS knotted=",w.find_children("KnottedSafetyNet","MeshInstance3D",true,false).size()," panels=",w.get_tree().get_nodes_in_group("safety_nets").size())
  var tower:=w.find_child("EastTower",true,false)
  for c in tower.get_children():print("TOWERCHILD ",c.name," ",c.get_class()," kids=",c.get_child_count())
  for g: GeometryInstance3D in w.find_children("*","GeometryInstance3D",true,false):
   var box: AABB=g.global_transform*g.get_aabb()
   if box.size.x*box.size.y*box.size.z<2. and (box.size.x<.08 or box.size.z<.08) and box.size.y>3. and (box.size.x>3. or box.size.z>3.):print("THIN ",g.get_path()," ",g.get_class()," ",box)
  # Snackbar close-up sight line (center 10.535,1.656,-0.0725; camera offset as in closeup-qa).
  var c:=Vector3(10.535,1.656,-.0725);var r:=maxf(1.2,Vector3(7.11,3.28,3.085).length()*.55);var eye:=c+Vector3(r*.55,r*.45,r*.8)
  for g: GeometryInstance3D in w.find_children("*","GeometryInstance3D",true,false):
   if not g.is_visible_in_tree():continue
   var box: AABB=g.global_transform*g.get_aabb()
   var hit=box.intersects_segment(eye,eye+(c-eye)*.6)
   if hit!=null:print("SIGHT ",snappedf(eye.distance_to(hit),.01)," ",g.get_path()," ",g.get_class()," ",(g as MeshInstance3D).mesh.get_class() if g is MeshInstance3D else "")
  game.get_tree().quit();return
 if "--materials-qa" in OS.get_cmdline_user_args():
  game._build_world("none");var w: PlayWorld=game.world
  var seen:={}
  for root in [w.props.structure,w.find_child("EastTower",true,false),w.props.pit,w.find_child("ConnectingBridge",true,false)]:
   for m: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
    if not m.visible or not m.mesh:continue
    var mat:=m.get_active_material(0)
    if not mat or seen.has(mat):continue
    seen[mat]=true
    var info:=str(mat.get_class())+" "+str(mat.resource_name)
    if mat is StandardMaterial3D:info+=" albedo="+str(mat.albedo_color.to_html())+" tex="+str(mat.albedo_texture.resource_path if mat.albedo_texture else "-")+" normal="+str(mat.normal_texture.resource_path if mat.normal_texture else "-")+" rough="+str(mat.roughness)
    elif mat is ShaderMaterial:info+=" shader="+str(mat.shader.resource_path)
    var uses:=0
    print("MAT ",root.name," ",m.name," mesh=",m.mesh.get_class()," ",info)
  for id in ["blue","red","gold","teal","stitch","cream"]:print("WMAT ",id," ",w.materials[id] if w.materials.has(id) else "none")
  game.get_tree().quit();return
 if "--closeup-qa" in OS.get_cmdline_user_args():
  # Close looks at the hero props, framed from their bounding boxes.
  game._build_world("none");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var w: PlayWorld=game.world
  var targets:={"chairs":w.props.chairs,"stereo":w.find_child("OldHappylandStereo",true,false),"snackbar":w.find_child("ClosedHappylandSnackBar",true,false),"stage":w.find_child("BirthdayStage",true,false),"easttower":w.find_child("EastTower",true,false),"structure":w.props.structure,"arcade":w.find_child("ArcadeLounge",true,false),"photobooth":w.find_child("AbandonedPhotoBooth",true,false),"emptychairs":w.find_child("TheFourEmptyChairs",true,false),"bridge":w.find_child("ConnectingBridge",true,false),"pit":w.props.pit,"mats":w.finish.get_node("FoamPuzzleMats")}
  var cam:=Camera3D.new();w.add_child(cam);cam.fov=60;cam.make_current()
  w.environment.environment.ambient_light_energy=.5
  var flood:=OmniLight3D.new();w.add_child(flood);flood.omni_range=14;flood.light_energy=1.6;flood.light_color=Color("fff4e6")
  for key in targets:
   var node: Node3D=targets[key]
   if not node:print("CLOSEUP missing ",key);continue
   var box:=AABB();var first:=true
   for m: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false)+([node] if node is MeshInstance3D else []):
    if not m.is_visible_in_tree():continue
    var b2:=m.global_transform*m.get_aabb();box=b2 if first else box.merge(b2);first=false
   var c:=box.get_center();var r:=maxf(1.2,box.size.length()*.55)
   if key=="mats":c=Vector3(8.,0,13.5);r=2.6
   cam.global_position=c+Vector3(r*.55,r*.45,r*.8);cam.look_at(c,Vector3.UP);flood.global_position=cam.global_position+Vector3(0,1,0)
   print("CLOSEUP ",key," center ",c," size ",box.size)
   await capture(game,output,"closeup-"+key)
  game.get_tree().quit();return
 if "--inventory-qa" in OS.get_cmdline_user_args():
  # Which visible things in the hall and party room are still primitives?
  game._build_world("none");var w: PlayWorld=game.world
  var groups:={}
  for m: MeshInstance3D in w.find_children("*","MeshInstance3D",true,false):
   if not w.shown(m) or not m.mesh:continue
   var box:=m.global_transform*m.get_aabb();var c:=box.get_center()
   if c.x< -10.3 or c.x>20 or c.z< -19 or c.z>17.5:continue
   var path:=str(m.mesh.resource_path)
   var kind:="glb" if path.contains(".glb") or path.contains(".gltf") else "prim"
   # Group by the first node under the world (module or prop group) plus one level.
   var node: Node=m;var chain: Array[String]=[]
   while node and node.get_parent()!=w:chain.push_front(str(node.name));node=node.get_parent()
   if node:chain.push_front(str(node.name))
   var key:=" / ".join(chain.slice(0,2))+" ["+kind+"]"
   var g: Dictionary=groups.get(key,{"n":0,"area":0.})
   g.n+=1;g.area+=box.size.x*box.size.y+box.size.y*box.size.z+box.size.x*box.size.z;groups[key]=g
  var rows: Array=groups.keys();rows.sort_custom(func(a,b):return groups[a].area>groups[b].area)
  for k in rows.slice(0,70):print("INV ",snappedf(groups[k].area,.1)," m2  ",groups[k].n,"  ",k)
  game.get_tree().quit();return
 if "--heroprops-qa" in OS.get_cmdline_user_args():
  # Hero props from where the guard actually stands.
  game._build_world("none");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false);game.notice_time=0;game.notice.hide()
  for i in range(20):await game.get_tree().process_frame
  for shot in [["craft-corner",Vector3(12.,0,-1.6),Vector3(13.7,.45,-3.8)],["kitchen-hood",Vector3(-10.9,0,-28.6),Vector3(-13.4,2.3,-31.3)],["floor-a",Vector3(6.,0,15.),Vector3(10.,0,9.5)],["floor-b",Vector3(-3.,0,13.5),Vector3(4.,0,11.)],["snackbar",Vector3(10.5,0,-4.2),Vector3(10.5,1.2,0)],["snack-front",Vector3(11.4,0,-1.3),Vector3(11.8,.9,.7)],["snack-slush",Vector3(12.75,0,-.45),Vector3(12.8,1.3,.76)],["arcade",Vector3(8.4,0,11.6),Vector3(8.4,1.3,15.6)],["arcade-close",Vector3(6.9,0,14.6),Vector3(6.6,1.2,16.4)],["arcade-prizes",Vector3(9.5,0,15.2),Vector3(9.5,1.25,16.5)],["photobooth",Vector3(10.9,0,14.4),Vector3(13.,1.2,16.)],["annex-seats",Vector3(2.6,0,-29.6),Vector3(-1.3,.7,-29.8)],["annex-seat-close",Vector3(1.3,0,-27.6),Vector3(.2,.6,-28.6)],["annex-popcorn",Vector3(1.5,0,-28.1),Vector3(2.05,1.0,-26.35)],["annex-basins",Vector3(23.1,0,7.6),Vector3(23.1,.85,5.4)],["annex-cubicles",Vector3(21.,0,7.4),Vector3(24.2,1.,9.4)],["annex-toilet",Vector3(23.4,0,8.0),Vector3(23.5,.45,9.7)],["photobooth-front",Vector3(12.6,0,14.35),Vector3(12.8,1.25,16.25)],["photobooth-changer",Vector3(10.6,0,15.0),Vector3(11.2,1.0,16.38)],["bunting",Vector3(9.,0,-4.),Vector3(13,2.6,-11)],["costume-rack",Vector3(15.,0,-14.2),Vector3(14.6,1.4,-18.)],["costume-close",Vector3(14.9,0,-16.3),Vector3(14.7,1.3,-18.)],["costume-side",Vector3(14.5,0,-15.2),Vector3(11.9,1.3,-15.)],["costume-vanity",Vector3(16.6,0,-15.),Vector3(19.2,1.2,-15.)],["costume-bench",Vector3(14.6,0,-14.6),Vector3(13.5,.9,-13.2)]]:
   var only:=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--only="))
   if only.size() and not shot[0].begins_with(only[0].substr(7)):continue
   game.player.position=shot[1];game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(shot[2])
   for i in range(30):await game.get_tree().process_frame
   await capture(game,output,"props-"+shot[0])
  game.get_tree().quit();return
 if "--details-qa" in OS.get_cmdline_user_args():
  # 4.12.0 night details: the children's trail, the cold kitchen breath.
  for id in [NightDetails.FOOTPRINT_ID,NightDetails.BREATH_ID]:
   game._new_shift();game.intro.skip();game.state.current=id;game._build_world(id);game._resume()
   game.player.active=false;game.player.set_physics_process(false);game.notice_time=0;game.notice.hide();game.set_process(false)
   var helper:=OmniLight3D.new();game.world.add_child(helper);helper.light_energy=1.2;helper.omni_range=7
   if id==NightDetails.FOOTPRINT_ID:
    game.player.position=Vector3(2.6,0,7.6);helper.global_position=Vector3(4.6,2.2,12.)
    game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(Vector3(4.7,0,12.4))
   else:
    var k:=NightDetails.KITCHEN.get_center();game.player.position=Vector3(k.x+1.5,0,k.y+2.);helper.global_position=Vector3(k.x,2.,k.y);helper.light_energy=.5
    game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(Vector3(k.x-2.,1.4,k.y-3.))
   for i in range(25):await game.get_tree().process_frame
   if id==NightDetails.BREATH_ID:
    game.world.night.breath_clock=0.;game.world.night._breathe(.1,game.player)
    for i in range(14):await game.get_tree().process_frame
   await capture(game,output,"details-"+id)
  game.get_tree().quit();return
 if "--storm-qa" in OS.get_cmdline_user_args():
  # Lightning through the parking window, in normal light and in a power cut.
  for blackout in [false,true]:
   game._new_shift();game.intro.skip();game.state.current=PowerBlackout.ID if blackout else "none";game._build_world(game.state.current);game._resume()
   game.player.active=false;game.player.set_physics_process(false);game.notice_time=0;game.notice.hide();game.set_process(false)
   if blackout:
    game.world.blackout.set_process(false)
    for i in range(int((PowerBlackout.WAIT+PowerBlackout.FLICKER+.3)*30)):game.world.blackout.step(1./30,true,game.player)
   game.player.position=Vector3(-3.5,0,4.5);game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(Vector3(-9.5,1.6,2.2))
   for i in range(25):await game.get_tree().process_frame
   var tag:="blackout-" if blackout else ""
   await capture(game,output,"storm-"+tag+"0-before")
   game.world.storm.flash(1.)
   if blackout:game.world.blackout.step(1./60,true,game.player)
   await capture(game,output,"storm-"+tag+"1-flash")
  game.get_tree().quit();return
 if "--history-qa" in OS.get_cmdline_user_args():
  # The same five camera points as the first Nachtwache build, same 3:2 frame.
  var shots:=[["eingang",Vector3(-7,0,9.5),Vector3(2,1.4,0)],["empfang",Vector3(-5,0,6.5),Vector3(-8.5,1,7.8)],["baellebad",Vector3(-1,0,10),Vector3(3,.5,5)],["halle",Vector3(8,0,9),Vector3(-3,2,-6)],["wartung",Vector3(-4,0,-4),Vector3(-8,1.4,-8)]]
  game.get_window().mode=Window.MODE_WINDOWED;game.get_window().size=Vector2i(1920,1080)
  game._new_shift();game.intro.skip();game._resume();game.player.active=false;game.player.set_physics_process(false);game.notice_time=0;game.notice.hide()
  for i in range(30):await game.get_tree().process_frame
  for shot in shots:
   game.player.position=shot[1];game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0);game.player.camera.look_at(shot[2])
   for i in range(40):await game.get_tree().process_frame
   await RenderingServer.frame_post_draw
   game.get_viewport().get_texture().get_image().save_png(output.path_join("now-"+shot[0]+".png"))
  game.get_tree().quit();return
 if "--coords-qa" in OS.get_cmdline_user_args():
  game._build_world("none");var w: PlayWorld=game.world
  for c in w.props.chairs.get_children():print("CHAIR ",c.global_position," rot ",c.global_rotation)
  print("TABLE ",w.props.party_table.global_position)
  var phone:=w.find_child("ReceptionDeskPhone",true,false) as Node3D;print("PHONE ",phone.global_position if phone else null)
  print("LEAF ",w.backstage.exit_leaf.global_position," ROOT ",w.backstage.exit_root.global_position)
  for s in [0.,2.,4.,6.,8.,10.,12.,14.,CrawlTubes.LENGTH]:print("TUBE ",s," ",CrawlTubes.route(s))
  var pit:=AABB(w.pit_physics.starts[0],Vector3.ZERO)
  for b in w.pit_physics.starts:pit=pit.expand(b)
  print("PIT ",pit)
  for z in w.zones:print("ZONE ",z," ",w.zones[z])
  print("SLIDE ",w.props.slide.global_position," STRUCT ",w.props.structure.global_position)
  var names:={}
  for d in w.find_children("*","Decal",true,false):names[str(d.name)]=names.get(str(d.name),0)+1
  print("DECALS ",names)
  var flats:={}
  for m: GeometryInstance3D in w.find_children("*","GeometryInstance3D",true,false):
   var box:=m.global_transform*m.get_aabb()
   if box.position.y<.1 and box.size.y<.06 and box.position.x> -10 and box.position.x<20 and box.position.z> -12 and box.position.z<17:
    var key:=str(m.get_parent().name)+"/"+str(m.name);flats[key]=flats.get(key,0)+1
  print("FLATS ",flats)
  game.get_tree().quit();return
 if "--topdown-qa" in OS.get_cmdline_user_args():
  # Dollhouse view for the secret ending: ceiling slabs lifted off the venue.
  game._build_world("none");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var hidden:=SecretPlushEnding.lift_ceilings(game.world)
  print("TOPDOWN hidden ceilings ",hidden.size())
  var cam:=Camera3D.new();game.world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=62;cam.far=200
  cam.global_position=Vector3(1,60,-8);cam.rotation=Vector3(-PI/2,0,0);cam.make_current()
  game.world.environment.environment.ambient_light_energy=1.2;game.world.environment.environment.fog_enabled=false;game.world.environment.environment.volumetric_fog_enabled=false
  await capture(game,output,"topdown-00-plan")
  cam.projection=Camera3D.PROJECTION_PERSPECTIVE;cam.fov=55;cam.global_position=Vector3(1,34,22);cam.look_at(Vector3(1,0,-6),Vector3.UP)
  await capture(game,output,"topdown-01-dollhouse")
  game.get_tree().quit();return
 if "--breaker-qa" in OS.get_cmdline_user_args():
  # 4.9.2: the main breaker sits clear of the workbench, seen from the room.
  game._build_world("none");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var lever: Vector3=PowerBlackout.CABINET+PowerBlackout.LEVER_OFFSET+Vector3(0,.95,.05)
  for shot in [[Vector3(.55,0,1.35),"breaker-00-approach"],[Vector3(0,0,.95),"breaker-01-front"]]:
   game.player.global_position=Vector3(lever.x,0,lever.z)+shot[0];game.player.lamp.show()
   game.player.look_at(Vector3(lever.x,game.player.global_position.y,lever.z));game.player.camera.look_at(lever,Vector3.UP)
   await capture(game,output,shot[1])
  game.get_tree().quit();return
 if "--load-qa" in OS.get_cmdline_user_args():
  await load("res://scripts/load_benchmark.gd").new().run(game,output)
  game.get_tree().quit();return
 if "--occlusion-qa" in OS.get_cmdline_user_args():
  await load("res://scripts/occlusion_qa.gd").new().run(game,output)
  game.get_tree().quit();return
 if "--perf-qa" in OS.get_cmdline_user_args():
  await load("res://scripts/perf_benchmark.gd").new().run(game,output)
  game.get_tree().quit();return
 if "--pit-hands-qa" in OS.get_cmdline_user_args():
  game._build_world("pit_hands");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var t: NightTerrors=game.world.terrors
  for view in [[Vector3(2.4,.03,10.2),"a"],[Vector3(5.6,.03,9.4),"b"],[Vector3(3.3,.03,9.25),"c"]]:
   game._build_world("pit_hands");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false);t=game.world.terrors;game.world.pit_physics.configure();game.world.pit_physics.tick(true,game.player)
   game.player.global_position=view[0];game.player.lamp.show()
   var look: Vector3=t.origin+Vector3(0,.5,0)
   game.player.look_at(Vector3(look.x,game.player.global_position.y,look.z));game.player.camera.look_at(look,Vector3.UP)
   t.tick(0,true,game.player);await capture(game,output,"pit-"+view[1]+"-00-idle")
   for c in t.marker.get_children():
    if c is MeshInstance3D and c.name.begins_with("BoneClue"):
     print("PITCLUE ",c.name," ",c.global_position," top=",c.global_position.y+c.get_aabb().end.y," v=",c.is_visible_in_tree()," surface=",t._pit_surface(c.global_position))
     if view[1]=="a":
      game.player.global_position=c.global_position+Vector3(.3,0,1.3);game.player.global_position.y=.03;game.player.camera.look_at(c.global_position+Vector3(0,c.get_aabb().end.y-.2,0),Vector3.UP);await capture(game,output,"pit-clue-"+str(c.name))
   game.player.global_position=view[0];game.player.camera.look_at(look,Vector3.UP)
   print("PITBALLS frozen=",game.world.pit_physics.bodies.filter(func(b):return b.freeze).size()," running=",game.world.pit_physics.running)
   t.triggered=true;t.attack=0.
   var at:=0.
   for frame in [.06,.14,.3,.6,1.0,1.6,2.4,3.4]:
    while at<frame:
     t.tick(1./60.,true,game.player);await game.get_tree().physics_frame;at+=1./60.
    await capture(game,output,"pit-%s-%02d-%03d"%[view[1],int(frame*10),int(frame*100)])
    var fast:=0.;for b in game.world.pit_physics.bodies: fast=maxf(fast,b.linear_velocity.length())
    print("PITVEL ",frame," ",fast)
   print("PITQA ",view[1]," ",JSON.stringify(t.snapshot()))
  game.get_tree().quit();return
 if "--wc-qa" in OS.get_cmdline_user_args():
  game._build_world("wc_ceiling_guest");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var t: NightTerrors=game.world.terrors
  game.player.global_position=Vector3(22.4,.03,7.1);game.player.lamp.show()
  game.player.look_at(Vector3(24.0,game.player.global_position.y,7.15));game.player.camera.rotation=Vector3(.12,0,0)
  t.tick(0,true,game.player);await capture(game,output,"wc-00-hanging")
  t.triggered=true;t.attack=0.
  for i in range(12):t.tick(1./60.,true,game.player)
  await capture(game,output,"wc-01-swing")
  game.get_tree().quit();return
 if "--tube-qa" in OS.get_cmdline_user_args():
  game._build_world("tube_burst");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var t: NightTerrors=game.world.terrors
  game.player.global_position=CrawlTubes.route(7.2)+Vector3(0,-.72,0);game.player.lamp.show();game.player.set_crouch(true);game.player.camera.position.y=.8
  var ahead:=CrawlTubes.route(9.8);game.player.look_at(Vector3(ahead.x,game.player.global_position.y,ahead.z));game.player.camera.rotation=Vector3.ZERO
  t.tick(0,true,game.player);await capture(game,output,"tube-00-start")
  t.triggered=true;t.attack=0.
  while t.lunge_at<0 and t.attack<4.:t.tick(1./60.,true,game.player)
  print("TUBEQA attack=",t.attack," lunge=",t.lunge_at," in_tube=",game.world.tubes.contains_original(game.player.position)," finished=",t.finished," arms=",t.arms.size()," vis=",t.visual.rotation)
  await capture(game,output,"tube-01-approach")
  for i in range(9):t.tick(1./60.,true,game.player)
  print("TUBEQA2 attack=",t.attack," lunge=",t.lunge_at," finished=",t.finished," vis=",t.visual.rotation," arm=",t.arms[0].rotation if t.arms.size() else Vector3.ZERO)
  await capture(game,output,"tube-02-face")
  game.get_tree().quit();return
 if "--v433-qa" in OS.get_cmdline_user_args():
  game._build_world("screen_visitor");game._resume();game.player.active=false;game.player.set_physics_process(false);game.set_process(false)
  var t: NightTerrors=game.world.terrors
  var from: Vector3=t.actor.global_position
  game.player.global_position=from+Vector3(0,0,2.4);game.player.rotation=Vector3.ZERO;game.player.camera.rotation=Vector3.ZERO;game.player.lamp.show()
  game.player.look_at(Vector3(from.x,game.player.global_position.y,from.z))
  await capture(game,output,"v433-00-visitor-standing")
  t.triggered=true;t.attack=0.
  for i in range(14):t.tick(1./60.,true,game.player)
  await capture(game,output,"v433-01-visitor-closing")
  for i in range(12):t.tick(1./60.,true,game.player)
  await capture(game,output,"v433-02-visitor-face")
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(9.6,0,15.2),Vector3(12.3,1.6,12.6));await capture(game,output,"v433-03-croc-mouth")
  author.pose(game,Vector3(10.6,0,14.0),Vector3(12.0,1.8,12.6));await capture(game,output,"v433-04-croc-teeth")
  game.get_tree().quit();return
 if "--v431-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.tick(1.5);game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  await capture(game,output,"v431-00-phone")
  game.intro.tick(2.);await capture(game,output,"v431-01-phone-raised")
  game.intro.skip();game.dialogue.reset();game.notice.hide()
  var author=load("res://art-direction/itch_capture.gd").new()
  game.player.lamp.show()
  if "--corpse-only" in OS.get_cmdline_user_args():
   for view in [["v431-06-corpse",Vector3(-13.05,0,-10.1),Vector3(-13.05,.6,-8.0)],["v431-07-corpse-close",Vector3(-12.4,0,-9.0),Vector3(-13.0,.75,-8.0)]]:
    author.pose(game,view[1],view[2]);await capture(game,output,view[0])
   game.get_tree().quit();return
  for view in [["v431-02-lost-property",Vector3(2.2,0,-10.25),Vector3(2.2,.65,-11.7)],["v431-03-lost-close",Vector3(2.0,0,-10.9),Vector3(2.0,.45,-11.7)],
               ["v431-04-doorframe",Vector3(-7.9,0,-9.6),Vector3(-7.9,1.5,-12.2)],["v431-05-balls",Vector3(1.0,0,12.6),Vector3(1.0,.15,9.6)],
               ["v431-06-corpse",Vector3(-13.05,0,-10.1),Vector3(-13.05,.6,-8.0)],["v431-07-corpse-close",Vector3(-12.4,0,-9.0),Vector3(-13.0,.75,-8.0)]]:
   author.pose(game,view[1],view[2]);await capture(game,output,view[0])
  game.get_tree().quit();return
 if "--drive-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.player.active=false;game.player.set_physics_process(false)
  game.secret_ending=true;game._show_ending(3);game.set_process(false)
  var credits: EndCredits=game.end_credits
  credits.tick(credits.title_length()-.01);credits.tick(.02)
  for shot in [[2.6,"01-road"],[4.35,"02-shout"],[5.6,"03-shout-late"],[7.75,"04-letters-fall"],[9.0,"05-drive"],[10.5,"06-look-up"],[11.33,"07-mirror-flash"],[12.1,"08-mirror-stare"],[12.47,"09-lunge"],[12.7,"10-face"]]:
   while credits.drive.clock<float(shot[0]):credits.tick(minf(.033,float(shot[0])-credits.drive.clock+.0001))
   await capture(game,output,"drive-"+str(shot[1]))
   if shot[1]=="07-mirror-flash":credits.drive.mirror_view.get_texture().get_image().save_png(output.path_join("drive-07b-mirror-texture.png"))
  game.get_tree().quit();return
 if "--quality-v410-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.tick(1.5);game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  await capture(game,output,"00-phone-hand")
  game.intro.skip();game.dialogue.reset();game.notice.hide()
  var author=load("res://art-direction/itch_capture.gd").new()
  var views=[
   ["01-reception",Vector3(-7.0,0,8.65),Vector3(-8.2,1.03,7.3)],
   ["02-plates-chairs",Vector3(11.45,0,-5.8),Vector3(10.2,.82,-7.)],
   ["03-rabbit",Vector3(15.2,0,-4.7),Vector3(17.9,2.25,.38)],
   ["04-clown",Vector3(-12.4,0,-31.25),Vector3(-14.4,1.8,-31.25)],
   ["05-kitchen",Vector3(-11.6,0,-29.2),Vector3(-13.7,1.9,-31.2)],
   ["06-hall",Vector3(-3.5,0,8.8),Vector3(4,2.5,0)],
   ["07-cinema",Vector3(-3.55,0,-30.9),Vector3(3.3,1.7,-29.7)],
   ["08-horse",game.world.room_horror.creature.mask.global_position-game.world.room_horror.creature.mask.global_basis.z*2.-Vector3.UP*1.65,game.world.room_horror.creature.mask.global_position]]
  var samples: Dictionary={}
  for view in views:
   author.pose(game,view[1],view[2]);game.player.torch_body.tick(1.,true,0.,game.player)
   for frame in range(24):await game.get_tree().process_frame
   var times: Array[float]=[]
   for frame in range(90):
    var started:=Time.get_ticks_usec();await game.get_tree().process_frame;times.append((Time.get_ticks_usec()-started)/1000.)
   times.sort()
   samples[view[0]]={"median_frame_ms":times[45],"p95_frame_ms":times[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
   await capture(game,output,view[0])
  var point: Vector3=game.world.mechanics.records.bell.contact.global_position
  author.pose(game,Vector3(point.x,0,8.56),point);game.player.hands.begin("mechanical:bell",point)
  game.player.hands.clock=game.player.hands.duration*.40;game.player.hands.pose()
  await capture(game,output,"09-bell-hand");game.player.hands.cancel()
  for kind in ["granny","passage"]:
   var head:=ScareSculpt.head(game.player.camera,kind,Vector3(0,-.02,-.75))
   await capture(game,output,"10-head-"+kind);head.free()
  var report:=FileAccess.open(output.path_join("quality-render.json"),FileAccess.WRITE);report.store_string(JSON.stringify(samples," "));report.close()
  game._quit();return
 if "--reception-v408-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false);game.dialogue.reset()
  game.notice.hide()
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-8.25,0,7.1),Vector3(-9.95,1.85,7.3))
  await capture(game,output,"01-noticeboard")
  for id in ["bell","gum","ticket"]:
   var point: Vector3=game.world.mechanics.records[id].contact.global_position
   var p:=Vector3(point.x,0,8.77) if id!="ticket" else Vector3(-5.3,0,point.z)
   author.pose(game,p,point);game.player.hands.begin("mechanical:"+id,point)
   for frame in [.12,.30,.55,.85]:
    game.player.hands.clock=game.player.hands.duration*frame;game.player.hands.pose()
    await capture(game,output,"02-%s-%02d"%[id,int(frame*100)])
   print("HAND PROBE ",id," position=",game.player.hands.position," scale=",game.player.hands.scale," sleeve=",game.player.hands.sleeve.get_aabb())
   game.player.hands.cancel()
   if id in ["bell","ticket"]:
    if id=="bell":p.z=8.56
    else:p.x-=.22
    author.pose(game,p,point);game.player.hands.begin("mechanical:"+id,point)
    game.player.hands.clock=game.player.hands.duration*.4;game.player.hands.pose()
    print("CLOSE CONTACT ",id,"=",game.player.hands.close_contact)
    await capture(game,output,"03-close-"+id);game.player.hands.cancel()
  game._quit();return
 if "--finish-v406-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game._build_world("none");game.set_process(false);game.player.active=false;game.dialogue.reset()
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-8.15,0,15.8),Vector3(-9.3,.76,15.3))
  await capture(game,output,"01-plant")
  author.pose(game,Vector3(2.05,0,-27.35),Vector3(2.05,1.06,-26.35))
  await capture(game,output,"02-popcorn")
  for index in range(2):
   game.world.passages.open(bool(index));game.world.passages.tick(2.,true,game.player,bool(index),false)
   var lift: PassageLift=game.world.passages.lanes[index].lift
   for i in range(2):lift.doors[i].position.x=(-1 if i==0 else 1)*.65
   author.pose(game,lift.cabin.to_global(Vector3(0,0,.55)),lift.cabin.to_global(Vector3(0,1.65,-1.4)))
   await capture(game,output,"03-return-cabin-%d"%index)
  var cabin: Node3D=game.intro.get_node("RestoredOriginalLiftCabin")
  for i in range(2):game.intro.doors[i].position.x=(-1 if i==0 else 1)*.65
  author.pose(game,cabin.to_global(Vector3(0,0,.55)),cabin.to_global(Vector3(0,1.65,-1.4)))
  await capture(game,output,"04-original-cabin")
  author.pose(game,Vector3(-11.6,0,-29.2),Vector3(-13.7,1.9,-31.2))
  for time in [1.,6.8,12.0]:
   game.world.annex.clock=time;game.world.annex.tick(.01,true);game.world.room_horror.clock=time;game.world.room_horror.tick(.01,true)
   await capture(game,output,"05-steady-kitchen-%d"%int(time))
  for frame in range(90):
   game.world.annex.tick(1./60.,true)
   await game.get_tree().process_frame
  await capture(game,output,"05b-warmed-kitchen")
  game.world.environment.environment.sdfgi_enabled=false
  for frame in range(30):await game.get_tree().process_frame
  await capture(game,output,"05c-kitchen-without-sdfgi")
  game.world.annex.get_node("PotFlies").hide()
  await capture(game,output,"06-kitchen-without-flies")
  game.world.environment.environment.ssil_enabled=false
  await capture(game,output,"07-kitchen-without-ssil")
  game.world.environment.environment.ssao_enabled=false
  await capture(game,output,"08-kitchen-without-ssao")
  game._quit();return
 if "--dialogue-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game._build_world("none");game.set_process(false);game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-7.,0,14.5),Vector3(-7.,1.45,8.))
  await game.get_tree().process_frame
  game.dialogue.reset();game.dialogue.request("arrival")
  for i in range(110):game.dialogue.tick(1./60.)
  await capture(game,output,"01-typed-comment")
  for i in range(150):game.dialogue.tick(1./60.)
  await capture(game,output,"02-falling-letters")
  for i in range(65):game.dialogue.tick(1./60.)
  game.player.camera.look_at(Vector3(-7.,.02,13.6))
  await capture(game,output,"03-letters-on-floor")
  game._quit();return
 if "--mechanics-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game._build_world("none");game.set_process(false);game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  for id in ["bell","gum","ticket"]:
   var r: Dictionary=game.world.mechanics.records[id]
   var point: Vector3=r.contact.global_position
   var p:=Vector3(point.x,0,8.77) if id!="ticket" else Vector3(-5.3,0,point.z)
   author.pose(game,p,point);game.player.torch_body.hide()
   await capture(game,output,"01-"+id)
   game.player.hands.begin("mechanical:"+id,point)
   game.player.hands.clock=game.player.hands.duration*.40;game.player.hands.pose()
   game.world.mechanics.interact("mechanical:"+id);game.world.mechanics.tick(.15,true);game.player.hands.pose()
   await capture(game,output,"02-"+id+"-interaction");game.player.hands.cancel()
  for time in [0.,2.,(TAU*2.+PI)/1.15]:
   game.world.annex.clock=time;game.world.annex._stir_pose()
   author.pose(game,Vector3(-12.55,.0,-30.1),Vector3(-13.43,1.4,-31.22));game.player.torch_body.hide()
   await capture(game,output,"03-cooking-%d"%int(time))
  game._quit();return
 if "--details-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  game.player.lamp.show()
  for view in [["01-doorframe",Vector3(-7.9,0,-9.6),Vector3(-7.9,1.5,-12.2)],["02-party-table",Vector3(9.75,0,-6.6),Vector3(9.15,.86,-7.0)],
               ["03-prep-table",Vector3(14.6,0,-6.4),Vector3(14.6,.68,-7.6)],["04-rolls",Vector3(16.3,.0,-6.6),Vector3(15.9,.72,-7.6)],
               ["05-books",Vector3(4.5,0,-10.2),Vector3(4.5,1.0,-11.65)],["06-books-close",Vector3(3.9,0,-10.9),Vector3(3.8,1.25,-11.65)]]:
   author.pose(game,view[1],view[2]);await capture(game,output,view[0])
  author.pose(game,Vector3(-7.6,0,1.7),Vector3(-10.2,2.3,1.7));await capture(game,output,"07-window")
  author.pose(game,Vector3(-8.6,0,1.25),Vector3(-10.2,2.0,1.9));await capture(game,output,"08-window-hole")
  author.pose(game,Vector3(-7,0,-2),Vector3(-7,1.6,-6))
  game.door_failure.start_patrol(game.world,game.player.camera)
  for at in [.24,.5,.82]:
   game.door_failure.tick(at-game.door_failure.clock);await capture(game,output,"09-door-%02d"%int(at*100))
  game._quit();return
 if "--clown-ceiling-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-12.1,0,-33.2),Vector3(-13.6,3.3,-31.1))
  game.player.torch_body.show()
  await capture(game,output,"01-ceiling-up")
  author.pose(game,Vector3(-13.9,0,-33.4),Vector3(-13.7,3.3,-31.0))
  await capture(game,output,"02-ceiling-up2")
  game._quit();return
 if "--remains-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  var remains: Node3D=game.world.archive.finale.get_node("ChainedRemains")
  var bounds:=AABB();var first:=true
  for mesh in remains.find_children("*","MeshInstance3D",true,false):
   var local: AABB=(remains.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
   bounds=local if first else bounds.merge(local);first=false
  var centre:=remains.to_global(bounds.get_center())
  game.player.lamp.show()
  author.pose(game,Vector3(centre.x,.05,centre.z-2.0),centre)
  await capture(game,output,"01-remains-front")
  author.pose(game,Vector3(centre.x+1.3,.05,centre.z-1.4),centre)
  await capture(game,output,"02-remains-angle")
  game._quit();return
 if "--album-menu-qa" in OS.get_cmdline_user_args():
  var album: AnomalyAlbum=game.anomaly_album;album.found.clear()
  for a in PatrolState.ANOMALIES.slice(0,40).filter(func(x):return hash(x.id)%3!=0):album.found[a.id]={"date":"2026-11-23","times":1+hash(a.id)%4}
  album.show_menu(func():NightMenus.home(game));for i in range(8):await game.get_tree().process_frame
  await capture(game,output,"01-album")
  var card: Button=game.menu.find_child("Polaroid_"+str(album.found.keys()[3]),true,false)
  if card:card.pressed.emit()
  for i in range(8):await game.get_tree().process_frame
  await capture(game,output,"02-detail")
  NightMenus.home(game);for i in range(8):await game.get_tree().process_frame
  await capture(game,output,"03-home")
  album.found.clear();DirAccess.remove_absolute(album.path);game._quit();return
 if "--album-photos-qa" in OS.get_cmdline_user_args():
  await album_photos(game,output);game._quit();return
 if "--sparkle-qa" in OS.get_cmdline_user_args():
  await sparkle_frames(game,output);game._quit();return
 if "--jumpscare-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  for id in ["snackbar_visitor","kitchen_floor_crawler"]:
   game._build_world(id);game.player.active=false
   for i in range(4):await game.get_tree().process_frame
   var t: NightTerrors=game.world.terrors;t.actor.show()
   var feet:=t.actor.global_position+Vector3(0,0,3.)
   author.pose(game,feet,t.actor.global_position+Vector3.UP*1.2);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for i in range(3):await game.get_tree().process_frame
   t.attack=1.;t._start_lunge(game.player)
   var shots:={3:"a",10:"b",30:"c",55:"d"}
   for f in range(60):
    t.attack+=.016;t._face_lunge(game.player,9.,0.)
    game.jumpscare.tick(.016,true,game.player.camera,game.settings)
    await game.get_tree().process_frame
    if shots.has(f):await capture(game,output,"jumpscare-%s-%s"%[id,shots[f]])
  game._quit();return
 if "--mic-qa" in OS.get_cmdline_user_args():
  if "--mic-menu" in OS.get_cmdline_user_args():
   game._settings("menu");NightMenus.settings(game,"Mikrofon")
   for i in range(6):await game.get_tree().process_frame
   await capture(game,output,"mic-00-settings");game._quit();return
  game._new_shift();game.intro.skip();game.set_process(false);game.player.set_physics_process(false)
  for i in range(6):await game.get_tree().process_frame
  game.phase="play";game.player.active=true;game.hud.show();game.settings.mic=true;game.mic.enabled=true
  var w: MicWarden=game.mic_warden;w.reset()
  game.mic.inject(-40.);w.tick(.05,true);await capture(game,output,"mic-01-hud-quiet")
  game.mic.inject(-6.)
  for i in range(12):w.tick(.05,true);await game.get_tree().process_frame
  await capture(game,output,"mic-02-warning")
  game.mic.inject(-70.);w.cooldown=0.;w.text_left=0.;w.tick(.05,true)
  game.mic.inject(-6.)
  for i in range(12):w.tick(.05,true);await game.get_tree().process_frame
  await capture(game,output,"mic-03-provoke")
  game.mic.inject(-70.);w.cooldown=0.
  for i in range(80):w.tick(.05,true)
  game.mic.inject(-6.)
  for i in range(12):w.tick(.05,true)
  var shots:={"turn":false,"still":false}
  var frames:={2:"a",6:"b",14:"c",30:"d",50:"e"}
  var f:=0
  while w.stage not in ["done","idle"]:
   w.tick(.05 if w.stage!="scare" else .016,false)
   game.jumpscare.tick(.016 if w.stage=="scare" else .05,true,game.player.camera,game.settings)
   await game.get_tree().process_frame
   if w.stage=="turn" and w.clock>1.6 and not shots.turn:shots.turn=true;await capture(game,output,"mic-04-turning")
   if w.stage=="still" and w.clock>1. and not shots.still:shots.still=true;await capture(game,output,"mic-05-nothing")
   if w.stage=="scare":
    f+=1
    if frames.has(f):await capture(game,output,"mic-06-godless-%s"%frames[f])
  game._quit();return
 if "--crawler-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  for id in ["party_under_table","kitchen_floor_crawler","frame_stalker","slide_crawler","tube_burst","tube_chase"]:
   game._build_world(id);game.player.active=false
   for i in range(4):await game.get_tree().process_frame
   var actor: Node3D=game.world.terrors.actor;actor.show()
   var at:=actor.global_position;var fwd:=actor.global_basis.z;fwd.y=0;fwd=fwd.normalized() if fwd.length()>.1 else Vector3.FORWARD
   var eye:=at+fwd*2.2+fwd.cross(Vector3.UP)*1.2+Vector3.UP*.9
   if id.begins_with("tube"):eye=at+fwd*1.6+Vector3.UP*.5
   author.pose(game,eye-Vector3.UP*1.65,at+Vector3.UP*.45);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for i in range(6):await game.get_tree().process_frame
   print("CRAWLER ",id," at ",at," visible ",actor.is_visible_in_tree())
   await capture(game,output,"crawler-"+id)
  game._quit();return
 if "--mood-qa" in OS.get_cmdline_user_args():
  await mood_views(game,output);game._quit();return
 if "--visitors-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  for pair in [["wc_ceiling_guest","01-hooded"],["cake_mouth","02-split"],["service_pursuit","03-ragged"],["throne_guest","04-seated"]]:
   game._build_world(pair[0]);game.player.active=false
   var head_node: Node3D=game.world.terrors.visual.find_child("HeadRig",true,false)
   var target: Vector3=(head_node.global_position if head_node else game.world.terrors.visual.global_position)
   author.pose(game,target+Vector3(0,.1,1.6),target);game.player.lamp.show()
   await capture(game,output,pair[1])
  game._quit();return
 if "--long-horse-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  var author=load("res://art-direction/itch_capture.gd").new()
  var horse: CeilingHorse=game.world.room_horror.creature
  var head: Vector3=horse.mask.global_position
  for view in [["01-horse-face",head-horse.mask.global_basis.z*1.6-Vector3.UP*1.45,head],["02-horse-under",head+Vector3(1.8,-2.2,1.2),head+Vector3(-.4,.1,0)],["03-horse-neck",head+Vector3(2.6,-1.7,-1.6),horse.to_global(Vector3(-.3,-.3,.2))]]:
   author.pose(game,view[1],view[2]);game.player.lamp.show()
   await capture(game,output,view[0])
  horse.debug_hold=true;horse.pose(.55);var mid: Vector3=horse.mask.global_position
  author.pose(game,mid+Vector3(.4,-1.6,2.6),mid);await capture(game,output,"04-horse-reaching")
  # The contact close-up uses a copy of the same head in front of the camera.
  var close:=horse.mask.duplicate() as Node3D;game.player.camera.add_child(close);close.scale=Vector3.ONE*.68
  close.position=Vector3(.04,.20,-1.08);close.rotation=Vector3(-.98,PI-.28,-.10);game.player.torch_body.hide();var fill:=OmniLight3D.new();fill.position=Vector3(.28,.18,-.35);fill.light_color=Color("bfc6b3");fill.light_energy=.9;fill.omni_range=4;game.player.camera.add_child(fill)
  await capture(game,output,"05-horse-contact")
  close.position=Vector3(.0,.05,-1.5);close.rotation=Vector3(-.35,PI-.9,-.05);await capture(game,output,"06-horse-profile")
  game._quit();return
 if "--clown-style-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-12.4,0,-31.25),Vector3(-14.4,1.8,-31.25))
  game.player.torch_body.hide()
  await capture(game,output,"01-kitchen-clown")
  author.pose(game,Vector3(-13.9,0,-34.1),Vector3(-13.8,1.25,-31.25))
  await capture(game,output,"01b-kitchen-side")
  author.pose(game,Vector3(-12.1,0,-33.2),Vector3(-13.7,1.55,-31.25))
  await capture(game,output,"01c-kitchen-approach")
  author.pose(game,Vector3(-12.4,0,-31.25),Vector3(-14.4,1.8,-31.25))
  game.world.annex.clown.root.hide()
  var root: Node3D=HorrorFigures.clown(game.world,game.player.camera).root
  root.position=Vector3(0,-1.86,-1.25)
  var fill:=OmniLight3D.new();fill.position=Vector3(.36,.23,-.3);fill.light_energy=.65;fill.omni_range=3.;fill.light_color=Color("e3d8c4");game.player.camera.add_child(fill)
  game.player.lamp.hide()
  await capture(game,output,"02-clown-front")
  root.rotation.y=.8;await capture(game,output,"03-clown-profile")
  fill.light_energy=4.5;fill.omni_range=7.;root.position=Vector3(0,-1.3,-3.3);root.rotation.y=.3;await capture(game,output,"04-clown-full")
  root.rotation.y=1.5;await capture(game,output,"05-clown-side")
  var figure: Dictionary=HorrorFigures.clown(game.world,game.player.camera);root.hide()
  fill.light_energy=1.2;figure.root.position=Vector3(0,-1.8,-1.55);figure.spoon.hide();figure.bowl.hide();HorrorFigures.strike(figure,1.);HorrorFigures.gape(figure,1.)
  await capture(game,output,"06-clown-attack")
  game._quit();return
 if "--horse-damage-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
  game.state.current=HorseHunt.ID;game._build_world(HorseHunt.ID)
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-7.9,0,-25.5),Vector3(-7.9,1.5,-29.65))
  var hunt: HorseHunt=game.world.horse_hunt
  hunt.head=Vector3(-7.9,2.03,-26.5)
  for hit in range(1,3):
   hunt._catch(game.player);hunt.tick(1.06,true,game.player);hunt.present_contact(true)
   hunt.horse.mask.hide()
   await capture(game,output,"horse-injury-%d"%hit)
  hunt._catch(game.player);hunt.tick(.17,true,game.player);hunt.present_contact(true)
  await capture(game,output,"horse-fatal-approach")
  hunt.tick(.19,true,game.player);hunt.present_contact(true)
  await capture(game,output,"horse-fatal-open-mouth")
  game._quit();return
 if "--tactile-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-4.0,0,-11.1),game.world.tactile.contact.green.global_position)
  game.player.hands.begin("green",game.world.tactile.contact.green.global_position);game.player.hands.clock=.22;game.player.hands.pose();game.world.tactile.tick(.20,true)
  await capture(game,output,"01-door-hand");game.player.hands.cancel()
  var button: Node3D=game.world.party.control
  var p:=button.global_position+button.global_basis.z*.80;p.y=.2
  author.pose(game,p,button.global_position)
  game.player.hands.begin("party_control",button.global_position);game.player.hands.clock=.22;game.player.hands.pose();game.world.tactile.tick(.20,true)
  await capture(game,output,"02-button-hand");game.player.hands.cancel()
  var key: Node3D=game.world.details.parking_key
  p=key.global_position+key.global_basis.z*.8;p.y=0.
  author.pose(game,p,key.to_global(Vector3(0,-.03,.12)))
  game.player.hands.begin("parking_key",key.global_position);game.player.hands.clock=.65;game.player.hands.pose();key.hide()
  await capture(game,output,"03-key-pickup");game.player.hands.cancel()
  game.state.streak=2;game.world.archive.sync(game.archive,3)
  author.pose(game,Vector3(10.2,0,-4.95),Vector3(10.2,.853,-6.05))
  game.player.hands.begin("paper:opening",Vector3(10.2,.853,-6.05));game._collect_paper("opening");game.player.hands.clock=.65;game.player.hands.pose()
  await capture(game,output,"04-newspaper-hand");game.player.hands.cancel()
  game.archive.parking_key_found=true;game._sync_parking_key()
  var lock: Node3D=game.world.tactile.contact.delivery_exit
  p=lock.global_position+lock.global_basis.z*.7;p.y=0.
  author.pose(game,p,lock.global_position)
  game.player.hands.begin("delivery_exit",lock.global_position);game.player.hands.clock=.4;game.player.hands.pose();game.world.tactile.tick(.2,true)
  await capture(game,output,"05-key-in-lock");game.player.hands.cancel()
  game._settings("menu");NightMenus.settings(game,"Steuerung");await capture(game,output,"06-body-settings")
  game._quit();return
 if "--menu-qa" in OS.get_cmdline_user_args():
  await capture(game,output,"main-menu")
  game._settings("menu");NightMenus.settings(game,"Steuerung");await capture(game,output,"settings-controls")
  game._quit();return
 if "--lift-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.tick(1.5);game.set_process(false)
  await capture(game,output,"01-incoming-phone")
  game.intro.accept();game.intro.tick(2.);await capture(game,output,"02-connected-phone")
  game.intro.phone.hide();game.intro.overlay.hide();await capture(game,output,"03-cabin-front")
  for shot in [{"name":"04-cabin-controls","look":Vector3(-6.72,1.55,18.05)},{"name":"05-cabin-rear","look":Vector3(-8.,1.5,20.3)}]:
   game.player.camera.look_at(shot.look);await capture(game,output,shot.name)
  game.player.position=Vector3(-8.,0,17.85);game.player.camera.look_at(Vector3(-8.,1.85,20.3));await capture(game,output,"06-cabin-directory")
  game.player.position=Vector3(-8.,0,18.65);game.player.camera.look_at(Vector3(-8.,2.7,18.4));await capture(game,output,"07-cabin-ceiling")
  game.intro.skip();game.player.active=false;game.player.torch_body.hide();game.player.lamp.hide()
  game.player.position=Vector3(-8.,0,16.2);game.player.camera.look_at(Vector3(-8.,1.4,20.3));await capture(game,output,"08-cabin-from-hall")
  game._quit();return
 if "--shift-qa" in OS.get_cmdline_user_args():
  game.set_process(false)
  for language in ["de","en"]:
   AfterPlayLanguage.choose(language)
   var warning:=AfterPlayStartWarning.new();game.add_child(warning);warning.build(game)
   await capture(game,output,"01-warning-"+language);warning.queue_free();await game.get_tree().process_frame
  AfterPlayLanguage.choose("de")
  game._new_shift();game.intro.skip();game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(-5.8,0,12.),Vector3(-8.0,1.7,6.3))
  game.player.torch_body.tick(.016,true,0.)
  for mesh in game.player.torch_body.find_children("*","MeshInstance3D",true,false):
   var bounds: AABB=(game.player.camera.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
   if bounds.size.length()>1.:print("LARGE HAND MESH ",mesh.name," ",bounds)
  await capture(game,output,"02-new-flashlight")
  game.player.torch_body.hide();await capture(game,output,"02b-room-only");game.player.torch_body.show()
  game.intro.set_floor(13);game.intro.ticket.tick(2.,true)
  author.pose(game,Vector3(-8.0,0,19.3),game.intro.ticket.global_position)
  await capture(game,output,"03-last-patrol-receipt")
  game.door_failure.start_patrol(game.world,game.player.camera);game.door_failure.running=false
  game.door_failure.attacker.position=Vector3(0,-1.77,-1.25);game.door_failure.fill.light_energy=.45
  game.player.torch_body.hide();game.player.lamp.hide()
  await capture(game,output,"04-passage-creature");game.door_failure.hide()
  game._build_world("service_pursuit");game.player.active=false
  var granny: Node3D=game.world.terrors.visual
  granny.reparent(game.player.camera,false);granny.position=Vector3(0,-1.73,-1.22);granny.rotation=Vector3.ZERO
  game.player.torch_body.hide();game.player.lamp.hide()
  var fill:=OmniLight3D.new();fill.light_energy=.45;fill.omni_range=3.;fill.position=Vector3(.3,.2,-.1);game.player.camera.add_child(fill)
  await capture(game,output,"05-granny");granny.queue_free();fill.queue_free()
  game._new_shift();game.intro.skip();game.player.active=false
  game.album.discover(1);game.album.entries["1"].image="";game._show_ending(1);game.end_credits.tick(5);await game.end_credits.wait_prepared();game.end_credits.finish_scroll()
  var party: PatrolPartyOutro=game.end_credits.afterglow;party.clock=8.;party._pose(0.);game.end_credits.tick(0.)
  await game.album.capture(1,party.camera)
  while game.album.capturing:await game.get_tree().process_frame
  game._main_menu();game.album.show_menu();await capture(game,output,"06-memory-album")
  game._quit();return
 if "--celebration-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.player.active=false
  game.phase="code";game.archive_input=PatrolPartyOutro.TEST_CODE;game._submit_archive_code()
  game.end_credits.tick(5);await game.end_credits.wait_prepared();game.end_credits.finish_scroll()
  var party: PatrolPartyOutro=game.end_credits.afterglow
  if "--celebration-detail-qa" in OS.get_cmdline_user_args():
   game.set_process(false)
   party.clock=12.;party._pose(0.);game.end_credits.tick(0.)
   game.world.party.evaluate(PatrolPartyOutro.SONG_START+12.,bool(game.settings.strobe))
   for detail in [{"name":"clown","p":party.actors[0].origin,"yaw":party.actors[0].yaw},{"name":"guest","p":party.actors[1].origin,"yaw":party.actors[1].yaw},{"name":"horse","p":party.horse.origin,"yaw":party.horse.yaw}]:
    var facing:=Vector3(sin(detail.yaw),0,cos(detail.yaw))
    party.camera.position=detail.p+facing*(3.5 if detail.name=="horse" else 2.8)+Vector3(0,1.7,0);party.camera.look_at(detail.p+Vector3(0,1.6 if detail.name=="horse" else 1.2,0))
    await capture(game,output,"detail-"+detail.name)
   game._quit();return
  for moment in [2.,8.,16.,24.,32.,40.,44.]:
   party.clock=moment;game.world.party.audio.seek(PatrolPartyOutro.SONG_START+moment)
   await game.get_tree().create_timer(.5).timeout
   await capture(game,output,"celebration-%02d"%int(moment))
  print("CELEBRATION ",JSON.stringify(game.end_credits.snapshot()))
  game._quit();return
 if "--party-control-qa" in OS.get_cmdline_user_args():
  game.party_reboot_until=0;game.world.party.reboot_until=0
  game._new_shift();game.intro.skip();game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(17.1,.2,-14.2),Vector3(19.5,1.65,-14.2))
  await capture(game,output,"party-control-room")
  author.pose(game,Vector3(18.3,.2,-13.25),game.world.party.control.global_position)
  game.world.party.interact();await game.get_tree().create_timer(.5).timeout;await capture(game,output,"party-control-on")
  game.world.party.interact();await game.get_tree().create_timer(.5).timeout;await capture(game,output,"party-control-restart-de")
  AfterPlayLanguage.choose("en");await game.get_tree().create_timer(.5).timeout;await capture(game,output,"party-control-restart-en")
  game._quit();return
 if "--croc-contact-profile" in OS.get_cmdline_user_args():
  await load("res://art-direction/croc_profile.gd").new().run(game,output);return
 if "--rolling-acid-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(8.3,0,-8.8),Vector3(13.5,4.0,-4.5))
  await capture(game,output,"01-party-off")
  game.world.party.set_enabled(true)
  for point in [{"id":"02-build","time":57.5},{"id":"03-first-drop","time":60.0},{"id":"04-breakdown","time":150.0},{"id":"05-final-drop","time":250.0}]:
   game.world.party.audio.seek(point.time)
   await game.get_tree().create_timer(.3).timeout
   await capture(game,output,point.id)
  game.world.party.set_enabled(false)
  for language in ["de","en"]:
   AfterPlayLanguage.choose(language);NightMenus.credits(game)
   await capture(game,output,"credit-"+language)
  game._quit();return
 if "--party-credit-qa" in OS.get_cmdline_user_args():
  for language in ["de","en"]:
   AfterPlayLanguage.choose(language);NightMenus.credits(game)
   await capture(game,output,"party-credit-"+language)
   print("PARTY CREDIT ",language," ",game.menu.find_child("PartyMusicCredit",true,false).get_parsed_text())
  game._quit();return
 if "--stereo-v387-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  author.pose(game,Vector3(10.8,0,-2.4),Vector3(7.4,1.0,-3.5))
  await capture(game,output,"stereo-off")
  game.world.party.set_enabled(true);game.world.party.audio.seek(HappylandParty.TRACK.DROPS[0]+1)
  await game.get_tree().create_timer(.3).timeout;await capture(game,output,"stereo-on")
  author.pose(game,Vector3(17.6,0,-10),Vector3(9.0,2.0,-2.8))
  await capture(game,output,"party-wide")
  game.world.party.set_enabled(false)
  author.pose(game,Vector3(15.8,0,-1.8),Vector3(13.7,.6,-3.8))
  await capture(game,output,"round-table")
  game._quit();return
 if "--warning-v386-qa" in OS.get_cmdline_user_args():
  var warning:=AfterPlayStartWarning.new();game.add_child(warning);warning.build(game)
  AfterPlayLanguage.choose("de");await capture(game,output,"start-warning-de")
  AfterPlayLanguage.choose("en");warning.language.selected=1;await capture(game,output,"start-warning-en")
  warning.queue_free();game._quit();return
 if "--update-v385-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.skip();game.player.active=false
  var author=load("res://art-direction/itch_capture.gd").new()
  for view in [{"id":"croc-front","p":Vector3(5.4,1.0,16.0),"look":Vector3(12.3,1.55,12.4)},{"id":"croc-rear","p":Vector3(19,1.0,15.4),"look":Vector3(12.3,1.3,12.4)},{"id":"parking-key","p":Vector3(-7.7,0,-18.0),"look":game.world.details.parking_key.global_position},{"id":"play-entry","p":Vector3(11.8,2.15,7.5),"look":Vector3(9.1,1.8,7.5)}]:
   author.pose(game,view.p,view.look);await game.get_tree().create_timer(.5).timeout;await capture(game,output,view.id)
  author.pose(game,Vector3(8.3,0,-8.8),Vector3(13.5,4.0,-4.5))
  await capture(game,output,"party-off")
  game.world.party.set_enabled(true)
  for seconds in [12.0,HappylandParty.TRACK.DROPS[0]+1,HappylandParty.TRACK.DROPS[1]+1]:
   game.world.party.audio.seek(seconds);await game.get_tree().create_timer(.3).timeout;await capture(game,output,"party-"+str(int(seconds)))
  game.world.party.set_enabled(false);game._quit();return
 if "--language-qa" in OS.get_cmdline_user_args():
  for index in [1,0]:
   game._settings("menu");NightMenus.settings(game,"Sprache")
   var choice:=game.menu.find_child("LanguageChoice",true,false) as OptionButton
   choice.item_selected.emit(index);game._main_menu()
   await game.get_tree().create_timer(.3).timeout;await capture(game,output,"menu-en" if index==1 else "menu-de")
  game._read_settings();game._main_menu()
  await capture(game,output,"menu-de-reloaded");game._quit();return
 if "--wall-decay-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/wall_decay_capture.gd").new().run(game,output);game._quit();return
 if "--child-art-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/child_art_capture.gd").new().run(game,output);game._quit();return
 if "--chalk-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/chalk_capture.gd").new().run(game,output);game._quit();return
 if "--itch-v380" in OS.get_cmdline_user_args():
  await load("res://art-direction/itch_v380_capture.gd").new().run(game,output);game._quit();return
 if "--v380-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v380_capture.gd").new().run(game,output);game._quit();return
 if "--v370-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v370_capture.gd").new().run(game,output);game._quit();return
 if "--v361-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v361_capture.gd").new().run(game,output);game._quit();return
 if "--v360-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v360_capture.gd").new().run(game,output);game._quit();return
 if "--v357-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v357_capture.gd").new().run(game,output);game._quit();return
 if "--v356-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v356_capture.gd").new().run(game,output);game._quit();return
 if "--v355-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v355_capture.gd").new().run(game,output);game._quit();return
 if "--v354-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v354_capture.gd").new().run(game,output);game._quit();return
 if "--v353-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v353_capture.gd").new().run(game,output);game._quit();return
 if "--weather-audio" in OS.get_cmdline_user_args():
  await load("res://art-direction/weather_audio_capture.gd").new().run(game,output);game._quit();return
 if "--v351-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v351_capture.gd").new().run(game,output);game._quit();return
 if "--chair-profile" in OS.get_cmdline_user_args():
  await load("res://art-direction/chair_profile.gd").new().run(game,output);return
 if "--v350-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v350_capture.gd").new().run(game,output);game._quit();return
 if "--v340-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v340_capture.gd").new().run(game,output);game._quit();return
 if "--v330-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v330_capture.gd").new().run(game,output);game._quit();return
 if "--v320-audio" in OS.get_cmdline_user_args():
  await load("res://art-direction/v320_audio_capture.gd").new().run(game,output);game._quit();return
 if "--v320-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v320_capture.gd").new().run(game,output);game._quit();return
 if "--v310-qa" in OS.get_cmdline_user_args() or "--clown-fit-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v310_capture.gd").new().run(game,output);game._quit();return
 if "--v300-actors" in OS.get_cmdline_user_args():
  await load("res://art-direction/v300_capture.gd").new().actors(game,output);game._quit();return
 if "--v300-qa" in OS.get_cmdline_user_args():
  await load("res://art-direction/v300_capture.gd").new().run(game,output);game._quit();return
 if "--itch-media" in OS.get_cmdline_user_args():
  await load("res://art-direction/itch_capture.gd").new().run(game,output);game._quit();return
 if "--endings-qa" in OS.get_cmdline_user_args():
  await endings_views(game,output);game._quit();return
 if "--watch-qa" in OS.get_cmdline_user_args():
  await watch_views(game,output);game._quit();return
 if "--life-qa" in OS.get_cmdline_user_args():
  await life_views(game,output);game._quit();return
 if "--film-qa" in OS.get_cmdline_user_args():
  await film_views(game,output);game._quit();return
 if "--layout-qa" in OS.get_cmdline_user_args():
  await layout_views(game,output);game._quit();return
 if "--details-qa" in OS.get_cmdline_user_args():
  await details_views(game,output);game._quit();return
 if "--v280-qa" in OS.get_cmdline_user_args():
  await v280_views(game,output);game._quit();return
 if "--v270-qa" in OS.get_cmdline_user_args():
  await v270_views(game,output);game._quit();return
 if "--v260-qa" in OS.get_cmdline_user_args():
  await v260_views(game,output);game._quit();return
 if "--menu-only" in OS.get_cmdline_user_args():
  await game.get_tree().create_timer(5).timeout;await capture(game,output,"main-menu");game._quit();return
 if "--v250-qa" in OS.get_cmdline_user_args():
  await v250_views(game,output);game._quit();return
 if "--placement-only" in OS.get_cmdline_user_args():
  print("PLACEMENT AUDIT ",JSON.stringify(SceneAudit.placement(game.world)));game._quit();return
 if "--polish-v240-qa" in OS.get_cmdline_user_args():
  await capture(game,output,"main-menu-v250")
  await polish_v240_views(game,output);game._quit();return
 if "--presentation-qa" in OS.get_cmdline_user_args():
  await presentation_views(game,output);game._quit();return
 if "--finale-qa" in OS.get_cmdline_user_args():
  await finale_views(game,output);game._quit();return
 if "--props-qa" in OS.get_cmdline_user_args():
  await props_views(game,output);game._quit();return
 if "--nightmares-qa" in OS.get_cmdline_user_args():
  await nightmare_views(game,output);game._quit();return
 if "--archive-qa" in OS.get_cmdline_user_args():
  await archive_views(game,output);game._quit();return
 if "--voice-qa" in OS.get_cmdline_user_args():
  game._new_shift();game.intro.tick(1.3);game.intro.accept()
  await game.get_tree().create_timer(.4).timeout
  var loaded: bool=game.intro.recording and game.intro.call_length>1 and game.intro.voice.playing
  game.intro.paused=true;game.intro.tick(.1);var clock: float=game.intro.clock
  await game.get_tree().create_timer(.2).timeout
  var frozen: bool=game.intro.voice.stream_paused and game.intro.clock==clock
  game.intro.paused=false;game.intro.tick(game.intro.call_length+.1)
  var hung_up: bool=game.intro.stage=="arrival" and not game.intro.voice.playing
  var report:={"recording":loaded,"source":game.intro.voice.stream.resource_path,"duration":game.intro.call_length,"pause":frozen,"hang_up":hung_up}
  var file:=FileAccess.open(output.path_join("voice-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
  print("VOICE QA ",JSON.stringify(report));game._quit();return
 if "--v194-qa" in OS.get_cmdline_user_args():
  await v194_views(game,output);game._quit();return
 if "--v193-qa" in OS.get_cmdline_user_args():
  await v193_views(game,output);game._quit();return
 if "--entry-qa" in OS.get_cmdline_user_args():
  await entry_probe(game,output);game._quit();return
 if "--v192-qa" in OS.get_cmdline_user_args():
  await v192_views(game,output);game._quit();return
 if "--v190-qa" in OS.get_cmdline_user_args():
  await v190_views(game,output);game._quit();return
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
 game._new_shift();game.intro.skip()
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
 report.quality_toggle=low_ok and not game.world.environment.environment.sdfgi_enabled and game.world.environment.environment.ssil_enabled and game.world.environment.environment.ssr_enabled
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
 game._build_world("croc_snap");game._resume();game.player.position=Vector3(3.5,0,13.7);game.player.rotation.y=-1.2
 await game.get_tree().create_timer(1.1).timeout;await capture(game,output,"croc_snap")
 var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("NATIVE RENDER QA ",JSON.stringify(report))
 game._quit()

func capture(game: Node3D, output: String, name: String) -> void:
 # Skinned close-up meshes need the skeleton update before the render frame.
 for frame in range(3):await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image:=game.get_viewport().get_texture().get_image()
 var error:=image.save_png(output.path_join(name+".png"))
 assert(error==OK,"Native screenshot failed")

func v250_views(game: Node3D, output: String) -> void:
 game._main_menu();await game.get_tree().create_timer(.3).timeout;await capture(game,output,"main-menu")
 game._settings("menu");await game.get_tree().process_frame;await capture(game,output,"settings")
 await polish_v240_views(game,output)
 game.archive.collected.assign(ArchiveState.PAPERS);game.archive.try_code("6428");game.world.archive.open();game.world.archive.tick(3,true)
 game.player.position=Vector3(-11.3,0,-9.9);game.player.velocity=Vector3.ZERO;game.player.camera.look_at(ArchiveFinale.RECORDER)
 var finale: ArchiveFinale=game.world.archive.finale;finale.interact()
 var views: Array=[]
 for shot in game.memories.shots:
  finale.voice.seek(float(shot.start)+2.0);await game.get_tree().create_timer(.35).timeout
  await capture(game,output,"memory-"+str(shot.image).trim_suffix(".png"));views.append(game.memories.snapshot())
 game._pause();await game.get_tree().process_frame;await capture(game,output,"memory-paused")
 var report:={"memories":views,"audit":SceneAudit.inspect(game.world),"renderer":RenderingServer.get_current_rendering_method()}
 var file:=FileAccess.open(output.path_join("v250-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("V250 VISUAL QA ",JSON.stringify(report))

func polish_v240_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.tick(1.5)
 await game.get_tree().create_timer(.7).timeout;await capture(game,output,"phone-incoming")
 game.intro.accept();await game.get_tree().create_timer(.7).timeout;await capture(game,output,"phone-connected")
 game.intro.skip()
 var shots: Array[Dictionary]=[
  {"name":"hall-finish","p":Vector3(-5.5,0,10.3),"look":Vector3(3.8,2.2,-1.2)},
  {"name":"party-finish","p":Vector3(7.2,0,-9.0),"look":Vector3(12.4,1.7,-4.3)},
  {"name":"kitchen-finish","p":(Vector3(-10.6,0,-17.4)+ServiceAnnex.OFFSET),"look":(Vector3(-14.8,1.7,-19.8)+ServiceAnnex.OFFSET)},
  {"name":"mascot-corner","p":Vector3(13.9,0,14.7),"look":Vector3(18,2.7,15.35)},
  {"name":"mascot-close","p":Vector3(15.8,0,14.5),"look":Vector3(18,3.0,15.35)},
  {"name":"party-mascot","p":Vector3(13.2,0,-6.8),"look":Vector3(17.9,2.5,.38)},
  {"name":"party-mascot-close","p":Vector3(17.2,0,-3.6),"look":Vector3(17.9,2.15,.38)},
  {"name":"small-rabbit-reference","p":Vector3(-5.4,0,4.85),"look":Vector3(-3.35,1.35,4.85)},
  {"name":"workshop","p":Vector3(-11.3,0,-4.55),"look":Vector3(-15.8,1.6,-5.6)},
  {"name":"server-racks","p":Vector3(-12.2,0,-5.8),"look":Vector3(-14.4,1.4,-2.65)},
  {"name":"maintenance","p":Vector3(-6.8,0,-7.4),"look":Vector3(-9.9,2.0,-6.4)},
  {"name":"cinema-wide","p":(Vector3(-5.6,0,-17.65)+ServiceAnnex.OFFSET),"look":(Vector3(2.0,1.8,-17.65)+ServiceAnnex.OFFSET)},
  {"name":"cinema-back","p":(Vector3(1.4,0,-17.65)+ServiceAnnex.OFFSET),"look":(Vector3(-5.8,1.6,-14.5)+ServiceAnnex.OFFSET)}]
 for shot in shots:
  game.player.position=shot.p;game.player.velocity=Vector3.ZERO;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.look)
  await game.get_tree().create_timer(1.3).timeout;await capture(game,output,shot.name)
 var report:={"audit":SceneAudit.inspect(game.world),"floor":{},"renderer":RenderingServer.get_current_rendering_method()}
 for sample in [{"p":Vector3(-6,0,8),"type":"concrete"},{"p":(Vector3(-3,0,-17.65)+ServiceAnnex.OFFSET),"type":"carpet"},{"p":Vector3(-12.2,0,-4.6),"type":"metal"},{"p":CrawlTubes.route(6)-Vector3.UP*.72,"type":"plastic"}]:
  game.player.active=false;game.player.position=sample.p;await game.get_tree().physics_frame;report.floor[sample.type]=FootSurfaces.at(game.player)
 var file:=FileAccess.open(output.path_join("polish-v240-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("POLISH V240 QA ",JSON.stringify(report))

func annex_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip()
 var shots: Array[Dictionary]=[
  {"name":"annex-corridor","pos":(Vector3(-7.9,0,-13.6)+ServiceAnnex.OFFSET),"yaw":0,"pitch":.03},
  {"name":"annex-kitchen","pos":(Vector3(-10.8,0,-16.7)+ServiceAnnex.OFFSET),"yaw":1.02,"pitch":-.01},
  {"name":"annex-clown","pos":(Vector3(-12.2,0,-18.0)+ServiceAnnex.OFFSET),"yaw":1.1,"pitch":.09},
  {"name":"annex-pot","pos":(Vector3(-12.2,0,-18.6)+ServiceAnnex.OFFSET),"yaw":1.03,"pitch":-.36},
  {"name":"annex-cinema","pos":(Vector3(-4.6,0,-17.65)+ServiceAnnex.OFFSET),"yaw":-PI/2,"pitch":.1},
  {"name":"crocodile-v3","pos":Vector3(4.8,0,13.8),"yaw":-1.25,"pitch":.13},
  {"name":"crocodile-profile","pos":Vector3(8.3,0,7.4),"yaw":-2.35,"pitch":.11}]
 for shot in shots:
  game.player.position=shot.pos;game.player.velocity=Vector3.ZERO;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2.5).timeout;await capture(game,output,shot.name)
 game._build_world("clown_lunge");game._resume();game.player.position=(Vector3(-12.2,0,-18)+ServiceAnnex.OFFSET);game.player.rotation.y=1.1;game.player.camera.rotation.x=.09
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

func v190_views(game: Node3D, output: String) -> void:
 game._new_shift()
 await game.get_tree().create_timer(2).timeout;await capture(game,output,"intro-ringing")
 game.intro.accept();await game.get_tree().create_timer(1.2).timeout;await capture(game,output,"intro-call")
 game.intro.tick(game.intro.call_length)
 await game.get_tree().create_timer(2.7).timeout;await capture(game,output,"lift-open")
 var arrived: bool=game.phase=="play" and game.player.position.z>17 and not game.intro_pending
 Input.action_press("forward");await game.get_tree().create_timer(3.5).timeout;Input.action_release("forward")
 var walked: bool=game.player.position.z<10.8 and game.player.position.y>-.1
 var shots: Array[Dictionary]=[
  {"name":"climbing-frame","pos":Vector3(-2.0,0,7.5),"yaw":-.65,"pitch":.4},
  {"name":"ceiling-mounts","pos":Vector3(-6.5,0,1),"yaw":-.4,"pitch":.9},
  {"name":"stocked-shelves","pos":Vector3(-7.3,0,2.1),"yaw":PI/2,"pitch":-.07},
  {"name":"party-right-wall","pos":Vector3(15.5,0,-4),"yaw":-PI/2,"pitch":.1},
  {"name":"expanded-kitchen","pos":(Vector3(-11.5,0,-17)+ServiceAnnex.OFFSET),"yaw":1.0,"pitch":.05},
  {"name":"kitchen-preparation","pos":(Vector3(-14.0,0,-20.3)+ServiceAnnex.OFFSET),"yaw":0,"pitch":-.05}]
 for shot in shots:
  game.player.position=shot.pos;game.player.velocity=Vector3.ZERO;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(2).timeout;await capture(game,output,shot.name)
 game._decide(true)
 var limit:=0.0
 while game.phase!="intro" and limit<10:
  await game.get_tree().process_frame;limit+=game.get_process_delta_time()
 var restart: bool=game.phase=="intro" and game.state.rounds==0 and game.state.streak==0 and game.intro_pending
 await game.get_tree().create_timer(1.4).timeout;await capture(game,output,"death-restart")
 var report:={"renderer":RenderingServer.get_current_rendering_method(),"arrived":arrived,"walked_out":walked,"death_restart":restart,"shelves":game.world.find_children("*","Node3D",true,false).filter(func(node): return node.has_meta("stocked_shelf")).size(),"audit":SceneAudit.inspect(game.world)}
 var file:=FileAccess.open(output.path_join("v190-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V190 RENDER QA ",JSON.stringify(report))

func v180_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip()
 var shots: Array[Dictionary]=[
  {"name":"reception-pc","pos":Vector3(-9.65,0,5.2),"yaw":-1.87,"pitch":-.32},
  {"name":"torch","pos":Vector3(-6.2,0,7.5),"yaw":-.55,"pitch":-.22},
  {"name":"kitchen","pos":(Vector3(-10.8,0,-17)+ServiceAnnex.OFFSET),"yaw":1.0,"pitch":.04},
  {"name":"clown-front","pos":(Vector3(-12.4,0,-19.25)+ServiceAnnex.OFFSET),"yaw":PI/2,"pitch":.1},
  {"name":"clown-profile","pos":(Vector3(-14.4,0,-17.5)+ServiceAnnex.OFFSET),"yaw":0,"pitch":.14}]
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
 var recovered: bool=is_equal_approx(game.player.lamp.light_energy,GuardTorch.BASE_ENERGY)
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
 game._new_shift();game.intro.skip()
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
 game._new_shift();game.intro.skip()
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
 game._new_shift();game.intro.skip()
 var shots: Array[Dictionary]=[
  {"name":"door-front","pos":Vector3(4.87,0,-8.7),"yaw":-PI/2,"pitch":.16},
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

func entry_probe(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip()
 var frame: Node3D=game.world.props.structure;var results: Array=[]
 for offset in [-.4,0,.4]:
  for outward in [true,false]:
   game.player.position=frame.to_global(Vector3(.2,.31,-1+offset)) if outward else frame.to_global(Vector3(-1.9,0,-1+offset))
   game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI/2 if outward else -PI/2
   Input.action_press("forward")
   for k in range(90): await game.get_tree().physics_frame
   Input.action_release("forward")
   var hits: Array=[]
   for k in range(game.player.get_slide_collision_count()):
    var hit: KinematicCollision3D=game.player.get_slide_collision(k);hits.append({"body":str(hit.get_collider().get_path()),"normal":str(hit.get_normal())})
   var local: Vector3=frame.to_local(game.player.position)
   results.append({"out":outward,"offset":offset,"local":str(local),"passed":local.x< -1.8 if outward else local.x>.8,"hits":hits})
 print("ENTRY PROBE ",JSON.stringify(results))
 var file:=FileAccess.open(output.path_join("entry-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results," "))

func v193_views(game: Node3D, output: String) -> void:
 await entry_probe(game,output)
 var shots: Array[Dictionary]=[
  {"name":"entry-ramp","pos":Vector3(-4.8,0,-1.12),"yaw":-PI/2,"pitch":-.09},
  {"name":"clown-front","pos":(Vector3(-12.4,0,-19.25)+ServiceAnnex.OFFSET),"yaw":PI/2,"pitch":.07},
  {"name":"clown-profile","pos":(Vector3(-14.4,0,-17.5)+ServiceAnnex.OFFSET),"yaw":0,"pitch":.1},
  {"name":"stirring-hand","pos":(Vector3(-12.2,0,-18.9)+ServiceAnnex.OFFSET),"yaw":1.43,"pitch":-.25},
  {"name":"guard-hand","pos":Vector3(-6.5,0,6.5),"yaw":-.6,"pitch":-.12}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(1.3).timeout;await capture(game,output,shot.name)
 game.world.soundscape.cue_steps(game.player)
 var before: Vector3=game.world.soundscape.ghost.position
 await game.get_tree().create_timer(.6).timeout
 var moved: bool=before.distance_to(game.world.soundscape.ghost.position)>.1
 game._pause();var clock: float=game.world.soundscape.ghost_clock;await game.get_tree().create_timer(.3).timeout
 var frozen: bool=game.world.soundscape.ghost.stream_paused and game.world.soundscape.ghost_clock==clock
 game._resume();await game.get_tree().create_timer(.2).timeout
 var report: Dictionary=game.world.soundscape.snapshot();report.moving_steps=moved;report.pause=frozen;report.audit=SceneAudit.inspect(game.world)
 var file:=FileAccess.open(output.path_join("v193-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("V193 RENDER QA ",JSON.stringify(report))

func nightmare_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume()
 for shot in [{"name":"ossuary","p":(Vector3(-3.7,0,-19.4)+ServiceAnnex.OFFSET),"look":(Vector3(-1.0,2.0,-19.5)+ServiceAnnex.OFFSET)},{"name":"party-fresco","p":Vector3(13.3,0,-4.4),"look":Vector3(13.3,2.6,1.485)}]:
  game.player.position=shot.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.look)
  await game.get_tree().create_timer(.7).timeout;await capture(game,output,shot.name)
 game.state.streak=2;game._build_world("none");game._resume();game._collect_paper("opening");game._inventory();await game.get_tree().process_frame;await capture(game,output,"newspaper-v21")
 var reports: Dictionary={}
 for id in NightTerrors.SCENARIOS:
  game._build_world(id);game._resume()
  var t: NightTerrors=game.world.terrors;var mode: String=t.spec.mode
  var points:={"Empfang":Vector3(-5.5,0,6),"Bällebad":Vector3(3.0,.31,5),"Party Raum":Vector3(13.8,0,-8),"Wartungsgang":Vector3(-6.5,0,-4),"Küche":(Vector3(-11.8,0,-17.5)+ServiceAnnex.OFFSET),"Kino":(Vector3(-5.9,0,-17.7)+ServiceAnnex.OFFSET),"Krabbelröhre":CrawlTubes.route(7.4)+Vector3(0,-.72,0)}
  game.player.position=points[t.spec.zone];game.player.rotation=Vector3.ZERO
  if id=="screen_visitor": game.player.position=(Vector3(-1.3,0,-17.7)+ServiceAnnex.OFFSET)
  if id=="frame_stalker": game.player.position=Vector3(2.0,.4,3.6)
  if id=="cake_mouth": game.player.position=Vector3(11.8,0,-7.4)
  if id=="slide_crawler": game.player.position=Vector3(5.6,0,11.5)
  var target: Vector3=t.actor.position+Vector3(0,1.6,0)
  if mode=="crawl": target=t.actor.position+Vector3(0,.7,0)
  if mode in ["hands","mouth"]: target=t.actor.position+Vector3(0,.35,0)
  if mode=="ceiling": target=t.actor.position-Vector3(0,1.6,0)
  if mode=="vent": target=game.world.room_horror.creature.position+Vector3(0,-1.5,.7)
  if mode in ["tube","window"]:
   Input.action_press("crouch");game.player.set_crouch(true);game.player.camera.position.y=.8
   game.player.position=CrawlTubes.route(7.0 if mode=="tube" else 11.8)+Vector3(0,-.72,0);target=t.actor.position+Vector3(.1,0,.05) if mode=="window" else t.actor.position+Vector3(0,.35,0)
  game.player.camera.look_at(target)
  await game.get_tree().create_timer(1.3).timeout
  if mode=="crawl": game.player.camera.look_at(t.actor.position+Vector3(0,.65,0))
  await capture(game,output,id);reports[id]=t.snapshot()
  if mode in ["tube","window"]: Input.action_release("crouch")
 game._build_world("tube_watcher");game._resume();game.player.position=CrawlTubes.route(7.4)+Vector3(0,-.72,0);Input.action_press("crouch");game.player.set_crouch(true);game.player.camera.position.y=.8;game.player.camera.look_at(game.world.tubes.watcher.position+Vector3(.06,0,.02))
 await game.get_tree().create_timer(.5).timeout;await capture(game,output,"watcher-inside");var inner: bool=game.world.tubes.watcher.visible
 Input.action_release("crouch");game.player.position=Vector3(-1.2,0,12.2);game.player.camera.look_at(game.world.tubes.watcher.position+Vector3(.06,0,.02))
 await game.get_tree().create_timer(.4).timeout;await capture(game,output,"watcher-outside");var outer: bool=game.world.tubes.watcher.visible
 reports.tube_visibility={"inside":inner,"outside":outer};reports.geometry=game.world.room_horror.creature_geometry()
 var file:=FileAccess.open(output.path_join("nightmares-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(reports," "));print("AFTER PLAY NIGHTMARES QA ",JSON.stringify(reports))

func archive_views(game: Node3D, output: String) -> void:
 game._main_menu();await game.get_tree().create_timer(.5).timeout;await capture(game,output,"after-play-menu")
 game._new_shift();game.intro.skip()
 game.player.position=Vector3(-8.1,0,-9.9);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(Vector3(-10.1,1.6,-9.9))
 await game.get_tree().create_timer(.5).timeout;await capture(game,output,"rust-door");var note_target: String=game._target();game._collect_paper("note")
 game._inventory();await game.get_tree().process_frame;await capture(game,output,"note-reader");game._resume()
 var targets: Dictionary={}
 for item in [{"id":"opening","level":3,"pos":Vector3(10.2,0,-4.6)},{"id":"missing","level":5,"pos":(Vector3(.9,0,-19.9)+ServiceAnnex.OFFSET)},{"id":"coverup","level":8,"pos":(Vector3(-11.75,0,-18.45)+ServiceAnnex.OFFSET)},{"id":"closure","level":11,"pos":Vector3(CrawlTubes.route(7.65).x,.31,15.8)}]:
  game.state.streak=item.level-1;game._build_world("none");game._resume();game.player.position=item.pos;game.player.rotation=Vector3.ZERO
  if item.id=="closure": Input.action_press("crouch");game.player.set_crouch(true);game.player.camera.position.y=.8
  game.player.camera.look_at(game.world.archive.items[item.id].global_position)
  await game.get_tree().create_timer(.6).timeout;await capture(game,output,"paper-"+item.id);targets[item.id]=game._target();game._collect_paper(item.id)
  if item.id=="closure": Input.action_release("crouch")
 game._inventory();await game.get_tree().process_frame;await capture(game,output,"newspaper-reader")
 game._open_archive_lock();await game.get_tree().process_frame;await capture(game,output,"code-lock")
 game.archive_input="6428";game._submit_archive_code();await game.get_tree().create_timer(2.2).timeout
 game.player.position=Vector3(-8.7,0,-9.9);game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(90): await game.get_tree().physics_frame
 Input.action_release("forward");var entered: bool=game.player.position.x< -11.5
 game.player.position=Vector3(-12.8,0,-9.9);game.player.camera.look_at(Vector3(-15.15,1.1,-9.9));await game.get_tree().create_timer(.6).timeout;await capture(game,output,"archive-room")
 game.player.rotation.y=-PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(105): await game.get_tree().physics_frame
 Input.action_release("forward");var exited: bool=game.player.position.x> -9.8
 var report: Dictionary=game.world.archive.snapshot();report.note_target=note_target;report.paper_targets=targets;report.entered=entered;report.exited=exited;report.audit=SceneAudit.inspect(game.world)
 var file:=FileAccess.open(output.path_join("archive-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("AFTER PLAY ARCHIVE QA ",JSON.stringify(report))

func v194_views(game: Node3D, output: String) -> void:
 game._main_menu();await game.get_tree().create_timer(1.1).timeout;await capture(game,output,"main-menu")
 game._settings("menu");await game.get_tree().process_frame;await capture(game,output,"settings-bild")
 NightMenus.settings(game,"Audio");await game.get_tree().process_frame;await capture(game,output,"settings-audio")
 NightMenus.settings(game,"Spiel");await game.get_tree().process_frame;await capture(game,output,"settings-spiel")
 var patrol_before:=JSON.stringify(game.state.serialize());var settings_before:=JSON.stringify(game.settings)
 game._menu_jump();await game.get_tree().create_timer(.35).timeout;await capture(game,output,"menu-scare")
 await game.get_tree().create_timer(1).timeout
 var prank_ok: bool=game.phase=="settings" and not game.menu_scare.running and game.menu_scare.shown==1 and patrol_before==JSON.stringify(game.state.serialize()) and settings_before==JSON.stringify(game.settings)
 game._new_shift();await game.get_tree().create_timer(1.7).timeout;await capture(game,output,"lift-phone");game.intro.accept()
 await game.get_tree().create_timer(.6).timeout;await capture(game,output,"lift-call");game.intro.skip()
 for shot in [{"name":"clown-body","pos":(Vector3(-13.1,0,-16.9)+ServiceAnnex.OFFSET),"target":(Vector3(-14.4,1.14,-19.25)+ServiceAnnex.OFFSET)},{"name":"shaft-and-neck","pos":(Vector3(-4.5,0,-17.6)+ServiceAnnex.OFFSET),"target":(Vector3(-1.8,2.8,-19.4)+ServiceAnnex.OFFSET)},{"name":"horse-skull","pos":(Vector3(-3.7,0,-17.4)+ServiceAnnex.OFFSET),"target":(Vector3(-2.1,2.03,-18.8)+ServiceAnnex.OFFSET)},{"name":"dark-shaft","pos":(Vector3(-2.5,0,-18.1)+ServiceAnnex.OFFSET),"target":(Vector3(-1.3,3.65,-19.95)+ServiceAnnex.OFFSET)}]:
  game.player.position=shot.pos;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.target)
  await game.get_tree().create_timer(1.3).timeout;await capture(game,output,shot.name)
 var report: Dictionary=game.world.room_horror.snapshot();report.audit=SceneAudit.inspect(game.world);report.menu_prank_nonlethal=prank_ok;report.menu_prank_count=game.menu_scare.shown;report.user_fov=game.player.base_fov
 var file:=FileAccess.open(output.path_join("v194-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("V194 RENDER QA ",JSON.stringify(report))

func v192_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip()
 var shots: Array[Dictionary]=[
  {"name":"party-entrance","pos":Vector3(4.4,0,-8.7),"yaw":-PI/2,"pitch":.18},
  {"name":"music-box","pos":Vector3(17.85,0,-2.42),"yaw":-PI/2,"pitch":-.16},
  {"name":"kitchen-ceiling","pos":(Vector3(-11.2,0,-16.5)+ServiceAnnex.OFFSET),"yaw":.6,"pitch":.6},
  {"name":"cinema-ceiling","pos":(Vector3(-4.7,0,-17.7)+ServiceAnnex.OFFSET),"yaw":-.8,"pitch":.5},
  {"name":"vent-creature","pos":(Vector3(-3.5,0,-17.9)+ServiceAnnex.OFFSET),"yaw":-.3,"pitch":.38},
  {"name":"creature-close","pos":(Vector3(-2.9,0,-18.3)+ServiceAnnex.OFFSET),"yaw":-.35,"pitch":.55}]
 for shot in shots:
  game.player.position=shot.pos;game.player.rotation.y=shot.yaw;game.player.camera.rotation.x=shot.pitch
  await game.get_tree().create_timer(1.3).timeout;await capture(game,output,shot.name)
 game._pause();var paused: Dictionary=game.world.room_horror.snapshot();await game.get_tree().create_timer(.3).timeout
 var frozen: bool=game.world.room_horror.clock==paused.clock and game.world.room_horror.music.stream_paused
 game._resume();await game.get_tree().create_timer(.4).timeout
 var report: Dictionary=game.world.room_horror.snapshot();report.pause=frozen;report.audit=SceneAudit.inspect(game.world)
 var file:=FileAccess.open(output.path_join("v192-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("V192 RENDER QA ",JSON.stringify(report))

func croc_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip()
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

func props_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume()
 for shot in [{"name":"croc-body","p":Vector3(17.8,0,15.9),"look":Vector3(13.0,1.3,11.3)},{"name":"croc-front","p":Vector3(5.0,0,14.8),"look":Vector3(10.8,1.55,11.3)},{"name":"kitchen-sink","p":(Vector3(-15.25,0,-16.1)+ServiceAnnex.OFFSET),"look":(Vector3(-16.63,1.13,-16.65)+ServiceAnnex.OFFSET)},{"name":"pot-interior","p":(Vector3(-12.6,.25,-18.75)+ServiceAnnex.OFFSET),"look":(Vector3(-13.25,1.22,-19.25)+ServiceAnnex.OFFSET)},{"name":"ball-pit","p":Vector3(.2,0,10.7),"look":Vector3(1,.4,6.7)},{"name":"bucket-interior","p":Vector3(3.1,0,9.3),"look":Vector3(3.7,.43,8.7)},{"name":"server-room","p":Vector3(-11.5,0,-5.4),"look":Vector3(-14.4,1.35,-2.65)},{"name":"party-gallery","p":Vector3(13.8,0,-8.7),"look":Vector3(13.8,2.1,-11.96)},{"name":"hall-gallery","p":Vector3(-6.4,0,1),"look":Vector3(-9.96,2.7,.8)}]:
  game.player.position=shot.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.look)
  await game.get_tree().create_timer(.7).timeout;await capture(game,output,shot.name)
 game._collect_paper("note");game._inventory();await game.get_tree().process_frame;await capture(game,output,"handwritten-note")
 var file:=FileAccess.open(output.path_join("props-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(SceneAudit.inspect(game.world)," "))

func presentation_views(game: Node3D, output: String) -> void:
 await game.get_tree().create_timer(.7).timeout;await capture(game,output,"menu-16x9")
 var report:={"logical":game.get_viewport().get_visible_rect().size,"window":DisplayServer.window_get_size(),"render":game.get_viewport().get_texture().get_size()}
 game._new_shift();game.intro.skip();game.player.position=Vector3(-8.7,0,-5.4);game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO
 await game.get_tree().create_timer(.7).timeout;await capture(game,output,"server-doorway")
 Input.action_press("forward")
 for frame in range(75): await game.get_tree().physics_frame
 Input.action_release("forward");report.server_entered=game.world.server_room.safe_pose(game.player.position)
 game.player.position=Vector3(-14.1,0,-4.6);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(Vector3(-16.11,1.5,-3.85))
 await game.get_tree().create_timer(.6).timeout;await capture(game,output,"mounted-power-box")
 game.player.position=Vector3(13.3,0,-4.4);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(Vector3(13.3,2.7,1.485))
 await game.get_tree().create_timer(.8).timeout;await capture(game,output,"party-right-wall")
 DisplayServer.window_set_size(Vector2i(960,720));await game.get_tree().create_timer(.5).timeout
 report.resized_window=DisplayServer.window_get_size();report.resized_render=game.get_viewport().get_texture().get_size();report.resized_logical=game.get_viewport().get_visible_rect().size
 await capture(game,output,"4x3-letterbox-content")
 DisplayServer.window_set_size(Vector2i(1280,720));await game.get_tree().create_timer(.3).timeout
 game._show_archive_ending();await game.get_tree().create_timer(.8).timeout;report.title_music=game.end_credits.music.playing;await capture(game,output,"ende")
 await game.get_tree().create_timer(4).timeout;game.end_credits.tick(13);await game.get_tree().process_frame;await capture(game,output,"credits-music")
 report.credits=game.end_credits.snapshot();var song: AudioStreamPlayer=game.end_credits.music;game._main_menu();report.music_stopped_on_exit=not song.playing
 var file:=FileAccess.open(output.path_join("presentation-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("PRESENTATION QA ",JSON.stringify(report))

func finale_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.archive.collected.assign(ArchiveState.PAPERS);game._open_archive_lock();game.archive_input="6428";game._submit_archive_code()
 await game.get_tree().create_timer(2.3).timeout
 game.player.position=Vector3(-8.7,0,-9.9);game.player.rotation.y=PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
 for frame in range(95): await game.get_tree().physics_frame
 Input.action_release("forward");var entered: bool=game.player.position.x< -11.5
 game.player.position=Vector3(-11.35,0,-10.3);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(Vector3(-13.15,.16,-8.7))
 await game.get_tree().create_timer(.7).timeout;await capture(game,output,"archive-remains")
 game.player.position=Vector3(-11.3,0,-9.9);game.player.camera.look_at(ArchiveFinale.RECORDER+Vector3(0,.07,0))
 await game.get_tree().create_timer(.4).timeout;await capture(game,output,"recorder")
 var target: String=game._target();game.world.archive.finale.interact()
 await game.get_tree().create_timer(.5).timeout;game._pause();await game.get_tree().process_frame
 var pause_at: float=game.archive.recording_position
 await game.get_tree().create_timer(.3).timeout;var paused: bool=game.archive.recording_position==pause_at and game.world.archive.finale.voice.stream_paused;game._resume()
 game.player.camera.look_at(Vector3(-14,1.3,-9.9))
 if "--fast-finale-qa" in OS.get_cmdline_user_args(): game.world.archive.finale.voice.seek(game.world.archive.finale.duration-.15)
 var wait_clock:=0.0
 while game.archive.ending=="recording" and wait_clock<290:
  await game.get_tree().process_frame;wait_clock+=game.get_process_delta_time()
 var listened: bool=game.archive.ending=="armed" and game.phase=="play"
 await game.get_tree().create_timer(.2).timeout
 game.player.camera.look_at(LostArchive.ENTRY+Vector3(0,1.5,0))
 await game.get_tree().create_timer(.24).timeout;await capture(game,output,"chef-reveal")
 await game.get_tree().create_timer(1.1).timeout;await game.get_tree().create_timer(.5).timeout;await capture(game,output,"ende")
 var word: bool=is_instance_valid(game.end_credits) and game.end_credits.snapshot().end_word
 game.end_credits.tick(12);await game.get_tree().process_frame;await capture(game,output,"credits-kyoko")
 game.end_credits.tick(16);await game.get_tree().process_frame;await capture(game,output,"credits-testers")
 var report:={"entered":entered,"papers":game.archive.collected,"recorder_target":target,"recording_pause":paused,"duration":game.world.archive.finale.duration,"full_recording": "--fast-finale-qa" not in OS.get_cmdline_user_args(),"listened_seconds":wait_clock,"armed_after_audio":listened,"ending":game.phase,"end_word":word,"credits":game.end_credits.snapshot(),"finale":game.world.archive.finale.snapshot()}
 var file:=FileAccess.open(output.path_join("finale-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));print("ARCHIVE FINALE QA ",JSON.stringify(report))

func v270_views(game: Node3D, output: String) -> void:
 await game.get_tree().create_timer(1).timeout;await capture(game,output,"menu-v270")
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 for shot in [
  {"name":"birthday-stage","p":Vector3(14.0,0,-6.1),"look":Vector3(14.2,2.2,-11.3)},
  {"name":"throne-close","p":Vector3(13.4,.2,-8.9),"look":Vector3(13.4,1.95,-11.0)},
  {"name":"backstage-door","p":Vector3(17.3,0,-8.6),"look":Vector3(17.3,1.5,-14.9)},
  {"name":"costume-room","p":Vector3(17.3,.2,-13.3),"look":Vector3(14.5,1.9,-17.7)},
  {"name":"maintenance-story","p":Vector3(-12.9,0,-4.4),"look":Vector3(-13.55,1.8,-6.8)},
  {"name":"dented-locker","p":Vector3(-11.9,0,-4.6),"look":Vector3(-11.45,1.25,-2.5)},
  {"name":"kitchen-palette","p":(Vector3(-10.5,0,-17.3)+ServiceAnnex.OFFSET),"look":(Vector3(-15.1,1.1,-19.0)+ServiceAnnex.OFFSET)},
  {"name":"cinema-palette","p":(Vector3(-5.5,0,-17.65)+ServiceAnnex.OFFSET),"look":(Vector3(2.6,1.7,-17.65)+ServiceAnnex.OFFSET)},
  {"name":"delivery-door","p":Vector3(-7.9,0,9.4),"look":Vector3(-10.2,1.6,9.4)}]:
  game.player.position=shot.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.look)
  await game.get_tree().create_timer(.75).timeout;await capture(game,output,shot.name)
 print("V270 PLACEMENT ",JSON.stringify(SceneAudit.placement(game.world)))
 game.archive_selected="checklist";game._inventory();await game.get_tree().process_frame;await capture(game,output,"handwritten-notebook")
 game._equipment_card();await game.get_tree().process_frame;await capture(game,output,"personal-equipment")
 game._build_world("false_exit");game._resume();game.player.active=false
 game.player.position=Vector3(-8.8,0,9.4);game.player.camera.look_at(Vector3(-14,1.5,9.4));game.world.backstage.interact_exit(game.player)
 await game.get_tree().create_timer(1.2).timeout;await capture(game,output,"impossible-clean-exit")
 await game.get_tree().create_timer(3.6).timeout;game.world.backstage.interact_exit(game.player)
 await game.get_tree().create_timer(1.2).timeout;await capture(game,output,"decayed-exit")
 for spec in [{"id":"throne_guest","p":Vector3(13.4,.2,-8.6),"target":Vector3(13.4,2.15,-10.75)},{"id":"costume_wakes","p":Vector3(16.1,.2,-15.1),"target":Vector3(16.18,2.26,-18.02)}]:
  game._build_world(spec.id);game._resume();game.player.active=false;game.player.position=spec.p;game.player.camera.look_at(spec.target)
  await game.get_tree().create_timer(1.15).timeout;await capture(game,output,spec.id)
 print("V270 RENDER COMPLETE")

func v260_views(game: Node3D, output: String) -> void:
 await game.get_tree().create_timer(2).timeout;await capture(game,output,"main-menu-v260")
 game._help("menu");await game.get_tree().process_frame;await capture(game,output,"instructions-v260")
 game._new_shift();game.intro.skip();game._build_world("none");game._resume();game.player.active=false
 for shot in [{"name":"kitchen-v260","p":(Vector3(-10.5,0,-17.3)+ServiceAnnex.OFFSET),"look":(Vector3(-15.1,1.1,-19.0)+ServiceAnnex.OFFSET)},{"name":"kitchen-oven-v260","p":(Vector3(-11.3,0,-18.3)+ServiceAnnex.OFFSET),"look":(Vector3(-13.25,.75,-19.25)+ServiceAnnex.OFFSET)},{"name":"kitchen-cabinet-v260","p":(Vector3(-14.9,0,-17.3)+ServiceAnnex.OFFSET),"look":(Vector3(-16.6,.85,-18.3)+ServiceAnnex.OFFSET)},{"name":"party-only-rabbit-v260","p":Vector3(13.2,0,-6.8),"look":Vector3(17.9,2.5,.38)},{"name":"hall-without-rabbit-v260","p":Vector3(13.9,0,14.7),"look":Vector3(18,2.7,15.35)}]:
  game.player.position=shot.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(shot.look)
  await game.get_tree().create_timer(.7).timeout;await capture(game,output,shot.name)
 print("V260 PLACEMENT ",JSON.stringify(SceneAudit.placement(game.world)))
 game.state.streak=13;game.state.completed=true;game._won();game.player.active=false
 await game.get_tree().create_timer(.8).timeout;await capture(game,output,"patrol-ending-v260")
 game.end_credits.tick(35);await game.get_tree().process_frame;await capture(game,output,"patrol-ending-credits-v260")
 for spec in [{"id":"reception_overhead","p":Vector3(-4.8,0,8.5)},{"id":"cinema_aisle_rush","p":(Vector3(-1.0,0,-17.65)+ServiceAnnex.OFFSET)},{"id":"kitchen_floor_crawler","p":(Vector3(-12.9,0,-15.5)+ServiceAnnex.OFFSET)}]:
  game._build_world(spec.id);game._resume();game.player.active=false
  game.player.position=spec.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(game.world.terrors.focus_point())
  await game.get_tree().create_timer(1.1).timeout;await capture(game,output,spec.id+"-v260")
 game._show_archive_ending();await game.get_tree().process_frame;await game.get_tree().process_frame
 var note: Label=game.end_credits.roll.find_child("KyokoNote",true,false)
 game.end_credits.clock=4+(1120+note.position.y-160)/38
 await game.get_tree().create_timer(.2).timeout;await capture(game,output,"kyoko-note-v260")

func v280_views(game: Node3D, output: String) -> void:
 await game.get_tree().create_timer(1).timeout;await capture(game,output,"menu-v280")
 game._new_shift();game.intro.skip();game.player.active=false
 for shot in [
  {"name":"costume-workshop","p":Vector3(17.6,.2,-13.5),"look":Vector3(13.2,1.7,-16.1)},
  {"name":"sewing-bench","p":Vector3(15.6,.2,-14.9),"look":Vector3(13.3,1.3,-13.1)},
  {"name":"decision-doors","p":Vector3(-3.2,0,-8.0),"look":Vector3(-3.2,1.9,PatrolPassage.ENTRY_Z)}]:
  game.player.position=shot.p;game.player.camera.look_at(shot.look);await game.get_tree().create_timer(.8).timeout;await capture(game,output,shot.name)
 game._decide(false);game.player.position=Vector3(PatrolPassage.CENTERS[0],0,PatrolPassage.ENTRY_Z-2.7);game.player.rotation.y=0;game.player.camera.rotation=Vector3.ZERO
 await game.get_tree().create_timer(1).timeout;await capture(game,output,"green-corridor")
 print("V280 PLACEMENT ",JSON.stringify(SceneAudit.placement(game.world)))
 game.phase="pause";game.hud.hide();game.player.release();game.player.lamp.hide();game.player.camera.rotation=Vector3.ZERO;game.door_failure.start_patrol(game.world,game.player.camera);game.door_failure.tick(.43)
 await capture(game,output,"corridor-attacker");game.door_failure.hide();game.door_failure.running=false;game.door_failure.audio.stop()
 print("V280 RENDER COMPLETE")

func film_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var film: CinemaFilm=game.world.film
 game.player.position=Vector3(-4.85,0,-14.1)+ServiceAnnex.OFFSET;game.player.camera.look_at(film.reel.global_position+Vector3(0,.04,0))
 await game.get_tree().create_timer(.6).timeout;await capture(game,output,"film-reel")
 game.archive.film_found=true;film.sync(true);assert(film.start())
 game.player.position=Vector3(-2.8,0,-17.7)+ServiceAnnex.OFFSET;game.player.camera.look_at(Vector3(3.48,1.9,-17.7)+ServiceAnnex.OFFSET)
 await game.get_tree().create_timer(3).timeout;await capture(game,output,"happyland-projection")
 film.viewport.get_texture().get_image().save_png(output.path_join("projected-video-frame.png"))
 game._pause();await game.get_tree().create_timer(.1).timeout;var before: float=film.video.stream_position
 await game.get_tree().create_timer(.4).timeout;assert(absf(film.video.stream_position-before)<.04);game._resume();game.player.active=false
 await game.get_tree().create_timer(9).timeout;await capture(game,output,"happyland-projection-playground")
 await game.get_tree().create_timer(23).timeout
 assert(not film.playing and film.screen.material_override==film.original,"Film did not naturally finish and restore NO SIGNAL")
 await capture(game,output,"projection-finished")
 print("FILM NATIVE QA ",JSON.stringify({"film":film.snapshot(),"placement":SceneAudit.placement(game.world),"complete_playback":true}))

func layout_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 for view in [
  {"id":"service-approach","p":Vector3(-7.9,0,-23),"look":Vector3(-7.9,1.5,-15)},
  {"id":"service-notice","p":Vector3(-7.6,0,-18),"look":Vector3(-9.29,1.6,-18)},
  {"id":"green-open","p":Vector3(-4.3,0,-10.2),"look":Vector3(-4.3,1.5,-21)},
  {"id":"red-open","p":Vector3(-2.15,0,-10.2),"look":Vector3(-2.15,1.5,-21)}]:
  if view.id.ends_with("-open"):
   game.world.passages.restore({"chosen":-1,"open":[view.id=="green-open",view.id=="red-open"]})
  game.player.position=view.p;game.player.rotation=Vector3.ZERO;game.player.camera.look_at(view.look)
  await game.get_tree().create_timer(.7).timeout;await capture(game,output,view.id)
 print("LAYOUT AUDIT ",JSON.stringify(SceneAudit.placement(game.world)))

func details_views(game: Node3D, output: String) -> void:
 await capture(game,output,"main-menu-details")
 game._new_shift();game.intro.skip();game.player.active=false
 for view in [
  {"id":"lost-property","p":Vector3(1.8,0,-8.0),"look":Vector3(2.7,1.1,-11.7)},
  {"id":"arcade","p":Vector3(7.8,0,13.0),"look":Vector3(9.0,1.1,16.5)},
  {"id":"reception","p":Vector3(-6.5,0,13.4),"look":Vector3(-9.5,1.05,14.2)},
  {"id":"party","p":Vector3(13,0,-4),"look":Vector3(16.4,.9,-7.2)},
  {"id":"birthday-table","p":Vector3(11.4,0,-4),"look":Vector3(10.2,.9,-7)},
  {"id":"kitchen","p":Vector3(-13.2,0,-16)+ServiceAnnex.OFFSET,"look":Vector3(-16.5,1.3,-15.5)+ServiceAnnex.OFFSET},
  {"id":"cinema","p":Vector3(.9,0,-17)+ServiceAnnex.OFFSET,"look":Vector3(2.05,1,-14.35)+ServiceAnnex.OFFSET},
  {"id":"maintenance","p":Vector3(-11.2,0,-3.9),"look":Vector3(-13.5,1.1,-6.2)},
  {"id":"service-hall","p":Vector3(-7.9,0,-15.5),"look":Vector3(-9.2,1.8,-18.0)}]:
  game.player.position=view.p;game.player.camera.look_at(view.look);await game.get_tree().create_timer(.5).timeout;await capture(game,output,view.id)
 print("DETAILS AUDIT ",JSON.stringify(SceneAudit.placement(game.world))," COUNTS ",JSON.stringify(game.world.details.snapshot()))

func endings_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false;game.state.streak=4;game._build_world("none");game._resume();game.player.active=false
 game.player.position=Vector3(1.2,.03,-31.9);game.player.camera.look_at(game.world.archive.items.missing.global_position)
 await game.get_tree().create_timer(.6).timeout;await capture(game,output,"cinema-newspaper")
 assert(game._target()=="paper:missing","Real native ray cannot collect cinema newspaper")
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)
 assert("missing" in game.archive.collected,"E cannot collect native newspaper")
 for i in range(2):
  if i==0: game.state.completed=true;game.state.streak=13;game._show_patrol_ending()
  else: game.archive.creator_access=true;game.archive.unlocked=true;game.archive.ending="complete";game._show_archive_ending()
  game.end_credits.tick(.8)
  await game.get_tree().create_timer(.1).timeout;await capture(game,output,"end-%d-title"%(i+1))
  game.end_credits.tick(35)
  await game.get_tree().create_timer(.1).timeout;await capture(game,output,"end-%d-credits"%(i+1))
  game.end_credits.finish_scroll();game.end_credits.tick(17)
  await game.get_tree().create_timer(.2).timeout;await capture(game,output,"end-%d-finished"%(i+1))
  print("NUMBERED END ",JSON.stringify(game.end_credits.snapshot()))

func life_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 for view in [
  {"id":"snackbar","p":Vector3(16.4,0,12.8),"look":Vector3(16.8,1.4,16.4)},
  {"id":"photo-booth","p":Vector3(12.8,0,13.8),"look":Vector3(13,1.25,16.25)},
  {"id":"photo-strip","p":Vector3(12.7,0,15.0),"look":HappylandLife.PHOTO},
  {"id":"wc-entrance","p":Vector3(17.7,0,7.8),"look":Vector3(23,1.4,7.8)},
  {"id":"washbasins","p":Vector3(22.4,0,7.2),"look":Vector3(23.1,.9,5.6)},
  {"id":"cubicles","p":Vector3(24.0,0,6.3),"look":Vector3(24.8,1.1,9.4)},
  {"id":"condensation","p":Vector3(25.3,0,7.6),"look":Vector3(26.2,.85,6.3)}]:
  game.player.position=view.p;game.player.camera.look_at(view.look);await game.get_tree().create_timer(.6).timeout;await capture(game,output,view.id)
 print("LIFE AUDIT ",JSON.stringify(SceneAudit.placement(game.world))," STATE ",JSON.stringify(game.world.life.snapshot()))
 game._show_booth_photo();await game.get_tree().create_timer(.4).timeout;await capture(game,output,"photo-reader");game._return_from_panel()
 game._show_archive_ending();game.end_credits.tick(5);game.end_credits.finish_scroll();game.end_credits.tick(3)
 await game.get_tree().create_timer(.5).timeout;await capture(game,output,"last-look")
 game.end_credits.tick(7);await capture(game,output,"last-lights");game.end_credits.tick(7)
 print("LAST LOOK QA ",JSON.stringify(game.end_credits.snapshot()))

func watch_views(game: Node3D, output: String) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 game.player.position=Vector3(.4,0,13.65);game.player.camera.look_at(ReceptionWatch.WALL)
 await game.get_tree().create_timer(.8).timeout;await capture(game,output,"memories-wall")
 game._show_memory_wall();await game.get_tree().create_timer(.3).timeout;await capture(game,output,"memories-reader");game._return_from_panel();game.player.active=false
 game.player.position=Vector3(-7.25,0,5.6);game.player.camera.look_at(game.world.watch.display.global_position)
 await game.get_tree().create_timer(.5).timeout;await capture(game,output,"reception-crt")
 game._open_watch()
 for i in range(ReceptionWatch.FEEDS.size()):
  game.world.watch._select(i)
  game.menu.find_child("CCTVCameraLabel",true,false).text=ReceptionWatch.FEEDS[i].label
  await game.get_tree().create_timer(.5).timeout;await capture(game,output,"cctv-%02d"%(i+1))
 game._close_watch();game.player.active=false
 game.player.position=Vector3(.9,0,9.6);game.player.camera.look_at(Vector3(.9,.2,6.9))
 await game.get_tree().create_timer(1.5).timeout;await capture(game,output,"physical-ball-pit")
 print("WATCH AUDIT ",JSON.stringify(SceneAudit.placement(game.world))," PHYSICS ",JSON.stringify(game.world.pit_physics.snapshot()))
 game.player.position=Vector3(1.1,.03,7.8);game.player.rotation=Vector3.ZERO;game.player.camera.rotation=Vector3(-.45,0,0);game.player.active=true
 Input.action_press("forward")
 await game.get_tree().create_timer(.65).timeout;Input.action_release("forward");game.player.active=false;game.player.velocity=Vector3.ZERO
 await capture(game,output,"balls-after-walking")
 assert(game.world.pit_physics.kicks>0,"Native guard never displaces a ball")
 print("BALL WALK ",JSON.stringify(game.world.pit_physics.snapshot()))
 game._build_world("chair_ceiling");game.player.active=false;game._open_watch(2)
 await game.get_tree().create_timer(.6).timeout;await capture(game,output,"cctv-real-anomaly");game._close_watch();game.player.active=false
 for id in ["wc_stall_watcher","wc_ceiling_guest","snackbar_visitor"]:
  game._build_world(id);game.player.active=false
  var terror: NightTerrors=game.world.terrors
  game.player.position=Vector3(23.5,.03,7.0) if id=="wc_stall_watcher" else Vector3(22.4,.03,7.1) if id=="wc_ceiling_guest" else Vector3(17.2,.03,11.9)
  game.player.camera.look_at(terror.focus_point())
  await game.get_tree().create_timer(1.1).timeout;await capture(game,output,id)
  assert(terror.triggered,"New native encounter cannot trigger: "+id)

# 5.2.8: one polaroid photo per anomaly for the anomaly album. The camera looks
# at the anomaly's anchor from the side of its room, lamp on, no HUD.
const ALBUM_ROOMS:={"Empfang":Vector3(-5.5,1.65,9.5),"Bällebad":Vector3(-1.,1.65,9.),"Party Raum":Vector3(10.5,1.65,-2.5),"Wartungsgang":Vector3(-7.9,1.65,-9.5),"Küche":Vector3(-11.,1.65,-30.),"Kino":Vector3(-2.,1.65,-25.5),"Kinder-WC":Vector3(21.,1.65,7.8),"Krabbelröhre":Vector3(-1.,1.65,9.)}
const ALBUM_ANCHORS:={"horse_clown_hunt":Vector3(-1.3,1.6,-32.15),"power_blackout":Vector3(-13.,1.3,-5.),"dust_footprints":Vector3(1.5,0.,10.5),"cold_breath":Vector3(-13.25,1.3,-31.25),"costume_wakes":Vector3(16.,1.5,-15.),"false_exit":Vector3(-13.5,1.4,9.4),"clown_lunge":Vector3(-13.25,1.4,-31.25),"chair_ceiling":Vector3(8.5,2.4,-7.),"balls_float":Vector3(3.,1.2,7.),"balls_missing":Vector3(3.,.4,7.),"ball_giant":Vector3(2.2,1.3,6.),"mural_missing":Vector3(-9.96,2.2,-2.3),"mural_bleeds":Vector3(-9.96,1.8,-2.8),"clock_fast":Vector3(-9.98,3.05,7.3),"car_giant":Vector3(4.15,1.,-7.45),"car_missing":Vector3(4.15,.4,-7.45),"lights_red":Vector3(-2.,2.2,2.),"party_dark":Vector3(12.,1.4,-6.),"balloons_many":Vector3(8.5,2.,-8.5),"balloons_floor":Vector3(8.5,.6,-9.),"balloons_follow":Vector3(8.5,2.,-9.),"party_burst":Vector3(8.5,2.,-9.),"net_missing":Vector3(-.5,2.,5.),"blood_trail":Vector3(-5.8,0.,-2.),"bunny_ceiling":Vector3(-4.3,3.5,-8.5),"heavy_mist":Vector3(3.,.8,6.),"horse_rocks":Vector3(-6.,.8,11.)}

# Fixed camera positions where the automatic side view lands in a wall.
const ALBUM_EYES:={"car_giant":Vector3(-.5,1.9,-2.6),"car_missing":Vector3(-.5,1.9,-2.6),"heavy_mist":Vector3(-1.5,1.9,11.5),"frame_drop":Vector3(-2.,1.8,6.),"frame_stalker":Vector3(-1.8,1.7,5.8),"party_portrait":Vector3(12.5,1.7,-4.5),"horse_clown_hunt":Vector3(-4.5,1.7,-26.5),"power_blackout":Vector3(-7.5,1.7,-1.),"balls_float":Vector3(-1.5,2.,11.),"pit_hands":Vector3(-.5,2.,10.5),"pit_runner":Vector3(1.,1.8,10.),"slide_crawler":Vector3(.5,1.8,13.5),"net_missing":Vector3(-4.,1.8,9.),"cold_breath":Vector3(-10.5,1.7,-29.5),"tube_watcher":Vector3(-1.5,2.,11.)}
const ALBUM_TUBE:=["tube_burst","tube_chase","tube_window_hands"]

func album_anchor(game: Node3D,id: String,zone: String) -> Vector3:
 var w=game.world
 if NightTerrors.SCENARIOS.has(id) and is_instance_valid(w.terrors.visual):
  var head: Node3D=w.terrors.visual.find_child("HeadRig",true,false)
  return head.global_position if head else w.terrors.visual.global_position+Vector3.UP*1.2
 if id=="star_giant":return w.props.stars.get_child(0).global_position
 if id=="croc_snap":return w.props.inflatable.global_position+Vector3.UP*1.2
 if id=="bunny_lunge":return w.atmosphere.horrors.bunny.global_position+Vector3.UP*.5
 if ALBUM_ANCHORS.has(id):return ALBUM_ANCHORS[id]
 return ALBUM_ROOMS.get(zone,Vector3(0,1.65,0))+Vector3(0,0,-3)

func album_photos(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 var author=load("res://art-direction/itch_capture.gd").new()
 var only:=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--only=")).map(func(a):return a.trim_prefix("--only="))
 for a in PatrolState.ANOMALIES:
  if not only.is_empty() and a.id not in only:continue
  game._build_world(a.id);game.player.active=false
  for i in range(4):await game.get_tree().process_frame
  if NightTerrors.SCENARIOS.has(a.id) and is_instance_valid(game.world.terrors.actor) and a.id not in ALBUM_TUBE:game.world.terrors.actor.show()
  var target:=album_anchor(game,a.id,a.zone)
  if a.id in ALBUM_TUBE:
   # From inside the crawl tube, looking along it.
   var at: float={"tube_burst":3.2,"tube_chase":8.4,"tube_window_hands":12.6}[a.id]
   var inside:=CrawlTubes.route(at)+Vector3.UP*.45
   author.pose(game,inside-Vector3.UP*1.65,CrawlTubes.route(minf(at+1.6,CrawlTubes.LENGTH-.2))+Vector3.UP*.4+Vector3(.25,0,0));game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for i in range(6):await game.get_tree().process_frame
   await capture(game,output,a.id);continue
  if ALBUM_EYES.has(a.id):
   author.pose(game,ALBUM_EYES[a.id]-Vector3.UP*1.65,target);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for i in range(6):await game.get_tree().process_frame
   await capture(game,output,a.id);continue
  var room: Vector3=ALBUM_ROOMS.get(a.zone,Vector3(0,1.65,0))
  var flat:=Vector3(room.x-target.x,0,room.z-target.z)
  if flat.length()<1.:flat=Vector3(0,0,1)
  var eye:=target+flat.normalized()*3.4;eye.y=clampf(target.y+.35,1.2,2.2)
  # Stay inside the room: stop short of any wall between anchor and camera.
  var q:=PhysicsRayQueryParameters3D.create(target+flat.normalized()*.4,eye,1);q.exclude=[game.player.get_rid()]
  var hit: Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(q)
  if not hit.is_empty():eye=hit.position-flat.normalized()*.35;eye.y=clampf(target.y+.35,1.2,2.2)
  author.pose(game,eye-Vector3.UP*1.65,target);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
  for i in range(6):await game.get_tree().process_frame
  await capture(game,output,a.id)

# 5.3.0: every room without an anomaly, seen from one corner across to the
# other, torch on. Compares the light mood of the rooms before and after.
const MOOD_EXTRA:={"Kino-ost":[Vector3(-4.5,1.7,-29.6),Vector3(4.,1.6,-29.6)],"Kino-west":[Vector3(2.,1.7,-29.6),Vector3(-6.,1.4,-29.6)],"Kino-nord":[Vector3(-.5,1.7,-34.),Vector3(-.5,1.4,-24.5)]}
const MOOD_VIEWS:={"Empfang":[Vector3(-4.2,1.65,9.2),Vector3(-9.6,2.3,6.6)],"Bällebad":[Vector3(17.5,1.75,15.8),Vector3(3.,.8,6.5)],"Kino":[Vector3(-3.,1.9,-25.2),Vector3(3.8,1.4,-30.5)]}
func mood_views(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 game._build_world("none");game.player.active=false
 var author=load("res://art-direction/itch_capture.gd").new()
 var wait:=float(Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--wait=")).map(func(a):return a.trim_prefix("--wait=")).front() if Array(OS.get_cmdline_user_args()).any(func(a):return a.begins_with("--wait=")) else "0")
 for room in SecretPlushEnding.ROOMS:
  var x0: float=room[1];var x1: float=room[2];var z0: float=room[3];var z1: float=room[4]
  var eye:=Vector3(lerpf(x0,x1,.12),1.65,lerpf(z0,z1,.88));var target:=Vector3(lerpf(x0,x1,.8),1.2,lerpf(z0,z1,.2))
  if MOOD_VIEWS.has(room[0]):eye=MOOD_VIEWS[room[0]][0];target=MOOD_VIEWS[room[0]][1]
  author.pose(game,eye-Vector3.UP*1.65,target);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
  game.player.position=eye-Vector3.UP*1.65
  for i in range(8):await game.get_tree().process_frame
  if wait>0.:
   var t:=0.
   while t<wait:
    game.world.tick(.016,true);t+=.016;await game.get_tree().process_frame
  await capture(game,output,"mood-"+str(room[0]).replace(" ","-"))
 if "--mood-extra" in OS.get_cmdline_user_args():
  for key in MOOD_EXTRA:
   author.pose(game,MOOD_EXTRA[key][0]-Vector3.UP*1.65,MOOD_EXTRA[key][1]);game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for i in range(8):await game.get_tree().process_frame
   await capture(game,output,"extra-"+key)

# 5.3.0: twelve frames of a slow sideways drift at the kitchen hood and the
# clown, once per variant with one suspect switched off. Pixels that jump
# between neighbouring frames are sparkle.
func sparkle_frames(game: Node3D,output: String) -> void:
 game._new_shift();game.intro.skip();game.set_process(false);game.player.active=false;game.player.set_physics_process(false)
 var author=load("res://art-direction/itch_capture.gd").new()
 var variants:=["base","noclown","nofog","noglow","nossil","nossr","nolamps","nossao"]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--variants="):variants=Array(arg.trim_prefix("--variants=").split(","))
 for variant in variants:
  game._build_world("none");game.player.active=false
  var w: PlayWorld=game.world;var env:=w.environment.environment
  match variant:
   "noclown":(w.find_child("KitchenClown",true,false) as Node3D).hide()
   "nofog":env.volumetric_fog_enabled=false
   "noglow":env.glow_enabled=false
   "nossil":env.ssil_enabled=false
   "nossr":env.ssr_enabled=false
   "nossao":env.ssao_enabled=false
   "plainpanels","checkpanels":
    for m: MeshInstance3D in w.find_child("KitchenClown",true,false).find_children("FauxLeatherPanel*","MeshInstance3D",true,false):
     if variant=="plainpanels":m.material_override=w.mat(Color("7a5a44"),null,.8)
     for arg in OS.get_cmdline_user_args():
      if arg.begins_with("--panel-code="):
       var sh:=Shader.new();sh.code="shader_type spatial;
"+arg.trim_prefix("--panel-code=");var sm:=ShaderMaterial.new();sm.shader=sh;m.material_override=sm
     var arrays:=m.mesh.surface_get_arrays(0);var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     var bad:=0;var tiny:=0
     for n in normals:
      if not n.is_finite() or n.length()<.5:bad+=1
     var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
     for t in range(0,idx.size(),3):
      if (verts[idx[t+1]]-verts[idx[t]]).cross(verts[idx[t+2]]-verts[idx[t]]).length()<1e-10:tiny+=1
     var tangents=arrays[Mesh.ARRAY_TANGENT]
     var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var badu:=0;var lo:=Vector2(1e9,1e9);var hi:=-lo
     for u in uvs:
      if not u.is_finite():badu+=1
      else:lo=lo.min(u);hi=hi.max(u)
     print("UV ",m.name," bad ",badu," range ",lo," ",hi)
     print("PANEL ",m.name," verts ",verts.size()," badnormals ",bad," degenerate ",tiny," tangents ",0 if tangents==null else tangents.size()," scale ",m.global_transform.basis.get_scale())
   "nopanels","nobell","nostitches","nohem":
    var key: String={"nopanels":"FauxLeatherPanel","nobell":"TarnishedCostumeBell","nostitches":"IndividualWaxedStitches","nohem":"RolledHemAndSeamWelts"}[variant]
    for m: MeshInstance3D in w.find_child("KitchenClown",true,false).find_children("*","MeshInstance3D",true,false):
     if str(m.name).begins_with(key):
      m.hide()
      var mat=m.get_active_material(0)
      if mat is StandardMaterial3D:print("PART ",m.name," metal ",mat.metallic," rough ",mat.roughness," spec ",mat.metallic_specular," aabb ",m.get_aabb().size)
   "nohair","nocap","noskin","nocloth","noother":
    var clown: Node3D=w.find_child("KitchenClown",true,false)
    for m: MeshInstance3D in clown.find_children("*","MeshInstance3D",true,false):
     var shaders:=[]
     for i in range(m.mesh.get_surface_count()):
      var mat:=m.get_active_material(i)
      shaders.append(mat.shader.resource_path.get_file() if mat is ShaderMaterial and mat.shader else "std")
     var kind:="hair" if "matted_locks.gdshader" in shaders else "cap" if "patched-cap.gdshader" in shaders or "Cap" in str(m.get_parent().name)+str(m.name) else "skin" if "clown_skin.gdshader" in shaders else "cloth" if "soaked_cloth.gdshader" in shaders else "other"
     if variant=="no"+kind:m.hide();print("HIDE ",kind," ",m.name," ",shaders)
   "nolamps":
    for l: Light3D in w.find_children("*","Light3D",true,false):
     if l.global_position.distance_to(Vector3(-13.25,2.5,-31.25))<3.5:l.hide();print("HID ",l.get_path()," ",l.global_position)
  for i in range(12):
   var eye:=Vector3(-10.9+i*.012,0,-28.6)
   author.pose(game,eye,Vector3(-13.4,2.0,-31.3));game.player.lamp.show();game.player.torch_body.hide();game.hud.hide()
   for f in range(3):await game.get_tree().process_frame
   await capture(game,output,"sparkle-%s-%02d"%[variant,i])
