class_name NativeArt
extends Node3D

var w: PlayWorld
var advanced := false
var model_count := 0
var sources := {}
var spots: Array[SpotLight3D]=[]
var fog_volumes: Array[FogVolume]=[]
var probes: Array[ReflectionProbe]=[]
var elapsed := 0.0
var strip_material: StandardMaterial3D
var fill_lights: Array[OmniLight3D]=[]
var power_box: Node3D

func build(world: PlayWorld) -> void:
 w=world
 advanced=RenderingServer.get_current_rendering_method()=="forward_plus" and DisplayServer.get_name()!="headless"
 _materials();_models();_counter();_play_details();_acoustics()
 if advanced: _lighting()

func surface(material: StandardMaterial3D, id: String, tint: Color, scale_value: float=1.0) -> void:
 var path:="res://assets/pbr/"+id+"/"
 material.albedo_texture=load(path+"albedo.jpg");material.albedo_color=tint
 material.normal_enabled=true;material.normal_texture=load(path+"normal.jpg");material.normal_scale=.6
 material.roughness_texture=load(path+"roughness.jpg");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.roughness=1;material.metallic=0
 material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*scale_value

func _materials() -> void:
 surface(w.materials.wall,"painted_plaster_wall",Color("c8cfc1"),.48)
 w.materials.wall.normal_scale=.22
 for id in ["blue","red","gold","teal","cream"]:
  var material: StandardMaterial3D=w.materials[id]
  var tint: Color=material.albedo_color
  surface(material,"fabric_leather_01",tint.lightened(.22),2.5)
  material.albedo_texture=load("res://assets/vinyl.png");material.albedo_color=tint.lightened(.12)
  material.normal_scale=.18;material.roughness=.62
  material.clearcoat_enabled=true;material.clearcoat=.20;material.clearcoat_roughness=.42
 surface(w.materials.fabric,"fabric_pattern_07",Color("9d9582"),4)
 # A continuous worn floor replaces the repeated checkerboard only on PC.
 for tile in w.props.floor_tiles: tile.hide()
 var material:=w.mat(Color("909889"));surface(material,"concrete_floor_worn_001",Color("909889"),.45)
 material.roughness=.72
 var shader:=Shader.new();shader.code="""
shader_type spatial;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_map:filter_linear_mipmap_anisotropic,repeat_enable;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){vec2 uv=UV*vec2(10.0,10.0);float n=noise(UV*11.0)*0.7+noise(UV*29.0)*0.3;float wet=smoothstep(0.53,0.72,n);ALBEDO=texture(albedo_map,uv).rgb*vec3(0.7,0.73,0.69)*(1.0-wet*0.28);ROUGHNESS=mix(texture(rough_map,uv).r*0.9,0.12,wet);NORMAL_MAP=texture(normal_map,uv).rgb;NORMAL_MAP_DEPTH=0.6;SPECULAR=0.65;}
"""
 var floor_material:=ShaderMaterial.new();floor_material.shader=shader;floor_material.set_shader_parameter("albedo_map",material.albedo_texture);floor_material.set_shader_parameter("normal_map",material.normal_texture);floor_material.set_shader_parameter("rough_map",material.roughness_texture)
 var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(29.6,29.1);floor_mesh.mesh=plane;floor_mesh.material_override=floor_material;floor_mesh.position=Vector3(4.8,.014,2.4);add_child(floor_mesh)

func model(parent: Node3D, id: String, pos: Vector3, height: float, yaw: float=0) -> Node3D:
 var path:="res://assets/models/"+id+"/"+id+".gltf"
 if id.begins_with("hero/"): path="res://assets/"+id+".glb"
 if not sources.has(path): sources[path]=load(path)
 var scene: PackedScene=sources[path]
 assert(scene!=null,"Missing native model: "+path)
 var instance: Node3D=scene.instantiate();parent.add_child(instance)
 var bounds:=AABB();var first:=true
 for mesh in instance.find_children("*","MeshInstance3D",true,false):
  var local: Transform3D=instance.global_transform.affine_inverse()*mesh.global_transform
  var box: AABB=local*mesh.get_aabb()
  bounds=box if first else bounds.merge(box);first=false
  mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
  mesh.set_meta("native_model",id)
  for surface_index in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.get_active_material(surface_index)
   if material is StandardMaterial3D and material.resource_name.begins_with("Worn oatmeal"): material.uv1_scale=Vector3(3,3,1)
 var factor:=height/maxf(bounds.size.y,.01)
 instance.scale=Vector3.ONE*factor
 instance.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
 var pivot:=Node3D.new();parent.remove_child(instance);parent.add_child(pivot);pivot.add_child(instance);pivot.position=pos;pivot.rotation.y=yaw
 model_count+=1
 return pivot

func hide_geometry(node: Node) -> void:
 for child in node.get_children():
  if child is GeometryInstance3D: child.hide()

func _models() -> void:
 for chair in w.props.chairs.get_children():
  # Imported chair back points toward -Z; the common chair uses +Z.
  hide_geometry(chair);model(chair,"SchoolChair_01",Vector3.ZERO,.91,PI)
 hide_geometry(w.props.reception_shelves)
 for i in range(5): model(self,"cardboard_box_01",Vector3(-16.5+(i%2)*.55,.02+floori(i/2.0)*.35,-14.1),.34,-.3+i*.4)
 for i in range(4): model(self,"cardboard_box_01",Vector3(-8.25+(i%2)*.5,.02+floori(i/2.0)*.42,-3.4),.41,i*.45)
 power_box=model(self,"power_box_01",Vector3(-16.11,1.1,-3.85),.7,PI/2)
 power_box.name="WallMountedPowerBox"
 model(self,"metal_office_desk",Vector3(-7.9,.02,-21.5),.85)
 model(w.props.counter,"rubber_duck_toy",Vector3(.12,1.0,.45),.13,.5)
 model(w.props.party_table,"rubber_duck_toy",Vector3(8.8,.87,-7.3),.12,-.8)
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  var p: Vector3=mesh.global_position
  if absf(p.x-10.2)<.36 and absf(p.z+7)<.34 and p.y>.9 and p.y<1.28: mesh.hide()
 model(w.props.party_table,"hero/birthday-cake",Vector3(8.5,.87,-7),.43)
 # Keep the anomaly parents/transforms so imported details obey every old rule.
 hide_geometry(w.atmosphere.horrors.bunny)
 w.atmosphere.horrors.bunny.rotation.y=-PI/2
 model(w.atmosphere.horrors.bunny,"hero/stitched-rabbit",Vector3.ZERO,1.1)
 var bench: Node3D=w.atmosphere.horrors.bench;hide_geometry(bench)
 bench.rotation.y=PI/2
 model(bench,"hero/waiting-bench",Vector3.ZERO,1.28,PI)
 w.box(bench,Vector3(0,.55,0),Vector3(2.8,.16,.72),w.materials.dark,true).hide()
 for body in w.atmosphere.loose:
  if body.title=="Stoffhase":
   hide_geometry(body);model(body,"hero/stitched-rabbit",Vector3(0,-.3,0),.63)
  for mesh in body.find_children("*","MeshInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
 w.balls.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("basic_lamp_shade"): mesh.hide()
 # Swap the hand-built desk lamp's local geometry, leaving its practical light.
 for mesh in w.props.counter.find_children("*","MeshInstance3D",true,false):
  if mesh.position.z>.85 and mesh.position.y>1: mesh.hide()
 model(w.props.counter,"desk_lamp_arm_01",Vector3(-.1,1,.99),.45,-.5)
 for z in [-8,0,7]: model(self,"hanging_industrial_lamp",Vector3(-5.5,6.02,z),.72)

 # This model is already placed by the common playground for Windows and Web.
 sources[ExpandedPlayground.CROCODILE_PATH]=load(ExpandedPlayground.CROCODILE_PATH)
 model_count+=1
 for pos in [Vector3(12.4,6.0,11.4),Vector3(10.2,6.0,-7)]: model(self,"hanging_industrial_lamp",pos,.72)

func _counter() -> void:
 # Compact 0.96 x 2.9 m reception desk; detailing shares its local frame.
 w.props.counter_base.material_override=w.materials.wood
 var counter: Node3D=w.props.counter
 for i in range(17):
  w.box(counter,Vector3(.43,.46,-1.28+i*.16),Vector3(.045,.82,.055),w.materials.wood)
 for y in [.07,.87]: w.box(counter,Vector3(.45,y,0),Vector3(.06,.03,2.7),w.materials.rust)

func _play_details() -> void:
 # Shared ropes, apertures and obstacles already have matching collisions.
 # Native rendering only refines materials; it never lays a second net over them.
 var rubber:=w.mat(Color("b2b6ab"));surface(rubber,"rubberized_track",Color("b2b6ab"),1.2)
 w.props.play_threshold.material_override=rubber

func finish() -> void:
 # Apply after the annex/workshop exist. Shared source materials keep their
 # identity, so anomaly tint changes and every physical collider still agree.
 var noise:=FastNoiseLite.new();noise.seed=250;noise.frequency=.075;noise.fractal_octaves=3
 var rough:=NoiseTexture2D.new();rough.width=512;rough.height=512;rough.noise=noise;rough.seamless=true
 var ramp:=Gradient.new();ramp.set_color(0,Color(.24,.24,.24));ramp.set_color(1,Color(.83,.83,.83));rough.color_ramp=ramp
 var normal:=NoiseTexture2D.new();normal.width=512;normal.height=512;normal.noise=noise;normal.seamless=true;normal.as_normal_map=true;normal.bump_strength=.5
 var patina:=NoiseTexture2D.new();patina.width=512;patina.height=512;patina.noise=noise;patina.seamless=true
 var rust:=Gradient.new();rust.set_color(0,Color("a0a29a"));rust.add_point(.53,Color("81715a"));rust.set_color(1,Color("493225"));patina.color_ramp=rust
 var done: Dictionary={}
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("native_model"): continue # Retain authored imported PBR maps.
  var material:=mesh.material_override as StandardMaterial3D
  if not material or material.metallic<.35 or done.has(material.get_instance_id()): continue
  done[material.get_instance_id()]=true
  material.normal_enabled=true;material.normal_texture=normal;material.normal_scale=.12
  material.roughness_texture=rough;material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED;material.roughness=.80
  material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*2.1
  if material==w.materials.rust: material.albedo_texture=patina;material.albedo_color=Color("b7a08c");material.metallic=.55
 # Upholstery uses the same physically scaled weave as the sewn curtains.
 var seat_fabric:=w.polish.pbr("fabric_pattern_07",Color("792e39"),3.2)
 seat_fabric.normal_scale=.38;seat_fabric.roughness=.90
 for seat in w.annex.get_children():
  if not str(seat.name).begins_with("CinemaSeat"): continue
  for mesh in seat.find_children("*","MeshInstance3D",true,false):
   var material:=mesh.material_override as StandardMaterial3D
   if material and material.metallic==0 and material.albedo_color.r>material.albedo_color.g*1.6: mesh.material_override=seat_fabric
 if not advanced: return
 # Screen bounce comes from the screen plane, not an unexplained room fill.
 for light in w.practicals:
  if light.position.distance_to(Vector3(2.8,2.2,-17.7))<.1:
   light.light_energy=.88;light.light_color=Color("a6c0cf");light.omni_range=7;light.omni_attenuation=1.8;light.set_meta("shadow_practical",true)
  elif light.position.distance_to(Vector3(-13.35,2.89,-4.4))<.1:
   light.light_energy=1.1;light.light_color=Color("a6c0b1");light.set_meta("shadow_practical",true)
 var projector:=w.annex.get_children().filter(func(n):return n is SpotLight3D)
 for light in projector:
  light.light_energy=.75;light.light_volumetric_fog_energy=2.2;light.light_size=.018
  light.spot_angle=19;light.spot_attenuation=1.4
 for mesh in w.server_room.get_children():
  if mesh is MeshInstance3D and mesh.position.distance_to(Vector3(-13.35,2.99,-4.4))<.1:
   (mesh.material_override as StandardMaterial3D).emission_energy_multiplier=2.8

func _lighting() -> void:
 var env:=w.environment.environment
 env.ambient_light_energy=.10;env.ambient_light_color=Color("647b88");env.tonemap_mode=Environment.TONE_MAPPER_AGX
 env.fog_density=.004;env.volumetric_fog_enabled=true;env.volumetric_fog_density=.058
 env.volumetric_fog_albedo=Color("99adae");env.volumetric_fog_length=45;env.volumetric_fog_anisotropy=.4
 env.volumetric_fog_ambient_inject=.12;env.volumetric_fog_gi_inject=.35
 env.volumetric_fog_temporal_reprojection_amount=.75
 env.sdfgi_cascades=4;env.sdfgi_min_cell_size=.2;env.sdfgi_use_occlusion=true;env.sdfgi_read_sky_light=false;env.sdfgi_energy=.85
 env.ssao_enabled=true;env.ssao_radius=.85;env.ssao_intensity=1.5;env.ssao_detail=.7
 env.ssil_radius=2.5;env.ssil_intensity=.7
 env.glow_enabled=true;env.glow_intensity=.22;env.glow_hdr_threshold=1.4
 for mesh in w.atmosphere.get_children():
  if mesh is MeshInstance3D and (mesh.material_override==w.atmosphere.mist or (mesh.mesh is SphereMesh and mesh.material_override is StandardMaterial3D and mesh.material_override.roughness<.1)): mesh.hide()
 # The old unsupported cyan strips inside the net have been removed entirely.
 # Cool fill now comes from a caged wall fixture outside the play structure.
 var strip_mat:=w.mat(Color("8ba8a7"));strip_mat.emission_enabled=true;strip_mat.emission=Color("8ba8a7");strip_mat.emission_energy_multiplier=.6
 strip_material=strip_mat
 w.box(self,Vector3(19.50,5.4,7.0),Vector3(.16,.28,1.2),w.materials.dark)
 for z in [6.55,7.45]: w.tube(self,Vector3(19.58,5.4,z),Vector3(19.69,5.4,z),.018,w.materials.metal)
 w.box(self,Vector3(19.40,5.4,7.0),Vector3(.045,.18,1.06),strip_mat)
 for z in [6.5,6.75,7.0,7.25,7.5]: w.tube(self,Vector3(19.36,5.25,z),Vector3(19.36,5.55,z),.012,w.materials.metal)
 var fill:=OmniLight3D.new();fill.position=Vector3(19.1,5.4,7.0);fill.light_color=Color("84a8ad");fill.light_energy=.85;fill.omni_range=10;fill.shadow_enabled=true;add_child(fill);fill_lights.append(fill)
 for z in [-8,0,7]:
  var spot:=SpotLight3D.new();spot.position=Vector3(-5.5,6.02,z);spot.rotation.x=-PI/2;spot.light_color=Color("ffe0ad");spot.light_energy=3.0;spot.spot_range=9;spot.spot_angle=65;spot.spot_angle_attenuation=.8;spot.shadow_enabled=true;spot.light_size=.12;spot.shadow_bias=.025;spot.shadow_normal_bias=.6;spot.light_volumetric_fog_energy=1.3;spot.light_indirect_energy=1.3;add_child(spot);spots.append(spot)
 for pos in [Vector3(12.4,6,11.4),Vector3(10.2,6,-7)]:
  var spot:=SpotLight3D.new();spot.position=pos;spot.rotation.x=-PI/2;spot.light_color=Color("bbcab6") if pos.z>0 else Color("e8c399");spot.light_energy=3;spot.spot_range=11;spot.spot_angle=66;spot.shadow_enabled=true;spot.light_size=.16;spot.shadow_bias=.025;spot.shadow_normal_bias=.6;add_child(spot);spots.append(spot)
 for pos in [Vector3(4.8,3,2.4),Vector3(13.3,3,-5.3)]:
  var probe:=ReflectionProbe.new();probe.position=pos;probe.size=Vector3(29.5,7.1,29) if pos.x<5 else Vector3(12.7,7.1,13.1);probe.box_projection=true;probe.interior=true;probe.intensity=.6;probe.max_distance=30;add_child(probe);probes.append(probe)
 # Low fog banks use participating-media density and react to light/shadow.
 for pos in [Vector3(-5,.2,-4),Vector3(2,.2,7.5),Vector3(12.4,.2,12.5),Vector3(14,.2,-6)]:
  var volume:=FogVolume.new();volume.position=pos;volume.size=Vector3(8,.8,5);volume.shape=RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
  var material:=FogMaterial.new();material.density=.045;material.albedo=Color("8c9b96");volume.material=material;add_child(volume);fog_volumes.append(volume)

func quality(value: int) -> void:
 if not advanced: return
 var env:=w.environment.environment
 env.sdfgi_enabled=value>0;env.ssil_enabled=value==2;env.ssr_enabled=value==2
 env.volumetric_fog_enabled=value>0;env.ssao_enabled=value>0;env.glow_enabled=value>0
 for spot in spots: spot.shadow_enabled=value>0
 for light in fill_lights: light.shadow_enabled=value>0
 for volume in fog_volumes: volume.visible=value>0

func anomaly(id: String) -> void:
 # Common Web fog is deliberately dense. Forward+ already has participating
 # fog; stacking the full Web fog over it flattened every material and shadow.
 if advanced: w.environment.environment.fog_density=.009
 if id=="heavy_mist" and advanced:
  w.environment.environment.volumetric_fog_albedo=Color("b22629")
 if id=="lights_red":
  if strip_material: strip_material.albedo_color=Color("e22c28");strip_material.emission=Color("e22c28")
  for spot in spots: spot.light_color=Color("e22c28")
  for light in fill_lights: light.light_color=Color("e22c28")

func tick(delta: float, active: bool) -> void:
 if active: elapsed+=delta

func _acoustics() -> void:
 if AudioServer.get_bus_index("Interior")<0:
  AudioServer.add_bus();var index:=AudioServer.bus_count-1;AudioServer.set_bus_name(index,"Interior");AudioServer.set_bus_send(index,"Master")
  var reverb:=AudioEffectReverb.new();reverb.room_size=.78;reverb.damping=.65;reverb.wet=.18;reverb.dry=.9
  AudioServer.add_bus_effect(index,reverb)
 for sound in w.find_children("*","AudioStreamPlayer3D",true,false): sound.bus="Interior"
