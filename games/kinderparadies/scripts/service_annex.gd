class_name ServiceAnnex
extends Node3D

var w: PlayWorld
var clown: Dictionary
var clown_origin:=Vector3(-14.4,0,-19.25)
var screen: ShaderMaterial
var food: ShaderMaterial
var clock:=0.0
var scare:=false
var settled:=false
var clown_shape: CollisionShape3D
var sources: Array[AudioStreamPlayer3D]=[]

func wall(pos: Vector3, size: Vector3) -> void:
 var mesh:=w.box(self,pos,size,w.materials.wall,true);mesh.set_meta("architecture_wall",true)

func doorway(x: float) -> void:
 wall(Vector3(x,1.8,-14.4),Vector3(.18,3.6,4.6))
 wall(Vector3(x,1.8,-20.55),Vector3(.18,3.6,3.9))
 wall(Vector3(x,3.07,-17.65),Vector3(.18,1.06,1.9))
 for z in [-18.64,-16.66]: w.box(self,Vector3(x,1.27,z),Vector3(.28,2.54,.09),w.materials.rust,true)
 w.box(self,Vector3(x,2.55,-17.65),Vector3(.28,.12,2.12),w.materials.rust,true)

func build(world: PlayWorld) -> void:
 w=world;name="ServiceAnnex"
 # North-wall opening continues into a small corridor with opposite doors.
 var floor_mat:=w.mat(Color("747b6b"),load("res://assets/floor.png"),.88);floor_mat.uv1_triplanar=true;floor_mat.uv1_scale=Vector3.ONE*.8
 # A four-millimetre step avoids coplanar overlap with the hall's tile lip.
 w.box(self,Vector3(-6.8,-.142,-17.3),Vector3(21.0,.3,10.5),floor_mat,true)
 for roof in RoomHorror.outside_shaft(Rect2(-17.3,-22.55,21,10.5)):
  w.box(self,Vector3(roof.get_center().x,3.65,roof.get_center().y),Vector3(roof.size.x,.18,roof.size.y),w.materials.dark,true)
 wall(Vector3(-17.35,1.8,-17.3),Vector3(.2,3.6,10.5));wall(Vector3(3.75,1.8,-17.3),Vector3(.2,3.6,10.5))
 wall(Vector3(-6.8,1.8,-22.55),Vector3(21,3.6,.2))
 wall(Vector3(-13.4,1.8,-13.3),Vector3(7.8,3.6,.18));wall(Vector3(-1.3,1.8,-13.3),Vector3(10.1,3.6,.18))
 # Only the extension outside the old hall needs a front return. Duplicating
 # the existing north wall would produce coplanar plaster on the hall side.
 wall(Vector3(-13.775,1.8,-12.2),Vector3(7.15,3.6,.2))
 doorway(-9.4);doorway(-6.4)
 for x in [-9.4,-6.4]:
  for z in [-12.2,-15.2,-19.7,-22.3]:
   w.box(self,Vector3(x,1.0,z),Vector3(.23,.08,.9),w.materials.teal)
 for z in [-13.7,-18.9,-21.4]:
  w.box(self,Vector3(-7.9,3.35,z),Vector3(.8,.09,.3),w.materials.metal)
  var light:=w.lamp(Vector3(-7.9,3.18,z),Color("91aaa1"),.5,5.5);light.shadow_enabled=true
 for x in [-9.35,-6.45]: w.tube(self,Vector3(x,3.25,-12.3),Vector3(x,3.25,-22.3),.06,w.materials.rust)
 plaque("KÜCHE",Vector3(-9.23,2.9,-17.65),PI/2)
 plaque("LICHTSPIEL",Vector3(-6.57,2.9,-17.65),-PI/2)
 _kitchen();KitchenDressing.build(w,self);_cinema();_audio()
 # Wall damp lives on physical plaster, away from door apertures and the screen.
 for z in [-21.0,-18.0,-14.9]:
  w.atmosphere.decal(self,2,Vector3(-17.235,2.15,z),Vector2(1.8,2.7),Vector3(0,PI/2,0),Color(.46,.53,.35,.8))
 for x in [-15.1,-11.8,-4.4,-.8]:
  w.atmosphere.decal(self,2,Vector3(x,1.85,-22.435),Vector2(2,3.15),Vector3.ZERO,Color(.42,.49,.38,.75))

func plaque(text: String, pos: Vector3, yaw: float) -> void:
 # Sign pixels and text are a single opaque texture, mounted above the frame.
 var filename:="kitchen" if text=="KÜCHE" else "cinema"
 w.artwork(self,pos,Vector2(1.4,.45),load("res://assets/annex/"+filename+"-sign.png"),yaw)

func _kitchen() -> void:
 var steel:=w.mat(Color("596661"),load("res://assets/paint.png"),.43,.7)
 var enamel:=w.mat(Color("b1b09a"),load("res://assets/aged-plaster.png"),.72)
 # A greasy tiled backsplash, cracked grout and a long preparation counter.
 for row in range(8):
  for col in range(20):
   var tile:=w.box(self,Vector3(-17.23,.45+row*.24,-21.85+col*.4),Vector3(.028,.23,.39),enamel if (row*7+col)%9 else w.materials.rust)
   tile.rotation.x=.012*sin(col*row)
 KitchenFurniture.build(w,self)
 SurfaceDetails.sink(w,self,steel)
 # Cooker island leaves a complete approach and escape route on every side.
 var hood:=w.box(self,Vector3(-13.25,2.8,-19.25),Vector3(1.45,.25,1.5),steel);w.box(self,Vector3(-13.25,3.24,-19.25),Vector3(.5,.64,.55),steel)
 var interior:=w.mat(Color("4a4a35"),load("res://assets/aged-plaster.png"),.93,.35);interior.uv1_triplanar=true;interior.uv1_scale=Vector3.ONE*5
 SurfaceDetails.vessel(self,Vector3(-13.25,.975,-19.25),.37,.34,.29,.018,steel,interior,"CookingPot")
 for side in [-1,1]: w.tube(self,Vector3(-13.25+side*.31,1.22,-19.25),Vector3(-13.25+side*.49,1.22,-19.25),.035,steel)
 var shader:=Shader.new();shader.code="""
shader_type spatial;
uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){float n=noise(UV*15.0)*.65+noise(UV*37.0)*.25+noise(UV*94.0)*.1;float mould=smoothstep(.43,.62,n);ALBEDO=mix(vec3(.12,.082,.027),vec3(.29,.34,.19),mould);ROUGHNESS=.92;}
""";food=ShaderMaterial.new();food.shader=shader
 var soup:=w.tube(self,Vector3(-13.25,1.20,-19.25),Vector3(-13.25,1.24,-19.25),.318,food)
 (soup.mesh as CylinderMesh).radial_segments=48
 for i in range(21):
  var a:=i*2.4;var r:=.05+(i%5)*.05;var mould:=w.sphere(self,Vector3(-13.25+cos(a)*r,1.251,-19.25+sin(a)*r),.025+(i%3)*.012,w.mat(Color("878b60") if i%2 else Color("3c4826"),null,.99));mould.scale.y=.12
 # Racks, dented trays, jars, stacked plates and abandoned ingredients.
 for y in [1.65,2.1]:
  w.box(self,Vector3(-16.8,y,-15),Vector3(.8,.06,2.4),steel)
  for z in [-15.9,-14.1]:
   w.tube(self,Vector3(-17.22,y-.32,z),Vector3(-16.45,y-.035,z),.017,steel)
  for i in range(6): w.tube(self,Vector3(-16.7,y+.04,-16+i*.35),Vector3(-16.7,y+.24,-16+i*.35),.08,w.materials.cream if i%2 else w.materials.teal)
 for i in range(9): w.tube(self,Vector3(-16.5,1.08+i*.018,-20.2),Vector3(-16.5,1.092+i*.018,-20.2),.2,enamel)
 if OS.has_feature("web"):
  for i in range(4): w.box(self,Vector3(-16.4+(i%2)*.55,.2+floori(i/2.0)*.4,-14.1),Vector3(.5,.38,.5),w.materials.wood,true)
 var key:=w.lamp(Vector3(-13.6,3.2,-18.7),Color("bab97b"),1.25,7);key.shadow_enabled=true;key.set_meta("kitchen_flicker",true);key.set_meta("base_energy",1.25)
 clown=HorrorFigures.clown(w,self);clown.root.position=clown_origin;clown.root.rotation.y=PI/2
 var collider:=StaticBody3D.new();collider.position=clown_origin+Vector3(0,.85,0);clown_shape=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;clown_shape.shape=capsule;collider.add_child(clown_shape);add_child(collider)

func _cinema() -> void:
 var carpet:=w.mat(Color("40262b"),load("res://assets/floor.png"),.98);carpet.uv1_triplanar=true;carpet.uv1_scale=Vector3.ONE
 var carpet_mesh:=w.box(self,Vector3(-1.3,.0095,-17.85),Vector3(9.95,.002,8.6),carpet);carpet_mesh.name="CinemaCarpet"
 var seat_mat:=w.mat(Color("642f35"),load("res://assets/aged-plaster.png"),.94)
 for x in [-4.7,-3.2,-1.7,-.2]:
  for z in [-21.0,-19.9,-18.8,-16.6,-15.5,-14.4]:
   var seat:=Node3D.new();seat.name="CinemaSeat";seat.position=Vector3(x,0,z);seat.rotation.y=PI/2;add_child(seat)
   w.box(seat,Vector3(0,.46,0),Vector3(.63,.18,.64),seat_mat,true)
   var back:=Node3D.new();back.position=Vector3(0,.87,-.27);back.rotation.x=-.12;seat.add_child(back);w.box(back,Vector3.ZERO,Vector3(.66,.82,.16),seat_mat,true)
   for side in [-1,1]:
    w.box(seat,Vector3(side*.37,.68,.02),Vector3(.09,.1,.62),w.materials.dark,true)
    w.tube(seat,Vector3(side*.28,.05,0),Vector3(side*.28,.45,0),.04,w.materials.metal)
   if int(absf(x*10+z))%4==0: w.box(seat,Vector3(.13,.56,.1),Vector3(.16,.009,.13),w.materials.rust)
 var frame:=Node3D.new();frame.position=Vector3(3.48,1.9,-17.7);frame.rotation.y=-PI/2;add_child(frame)
 w.box(frame,Vector3(0,0,-.035),Vector3(7,2.9,.08),w.materials.dark)
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(6.8,2.7);mesh.mesh=quad;mesh.position.z=.015;frame.add_child(mesh)
 var shader:=Shader.new();shader.code="""
shader_type spatial;render_mode unshaded;
uniform sampler2D lettering:source_color;uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){vec2 uv=UV;uv.x+=sin(uv.y*29.0+clock*3.0)*.0015;float n=hash(floor(uv*vec2(640.0,270.0))+floor(clock*12.0));float stripe=sin(uv.y*840.0)*.025;float roll=1.0-smoothstep(.0,.015,abs(uv.y-fract(clock*.12)));float text=texture(lettering,uv).r;vec3 c=vec3(.07+n*.14+stripe);c=mix(c,vec3(.45),text*(.88+.07*sin(clock*9.0)));c*=1.0-roll*.45;ALBEDO=c;}
""";screen=ShaderMaterial.new();screen.shader=shader;screen.set_shader_parameter("lettering",load("res://assets/annex/no-signal.png"));mesh.material_override=screen
 # Torn velvet side curtains have sewn folds and uneven hems.
 for side in [-1,1]:
  for i in range(9):
   var z: float=-17.7+side*(3.45+i*.07);var curtain:=w.sphere(self,Vector3(3.33,1.85,z),.12,seat_mat);curtain.name="LegacyCurtainFold";curtain.scale=Vector3(.7,13,1)
 for z in [-21.6,-13.9]:
  w.box(self,Vector3(3.35,.3,z),Vector3(.35,.6,.45),w.materials.dark,true)
 var projector:=w.box(self,Vector3(-5.4,2.98,-17.7),Vector3(.6,.32,.45),w.materials.metal)
 w.box(self,Vector3(-5.4,3.545,-17.7),Vector3(.3,.03,.3),w.materials.metal)
 w.tube(self,Vector3(-5.4,3.53,-17.7),Vector3(-5.4,3.14,-17.7),.025,w.materials.metal)
 w.tube(self,Vector3(-5.1,2.98,-17.7),Vector3(-5.0,2.98,-17.7),.08,w.materials.dark)
 var beam:=SpotLight3D.new();beam.position=Vector3(-4.95,2.95,-17.7);beam.rotation.y=-PI/2;beam.spot_range=10;beam.spot_angle=22;beam.light_energy=.35;beam.light_color=Color("82919e");beam.shadow_enabled=true;add_child(beam)
 var glow:=w.lamp(Vector3(2.8,2.2,-17.7),Color("91a5a3"),.5,7)
 for x in [-5.7,1.4]:
  for z in [-21.8,-13.7]: w.lamp(Vector3(x,.16,z),Color("9f3832"),.14,2.4)
 for i in range(18):
  var x:=-5.7+fmod(i*2.17,8.2);var z:=-21.7+fmod(i*3.14,7.6)
  if absf(z+17.65)<.8: continue
  var paper:=w.box(self,Vector3(x,.036,z),Vector3(.2,.008,.28),w.materials.paper);paper.rotation.y=i*.7

func _audio() -> void:
 for item in [{"file":"stir-pot.wav","pos":Vector3(-13.25,1.2,-19.25),"db":-22.0},{"file":"projector.wav","pos":Vector3(-5.4,2.9,-17.7),"db":-27.0}]:
  var source:=AudioStreamPlayer3D.new();source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;var stream: AudioStreamWAV=load("res://assets/annex/"+item.file);stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);source.stream=stream;source.position=item.pos;source.volume_db=item.db;source.max_distance=9;source.unit_size=2;add_child(source);sources.append(source)
  if w.native_art: source.bus="Interior"

func configure(id: String) -> void:
 scare=false;settled=false

func tick(delta: float, active: bool) -> void:
 for i in range(sources.size()):
  var source:=sources[i];var audible:=active and (i!=0 or not (scare or settled))
  if source.stream_paused==audible: source.stream_paused=not audible
  if audible and not source.playing: source.play()
 if clown_shape.disabled!=scare: clown_shape.set_deferred("disabled",scare)
 if not active: return
 clock+=delta;screen.set_shader_parameter("clock",clock)
 var flies:=get_node("PotFlies")
 for i in range(flies.get_child_count()): flies.get_child(i).position=Vector3(-13.25+sin(clock*(1+i*.06)+i*2)*.28,1.55+sin(clock*1.4+i)*.16,-19.25+cos(clock*1.3+i*2)*.25)
 if scare or settled: return
 var a:=clock*1.5;var hand:=Vector3(-.05+cos(a)*.12,1.42,1.08+sin(a)*.12);var tip:=Vector3(cos(a)*.12,1.22,1.15+sin(a)*.12)
 HorrorFigures.link(clown.upper,Vector3(-.28,1.48,0),Vector3(-.25,1.18,.42));HorrorFigures.link(clown.forearm,Vector3(-.25,1.18,.42),hand)
 clown.hand.position=hand;clown.hand.quaternion=Quaternion(Vector3.UP,(Vector3(-.25,1.18,.42)-hand).normalized());HorrorFigures.link(clown.spoon,hand,tip);clown.bowl.position=tip
 clown.head.rotation.z=sin(clock*.42)*.025

func safe_pose(pos: Vector3) -> bool:
 return pos.y>-.2 and pos.y<3.3 and pos.x> -17.15 and pos.x<3.55 and pos.z> -22.35 and pos.z< -12.05
