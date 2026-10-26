extends Node3D

# Authoring scene, excluded from all player exports. Captures the actual native
# world with deterministic dolly moves; no player saves or settings are touched.
var phase:="capture"
var world: PlayWorld
var player: NightGuard
var intro: ElevatorIntro
var attack: DoorFailure
var clock:=0.0
var last_shot:=""
var clean:=false
var probe:=false
var shots: Array[Dictionary]=[]
var shade: ColorRect
var camera_fill: OmniLight3D
var duration:=75.0
var active_anomaly:="none"

func shot(id: String, start: float, end: float, a: Vector3, b: Vector3, look: Vector3, fov: float=62, torch: bool=false, anomaly: String="none") -> void:
 shots.append({"id":id,"start":start,"end":end,"a":a,"b":b,"look":look,"fov":fov,"torch":torch,"anomaly":anomaly})

func _ready() -> void:
 clean="--archive-film" in OS.get_cmdline_user_args();probe="--media-probe" in OS.get_cmdline_user_args()
 AudioServer.set_bus_mute(0,true)
 world=PlayWorld.new();add_child(world);world.build();world.set_anomaly("none");world.quality(2);world.brightness(1.28)
 player=NightGuard.new();add_child(player);player.release();player.set_physics_process(false);player.camera.current=true
 player.camera.fov=62;player.camera.near=.05;player.lamp.light_size=.025;player.lamp.spot_angle=27;player.lamp.light_energy=3.8
 player.lamp.light_volumetric_fog_energy=.4;player.torch_body.wait=10000;player.torch_body.burst=-1
 camera_fill=OmniLight3D.new();camera_fill.light_energy=.24;camera_fill.light_color=Color("d7c5a7");camera_fill.omni_range=7;player.camera.add_child(camera_fill)
 intro=ElevatorIntro.new();add_child(intro);intro.build(world,player);intro.start();intro.overlay.hide();intro.phone.hide()
 for door in intro.doors: door.position.x=signf(door.position.x)*1.89
 attack=DoorFailure.new();player.camera.add_child(attack)
 var layer:=CanvasLayer.new();add_child(layer);shade=ColorRect.new();shade.color=Color.BLACK;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(shade)
 get_viewport().msaa_3d=Viewport.MSAA_4X;get_viewport().use_taa=true
 if clean: _clean_world();_film_shots()
 else: _trailer_shots()
 if probe: call_deferred("_probes")

func _trailer_shots() -> void:
 shot("lift",2,7,Vector3(-8,1.65,19.2),Vector3(-8,1.65,16.9),Vector3(-6.5,2,5),65)
 shot("playground",7,12,Vector3(-3,1.8,8.3),Vector3(-1,2.0,7.3),Vector3(4.5,2.4,.9),65)
 shot("arcade",12,16,Vector3(8.7,1.3,14.4),Vector3(9.2,1.4,14.9),Vector3(9,1.25,16.55),55)
 shot("birthday",16,20,Vector3(11.2,1.5,-4.5),Vector3(10.8,1.4,-5.2),Vector3(10.2,1.15,-7),56)
 shot("cook",23,28,Vector3(-11.9,1.6,-17.9)+ServiceAnnex.OFFSET,Vector3(-12.3,1.65,-18.25)+ServiceAnnex.OFFSET,Vector3(-14.4,1.55,-19.1)+ServiceAnnex.OFFSET,54,true)
 shot("cinema",28,32,Vector3(-3.8,1.5,-18.1)+ServiceAnnex.OFFSET,Vector3(-3.15,1.65,-18.1)+ServiceAnnex.OFFSET,Vector3(2.5,2,-18)+ServiceAnnex.OFFSET,64)
 shot("doors",35,40,Vector3(-3.2,1.65,-8.4),Vector3(-3.2,1.65,-9.2),Vector3(-3.2,1.8,-12.2),57)
 shot("green",40,43,Vector3(-4.3,1.65,-11.1),Vector3(-4.3,1.65,-13.3),Vector3(-4.3,1.5,-21),63,true)
 shot("costumes",44,47,Vector3(17.7,1.65,-13.4),Vector3(17,1.65,-13.8),Vector3(13.2,1.6,-16.2),62,true)
 shot("tube",47,50,CrawlTubes.route(4.9),CrawlTubes.route(6.9),CrawlTubes.route(9.0),68,true)
 shot("mascot",50,53,Vector3(17.15,1.75,-3.5),Vector3(17.45,1.8,-3.1),Vector3(17.95,2.7,.3),56,true)
 shot("crocodile",53,55,Vector3(6.4,1.3,10.0),Vector3(6.7,1.2,10.1),Vector3(10.5,1.5,11.3),62,true)
 shot("visitor",55,56.3,Vector3(-7.5,1.65,-3.4),Vector3(-7.4,1.65,-3.8),Vector3(-6.1,1.1,-6.6),60,true,"corridor_crossing")
 shot("floating",56.3,58,Vector3(-1.8,1.8,8.8),Vector3(-1.4,1.8,8.5),Vector3(2.5,1.5,6),67,false,"balls_float")
 shot("vent",58,59.8,Vector3(-4.7,1.6,-18.0)+ServiceAnnex.OFFSET,Vector3(-4.5,1.6,-18.1)+ServiceAnnex.OFFSET,Vector3(-1.9,2.3,-20.1)+ServiceAnnex.OFFSET,65,true)
 shot("attack",60.4,61.2,Vector3(-2.15,1.65,-15),Vector3(-2.15,1.65,-15),Vector3(-2.15,1.65,-21),65)

func _film_shots() -> void:
 duration=34
 shot("welcome",0,5,Vector3(-6.5,1.65,10.4),Vector3(-4.7,1.65,9.9),Vector3(2,2.0,2.5),68)
 shot("play",5,11,Vector3(-2.1,1.6,7),Vector3(-1,1.8,5.5),Vector3(3.7,2.3,.7),66)
 shot("balls",11,17,Vector3(-1.6,1.5,9),Vector3(-1.5,1.5,8.5),Vector3(2.6,.8,6),64)
 shot("party",17,23,Vector3(11.8,1.65,-4.1),Vector3(11.4,1.6,-4.8),Vector3(10.2,1.2,-7),61)
 shot("games",23,28,Vector3(8.5,1.4,14.2),Vector3(9.3,1.5,14.2),Vector3(9,1.2,16.5),63)
 shot("farewell",28,34,Vector3(-5.1,1.65,8.4),Vector3(-5.4,1.65,9.0),Vector3(-8.5,1.5,5.8),64)

func _clean_world() -> void:
 var env:=world.environment.environment
 env.fog_enabled=false;env.volumetric_fog_enabled=false;env.sdfgi_enabled=false;env.ssil_enabled=false;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.70;env.ambient_light_color=Color("d9e5ef");env.tonemap_exposure=1.12
 world.atmosphere.hide();world.polish.party_mascot.hide();world.room_horror.hide();world.archive.hide();world.props.wall_paintings.hide()
 world.playground.inflatable.hide()
 for x in [-5.0,3.0,12.0]:
  for z in [-6.0,4.0,13.0]:
   var light:=OmniLight3D.new();light.position=Vector3(x,4.8,z);light.light_color=Color("fff0cf");light.light_energy=2.1;light.omni_range=12;world.add_child(light)
 for fog in world.native_art.fog_volumes: fog.hide()
 for tile in world.props.floor_tiles: tile.show()
 for mesh in world.native_art.get_children():
  if mesh is MeshInstance3D and mesh.mesh is PlaneMesh: mesh.hide()
 world.materials.wall.albedo_texture=null;world.materials.wall.albedo_color=Color("e8dfbf");world.materials.wall.normal_enabled=false
 for id in ["blue","red","gold","teal","cream"]:
  var material: StandardMaterial3D=world.materials[id];material.albedo_color=material.albedo_color.lightened(.28);material.normal_scale=.08
 for light in world.practicals: light.light_energy*=2;light.light_color=Color("ffe5b5")
 for spot in world.native_art.spots: spot.light_energy*=1.7;spot.light_color=Color("ffe6c0")
 for mesh in world.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("mounted_art"): mesh.hide()
  var standard:=mesh.material_override as StandardMaterial3D
  if standard and standard.albedo_texture and standard.albedo_texture.resource_path.ends_with("aged-plaster.png"):
   standard.albedo_texture=null;standard.normal_enabled=false;standard.albedo_color=standard.albedo_color.lightened(.35)
  var material:=mesh.material_override as ShaderMaterial
  if material and material.shader and "blood_map" in material.shader.code: mesh.hide()
 world.text(world,"HAPPYLAND",Vector3(-.5,3.6,-11.98),1.0,Color("a34d35"))
 world.text(world,"Hier beginnt dein Abenteuer!",Vector3(-.5,2.9,-11.98),.38,Color("567850"))

func _process(delta: float) -> void:
 if probe: return
 _frame(delta)
 clock+=delta
 if clock>=duration:
  print("MEDIA CAPTURE COMPLETE ","archive-film" if clean else "trailer",": ",duration,"s")
  get_tree().quit()

func _frame(delta: float) -> void:
 var selected: Dictionary={}
 for item in shots:
  if clock>=item.start and clock<item.end: selected=item;break
 shade.visible=selected.is_empty()
 if selected.is_empty(): return
 if selected.id!=last_shot:
  last_shot=selected.id;print("MEDIA SHOT ",last_shot," @ ",clock)
  if selected.anomaly!=active_anomaly:
   # Only these reversible variants are used by the edit.
   world.terrors.configure("none");world.encounters.configure("none")
   if active_anomaly=="balls_float":
    for i in range(world.ball_transforms.size()): world.balls.multimesh.set_instance_transform(i,world.ball_transforms[i])
   world.set_anomaly(selected.anomaly);active_anomaly=selected.anomaly
  if selected.id=="green": world.passages.restore({"chosen":-1,"open":[true,false]})
  if selected.id=="attack": attack.start_patrol(world,player.camera)
 var t: float=clampf((clock-float(selected.start))/(float(selected.end)-float(selected.start)),0,1)
 var pos: Vector3=selected.a.lerp(selected.b,smoothstep(0,1,t))
 if clean: pos+=Vector3(sin(clock*1.7)*.012,sin(clock*2.3)*.009,0)
 player.position=pos-Vector3(0,1.65,0);player.rotation=Vector3.ZERO;player.camera.position=Vector3(0,1.65,0);player.camera.look_at(selected.look);player.camera.fov=selected.fov
 player.lamp.visible=selected.torch;player.torch_body.visible=selected.torch
 camera_fill.visible=not clean;camera_fill.light_energy=.14 if selected.id=="vent" else .26
 if clean:
  world.details.tick(delta,true)
 else:
  world.tick(delta,true)
  if selected.id=="visitor": world.terrors.tick(delta,true,player)
  if selected.id=="attack": attack.tick(delta)
  if selected.id=="lift":
   var open_amount:=smoothstep(2.15,4.0,clock)
   for i in range(2): intro.doors[i].position.x=(-1 if i==0 else 1)*lerpf(.65,1.89,open_amount)

func _probes() -> void:
 var dir:=OS.get_environment("TEMP").path_join("after-play-media-probes"+("-film" if clean else ""));DirAccess.make_dir_recursive_absolute(dir)
 var times: Array=[2.5,8.5,14,18,24.5,29.5,36,41.5,45,48,51.5,54,55.5,57,58.8,60.8] if not clean else [2,8,14,20,25,31]
 for seconds in times:
  clock=seconds;_frame(.1)
  for frame in range(15): await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(dir.path_join(last_shot+".png"))
 print("MEDIA PROBES COMPLETE ",dir);get_tree().quit()
