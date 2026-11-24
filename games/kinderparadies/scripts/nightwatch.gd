class_name Nightwatch
extends Node3D

# Nightwatch Protocol (4.15.0): a seated security shift in a control room far
# below Happyland. Ten CCTV feeds show the real, running world.
# 5.6.0: nights 1-5 from 00:00 to 06:00. The rooms change on the cameras and a
# left click on the change puts it right; something stands at the stair door
# on the left (shutter, 20 %) or sits in the vent on the right (torch, 10 %);
# the generator is restarted by typing when the power runs short.
# The mode owns its state completely and leaves the shared world as it was.

signal ended(reason: String)

const ORIGIN:=Vector3(0,-80,0)
const ROOM_LAYER:=8
const CLICK_LAYER:=1<<19
const EYE:=Vector3(0,1.2,.5)
# Seated view: yaw/pitch of the monitor wall and of the generator, and the
# limits the mouse can pan between.
const FRONT:=Vector2(0,-.03)
const RIGHT:=Vector2(-1.38,-.32)
const YAW_LEFT:=1.78
# 5.5.0: the stair door with its rolling shutter on the left.
const LEFT:=Vector2(1.52,-.06)
const YAW_RIGHT:=-1.72
const EDGE:=.12
const PAN_SPEED:=1.7
const SMOOTH:=7.0
const REASONS:={"missed":"ANOMALY THRESHOLD EXCEEDED","power":"STROMAUSFALL","caught":"ES IST HEREINGEKOMMEN","vent":"ES KAM DURCH DEN SCHACHT","clicks":"ZU VIELE FEHLKLICKS","bunny":"DER HASE IST HEREINGEKOMMEN"}
const DESK_TOP:=.787
const RACK_SHELVES:=[.425,.915,1.40,1.89]
# Ten wall monitors (bottom centre): two rows on the outer racks, two on top
# of the middle rack; the large main monitor stands on the desk.
const MONITOR_SLOTS:=[Vector3(-1.22,1.40,-1.6),Vector3(-.78,1.40,-1.6),Vector3(-.23,1.89,-1.62),Vector3(.23,1.89,-1.62),Vector3(.78,1.40,-1.6),Vector3(1.22,1.40,-1.6),
 Vector3(-1.22,.915,-1.6),Vector3(-.78,.915,-1.6),Vector3(.78,.915,-1.6),Vector3(1.22,.915,-1.6)]
const MAIN_SLOT:=Vector3(0,.787,-.8)
const MAIN_SCALE:=1.35
const GENERATOR_AT:=Vector3(1.95,0,.45)
const SWITCH_KEY_X0:=-.235
const SWITCH_KEY_DX:=.062
const SWITCH_KEY_Z:=[.045,-.035]

var g: Node3D
var w: PlayWorld
var room: Node3D
var cam: Camera3D
var feeds: Array=[]
var main_view: SubViewport
var main_camera: Camera3D
var main_material: ShaderMaterial
var small_materials: Array=[]
var main_label: Label3D
var stamp_label: Label3D
var power_label: Label3D
var gen_label: Label3D
var monitors: Array=[]
var main_monitor: Node3D
var switcher: Node3D
var keys: Array=[]
var meter: Node3D
var key_lit: StandardMaterial3D
var night_env: Environment
# Full-screen view of one camera (left click on a monitor, right click back).
var full: Control
var full_image: TextureRect
var full_label: Label
var full_stamp: Label
var full_banner: Label
var fullscreen:=false
var lights: Array=[]
var anomalies: NightwatchAnomalies
var stalker: NightwatchStalker
var vent: NightwatchVent
var bunny: NightwatchBunny
var torch: SpotLight3D
var beacon: OmniLight3D
var banner_labels: Array=[]
var rng:=RandomNumberGenerator.new()

# Run state, reset by start().
var running:=false
var over:=false
var won:=false
var reason:=""
var night:=1
var level_crawler:=0
var level_clown:=0
var level_bunny:=0
var seconds:=0.0
var power:=100.0
var fixed:=0
var misses:=0
var repairs:=0
var failed_repairs:=0
var active: Array=[]
var spawn_clock:=0.0
var next_spawn:=0.0
var selected:=0
var refresh_index:=0
var view:="monitors"
var yaw:=0.0
var pitch:=0.0
# Where the view wants to look; the camera eases towards it every frame.
var anchor_yaw:=0.0
var sway:=Vector2.ZERO
var qte: Dictionary={}
var message_time:=0.0
var beep_clock:=0.0
var glitch_clock:=0.0
var glitch:=0.0
var ambience_clock:=0.0
var run_id:=0
var new_best:=false
var blackout:=false
var was_dark:=false
var blackout_clock:=0.0
var blackout_wait:=0.0
var torch_time:=0.0
var miss_lock:=0.0
var card_time:=0.0
var critical_clock:=0.0
var alarm_clock:=0.0

# UI and audio.
var layer: CanvasLayer
var hud: Control
var power_bar: ProgressBar
var power_text: Label
var night_text: Label
var clock_text: Label
var sensor_text: Label
var message: Label
var hint: Label
var card: Label
var arrow_left: PanelContainer
var arrow_right: PanelContainer
var qte_panel: PanelContainer
var qte_title: Label
var qte_words: RichTextLabel
var qte_bar: ProgressBar
var qte_time: Label
var hum: AudioStreamPlayer
var beep: AudioStreamPlayer
var buzz: AudioStreamPlayer
var click: AudioStreamPlayer
var switch_sound: AudioStreamPlayer
var engine: AudioStreamPlayer
var thud: AudioStreamPlayer
var distant: AudioStreamPlayer
var chime: AudioStreamPlayer
var cheer: AudioStreamPlayer
var siren: AudioStreamPlayer

func build(game: Node3D) -> void:
 g=game;w=g.world;name="NightwatchProtocol";position=ORIGIN
 room=Node3D.new();room.name="ControlRoom";add_child(room)
 _shell();_desk();_monitor_wall();_generator()
 for mesh: GeometryInstance3D in room.find_children("*","GeometryInstance3D",true,false):mesh.layers=ROOM_LAYER
 cam=Camera3D.new();cam.name="ControlRoomCamera";cam.fov=62;cam.near=.04;cam.far=12;cam.cull_mask=1|ROOM_LAYER|NightwatchVent.LAYER;cam.position=EYE;add_child(cam)
 # The torch in your hand: the only light that reaches into the vent.
 torch=SpotLight3D.new();torch.name="Torch";cam.add_child(torch);torch.position=Vector3(.12,-.1,0);torch.light_color=Color("fff0d6");torch.light_energy=0.
 torch.spot_range=7.;torch.spot_angle=22.;torch.spot_attenuation=.6;torch.shadow_enabled=true;torch.light_cull_mask=ROOM_LAYER|NightwatchVent.LAYER;torch.light_volumetric_fog_energy=0.
 _feeds();_ui();_audio()
 stalker=NightwatchStalker.new();stalker.build(self)
 vent=NightwatchVent.new();vent.build(self)
 bunny=NightwatchBunny.new();bunny.build(self)
 _wall_clock()
 hide();set_process(false)

# ---------------------------------------------------------------- the room
# Real assets: Poly Haven CC0 models (desk, lamp, rack, generator, binder,
# clipboard, notepads, radio, fluorescents, power boxes, bin, multimeter) and
# the modelled CCTV monitors and camera switcher of 4.16.0.

func _model(id: String, parent: Node3D, pos: Vector3, yaw_value: float=0., scale_value: float=1.) -> Node3D:
 var path:="res://assets/models/%s/%s.gltf"%[id,id]
 if id.ends_with(".glb"):path="res://assets/nightwatch-v4160/"+id
 var node:=(load(path) as PackedScene).instantiate() as Node3D
 node.name=id.get_basename().to_pascal_case();parent.add_child(node);node.position=pos;node.rotation.y=yaw_value;node.scale=Vector3.ONE*scale_value
 return node

func _pbr(id: String, tint: Color, scale_value: float) -> StandardMaterial3D:
 var root:="res://assets/pbr/%s/"%id
 var m:=StandardMaterial3D.new();m.albedo_texture=load(root+"albedo.jpg");m.albedo_color=tint
 m.normal_enabled=true;m.normal_texture=load(root+"normal.jpg");m.roughness_texture=load(root+"roughness.jpg");m.roughness=1.
 m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_scale=Vector3.ONE*scale_value;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return m

func _box(parent: Node3D, pos: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
 return w.box(parent,pos,size_value,material)

func _shell() -> void:
 var wall:=_pbr("painted_plaster_wall",Color(.55,.6,.56),.55)
 var floor_mat:=_pbr("concrete_floor_worn_001",Color(.62,.62,.6),.45)
 var ceiling:=_pbr("concrete_floor_worn_001",Color(.42,.43,.42),.4)
 var metal:=_pbr("rusty_painted_metal",Color(.55,.6,.58),.9)
 var grille:=_pbr("metal_plate",Color(.2,.22,.22),2.)
 _box(room,Vector3(0,-.05,-.2),Vector3(5.4,.1,4.6),floor_mat)
 _box(room,Vector3(0,3.25,-.2),Vector3(5.4,.1,4.6),ceiling)
 _box(room,Vector3(0,1.6,-2.15),Vector3(5.4,3.3,.1),wall)
 _box(room,Vector3(0,1.6,1.75),Vector3(5.4,3.3,.1),wall)
 # Left wall with the stair doorway (NightwatchStalker builds the frame).
 _box(room,Vector3(-2.65,1.6,-1.225),Vector3(.1,3.3,2.55),wall)
 _box(room,Vector3(-2.65,1.6,1.605),Vector3(.1,3.3,.99),wall)
 _box(room,Vector3(-2.65,2.75,.55),Vector3(.1,1.1,1.12),wall)
 # Right wall with the vent opening (NightwatchVent builds the duct).
 var vz0:=NightwatchVent.Z-NightwatchVent.W*.5;var vz1:=NightwatchVent.Z+NightwatchVent.W*.5
 var vy0:=NightwatchVent.Y-NightwatchVent.H*.5;var vy1:=NightwatchVent.Y+NightwatchVent.H*.5
 _box(room,Vector3(2.65,1.6,(-2.5+vz0)*.5),Vector3(.1,3.3,vz0+2.5),wall)
 _box(room,Vector3(2.65,1.6,(vz1+2.1)*.5),Vector3(.1,3.3,2.1-vz1),wall)
 _box(room,Vector3(2.65,(vy0-.05)*.5,NightwatchVent.Z),Vector3(.1,vy0+.05,NightwatchVent.W),wall)
 _box(room,Vector3(2.65,(vy1+3.25)*.5,NightwatchVent.Z),Vector3(.1,3.25-vy1,NightwatchVent.W),wall)
 # Skirting, a cable duct along the back wall and a ventilation grille.
 _box(room,Vector3(0,.06,-2.09),Vector3(5.3,.12,.03),metal)
 _box(room,Vector3(2.59,.06,-.2),Vector3(.03,.12,4.5),metal)
 _box(room,Vector3(-2.59,.06,-1.25),Vector3(.03,.12,2.4),metal);_box(room,Vector3(-2.59,.06,1.6),Vector3(.03,.12,.95),metal)
 _box(room,Vector3(0,2.72,-2.07),Vector3(5.2,.08,.06),metal)
 _box(room,Vector3(-1.9,2.35,-2.09),Vector3(.5,.32,.03),metal)
 for k in range(6):_box(room,Vector3(-1.9,2.24+k*.045,-2.07),Vector3(.44,.012,.02),grille)
 # Fluorescent tubes on the ceiling, power boxes, a work lamp and the bin.
 var tubes:=_model("mounted_fluorescent_lights",room,Vector3(0,3.2,-.45))
 tubes.rotation.x=PI
 _model("power_box_01",room,Vector3(-2.58,1.55,-.9),PI/2)
 _model("power_box_01",room,Vector3(2.58,1.3,.85),-PI/2)
 _model("hanging_industrial_lamp",room,Vector3(2.0,3.2,.5))
 var bin:=_model("metal_trash_can",room,Vector3(-1.45,.04,.05),-.4,.5)
 bin.name="WasteBin"
 # Cable from the generator to its wall socket.
 w.tube(room,Vector3(1.75,.12,.55),Vector3(2.5,.12,.6),.018,metal)
 w.tube(room,Vector3(2.5,.12,.6),Vector3(2.56,1.1,.75),.018,metal)
 # Light: weak cool tubes, the warm desk lamp, the glow of the monitor wall.
 _lamp(Vector3(0,3.0,-.45),Color("c9dccd"),.42,5.5,false)
 _lamp(Vector3(-.74,1.3,-.55),Color("ffc98a"),.95,2.6,true)
 _lamp(Vector3(0,1.45,-1.05),Color("8fb7a3"),.6,2.8,false)
 _lamp(Vector3(2.0,1.72,.5),Color("ffd59c"),1.35,3.6,true)

# 5.6.1: a wall clock on the back wall, above the left rack. Hour and
# minute hands show the night from 00:00 to 06:00; the second hand jumps and
# ticks once a real second, through the blackout too (it runs on a battery).
var clock_face: Node3D
var clock_hour: Node3D
var clock_minute: Node3D
var clock_second: Node3D
var clock_tick: AudioStreamPlayer
var clock_step:=0
const CLOCK_AT:=Vector3(-1.05,2.42,-2.08)

func _wall_clock() -> void:
 var metal:=_pbr("rusty_painted_metal",Color(.5,.53,.5),1.4)
 var dial:=StandardMaterial3D.new();dial.albedo_color=Color("d9d4c2");dial.roughness=.85
 var ink:=StandardMaterial3D.new();ink.albedo_color=Color("1d1c1a");ink.roughness=.7
 var red:=StandardMaterial3D.new();red.albedo_color=Color("a3201a");red.roughness=.6
 clock_face=Node3D.new();clock_face.name="WallClock";clock_face.position=CLOCK_AT;room.add_child(clock_face)
 w.tube(clock_face,Vector3(0,0,-.02),Vector3(0,0,.03),.2,metal)
 w.tube(clock_face,Vector3(0,0,.03),Vector3(0,0,.035),.175,dial)
 for i in range(12):
  var a:=float(i)*TAU/12;var mark:=_box(clock_face,Vector3(sin(a)*.15,cos(a)*.15,.037),Vector3(.009 if i%3 else .014,.03,.004),ink);mark.rotation.z=-a
 clock_hour=Node3D.new();clock_hour.position.z=.04;clock_face.add_child(clock_hour);_box(clock_hour,Vector3(0,.04,0),Vector3(.016,.09,.004),ink)
 clock_minute=Node3D.new();clock_minute.position.z=.044;clock_face.add_child(clock_minute);_box(clock_minute,Vector3(0,.06,0),Vector3(.01,.13,.004),ink)
 clock_second=Node3D.new();clock_second.position.z=.048;clock_face.add_child(clock_second);_box(clock_second,Vector3(0,.05,0),Vector3(.004,.15,.003),red)
 w.tube(clock_face,Vector3(0,0,.036),Vector3(0,0,.052),.01,ink)
 for mesh: GeometryInstance3D in clock_face.find_children("*","GeometryInstance3D",true,false):mesh.layers=ROOM_LAYER
 clock_tick=_player(ClockTick.stream(),-17.)

func _tick_wall_clock() -> void:
 if not clock_face:return
 var minutes:=seconds/NightwatchConfig.HOUR*60.
 clock_minute.rotation.z=-fmod(minutes,60.)/60.*TAU
 clock_hour.rotation.z=-fmod(minutes/60.,12.)/12.*TAU
 var step:=int(seconds)
 if step!=clock_step:
  clock_step=step
  clock_second.rotation.z=-float(step%60)/60.*TAU
  clock_tick.stream=ClockTick.stream(step%2==1);clock_tick.pitch_scale=rng.randf_range(.98,1.02);clock_tick.play()

func _lamp(pos: Vector3, color: Color, energy: float, reach: float, shadows: bool) -> void:
 var lamp:=OmniLight3D.new();lamp.position=pos;lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=reach;lamp.light_cull_mask=ROOM_LAYER;lamp.shadow_enabled=shadows;room.add_child(lamp)
 lights.append([lamp,energy])

func _desk() -> void:
 _model("metal_office_desk",room,Vector3(0,0,-.5))
 _model("desk_lamp_arm_01",room,Vector3(-.95,DESK_TOP,-.86),1.1)
 _model("clipboard",room,Vector3(-.52,DESK_TOP,-.28),-.25)
 _model("office_notepads",room,Vector3(-.82,DESK_TOP,-.4),.35)
 _model("vintage_radio_transceiver",room,Vector3(.74,DESK_TOP+.111,-.72),-.45,.85)
 switcher=_model("video-switcher.glb",room,Vector3(0,DESK_TOP,-.16))
 for i in range(10):
  var key:=switcher.find_child("Key%02d"%(i+1),true,false) as MeshInstance3D
  keys.append(key)
  var row:=floori(i/5.0);var col:=i%5
  var z: float=SWITCH_KEY_Z[row];var y:=.03+(.12-z)/.24*.045
  _clickable(switcher,Vector3(SWITCH_KEY_X0+col*SWITCH_KEY_DX,y+.01,z),Vector3(.05,.03,.05),"monitor:%d"%i)
 var book_node:=_model("binder_notebook",room,Vector3(.55,DESK_TOP,-.3),.32)
 book_node.name="ShiftLog"
 var title:=Label3D.new();title.text="SCHICHTBUCH";title.font=load("res://assets/backstage-v270/Caveat.ttf");title.font_size=46;title.pixel_size=.0009;title.position=Vector3(.02,.027,0);title.rotation.x=-PI/2
 title.modulate=Color(.85,.78,.6,.85);title.shaded=true;title.layers=ROOM_LAYER;book_node.add_child(title)

func _screen_shader() -> Shader:
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded,cull_back;
uniform sampler2D feed:source_color,filter_linear,repeat_disable;
uniform float instability=0.0;
uniform float glitch=0.0;
uniform float dim=1.0;
uniform float seed=0.0;
uniform float gain=1.4;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 uv=UV;
 vec2 d=uv-.5;uv=.5+d*(1.0-.035*dot(d,d));
 float line=floor(uv.y*150.0);
 float tear=glitch*(hash(vec2(line,floor(TIME*26.0)+seed))-.5)*.09;
 uv.x+=tear+sin(uv.y*90.0+TIME*2.0)*.0007*(1.0+instability*5.0);
 uv.y=fract(uv.y+glitch*.025*sin(TIME*37.0+seed));
 vec3 c=pow(texture(feed,uv).rgb,vec3(.82));
 float l=dot(c,vec3(.299,.587,.114));
 c=mix(c,vec3(l*.84,l,l*.9),.45)*gain;
 float n=hash(floor(UV*vec2(400.,300.))+floor(TIME*20.)+seed);
 c+=(n-.5)*(.05+instability*.22+glitch*.45);
 c*=.92+.08*sin(UV.y*600.0*3.14159);
 c*=.95+.05*smoothstep(.0,.05,abs(fract(UV.y-TIME*.11)-.5));
 float v=1.-.55*pow(length((UV-.5)*1.25),2.2);
 vec3 glass=vec3(.015,.02,.018);
 ALBEDO=clamp(mix(glass,c*v,dim),0.0,1.0)+vec3(.012)*pow(1.0-abs(dot(NORMAL,VIEW)),3.0);
}"""
 return shader

func _monitor(pos: Vector3, scale_value: float, index: int, shader: Shader) -> Node3D:
 var to_eye:=EYE-pos
 var node:=_model("cctv-monitor.glb",room,pos,atan2(to_eye.x,to_eye.z),scale_value)
 node.name="CCTVMonitor%d"%index if index>=0 else "MainMonitor"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("seed",float(index+2)*17.3)
 (node.find_child("Screen",true,false) as MeshInstance3D).material_override=material
 _clickable(node,Vector3(0,.18,0),Vector3(.45,.37,.34),"monitor:%d"%index if index>=0 else "main")
 return node

func _monitor_wall() -> void:
 var shader:=_screen_shader()
 for x in [-1.0,0.,1.0]:
  var rack:=_model("worn_metal_rack",room,Vector3(x,0,-1.72))
  rack.name="MonitorRack"
 # Boxes of tapes on the shelves behind the main monitor and under the rows.
 for spot in [Vector3(-.22,RACK_SHELVES[1],-1.75),Vector3(.25,RACK_SHELVES[1],-1.75),Vector3(.05,RACK_SHELVES[2],-1.78),Vector3(-1.0,RACK_SHELVES[0],-1.74),Vector3(1.05,RACK_SHELVES[0],-1.74)]:
  var crate:=_model("cardboard_box_01",room,spot,rng.randf_range(-.3,.3),.8)
  crate.name="TapeBox"
 for i in range(MONITOR_SLOTS.size()):
  var monitor:=_monitor(MONITOR_SLOTS[i],1.,i,shader);monitors.append(monitor)
  small_materials.append((monitor.find_child("Screen",true,false) as MeshInstance3D).material_override)
  var label:=_text(monitor,Vector3(-.15,.3,.172),"CAM %02d"%(i+1),15,HORIZONTAL_ALIGNMENT_LEFT);label.name="SmallLabel%d"%i
 main_monitor=_monitor(MAIN_SLOT,MAIN_SCALE,-1,shader)
 main_material=(main_monitor.find_child("Screen",true,false) as MeshInstance3D).material_override
 main_label=_text(main_monitor,Vector3(-.15,.305,.172),"CAM 01",12,HORIZONTAL_ALIGNMENT_LEFT)
 stamp_label=_text(main_monitor,Vector3(.15,.305,.172),"23:00:00",12,HORIZONTAL_ALIGNMENT_RIGHT)
 power_label=_text(main_monitor,Vector3(-.15,.094,.172),"STROM 100 %",11,HORIZONTAL_ALIGNMENT_LEFT)

func _clickable(parent: Node3D, pos: Vector3, size_value: Vector3, id: String) -> void:
 var body:=StaticBody3D.new();body.collision_layer=CLICK_LAYER;body.collision_mask=0;body.set_meta("nightwatch",id);body.position=pos;parent.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_value;shape.shape=box;body.add_child(shape)

func _text(parent: Node3D, pos: Vector3, value: String, font_size: int, align: HorizontalAlignment) -> Label3D:
 var label:=Label3D.new();label.text=value;label.font=load("res://assets/Oswald.ttf");label.font_size=font_size;label.pixel_size=.0008;label.position=pos;label.horizontal_alignment=align
 label.modulate=Color("d8f0d8");label.outline_size=3;label.outline_modulate=Color(0,0,0,.7);label.shaded=false;label.double_sided=false;label.layers=ROOM_LAYER;parent.add_child(label);return label

func _generator() -> void:
 var gen:=_model("portable_generator",room,GENERATOR_AT,-PI/2,1.15)
 gen.name="Generator"
 _clickable(gen,Vector3(0,.3,0),Vector3(.9,.7,.65),"generator")
 meter=_model("retro_multimeter",room,GENERATOR_AT+Vector3(-.05,.665,-.2),-PI/2-.35,.9)
 # Wall-mounted power meter above the generator: dark housing, glass, LED digits.
 var panel_mat:=_pbr("rusty_painted_metal",Color(.25,.27,.27),2.)
 var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.02,.03,.025);glass.roughness=.08;glass.metallic_specular=.9
 _box(room,Vector3(2.585,1.02,.2),Vector3(.05,.2,.4),panel_mat)
 _box(room,Vector3(2.557,1.03,.2),Vector3(.008,.1,.3),glass)
 w.tube(room,Vector3(2.59,.92,.2),Vector3(2.59,.15,.2),.012,panel_mat)
 gen_label=Label3D.new();gen_label.text="";gen_label.font=load("res://assets/Oswald.ttf");gen_label.font_size=54;gen_label.pixel_size=.0008;gen_label.position=Vector3(2.551,1.03,.2)
 gen_label.rotation.y=-PI/2;gen_label.modulate=Color("7dff8a");gen_label.outline_size=0;gen_label.shaded=false;gen_label.layers=ROOM_LAYER;room.add_child(gen_label)
 var caption:=Label3D.new();caption.text="NETZ / GENERATOR";caption.font=load("res://assets/Oswald.ttf");caption.font_size=24;caption.pixel_size=.0008;caption.position=Vector3(2.557,1.105,.2);caption.rotation.y=-PI/2;caption.modulate=Color(.75,.75,.7);caption.shaded=true;caption.layers=ROOM_LAYER;room.add_child(caption)

func _feeds() -> void:
 main_view=_viewport(Vector2i(1280,960),"NightwatchMainFeed")
 main_camera=main_view.get_child(0) as Camera3D
 main_material.set_shader_parameter("feed",main_view.get_texture())
 for i in range(NightwatchConfig.CAMERAS.size()):
  var view_port:=_viewport(Vector2i(320,240),"NightwatchFeed%d"%i)
  var spec: Dictionary=NightwatchConfig.CAMERAS[i]
  var feed_cam:=view_port.get_child(0) as Camera3D;_aim(feed_cam,spec)
  feeds.append(view_port)
  (small_materials[i] as ShaderMaterial).set_shader_parameter("feed",view_port.get_texture())
  (monitors[i].find_child("SmallLabel%d"%i,true,false) as Label3D).text=str(spec.label).get_slice(" · ",0)+" · "+str(spec.label).get_slice(" · ",1)
  # The infrared lamp beside each camera keeps dark rooms readable.
  var ir:=SpotLight3D.new();ir.name="InfraredLamp%d"%i;add_child(ir);ir.global_position=spec.p;ir.look_at(spec.at)
  ir.light_energy=NightwatchConfig.IR_ENERGY;ir.spot_range=NightwatchConfig.IR_RANGE;ir.spot_angle=NightwatchConfig.IR_ANGLE;ir.spot_attenuation=.8;ir.light_color=Color("d8e6dc");ir.light_cull_mask=1;ir.shadow_enabled=false

func _viewport(size_value: Vector2i, title: String) -> SubViewport:
 var port:=SubViewport.new();port.name=title;port.size=size_value;port.world_3d=get_world_3d();port.msaa_3d=Viewport.MSAA_DISABLED;port.positional_shadow_atlas_size=1024
 port.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(port)
 var feed_cam:=Camera3D.new();feed_cam.near=.1;feed_cam.far=46;feed_cam.cull_mask=1;port.add_child(feed_cam);feed_cam.current=true
 return port

# The 4:3 monitors keep the width each camera was framed for in 16:9.
static func feed_fov(spec: Dictionary) -> float:
 return rad_to_deg(2.*atan(tan(deg_to_rad(float(spec.fov))*.5)*16./9.))

func _night_vision() -> Environment:
 if night_env:return night_env
 var base: Environment=get_world_3d().environment
 night_env=base.duplicate() as Environment if base else Environment.new()
 night_env.tonemap_exposure=night_env.tonemap_exposure*NightwatchConfig.FEED_EXPOSURE
 night_env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;night_env.ambient_light_color=Color(.62,.7,.64);night_env.ambient_light_energy=NightwatchConfig.FEED_AMBIENT
 night_env.fog_density=night_env.fog_density*NightwatchConfig.FEED_FOG;night_env.volumetric_fog_density=night_env.volumetric_fog_density*NightwatchConfig.FEED_FOG
 return night_env

func _aim(feed_cam: Camera3D, spec: Dictionary) -> void:
 feed_cam.environment=_night_vision()
 feed_cam.keep_aspect=Camera3D.KEEP_WIDTH;feed_cam.fov=feed_fov(spec)
 feed_cam.global_position=spec.p;feed_cam.look_at(spec.at)

# ---------------------------------------------------------------- UI

func _ui() -> void:
 layer=CanvasLayer.new();layer.name="NightwatchUI";layer.layer=12;add_child(layer)
 hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
 var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);panel.offset_left=-372;panel.offset_right=-30;panel.offset_top=30;panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new();style.bg_color=Color(.02,.035,.03,.72);style.border_color=Color("5d7060");style.border_width_right=3;style.set_content_margin_all(14);style.content_margin_left=18;panel.add_theme_stylebox_override("panel",style);hud.add_child(panel)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",5);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(column)
 night_text=_ui_label("NIGHTWATCH PROTOCOL · NACHT 1",15,Color("9fb59f"));column.add_child(night_text)
 clock_text=_ui_label("00:00",44,Color("eee7d6"));clock_text.name="NightwatchClock";column.add_child(clock_text)
 power_text=_ui_label("STROM 100 %",22,Color("e3efe0"));column.add_child(power_text)
 power_bar=ProgressBar.new();power_bar.custom_minimum_size=Vector2(300,10);power_bar.show_percentage=false;power_bar.max_value=100;power_bar.value=100;power_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("8fd18c");power_bar.add_theme_stylebox_override("fill",fill)
 var back:=StyleBoxFlat.new();back.bg_color=Color(.1,.12,.1,.9);power_bar.add_theme_stylebox_override("background",back);column.add_child(power_bar)
 sensor_text=_ui_label("",16,Color("d9c58e"));column.add_child(sensor_text)
 message=_ui_label("",26,Color("eee7d6"));message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);message.offset_left=-620;message.offset_right=620;message.offset_top=-170;message.offset_bottom=-70;message.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;message.add_theme_color_override("font_outline_color",Color(0,0,0,.9));message.add_theme_constant_override("outline_size",8);message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.add_child(message)
 hint=_ui_label("",16,Color("aab5a6"));hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_top=-52;hint.offset_bottom=-22;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(hint)
 # Small arrows at the screen edges: left to the door, right to the vent.
 arrow_left=_arrow("◀",true);arrow_right=_arrow("▶",false)
 _qte_ui();_full_ui()
 # The card in the middle: the night at the start, 06:00 at the end.
 card=_ui_label("",96,Color("eee7d6"));card.name="NightwatchCard";card.set_anchors_and_offsets_preset(Control.PRESET_CENTER);card.offset_left=-700;card.offset_right=700;card.offset_top=-190;card.offset_bottom=-20;card.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 card.add_theme_color_override("font_outline_color",Color(0,0,0,.95));card.add_theme_constant_override("outline_size",14);layer.add_child(card)
 _alarm_parts()

# The status line on every monitor and the red beacon of the critical alarm.
func _alarm_parts() -> void:
 for monitor: Node3D in monitors+[main_monitor]:
  var label:=_text(monitor,Vector3(0,.272,.172),"",14,HORIZONTAL_ALIGNMENT_CENTER);label.name="StatusBanner";label.outline_size=6;label.outline_modulate=Color(0,0,0,.9)
  banner_labels.append(label)
 var lamp_mat:=StandardMaterial3D.new();lamp_mat.albedo_color=Color("7a1410");lamp_mat.emission_enabled=true;lamp_mat.emission=Color("ff2a1c");lamp_mat.emission_energy_multiplier=.6
 var dome:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.07;sphere.height=.1;dome.mesh=sphere;dome.material_override=lamp_mat;dome.position=Vector3(0,3.16,-1.7);dome.layers=ROOM_LAYER;dome.name="AlarmBeacon";room.add_child(dome)
 beacon=OmniLight3D.new();beacon.name="AlarmLight";beacon.light_color=Color("ff2418");beacon.light_energy=0.;beacon.omni_range=6.;beacon.light_cull_mask=ROOM_LAYER;beacon.position=Vector3(0,3.0,-1.5);room.add_child(beacon)

func _arrow(symbol: String, left: bool) -> PanelContainer:
 var box:=PanelContainer.new();box.name="ArrowLeft" if left else "ArrowRight";box.mouse_filter=Control.MOUSE_FILTER_IGNORE
 box.set_anchors_preset(Control.PRESET_CENTER_LEFT if left else Control.PRESET_CENTER_RIGHT)
 box.offset_left=18. if left else -82.;box.offset_right=82. if left else -18.;box.offset_top=-70;box.offset_bottom=70
 var style:=StyleBoxFlat.new();style.bg_color=Color(.03,.05,.04,.45);style.border_color=Color(.75,.85,.75,.35);style.set_border_width_all(2);style.set_corner_radius_all(10);box.add_theme_stylebox_override("panel",style)
 var label:=_ui_label(symbol,40,Color(.85,.95,.85,.8));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;box.add_child(label)
 hud.add_child(box);return box

func _ui_label(value: String, font_size: int, color: Color) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.add_theme_font_override("font",load("res://assets/Oswald.ttf"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;return label

func _full_ui() -> void:
 full=Control.new();full.name="FullscreenFeed";full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);full.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(full);layer.move_child(full,0)
 var black:=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);black.mouse_filter=Control.MOUSE_FILTER_IGNORE;full.add_child(black)
 full_image=TextureRect.new();full_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);full_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;full_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;full_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader:=Shader.new();shader.code="""shader_type canvas_item;
uniform float glitch=0.0;
uniform float instability=0.0;
uniform float dim=1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 uv=UV;float line=floor(uv.y*150.0);
 uv.x+=glitch*(hash(vec2(line,floor(TIME*26.0)))-.5)*.06+sin(uv.y*90.0+TIME*2.0)*.0006*(1.0+instability*5.0);
 vec3 c=pow(texture(TEXTURE,uv).rgb,vec3(.82));float l=dot(c,vec3(.299,.587,.114));c=mix(c,vec3(l*.84,l,l*.9),.45)*1.4;
 c+=(hash(floor(UV*vec2(640.,480.))+floor(TIME*20.))-.5)*(.05+instability*.2+glitch*.4);
 c*=.94+.06*sin(UV.y*900.0);float v=1.-.4*pow(length((UV-.5)*1.2),2.4);
 COLOR=vec4(clamp(c*v*dim,0.,1.),1.);}"""
 var m:=ShaderMaterial.new();m.shader=shader;full_image.material=m;full.add_child(full_image)
 full_label=_ui_label("",30,Color("d8f0d8"));full_label.position=Vector2(60,40);full.add_child(full_label)
 full_stamp=_ui_label("",30,Color("d8f0d8"));full_stamp.position=Vector2(60,82);full.add_child(full_stamp)
 full_banner=_ui_label("",30,Color("ffd24a"));full_banner.name="StatusBannerFull";full_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);full_banner.offset_left=-800;full_banner.offset_right=800;full_banner.offset_top=130;full_banner.offset_bottom=200;full_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 full_banner.add_theme_color_override("font_outline_color",Color(0,0,0,.95));full_banner.add_theme_constant_override("outline_size",10);full.add_child(full_banner)
 var tip:=_ui_label("Linksklick auf die Veränderung: beheben  ·  Rechtsklick: zurück  ·  1–0 / Mausrad: Kamera  ·  Leertaste: Rolltor",18,Color("aab5a6"));tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);tip.offset_left=-620;tip.offset_right=620;tip.offset_top=-130;tip.offset_bottom=-100;tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;full.add_child(tip)
 full.hide()

func _qte_ui() -> void:
 qte_panel=PanelContainer.new();qte_panel.name="GeneratorQTE";qte_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);qte_panel.offset_left=-430;qte_panel.offset_right=430;qte_panel.offset_top=60;qte_panel.offset_bottom=330;qte_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new();style.bg_color=Color(.03,.03,.02,.9);style.border_color=Color("d9b25a");style.set_border_width_all(2);style.set_content_margin_all(22);qte_panel.add_theme_stylebox_override("panel",style);hud.add_child(qte_panel)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;qte_panel.add_child(column)
 qte_title=_ui_label("GENERATOR-NEUSTART",22,Color("d9b25a"));column.add_child(qte_title)
 qte_words=RichTextLabel.new();qte_words.bbcode_enabled=true;qte_words.fit_content=true;qte_words.scroll_active=false;qte_words.custom_minimum_size=Vector2(800,90);qte_words.mouse_filter=Control.MOUSE_FILTER_IGNORE
 qte_words.add_theme_font_override("normal_font",load("res://assets/Oswald.ttf"));qte_words.add_theme_font_size_override("normal_font_size",40);column.add_child(qte_words)
 qte_bar=ProgressBar.new();qte_bar.custom_minimum_size=Vector2(800,12);qte_bar.show_percentage=false;qte_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("d9b25a");qte_bar.add_theme_stylebox_override("fill",fill);column.add_child(qte_bar)
 qte_time=_ui_label("",18,Color("e8dfc0"));column.add_child(qte_time)
 qte_panel.hide()

func open_fullscreen(index: int=-1) -> void:
 if not running or blackout or not qte.is_empty():return
 if index>=0:select_camera(index)
 fullscreen=true;full.show();full_image.texture=main_view.get_texture();switch_sound.pitch_scale=1.3;switch_sound.play()

func close_fullscreen() -> void:
 if not fullscreen:return
 fullscreen=false;full.hide()

# ---------------------------------------------------------------- audio

func _wav(seconds_value: float, wave: Callable, looped: bool=false) -> AudioStreamWAV:
 var rate:=22050;var count:=int(seconds_value*rate);var data:=PackedByteArray();data.resize(count*2)
 for i in range(count):data.encode_s16(i*2,int(clampf(float(wave.call(float(i)/rate)),-1.,1.)*32000.))
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.stereo=false;stream.data=data
 if looped:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=count
 return stream

func _player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
 var player:=AudioStreamPlayer.new();player.stream=stream;player.volume_db=volume;player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(player);return player

func _audio() -> void:
 var noise:=RandomNumberGenerator.new();noise.seed=415
 hum=_player(_wav(1.0,func(t: float):return .22*sin(TAU*50.*t)+.12*sin(TAU*100.*t)+.05*sin(TAU*150.*t)+.03*(noise.randf()-.5),true),-27)
 beep=_player(_wav(.16,func(t: float):return .55*signf(sin(TAU*1320.*t))*clampf(1.-t/.16,0,1)*clampf(t/.01,0,1)),-9)
 buzz=_player(_wav(.24,func(t: float):return .5*signf(sin(TAU*170.*t))*clampf(1.-t/.24,0,1)),-11)
 click=_player(_wav(.035,func(t: float):return (noise.randf()-.5)*1.6*exp(-t*160.)+.4*sin(TAU*2400.*t)*exp(-t*220.)),-12)
 engine=_player(_wav(1.0,func(t: float):return .32*signf(sin(TAU*28.*t))*(.6+.4*sin(TAU*7.*t))+.18*sin(TAU*56.*t)+.08*(noise.randf()-.5),true),-34)
 switch_sound=_player(load("res://assets/feedback-v403/switch.ogg"),-8)
 thud=_player(load("res://assets/scares-v260/dry-impact.wav"),-6)
 distant=_player(null,-24)
 # Six o'clock: three soft bell tones.
 chime=_player(_wav(3.2,func(t: float):
  var v:=0.
  for k in range(3):
   var s:=t-k*.55
   if s>0.:v+=.3*sin(TAU*[784.,659.,523.][k]*s)*exp(-s*1.6)+.08*sin(TAU*[1568.,1318.,1046.][k]*s)*exp(-s*3.)
  return v),-6)
 cheer=_player(load("res://assets/ambience/children-laugh.ogg"),-14)
 # The critical alarm: a hard two-tone blip.
 siren=_player(_wav(.22,func(t: float):return .5*signf(sin(TAU*(880. if t<.11 else 660.)*t))*clampf(t/.006,0,1)*clampf((.22-t)/.02,0,1)),-7)

const DISTANT:=["res://assets/ambience-v193/ghost-run.wav","res://assets/annex/clown-sting.wav","res://assets/ambience/relay-tick.wav"]

# ---------------------------------------------------------------- run

func start(night_value: int=1, seed_value: int=-1) -> void:
 run_id+=1
 _clear_anomalies()
 w=g.world;rng.seed=seed_value if seed_value>=0 else int(Time.get_unix_time_from_system()*1000.)%2147483647
 anomalies=NightwatchAnomalies.new(w,rng.randi())
 night=clampi(night_value,1,NightwatchConfig.NIGHTS)
 var cfg:=NightwatchConfig.night(night);level_crawler=int(cfg.crawler);level_clown=int(cfg.clown);level_bunny=int(cfg.get("bunny",0))
 running=true;over=false;won=false;reason="";seconds=0.;power=NightwatchConfig.POWER_START;new_best=false
 fixed=0;misses=0;repairs=0;failed_repairs=0;blackout=false;blackout_clock=0.;blackout_wait=0.;torch_time=0.;miss_lock=0.;was_dark=false;critical_clock=0.;alarm_clock=0.;beacon.light_energy=0.;siren.stop()
 spawn_clock=0.;next_spawn=NightwatchConfig.FIRST_ANOMALY;selected=0;refresh_index=0;view="monitors";yaw=FRONT.x;pitch=FRONT.y;anchor_yaw=FRONT.x;sway=Vector2.ZERO
 qte={};fullscreen=false;message_time=0;beep_clock=0;glitch_clock=4.;glitch=0;ambience_clock=rng.randf_range(20,40)
 for port in feeds:(port as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE
 main_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 select_camera(0,false)
 clock_step=0
 if clock_second:clock_second.rotation.z=0.
 _tick_wall_clock()
 if stalker:stalker.start()
 if vent:vent.start()
 if bunny:bunny.start(level_bunny)
 torch.light_energy=0.
 for row in lights:(row[0] as Light3D).light_energy=float(row[1])
 show();cam.current=true;cam.rotation=Vector3(pitch,yaw,0)
 layer.show();hud.show();full.hide();qte_panel.hide();message.text=""
 card.text=AfterPlayLanguage.t("NACHT %d")%night+"\n00:00";card_time=4.;card.modulate.a=1.
 _say(NightwatchConfig.BRIEFING[night-1],12.)
 hum.play();engine.play();engine.volume_db=-34;engine.pitch_scale=1.;beep.stop()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 _refresh_hud();set_process(false)

# In-game time as "HH:MM", from 00:00 to 06:00.
func clock_string() -> String:
 var minutes:=mini(int(seconds/NightwatchConfig.HOUR*60.),NightwatchConfig.HOURS*60)
 return "%02d:%02d"%[minutes/60,minutes%60]

# Called by the game every frame while the mode is on screen.
func tick(delta: float) -> void:
 if not running:return
 seconds+=delta
 _tick_wall_clock()
 if seconds>=NightwatchConfig.night_length():_win();return
 var cfg:=NightwatchConfig.night(night)
 miss_lock=maxf(miss_lock-delta,0.)
 if blackout:_tick_blackout(delta)
 else:
  power=maxf(power-float(cfg.drain)*delta,0.)
  if power<=0. and qte.is_empty():_begin_blackout()
 if not running:return
 if not blackout:
  _tick_torch(delta)
  if stalker and stalker.tick(delta,level_crawler,seconds)=="caught":_game_over("caught");return
  if vent and vent.tick(delta,level_clown,seconds,torch_on_vent())=="caught":_game_over("vent");return
  if bunny and bunny.tick(delta,level_bunny)=="caught":_game_over("bunny");return
 for record in active:
  anomalies.tick(record,delta if qte.is_empty() else 0.)
  if not blackout and qte.is_empty():record.left=float(record.left)-delta
 if qte.is_empty() and not blackout:
  spawn_clock+=delta
  if spawn_clock>=next_spawn and active.size()<int(cfg.active):_spawn()
 if not qte.is_empty():
  _tick_qte(delta)
  if not running:return
 _tick_critical(delta)
 if not running:return
 _tick_screens(delta)
 _tick_alarm(delta)
 _tick_view(delta)
 ambience_clock-=delta
 if ambience_clock<=0 and not blackout:
  ambience_clock=rng.randf_range(25,55)
  var path: String=DISTANT[rng.randi_range(0,DISTANT.size()-1)]
  if ResourceLoader.exists(path):distant.stream=load(path);distant.pitch_scale=rng.randf_range(.75,1.0);distant.volume_db=-26;distant.play()
 if message_time>0:
  message_time-=delta
  if message_time<=0:message.text=""
 if card_time>0:
  card_time-=delta;card.modulate.a=clampf(card_time,0.,1.)
 _refresh_hud()

# ---------------------------------------------------------------- anomalies

func _spawn() -> void:
 var cfg:=NightwatchConfig.night(night)
 var busy:={}
 for record in active:busy[str(record.room)+"/"+str(record.area)]=true
 for attempt in range(6):
  var option:=anomalies.pick(night,busy)
  if option.is_empty():return
  var area:=NightwatchConfig.area(option.room,option.area)
  var spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(area.camera)]
  var record:=anomalies.apply(option,spec,float(cfg.detect))
  if record.is_empty():continue
  record.started=seconds;active.append(record)
  spawn_clock=0;next_spawn=NightwatchConfig.spawn_interval(night,seconds)*rng.randf_range(1.-NightwatchConfig.JITTER,1.+NightwatchConfig.JITTER)
  for i in range(feeds.size()):
   if NightwatchConfig.CAMERAS[i].id==area.camera:(feeds[i] as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE
  return

# Forces one anomaly (tests and QA): returns the record or {}.
func force(room_id: String, area_id: String, kind: String, spec: String="") -> Dictionary:
 var area:=NightwatchConfig.area(room_id,area_id)
 if area.is_empty():return {}
 var option:={"room":room_id,"area":area_id,"kind":kind,"spec":spec}
 if spec=="" and not kind in NightwatchConfig.SPOT_KINDS:
  for row in area.objects:
   if kind in row[2]:option.spec=row[0];option.label=row[1];break
  if option.spec=="":return {}
 var cam_spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(area.camera)]
 var record:=anomalies.apply(option,cam_spec,float(NightwatchConfig.night(night).detect))
 if record.is_empty():return {}
 record.started=seconds;active.append(record);return record

# Screen position in the full-screen view -> position in the feed image.
func feed_point(screen: Vector2) -> Vector2:
 var view_size:=full_image.size if full_image.size.x>0 else get_viewport().get_visible_rect().size
 var tex:=Vector2(main_view.size);var s:=minf(view_size.x/tex.x,view_size.y/tex.y)
 var shown:=tex*s;var offset:=(view_size-shown)*.5
 return (screen-full_image.global_position-offset)/s

# The other way round, for tests and QA.
func screen_point(feed: Vector2) -> Vector2:
 var view_size:=full_image.size if full_image.size.x>0 else get_viewport().get_visible_rect().size
 var tex:=Vector2(main_view.size);var s:=minf(view_size.x/tex.x,view_size.y/tex.y)
 return feed*s+(view_size-tex*s)*.5+full_image.global_position

# A left click into the full-screen picture: on a change it is put right,
# anywhere else clicking is locked for a moment.
func fix_at(screen: Vector2) -> bool:
 if not running or not fullscreen or blackout or miss_lock>0.:return false
 var p:=feed_point(screen)
 var id: String=NightwatchConfig.CAMERAS[selected].id
 for record in active:
  if str(NightwatchConfig.area(record.room,record.area).camera)!=id:continue
  if anomalies.hits(record,main_camera,p):fix(record);return true
 # The rabbit is no change in the room: no fix, but no missed click either.
 if bunny and bunny.hit(main_camera,p):_say("Das ist der Hase – keine Veränderung. Lass ihn nicht aus den Augen.",2.5);return false
 misses+=1;miss_lock=NightwatchConfig.MISS_LOCK;buzz.play()
 message.text=AfterPlayLanguage.t("Dort ist nichts. Fehlklick %d / %d")%[misses,NightwatchConfig.MAX_MISSES];message_time=1.6
 if misses>=NightwatchConfig.MAX_MISSES:_game_over("clicks")
 return false

func fix(record: Dictionary) -> void:
 record.state="fixed";anomalies.revert(record);active.erase(record);fixed+=1
 glitch=maxf(glitch,.55);switch_sound.pitch_scale=1.2;switch_sound.play()
 _say("Behoben: %s · %s"%[NightwatchConfig.room(record.room).get("name",""),NightwatchConfig.area(record.room,record.area).get("name","")],2.5)
 if g.achievements:
  g.achievements.unlock("nightwatch_first")
  if fixed>=10:g.achievements.unlock("nightwatch_10")

# ---------------------------------------------------------------- alarm

# 0 none, 1 warning, 2 alert, 3 critical: what every camera shows.
func status() -> int:
 if critical():return 3
 return mini(active.size(),3)

# Too many open, or one left too long: the critical alarm runs.
func critical() -> bool:
 if active.size()>=NightwatchConfig.CRITICAL_COUNT:return true
 for record in active:
  if float(record.left)<=0.:return true
 return false

func _tick_critical(delta: float) -> void:
 if critical() and not blackout:
  critical_clock+=delta
  var k:=clampf(critical_clock/NightwatchConfig.CRITICAL_TIME,0.,1.)
  alarm_clock-=delta
  if alarm_clock<=0.:
   alarm_clock=lerpf(.9,.14,k);siren.pitch_scale=lerpf(1.,1.35,k);siren.play()
  beacon.light_energy=2.4 if fmod(critical_clock,alarm_clock_step(k))<alarm_clock_step(k)*.5 else 0.
  if critical_clock>=NightwatchConfig.CRITICAL_TIME:
   var worst: Dictionary=active[0] if not active.is_empty() else {}
   for record in active:
    if float(record.left)<float(worst.left):worst=record
   if not worst.is_empty():worst.state="expired"
   _game_over("missed",worst)
 else:
  critical_clock=maxf(critical_clock-delta*2.,0.);alarm_clock=0.;beacon.light_energy=0.

func alarm_clock_step(k: float) -> float:
 return lerpf(.9,.14,k)

# The last seconds before the threshold: the lights go mad.
func critical_flicker() -> bool:
 return critical_clock>NightwatchConfig.CRITICAL_TIME-NightwatchConfig.CRITICAL_FLICKER

# The status line in every camera picture.
func _banners() -> void:
 var level:=status()
 var text: String=NightwatchConfig.STATUS[level]
 var colour: Color=NightwatchConfig.STATUS_COLOURS[level]
 var blink:=level<3 or fmod(seconds,.5)<.33
 var shout:=level==3 and critical_flicker()
 for label: Label3D in banner_labels:
  label.text=text if blink else "";label.modulate=colour
  label.font_size=24 if shout else 14
 full_banner.text=text if blink else "";full_banner.add_theme_color_override("font_color",colour)
 full_banner.add_theme_font_size_override("font_size",54 if shout else 30)

# ---------------------------------------------------------------- door, vent, torch

# Space or the panel: down costs 20 % at once; up is free.
func toggle_shutter() -> bool:
 if not stalker or blackout or not running:return false
 if stalker.closed:stalker.set_shutter(false);return true
 if power<NightwatchConfig.SHUTTER_COST:
  buzz.play();_say("Zu wenig Strom für das Tor! Schnell zum Generator (D) und tippen.",3.5);return false
 power-=NightwatchConfig.SHUTTER_COST;stalker.set_shutter(true);return true

# F: the torch burns for a few seconds; every switch-on costs 10 %.
func toggle_torch() -> bool:
 if blackout or not running:return false
 if torch_time>0.:torch_time=0.;click.play();return true
 if power<NightwatchConfig.TORCH_COST:
  buzz.play();_say("Zu wenig Strom für die Taschenlampe! Schnell zum Generator und tippen.",3.5);return false
 power-=NightwatchConfig.TORCH_COST;torch_time=NightwatchConfig.TORCH_TIME;click.pitch_scale=1.4;click.play();return true

func torch_on_vent() -> bool:
 return torch_time>0. and view=="right" and absf(yaw-RIGHT.x)<.4

func _tick_torch(delta: float) -> void:
 torch_time=maxf(torch_time-delta,0.)
 var fade:=clampf(torch_time/.25,0.,1.)
 # Looking right, the beam goes into the vent; elsewhere straight ahead.
 if view=="right":torch.look_at(to_global(Vector3(NightwatchVent.WALL_X+.6,NightwatchVent.Y,NightwatchVent.Z)),Vector3.UP)
 else:torch.rotation=Vector3.ZERO
 torch.light_energy=NightwatchConfig.TORCH_ENERGY*fade*(.96+.04*sin(seconds*37.)) if torch_time>0. else 0.

# ---------------------------------------------------------------- generator

func start_qte() -> bool:
 if not running or not qte.is_empty():return false
 close_fullscreen()
 var cfg:=NightwatchConfig.night(night)
 qte={"words":NightwatchConfig.words_for(night,rng),"index":0,"typed":0,"time":float(cfg.time),"left":float(cfg.time),"flash":0.}
 qte_panel.show();_refresh_qte()
 engine.volume_db=-14+night*1.5;engine.pitch_scale=.8+night*.08
 if not engine.playing:engine.play()
 switch_sound.pitch_scale=.8;switch_sound.play()
 return true

func _tick_qte(delta: float) -> void:
 qte.left=float(qte.left)-delta;qte.flash=maxf(float(qte.flash)-delta,0)
 if float(qte.left)<=0:_finish_qte(false);return
 _refresh_qte()

func type_key(character: String) -> bool:
 if qte.is_empty():return false
 var words: Array=qte.words;var word: String=words[int(qte.index)]
 if character.to_upper()==word[int(qte.typed)]:
  qte.typed=int(qte.typed)+1;click.pitch_scale=rng.randf_range(.9,1.15);click.play()
  if int(qte.typed)>=word.length():
   qte.index=int(qte.index)+1;qte.typed=0
   if int(qte.index)>=words.size():_finish_qte(true);return true
 else:
  qte.flash=.25;buzz.play()
 _refresh_qte();return true

func _finish_qte(success: bool) -> void:
 qte={};qte_panel.hide();engine.volume_db=-34;engine.pitch_scale=1.
 if success:
  power=NightwatchConfig.POWER_START;repairs+=1;beep.stop();beep_clock=0
  if blackout:_end_blackout()
  switch_sound.pitch_scale=1.;switch_sound.play();_say("Generator läuft wieder. Strom 100 %",3.5)
  if g.achievements and repairs>=5:g.achievements.unlock("nightwatch_generator")
 else:
  failed_repairs+=1;thud.play();_say("Neustart fehlgeschlagen. Versuch es noch einmal.",4.)
  if power<=0. and not blackout:_begin_blackout()

func _refresh_qte() -> void:
 if qte.is_empty():return
 var words: Array=qte.words;var parts: Array=[]
 for i in range(words.size()):
  var word: String=words[i]
  if i<int(qte.index):parts.append("[color=#6d8a6b]%s[/color]"%word)
  elif i==int(qte.index):
   var done:=word.substr(0,int(qte.typed));var rest:=word.substr(int(qte.typed))
   parts.append("[color=#f6e7a8]%s[/color][color=%s][u]%s[/u][/color]"%[done,"#ff5a46" if float(qte.flash)>0 else "#ffffff",rest])
  else:parts.append("[color=#8e8a7a]%s[/color]"%word)
 qte_words.text="  ".join(parts)
 var share: float=float(qte.left)/float(qte.time)
 qte_bar.value=share*100.;qte_time.text=AfterPlayLanguage.t("Noch %.1f s  ·  Wort %d / %d")%[float(qte.left),mini(int(qte.index)+1,words.size()),words.size()]
 var urgent:=share<.3
 (qte_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color=Color("ff5a46") if urgent else Color("d9b25a")
 qte_title.text=AfterPlayLanguage.t("GENERATOR-NEUSTART  ·  TIPPE DIE WÖRTER")+(AfterPlayLanguage.t("  ·  SCHNELL!") if urgent else "")

# ---------------------------------------------------------------- blackout

func _begin_blackout() -> void:
 blackout=true;was_dark=true;blackout_clock=0.;blackout_wait=rng.randf_range(NightwatchConfig.BLACKOUT_MIN,NightwatchConfig.BLACKOUT_MAX)
 power=0.;close_fullscreen();torch_time=0.;torch.light_energy=0.
 hum.stop();engine.stop();beep.stop();thud.play()
 if stalker:stalker.blackout()
 if vent:vent.blackout()
 for row in lights:(row[0] as Light3D).light_energy=0.
 for material in [main_material]+small_materials:(material as ShaderMaterial).set_shader_parameter("dim",0.)
 _say("STROMAUSFALL – nur der Generator hilft noch (D, anklicken, tippen).",5.)

func _end_blackout() -> void:
 blackout=false;blackout_clock=0.
 hum.play();engine.play();engine.volume_db=-34
 if stalker:stalker.restore()
 if vent:vent.restore()
 for row in lights:(row[0] as Light3D).light_energy=float(row[1])

# In the dark: its eyes in the doorway, then it is there.
func _tick_blackout(delta: float) -> void:
 blackout_clock+=delta
 if stalker:
  stalker.animate(delta,seconds)
  var near:=blackout_clock>blackout_wait-3.
  stalker.guest.visible=near and fmod(blackout_clock,.9)<.55
  stalker.face_light.light_energy=.45 if stalker.guest.visible else 0.
 if blackout_clock>=blackout_wait and qte.is_empty():_game_over("power")
 elif blackout_clock>=blackout_wait+4.:_game_over("power")

# ---------------------------------------------------------------- screens

func select_camera(index: int, sound: bool=true) -> void:
 selected=posmod(index,NightwatchConfig.CAMERAS.size())
 var spec: Dictionary=NightwatchConfig.CAMERAS[selected]
 _aim(main_camera,spec)
 main_label.text=spec.label
 if sound:switch_sound.pitch_scale=rng.randf_range(1.5,1.7);switch_sound.play();glitch=maxf(glitch,.35)
 if not key_lit:
  key_lit=StandardMaterial3D.new();key_lit.albedo_color=Color("e8d9a0");key_lit.emission_enabled=true;key_lit.emission=Color("ffc85a");key_lit.emission_energy_multiplier=1.4
 for i in range(keys.size()):
  if keys[i]:(keys[i] as MeshInstance3D).material_override=key_lit if i==selected else null
 for i in range(monitors.size()):
  var label:=(monitors[i] as Node3D).find_child("SmallLabel%d"%i,true,false) as Label3D
  label.modulate=Color("ffd47a") if i==selected else Color("d8f0d8")

func instability() -> float:
 if power>NightwatchConfig.FLICKER_LIGHT:return 0.
 if power>NightwatchConfig.ALARM:return .12
 if power>NightwatchConfig.CRITICAL:return .35
 return .65

func _tick_screens(delta: float) -> void:
 var stamp:=int(seconds*3600./NightwatchConfig.HOUR)
 var text:="%02d:%02d:%02d"%[(stamp/3600)%24,(stamp/60)%60,stamp%60]
 gen_label.text="%03d %%"%ceili(power)
 if blackout:
  gen_label.modulate=Color("5a2018") if fmod(seconds,1.2)<.6 else Color(0,0,0,0)
  stamp_label.text="";power_label.text=""
  for label: Label3D in banner_labels:label.text=""
  return
 # Low power: random dropouts get more frequent; never permanent before 0 %.
 glitch_clock-=delta;glitch=maxf(glitch-delta*2.5,0)
 if glitch_clock<=0:
  var level:=instability()
  if level>0:glitch=clampf(.35+level,0,1);glitch_clock=lerpf(7.,.35,level/.65)*rng.randf_range(.6,1.3)
  else:glitch=maxf(glitch,.18);glitch_clock=rng.randf_range(9,16)
 var dim:=1.
 if power<=NightwatchConfig.FLICKER_LIGHT and glitch>.3:dim=lerpf(1.,.15,clampf((glitch-.3)*1.6,0,1))
 for material in [main_material]+small_materials:
  (material as ShaderMaterial).set_shader_parameter("instability",instability());(material as ShaderMaterial).set_shader_parameter("glitch",glitch);(material as ShaderMaterial).set_shader_parameter("dim",dim)
 # One small feed refreshes per frame: a stuttering CCTV wall at full speed.
 if not feeds.is_empty():
  refresh_index=(refresh_index+1)%feeds.size()
  (feeds[refresh_index] as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE
 if fullscreen:
  var fm:=full_image.material as ShaderMaterial;fm.set_shader_parameter("glitch",glitch);fm.set_shader_parameter("instability",instability());fm.set_shader_parameter("dim",dim)
  full_label.text=NightwatchConfig.CAMERAS[selected].label+"   ·   STROM %d %%"%ceili(power)
  full_stamp.text=text
 stamp_label.text=text
 power_label.text="STROM %d %%"%ceili(power)
 power_label.modulate=Color("ff6a50") if power<=NightwatchConfig.ALARM else Color("d8f0d8")
 var blink:=power>NightwatchConfig.ALARM or fmod(seconds,.6)<.3
 gen_label.modulate=Color("7dff8a") if power>NightwatchConfig.ALARM else (Color("ff5a40") if blink else Color("5a2018"))
 var room_dim:=1. if power>NightwatchConfig.CRITICAL else .6+.4*float(glitch<.3)
 if critical_flicker():
  room_dim*=.08 if rng.randf()<.4 else 1.
  glitch=maxf(glitch,.5)
 for row in lights:(row[0] as Light3D).light_energy=float(row[1])*room_dim
 _banners()

func _tick_alarm(delta: float) -> void:
 if blackout or power>NightwatchConfig.ALARM:beep_clock=0;return
 beep_clock-=delta
 if beep_clock<=0:
  beep.pitch_scale=1.0 if power>NightwatchConfig.CRITICAL else 1.18;beep.play()
  beep_clock=lerpf(.22,1.35,clampf(power/NightwatchConfig.ALARM,0,1)) if power>NightwatchConfig.CRITICAL else lerpf(.16,.4,clampf(power/NightwatchConfig.CRITICAL,0,1))

func alarm_active() -> bool:
 return running and not blackout and power<=NightwatchConfig.ALARM

# Seated look: the arrows, A/D or a click ease the head to the door, the
# monitor wall or the vent and generator; a faint drift follows the cursor.
func _tick_view(delta: float) -> void:
 var size_value:=get_viewport().get_visible_rect().size
 var mouse:=get_viewport().get_mouse_position()/size_value
 var inside:=mouse.x>=0. and mouse.x<=1. and mouse.y>=0. and mouse.y<=1.
 var drift:=Vector2.ZERO
 if inside and qte.is_empty():drift=Vector2(-(clampf(mouse.x,EDGE,1.-EDGE)-.5)*.05,-(mouse.y-.5)*.05)
 var ease_value:=1.-exp(-delta*SMOOTH)
 sway=sway.lerp(drift,1.-exp(-delta*3.))
 yaw=lerpf(yaw,anchor_yaw+sway.x,ease_value)
 var turn:=clampf((yaw-FRONT.x)/(RIGHT.x-FRONT.x),0.,1.)
 var turn_left:=clampf((yaw-FRONT.x)/(LEFT.x-FRONT.x),0.,1.)
 var breathe:=sin(seconds*1.3)*.0025
 var base_pitch:=lerpf(FRONT.y,RIGHT.y,smoothstep(0.,1.,turn)) if yaw<FRONT.x else lerpf(FRONT.y,LEFT.y,smoothstep(0.,1.,turn_left))
 pitch=lerpf(pitch,base_pitch+sway.y+breathe,ease_value)
 cam.rotation=Vector3(pitch,yaw,0)
 _refresh_arrows()
 _hover(get_viewport().get_mouse_position())

func look(where: String) -> void:
 if not qte.is_empty():return
 anchor_yaw=RIGHT.x if where=="right" else LEFT.x if where=="door" else FRONT.x
 view=where

func _refresh_arrows() -> void:
 var free:=not fullscreen and qte.is_empty() and running
 arrow_left.visible=free and view!="door"
 arrow_right.visible=free and view!="right"
 var mouse:=get_viewport().get_mouse_position()
 for arrow: PanelContainer in [arrow_left,arrow_right]:
  arrow.modulate.a=1. if arrow.get_global_rect().has_point(mouse) else .6

# Which arrow sits under the cursor: "left", "right" or "".
func arrow_at(screen: Vector2) -> String:
 if arrow_left.visible and arrow_left.get_global_rect().has_point(screen):return "left"
 if arrow_right.visible and arrow_right.get_global_rect().has_point(screen):return "right"
 return ""

func turn(side: String) -> void:
 if side=="left":look("monitors" if view=="right" else "door")
 elif side=="right":look("monitors" if view=="door" else "right")

func _pick(screen: Vector2) -> String:
 var space:=get_world_3d().direct_space_state
 var from:=cam.project_ray_origin(screen);var to:=from+cam.project_ray_normal(screen)*6.
 var query:=PhysicsRayQueryParameters3D.create(from,to,CLICK_LAYER);query.collide_with_areas=false
 var hit:=space.intersect_ray(query)
 if hit.is_empty():return ""
 return str((hit.collider as Node).get_meta("nightwatch",""))

func _hover(screen: Vector2) -> void:
 var target:=_pick(screen) if qte.is_empty() and arrow_at(screen)=="" else ""
 if blackout and target!="generator":target=""
 Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if target!="" or arrow_at(screen)!="" else Input.CURSOR_ARROW)
 if not qte.is_empty():hint.text="Tippe die Wörter in der richtigen Reihenfolge"
 elif blackout:hint.text="Generator anklicken und tippen – schnell!" if view=="right" else "D / ▶: zum Generator"
 elif fullscreen:hint.text=""
 elif view=="right":hint.text="F: Taschenlampe in den Schacht (10 %)  ·  Generator anklicken: Neustart (Wörter tippen)  ·  A / ◀: zurück"
 elif view=="door":hint.text="Leertaste oder Rolltor-Knopf: Tor runter (20 %)  ·  D / ▶: zurück zu den Monitoren"
 else:hint.text="Monitor anklicken: Vollbild  ·  1–0 oder Mausrad: Kamera  ·  ◀ / A: Tür  ·  ▶ / D: Schacht und Generator  ·  F: Taschenlampe  ·  ESC: Pause"

func click_at(screen: Vector2) -> bool:
 if not running or fullscreen or not qte.is_empty():return false
 var side:=arrow_at(screen)
 if side!="":turn(side);return true
 var target:=_pick(screen)
 if target=="generator":
  look("right");return start_qte()
 if blackout:return false
 if target.begins_with("monitor:"):open_fullscreen(int(target.get_slice(":",1)));return true
 if target=="main":open_fullscreen();return true
 if target=="vent":
  look("right")
  if torch_time<=0.:toggle_torch()
  return true
 if target=="shutter":
  look("door");toggle_shutter();return true
 return false

# Input from the game. Returns true when the event was used.
func handle(event: InputEvent) -> bool:
 if not running:return false
 if not qte.is_empty():
  if event is InputEventKey and event.pressed and not event.echo:
   var key_event:=event as InputEventKey
   if key_event.keycode==KEY_ESCAPE:return false
   if key_event.unicode>32:return type_key(char(key_event.unicode))
   return true
  return false
 if event is InputEventKey and event.pressed and not event.echo:
  var key:=(event as InputEventKey).physical_keycode
  if key==KEY_SPACE:toggle_shutter();return true
  if key==KEY_F:toggle_torch();return true
 if fullscreen:
  if event is InputEventMouseButton and event.pressed:
   var mb:=event as InputEventMouseButton
   if mb.button_index==MOUSE_BUTTON_LEFT:fix_at(mb.position);return true
   if mb.button_index==MOUSE_BUTTON_RIGHT:close_fullscreen();return true
   if mb.button_index==MOUSE_BUTTON_WHEEL_UP:select_camera(selected-1);return true
   if mb.button_index==MOUSE_BUTTON_WHEEL_DOWN:select_camera(selected+1);return true
   return true
  if event.is_action_pressed("pause"):close_fullscreen();return true
  if event is InputEventKey and event.pressed and not event.echo:
   var fk:=(event as InputEventKey).physical_keycode
   if fk>=KEY_1 and fk<=KEY_9:select_camera(fk-KEY_1);return true
   if fk==KEY_0:select_camera(9);return true
   if fk in [KEY_A,KEY_LEFT]:close_fullscreen();look("door");return true
   if fk in [KEY_D,KEY_RIGHT]:close_fullscreen();look("right");return true
  return false
 if event is InputEventMouseButton and event.pressed:
  var button_event:=event as InputEventMouseButton
  if button_event.button_index==MOUSE_BUTTON_LEFT:return click_at(button_event.position)
  if blackout:return false
  if button_event.button_index==MOUSE_BUTTON_WHEEL_UP:select_camera(selected-1);return true
  if button_event.button_index==MOUSE_BUTTON_WHEEL_DOWN:select_camera(selected+1);return true
 if event is InputEventKey and event.pressed and not event.echo:
  var key:=(event as InputEventKey).physical_keycode
  if key in [KEY_D,KEY_RIGHT]:turn("right");return true
  if key in [KEY_A,KEY_LEFT]:turn("left");return true
  if blackout:return false
  if key>=KEY_1 and key<=KEY_9:select_camera(key-KEY_1);return true
  if key==KEY_0:select_camera(9);return true
  if key==KEY_Q:select_camera(selected-1);return true
  if key==KEY_E:select_camera(selected+1);return true
 return false

# ---------------------------------------------------------------- HUD

func _say(value: String, duration: float) -> void:
 message.text=AfterPlayLanguage.t(value);message_time=duration

func _refresh_hud() -> void:
 night_text.text=AfterPlayLanguage.t("NIGHTWATCH PROTOCOL · NACHT %d")%night
 clock_text.text=clock_string()
 power_text.text=AfterPlayLanguage.t("STROM %d %%")%ceili(power)+(AfterPlayLanguage.t("  ·  WARNUNG") if power<=NightwatchConfig.ALARM else "")
 power_bar.value=power
 var fill:=power_bar.get_theme_stylebox("fill") as StyleBoxFlat
 fill.bg_color=Color("8fd18c") if power>NightwatchConfig.FLICKER_LIGHT else Color("e0c060") if power>NightwatchConfig.ALARM else Color("ff5a46")
 power_text.add_theme_color_override("font_color",Color("ff7a64") if power<=NightwatchConfig.ALARM else Color("e3efe0"))
 var lines: Array=[AfterPlayLanguage.t("ROLLTOR: ")+AfterPlayLanguage.t("UNTEN" if stalker and stalker.closed else "OBEN")]
 lines.append(AfterPlayLanguage.t("TASCHENLAMPE: ")+(AfterPlayLanguage.t("AN") if torch_time>0. else AfterPlayLanguage.t("AUS")))
 lines.append(AfterPlayLanguage.t("SENSOREN: KEINE AUFFÄLLIGKEIT") if active.is_empty() else AfterPlayLanguage.t("SENSOREN: %d VERÄNDERUNG(EN)")%active.size())
 sensor_text.text="\n".join(lines)

# ---------------------------------------------------------------- the end

# 06:00: the shift is over.
func _win() -> void:
 if over:return
 over=true;running=false;won=true;reason="survived";seconds=NightwatchConfig.night_length()
 var this_run:=run_id
 close_fullscreen();qte={};qte_panel.hide();torch_time=0.;torch.light_energy=0.;beep.stop();engine.volume_db=-34;Input.set_default_cursor_shape(Input.CURSOR_ARROW);beacon.light_energy=0.;siren.stop()
 if stalker:stalker.stop()
 if vent:vent.stop()
 if bunny:bunny.stop()
 _clear_anomalies()
 if g.achievements:
  new_best=g.achievements.record_nightwatch(night,true,seconds)
  g.achievements.unlock("nightwatch_10min")
  if night>=NightwatchConfig.NIGHTS:g.achievements.unlock("nightwatch_25")
  if was_dark:g.achievements.unlock("nightwatch_5000")
 g.phase="nightwatch_end"
 if blackout:_end_blackout()
 chime.play();cheer.play()
 card.text="06:00";card_time=99.;card.modulate.a=1.
 message.text="";hint.text="";_refresh_hud();arrow_left.hide();arrow_right.hide()
 ended.emit("survived")
 await get_tree().create_timer(2.).timeout
 if this_run!=run_id:return
 card.text="06:00\n"+AfterPlayLanguage.t("NACHT %d GESCHAFFT")%night
 await get_tree().create_timer(2.6).timeout
 if this_run!=run_id or not is_instance_valid(g):return
 if g.phase=="nightwatch_end":g._nightwatch_results()

func _game_over(why: String, record: Dictionary={}) -> void:
 if over:return
 over=true;running=false;reason=why
 var this_run:=run_id
 close_fullscreen();qte={};qte_panel.hide();torch_time=0.;torch.light_energy=0.;beep.stop();engine.volume_db=-34;Input.set_default_cursor_shape(Input.CURSOR_ARROW);beacon.light_energy=0.;siren.stop()
 arrow_left.hide();arrow_right.hide();card.text=""
 if g.achievements:new_best=g.achievements.record_nightwatch(night,false,seconds)
 g.phase="nightwatch_end"
 match why:
  "caught","power":await _caught()
  "vent":await _vent_caught()
  "bunny":await _bunny_caught()
  "missed","clicks":await _missed(record)
 ended.emit(why)
 await get_tree().create_timer(1.7).timeout
 if this_run!=run_id or not is_instance_valid(g):return
 if g.phase=="nightwatch_end":g._nightwatch_results()

# It stood at the door and the shutter was up (or the power was gone): it
# comes through, into your face.
func _caught() -> void:
 look("door");yaw=LEFT.x;anchor_yaw=LEFT.x;pitch=LEFT.y;cam.rotation=Vector3(pitch,yaw,0)
 var guest:=stalker.guest;guest.show();stalker.face_light.light_energy=3.
 var from:=guest.global_position
 var forward:=-cam.global_basis.z;forward.y=0;forward=forward.normalized()
 var to:=cam.global_position+forward*.35-Vector3(0,.55,0)
 JumpscareFX.fire(1.5,.1)
 var scream:=_player(load(ScareBank.track("crawler",rng.randi_range(1,4))),0.);ScareBank.loud(scream);scream.play();ScareBank.sting()
 var t:=0.
 while t<.3 and is_instance_valid(guest):
  t+=get_process_delta_time();var k:=smoothstep(0.,.3,t)
  guest.global_position=from.lerp(to,k);guest.look_at(cam.global_position,Vector3.UP,true)
  # Lit from the front, right where it lands.
  stalker.face_light.global_position=cam.global_position+forward*.15-Vector3(0,.25,0);stalker.face_light.omni_range=1.4
  await get_tree().process_frame
 await get_tree().create_timer(.9).timeout
 stalker.stop()

# The clown comes out of the vent.
func _vent_caught() -> void:
 look("right")
 var to: Vector3=to_global(NightwatchVent.HEAD_AT)-cam.global_position
 yaw=atan2(-to.x,-to.z);anchor_yaw=yaw;pitch=atan2(to.y,Vector2(to.x,to.z).length());cam.rotation=Vector3(pitch,yaw,0)
 await vent.lunge(cam)

# The rabbit at the stair door with the shutter up: it hops into your face.
func _bunny_caught() -> void:
 look("door");yaw=LEFT.x;anchor_yaw=LEFT.x;pitch=LEFT.y;cam.rotation=Vector3(pitch,yaw,0)
 var body: Node3D=bunny.door_body;body.show();stalker.face_light.light_energy=3.
 var from: Vector3=body.global_position
 var forward:=-cam.global_basis.z;forward.y=0;forward=forward.normalized()
 var to:=cam.global_position+forward*.45-Vector3(0,.95,0)
 JumpscareFX.fire(1.5,.1)
 var scream:=_player(load(ScareBank.track("rabbit",rng.randi_range(1,4))),0.);ScareBank.loud(scream);scream.play();ScareBank.sting()
 var t:=0.
 while t<.32 and is_instance_valid(body):
  t+=get_process_delta_time();var k:=smoothstep(0.,.32,t)
  body.global_position=from.lerp(to,k)+Vector3.UP*sin(k*PI)*.25
  body.look_at(cam.global_position,Vector3.UP,true)
  stalker.face_light.global_position=cam.global_position+forward*.15-Vector3(0,.25,0);stalker.face_light.omni_range=1.4
  await get_tree().process_frame
 await get_tree().create_timer(.9).timeout
 if is_instance_valid(body):body.hide();body.position=NightwatchBunny.DOOR_AT;body.rotation=Vector3(0,PI/2,0)
 stalker.stop()

# A change left too long: the picture of that room, then the godless scare.
func _missed(record: Dictionary) -> void:
 if not record.is_empty():
  var index:=NightwatchConfig.camera_index(str(NightwatchConfig.area(record.room,record.area).camera))
  if index>=0:select_camera(index,false)
  open_fullscreen_forced()
  _say("ÜBERSEHEN: %s · %s"%[NightwatchConfig.room(record.room).get("name",""),NightwatchConfig.area(record.room,record.area).get("name","")],4.)
 await get_tree().create_timer(1.2).timeout
 JumpscareFX.fire_godless()
 var scream:=_player(load(ScareBank.track("crowd",rng.randi_range(1,4))),0.);ScareBank.loud(scream);scream.play()
 await get_tree().create_timer(1.4).timeout
 close_fullscreen()

func open_fullscreen_forced() -> void:
 fullscreen=true;full.show();full_image.texture=main_view.get_texture()

func results() -> Dictionary:
 var title:=AfterPlayLanguage.t("NACHT %d GESCHAFFT")%night if won else str(REASONS.get(reason,reason))
 return {"won":won,"reason":reason,"title":title,"night":night,"clock":clock_string(),"seconds":seconds,"power":power,"fixed":fixed,"misses":misses,"repairs":repairs,"failed_repairs":failed_repairs,"door":stalker.repelled if stalker else 0,"vent":vent.repelled if vent else 0,"bunny":bunny.repelled if bunny else 0,"blackout":was_dark,"new_best":new_best}

func _clear_anomalies() -> void:
 if anomalies:
  # Leaving or restarting: the screens stop, everything goes at once.
  for record in active:anomalies.revert(record,true)
 active.clear()

# Leaves the mode: every change in the world is undone, the screens stop.
func stop() -> void:
 run_id+=1;running=false;qte={};fullscreen=false;torch_time=0.
 if full:full.hide()
 if torch:torch.light_energy=0.
 if stalker:stalker.stop()
 if vent:vent.stop()
 if bunny:bunny.stop()
 _clear_anomalies()
 for port in feeds:(port as SubViewport).render_target_update_mode=SubViewport.UPDATE_DISABLED
 if main_view:main_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for player in [hum,beep,engine,distant,chime,cheer,siren]:if player:(player as AudioStreamPlayer).stop()
 if beacon:beacon.light_energy=0.
 if layer:layer.hide()
 Input.set_default_cursor_shape(Input.CURSOR_ARROW)
 hide()

# Screens let go of their feeds before the viewports are freed on exit.
func _exit_tree() -> void:
 for material in [main_material]+small_materials:
  if material:(material as ShaderMaterial).set_shader_parameter("feed",null)
 for screen: GeometryInstance3D in room.find_children("*","MeshInstance3D",true,false) if room else []:
  if screen.material_override is ShaderMaterial:screen.material_override=null

func pause_audio(paused: bool) -> void:
 for player in [hum,engine,beep,distant]:if player:(player as AudioStreamPlayer).stream_paused=paused
 if layer:layer.visible=not paused

func snapshot() -> Dictionary:
 var open: Array=[]
 for record in active:open.append({"room":record.room,"area":record.area,"kind":record.kind,"left":snappedf(float(record.left),.1)})
 return {"night":night,"clock":clock_string(),"stalker":stalker.snapshot() if stalker else {},"vent":vent.snapshot() if vent else {},"bunny":bunny.snapshot() if bunny else {},"running":running,"over":over,"won":won,"reason":reason,"seconds":snappedf(seconds,.1),"power":snappedf(power,.1),"fixed":fixed,"active":open,"camera":selected,"view":view,"torch":torch_time>0.,"qte":not qte.is_empty(),"blackout":blackout,"alarm":alarm_active()}
