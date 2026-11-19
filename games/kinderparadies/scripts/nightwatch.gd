class_name Nightwatch
extends Node3D

# Nightwatch Protocol (4.15.0): a seated security shift in a control room far
# below Happyland. Ten CCTV feeds show the real, running world; anomalies are
# reported in a desk book; a generator to the right is restarted by typing.
# The mode owns its state completely and leaves the shared world as it was.

signal ended(reason: String)

const ORIGIN:=Vector3(0,-80,0)
const ROOM_LAYER:=8
const CLICK_LAYER:=1<<19
const EYE:=Vector3(0,1.2,.5)
# Seated view: yaw/pitch of the monitor wall and of the generator, and the
# limits the mouse can pan between.
const FRONT:=Vector2(0,-.03)
const RIGHT:=Vector2(-1.5,-.5)
const YAW_LEFT:=.42
const YAW_RIGHT:=-1.72
const EDGE:=.12
const PAN_SPEED:=1.7
const SMOOTH:=7.0
const REASONS:={"missed":"ANOMALIE ÜBERSEHEN","wrong":"ZU VIELE FEHLMELDUNGEN","power":"STROMAUSFALL"}
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
var lights: Array=[]
var anomalies: NightwatchAnomalies
# Own jumpscare on the control room camera; the shift one is never moved.
var scare: DoorFailure
var rng:=RandomNumberGenerator.new()

# Run state, reset by start().
var running:=false
var over:=false
var reason:=""
var seconds:=0.0
var power:=100.0
var wrong:=0
var reports:=0
var combo:=0
var best_combo:=0
var score_float:=0.0
var repairs:=0
var failed_repairs:=0
var top_stage:=1
var active: Array=[]
var history: Array=[]
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
var book_open:=false
var choice:={"room":"","area":"","kind":""}
var message_time:=0.0
var beep_clock:=0.0
var glitch_clock:=0.0
var glitch:=0.0
var ambience_clock:=0.0
var run_id:=0
var new_best:=false

# UI and audio.
var layer: CanvasLayer
var hud: Control
var power_bar: ProgressBar
var power_text: Label
var wrong_text: Label
var score_text: Label
var time_text: Label
var sensor_text: Label
var message: Label
var hint: Label
var book: Control
var book_rooms: GridContainer
var book_areas: VBoxContainer
var book_kinds: GridContainer
var book_send: Button
var book_log: Label
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

func build(game: Node3D) -> void:
 g=game;w=g.world;name="NightwatchProtocol";position=ORIGIN
 room=Node3D.new();room.name="ControlRoom";add_child(room)
 _shell();_desk();_monitor_wall();_generator()
 for mesh: GeometryInstance3D in room.find_children("*","GeometryInstance3D",true,false):mesh.layers=ROOM_LAYER
 cam=Camera3D.new();cam.name="ControlRoomCamera";cam.fov=62;cam.near=.04;cam.far=12;cam.cull_mask=1|ROOM_LAYER;cam.position=EYE;add_child(cam)
 scare=DoorFailure.new();scare.name="NightwatchScare";cam.add_child(scare);scare.hide()
 _feeds();_ui();_audio()
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
 _box(room,Vector3(-2.65,1.6,-.2),Vector3(.1,3.3,4.6),wall)
 _box(room,Vector3(2.65,1.6,-.2),Vector3(.1,3.3,4.6),wall)
 # Skirting, a cable duct along the back wall and a ventilation grille.
 _box(room,Vector3(0,.06,-2.09),Vector3(5.3,.12,.03),metal)
 for x in [-2.59,2.59]:_box(room,Vector3(x,.06,-.2),Vector3(.03,.12,4.5),metal)
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
 book_node.name="ReportBook"
 _clickable(book_node,Vector3(.02,.02,0),Vector3(.4,.06,.24),"book")
 var title:=Label3D.new();title.text="MELDEBUCH";title.font=load("res://assets/backstage-v270/Caveat.ttf");title.font_size=46;title.pixel_size=.0009;title.position=Vector3(.02,.027,0);title.rotation.x=-PI/2
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
 vec3 c=texture(feed,uv).rgb;
 float l=dot(c,vec3(.299,.587,.114));
 c=mix(c,vec3(l*.84,l,l*.9),.5)*gain;
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
 main_view=_viewport(Vector2i(960,720),"NightwatchMainFeed")
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

func _aim(feed_cam: Camera3D, spec: Dictionary) -> void:
 feed_cam.keep_aspect=Camera3D.KEEP_WIDTH;feed_cam.fov=feed_fov(spec)
 feed_cam.global_position=spec.p;feed_cam.look_at(spec.at)

# ---------------------------------------------------------------- UI

func _ui() -> void:
 layer=CanvasLayer.new();layer.name="NightwatchUI";layer.layer=12;add_child(layer)
 hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
 var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);panel.offset_left=-372;panel.offset_right=-30;panel.offset_top=30;panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new();style.bg_color=Color(.02,.035,.03,.72);style.border_color=Color("5d7060");style.border_width_right=3;style.set_content_margin_all(14);style.content_margin_left=18;panel.add_theme_stylebox_override("panel",style);hud.add_child(panel)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",5);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(column)
 var title:=_ui_label("NIGHTWATCH PROTOCOL",15,Color("9fb59f"));column.add_child(title)
 power_text=_ui_label("STROM 100 %",22,Color("e3efe0"));column.add_child(power_text)
 power_bar=ProgressBar.new();power_bar.custom_minimum_size=Vector2(300,10);power_bar.show_percentage=false;power_bar.max_value=100;power_bar.value=100;power_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("8fd18c");power_bar.add_theme_stylebox_override("fill",fill)
 var back:=StyleBoxFlat.new();back.bg_color=Color(.1,.12,.1,.9);power_bar.add_theme_stylebox_override("background",back);column.add_child(power_bar)
 wrong_text=_ui_label("",19,Color("e3efe0"));column.add_child(wrong_text)
 score_text=_ui_label("",19,Color("e3efe0"));column.add_child(score_text)
 time_text=_ui_label("",17,Color("b9c7b6"));column.add_child(time_text)
 sensor_text=_ui_label("",16,Color("d9c58e"));column.add_child(sensor_text)
 message=_ui_label("",26,Color("eee7d6"));message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);message.offset_left=-620;message.offset_right=620;message.offset_top=-150;message.offset_bottom=-70;message.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;message.add_theme_color_override("font_outline_color",Color(0,0,0,.9));message.add_theme_constant_override("outline_size",8);message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.add_child(message)
 hint=_ui_label("",16,Color("aab5a6"));hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hint.offset_top=-52;hint.offset_bottom=-22;hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(hint)
 _qte_ui();_book_ui()

func _ui_label(value: String, font_size: int, color: Color) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.add_theme_font_override("font",load("res://assets/Oswald.ttf"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;return label

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

func _book_ui() -> void:
 book=Control.new();book.name="ReportBookUI";book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(book)
 var shade:=ColorRect.new();shade.color=Color(0,0,0,.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);book.add_child(shade)
 shade.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:close_book())
 var paper:=PanelContainer.new();paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER);paper.offset_left=-660;paper.offset_right=660;paper.offset_top=-400;paper.offset_bottom=400
 var style:=StyleBoxFlat.new();style.bg_color=Color("d6ccae");style.border_color=Color("5e2620");style.set_border_width_all(10);style.set_corner_radius_all(6);style.set_content_margin_all(34);paper.add_theme_stylebox_override("panel",style);book.add_child(paper)
 var spread:=HBoxContainer.new();spread.add_theme_constant_override("separation",44);paper.add_child(spread)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=560;left.add_theme_constant_override("separation",10);spread.add_child(left)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=620;right.add_theme_constant_override("separation",10);spread.add_child(right)
 left.add_child(_ink("Meldebuch · Nachtwache",40,true))
 left.add_child(_ink("1. Raum",26,true))
 book_rooms=GridContainer.new();book_rooms.columns=2;book_rooms.add_theme_constant_override("h_separation",10);book_rooms.add_theme_constant_override("v_separation",8);left.add_child(book_rooms)
 for item in NightwatchConfig.ROOMS:
  var room_id: String=item.id
  var button:=_page_button(str(item.name),func():_choose("room",room_id));button.name="BookRoom_"+room_id;button.custom_minimum_size=Vector2(270,44);book_rooms.add_child(button)
 left.add_child(_ink("Letzte Einträge",22,true))
 book_log=_ink("",19,false);book_log.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;book_log.custom_minimum_size=Vector2(540,120);left.add_child(book_log)
 right.add_child(_ink("2. Bereich",26,true))
 book_areas=VBoxContainer.new();book_areas.add_theme_constant_override("separation",8);book_areas.custom_minimum_size.y=160;right.add_child(book_areas)
 right.add_child(_ink("3. Art der Anomalie",26,true))
 book_kinds=GridContainer.new();book_kinds.columns=2;book_kinds.add_theme_constant_override("h_separation",10);book_kinds.add_theme_constant_override("v_separation",8);right.add_child(book_kinds)
 for kind in NightwatchConfig.KIND_ORDER:
  var kind_id: String=kind
  var button:=_page_button(str(NightwatchConfig.KINDS[kind]),func():_choose("kind",kind_id));button.name="BookKind_"+kind_id;button.custom_minimum_size=Vector2(300,44);book_kinds.add_child(button)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);right.add_child(row)
 book_send=_page_button("Meldung abgeben",submit_book);book_send.name="BookSubmit";book_send.custom_minimum_size=Vector2(300,54);row.add_child(book_send)
 var close:=_page_button("Schließen · ESC",close_book);close.name="BookClose";close.custom_minimum_size=Vector2(240,54);row.add_child(close)
 book.hide()

func _ink(value: String, font_size: int, hand: bool) -> Label:
 var label:=Label.new();label.text=AfterPlayLanguage.t(value);label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("2c2a22"))
 label.add_theme_font_override("font",load("res://assets/backstage-v270/Caveat.ttf" if hand else "res://assets/Oswald.ttf"));return label

func _page_button(value: String, action: Callable) -> Button:
 var button:=Button.new();button.text=AfterPlayLanguage.t(value);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.focus_mode=Control.FOCUS_NONE
 button.add_theme_font_override("font",load("res://assets/Oswald.ttf"));button.add_theme_font_size_override("font_size",20)
 for state in ["normal","hover","pressed","disabled"]:
  var box:=StyleBoxFlat.new();box.set_content_margin_all(8);box.content_margin_left=14
  box.bg_color={"normal":Color(.36,.3,.2,.12),"hover":Color(.36,.3,.2,.28),"pressed":Color(.36,.15,.1,.4),"disabled":Color(.36,.3,.2,.05)}[state]
  box.border_color=Color("6b5a3c");box.border_width_bottom=2;button.add_theme_stylebox_override(state,box)
 for state in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(state,Color("2c2a22"))
 button.add_theme_color_override("font_disabled_color",Color("8a8270"))
 button.pressed.connect(action);return button

func _mark(button: Button, on: bool) -> void:
 var box:=StyleBoxFlat.new();box.set_content_margin_all(8);box.content_margin_left=14;box.border_color=Color("5e2620");box.border_width_bottom=2
 box.bg_color=Color(.55,.16,.12,.55) if on else Color(.36,.3,.2,.12);box.border_width_left=5 if on else 0
 button.add_theme_stylebox_override("normal",box);button.add_theme_color_override("font_color",Color("f3ead2") if on else Color("2c2a22"))

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

const DISTANT:=["res://assets/ambience-v193/ghost-run.wav","res://assets/annex/clown-sting.wav","res://assets/ambience/relay-tick.wav"]

# ---------------------------------------------------------------- run

func start(seed_value: int=-1) -> void:
 run_id+=1
 _clear_anomalies()
 w=g.world;rng.seed=seed_value if seed_value>=0 else int(Time.get_unix_time_from_system()*1000.)%2147483647
 anomalies=NightwatchAnomalies.new(w,rng.randi())
 running=true;over=false;reason="";seconds=0.;power=NightwatchConfig.POWER_START;wrong=0;reports=0;combo=0;best_combo=0;score_float=0.;repairs=0;failed_repairs=0;top_stage=1
 history.clear();spawn_clock=0.;next_spawn=NightwatchConfig.FIRST_ANOMALY;selected=0;refresh_index=0;view="monitors";yaw=FRONT.x;pitch=FRONT.y;anchor_yaw=FRONT.x;sway=Vector2.ZERO
 qte={};book_open=false;choice={"room":"","area":"","kind":""};message_time=0;beep_clock=0;glitch_clock=4.;glitch=0;ambience_clock=rng.randf_range(20,40);new_best=false
 for port in feeds:(port as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE
 main_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 select_camera(0,false)
 for row in lights:(row[0] as Light3D).light_energy=float(row[1])
 show();cam.current=true;cam.rotation=Vector3(pitch,yaw,0)
 layer.show();hud.show();book.hide();qte_panel.hide();message.text="";_say("Nachtwache beginnt. Beobachte die Kameras und melde jede Anomalie im Buch.",6.)
 hum.play();engine.play();engine.volume_db=-34;beep.stop()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 _refresh_book();_refresh_hud();set_process(false)

# Called by the game every frame while the mode is on screen.
func tick(delta: float) -> void:
 if not running:return
 seconds+=delta
 var stage:=NightwatchConfig.stage_of(seconds);top_stage=maxi(top_stage,stage)
 var cfg:=NightwatchConfig.stage(stage)
 power=maxf(power-float(cfg.drain)*delta,0.)
 score_float+=NightwatchConfig.POINTS_PER_SECOND*delta
 if power<=0.:_game_over("power");return
 if qte.is_empty():
  # Anomaly timers and spawns only run while the cameras can be watched.
  for record in active:
   anomalies.tick(record,delta)
   record.left=float(record.left)-delta
   if float(record.left)<=0.:
    record.state="expired";_game_over("missed",record);return
  spawn_clock+=delta
  if spawn_clock>=next_spawn and active.size()<int(cfg.active):_spawn(stage)
 else:
  for record in active:anomalies.tick(record,0.)
  _tick_qte(delta)
  if not running:return
 _tick_screens(delta)
 _tick_alarm(delta)
 _tick_view(delta)
 ambience_clock-=delta
 if ambience_clock<=0:
  ambience_clock=rng.randf_range(25,55)
  var path: String=DISTANT[rng.randi_range(0,DISTANT.size()-1)]
  if ResourceLoader.exists(path):distant.stream=load(path);distant.pitch_scale=rng.randf_range(.75,1.0);distant.volume_db=-26;distant.play()
 if message_time>0:
  message_time-=delta
  if message_time<=0:message.text=""
 _refresh_hud()

func _spawn(stage: int) -> void:
 var busy:={}
 for record in active:busy[str(record.room)+"/"+str(record.area)]=true
 for attempt in range(6):
  var option:=anomalies.pick(stage,busy)
  if option.is_empty():return
  var area:=NightwatchConfig.area(option.room,option.area)
  var spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(area.camera)]
  var record:=anomalies.apply(option,spec,float(NightwatchConfig.stage(stage).detect))
  if record.is_empty():continue
  record.started=seconds;record.stage=stage;active.append(record)
  spawn_clock=0;var base: float=NightwatchConfig.stage(stage).interval;next_spawn=base*rng.randf_range(1.-NightwatchConfig.JITTER,1.+NightwatchConfig.JITTER)
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
 var record:=anomalies.apply(option,cam_spec,float(NightwatchConfig.stage(NightwatchConfig.stage_of(seconds)).detect))
 if record.is_empty():return {}
 record.started=seconds;record.stage=NightwatchConfig.stage_of(seconds);active.append(record);return record

func report(room_id: String, area_id: String, kind: String) -> Dictionary:
 if not running:return {"accepted":false}
 var room_name: String=NightwatchConfig.room(room_id).get("name",room_id)
 var area_name: String=NightwatchConfig.area(room_id,area_id).get("name",area_id)
 var entry:="%s · %s · %s"%[room_name,area_name,NightwatchConfig.KINDS.get(kind,kind)]
 for record in active:
  if record.room==room_id and record.area==area_id and record.kind==kind:
   record.state="reported";anomalies.revert(record);active.erase(record)
   var points:=NightwatchConfig.POINTS_REPORT+NightwatchConfig.POINTS_COMBO*mini(combo,NightwatchConfig.POINTS_COMBO_MAX)
   combo+=1;best_combo=maxi(best_combo,combo);reports+=1;score_float+=points
   history.push_front("✓ "+entry);_say("Meldung bestätigt: %s  (+%d)"%[entry,points],4.)
   switch_sound.pitch_scale=1.2;switch_sound.play()
   if g.achievements:
    g.achievements.unlock("nightwatch_first")
    if reports>=10:g.achievements.unlock("nightwatch_10")
    if reports>=25:g.achievements.unlock("nightwatch_25")
   history=history.slice(0,5);_refresh_book();return {"accepted":true,"correct":true,"points":points}
 wrong+=1;combo=0
 history.push_front("✗ "+entry);history=history.slice(0,5)
 buzz.play()
 if wrong>=NightwatchConfig.MAX_WRONG:
  _game_over("wrong");return {"accepted":true,"correct":false,"over":true}
 _say("Fehlmeldung: Dort ist nichts. Fehlmeldungen %d / %d"%[wrong,NightwatchConfig.MAX_WRONG],4.)
 _refresh_book();return {"accepted":true,"correct":false}

# ---------------------------------------------------------------- generator

func start_qte() -> bool:
 if not running or not qte.is_empty() or power<=0:return false
 var stage:=NightwatchConfig.stage_of(seconds);var cfg:=NightwatchConfig.qte(stage)
 qte={"stage":stage,"words":NightwatchConfig.words_for(stage,rng),"index":0,"typed":0,"time":float(cfg.time),"left":float(cfg.time),"flash":0.}
 close_book();qte_panel.show();_refresh_qte()
 engine.volume_db=-14+mini(stage,8)*.9;engine.pitch_scale=.75+stage*.05
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
 var stage: int=int(qte.stage)
 qte={};qte_panel.hide();engine.volume_db=-34;engine.pitch_scale=1.
 if success:
  power=NightwatchConfig.POWER_START;repairs+=1;score_float+=NightwatchConfig.POINTS_GENERATOR*stage;beep.stop();beep_clock=0
  switch_sound.pitch_scale=1.;switch_sound.play();_say("Generator läuft wieder. Strom 100 %",3.5)
  if g.achievements and repairs>=5:g.achievements.unlock("nightwatch_generator")
 else:
  failed_repairs+=1;thud.play();_say("Neustart fehlgeschlagen. Versuch es noch einmal, solange Strom da ist.",4.)

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
 qte_bar.value=share*100.;qte_time.text="Noch %.1f s  ·  Wort %d / %d  ·  Stufe %d"%[float(qte.left),mini(int(qte.index)+1,words.size()),words.size(),int(qte.stage)]
 var urgent:=share<.3
 (qte_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color=Color("ff5a46") if urgent else Color("d9b25a")
 qte_title.text="GENERATOR-NEUSTART  ·  TIPPE DIE WÖRTER"+("  ·  SCHNELL!" if urgent else "")

# ---------------------------------------------------------------- book

func open_book() -> void:
 if not running or not qte.is_empty() or book_open:return
 book_open=true;book.show();switch_sound.pitch_scale=1.4;switch_sound.play();_refresh_book()

func close_book() -> void:
 if not book_open:return
 book_open=false;book.hide()

func _choose(field: String, value: String) -> void:
 choice[field]=value
 if field=="room":choice.area=""
 click.play();_refresh_book()

func submit_book() -> void:
 if choice.room=="" or choice.area=="" or choice.kind=="":return
 var result:=report(choice.room,choice.area,choice.kind)
 choice={"room":"","area":"","kind":""}
 if running:close_book()
 if result.get("correct",false):pass

func _refresh_book() -> void:
 if not book_rooms:return
 for button: Button in book_rooms.get_children():_mark(button,button.name=="BookRoom_"+str(choice.room))
 for child in book_areas.get_children():book_areas.remove_child(child);child.queue_free()
 if choice.room=="":book_areas.add_child(_ink("Wähle zuerst einen Raum.",21,false))
 else:
  for item in NightwatchConfig.room(choice.room).areas:
   var area_id: String=item.id
   var button:=_page_button(str(item.name),func():_choose("area",area_id));button.name="BookArea_"+area_id;button.custom_minimum_size=Vector2(400,44);book_areas.add_child(button);_mark(button,area_id==choice.area)
 for button: Button in book_kinds.get_children():_mark(button,button.name=="BookKind_"+str(choice.kind))
 book_send.disabled=choice.room=="" or choice.area=="" or choice.kind==""
 book_log.text="\n".join(history) if not history.is_empty() else "Noch keine Einträge."

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
 var clock:=int(seconds)+23*3600
 stamp_label.text="%02d:%02d:%02d"%[(clock/3600)%24,(clock/60)%60,clock%60]
 power_label.text="STROM %d %%"%ceili(power)
 power_label.modulate=Color("ff6a50") if power<=NightwatchConfig.ALARM else Color("d8f0d8")
 var blink:=power>NightwatchConfig.ALARM or fmod(seconds,.6)<.3
 gen_label.text="%03d %%"%ceili(power)
 gen_label.modulate=Color("7dff8a") if power>NightwatchConfig.ALARM else (Color("ff5a40") if blink else Color("5a2018"))
 var room_dim:=1. if power>NightwatchConfig.CRITICAL else .6+.4*float(glitch<.3)
 for row in lights:(row[0] as Light3D).light_energy=float(row[1])*room_dim

func _tick_alarm(delta: float) -> void:
 if power>NightwatchConfig.ALARM:beep_clock=0;return
 beep_clock-=delta
 if beep_clock<=0:
  beep.pitch_scale=1.0 if power>NightwatchConfig.CRITICAL else 1.18;beep.play()
  beep_clock=lerpf(.22,1.35,clampf(power/NightwatchConfig.ALARM,0,1)) if power>NightwatchConfig.CRITICAL else lerpf(.16,.4,clampf(power/NightwatchConfig.CRITICAL,0,1))

func alarm_active() -> bool:
 return running and power<=NightwatchConfig.ALARM

# Seated look: the cursor near a screen edge pans the head smoothly; A/D and
# clicks ease to the monitor wall or the generator. The camera follows with
# frame-rate independent damping and a faint drift with the cursor.
func _tick_view(delta: float) -> void:
 var size_value:=get_viewport().get_visible_rect().size
 var mouse:=get_viewport().get_mouse_position()/size_value
 var inside:=mouse.x>=0. and mouse.x<=1. and mouse.y>=0. and mouse.y<=1.
 if qte.is_empty() and not book_open and inside and DisplayServer.window_is_focused():
  var push:=0.
  if mouse.x>1.-EDGE:push=-smoothstep(0.,1.,(mouse.x-(1.-EDGE))/EDGE)
  elif mouse.x<EDGE:push=smoothstep(0.,1.,(EDGE-mouse.x)/EDGE)
  anchor_yaw=clampf(anchor_yaw+push*PAN_SPEED*delta,YAW_RIGHT,YAW_LEFT)
 view="generator" if anchor_yaw<(FRONT.x+RIGHT.x)*.5 else "monitors"
 var drift:=Vector2.ZERO
 if inside and not book_open and qte.is_empty():drift=Vector2(-(clampf(mouse.x,EDGE,1.-EDGE)-.5)*.05,-(mouse.y-.5)*.05)
 var ease_value:=1.-exp(-delta*SMOOTH)
 sway=sway.lerp(drift,1.-exp(-delta*3.))
 yaw=lerpf(yaw,anchor_yaw+sway.x,ease_value)
 var turn:=clampf((yaw-FRONT.x)/(RIGHT.x-FRONT.x),0.,1.)
 var breathe:=sin(seconds*1.3)*.0025
 pitch=lerpf(pitch,lerpf(FRONT.y,RIGHT.y,smoothstep(0.,1.,turn))+sway.y+breathe,ease_value)
 cam.rotation=Vector3(pitch,yaw,0)
 _hover(get_viewport().get_mouse_position())

func look(where: String) -> void:
 if not qte.is_empty():return
 anchor_yaw=RIGHT.x if where=="generator" else FRONT.x
 view=where;close_book()

func _pick(screen: Vector2) -> String:
 var space:=get_world_3d().direct_space_state
 var from:=cam.project_ray_origin(screen);var to:=from+cam.project_ray_normal(screen)*6.
 var query:=PhysicsRayQueryParameters3D.create(from,to,CLICK_LAYER);query.collide_with_areas=false
 var hit:=space.intersect_ray(query)
 if hit.is_empty():return ""
 return str((hit.collider as Node).get_meta("nightwatch",""))

func _hover(screen: Vector2) -> void:
 var target:=_pick(screen) if not book_open and qte.is_empty() else ""
 Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if target!="" else Input.CURSOR_ARROW)
 if book_open:hint.text="Raum, Bereich und Art wählen · Meldung abgeben · ESC schließt das Buch"
 elif not qte.is_empty():hint.text="Tippe die Wörter in der richtigen Reihenfolge"
 elif view=="generator":hint.text="Generator anklicken: Neustart  ·  Maus an den linken Rand oder A / ←: zurück zu den Monitoren"
 else:hint.text="Monitor oder Taste am Pult anklicken, 1–0 oder Mausrad: Kamera  ·  Buch: Meldung  ·  Maus an den rechten Rand oder D / →: Generator  ·  ESC: Pause"

func click_at(screen: Vector2) -> bool:
 if not running or book_open or not qte.is_empty():return false
 var target:=_pick(screen)
 if target.begins_with("monitor:"):select_camera(int(target.get_slice(":",1)));return true
 if target=="main":return true
 if target=="book":
  look("monitors");open_book();return true
 if target=="generator":
  look("generator");return start_qte()
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
 if book_open:
  if event.is_action_pressed("pause"):close_book();return true
  return false
 if event is InputEventMouseButton and event.pressed:
  var button_event:=event as InputEventMouseButton
  if button_event.button_index==MOUSE_BUTTON_LEFT:return click_at(button_event.position)
  if button_event.button_index==MOUSE_BUTTON_WHEEL_UP:select_camera(selected-1);return true
  if button_event.button_index==MOUSE_BUTTON_WHEEL_DOWN:select_camera(selected+1);return true
 if event is InputEventKey and event.pressed and not event.echo:
  var key:=(event as InputEventKey).physical_keycode
  if key>=KEY_1 and key<=KEY_9:select_camera(key-KEY_1);return true
  if key==KEY_0:select_camera(9);return true
  if key in [KEY_D,KEY_RIGHT]:look("generator");return true
  if key in [KEY_A,KEY_LEFT]:look("monitors");return true
  if key==KEY_Q:select_camera(selected-1);return true
  if key==KEY_E:select_camera(selected+1);return true
  if key in [KEY_B,KEY_TAB] and view=="monitors":open_book();return true
 return false

# ---------------------------------------------------------------- HUD

func _say(value: String, duration: float) -> void:
 message.text=AfterPlayLanguage.t(value);message_time=duration

func score() -> int:
 return int(score_float)

func _refresh_hud() -> void:
 power_text.text="STROM %d %%"%ceili(power)+("  ·  WARNUNG" if power<=NightwatchConfig.ALARM else "")
 power_bar.value=power
 var fill:=power_bar.get_theme_stylebox("fill") as StyleBoxFlat
 fill.bg_color=Color("8fd18c") if power>NightwatchConfig.FLICKER_LIGHT else Color("e0c060") if power>NightwatchConfig.ALARM else Color("ff5a46")
 power_text.add_theme_color_override("font_color",Color("ff7a64") if power<=NightwatchConfig.ALARM else Color("e3efe0"))
 var marks:=""
 for i in range(NightwatchConfig.MAX_WRONG):marks+="✗ " if i<wrong else "○ "
 wrong_text.text="FEHLMELDUNGEN  %s  %d / %d"%[marks,wrong,NightwatchConfig.MAX_WRONG]
 wrong_text.add_theme_color_override("font_color",Color("ff7a64") if wrong>=NightwatchConfig.MAX_WRONG-1 else Color("e3efe0"))
 score_text.text="PUNKTE  %d"%score()+("  ·  SERIE %d"%combo if combo>1 else "")
 time_text.text="SCHICHT  %02d:%02d  ·  STUFE %d"%[int(seconds)/60,int(seconds)%60,NightwatchConfig.stage_of(seconds)]
 sensor_text.text="SENSOREN: KEINE AUFFÄLLIGKEIT" if active.is_empty() else "SENSOREN: %d UNGEKLÄRTE %s"%[active.size(),"VORFALL" if active.size()==1 else "VORFÄLLE"]

# ---------------------------------------------------------------- the end

func _game_over(why: String, record: Dictionary={}) -> void:
 if over:return
 over=true;running=false;reason=why
 var this_run:=run_id
 if book_open:close_book()
 qte={};qte_panel.hide();beep.stop();engine.volume_db=-34;Input.set_default_cursor_shape(Input.CURSOR_ARROW)
 if g.achievements:
  new_best=g.achievements.record_nightwatch(score(),seconds)
  if seconds>=600:g.achievements.unlock("nightwatch_10min")
  if score()>=5000:g.achievements.unlock("nightwatch_5000")
 g.phase="nightwatch_end"
 match why:
  "power":
   hum.stop();engine.stop();thud.play()
   for material in [main_material]+small_materials:(material as ShaderMaterial).set_shader_parameter("dim",0.)
   for row in lights:(row[0] as Light3D).light_energy=0.
   _say("STROMAUSFALL",4.)
  "missed":
   if not record.is_empty():
    var index:=NightwatchConfig.camera_index(str(NightwatchConfig.area(record.room,record.area).camera))
    if index>=0:select_camera(index,false)
    view="monitors"
    _say("ANOMALIE ÜBERSEHEN: %s · %s · %s"%[NightwatchConfig.room(record.room).name,NightwatchConfig.area(record.room,record.area).name,NightwatchConfig.KINDS[record.kind]],4.)
  "wrong":
   thud.play();_say("ZU VIELE FEHLMELDUNGEN",4.)
 ended.emit(why)
 await get_tree().create_timer(1.7 if why!="wrong" else 1.3).timeout
 if this_run!=run_id or not is_instance_valid(g):return
 if why in ["power","missed"] and g.phase=="nightwatch_end":
  g.phase="nightwatch_scare";hud.hide()
  scare.start_patrol(w,cam)
  await scare.finished
  if this_run!=run_id:return
 if g.phase in ["nightwatch_end","nightwatch_scare"]:g._nightwatch_results()

func results() -> Dictionary:
 return {"reason":reason,"title":REASONS.get(reason,reason),"score":score(),"seconds":seconds,"reports":reports,"wrong":wrong,"repairs":repairs,"failed_repairs":failed_repairs,"stage":top_stage,"best_combo":best_combo,"new_best":new_best}

func _clear_anomalies() -> void:
 if anomalies:
  for record in active:anomalies.revert(record)
 active.clear()

# Leaves the mode: every change in the world is undone, the screens stop.
func stop() -> void:
 run_id+=1;running=false;qte={};book_open=false
 _clear_anomalies()
 for port in feeds:(port as SubViewport).render_target_update_mode=SubViewport.UPDATE_DISABLED
 if main_view:main_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for player in [hum,beep,engine,distant]:if player:(player as AudioStreamPlayer).stop()
 if layer:layer.hide()
 Input.set_default_cursor_shape(Input.CURSOR_ARROW)
 if scare:scare.running=false;scare.hide()
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
 return {"running":running,"over":over,"reason":reason,"seconds":snappedf(seconds,.1),"power":snappedf(power,.1),"wrong":wrong,"reports":reports,"score":score(),"stage":NightwatchConfig.stage_of(seconds),"active":open,"camera":selected,"view":view,"book":book_open,"qte":not qte.is_empty(),"alarm":alarm_active()}
