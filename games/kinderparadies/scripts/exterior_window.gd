class_name HappylandExterior
extends Node3D

const ROOT:="res://assets/atmosphere-v320/"
var w: PlayWorld
var glazing: ShaderMaterial
var rain_material: ShaderMaterial
var rain: MultiMeshInstance3D
var sign_material: StandardMaterial3D
var window_light: SpotLight3D
var lamps: Array[Light3D]=[]
var probe: ReflectionProbe
var clock:=0.
var count:=0

func part(p: Vector3,size_value: Vector3,material: Material) -> MeshInstance3D:
 count+=1;return w.box(self,p,size_value,material)

func build(world: PlayWorld) -> void:
 w=world;name="RainyParkingWindow";position=Vector3(-10.2,0,1.7);rotation.y=PI/2
 # +Z is the inside face. The parking lot sits behind the wall, in real 3D.
 var metal:=w.graphics.patina(Color("53605a"),.72)
 var rubber:=w.mat(Color("17201d"),null,.94)
 var sill:=w.mat(Color("7c8175"),load("res://assets/paint.png"),.66,.2)
 for x in [-1.8,-.6,.6,1.8]:
  part(Vector3(x,2.60,.02),Vector3(.10,2.62,.25),metal)
  for y in [1.49,3.71]:
   w.tube(self,Vector3(x,y,.149),Vector3(x,y,.157),.014,w.materials.metal)
 for y in [1.35,3.85]:part(Vector3(0,y,.02),Vector3(3.72,.11,.25),metal)
 part(Vector3(0,1.285,.10),Vector3(3.96,.08,.53),sill)
 glazing=ShaderMaterial.new();glazing.shader=load(ROOT+"glazing.gdshader")
 for x in [-1.2,0.,1.2]:
  for side in [-1,1]:part(Vector3(x+side*.547,2.60,.11),Vector3(.018,2.36,.018),rubber)
  for y in [1.42,3.78]:part(Vector3(x,y,.11),Vector3(1.11,.018,.018),rubber)
  var glass:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.09,2.35);glass.mesh=quad
  glass.name="StreakedGlass";glass.position=Vector3(x,2.60,.075);glass.material_override=glazing
  glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(glass)
  part(Vector3(x+.48,2.20,.17),Vector3(.03,.16,.036),metal)
  w.tube(self,Vector3(x+.48,2.23,.20),Vector3(x+.40,2.23,.20),.012,w.materials.metal)
 var barrier:=StaticBody3D.new();barrier.name="ClosedWindowBarrier";barrier.set_meta("acoustic_barrier",true);add_child(barrier)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.6,2.5,.09);shape.shape=box;shape.position=Vector3(0,2.6,.02);barrier.add_child(shape)
 _parking(metal);_weather()
 window_light=SpotLight3D.new();window_light.name="ParkingLightThroughGlass";window_light.position=Vector3(-.2,3.2,-1.1)
 window_light.light_color=Color("a1bccd");window_light.light_energy=2.1;window_light.spot_range=14;window_light.spot_angle=57;window_light.spot_angle_attenuation=1.0
 window_light.light_size=.24;window_light.shadow_enabled=true;window_light.shadow_bias=.025;window_light.light_volumetric_fog_energy=.75;add_child(window_light)
 window_light.look_at(to_global(Vector3(1.2,.25,7.5)))
 if not OS.has_feature("web") and DisplayServer.get_name()!="headless":
  probe=ReflectionProbe.new();probe.position=Vector3(-2,2,-3);probe.size=Vector3(8,7,30);probe.origin_offset=Vector3(0,0,-2)
  probe.box_projection=true;probe.intensity=.42;probe.interior=false;probe.max_distance=38;probe.enable_shadows=true;add_child(probe)

func _parking(metal: Material) -> void:
 var asphalt:=w.graphics.floor_material("concrete_floor_worn_001",Color("59625f"),.45,.80)
 part(Vector3(-2.1,-.10,-15.5),Vector3(8.2,.18,29),asphalt)
 var paint:=w.mat(Color("aaa990"),load("res://assets/paint.png"),.96)
 var concrete:=w.mat(Color("676e68"),load("res://assets/aged-plaster.png"),.93)
 # Two rows of empty parking bays, worn line fragments and cast kerb stones.
 for row in [-9.,-22.]:
  for i in range(4):
   var x:=1.55-i*2.55
   part(Vector3(x,.003,row),Vector3(.075,.004,5.1),paint)
   for chip in range(3):part(Vector3(x,.006,row-1.6+chip*1.3),Vector3(.078,.002,.08+chip*.025),asphalt)
   if i<3:
    part(Vector3(x-1.275,.003,row-2.55),Vector3(2.55,.004,.075),paint)
    w.venue.text(self,"%02d"%(i+1+(0 if row> -10 else 3)),Vector3(x-1.275,.009,row+1.5),.32,Color("92947d")).rotation.x=-PI/2
 for i in range(13):part(Vector3(-5.9+i*.6,.08,-1.12),Vector3(.57,.16,.29),concrete)
 # Building wing conceals the maintenance room rather than overlapping it.
 part(Vector3(2.12,1.8,-15.0),Vector3(.20,3.6,30),w.materials.wall)
 # The old entrance joins the same parking lot beyond its west facade.
 part(Vector3(-6.28,1.8,-3.20),Vector3(.16,3.6,4.4),w.materials.wall)
 part(Vector3(-9.0,-.10,-18.0),Vector3(5.6,.18,24.),asphalt)
 for z in [-9.,-14.,-19.,-24.,-29.]:
  w.tube(self,Vector3(-11.7,0,z),Vector3(-11.7,1.8,z),.027,metal)
 for y in [.25,1.6]:w.tube(self,Vector3(-11.7,y,-6.),Vector3(-11.7,y,-29.9),.020,metal)
 for z in [-11.,-19.,-27.]:part(Vector3(-7.6,.003,z),Vector3(2.9,.004,.075),paint)
 for z in [-4.,-12.,-20.,-28.]:
  part(Vector3(1.99,1.2,z),Vector3(.025,.08,1.1),metal)
 for i in range(18):
  var x:=-6.1+i*.46
  w.tube(self,Vector3(x,0,-29.9),Vector3(x,2.3,-29.9),.018,metal)
 for y in [.2,2.2]:w.tube(self,Vector3(-6.2,y,-29.9),Vector3(1.95,y,-29.9),.022,metal)
 for x in [-5.7,-1.6]:
  part(Vector3(x,.08,-3.3),Vector3(.25,.16,.5),concrete)
  w.tube(self,Vector3(x,.16,-3.3),Vector3(x,.85,-3.3),.047,metal)
 # The sign is physical extruded lettering, captured by reflection probes.
 sign_material=w.mat(Color("8f9c6d"),null,.49,.15);sign_material.emission_enabled=true
 sign_material.emission=Color("8fa57a");sign_material.emission_energy_multiplier=1.35
 part(Vector3(-1.2,3.6,-16),Vector3(6.6,1.35,.22),metal)
 for x in [-4.0,1.6]:w.tube(self,Vector3(x,0,-16),Vector3(x,4.35,-16),.065,metal)
 var letters:=w.venue.text(self,"HAPPYLAND",Vector3(-1.2,3.32,-15.87),.72,Color.WHITE)
 (letters.mesh as TextMesh).depth=.035;letters.material_override=sign_material
 w.venue.text(self,"KINDERPARADIES",Vector3(-1.2,3.01,-15.85),.15,Color("7c8873"))
 for point in [Vector3(-5.7,0,-13),Vector3(-3.8,0,-25),Vector3(-10.8,0,-12)]:
  w.tube(self,point,point+Vector3(0,5.5,0),.055,metal)
  part(point+Vector3(0,5.43,0),Vector3(.45,.16,.7),metal)
  var diffuser:=w.mat(Color("c4c0a5"),null,.5);diffuser.emission_enabled=true;diffuser.emission=Color("d8d8b5");diffuser.emission_energy_multiplier=1.3
  part(point+Vector3(0,5.33,0),Vector3(.35,.025,.55),diffuser)
  var light:=SpotLight3D.new();light.position=point+Vector3(0,5.30,0);light.rotation.x=-PI/2;light.spot_angle=68;light.spot_range=12
  light.light_color=Color("b9c8c6");light.light_energy=3.6;light.shadow_enabled=true;light.light_size=.20;add_child(light);lamps.append(light)
 # A shallow gutter is a connected manufactured detail, not loose floor clutter.
 part(Vector3(-2.1,.001,-1.6),Vector3(7.8,.024,.22),w.materials.dark)
 for i in range(40):part(Vector3(-5.8+i*.19,.017,-1.6),Vector3(.028,.018,.20),metal)

func _weather() -> void:
 rain_material=ShaderMaterial.new();rain_material.shader=load(ROOT+"rain.gdshader")
 rain=MultiMeshInstance3D.new();rain.name="ExteriorRain";rain.material_override=rain_material;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 rain.set_meta("nonblocking_atmosphere",true)
 var mesh:=QuadMesh.new();mesh.size=Vector2(.014,.19)
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=720 if not OS.has_feature("web") else 240
 mm.custom_aabb=AABB(Vector3(-11.7,0,-29),Vector3(13.7,9,28))
 var rng:=RandomNumberGenerator.new();rng.seed=320
 for i in range(mm.instance_count):
  var point:=Vector3(rng.randf_range(-11.6,1.8),.05,rng.randf_range(-28.5,-1.3))
  # The entrance and its awning occupy this corner of the extended lot.
  if point.x< -6.15 and point.z> -7.0:point.z=rng.randf_range(-28.5,-7.0)
  mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
  mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 rain.multimesh=mm;add_child(rain)

func tick(delta: float,active: bool) -> void:
 if not active:return
 clock+=delta;glazing.set_shader_parameter("clock",clock);rain_material.set_shader_parameter("clock",clock)
 sign_material.emission_energy_multiplier=1.24+.07*sin(clock*1.7)+.035*sin(clock*9.1)

func quality(value: int) -> void:
 window_light.shadow_enabled=value>0
 for light in lamps:light.shadow_enabled=value>0 and not OS.has_feature("web")
 rain.multimesh.visible_instance_count=rain.multimesh.instance_count if value>0 else mini(140,rain.multimesh.instance_count)
 if probe:probe.visible=value>0
