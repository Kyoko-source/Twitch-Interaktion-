class_name AfterPlayGraphics
extends Node3D

const ROOT:="res://assets/atmosphere-v320/"
var w: PlayWorld
var exterior: HappylandExterior
var surfaces:=0
var details:=0
var clock:=0.
var native:=false
var lights: Array[Dictionary]=[]
var probes: Array[ReflectionProbe]=[]
var obstacles: Array[AABB]=[]
var fan: Node3D
var gloss_noise: NoiseTexture2D

func part(parent: Node3D,p: Vector3,size_value: Vector3,material: Material) -> MeshInstance3D:
 details+=1;return w.box(parent,p,size_value,material)

func patina(color: Color,metalness: float=.65) -> ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=load(ROOT+"patinated.gdshader")
 material.set_shader_parameter("paint",color);material.set_shader_parameter("metal",metalness)
 material.set_shader_parameter("detail",load("res://assets/paint.png" if OS.has_feature("web") else "res://assets/pbr/rusty_painted_metal/albedo.jpg"));return material

func floor_material(id: String,tint: Color,scale_value: float,wet: float=0.,cloth: float=0.) -> ShaderMaterial:
 var path:="res://assets/pbr/"+id+"/"
 var available:=not OS.has_feature("web") or id in ["dirty_carpet","fabric_pattern_07","metal_grate_rusty"]
 var m:=ShaderMaterial.new();m.shader=load(ROOT+"floor.gdshader")
 m.set_shader_parameter("albedo_map",load(path+"albedo.jpg" if available else "res://assets/floor.png"))
 m.set_shader_parameter("normal_map",load(path+"normal.jpg") if available else w.atmosphere.micro_normal)
 m.set_shader_parameter("rough_map",load(path+"roughness.jpg") if available else gloss_noise)
 m.set_shader_parameter("tint",tint);m.set_shader_parameter("scale_m",scale_value);m.set_shader_parameter("dampness",wet);m.set_shader_parameter("fibre",cloth)
 return m

func build(world: PlayWorld) -> void:
 w=world;name="AfterPlaySurfaceAndLightUpgrade"
 native=not OS.has_feature("web") and RenderingServer.get_current_rendering_method()=="forward_plus" and DisplayServer.get_name()!="headless"
 var noise:=FastNoiseLite.new();noise.seed=320;noise.frequency=.08;noise.fractal_octaves=4
 gloss_noise=NoiseTexture2D.new();gloss_noise.width=256;gloss_noise.height=256;gloss_noise.seamless=true;gloss_noise.noise=noise
 var ramp:=Gradient.new();ramp.set_color(0,Color(.55,.55,.55));ramp.set_color(1,Color(.95,.95,.95));gloss_noise.color_ramp=ramp
 _materials();_floors();_shelves()
 exterior=HappylandExterior.new();add_child(exterior);exterior.build(w)
 _play_seams();_ceiling();_crt_screens();_party();_kitchen();_cinema();_service();_light_design()
 if native:_environment()

func _materials() -> void:
 # Material identity and tint stay intact for anomaly logic. Authored creature
 # faces, eyes, fur, skin and existing scanned maps retain their own materials.
 var seen: Dictionary={}
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree():continue
  for i in range(mesh.mesh.get_surface_count()):
   var m:=mesh.get_active_material(i) as StandardMaterial3D
   if not m or seen.has(m.get_instance_id()):continue
   seen[m.get_instance_id()]=true
   var label:=m.resource_name.to_lower()
   if "skin" in label or "eye" in label or "iris" in label or "enamel" in label or "tooth" in label or "teeth" in label or "gum" in label or "hair" in label or mesh.get_meta("mascot_mesh",false):continue
   if m.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED or m.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
   m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   if m.metallic>.35 and not m.roughness_texture:
    m.roughness_texture=gloss_noise;m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED;m.roughness=.75
    if not m.normal_texture:m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.10
   if not m.normal_texture and m.albedo_texture and m.roughness>.4:
    m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.11
   surfaces+=1
 for id in ["blue","red","gold","teal","cream"]:
  var m: StandardMaterial3D=w.materials[id]
  m.roughness=.63;m.clearcoat_enabled=true;m.clearcoat=.16;m.clearcoat_roughness=.36
  m.roughness_texture=gloss_noise;m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
  m.normal_enabled=true;m.normal_scale=.21
 w.materials.wood.roughness_texture=gloss_noise;w.materials.wood.roughness=.91
 w.materials.wood.normal_scale=.18
 # The common ball material keeps per-instance colours and physical movement.
 var balls:=w.balls.material_override as StandardMaterial3D
 balls.roughness=.37;balls.clearcoat_enabled=true;balls.clearcoat=.28;balls.clearcoat_roughness=.27

func _floors() -> void:
 if w.native_art:
  for mesh in w.native_art.get_children():
   if mesh is MeshInstance3D and mesh.mesh is PlaneMesh:
    mesh.material_override=floor_material("concrete_floor_worn_001",Color("b0b3a7"),.45,.65);mesh.name="LayeredHallFloor"
 else:
  # Web keeps the existing checker pattern, with improved material response.
  for mesh in w.props.floor_tiles:
   var material:=mesh.material_override as StandardMaterial3D
   if material:material.roughness=.68;material.roughness_texture=gloss_noise;material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.18
 var kitchen:=w.revamp.find_child("KitchenTileFloor",true,false) as MeshInstance3D
 kitchen.material_override=floor_material("dirty_tiles",Color("939d8e"),.68,.30)
 var cinema:=w.annex.get_node("CinemaCarpet") as MeshInstance3D
 cinema.material_override=floor_material("dirty_carpet",Color("773e48"),.65,0.,1.)
 for mesh in w.archive.get_children():
  if mesh is MeshInstance3D and mesh.position.y<0 and mesh.mesh.get_aabb().size.x>5:
   mesh.material_override=floor_material("concrete_floor_worn_001",Color("737a72"),.6,.42)

func _shelves() -> void:
 # The two old west-wall shelves would cover the window. Rehouse them beside
 # the prize machines, with actual colliders and saved-pose checks at the new site.
 var index:=0
 for shelf in w.props.RoomDressing.get_children():
  if not shelf.get_meta("stocked_shelf",false) or shelf.position.x>0:continue
  shelf.position=Vector3(3.8+index*1.4,.016,-11.65);shelf.rotation.y=0;index+=1
  for shape in shelf.find_children("*","CollisionShape3D",true,false):
   if shape.shape:obstacles.append(shape.global_transform*shape.shape.get_debug_mesh().get_aabb())

func _play_seams() -> void:
 var mesh:=CylinderMesh.new();mesh.top_radius=.002;mesh.bottom_radius=.002;mesh.height=1;mesh.radial_segments=6
 var positions: Array[Transform3D]=[]
 for x in [-.3,2.6,5.5]:
  for z in [-5.5,-2.4,.7,3.8]:
   for side in [-1,1]:
    for i in range(24):
     var p:=Vector3(x+side*.035,.40+i*.17,z+.138)
     positions.append(Transform3D(Basis.from_scale(Vector3(1,.035,1)),p))
 var stitches:=MultiMeshInstance3D.new();stitches.name="StitchedPaddingSeams";stitches.material_override=w.materials.stitch
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=positions.size()
 for i in range(positions.size()):mm.set_instance_transform(i,positions[i])
 stitches.multimesh=mm;w.props.structure.add_child(stitches);details+=positions.size()

func _ceiling() -> void:
 var felt:=w.polish.pbr("fabric_pattern_07",Color("505a52"),4.5);felt.normal_scale=.20;felt.roughness=.98
 for rect in [Rect2(-9.90,-11.9,16.45,28.8),Rect2(7.05,1.8,12.35,15.1),Rect2(7.05,-11.9,12.35,13.25)]:
  var columns:=ceili(rect.size.x/2.8);var rows:=ceili(rect.size.y/3.6)
  var pitch:=Vector2(rect.size.x/columns,rect.size.y/rows)
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=w.bevel(Vector3(pitch.x-.12,.025,pitch.y-.12));mm.instance_count=rows*columns
  for row in range(rows):
   for col in range(columns):
    var p:=Vector3(rect.position.x+(col+.5)*pitch.x,7.286,rect.position.y+(row+.5)*pitch.y)
    mm.set_instance_transform(row*columns+col,Transform3D(Basis.IDENTITY,p));details+=1
  var panels:=MultiMeshInstance3D.new();panels.name="MountedAcousticCeiling";panels.multimesh=mm;panels.material_override=felt;add_child(panels)
 # Small sprinkler drops are physically connected to the existing cross pipes.
 for x in [-6.,5.,16.]:
  for z in [-5.,5.,15.]:
   w.tube(self,Vector3(x,6.9,z),Vector3(x,6.65,z),.012,w.materials.metal)
   w.tube(self,Vector3(x,6.66,z),Vector3(x,6.62,z),.031,w.materials.rust)
   part(self,Vector3(x,6.615,z),Vector3(.10,.010,.10),w.materials.metal)

func _crt_screens() -> void:
 var glass:=ShaderMaterial.new();glass.shader=load(ROOT+"crt-glass.gdshader")
 for screen in w.details.find_children("*","MeshInstance3D",true,false):
  if not screen.mesh is QuadMesh:continue
  var display_material:=screen.material_override as ShaderMaterial
  if not display_material or not display_material in w.details.screens:continue
  var size_value: Vector2=screen.mesh.size
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in range(12):
   for col in range(16):
    var points: Array[Vector3]=[];var uv: Array[Vector2]=[]
    for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
     var q:=Vector2((col+corner.x)/16.,(row+corner.y)/12.)
     points.append(Vector3((q.x-.5)*size_value.x,(.5-q.y)*size_value.y,.020*(1.-pow(q.x*2.-1.,2))*(1.-pow(q.y*2.-1.,2))))
     uv.append(q)
    for i in [0,1,2,1,3,2]:st.set_uv(uv[i]);st.add_vertex(points[i])
  st.generate_normals();st.generate_tangents();screen.mesh=st.commit();screen.set_meta("curved_crt",true)
  var cover:=MeshInstance3D.new();cover.name="ConvexCRTGlass";cover.mesh=screen.mesh;cover.material_override=glass;cover.position.z=.0013;cover.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;screen.add_child(cover);details+=1

func _party() -> void:
 var linen:=w.polish.pbr("fabric_pattern_07",Color("8d8065"),7.);linen.normal_scale=.24;linen.roughness=.97;linen.cull_mode=BaseMaterial3D.CULL_DISABLED
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(42):
  for j in range(10):
   var points: Array[Vector3]=[]
   for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
    var x: float=(j+corner.y)/10.*.64-.32
    var z: float=(i+corner.x)/42.*3.52-1.76
    var drop:=maxf(0.,absf(z)-1.52)
    points.append(Vector3(8.5+x,.847-drop*.92+sin(z*37.+x*19.)*.0012,-7+z))
   SurfaceDetails.triangle(st,points[0],points[1],points[2],Vector3.UP);SurfaceDetails.triangle(st,points[1],points[3],points[2],Vector3.UP)
 st.generate_normals()
 var runner:=MeshInstance3D.new();runner.name="CreasedBirthdayTableRunner";runner.mesh=st.commit();runner.material_override=linen;w.props.party_table.add_child(runner);details+=1
 # Corners, toe-kicks and proper plinth edges make the old sideboard read as furniture.
 var unit: Node3D=w.props.RoomDressing.find_child("PartySideboard",true,false)
 for x in [-1.4,1.4]:part(unit,Vector3(x,.48,.352),Vector3(.035,.53,.020),w.materials.wood)
 part(unit,Vector3(0,.18,.32),Vector3(2.84,.035,.024),w.materials.dark)

func _kitchen() -> void:
 var root:=Node3D.new();root.name="KitchenManufacturedFinishes";add_child(root)
 var metal:=patina(Color("69766b"),.72)
 # A bolted wall fan sits on the solid west wall, with a closed guard grille.
 var housing:=Node3D.new();housing.position=Vector3(-17.17,2.75,-27.55);root.add_child(housing)
 part(housing,Vector3(-.025,0,0),Vector3(.055,.67,.67),metal)
 for y in [-.28,.28]:
  for z in [-.28,.28]:w.tube(housing,Vector3(.006,y,z),Vector3(.020,y,z),.016,w.materials.metal)
 fan=Node3D.new();fan.position.x=.065;housing.add_child(fan)
 for i in range(5):
  var blade:=part(fan,Vector3(0,sin(i*TAU/5.)*.14,cos(i*TAU/5.)*.14),Vector3(.018,.15,.19),metal);blade.rotation.x=-i*TAU/5.+.3
 w.tube(housing,Vector3(.03,0,0),Vector3(.10,0,0),.075,w.materials.dark)
 for i in range(13):
  var y: float=-.27+i*.045;var radius:=sqrt(maxf(0.,.285*.285-y*y))
  w.tube(housing,Vector3(.12,y,-radius),Vector3(.12,y,radius),.006,w.materials.metal)
 for y in [-.34,.34]:part(housing,Vector3(.01,y,0),Vector3(.11,.025,.70),metal)
 for z in [-.34,.34]:part(housing,Vector3(.01,0,z),Vector3(.11,.70,.025),metal)
 # Door gaskets and kick plates belong to the real manufactured refrigerator.
 var kit:=w.annex.get_node("ManufacturedKitchen")
 for mesh in kit.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var m:=mesh.get_active_material(i) as StandardMaterial3D
   if m and "steel" in m.resource_name.to_lower():m.normal_scale=.13;m.roughness=.48
 var diffuser:=w.mat(Color("b0b39a"),null,.61);diffuser.emission_enabled=true;diffuser.emission=Color("d7d0a2");diffuser.emission_energy_multiplier=.55
 part(root,Vector3(-13.25,2.632,-30.57),Vector3(.61,.025,.045),w.materials.dark)
 part(root,Vector3(-13.25,2.615,-30.57),Vector3(.52,.009,.032),diffuser)
 practical(root,Vector3(-13.25,2.51,-30.57),Color("d7d0a2"),.32,2.7)

func _cinema() -> void:
 var root:=Node3D.new();root.name="CinemaCurtainAndWiring";add_child(root)
 var velvet:=w.polish.pbr("dirty_carpet",Color("4e2838"),3.7);velvet.normal_scale=.30
 # Folded drapes flank the physical screen, keeping the central aisle open.
 for z in [-33.35,-26.05]:
  for i in range(6):
   var fold:=w.tube(root,Vector3(3.29,.27,z+i*.065),Vector3(3.29,3.29,z+i*.065),.055,velvet);details+=1
  part(root,Vector3(3.29,3.35,z+.16),Vector3(.14,.065,.53),w.materials.dark)
 for z in [-33.90,-25.55]:
  w.tube(root,Vector3(-6.20,2.96,z),Vector3(2.95,2.96,z),.008,w.materials.dark)
  w.tube(root,Vector3(2.95,2.96,z),Vector3(2.95,2.82,z),.008,w.materials.dark)
 for x in [-5.65,-.15,2.6]:
  for z in [-34.27,-25.25]:practical(root,Vector3(x,.28,z),Color("bf8550"),.055,1.3)

func _service() -> void:
 var root:=Node3D.new();root.name="ServiceRoomFabrication";add_child(root)
 var metal:=patina(Color("586964"),.68)
 # A continuous bracketed service pipe and shut-off wheels meet the west wall.
 w.tube(root,Vector3(-16.27,.44,-6.62),Vector3(-16.27,.44,-2.22),.035,metal)
 for z in [-5.4,-3.4]:
  w.tube(root,Vector3(-16.27,.44,z),Vector3(-16.27,1.18,z),.027,metal)
  var valve:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.092;ring.outer_radius=.107;ring.rings=24;ring.ring_segments=8
  valve.mesh=ring;valve.material_override=patina(Color("79403b"),.50);valve.position=Vector3(-16.15,.97,z);valve.rotation.z=PI/2;root.add_child(valve)
  for side in [-1,1]:w.tube(root,Vector3(-16.15,.97+side*.075,z),Vector3(-16.15,.97,z+side*.075),.009,metal)
  part(root,Vector3(-16.30,.44,z),Vector3(.075,.085,.11),metal)

func practical(parent: Node3D,p: Vector3,color: Color,energy: float,reach: float) -> OmniLight3D:
 var light:=OmniLight3D.new();light.position=p;light.light_color=color;light.light_energy=energy;light.omni_range=reach;light.omni_attenuation=1.8
 light.light_indirect_energy=.6;parent.add_child(light);lights.append({"light":light,"color":color,"energy":energy});return light

func _light_design() -> void:
 for spec in [[6.,Color("7ab7b1")],[7.5,Color("c5a876")],[9.5,Color("9bbca4")]]:
  practical(self,Vector3(spec[0],1.40,15.85),spec[1],.21,2.3)
 # Glass and polished metal reflect the actual room, not a stock sky cubemap.
 if native:
  for spec in [Vector3(-13.3,1.8,-29.7),Vector3(-1.3,1.8,-29.7),Vector3(-13.3,1.5,-4.45),Vector3(15,1.8,-15.6)]:
   var probe:=ReflectionProbe.new();probe.position=spec;probe.size=Vector3(8,3.3,9) if spec.z< -24 else Vector3(6,3,5)
   probe.interior=true;probe.box_projection=true;probe.intensity=.45;probe.max_distance=14;add_child(probe);probes.append(probe)

func _environment() -> void:
 var env:=w.environment.environment
 env.ambient_light_energy=.105;env.ambient_light_color=Color("71858f")
 env.tonemap_mode=Environment.TONE_MAPPER_AGX
 env.ssao_radius=.55;env.ssao_intensity=1.35;env.ssao_detail=.9;env.ssao_sharpness=.88
 env.ssil_radius=2.2;env.ssil_intensity=.9
 env.ssr_max_steps=96;env.ssr_depth_tolerance=.25
 env.glow_intensity=.24;env.glow_hdr_threshold=1.25
 env.adjustment_enabled=true;env.adjustment_contrast=1.045;env.adjustment_saturation=.93
 env.volumetric_fog_albedo=Color("a1adb0");env.volumetric_fog_density=.054;env.volumetric_fog_anisotropy=.35

func equipment(guard: NightGuard,intro: ElevatorIntro) -> void:
 # Hands and phone retain their authored shapes; refine skin response, seams,
 # glass and brushed cabin metal after these late-built objects exist.
 for branch in [guard.torch_body,intro]:
  for mesh in branch.find_children("*","MeshInstance3D",true,false):
   for i in range(mesh.mesh.get_surface_count()):
    var m:=mesh.get_active_material(i) as StandardMaterial3D
    if not m:continue
    if m.metallic>.4:
     m.roughness_texture=gloss_noise;m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.07
    elif "skin" in m.resource_name.to_lower():m.metallic_specular=.24;m.roughness=.71
 if native:
  var beam:=GradientTexture2D.new();beam.width=256;beam.height=256;beam.fill=GradientTexture2D.FILL_RADIAL;beam.fill_from=Vector2(.5,.5);beam.fill_to=Vector2(.5,1.)
  var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0.,.18,.50,.78,1.]);gradient.colors=PackedColorArray([Color.WHITE,Color(.92,.90,.85),Color(.65,.64,.60),Color(.17,.17,.16),Color.BLACK]);beam.gradient=gradient
  guard.lamp.light_projector=beam

func tick(delta: float,active: bool) -> void:
 exterior.tick(delta,active)
 if not active:return
 clock+=delta;fan.rotation.x=clock*1.7
 for record in lights:
  var light: Light3D=record.light
  light.light_color=Color("e22c28") if w.current=="lights_red" else record.color
  light.light_energy=0. if w.current=="party_dark" and light.global_position.x>6.8 and light.global_position.z<1.6 else record.energy

func quality(value: int) -> void:
 exterior.quality(value)
 for record in lights:record.light.shadow_enabled=false
 for probe in probes:probe.visible=value>0

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.28,.08,-.28),Vector3(.56,1.62,.56))
 for node in [w.props.counter,w.props.reception_chair]:
  if guard.intersects(node.global_transform*node.get_meta("furniture_volume")):return false
 for bounds in obstacles:
  if guard.intersects(bounds):return false
 return true

func snapshot() -> Dictionary:
 return {"clock":clock,"surfaces":surfaces,"details":details,"exterior_details":exterior.count,"rain":exterior.rain.multimesh.visible_instance_count,"window":true,"window_boards":exterior.boards.size(),"window_curtains":exterior.drapes.size(),"probes":probes.size(),"shelf_hulls":obstacles.size()}
