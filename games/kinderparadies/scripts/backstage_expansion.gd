class_name BackstageExpansion
extends Node3D

const ROOT:="res://assets/backstage-v270/"
const THRONE_POS:=Vector3(13.4,.20,-11.0)
const DOCS:={
 "plan":{"title":"Bestandsplan · Technischer Dienst","text":"HAPPYLAND — PERSONALPLAN\n\nHinter dem Party Raum liegen Bühne und Kostümkammer. Küche und Kino erreicht man über den nördlichen Verbindungsgang.\n\nHandschriftlicher Nachtrag:\n‚Altbestand hinter der Westwand: NICHT BETRETEN. Die Tür wurde im Bestandsplan nie eingetragen.‘"},
 "repairs":{"title":"Das Wartungsbuch","text":"03.06. — Lüftung gereinigt. Geruch bleibt.\n05.06. — Kostümraum: Haken nachziehen.\n07.06. — Spind 04 von innen verformt.\n08.06. — Schlüssel eingezogen. Keine Freigabe.\n\nDarunter, in einer anderen Handschrift:\n‚Keine Ursache im Bericht angeben. Rückfragen ausschließlich an die Leitung.‘"}}
var w: PlayWorld
var throne: Node3D
var costumes: Array[Node3D]=[]
var masks: Array[Node3D]=[]
var exit_root: Node3D
var exit_leaf: Node3D
var exit_collider: CollisionShape3D
var exit_sign: MeshInstance3D
var clean: Node3D
var ruined: Node3D
var clean_light: OmniLight3D
var old_light: OmniLight3D
var door_audio: AudioStreamPlayer3D
var scare_audio: AudioStreamPlayer3D
var costume_light: OmniLight3D
var scene_lights: Array[Light3D]=[]
var anomaly:="none"
var exit_open:=false
var exit_started:=false
var exit_finished:=false
var exit_clock:=0.0
var triggered:=false
var attack:=0.0
var shock:=0.0
var elapsed:=0.0

func build(world: PlayWorld) -> void:
 w=world;name="BackstageExpansion"
 _stage();_costume_room();_maintenance_story();_unsettling_exit();_room_palettes()
 scare_audio=AudioStreamPlayer3D.new();scare_audio.name="CostumeSting";scare_audio.stream=load("res://assets/scares-v260/ragged-scream.wav");scare_audio.unit_size=5;scare_audio.max_distance=12;scare_audio.volume_db=-4;scare_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(scare_audio)

func model(parent: Node3D, file: String, pos: Vector3, yaw: float=0) -> Node3D:
 var instance: Node3D=(load(ROOT+file+".glb") as PackedScene).instantiate();parent.add_child(instance);instance.position=pos;instance.rotation.y=yaw
 for mesh in instance.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var m:=mesh.get_active_material(i) as StandardMaterial3D
   if not m: continue
   m=m.duplicate();m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.22;m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*3
   if "velvet" in m.resource_name or "canvas" in m.resource_name or "patches" in m.resource_name:
    m.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg") if "velvet" in m.resource_name else load("res://assets/mascot-v251/mascot-rabbit_plush-fur.png");m.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");m.uv1_scale=Vector3.ONE*7;m.normal_scale=.30;m.roughness=.98
   elif "walnut" in m.resource_name: m.albedo_texture=load("res://assets/wood.png");m.uv1_scale=Vector3.ONE*1.2
   elif "enamel" in m.resource_name: m.albedo_texture=load("res://assets/paint.png")
   mesh.set_surface_override_material(i,m)
 return instance

func solid(parent: Node3D, pos: Vector3, size: Vector3, title: String="FittedSolid") -> StaticBody3D:
 var body:=StaticBody3D.new();body.name=title;body.position=pos;parent.add_child(body)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;collision.shape=box;body.add_child(collision);return body

func wall(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
 var mesh:=w.box(parent,pos,size,material,true);mesh.set_meta("architecture_wall",true);return mesh

func print_board(parent: Node3D, id: String, pos: Vector3, size: Vector2, yaw: float=0, interactive: bool=false) -> MeshInstance3D:
 var board:=w.artwork(parent,pos,size,EnvironmentPrint.texture(parent,id),yaw);board.name="Document_"+id
 if interactive: solid(board,Vector3.ZERO,Vector3(size.x,size.y,.055),"ReadableDocument").set_meta("interaction","story:"+id)
 return board

func fixture(parent: Node3D, pos: Vector3, color: Color, power: float, radius: float) -> OmniLight3D:
 var housing:=w.box(parent,pos,Vector3(.68,.07,.22),w.materials.dark)
 var emission:=w.mat(color);emission.emission_enabled=true;emission.emission=color;emission.emission_energy_multiplier=.6
 w.box(housing,Vector3(0,-.045,0),Vector3(.57,.022,.14),emission)
 var light:=OmniLight3D.new();light.position=pos-Vector3(0,.14,0);light.light_color=color;light.light_energy=power;light.omni_range=radius;light.shadow_enabled=not OS.has_feature("web");parent.add_child(light);scene_lights.append(light);return light

func curtain(parent: Node3D, center: Vector3, width: float, height: float, material: Material) -> void:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(18):
  for col in range(24):
   for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
    var u: float=(col+corner.x)/24.0;var v: float=(row+corner.y)/18.0
    tool.set_uv(Vector2(u*2,v*4));tool.add_vertex(center+Vector3((u-.5)*width,-v*(height+.035*sin(u*53)),cos(u*TAU*7)*.055))
 tool.generate_normals();var mesh:=MeshInstance3D.new();mesh.name="HangingStageCurtain";mesh.mesh=tool.commit();mesh.material_override=material;parent.add_child(mesh)

func _stage() -> void:
 var stage:=Node3D.new();stage.name="BirthdayStage";add_child(stage)
 var wood:=w.mat(Color("70563c"),load("res://assets/wood.png"),.86);wood.uv1_triplanar=true
 var cloth:=w.polish.pbr("fabric_pattern_07",Color("61353f"),3);cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
 var deck:=w.box(stage,Vector3(14.8,.10,-10.85),Vector3(7,.20,2.38),wood,true);deck.set_meta("foot_surface","wood")
 # Broad physical ramp, with no step/jump requirement into the backstage door.
 var ramp:=w.box(stage,Vector3(17.30,.06054,-9.09658),Vector3(1.7,.08,1.21655),wood,true);ramp.rotation.x=.165149;ramp.set_meta("foot_surface","wood")
 for x in [11.35,18.25]:
  w.box(stage,Vector3(x,2.12,-11.86),Vector3(.18,4.1,.18),wood,true)
  w.tube(stage,Vector3(x,4.12,-11.86),Vector3(x,4.12,-12.045),.035,w.materials.rust)
 w.box(stage,Vector3(14.8,4.15,-11.83),Vector3(7.1,.30,.28),wood)
 w.tube(stage,Vector3(11.4,3.99,-11.72),Vector3(18.2,3.99,-11.72),.035,w.materials.metal)
 curtain(stage,Vector3(11.77,3.92,-11.71),.68,3.65,cloth)
 curtain(stage,Vector3(15.85,3.92,-11.71),.72,3.65,cloth)
 curtain(stage,Vector3(18.17,3.92,-11.71),.20,3.65,cloth)
 for x in [11.55,11.8,12.05,15.6,15.85,16.1,18.12,18.22]: w.tube(stage,Vector3(x,4.0,-11.72),Vector3(x,3.92,-11.71),.013,w.materials.metal)
 throne=model(stage,"birthday-throne",THRONE_POS);throne.name="BirthdayThrone"
 for part in [{"p":Vector3(0,.72,0),"s":Vector3(1.5,.32,1.15)},{"p":Vector3(0,1.7,-.48),"s":Vector3(1.45,1.85,.22)},{"p":Vector3(-.75,1.23,.05),"s":Vector3(.22,.24,1.04)},{"p":Vector3(.75,1.23,.05),"s":Vector3(.22,.24,1.04)}]: solid(throne,part.p,part.s,"ThroneSolid")
 var key:=SpotLight3D.new();key.position=Vector3(13.4,4.0,-9.25);stage.add_child(key);key.look_at(THRONE_POS+Vector3(0,1.4,0));key.light_color=Color("efd3a0");key.light_energy=2.8;key.spot_range=7;key.spot_angle=40;key.shadow_enabled=not OS.has_feature("web");scene_lights.append(key)
 w.box(stage,key.position,Vector3(.22,.18,.23),w.materials.dark);w.tube(stage,key.position+Vector3(0,.12,0),Vector3(13.4,7.27,-9.25),.017,w.materials.dark);w.box(stage,Vector3(13.4,7.28,-9.25),Vector3(.17,.04,.17),w.materials.dark)
 print_board(stage,"costumes",Vector3(17.30,3.20,-12.00),Vector2(1.3,.68))

func _costume_room() -> void:
 var room:=Node3D.new();room.name="CostumeRoom";add_child(room)
 var plaster:=w.materials.wall.duplicate() as StandardMaterial3D;plaster.albedo_color=Color("91a6a0")
 var floor:=w.box(room,Vector3(15.55,.045,-15.45),Vector3(8.5,.31,6.5),w.materials.wood,true);floor.set_meta("foot_surface","wood")
 var threshold:=w.box(room,Vector3(17.3,.10,-12.19),Vector3(1.7,.20,.38),w.materials.wood,true);threshold.set_meta("foot_surface","wood")
 wall(room,Vector3(11.25,1.86,-15.45),Vector3(.20,3.32,6.5),plaster)
 wall(room,Vector3(19.8,1.86,-15.45),Vector3(.20,3.32,6.5),plaster)
 wall(room,Vector3(15.55,1.86,-18.70),Vector3(8.75,3.32,.20),plaster)
 w.box(room,Vector3(15.55,3.58,-15.45),Vector3(8.75,.12,6.7),w.materials.dark,true)
 for x in [16.45,18.15]: w.box(room,Vector3(x,1.56,-12.20),Vector3(.10,2.72,.32),w.materials.wood,true)
 w.box(room,Vector3(17.3,2.94,-12.2),Vector3(1.80,.12,.32),w.materials.wood,true)
 w.box(room,Vector3(15.55,.33,-18.51),Vector3(8.26,.18,.08),w.materials.teal)
 w.tube(room,Vector3(11.8,2.78,-18.05),Vector3(18.4,2.78,-18.05),.035,w.materials.metal)
 for x in [11.85,15.1,18.35]: w.tube(room,Vector3(x,2.78,-18.05),Vector3(x,3.51,-18.05),.023,w.materials.metal)
 w.tube(room,Vector3(11.85,2.78,-17.65),Vector3(11.85,2.78,-13.35),.035,w.materials.metal)
 for z in [-17.65,-13.35]: w.tube(room,Vector3(11.85,2.78,z),Vector3(11.85,3.51,z),.023,w.materials.metal)
 for i in range(7):
  var root:=Node3D.new();root.name="HangingCostume%02d"%i;room.add_child(root)
  root.position=Vector3(12.4+i*1.26,.24,-18.02) if i<5 else Vector3(11.9,.24,-15.7+(i-5)*1.8)
  root.rotation.y=0 if i<5 else PI/2
  var body:=model(root,"empty-costume",Vector3.ZERO);body.name="EmptyClothBody"
  var head:=model(root,"costume-mask",Vector3(0,2.02,0));head.name="CostumeHead";masks.append(head);costumes.append(root)
  var tint: Color=[Color("b5ac8f"),Color("a5aaa3"),Color("a9907c"),Color("c1b493"),Color("a7b0a5"),Color("b4a487"),Color("8d9a96")][i]
  for mesh in root.find_children("*","MeshInstance3D",true,false):
   for s in range(mesh.mesh.get_surface_count()):
    var material:=mesh.get_active_material(s) as StandardMaterial3D
    if material and "canvas" in material.resource_name: material.albedo_color*=tint
  if i==1: head.hide() # One empty collar makes the arrangement less uniform.
  solid(root,Vector3(0,1.16,0),Vector3(.85,1.95,.55),"CostumeSolid")
  w.tube(root,Vector3(0,2.54,-.03),Vector3(0,2.36,-.03),.013,w.materials.metal)
  for side in [-1,1]:
   w.tube(root,Vector3(0,2.36,-.03),Vector3(side*.30,1.62,-.03),.012,w.materials.metal)
   w.tube(root,Vector3(side*.30,1.62,-.03),Vector3(0,1.62,-.03),.012,w.materials.metal)
  head.rotation.z=(-.07 if i%2 else .12);root.set_meta("hanging_costume",true)
 # A dressing counter is anchored against the east wall, clear of the aisle.
 var vanity:=Node3D.new();vanity.name="BackstageDressingTable";vanity.position=Vector3(19.22,.2,-15.0);vanity.rotation.y=-PI/2;room.add_child(vanity)
 w.box(vanity,Vector3(0,.81,0),Vector3(2.2,.10,.60),w.materials.wood,true)
 for side in [-1,1]:
  for z in [-.22,.22]: w.box(vanity,Vector3(side*.95,.38,z),Vector3(.07,.76,.07),w.materials.metal,true)
 var mirror:=w.mat(Color("596964"),load("res://assets/paint.png"),.26,.72)
 w.box(vanity,Vector3(0,1.53,-.25),Vector3(2.1,1.1,.06),w.materials.wood)
 w.box(vanity,Vector3(0,1.53,-.21),Vector3(1.93,.92,.015),mirror)
 for x in [-.85,-.43,0,.43,.85]:
  w.sphere(vanity,Vector3(x,2.13,-.19),.045,w.materials.cream)
 for i in range(3): w.box(vanity,Vector3(-.6+i*.42,.94,.02),Vector3(.26,.14,.22),w.materials.red if i%2 else w.materials.cream)
 costume_light=fixture(room,Vector3(16.1,3.49,-15.5),Color("a4c7b7"),.95,6)
 fixture(room,Vector3(12.7,3.49,-15.3),Color("b2a790"),.40,3.8)

func _maintenance_story() -> void:
 var root:=Node3D.new();root.name="MaintenanceEvidence";w.server_room.add_child(root)
 # Replace the old repeated generic poster on this exact wall with a unique plan.
 for child in w.server_room.find_children("*","MeshInstance3D",true,false):
  if child.has_meta("mounted_art") and child.global_position.distance_to(Vector3(-13,2.2,-6.835))<.1: child.hide()
 print_board(root,"plan",Vector3(-14.1,1.94,-6.82),Vector2(1.65,1.24),0,true)
 print_board(root,"repairs",Vector3(-12.55,1.82,-6.82),Vector2(.92,.69),0,true)
 var locker:=model(root,"staff-locker",Vector3(-11.45,.018,-2.5),PI);locker.name="DentedStaffLocker"
 solid(locker,Vector3(0,1.04,0),Vector3(.76,2.08,.55),"LockerSolid")
 # Mounted pipe labels and a locked chain reinforce the same maintenance story.
 var lock_mat:=w.mat(Color("847447"),load("res://assets/paint.png"),.65,.6)
 w.box(locker,Vector3(.24,1.02,.405),Vector3(.07,.085,.03),lock_mat)
 for i in range(8): w.tube(locker,Vector3(.20+i*.01,.99,.40),Vector3(.21+i*.01,1.005,.41),.006,w.materials.metal)

func _unsettling_exit() -> void:
 exit_root=Node3D.new();exit_root.name="DeliveryExit";exit_root.position=Vector3(-10.2,0,9.4);exit_root.rotation.y=PI/2;add_child(exit_root)
 var plaster:=w.materials.wall.duplicate() as StandardMaterial3D;plaster.albedo_color=Color("9da9a0")
 var floor:=w.box(exit_root,Vector3(0,-.14,-2.85),Vector3(2.5,.3,5.8),w.materials.dark,true);floor.set_meta("foot_surface","concrete")
 for side in [-1,1]: wall(exit_root,Vector3(side*1.25,1.55,-2.85),Vector3(.16,3.1,5.8),plaster)
 wall(exit_root,Vector3(0,1.55,-5.7),Vector3(2.65,3.1,.16),plaster)
 w.box(exit_root,Vector3(0,3.12,-2.85),Vector3(2.65,.16,5.8),w.materials.dark,true)
 for x in [-.87,.87]: w.box(exit_root,Vector3(x,1.34,0),Vector3(.12,2.68,.32),w.materials.metal,true)
 w.box(exit_root,Vector3(0,2.72,0),Vector3(1.86,.12,.32),w.materials.metal,true)
 exit_leaf=Node3D.new();exit_leaf.name="DeliveryDoorLeaf";exit_leaf.position=Vector3(-.80,0,0);exit_root.add_child(exit_leaf)
 w.box(exit_leaf,Vector3(.80,1.32,0),Vector3(1.6,2.64,.09),w.mat(Color("425b51"),load("res://assets/paint.png"),.83))
 var body:=solid(exit_leaf,Vector3(.80,1.32,0),Vector3(1.6,2.64,.09),"DeliveryDoorSolid");body.set_meta("interaction","delivery_exit");exit_collider=body.get_child(0)
 for face in [-1,1]:
  w.box(exit_leaf,Vector3(1.39,1.10,face*.072),Vector3(.08,.25,.055),w.materials.metal)
  w.tube(exit_leaf,Vector3(1.14,1.12,face*.12),Vector3(1.43,1.12,face*.12),.025,w.materials.metal)
 # A static wall button remains reachable after the hinged leaf opens.
 var button:=w.box(exit_root,Vector3(1.02,1.3,.19),Vector3(.15,.22,.08),w.materials.metal)
 solid(button,Vector3.ZERO,Vector3(.16,.23,.09),"DoorControl").set_meta("interaction","delivery_exit")
 exit_sign=print_board(exit_root,"exit",Vector3(0,3.18,.17),Vector2(1.45,.60))
 clean=Node3D.new();clean.name="ImpossibleCleanCorridor";exit_root.add_child(clean)
 ruined=Node3D.new();ruined.name="DecayedCorridor";exit_root.add_child(ruined)
 for group_node in [clean,ruined]:
  var bright: bool=group_node==clean
  var upper:=w.mat(Color("e1d8b5") if bright else Color("5f6557"),null if bright else load("res://assets/aged-plaster.png"),.82)
  var lower:=w.mat(Color("4baaa7") if bright else Color("234741"),null if bright else load("res://assets/paint.png"),.62)
  for side in [-1,1]:
   w.box(group_node,Vector3(side*1.16,2.07,-2.85),Vector3(.025,1.82,5.5),upper)
   w.box(group_node,Vector3(side*1.14,.58,-2.85),Vector3(.03,1.12,5.5),lower)
   w.box(group_node,Vector3(side*1.10,1.16,-2.85),Vector3(.035,.055,5.5),w.materials.gold)
  for i in range(5):
   var board:=Node3D.new();board.position=Vector3(-1.125,1.98,-1.0-i*.87);board.rotation.y=PI/2;group_node.add_child(board)
   w.box(board,Vector3.ZERO,Vector3(.58,.68,.014),w.mat(Color("e7dfb9") if bright else Color("83795c"),null if bright else load("res://assets/aged-plaster.png"),.94))
   var colour:=w.mat([Color("b35246"),Color("d0ad3a"),Color("437e9c")][i%3] if bright else Color("3d2621"))
   for k in range(6):
    var a:=k*TAU/6;w.sphere(board,Vector3(sin(a)*.12,cos(a)*.12,.018),.07,colour).scale.z=.08
   w.tube(board,Vector3(0,-.23,.018),Vector3(0,-.10,.018),.008,lower)
  w.box(group_node,Vector3(0,1.3,-5.58),Vector3(1.5,2.6,.07),lower)
  w.box(group_node,Vector3(.52,1.1,-5.51),Vector3(.23,.05,.06),w.materials.metal)
 clean_light=fixture(clean,Vector3(0,2.98,-2.6),Color("fff0d0"),2.4,6.0)
 old_light=fixture(ruined,Vector3(0,2.98,-2.6),Color("789e91"),.48,5.3)
 clean.hide()
 door_audio=AudioStreamPlayer3D.new();door_audio.name="DeliveryHinge";door_audio.stream=load("res://assets/door.ogg");door_audio.position=exit_root.position;door_audio.unit_size=2;door_audio.volume_db=-15;door_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(door_audio)

func _room_palettes() -> void:
 # Local wall/wood treatment plus physical lamp colours; never a full-screen tint.
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.has_meta("architecture_wall"): continue
  var m:=mesh.material_override as StandardMaterial3D
  if not m: continue
  var p: Vector3=mesh.global_position
  if p.x>=6.79 and p.z<1.61 and p.z>=-12.25:
   m=m.duplicate();m.albedo_color=Color("ccb39c");mesh.material_override=m
  elif w.server_room.is_ancestor_of(mesh):
   m=m.duplicate();m.albedo_color=Color("91aaa7");mesh.material_override=m
  elif w.annex.is_ancestor_of(mesh) and p.x< -9.5:
   m=m.duplicate();m.albedo_color=Color("b5b78e");mesh.material_override=m
  elif w.annex.is_ancestor_of(mesh) and p.x> -6.3:
   m=m.duplicate();m.albedo_color=Color("a48683");mesh.material_override=m
 for light in w.practicals:
  var p:=light.position
  if p.x>6.8 and p.z<1.6: light.light_color=Color("edc191")
  elif w.server_room.safe_pose(Vector3(p.x,1,p.z)): light.light_color=Color("88b1ba")
  elif p.x< -9.5 and p.z< -13.3: light.light_color=Color("cbd2a0")
  elif p.x> -6.3 and p.x<3.8 and p.z< -13.3: light.light_color=Color("c1a0b0")
 # Aged painted panelling provides colour close to the player's eye level.
 var rose:=w.mat(Color("8a5551"),load("res://assets/paint.png"),.95);rose.normal_enabled=true;rose.normal_texture=w.atmosphere.micro_normal;rose.normal_scale=.2
 for x in [6.925,19.61]:
  for segment in ([Vector2(-10.99,1.90),Vector2(-3.0,8.8)] if x<7 else [Vector2(-5.3,13.3)]):
   w.box(self,Vector3(x,.70,segment.x),Vector3(.025,1.35,segment.y),rose)
   w.box(self,Vector3(x+(.022 if x<7 else -.022),1.40,segment.x),Vector3(.04,.06,segment.y),w.materials.wood)

func configure(id: String) -> void:
 anomaly=id
 clean.visible=id=="false_exit";ruined.visible=not clean.visible
 if id=="party_dark":
  for light in scene_lights:
   if light.global_position.z>=-12.2 and light.global_position.x>6.8: light.light_energy=0
 elif id=="lights_red":
  for light in scene_lights: light.light_color=Color("e22c28")

func interact_exit(player: NightGuard) -> void:
 # Never sweep a closing leaf through someone standing on the threshold.
 var p:=exit_root.to_local(player.position)
 if exit_open and p.z> -1.85 and p.z<.65 and absf(p.x)<1.2: return
 exit_open=not exit_open;door_audio.play()
 if exit_open and anomaly=="false_exit" and not exit_finished: exit_started=true

func tick(delta: float, active: bool, player: NightGuard) -> void:
 door_audio.stream_paused=not active;scare_audio.stream_paused=not active
 if not active: return
 elapsed+=delta;shock=move_toward(shock,0,delta*2.2)
 var player_local:=exit_root.to_local(player.position)
 if not exit_open and exit_leaf.rotation.y>.1 and player_local.z> -1.85 and player_local.z<.65 and absf(player_local.x)<1.2: exit_open=true
 exit_leaf.rotation.y=move_toward(exit_leaf.rotation.y,PI*.49 if exit_open else 0,delta*1.8)
 var moving:=absf(exit_leaf.rotation.y-(PI*.49 if exit_open else 0))>.01
 exit_collider.disabled=moving or (exit_open and player_local.x<-.46 and player_local.z> -1.9 and player_local.z<.3)
 if anomaly=="false_exit" and exit_started and not exit_finished:
  exit_clock+=delta
  if exit_clock>3.2:
   clean_light.light_energy=0
   var p:=exit_root.to_local(player.position)
   if p.z>.8: exit_open=false
  if exit_clock>3.65:
   _finish_exit()
 if anomaly=="costume_wakes":
  var head:=masks[3];var target:=head.global_position
  if not triggered and elapsed>.8 and w.encounters.visible_to(player,target,3.7):
   triggered=true;attack=0;scare_audio.global_position=target;scare_audio.play();shock=1.0
  if triggered:
   attack+=delta
   _costume_pose()

func _finish_exit() -> void:
 if exit_finished: return
 exit_finished=true;clean.hide();ruined.show()
 (exit_sign.material_override as StandardMaterial3D).albedo_texture=EnvironmentPrint.texture(self,"exit_changed")

func _costume_pose() -> void:
 var head:=masks[3];var amount:=smoothstep(0,.22,attack)
 head.rotation.x=-.48*amount;head.rotation.z=.42*amount;head.rotation.y=.42*sin(minf(attack,.65)*6)
 costumes[3].rotation.x=-sin(clampf(attack/.85,0,1)*PI)*.16
 costume_light.light_energy=.12 if attack<.12 else .95

func quality(value: int) -> void:
 for light in scene_lights: light.shadow_enabled=value>0 and not OS.has_feature("web")

func serialize() -> Dictionary:
 return {"id":anomaly,"exit_open":exit_open,"exit_started":exit_started,"exit_finished":exit_finished,"exit_clock":exit_clock,"costume_triggered":triggered,"costume_attack":attack}

func restore(data: Variant) -> void:
 if not data is Dictionary or data.get("id","")!=anomaly: return
 for field in ["exit_open","exit_started","exit_finished","costume_triggered"]:
  if not data.get(field,false) is bool: return
 for field in ["exit_clock","costume_attack"]:
  var value: Variant=data.get(field,0)
  if not (value is float or value is int) or not is_finite(float(value)): return
 exit_open=data.get("exit_open",false);exit_leaf.rotation.y=PI*.49 if exit_open else 0
 if anomaly=="false_exit":
  exit_started=data.get("exit_started",false);exit_clock=clampf(float(data.get("exit_clock",0)),0,10)
  if data.get("exit_finished",false): _finish_exit()
 if anomaly=="costume_wakes":
  triggered=data.get("costume_triggered",false);attack=clampf(float(data.get("costume_attack",0)),0,60)
  if triggered: _costume_pose()

func safe_pose(p: Vector3) -> bool:
 if p.x>11.36 and p.x<19.64 and p.z< -12.15 and p.z> -18.55 and p.y>=.15 and p.y<3.3: return true
 var q:=exit_root.to_local(p)
 return absf(q.x)<1.1 and q.z<.1 and q.z> -5.5 and p.y>-.2 and p.y<2.9

func snapshot() -> Dictionary:
 return {"costumes":costumes.size(),"costume_triggered":triggered,"costume_attack":attack,"costume_audio":scare_audio.playing,"costume_paused":scare_audio.stream_paused,"exit_open":exit_open,"exit_angle":exit_leaf.rotation.y,"exit_started":exit_started,"exit_finished":exit_finished,"clean_corridor":clean.visible,"exit_clock":exit_clock,"anomaly":anomaly}
