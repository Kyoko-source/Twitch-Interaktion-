class_name HappylandLife
extends Node3D

const ROOT:="res://assets/life-v2110/"
const ENTRY:=Vector3(19.8,0,7.8)
const PHOTO:=Vector3(12.69,.548,16.32)
var w: PlayWorld
var bathroom: Node3D
var booth: Node3D
var snack: Node3D
var curtain: ShaderMaterial
var steel: StandardMaterial3D
var enamel: StandardMaterial3D
var rust: StandardMaterial3D
var timber: StandardMaterial3D
var damp: StandardMaterial3D
var motor: AudioStreamPlayer3D
var photo_hum: AudioStreamPlayer3D
var drip: AudioStreamPlayer3D
var room_tone: AudioStreamPlayer3D
var bead: MeshInstance3D
var ripple: MeshInstance3D
var status: StandardMaterial3D
var clock:=0.0
var running:=false
var drip_count:=0
var compressor_count:=0
var lights: Array[Light3D]=[]
var obstacle_bounds: Array[AABB]=[]
var puddles:=0

func group(id: String, pos: Vector3=Vector3.ZERO, yaw: float=0) -> Node3D:
 var root:=Node3D.new();root.name=id;root.position=pos;root.rotation.y=yaw;add_child(root);return root

func build(world: PlayWorld) -> void:
 w=world;name="HappylandEverydayLife"
 steel=w.mat(Color("697775"),load("res://assets/paint.png"),.39,.72)
 steel.normal_enabled=true;steel.normal_texture=w.atmosphere.micro_normal;steel.normal_scale=.14;steel.uv1_triplanar=true;steel.uv1_scale=Vector3.ONE*2
 steel.roughness_texture=load("res://assets/pbr/metal_grate_rusty/roughness.jpg");steel.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 rust=w.mat(Color("694a32"),load("res://assets/aged-plaster.png"),.97,.18)
 enamel=w.mat(Color("b5b4a0"),load("res://assets/paint.png"),.48)
 timber=w.polish.pbr("wood_table_worn",Color("88714e"),1) if ResourceLoader.exists("res://assets/pbr/wood_table_worn/albedo.jpg") else w.materials.wood.duplicate()
 damp=w.mat(Color(.10,.14,.12,.76),null,.065);damp.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;damp.clearcoat_enabled=true;damp.clearcoat=.9;damp.clearcoat_roughness=.08
 for material in [enamel,rust]:
  material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.18;material.uv1_triplanar=true
 _bathroom();_booth();_snackbar();_ordinary_motion();_surface_details()
 if AudioServer.get_bus_index("WashroomSteps")<0:
  AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,"WashroomSteps");AudioServer.set_bus_send(index,"Master")
  var echo:=AudioEffectReverb.new();echo.room_size=.45;echo.damping=.65;echo.dry=1.;echo.wet=.20;AudioServer.add_bus_effect(index,echo)
 for root in [booth,snack]:
  root.set_meta("environment_dressing",true)
  for collider in root.find_children("*","CollisionShape3D",true,false): obstacle_bounds.append(collider.global_transform*collider.shape.get_debug_mesh().get_aabb())

func wall(pos: Vector3, size: Vector3, material: Material) -> void:
 var mesh:=w.box(bathroom,pos,size,material,true);mesh.set_meta("architecture_wall",true)

func print_face(parent: Node3D, id: String, pos: Vector3, size: Vector2, yaw: float=0) -> void:
 if id=="soap" or (id=="closed" and parent==bathroom):
  var face:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size;face.mesh=quad;face.position=pos;face.rotation.y=yaw;face.material_override=w.mat(Color.WHITE,LifePrint.texture(self,id),.96);parent.add_child(face)
  return
 w.artwork(parent,pos,size,LifePrint.texture(self,id),yaw)

func _bathroom() -> void:
 bathroom=group("ChildrensWashroom")
 var tile:=ShaderMaterial.new();tile.shader=load(ROOT+"tiles.gdshader");tile.set_shader_parameter("dirt",load("res://assets/aged-plaster.png"));tile.set_shader_parameter("micro",w.atmosphere.micro_normal)
 var floor:=w.box(bathroom,Vector3(23.48,-.113,7.8),Vector3(7.35,.25,5.4),w.materials.dark,true);floor.set_meta("foot_surface","concrete")
 var tiles:=w.box(bathroom,Vector3(23.48,.016,7.8),Vector3(7.32,.006,5.36),tile);tiles.name="DampFloorTiles"
 wall(Vector3(23.48,1.6,5.1),Vector3(7.35,3.2,.18),tile)
 wall(Vector3(23.48,1.6,10.5),Vector3(7.35,3.2,.18),tile)
 wall(Vector3(27.15,1.6,7.8),Vector3(.18,3.2,5.4),tile)
 w.box(bathroom,Vector3(23.48,3.27,7.8),Vector3(7.48,.14,5.5),w.materials.dark,true)
 for z in [6.86,8.74]: w.box(bathroom,Vector3(19.79,1.25,z),Vector3(.40,2.5,.10),timber,true)
 w.box(bathroom,Vector3(19.79,2.52,7.8),Vector3(.40,.12,1.98),timber,true)
 print_face(bathroom,"wc",Vector3(19.60,2.98,7.8),Vector2(1.45,.36),-PI/2)
 var paint:=w.mat(Color("667b68"),load("res://assets/paint.png"),.89)
 for x in [22.4,24.6,26.8]:
  w.box(bathroom,Vector3(x,1.2,9.20),Vector3(.07,2.12,2.35),paint,true)
  for z in [8.13,10.15]: w.tube(bathroom,Vector3(x,.02,z),Vector3(x,.18,z),.024,steel)
 for x in [23.5,25.7]: _toilet(Vector3(x,.019,9.66))
 var open_door:=Node3D.new();open_door.name="OpenCubicleDoor";open_door.position=Vector3(22.52,0,8.01);open_door.rotation.y=-1.51;bathroom.add_child(open_door)
 w.box(open_door,Vector3(.97,1.2,0),Vector3(1.94,2.12,.065),paint,true)
 w.tube(open_door,Vector3(1.76,1.15,.055),Vector3(1.76,1.15,.12),.025,steel)
 var closed:=w.box(bathroom,Vector3(25.7,1.2,8.01),Vector3(2.02,2.12,.075),paint,true);closed.name="LockedCubicleDoor"
 (closed.get_child(0) as StaticBody3D).set_meta("interaction","life:locked_wc")
 w.box(bathroom,Vector3(24.96,1.25,7.955),Vector3(.08,.15,.035),steel)
 w.tube(bathroom,Vector3(24.96,1.22,7.91),Vector3(25.1,1.22,7.91),.016,steel)
 print_face(bathroom,"closed",Vector3(25.7,1.70,7.962),Vector2(1.20,.28),PI)
 for x in [21.5,23.1,24.7]: _sink(Vector3(x,0,5.68))
 for x in [21.5,23.1,24.7,26.2]:
  w.atmosphere.decal(bathroom,2,Vector3(x,.72,5.196),Vector2(.72,1.1),Vector3.ZERO,Color(.28,.38,.23,.72))
 # Plumbing is clipped to the wall, including shut-off valves and fasteners.
 w.tube(bathroom,Vector3(20.2,.28,5.23),Vector3(26.65,.28,5.23),.026,steel)
 for x in [21.5,23.1,24.7]:
  w.tube(bathroom,Vector3(x,.28,5.23),Vector3(x,.58,5.58),.018,steel)
  for y in [.33,.52]: w.box(bathroom,Vector3(x,y,5.235),Vector3(.07,.045,.04),rust)
 for x in [22.3,23.9]:
  var soap:=w.box(bathroom,Vector3(x,1.18,5.26),Vector3(.24,.39,.13),enamel)
  w.box(soap,Vector3(0,-.10,.09),Vector3(.17,.055,.12),steel)
  if x>23: soap.rotation.z=.16;w.box(soap,Vector3(.02,.08,.072),Vector3(.12,.13,.008),w.materials.dark)
  else: print_face(bathroom,"soap",Vector3(x,1.22,5.334),Vector2(.20,.055))
 for z in [6.05,9.75]: _fixture(Vector3(23.3,3.13,z),Color("9bbbad"),.62,bathroom)
 print_face(bathroom,"wc",Vector3(26.5,1.85,5.235),Vector2(.70,.17))
 # A real grated drain, fixed below the tile surface rather than floating.
 w.box(bathroom,Vector3(23.7,.023,7.05),Vector3(.30,.012,.30),w.materials.dark)
 for i in range(7): w.box(bathroom,Vector3(23.57+i*.043,.031,7.05),Vector3(.016,.010,.26),steel)
 _puddle(bathroom,Vector3(23.6,.027,6.84),Vector2(1.05,.46),3)
 _puddle(bathroom,Vector3(25.5,.027,9.72),Vector2(.48,.29),8)
 for i in range(8):
  var paper:=w.box(bathroom,Vector3(20.65+i*.19,.027,9.45+sin(i*3.7)*.22),Vector3(.16,.004,.12),enamel);paper.rotation.y=i*.7

func _toilet(pos: Vector3) -> void:
 var unit:=Node3D.new();unit.name="ChildToilet";unit.position=pos;bathroom.add_child(unit)
 var bowl:=SurfaceDetails.vessel(unit,Vector3(0,.14,0),.28,.24,.14,.026,enamel,w.mat(Color("777e66"),null,.48),"CeramicBowl");bowl.scale.z=1.28
 w.box(unit,Vector3(0,.10,.08),Vector3(.30,.20,.39),enamel,true)
 var seat:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.192;ring.outer_radius=.246;ring.rings=36;ring.ring_segments=10;seat.mesh=ring;seat.position=Vector3(0,.435,0);seat.scale=Vector3(1,.40,1.26);seat.material_override=w.materials.dark;unit.add_child(seat)
 w.box(unit,Vector3(0,.62,.28),Vector3(.48,.51,.19),enamel,true)
 w.box(unit,Vector3(0,.889,.28),Vector3(.51,.035,.22),enamel)
 w.tube(unit,Vector3(.22,.72,.18),Vector3(.29,.72,.14),.022,steel)
 w.tube(unit,Vector3(0,.43,.19),Vector3(0,.55,.26),.065,enamel)
 var water:=w.tube(unit,Vector3(0,.23,0),Vector3(0,.234,0),.105,damp);water.scale.z=1.2
 for side in [-1,1]: w.tube(unit,Vector3(side*.13,.005,.12),Vector3(side*.13,.01,.12),.025,steel)

func _sink(pos: Vector3) -> void:
 var unit:=Node3D.new();unit.name="ChildWashbasin";unit.position=pos;bathroom.add_child(unit)
 var basin:=SurfaceDetails.vessel(unit,Vector3(0,.56,0),.17,.28,.14,.018,enamel,w.mat(Color("8e9b83"),null,.35),"BasinInterior");basin.scale.z=.78
 w.box(unit,Vector3(0,.60,-.19),Vector3(.46,.17,.24),enamel,true)
 w.tube(unit,Vector3(0,.56,0),Vector3(0,.32,0),.031,steel)
 w.tube(unit,Vector3(0,.32,0),Vector3(0,.32,-.42),.031,steel)
 var tap:=PackedVector3Array([Vector3(0,.71,-.18),Vector3(0,.91,-.18),Vector3(0,.95,-.14),Vector3(0,.95,-.02),Vector3(0,.91,.02)])
 for i in range(tap.size()-1): w.tube(unit,tap[i],tap[i+1],.019,steel)
 w.tube(unit,Vector3(-.08,.75,-.18),Vector3(.08,.75,-.18),.016,steel)
 w.tube(unit,Vector3(0,.578,0),Vector3(0,.584,0),.027,steel)
 # Dark mottled metal gives a dull reflection without an expensive extra viewport.
 w.box(unit,Vector3(0,1.26,-.45),Vector3(.63,.58,.026),steel)
 w.box(unit,Vector3(0,1.26,-.433),Vector3(.56,.51,.009),w.mat(Color("596a61"),load("res://assets/paint.png"),.20,.82))

func _fixture(pos: Vector3, color: Color, energy: float, parent: Node3D) -> void:
 w.box(parent,pos,Vector3(1.15,.10,.22),steel)
 for x in [-.43,.43]: w.tube(parent,pos+Vector3(x,.05,0),Vector3(pos.x+x,3.2 if parent==bathroom else 2.25,pos.z),.012,steel)
 var glow:=w.mat(color);glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=.35
 w.box(parent,pos-Vector3(0,.058,0),Vector3(1.04,.018,.16),glow)
 var light:=OmniLight3D.new();light.position=pos-Vector3(0,.19,0);light.light_color=color;light.light_energy=energy;light.omni_range=5;parent.add_child(light);lights.append(light)

func _booth() -> void:
 booth=group("AbandonedPhotoBooth",Vector3(13, .016,16.25),PI)
 var paint:=w.mat(Color("69443e"),load("res://assets/paint.png"),.69,.22)
 w.box(booth,Vector3(0,.10,0),Vector3(1.62,.20,1.32),steel,true)
 w.box(booth,Vector3(0,1.21,-.60),Vector3(1.62,2.22,.10),paint,true)
 for x in [-.77,.77]: w.box(booth,Vector3(x,1.21,0),Vector3(.08,2.22,1.27),paint,true)
 w.box(booth,Vector3(0,2.32,0),Vector3(1.67,.14,1.36),paint,true)
 w.box(booth,Vector3(-.48,1.04,.05),Vector3(.53,1.93,1.15),paint,true)
 w.box(booth,Vector3(.28,.48,-.18),Vector3(.72,.11,.61),w.materials.dark,true)
 for x in [.02,.54]: w.tube(booth,Vector3(x,.20,-.31),Vector3(x,.43,-.31),.025,steel)
 print_face(booth,"photo",Vector3(0,2.31,.698),Vector2(1.46,.34))
 w.box(booth,Vector3(-.48,1.44,.645),Vector3(.40,.43,.045),w.materials.dark)
 w.tube(booth,Vector3(-.48,1.45,.67),Vector3(-.48,1.45,.71),.082,steel)
 w.tube(booth,Vector3(-.48,1.45,.714),Vector3(-.48,1.45,.72),.057,w.mat(Color("122824"),null,.14,.15))
 w.box(booth,Vector3(-.48,1.0,.66),Vector3(.18,.035,.025),w.materials.dark)
 for x in [-.56,-.40]: w.tube(booth,Vector3(x,.79,.66),Vector3(x,.79,.69),.025,steel)
 w.tube(booth,Vector3(-.06,2.16,.53),Vector3(.72,2.16,.53),.021,steel)
 curtain=ShaderMaterial.new();curtain.shader=load(ROOT+"curtain.gdshader");curtain.set_shader_parameter("cloth_map",load("res://assets/pbr/fabric_pattern_07/albedo.jpg"))
 var cloth:=MeshInstance3D.new();var grid:=PlaneMesh.new();grid.size=Vector2(.29,1.79);grid.subdivide_width=14;grid.subdivide_depth=24;cloth.mesh=grid;cloth.position=Vector3(.56,1.24,.53);cloth.rotation.x=PI/2;cloth.material_override=curtain;booth.add_child(cloth)
 for x in [.43,.52,.61,.70]: w.tube(booth,Vector3(x,2.16,.53),Vector3(x,2.13,.53),.012,steel)
 var photo:=w.box(booth,Vector3(.31,.538,-.07),Vector3(.13,.008,.39),enamel,true);photo.name="ForgottenPhotoStrip"
 (photo.get_child(0) as StaticBody3D).set_meta("interaction","life:photo")
 var picture:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.13,.39);picture.mesh=quad;picture.position=Vector3(.31,.544,-.07);picture.rotation.x=-PI/2;picture.rotation.z=.07;picture.material_override=w.mat(Color.WHITE,load(ROOT+"photostrip-v2.png"),.9);booth.add_child(picture)
 # Both cut ends are physically visible, with copper strands; no plug reaches a socket.
 var cord:=PackedVector3Array([Vector3(-.82,.13,-.25),Vector3(-1.0,.025,-.24),Vector3(-1.10,.025,.05),Vector3(-.95,.025,.23)])
 for i in range(cord.size()-1): w.tube(booth,cord[i],cord[i+1],.012,w.materials.dark)
 for i in range(3): w.tube(booth,Vector3(-.95,.025+i*.004,.23),Vector3(-.93+i*.006,.027,.255),.002,w.mat(Color("a07038"),null,.5,.6))
 var other:=PackedVector3Array([Vector3(-1.10,.025,.48),Vector3(-1.34,.025,.52),Vector3(-1.45,.05,-.20),Vector3(-1.42,.21,-.59)])
 for i in range(other.size()-1): w.tube(booth,other[i],other[i+1],.012,w.materials.dark)
 for i in range(3): w.tube(booth,Vector3(-1.10,.025+i*.004,.48),Vector3(-1.08+i*.006,.027,.46),.002,rust)
 w.box(booth,Vector3(-1.42,.22,-.76),Vector3(.13,.13,.04),enamel)
 w.tube(booth,Vector3(-1.42,.21,-.59),Vector3(-1.42,.21,-.72),.022,w.materials.dark)
 _fixture(Vector3(.25,2.17,-.23),Color("c9b58c"),.22,booth)

func _snackbar() -> void:
 snack=group("ClosedHappylandSnackBar",Vector3(16.95,.016,16.24),PI)
 var red:=w.mat(Color("70483d"),load("res://assets/paint.png"),.8)
 w.box(snack,Vector3(0,.61,0),Vector3(4.05,.64,1.14),red,true)
 w.box(snack,Vector3(0,.975,.0),Vector3(4.18,.09,1.25),steel,true)
 for x in [-1.86,1.86]:
  w.box(snack,Vector3(x,.16,-.40),Vector3(.09,.32,.10),steel)
  w.box(snack,Vector3(x,.16,.40),Vector3(.09,.32,.10),steel)
 # Customer-facing planks, chipped edge strips and actual cabinet hinges.
 for i in range(16): w.box(snack,Vector3(-1.9+i*.25,.62,.581),Vector3(.21,.61,.025),timber)
 for x in [-1.2,0,1.2]:
  w.box(snack,Vector3(x,.61,-.584),Vector3(1.10,.60,.03),red)
  for y in [.3,.75]: w.box(snack,Vector3(x-.48,y,-.61),Vector3(.04,.08,.035),steel)
 for x in [-1.15,-.40]: _slush(snack,Vector3(x,1.022,-.05),Color("753327") if x<-.8 else Color("52633d"))
 print_face(snack,"menu",Vector3(.12,2.43,-.73),Vector2(2.73,1.70))
 # Frame and menu backing are mounted against the existing south wall.
 print_face(snack,"closed",Vector3(1.37,1.18,.64),Vector2(.93,.23))
 var cup:=SurfaceDetails.vessel(snack,Vector3(.85,1.024,.16),.19,.077,.05,.007,enamel,enamel,"MouldyDrinkCup")
 w.tube(cup,Vector3(0,.10,0),Vector3(0,.112,0),.059,w.mat(Color("263e29"),null,.96))
 for i in range(13):
  var a:=i*2.39;var mould:=w.sphere(cup,Vector3(sin(a)*.045,.12+cos(a*3)*.006,cos(a)*.045),.011,w.mat(Color("71866a"),null,1));mould.scale.y=.35
 w.tube(cup,Vector3(.02,.1,.01),Vector3(.045,.31,.016),.005,w.materials.red)
 w.box(snack,Vector3(0,.09,.15),Vector3(3.95,.035,1.18),steel)
 w.box(snack,Vector3(.95,.125,.65),Vector3(1.20,.035,.32),rust)
 for i in range(17):
  var fry:=w.box(snack,Vector3(.44+fmod(i*.137,.97),.15+floori(i/9.)*.018,.55+fmod(i*.079,.23)),Vector3(.13,.019,.018),w.materials.gold);fry.rotation.y=i*1.41
 w.box(snack,Vector3(-1.72,1.065,.30),Vector3(.28,.07,.20),enamel)
 for i in range(4): w.box(snack,Vector3(-1.72,1.11+i*.012,.30),Vector3(.26,.008,.18),enamel)
 _puddle(self,Vector3(16.4,.020,15.20),Vector2(.75,.35),13)

func _slush(parent: Node3D, pos: Vector3, color: Color) -> void:
 var root:=Node3D.new();root.name="CrustedSlushMachine";root.position=pos;parent.add_child(root)
 w.box(root,Vector3(0,.145,0),Vector3(.61,.29,.53),steel)
 var glass:=w.mat(Color(.38,.47,.35,.19),null,.20);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
 var tub:=SurfaceDetails.vessel(root,Vector3(0,.30,0),.42,.24,.21,.012,glass,glass,"SlushReservoir");tub.scale.z=.87
 var dried:=w.tube(root,Vector3(0,.31,0),Vector3(0,.48,0),.205,w.mat(color,load("res://assets/aged-plaster.png"),.93));dried.scale.z=.86
 w.box(root,Vector3(0,.74,0),Vector3(.53,.045,.47),w.materials.dark)
 w.tube(root,Vector3(0,.31,.22),Vector3(0,.31,.36),.028,steel)
 w.tube(root,Vector3(0,.31,.36),Vector3(0,.24,.36),.024,steel)
 w.tube(root,Vector3(0,.35,.31),Vector3(0,.49,.31),.015,w.materials.dark)
 w.box(root,Vector3(0,.025,.27),Vector3(.33,.035,.31),steel)
 for x in [-.12,-.06,0,.06,.12]: w.box(root,Vector3(x,.048,.27),Vector3(.012,.005,.27),w.materials.dark)
 for i in range(8): w.sphere(root,Vector3(sin(i*3.1)*.025,.27+i*.012,.355),.012,rust)

func emitter(file: String, pos: Vector3, db: float, distance_value: float, loop: bool=false) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.name=file.get_basename();source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;source.stream=load(ROOT+file)
 if loop:
  var wav:=source.stream.duplicate() as AudioStreamWAV;wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_end=int(wav.get_length()*wav.mix_rate);source.stream=wav
 source.position=pos;source.volume_db=db;source.max_distance=distance_value;source.unit_size=1.6;source.attenuation_filter_cutoff_hz=2600;add_child(source);return source

func _ordinary_motion() -> void:
 photo_hum=emitter("photo-hum.wav",Vector3(13,1,16.25),-27,4,true)
 motor=emitter("compressor.wav",Vector3(-11,1,-21.7)+ServiceAnnex.OFFSET,-19,6)
 drip=emitter("bucket-drop.wav",Vector3(26.2,.28,6.3),-14,7)
 room_tone=emitter("washroom-air.wav",Vector3(24,2.4,8),-30,7,true)
 for source in w.soundscape.beds:
  if source.stream.resource_path.ends_with("fridge.wav"): source.volume_db=-34
 status=w.mat(Color("466a44"));status.emission_enabled=true;status.emission=Color("86a469")
 w.box(self,Vector3(-10.65,1.81,-21.205)+ServiceAnnex.OFFSET,Vector3(.024,.018,.009),status)
 w.tube(bathroom,Vector3(26.2,3.19,6.1),Vector3(26.2,2.50,6.1),.032,steel)
 w.tube(bathroom,Vector3(26.2,2.50,6.1),Vector3(26.2,2.46,6.3),.032,steel)
 for y in [2.68,3.06]: w.box(bathroom,Vector3(26.2,y,5.99),Vector3(.13,.045,.21),rust)
 SurfaceDetails.vessel(bathroom,Vector3(26.2,.019,6.3),.31,.20,.15,.012,steel,w.mat(Color("53594b"),null,.66),"CondensationBucket")
 w.tube(bathroom,Vector3(26.2,.16,6.3),Vector3(26.2,.166,6.3),.163,damp)
 var arc:=PackedVector3Array()
 for i in range(17):
  var t:=PI*i/16.;arc.append(Vector3(26.2+cos(t)*.198,.29+sin(t)*.23,6.3))
 for i in range(16): w.tube(bathroom,arc[i],arc[i+1],.009,steel)
 bead=w.sphere(bathroom,Vector3(26.2,2.44,6.3),.015,damp);bead.scale.y=1.7
 ripple=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.08;ring.outer_radius=.084;ring.rings=32;ring.ring_segments=5;ripple.mesh=ring;ripple.material_override=damp;ripple.position=Vector3(26.2,.170,6.3);bathroom.add_child(ripple)

func _puddle(parent: Node3D, pos: Vector3, size: Vector2, seed_value: int) -> void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(40):
  var a:=TAU*i/40.;var b:=TAU*(i+1)/40.
  var ra:=.89+.07*sin(i*1.9+seed_value);var rb:=.89+.07*sin((i+1)*1.9+seed_value)
  SurfaceDetails.triangle(st,Vector3.ZERO,Vector3(cos(a)*size.x*ra,0,sin(a)*size.y*ra),Vector3(cos(b)*size.x*rb,0,sin(b)*size.y*rb),Vector3.UP)
 var wet:=ShaderMaterial.new();wet.shader=load(ROOT+"water-film.gdshader");wet.set_shader_parameter("span",size)
 var mesh:=MeshInstance3D.new();mesh.name="ThinWaterFilm";mesh.mesh=st.commit();mesh.position=pos;mesh.material_override=wet;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);puddles+=1

func _surface_details() -> void:
 # One shared closed cushion mesh, with a depressed top and full side walls.
 # Keep the existing fitted collider and per-seat fabric material.
 var cushion:=_cushion_mesh()
 for seat in w.annex.get_children():
  if not str(seat.name).begins_with("CinemaSeat"): continue
  for mesh in seat.get_children():
   if mesh is MeshInstance3D and mesh.position.y>.4 and mesh.position.y<.5:
    mesh.mesh=cushion;mesh.set_meta("depressed_cushion",true)
 for x in [21.5,23.1,24.7]:
  for side in [-1,1]:
   var mark:=w.box(bathroom,Vector3(x+side*.21,.60,5.245),Vector3(.035,.10,.018),rust)
   w.tube(mark,Vector3(0,0,.011),Vector3(0,0,.015),.011,steel)

func _cushion_mesh() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(20):
  for col in range(20):
   var points: Array[Vector3]=[]
   for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
    var x: float=((col+corner.x)/20.-.5)*.63;var z: float=((row+corner.y)/20.-.5)*.64
    points.append(Vector3(x,.09-.037*exp(-(x*x+z*z)*30.),z))
   SurfaceDetails.triangle(st,points[0],points[1],points[2],Vector3.UP);SurfaceDetails.triangle(st,points[1],points[3],points[2],Vector3.UP)
 for side in range(4):
  for i in range(20):
   var a:=Vector3.ZERO;var b:=Vector3.ZERO
   if side<2:
    a=Vector3((i/20.-.5)*.63,0,(-.32 if side==0 else .32));b=a+Vector3(.63/20.,0,0)
   else:
    a=Vector3((-.315 if side==2 else .315),0,(i/20.-.5)*.64);b=a+Vector3(0,0,.64/20.)
   a.y=.09-.037*exp(-(a.x*a.x+a.z*a.z)*30.);b.y=.09-.037*exp(-(b.x*b.x+b.z*b.z)*30.)
   var aa:=Vector3(a.x,-.09,a.z);var bb:=Vector3(b.x,-.09,b.z);var normal: Vector3=[Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT][side]
   SurfaceDetails.triangle(st,a,aa,b,normal);SurfaceDetails.triangle(st,b,aa,bb,normal)
 SurfaceDetails.triangle(st,Vector3(-.315,-.09,-.32),Vector3(.315,-.09,-.32),Vector3(-.315,-.09,.32),Vector3.DOWN)
 SurfaceDetails.triangle(st,Vector3(.315,-.09,-.32),Vector3(.315,-.09,.32),Vector3(-.315,-.09,.32),Vector3.DOWN)
 st.generate_normals();return st.commit()

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.28,.08,-.28),Vector3(.56,1.62,.56))
 for bounds in obstacle_bounds:
  if guard.intersects(bounds): return false
 return true

func safe_pose(point: Vector3) -> bool:
 return point.x>19.48 and point.x<27.0 and point.z>5.24 and point.z<10.36 and point.y>-.1 and point.y<2.8

func apply_room_audio(guard: NightGuard) -> void:
 guard.step_player.bus="WashroomSteps" if safe_pose(guard.global_position) else "Master"

func interact(id: String) -> String:
 if id=="locked_wc": return "Verriegelt. Der Riegel lässt sich von außen nicht bewegen."
 return ""

func tick(delta: float, active: bool) -> void:
 for source in [photo_hum,room_tone]:
  if active and not source.playing: source.play()
 for source in [photo_hum,room_tone,motor,drip]: source.stream_paused=not active
 if not active: return
 var before:=clock;clock+=delta;curtain.set_shader_parameter("clock",clock)
 var cycle:=fmod(clock,31.)
 if floori((before+26.)/31.)!=floori((clock+26.)/31.): motor.play();compressor_count+=1
 status.emission_energy_multiplier=.45 if cycle>5 and cycle<14 else .025
 var t:=fmod(clock,5.4)
 bead.visible=t<.72;bead.position.y=2.44-2.25*pow(minf(t/.72,1.),2)
 if floori((before+4.68)/5.4)!=floori((clock+4.68)/5.4): drip.play();drip_count+=1
 ripple.visible=t>=.72 and t<1.35;ripple.scale=Vector3.ONE*(.3+clampf((t-.72)/.63,0,1)*1.4)

func quality(value: int) -> void:
 for light in lights: light.shadow_enabled=value>0 and not OS.has_feature("web")

func snapshot() -> Dictionary:
 return {"clock":clock,"bathroom":true,"photo":ResourceLoader.exists(ROOT+"photostrip-v2.png"),"drips":drip_count,"compressors":compressor_count,"curtain":curtain.get_shader_parameter("clock"),"hum":photo_hum.playing,"paused":photo_hum.stream_paused,"puddles":puddles}
