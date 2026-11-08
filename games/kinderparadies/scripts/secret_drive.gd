class_name SecretDrive
extends Node3D

# The secret ending's drive home: first person behind the wheel of an old car
# on a broken forest road at night in the rain. A red, screamed line; the
# driver looks up into the rear-view mirror; two dead children are suddenly on
# the back seat and one of them lunges into the driver's face, shrieking.
signal finished
const LINE:="Du bist bald genau so tot wie wir"
const ROOT:="res://assets/drive-v430/"
const SPEED:=8.6
const START_S:=6.0
const FADE_IN:=2.2
const SHOUT_AT:=4.0
const SHOUT_FALL:=7.5
const LOOK_AT:=9.9
const LOOK_TIME:=1.05
const REVEAL_AT:=11.2
const STARE_AT:=11.85
const LUNGE_AT:=12.4
const LUNGE_TIME:=.17
const CUT_AT:=13.02
const LENGTH:=15.0
const POTHOLES:=[17.,29.5,43.,51.,66.,79.,93.,104.,117.]
const EYE:=Vector3(-.36,1.22,.12)
const MIRROR:=Vector3(.02,1.335,-.60)

var g: Node3D
var ui: Control
var clock:=0.0
var running:=false
var done:=false
var env: Environment
var body: Node3D
var car: Node3D
var head: Node3D
var camera: Camera3D
var face_light: OmniLight3D
var prior_camera: Camera3D
var mirror_view: SubViewport
var mirror_camera: Camera3D
var mirror_holder: Node3D
var rear_dir:=Vector3.BACK
var wheel: Node3D
var wipers: Array[Node3D]=[]
var glass: ShaderMaterial
var lightning: DirectionalLight3D
var dash_light: OmniLight3D
var rear_light: OmniLight3D
var girl: Node3D
var boy: Node3D
var girl_head: Node3D
var boy_head: Node3D
var girl_arms: Array[Node3D]=[]
var girl_seat: Transform3D
var lunge_from: Transform3D
var shade: ColorRect
var shout: ShoutText
var falling: Array[Dictionary]=[]
var engine: AudioStreamPlayer
var rain: AudioStreamPlayer
var bump: AudioStreamPlayer
var voice: AudioStreamPlayer
var drone: AudioStreamPlayer
var shriek: AudioStreamPlayer
var thunder: AudioStreamPlayer
var bumps_played:=0
var cues: Dictionary={}
var rng:=RandomNumberGenerator.new()
var strobe:=true

static func center(s: float) -> Vector3:
 return Vector3(5.5*sin(s*.021)+2.2*sin(s*.053+1.3),.55*sin(s*.034)+.22*sin(s*.09),-s)

static func frame_at(s: float) -> Transform3D:
 var ahead:=(center(s+1.6)-center(s-1.6)).normalized()
 var right:=ahead.cross(Vector3.UP).normalized()
 return Transform3D(Basis.looking_at(ahead,Vector3.UP),center(s)+right*1.05)

func build(game: Node3D,overlay: Control) -> void:
 g=game;ui=overlay;name="SecretDriveHome";rng.seed=430;position=Vector3(3000,0,0);hide()
 strobe=bool(g.settings.get("strobe",true))
 env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("020305")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("1b2433");env.ambient_light_energy=.06
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=1.05
 env.fog_enabled=true;env.fog_light_color=Color("040508");env.fog_density=.011
 env.volumetric_fog_enabled=true;env.volumetric_fog_density=.012;env.volumetric_fog_albedo=Color(.55,.6,.66);env.volumetric_fog_length=48;env.volumetric_fog_ambient_inject=0.
 env.glow_enabled=true;env.glow_intensity=.55;env.glow_bloom=.04
 env.ssao_enabled=true;env.ssao_radius=.6;env.ssao_intensity=1.4
 env.adjustment_enabled=true;env.adjustment_brightness=float(g.settings.get("brightness",1.15))/1.15;env.adjustment_saturation=.82
 _forest()
 car=Node3D.new();car.name="OldCar";add_child(car)
 body=Node3D.new();body.name="SprungBody";car.add_child(body)
 _cabin()
 _children()
 head=Node3D.new();head.name="DriverHead";head.position=EYE;body.add_child(head)
 camera=Camera3D.new();camera.name="DriverEyes";camera.fov=72;camera.near=.02;camera.far=140;camera.environment=env;head.add_child(camera)
 face_light=OmniLight3D.new();face_light.position=Vector3(.05,-.2,-.08);face_light.light_color=Color("cfd7e6");face_light.omni_range=1.1;face_light.light_energy=0;camera.add_child(face_light)
 _mirror()
 lightning=DirectionalLight3D.new();lightning.name="Lightning";lightning.rotation=Vector3(-1.05,.6,0);lightning.light_color=Color("c9d6ff");lightning.light_energy=0;add_child(lightning)
 engine=_audio("drive-loop.ogg",-60,true);rain=_audio("res://assets/weather-v352/soft-roof-rain.ogg",-60,true)
 bump=_audio("pothole-1.ogg",-3);voice=_audio("shout.ogg",-1.5);drone=_audio("mirror-drone.ogg",-4);shriek=_audio("child-shriek.ogg",0)
 thunder=_audio("res://assets/weather-v352/distant-thunder-2.ogg",-6)
 shade=ColorRect.new();shade.name="DriveShade";shade.color=Color.BLACK;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.hide();ui.add_child(shade)
 shout=ShoutText.new();shout.name="ScreamedRedLine";shout.mouse_filter=Control.MOUSE_FILTER_IGNORE;shout.position=Vector2(960,770);shout.hide();ui.add_child(shout)
 _place(0.)

func _audio(file: String,db: float,loop:=false) -> AudioStreamPlayer:
 var player:=AudioStreamPlayer.new();player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var stream: AudioStream=load(file if file.begins_with("res://") else ROOT+file)
 if loop:
  stream=stream.duplicate()
  if stream is AudioStreamOggVorbis:(stream as AudioStreamOggVorbis).loop=true
 player.stream=stream;player.volume_db=db;add_child(player);return player

# ---------------------------------------------------------------- the forest
func _strip(from_s: float,to_s: float,lateral: Array,lift: Callable,material: Material) -> MeshInstance3D:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows:=0;var s:=from_s
 while s<=to_s:
  var c:=center(s);var ahead:=(center(s+1.)-center(s-1.)).normalized();var right:=ahead.cross(Vector3.UP).normalized()
  for i in range(lateral.size()):
   var x: float=lateral[i]
   tool.set_uv(Vector2(float(i)/(lateral.size()-1),s/4.))
   tool.add_vertex(c+right*x+Vector3.UP*float(lift.call(x,s)))
  rows+=1;s+=.8
 var cols:=lateral.size()
 for r in range(rows-1):
  for i in range(cols-1):
   var a:=r*cols+i;var b:=a+cols
   tool.add_index(a);tool.add_index(b);tool.add_index(a+1)
   tool.add_index(a+1);tool.add_index(b);tool.add_index(b+1)
 tool.generate_normals();tool.generate_tangents()
 var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit();mesh.material_override=material;add_child(mesh);return mesh

func _forest() -> void:
 var road:=ShaderMaterial.new();road.shader=load(ROOT+"forest_road.gdshader")
 road.set_shader_parameter("albedo_tex",load("res://assets/pbr/concrete_floor_worn_001/albedo.jpg"))
 road.set_shader_parameter("normal_tex",load("res://assets/pbr/concrete_floor_worn_001/normal.jpg"))
 # The tarmac is slightly cambered and sags at its broken edges.
 _strip(-20,260,[-3.,-2.2,-1.1,0.,1.1,2.2,3.],func(x: float,s: float)->float:return .03-.012*x*x/9.-.05*maxf(0,absf(x)-2.4)+.012*sin(s*1.7+x),road).name="BrokenForestRoad"
 var ground:=ShaderMaterial.new();ground.shader=load(ROOT+"forest_floor.gdshader")
 var sides: Array=[]
 for x in [-70.,-40.,-22.,-12.,-7.,-4.5,-3.2,-2.9,2.9,3.2,4.5,7.,12.,22.,40.,70.]:sides.append(x)
 _strip(-20,260,sides,func(x: float,s: float)->float:return -.06-.18*clampf((absf(x)-3.)/1.5,0,1)+(absf(x)-4.5)*.04*sin(s*.11+x*.2)*float(absf(x)>4.5),ground).name="ForestFloor"
 var bark:=StandardMaterial3D.new();bark.albedo_texture=load("res://assets/wood.png");bark.albedo_color=Color("1d1916");bark.roughness=.95;bark.uv1_scale=Vector3(1,8,1)
 var needles:=StandardMaterial3D.new();needles.albedo_color=Color("08100a");needles.roughness=.95
 var bush:=StandardMaterial3D.new();bush.albedo_color=Color("070b06");bush.roughness=.9
 var trunk_mesh:=CylinderMesh.new();trunk_mesh.top_radius=.09;trunk_mesh.bottom_radius=.28;trunk_mesh.height=18;trunk_mesh.radial_segments=10;trunk_mesh.material=bark
 var crown_mesh:=CylinderMesh.new();crown_mesh.top_radius=0;crown_mesh.bottom_radius=1.45;crown_mesh.height=3.4;crown_mesh.radial_segments=14;crown_mesh.cap_bottom=true;crown_mesh.material=needles
 var bush_mesh:=SphereMesh.new();bush_mesh.radius=.55;bush_mesh.height=.7;bush_mesh.radial_segments=10;bush_mesh.rings=5;bush_mesh.material=bush
 var trunks: Array[Transform3D]=[];var crowns: Array[Transform3D]=[];var bushes: Array[Transform3D]=[]
 var s:=-20.
 while s<262:
  for side: float in [-1.,1.]:
   var c:=center(s);var ahead:=(center(s+1.)-center(s-1.)).normalized();var right:=ahead.cross(Vector3.UP).normalized()
   for k in range(4):
    var lateral:=5.6+pow(rng.randf(),1.6)*42.+k*2.5
    var p:=c+right*side*lateral+ahead*rng.randf_range(-.5,.5);p.y=c.y-.25
    var sz:=rng.randf_range(.75,1.3)
    var lean:=Basis(Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized(),rng.randf_range(0,.07))
    trunks.append(Transform3D(lean.scaled(Vector3(sz,rng.randf_range(.8,1.15),sz)),p+lean*Vector3(0,8.5,0)))
    if rng.randf()<.78:
     for tier in range(6):
      var h:=5.2+tier*1.9+rng.randf_range(-.3,.3);var size:=(1.3-tier*.19)*sz*rng.randf_range(.85,1.1)
      crowns.append(Transform3D(lean.rotated(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size*.9,size)),p+lean*Vector3(0,h,0)))
   if rng.randf()<.8:
    var q:=c+right*side*rng.randf_range(3.6,9.);q.y=c.y-.2
    bushes.append(Transform3D(Basis.IDENTITY.rotated(Vector3.UP,rng.randf()*TAU).scaled(Vector3(rng.randf_range(.6,1.4),rng.randf_range(.5,1.),rng.randf_range(.6,1.4))),q))
  s+=1.15
 for entry in [[trunk_mesh,trunks,"Trunks"],[crown_mesh,crowns,"Needles"],[bush_mesh,bushes,"Undergrowth"]]:
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=entry[0];mm.instance_count=entry[1].size()
  for i in range(entry[1].size()):mm.set_instance_transform(i,entry[1][i])
  var node:=MultiMeshInstance3D.new();node.name=entry[2];node.multimesh=mm;add_child(node)
 # German roadside delineators: white posts with a black band and a reflector.
 var white:=StandardMaterial3D.new();white.albedo_color=Color("a9a79c");white.roughness=.7
 var black:=StandardMaterial3D.new();black.albedo_color=Color("111111")
 var amber:=StandardMaterial3D.new();amber.albedo_color=Color("d07a1c");amber.emission_enabled=true;amber.emission=Color("ff8a1a");amber.emission_energy_multiplier=.6;amber.metallic=.4;amber.roughness=.2
 s=12.
 while s<250:
  for side in [-1,1]:
   var f:=frame_at(s);var c:=center(s);var right:=f.basis.x
   var post:=Node3D.new();post.position=c+right*side*3.55+Vector3(0,-.05,0);post.basis=f.basis;post.rotation.z+=rng.randf_range(-.12,.12)*float(rng.randf()<.3);add_child(post)
   _box(post,Vector3(0,.5,0),Vector3(.11,1.0,.11),white);_box(post,Vector3(0,.82,0),Vector3(.115,.15,.115),black)
   _box(post,Vector3(-side*.0,.82,.06),Vector3(.05,.1,.01),amber)
  s+=50.

func _box(parent: Node3D,p: Vector3,size: Vector3,material: Material,rot:=Vector3.ZERO) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=material;mesh.position=p;mesh.rotation=rot;parent.add_child(mesh);return mesh

func _textured(folder: String,tint: Color,scale: float,rough:=.8) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_texture=load("res://assets/pbr/%s/albedo.jpg"%folder);m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/%s/normal.jpg"%folder)
 m.albedo_color=tint;m.roughness=rough;m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*scale;return m

# ---------------------------------------------------------------- the car
func _cabin() -> void:
 var dash:=_textured("fabric_leather_01",Color("2a2a2c"),3.,.7)
 var cloth:=_textured("fabric_leather_01",Color("2c2a29"),2.5,.75)
 var roof:=StandardMaterial3D.new();roof.albedo_color=Color("2a2927");roof.roughness=1.
 var carpet:=_textured("dirty_carpet",Color("2a2622"),2.,.95)
 var dark:=StandardMaterial3D.new();dark.albedo_color=Color("0b0b0c");dark.roughness=.5
 var paint:=StandardMaterial3D.new();paint.albedo_color=Color("3b0b0e");paint.metallic=.55;paint.roughness=.28;paint.clearcoat_enabled=true;paint.clearcoat=.8
 var side_glass:=StandardMaterial3D.new();side_glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;side_glass.albedo_color=Color(.04,.05,.06,.28);side_glass.roughness=.08;side_glass.metallic=.3
 # Dashboard, instrument binnacle, centre console.
 _box(body,Vector3(0,.86,-.86),Vector3(1.56,.24,.42),dash)
 _box(body,Vector3(0,.995,-.80),Vector3(1.56,.05,.40),dash,Vector3(-.18,0,0))
 _box(body,Vector3(0,.99,-1.0),Vector3(1.5,.04,.12),dash)
 _box(body,Vector3(-.36,1.055,-.74),Vector3(.46,.04,.16),dash,Vector3(.14,0,0))
 _box(body,Vector3(-.36,.985,-.70),Vector3(.43,.12,.02),dark)
 var dial:=StandardMaterial3D.new();dial.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;dial.albedo_texture=_dial_texture();dial.emission_enabled=true;dial.emission_texture=dial.albedo_texture;dial.emission=Color.WHITE;dial.emission_energy_multiplier=.55
 for x in [-.465,-.255]:
  var face:=MeshInstance3D.new();var disc:=QuadMesh.new();disc.size=Vector2(.12,.12);face.mesh=disc;face.material_override=dial;face.position=Vector3(x,.985,-.688);body.add_child(face)
  var needle:=Node3D.new();needle.position=Vector3(x,.985,-.686);needle.rotation.z=-.4+(.9 if x< -.3 else .3);body.add_child(needle);needle.set_meta("dial",x)
  var red:=StandardMaterial3D.new();red.albedo_color=Color("ff3b1f");red.emission_enabled=true;red.emission=Color("ff3b1f");red.emission_energy_multiplier=1.1
  _box(needle,Vector3(0,.025,0),Vector3(.004,.05,.002),red)
 _box(body,Vector3(0,.62,-.55),Vector3(.28,.40,.6),dash)
 var clock_text:=Label3D.new();clock_text.text="03:13";clock_text.font_size=48;clock_text.pixel_size=.0007;clock_text.modulate=Color("6fe3a6");clock_text.shaded=false;clock_text.outline_size=0
 clock_text.position=Vector3(0,.885,-.655);body.add_child(clock_text)
 _box(body,Vector3(0,.885,-.66),Vector3(.16,.045,.008),dark)
 # Steering wheel and column.
 var tilt:=Node3D.new();tilt.name="SteeringColumn";tilt.position=Vector3(-.36,.95,-.50);tilt.rotation.x=1.2;body.add_child(tilt)
 wheel=Node3D.new();wheel.name="SteeringWheel";tilt.add_child(wheel)
 var rim:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.162;torus.outer_radius=.192;torus.rings=48;torus.ring_segments=10;rim.mesh=torus;rim.material_override=dash;wheel.add_child(rim)
 _box(wheel,Vector3(-.09,0,.01),Vector3(.15,.022,.035),dash);_box(wheel,Vector3(.09,0,.01),Vector3(.15,.022,.035),dash);_box(wheel,Vector3(0,0,.09),Vector3(.04,.022,.15),dash)
 var hub:=MeshInstance3D.new();var cyl:=CylinderMesh.new();cyl.top_radius=.055;cyl.bottom_radius=.06;cyl.height=.05;hub.mesh=cyl;hub.material_override=dark;wheel.add_child(hub)
 var column:=MeshInstance3D.new();var stalk:=CylinderMesh.new();stalk.top_radius=.035;stalk.bottom_radius=.045;stalk.height=.32;column.mesh=stalk;column.material_override=dark;column.position=Vector3(0,-.17,0);tilt.add_child(column)
 # Windscreen with beaded rain and two wipers.
 var screen:=Node3D.new();screen.name="Windscreen";screen.position=Vector3(0,1.21,-.795);screen.rotation.x=.84;body.add_child(screen)
 glass=ShaderMaterial.new();glass.shader=load(ROOT+"windscreen.gdshader")
 var pane:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.46,.66);pane.mesh=quad;pane.material_override=glass;pane.layers=2;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;screen.add_child(pane)
 for pivot in [Vector2(.20,.02),Vector2(.62,.02)]:
  var arm:=Node3D.new();arm.position=Vector3((pivot.x-.5)*1.46,(pivot.y-.5)*.66,-.015);screen.add_child(arm);wipers.append(arm)
  _box(arm,Vector3(.25,0,-.006),Vector3(.5,.011,.012),dark);_box(arm,Vector3(.27,0,.0),Vector3(.47,.007,.016),dark)
 for side in [-1,1]:
  _box(body,Vector3(side*.715,1.21,-.795),Vector3(.09,.70,.075),dash,Vector3(.84,0,0))
  _box(body,Vector3(side*.80,.74,.25),Vector3(.06,.56,2.3),dash)
  _box(body,Vector3(side*.78,1.02,.25),Vector3(.1,.04,2.2),dash)
  _box(body,Vector3(side*.78,1.23,.58),Vector3(.08,.42,.13),dash)
  var window:=MeshInstance3D.new();var wq:=QuadMesh.new();wq.size=Vector2(2.1,.38);window.mesh=wq;window.material_override=side_glass;window.position=Vector3(side*.81,1.22,.15);window.rotation.y=PI/2;window.layers=2;body.add_child(window)
 _box(body,Vector3(0,1.445,-.53),Vector3(1.5,.07,.12),roof)
 _box(body,Vector3(0,1.48,.5),Vector3(1.6,.03,2.2),roof)
 _box(body,Vector3(0,.28,.2),Vector3(1.6,.04,2.8),carpet)
 # Seats.
 for x in [-.38,.38]:
  _box(body,Vector3(x,.47,.12),Vector3(.5,.14,.52),cloth)
  # Kept out of the mirror lens, so the back seat reads in the small glass.
  _box(body,Vector3(x,.85,.44),Vector3(.5,.70,.14),cloth,Vector3(.2,0,0)).layers=4
  _box(body,Vector3(x*1.08,1.27,.52),Vector3(.22,.16,.09),cloth).layers=4
 _box(body,Vector3(0,.46,1.05),Vector3(1.42,.16,.55),cloth)
 _box(body,Vector3(0,.86,1.38),Vector3(1.44,.72,.15),cloth,Vector3(.22,0,0))
 for x in [-.42,.42]:_box(body,Vector3(x,1.30,1.50),Vector3(.3,.16,.1),cloth)
 _box(body,Vector3(0,1.32,1.62),Vector3(1.5,.08,.4),dark)
 var rear:=MeshInstance3D.new();var rq:=QuadMesh.new();rq.size=Vector2(1.3,.36);rear.mesh=rq;rear.material_override=side_glass;rear.position=Vector3(0,1.25,1.75);rear.rotation.x=-.5;rear.layers=2;body.add_child(rear)
 # The bonnet beyond the glass and the headlights.
 _box(body,Vector3(0,.89,-1.62),Vector3(1.64,.06,1.2),paint,Vector3(.09,0,0))
 _box(body,Vector3(0,.915,-1.58),Vector3(.55,.04,1.1),paint,Vector3(.09,0,0))
 for x in [-.62,.62]:
  var beam:=SpotLight3D.new();beam.position=Vector3(x,.70,-2.3);beam.rotation.x=-.085;beam.light_color=Color("fff1d6");beam.light_energy=20;beam.spot_range=58;beam.spot_angle=30;beam.spot_attenuation=.8
  beam.shadow_enabled=true;beam.light_volumetric_fog_energy=.7;body.add_child(beam)
 dash_light=OmniLight3D.new();dash_light.position=Vector3(-.3,.98,-.6);dash_light.light_color=Color("d9b48c");dash_light.light_energy=.18;dash_light.omni_range=1.1;body.add_child(dash_light)
 rear_light=OmniLight3D.new();rear_light.position=Vector3(0,1.30,.62);rear_light.light_color=Color("8798bd");rear_light.light_energy=.05;rear_light.omni_range=1.9;rear_light.shadow_enabled=false;body.add_child(rear_light)

func _dial_texture() -> ImageTexture:
 var image:=Image.create(128,128,false,Image.FORMAT_RGBA8);image.fill(Color(0,0,0,0))
 for y in range(128):
  for x in range(128):
   var d:=Vector2(x-63.5,y-63.5);var r:=d.length()
   if r<62:image.set_pixel(x,y,Color(.02,.025,.02))
   if r>54 and r<58:image.set_pixel(x,y,Color(.85,.55,.25))
   var a:=atan2(d.y,d.x);var tk:=fmod(a+TAU,TAU/24.)
   if r>44 and r<56 and (tk<.03 or tk>TAU/24.-.03) and d.y<30:image.set_pixel(x,y,Color(.95,.75,.45))
 return ImageTexture.create_from_image(image)

func _mirror() -> void:
 var holder:=Node3D.new();holder.name="RearViewMirror";holder.position=MIRROR;body.add_child(holder)
 var to_eye:=(EYE-MIRROR).normalized();var to_rear:=(Vector3(-.03,1.13,1.25)-MIRROR).normalized()
 var normal:=(to_eye+to_rear).normalized()
 holder.basis=Basis.looking_at(-normal,Vector3.UP)
 var dark:=StandardMaterial3D.new();dark.albedo_color=Color("0c0c0d");dark.roughness=.45
 _box(holder,Vector3(0,0,-.012),Vector3(.275,.082,.03),dark)
 var stem:=_box(body,MIRROR+Vector3(0,.06,-.02),Vector3(.022,.11,.022),dark)
 stem.layers=2
 for child in holder.get_children():(child as VisualInstance3D).layers=2
 mirror_view=SubViewport.new();mirror_view.name="MirrorView";mirror_view.size=Vector2i(560,146);mirror_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;mirror_view.msaa_3d=Viewport.MSAA_2X;add_child(mirror_view)
 mirror_camera=Camera3D.new();mirror_camera.name="MirrorLens";mirror_camera.fov=14;mirror_camera.near=.05;mirror_camera.far=60;mirror_camera.cull_mask=1;mirror_camera.environment=env;mirror_view.add_child(mirror_camera)
 var face:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.255,.066);face.mesh=quad;face.layers=2
 var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_texture=mirror_view.get_texture();m.uv1_scale=Vector3(-1,1,1);m.uv1_offset=Vector3(1,0,0);m.albedo_color=Color(1.15,1.17,1.2)
 face.material_override=m;face.position=Vector3(0,0,.004);holder.add_child(face)
 mirror_holder=holder;rear_dir=to_rear

func _children() -> void:
 girl=(load(ROOT+"backseat-girl.glb") as PackedScene).instantiate();girl.name="BackseatGirl";body.add_child(girl)
 boy=(load(ROOT+"backseat-boy.glb") as PackedScene).instantiate();boy.name="BackseatBoy";body.add_child(boy)
 for kid in [girl,boy]:CharacterFinish.dynamic_only(kid)
 girl.position=Vector3(.31,.54,1.08);girl.rotation.y=PI;girl_seat=girl.transform
 boy.position=Vector3(-.33,.54,1.10);boy.rotation.y=PI-.06
 girl_head=girl.find_child("HeadRig",true,false);boy_head=boy.find_child("HeadRig",true,false)
 for key in ["ArmL","ArmR"]:
  var arm:=girl.find_child(key,true,false) as Node3D
  if arm:girl_arms.append(arm)
 girl_head.rotation=Vector3(.55,0,.12);boy_head.rotation=Vector3(-.12,.08,.32)
 girl.hide();boy.hide()

# ---------------------------------------------------------------- running
func start() -> void:
 prior_camera=get_viewport().get_camera_3d()
 if is_instance_valid(g.world):g.world.hide()
 show();camera.make_current();running=true;clock=0.;shade.show();shade.color.a=1
 engine.play();rain.play()

func _place(t: float) -> void:
 var s:=START_S+SPEED*t
 car.transform=frame_at(s)
 # Suspension: continuous rough tarmac plus a damped slam after each pothole.
 var heave:=.010*sin(s*2.3)+.006*sin(s*5.1+1.)+.004*sin(s*11.7)
 var pitch:=.004*sin(s*1.7)
 var roll:=.006*sin(s*1.3+.4)+.003*sin(s*4.4)
 for p: float in POTHOLES:
  if s>p:
   var since:=(s-p)/SPEED
   heave+=-.055*exp(-since*6.)*sin(since*24.)
   pitch+=.03*exp(-since*7.)*sin(since*22.+.6)
   roll+=(.02 if int(p)%2 else -.02)*exp(-since*7.)*sin(since*19.)
 body.position=Vector3(0,heave,0);body.rotation=Vector3(pitch,0,roll)
 mirror_camera.global_transform=Transform3D(Basis.looking_at(body.global_basis*rear_dir,body.global_basis.y),mirror_holder.global_position)
 var bend:=(frame_at(s+5.).basis.get_euler().y-frame_at(s).basis.get_euler().y)
 wheel.rotation.y=clampf(-bend*9.,-1.2,1.2)

func tick(delta: float) -> void:
 if not running or done:return
 clock+=delta;var t:=clock
 if is_instance_valid(g.world) and g.world.visible:g.world.hide()
 # A venue rebuilt in the background must not steal the view.
 if not camera.current:camera.make_current()
 var live:=t<CUT_AT
 if live:_place(t)
 shade.color.a=1. if not live else 1.-smoothstep(0.,FADE_IN,t)
 engine.volume_db=linear_to_db(maxf(.0001,smoothstep(0.,1.6,t)*db_to_linear(-9.)));rain.volume_db=linear_to_db(maxf(.0001,smoothstep(0.,1.6,t)*db_to_linear(-15.)))
 glass.set_shader_parameter("clock",t)
 for i in range(wipers.size()):wipers[i].rotation.z=(1.75 if i==0 else 1.6)*(.5-.5*cos(TAU*t/1.35))
 for needle in body.find_children("*","Node3D",false,false):
  if needle.has_meta("dial"):needle.rotation.z=(-.2 if float(needle.get_meta("dial"))< -.3 else .6)-.06*sin(t*3.)-.05*sin(t*7.1)
 var s:=START_S+SPEED*t
 while bumps_played<POTHOLES.size() and s>=POTHOLES[bumps_played]:
  if live:
   bump.stream=load(ROOT+"pothole-%d.ogg"%(bumps_played%3+1));bump.play()
  bumps_played+=1
 _look(t)
 _flashes(t)
 _shout(t)
 _backseat(t)
 if t>=CUT_AT and not cues.has("cut"):
  cues.cut=true
  for player in [engine,rain,bump,voice,drone,shriek,thunder]:player.stop()
  shout.hide();girl.hide();boy.hide()
 if t>=LENGTH:finish()

func _cue(id: String,at: float) -> bool:
 if clock>=at and not cues.has(id):cues[id]=true;return true
 return false

func _look(t: float) -> void:
 # Idle driving: eyes on the road, small sway with the bends and bumps.
 var forward:=Basis.from_euler(Vector3(-.12+.008*sin(t*.9),.01*sin(t*.37),0))
 var to_mirror:=Basis.looking_at((MIRROR+Vector3(0,-.004,0))-EYE,Vector3.UP)
 var k:=smoothstep(LOOK_AT,LOOK_AT+LOOK_TIME,t)
 var aim:=Basis(forward.get_rotation_quaternion().slerp(to_mirror.get_rotation_quaternion(),k*k*(3.-2.*k)))
 var shake:=Vector3.ZERO
 if t>SHOUT_AT and t<SHOUT_AT+2.:shake+=Vector3(randf_range(-1,1),randf_range(-1,1),0)*.004*(1.-(t-SHOUT_AT)/2.)
 if t>LUNGE_AT:
  # The head jerks back from the face in front of it.
  var j:=clampf((t-LUNGE_AT)/.12,0,1)
  aim=aim*Basis.from_euler(Vector3(.16*j,-.08*j,.05*j))
  shake+=Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*.03
 head.basis=aim*Basis.from_euler(shake)
 # The eyes fix on the little mirror: the view narrows onto it.
 camera.fov=lerpf(72.,24.,k*k*(3.-2.*k)) if t<LUNGE_AT else lerpf(24.,64.,clampf((t-LUNGE_AT)/.1,0,1))
 head.position=EYE+Vector3(0,0,.05*clampf((t-LUNGE_AT)/.12,0,1))

func _flashes(t: float) -> void:
 var e:=0.
 # Distant sheet lightning early on, then the strike that shows the back seat.
 for pair in [[2.6,.5],[REVEAL_AT,2.6],[LUNGE_AT+.02,2.2]]:
  var at: float=pair[0];var power: float=pair[1]
  var d:=t-at
  if d>=0 and d<.5:
   var flick:=1. if not strobe else (1. if fmod(d,.09)<.05 else .25)
   e=maxf(e,power*exp(-d*7.)*flick)
 lightning.light_energy=e
 env.ambient_light_energy=.06+e*.7
 glass.set_shader_parameter("flash",e)
 if _cue("thunder_far",3.2):thunder.stream=load("res://assets/weather-v352/distant-thunder-1.ogg");thunder.volume_db=-12;thunder.play()
 if _cue("thunder_near",REVEAL_AT+.25):thunder.stream=load("res://assets/weather-v352/distant-thunder-3.ogg");thunder.volume_db=-2;thunder.play()
 if _cue("drone",LOOK_AT-.3):drone.play()

func _shout(t: float) -> void:
 shout.set_meta("now",t)
 if _cue("shout",SHOUT_AT):
  shout.layout(AfterPlayLanguage.t(LINE));shout.show();voice.play()
 if t<SHOUT_AT or shout.text.is_empty():return
 shout.type_all_until(int((t-SHOUT_AT)/.017)+1,t)
 # Screamed: violent trembling while the voice is loudest, never quite still.
 shout.shake=lerpf(9.,3.,smoothstep(SHOUT_AT+.5,SHOUT_AT+2.4,t))
 shout.tick(t)
 if t>=SHOUT_FALL:
  var target:=mini(shout.glyphs.size(),int((t-SHOUT_FALL)/.03))
  while shout.dropped<target:
   _release(shout.glyph_screen(shout.dropped),shout.glyphs[shout.dropped].char);shout.dropped+=1
  if shout.dropped>=shout.glyphs.size():shout.hide()
 for i in range(falling.size()-1,-1,-1):
  var r: Dictionary=falling[i];r.time+=get_process_delta_time()
  var node: Label3D=r.node
  node.position=r.start+Vector3(r.drift.x*r.time,-4.2*r.time*r.time,r.drift.z*r.time)
  node.rotation.z+=r.spin*get_process_delta_time()
  if r.time>1.2:node.queue_free();falling.remove_at(i)

func _release(screen: Vector2,letter: String) -> void:
 if letter.strip_edges().is_empty():return
 var start:=body.to_local(camera.project_position(screen,.5))
 var node:=Label3D.new();node.text=letter;node.font=ThemeDB.fallback_font;node.font_size=96;node.outline_size=10;node.outline_modulate=Color(0,0,0,.9)
 node.pixel_size=clampf(camera.project_position(screen+Vector2(0,84),.5).distance_to(camera.project_position(screen,.5))/96.,.0002,.004)
 node.modulate=ShoutText.RED;node.shaded=false;node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.no_depth_test=false;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.position=start;body.add_child(node)
 falling.append({"node":node,"start":start,"time":0.,"spin":rng.randf_range(-4,4),"drift":Vector3(rng.randf_range(-.2,.2),0,rng.randf_range(-.05,.25))})

func _backseat(t: float) -> void:
 # Empty in the mirror while the driver looks up; there when the sky lights up.
 if _cue("reveal",REVEAL_AT):girl.show();boy.show()
 if t<REVEAL_AT:return
 boy_head.rotation=Vector3(-.12+.02*sin(t*1.3),.08,.32)
 var snap:=smoothstep(STARE_AT,STARE_AT+.07,t)
 girl_head.rotation=Vector3(lerpf(.55,-.08,snap),0,lerpf(.12,-.06,snap))
 rear_light.light_energy=.9+.12*sin(t*4.)
 if t<LUNGE_AT:return
 if _cue("lunge",LUNGE_AT):
  shriek.play();lunge_from=girl.global_transform
 # A split second: from the back seat straight into the driver's face.
 var k:=clampf((t-LUNGE_AT)/LUNGE_TIME,0,1);var reach:=1.-pow(1.-k,4.)
 var eye:=camera.global_transform
 var target_head:=eye.origin-eye.basis.z*.22-eye.basis.y*.02
 var facing:=Basis.looking_at(-((eye.origin-target_head).normalized()),Vector3.UP)
 var head_local:=girl_head.position+Vector3(0,0,.085)
 var to:=Transform3D(facing,target_head-facing*head_local)
 var from:=lunge_from
 girl.global_transform=Transform3D(from.basis.slerp(to.basis,reach),from.origin.lerp(to.origin,reach))
 girl_head.rotation=Vector3(-.12+randf_range(-.09,.09),randf_range(-.12,.12),randf_range(-.14,.14))
 for i in range(girl_arms.size()):
  girl_arms[i].rotation=Vector3(-1.15*reach+randf_range(-.08,.08),(.35 if i==0 else -.35)*reach,(-.12 if i==0 else .12)*reach)
 face_light.light_energy=.5*reach*(1. if not strobe or fmod(t,.06)<.04 else .35)

func finish() -> void:
 if done:return
 done=true;running=false
 for player in [engine,rain,bump,voice,drone,shriek,thunder]:
  if is_instance_valid(player):player.stop()
 finished.emit()

func dispose() -> void:
 for r in falling:
  if is_instance_valid(r.node):r.node.queue_free()
 falling.clear()
 if is_instance_valid(shade):shade.queue_free()
 if is_instance_valid(shout):shout.queue_free()
 if is_instance_valid(prior_camera) and prior_camera.is_inside_tree():prior_camera.make_current()
 queue_free()

func snapshot() -> Dictionary:
 return {"clock":clock,"running":running,"done":done,"line":shout.text if shout else "","typed":shout.typed if shout else 0,"dropped":shout.dropped if shout else 0,
  "kids_visible":is_instance_valid(girl) and girl.visible,"looking_up":smoothstep(LOOK_AT,LOOK_AT+LOOK_TIME,clock),"lunged":cues.has("lunge"),"cut":cues.has("cut"),
  "shriek":is_instance_valid(shriek) and shriek.playing,"engine":is_instance_valid(engine) and engine.playing}
