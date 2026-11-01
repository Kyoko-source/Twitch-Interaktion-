class_name RevampWorld
extends Node3D

var w: PlayWorld
var details:=0
var steel: StandardMaterial3D
var enamel: ShaderMaterial
var clock:=0.0
var condensation: Array[MeshInstance3D]=[]
var obstacles: Array[AABB]=[]

func build(world: PlayWorld) -> void:
 w=world;name="AfterPlayRevamp"
 steel=pbr("metal_plate",Color("b1b8af"),1.1);steel.metallic=.8;steel.roughness=.42
 enamel=paint(Color("a5ad91"),.19,.37)
 _kitchen();_party();_cinema();_maintenance();_reception();_architecture()
 for shape in find_children("*","CollisionShape3D",true,false):
  if shape.shape and not shape.disabled: obstacles.append(shape.global_transform*shape.shape.get_debug_mesh().get_aabb())
 set_meta("detail_count",details)

func pbr(id: String, color: Color, scale_value: float) -> StandardMaterial3D:
 if OS.has_feature("web") and id in ["dirty_tiles","metal_plate"]:
  var basic:=w.mat(color,load("res://assets/paint.png"),.75)
  basic.uv1_triplanar=true;basic.uv1_scale=Vector3.ONE*scale_value;return basic
 var m:=w.mat(color,load("res://assets/pbr/"+id+"/albedo.jpg"),.8)
 m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/"+id+"/normal.jpg");m.normal_scale=.55
 m.roughness_texture=load("res://assets/pbr/"+id+"/roughness.jpg");m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*scale_value;return m

func paint(color: Color, metal: float, rough: float) -> ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=load(ScareBank.ROOT+"weathered.gdshader")
 m.set_shader_parameter("paint",color);m.set_shader_parameter("metalness",metal);m.set_shader_parameter("polish",rough)
 m.set_shader_parameter("grain",load("res://assets/paint.png" if OS.has_feature("web") else "res://assets/pbr/rusty_painted_metal/albedo.jpg"));m.set_shader_parameter("roughness_map",load("res://assets/pbr/metal_grate_rusty/roughness.jpg" if OS.has_feature("web") else "res://assets/pbr/rusty_painted_metal/roughness.jpg"))
 m.set_shader_parameter("normal_map",w.atmosphere.micro_normal if OS.has_feature("web") else load("res://assets/pbr/metal_plate/normal.jpg"));return m

func part(parent: Node3D, pos: Vector3, size: Vector3, material: Material, solid: bool=false) -> MeshInstance3D:
 details+=1
 return w.box(parent,pos,size,material,solid)

func _kitchen() -> void:
 var root:=Node3D.new();root.name="KitchenRestoration";root.position=ServiceAnnex.OFFSET;root.set_meta("environment_dressing",true);add_child(root)
 var kit: Node3D=w.annex.find_child("ManufacturedKitchen",true,false)
 for mesh in kit.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var source: Material=mesh.get_active_material(i)
   if not source: continue
   var label: String=source.resource_name.to_lower()
   if "enamel" in label: mesh.set_surface_override_material(i,paint(Color("bac0a4") if "ivory" in label else Color("637b68"),.2,.36))
   elif "steel" in label: mesh.set_surface_override_material(i,steel)
 # A continuous photographic tiled wall replaces the old individually flat tiles.
 for mesh in w.annex.get_children():
  if mesh is MeshInstance3D and absf(mesh.position.x+17.23)<.005 and mesh.position.y<2.3 and mesh.position.y>.3: mesh.hide()
 var tiles:=pbr("dirty_tiles",Color("b9bdad"),.55)
 var wall:=part(root,Vector3(-17.207,1.25,-17.80),Vector3(.014,2.12,7.97),tiles);wall.name="PhotographicKitchenTiles"
 var floor:=part(root,Vector3(-13.36,.014,-17.86),Vector3(7.66,.006,8.92),pbr("dirty_tiles",Color("738076"),.68));floor.name="KitchenTileFloor"
 # Prep bench is built against the unused north wall, below its mounted prints.
 var bench:=Node3D.new();bench.name="KitchenPrepStation";bench.position=Vector3(-13.3,0,-14.0);root.add_child(bench)
 part(bench,Vector3(0,.91,0),Vector3(3.25,.07,.77),steel,true)
 for x in [-1.48,1.48]:
  for z in [-.28,.28]: part(bench,Vector3(x,.445,z),Vector3(.045,.89,.045),steel,true)
 part(bench,Vector3(0,.22,0),Vector3(3.1,.04,.63),steel,true)
 var board:=part(bench,Vector3(-.85,.965,.02),Vector3(.76,.045,.45),w.materials.wood)
 for i in range(9):
  var score:=part(board,Vector3(-.25+i*.059,.023,0),Vector3(.001,.001,.3),w.materials.dark);score.rotation.y=.2
 var knife:=part(bench,Vector3(-.7,.993,.06),Vector3(.32,.007,.045),steel);knife.rotation.y=.35
 part(knife,Vector3(-.22,0,0),Vector3(.17,.024,.04),w.materials.dark)
 for i in range(4):
  var dish:=SurfaceDetails.vessel(bench,Vector3(.65,.95+i*.022,.03),.055,.23,.17,.012,enamel,steel,"StackedPrepBowl");details+=1
 var tray:=SurfaceDetails.vessel(bench,Vector3(-.10,.95,.06),.07,.22,.20,.012,steel,steel,"GreasyPrepTray");details+=1
 for i in range(8): w.tube(tray,Vector3(-.1+i*.025,.07,-.10),Vector3(-.1+i*.025,.07,.10),.003,steel)
 # Real filter slats and a folded metal rim under the existing cooker hood.
 for x in [-13.83,-12.67]: part(root,Vector3(x,2.666,-19.25),Vector3(.045,.025,1.30),steel)
 for i in range(16): part(root,Vector3(-13.78+i*.071,2.661,-19.25),Vector3(.038,.018,1.28),w.materials.dark)
 for x in [-13.81,-12.69]:
  for z in [-19.86,-18.64]: w.sphere(root,Vector3(x,2.642,z),.011,steel)
 # Shelves are braced to plaster; their contents sit on the shelf top.
 for y in [1.65,2.12]:
  part(root,Vector3(-13.4,y,-13.55),Vector3(2.25,.035,.35),steel)
  for x in [-14.3,-12.5]: w.tube(root,Vector3(x,y-.24,-13.405),Vector3(x,y-.018,-13.71),.012,steel)
  for i in range(6):
   var jar:=SurfaceDetails.vessel(root,Vector3(-14.28+i*.34,y+.018,-13.56),.19,.08,.075,.007,enamel,w.materials.dark,"DustyKitchenJar");details+=1
   part(jar,Vector3(0,.20,0),Vector3(.15,.02,.15),steel)
 # Damp is shaded into the fitted tile finish by VenueCraft, without overlapping
 # transparent solids casting circular shadows through the kitchen floor.
 if w.native_art:
  var pantry:=w.native_art.model(root,"painted_wooden_cabinet_02",Vector3(-10.85,.012,-14.03),1.55,PI)
  pantry.name="ScannedKitchenPantry"
  var bounds:=AABB();var first:=true
  for mesh in pantry.find_children("*","MeshInstance3D",true,false):
   var box: AABB=(root.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
  var body:=StaticBody3D.new();body.name="PantryFittedSolid";root.add_child(body)
  var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=bounds.size;collision.shape=box;collision.position=bounds.get_center();body.add_child(collision)

func _party() -> void:
 var root:=Node3D.new();root.name="PartyHistoryDetails";add_child(root)
 # Sewn curtain folds and a proper valance beneath the existing stage lintel.
 var cloth:=pbr("fabric_pattern_07",Color("61433c"),3)
 for side in [-1,1]:
  for i in range(8):
   var fold:=w.tube(root,Vector3(14.2+side*(1.65+i*.055),.38,-11.57),Vector3(14.2+side*(1.65+i*.055),3.05,-11.57),.07,cloth);details+=1
  part(root,Vector3(14.2+side*1.85,3.10,-11.57),Vector3(.54,.07,.17),w.materials.wood)

func _cinema() -> void:
 var root:=Node3D.new();root.name="CinemaWallRestoration";root.position=ServiceAnnex.OFFSET;add_child(root)
 var velvet:=pbr("dirty_carpet",Color("5e3038"),2.1)
 # Absorber panels have padded faces and attached frames, leaving seat aisles open.
 # The remote and its label occupy -15.83; the poster occupies -14.55.
 # Neither may share the absorber's volume.
 for spec in [Vector2(-21.95,.60),Vector2(-19.4,.85)]:
  var z: float=spec.x;var width: float=spec.y
  part(root,Vector3(-6.275,1.76,z),Vector3(.045,1.66,width+.1),w.materials.dark)
  var face:=part(root,Vector3(-6.244,1.76,z),Vector3(.025,1.56,width),velvet);face.set_meta("new_acoustic_panel",true)
  for y in [1.02,2.50]:
   for zz in [-width*.4,width*.4]:w.sphere(root,Vector3(-6.224,y,z+zz),.012,steel)
 # Brass floor strips lie flush along the edges, outside all seat movement hulls.
 for z in [-22.1,-13.35]: part(root,Vector3(-1.2,.017,z),Vector3(9.7,.006,.032),steel)

func _maintenance() -> void:
 var root:=Node3D.new();root.name="MountedMaintenanceDetail";add_child(root)
 for z in [-5.9,-4.7,-3.5]:
  part(root,Vector3(-16.16,2.65,z),Vector3(.09,.24,.63),paint(Color("5a6863"),.7,.52))
  for y in [2.58,2.72]:
   for zz in [-.23,.23]: w.sphere(root,Vector3(-16.10,y,z+zz),.012,steel)
  w.tube(root,Vector3(-16.10,2.53,z),Vector3(-16.10,2.27,z),.013,w.materials.dark)
  w.tube(root,Vector3(-16.10,2.27,z),Vector3(-16.10,2.27,-6.54),.013,w.materials.dark)

func _reception() -> void:
 var root:=Node3D.new();root.name="ReceptionJoinery";w.props.counter.add_child(root)
 for y in [.08,.86]: part(root,Vector3(.468,y,0),Vector3(.012,.018,2.76),steel)
 for z in [-1.28,1.28]:
  for y in [.10,.84]: w.sphere(root,Vector3(.48,y,z),.009,steel)

func _architecture() -> void:
 var root:=Node3D.new();root.name="GroundedBuildingStructure";add_child(root)
 var trim:=paint(Color("49655c"),.35,.58)
 for span in [Vector2(-12.0,-10.6),Vector2(-9.2,-6.30),Vector2(-4.5,8.75),Vector2(10.15,16.8)]:
  for y in [.15,.32]:part(root,Vector3(-9.927,y,(span.x+span.y)*.5),Vector3(.07,.065,span.y-span.x),trim)
 for span in [Vector2(-11.8,6.65),Vector2(8.95,16.8)]:
  for y in [.15,.32]:part(root,Vector3(19.53,y,(span.x+span.y)*.5),Vector3(.07,.065,span.y-span.x),trim)
 # Beam tops meet the existing ceiling; no supports cross door openings.
 for z in [-9.7,-2.1,5.5,13.1]:
  part(root,Vector3(4.8,7.27,z),Vector3(29.5,.10,.19),trim)
  for x in [-9.80,19.40]:part(root,Vector3(x,7.12,z),Vector3(.18,.30,.28),steel)
 for p in [Vector3(12.4,6.72,11.4),Vector3(10.2,6.72,-7)]:
  w.tube(root,p,Vector3(p.x,7.23,p.z),.012,w.materials.dark)
  part(root,Vector3(p.x,7.26,p.z),Vector3(.16,.06,.16),steel)

func tick(delta: float, active: bool) -> void:
 if active: clock+=delta

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.27,.08,-.27),Vector3(.54,1.62,.54))
 for obstacle in obstacles:
  if guard.intersects(obstacle): return false
 return true
