class_name AfterPlayPolish
extends Node3D

const PARTY_MASCOT_POS:=Vector3(17.9,.016,.38)
var w: PlayWorld
var mascot: Node3D
var party_mascot: Node3D
var detail_count:=0

func build(world: PlayWorld) -> void:
 w=world;name="AfterPlayPolish"
 _mascot();_workshop();_cinema();_maintenance_hall();_collision_repairs()

func pbr(id: String, tint: Color, scale_value: float=1) -> StandardMaterial3D:
 var material:=w.mat(tint,load("res://assets/pbr/"+id+"/albedo.jpg"),.95)
 material.normal_enabled=true;material.normal_texture=load("res://assets/pbr/"+id+"/normal.jpg");material.normal_scale=.6
 material.roughness_texture=load("res://assets/pbr/"+id+"/roughness.jpg");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*scale_value
 return material

func blood_mark(parent: Node3D, pos: Vector3, size: Vector2, rotation_value: Vector3) -> void:
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size;mesh.mesh=quad;mesh.position=pos;mesh.rotation=rotation_value;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material:=ShaderMaterial.new();material.shader=load("res://assets/presentation-v250/blood-surface.gdshader");material.set_shader_parameter("blood_map",load("res://assets/presentation-v250/blood-texture.png"));material.set_shader_parameter("dryness",.82);mesh.material_override=material;parent.add_child(mesh)

func _mascot() -> void:
 party_mascot=_mascot_at(PARTY_MASCOT_POS,PI,"PartyMascotCorner")
 mascot=party_mascot

func _mascot_at(pos: Vector3, yaw: float, id: String) -> Node3D:
 var root:=Node3D.new();root.name=id;root.position=pos;root.rotation.y=yaw;root.set_meta("giant_mascot",true);add_child(root)
 var visual: Node3D=(load("res://assets/mascot-v251/mascot-rabbit.glb") as PackedScene).instantiate();visual.name="TailoredGiantMascot";root.add_child(visual)
 for mesh in visual.find_children("*","MeshInstance3D",true,false):
  mesh.set_meta("mascot_mesh",true)
  for s in range(mesh.mesh.get_surface_count()):
   var source:=mesh.get_active_material(s) as StandardMaterial3D
   if not source: continue
   var material:=source.duplicate() as StandardMaterial3D
   material.vertex_color_use_as_albedo=true;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   if material.resource_name.begins_with("Worn oatmeal"):
    material.uv1_scale=Vector3(10.8,10.8,1);material.normal_scale=.26;material.roughness=.97;material.metallic_specular=.13
   elif material.resource_name.begins_with("Vintage sewn"):
    material.uv1_scale=Vector3(5,5,1);material.normal_scale=.30;material.roughness=.99;material.metallic_specular=.10
   elif material.resource_name.begins_with("Dirty irregular"):
    material.albedo_texture=null;material.albedo_color=Color("d6d0bd");material.uv1_scale=Vector3(5,5,1);material.normal_scale=.50;material.roughness=1.0;material.metallic_specular=.03
   elif material.resource_name.begins_with("Loose cotton"):
    material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.metallic_specular=.03
   mesh.set_surface_override_material(s,material)
 # Separate fitted shapes preserve open space around the arms and ears.
 for piece in [{"p":Vector3(0,1.27,0),"size":Vector3(1.88,2.35,1.35)},{"p":Vector3(-.62,.38,.47),"size":Vector3(1.08,.72,1.60)},{"p":Vector3(.62,.38,.47),"size":Vector3(1.08,.72,1.60)}]:
  var body:=StaticBody3D.new();body.name="MascotSolid";var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=piece.size;collider.shape=shape;body.position=piece.p;body.add_child(collider);root.add_child(body)
 var head_body:=StaticBody3D.new();head_body.name="MascotHeadSolid";head_body.position=Vector3(.055,2.92,.091);root.add_child(head_body)
 var head_shape:=CollisionShape3D.new();var skull:=SphereShape3D.new();skull.radius=.83;head_shape.shape=skull;head_body.add_child(head_shape)
 for side in [-1,1]:
  var arm:=StaticBody3D.new();arm.name="MascotArmSolid";arm.position=Vector3(side*1.0,1.28,.036);root.add_child(arm)
  var shape:=CollisionShape3D.new();var bounds:=CapsuleShape3D.new();bounds.radius=.37;bounds.height=1.75;shape.shape=bounds;arm.add_child(shape)
 for side in [-1,1]:
  var points: Array[Vector3]=[Vector3(side*.13,.94,0),Vector3(side*.21,1.35,-.015),Vector3(side*.33,1.45,.08),Vector3(side*.35,1.18 if side<0 else 1.34,.2)]
  for i in range(4):
   var ends: Array[Vector3]=[]
   for t in [i/4.0,(i+1)/4.0]:
    var p: Vector3=pow(1-t,3)*points[0]+3*pow(1-t,2)*t*points[1]+3*(1-t)*t*t*points[2]+pow(t,3)*points[3];p.y+=.03;ends.append(p*3.65)
   var body:=StaticBody3D.new();body.name="MascotEarSolid";body.position=(ends[0]+ends[1])*.5;body.quaternion=Quaternion(Vector3.UP,(ends[1]-ends[0]).normalized());root.add_child(body)
   var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.18;capsule.height=ends[0].distance_to(ends[1])+.36;shape.shape=capsule;body.add_child(shape)
 var lamp_x:=-1.5
 var key:=SpotLight3D.new();key.position=Vector3(lamp_x,5.6,2.65);root.add_child(key);key.look_at(root.to_global(Vector3(0,2.4,0)))
 key.light_color=Color("dfbb83");key.light_energy=1.2;key.light_size=.12;key.spot_range=7;key.spot_angle=36;key.shadow_enabled=true
 # The light really sits on a bracket, not unsupported in the room.
 w.box(root,Vector3(lamp_x,5.6,2.65),Vector3(.23,.15,.12),w.materials.dark)
 w.tube(root,Vector3(lamp_x,5.68,2.65),Vector3(lamp_x,7.27,2.65),.018,w.materials.rust)
 w.box(root,Vector3(lamp_x,7.27,2.65),Vector3(.18,.04,.18),w.materials.dark)
 return visual

func _workshop() -> void:
 var root:=Node3D.new();root.name="MaintenanceWorkshop";w.server_room.add_child(root)
 var steel:=w.mat(Color("586358"),load("res://assets/paint.png"),.68,.65)
 var board:=Node3D.new();board.name="MountedToolBoard";board.position=Vector3(-16.27,1.89,-5.65);board.rotation.y=PI/2;root.add_child(board)
 w.box(board,Vector3.ZERO,Vector3(1.40,1.0,.045),w.materials.wood)
 for row in range(5):
  for col in range(9):
   var hole:=w.sphere(board,Vector3(-.6+col*.15,-.4+row*.18,.026),.011,w.materials.dark);hole.scale.z=.2
 for i in range(4):
  var x:=-.48+i*.29
  w.tube(board,Vector3(x,-.25,.065),Vector3(x,.27,.065),.016,steel)
  w.tube(board,Vector3(x-.06,.27,.065),Vector3(x+.06,.27,.065),.026,steel)
  w.tube(board,Vector3(x-.05,.23,.065),Vector3(x-.05,.33,.065),.015,steel)
  w.tube(board,Vector3(x+.05,.23,.065),Vector3(x+.05,.33,.065),.015,steel)
 var workbench:=Node3D.new();workbench.name="GroundedRepairBench";workbench.position=Vector3(-15.83,.012,-5.73);workbench.rotation.y=PI/2;root.add_child(workbench)
 var top:=w.box(workbench,Vector3(0,.85,0),Vector3(1.48,.09,.64),w.materials.wood,true);top.set_meta("foot_surface","wood")
 for side in [-1,1]:
  for back in [-1,1]: w.box(workbench,Vector3(side*.62,.41,back*.24),Vector3(.06,.82,.06),steel,true)
 w.box(workbench,Vector3(0,.2,0),Vector3(1.32,.05,.52),steel,true)
 for i in range(5):
  var binder:=w.box(workbench,Vector3(-.5+i*.16,.38,.04),Vector3(.13,.29,.32),w.materials.paper if i%2 else w.materials.teal)
  w.box(binder,Vector3(0,.04,.164),Vector3(.06,.10,.008),w.materials.cream)
 SurfaceDetails.vessel(workbench,Vector3(.34,.899,.0),.14,.10,.13,.009,steel,w.materials.dark,"BloodiedPartsTray")
 for i in range(6): w.tube(workbench,Vector3(.24+i*.025,.91,-.04),Vector3(.27+i*.025,.92,.06),.008,w.materials.rust)
 var rag:=w.box(workbench,Vector3(-.22,.91,.08),Vector3(.43,.016,.31),w.materials.fabric);rag.rotation.y=.18
 blood_mark(workbench,Vector3(-.22,.922,.08),Vector2(.37,.25),Vector3(-PI/2,0,0))
 w.artwork(root,Vector3(-13.0,2.2,-6.835),Vector2(1.55,.75),load("res://assets/polish-v240/maintenance-board.png"))
 # Cable coils and strapped pipes are attached to actual walls/rack anchors.
 for i in range(3):
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.17+i*.028;torus.outer_radius=.19+i*.028;torus.rings=32;torus.ring_segments=8;ring.mesh=torus;ring.material_override=w.materials.dark;ring.position=Vector3(-16.28,1.65,-2.65);ring.rotation.z=PI/2;root.add_child(ring)
 for z in [-6.35,-4.9,-3.4]:
  w.box(root,Vector3(-16.27,.48,z),Vector3(.04,.085,.30),steel)
 for y in [.36,.56]: w.tube(root,Vector3(-16.25,y,-6.6),Vector3(-16.25,y,-2.2),.036,w.materials.rust)
 var floor_mesh:=w.server_room.get_node("ServiceFloor") as MeshInstance3D
 floor_mesh.material_override=pbr("metal_grate_rusty",Color("8d9184"),1.8);floor_mesh.set_meta("foot_surface","metal")
 w.atmosphere.decal(root,0,Vector3(-15.75,1.2,-6.835),Vector2(.55,.75),Vector3.ZERO,Color(.5,.25,.23,.65))

func _cinema() -> void:
 var root:=Node3D.new();root.name="CinemaRestoration";w.annex.add_child(root)
 var carpet:=w.annex.get_node("CinemaCarpet") as MeshInstance3D
 carpet.material_override=pbr("dirty_carpet",Color("654148"),.65)
 var fabric:=pbr("fabric_pattern_07",Color("4a252b"),2)
 for mesh in w.annex.get_children():
  if mesh.name.begins_with("LegacyCurtainFold"): mesh.hide()
 _curtains(root,fabric)
 # Acoustic panels fixed to the two side walls, not floating ceiling curtains.
 for z in [-22.36,-13.48]:
  for i in range(8):
   var panel:=w.box(root,Vector3(-5.75+i*1.1,1.72,z),Vector3(.92,2.12,.065),fabric)
   for side in [-1,1]: w.box(panel,Vector3(side*.45,0,.04),Vector3(.025,2.1,.025),w.materials.wood)
 for x in [-4.6,-2.6,-.6,1.4]:
  for z in [-18.18,-17.12]:
   var casing:=w.box(root,Vector3(x,.06,z),Vector3(.22,.09,.10),w.materials.dark)
   var red:=w.mat(Color("86332a"));red.emission_enabled=true;red.emission=Color("a73b2b");red.emission_energy_multiplier=.8
   w.box(casing,Vector3(0,.005,.056),Vector3(.16,.025,.008),red)
 # Abandoned projection worktable is against the back wall, away from entry aisle.
 var desk:=Node3D.new();desk.name="ProjectionWorktable";desk.position=Vector3(-5.86,.008,-14.55);desk.rotation.y=PI/2;root.add_child(desk)
 var top:=w.box(desk,Vector3(0,.83,0),Vector3(1.05,.065,.56),w.materials.wood,true);top.set_meta("foot_surface","wood")
 for x in [-.43,.43]:
  for z in [-.2,.2]: w.box(desk,Vector3(x,.4,z),Vector3(.045,.8,.045),w.materials.metal,true)
 # The left-hand reel is the actual collectible built by CinemaFilm.
 for i in range(2): reel(desk,Vector3(.02+i*.27,.868,.04),.12,i*.35)
 w.artwork(root,Vector3(-6.265,2.23,-14.55),Vector2(1.25,1.35),load("res://assets/polish-v240/cinema-poster.png"),PI/2)
 w.artwork(root,Vector3(-6.265,2.23,-20.9),Vector2(1.15,1.35),load("res://assets/polish-v240/cinema-poster.png"),PI/2)
 # Worn seat seams, cupholders, torn patches and small abandoned paper cups.
 for seat in w.annex.get_children():
  if seat.name.to_lower().begins_with("cinemaseat"):
   w.tube(seat,Vector3(-.27,.59,-.27),Vector3(-.27,1.23,-.32),.009,w.materials.stitch)
   w.tube(seat,Vector3(.27,.59,-.27),Vector3(.27,1.23,-.32),.009,w.materials.stitch)
   if int(absf(seat.position.x*10+seat.position.z))%3==0:
    w.atmosphere.decal(seat,0,Vector3(.05,.561,.02),Vector2(.31,.37),Vector3(-PI/2,.2,0),Color(.38,.24,.21,.8))
   var holder:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.045;torus.outer_radius=.058;torus.rings=16;torus.ring_segments=6;holder.mesh=torus;holder.material_override=w.materials.dark;holder.position=Vector3(.37,.74,.21);seat.add_child(holder)
 w.atmosphere.decal(root,0,Vector3(3.36,.12,-20.9),Vector2(.65,1.1),Vector3(0,-PI/2,0),Color(.45,.23,.21,.8))

func _curtains(root: Node3D, fabric: StandardMaterial3D) -> void:
 w.tube(root,Vector3(3.28,3.39,-21.95),Vector3(3.28,3.39,-13.45),.032,w.materials.rust)
 for z in [-21.8,-17.7,-13.6]: w.tube(root,Vector3(3.28,3.4,z),Vector3(3.28,3.505,z),.025,w.materials.metal)
 for center in [-21.42,-13.98]:
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in range(26):
   for col in range(32):
    for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
     var u: float=(col+corner.x)/32.0;var v: float=(row+corner.y)/26.0;var z: float=center+(u-.5)*.86
     var hem:=.22+.11*sin(u*23)+.04*sin(u*79)
     var colour:=Color("641c1e") if sin(u*27+v*2.1)>.45 and v>.31 else Color("ba9982")
     tool.set_color(colour);tool.set_uv(Vector2(u,v*3));tool.add_vertex(Vector3(3.22+.065*cos(u*TAU*6),lerpf(3.32,hem,v),z))
  tool.generate_normals()
  var curtain:=MeshInstance3D.new();curtain.name="TornSewnCinemaCurtain";curtain.mesh=tool.commit()
  var material:=fabric.duplicate() as StandardMaterial3D;material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;curtain.material_override=material;root.add_child(curtain)
  for i in range(7): w.tube(root,Vector3(3.28,3.39,center-.39+i*.13),Vector3(3.23,3.32,center-.39+i*.13),.012,w.materials.metal)

func reel(parent: Node3D, pos: Vector3, radius: float, yaw: float) -> void:
 var root:=Node3D.new();root.position=pos;root.rotation.y=yaw;parent.add_child(root)
 for y in [0,.035]:
  var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=radius*.84;mesh.outer_radius=radius;mesh.rings=24;mesh.ring_segments=6;ring.mesh=mesh;ring.material_override=w.materials.metal;ring.position.y=y;root.add_child(ring)
  for i in range(5):
   var a:=i*TAU/5;w.tube(root,Vector3(0,y,0),Vector3(sin(a)*radius*.92,y,cos(a)*radius*.92),.012,w.materials.metal)
 w.tube(root,Vector3(0,0,0),Vector3(0,.04,0),.035,w.materials.rust)

func _maintenance_hall() -> void:
 var root:=Node3D.new();root.name="MaintenancePipework";add_child(root)
 # Wall-hugging infrastructure leaves both archive/server doors and main lane clear.
 for z in [-7.8,-6.5,-4.3,-3.0]:
  w.box(root,Vector3(-9.97,4.19,z),Vector3(.08,.32,.12),w.materials.rust)
 for y in [4.1,4.28]:
  w.tube(root,Vector3(-9.91,y,-8.0),Vector3(-9.91,y,-2.9),.045,w.materials.rust)
  for z in [-7.8,-6.5,-4.3,-3]: w.tube(root,Vector3(-9.99,y,z),Vector3(-9.85,y,z),.015,w.materials.metal)
 w.artwork(root,Vector3(-9.975,2.0,-7.55),Vector2(.75,.7),load("res://assets/polish-v240/maintenance-board.png"),PI/2)

func _collision_repairs() -> void:
 # Decorative imported cartons previously had no collision at all.
 if w.native_art:
  for chair in w.props.chairs.get_children():
   for old in chair.get_children():
    if old is MeshInstance3D and old.has_meta("solid_visual"):
     (old.get_node("Solid").get_child(0) as CollisionShape3D).disabled=true
  for instance in w.native_art.find_children("*","MeshInstance3D",true,false):
   if instance.get_meta("native_model","")=="cardboard_box_01":
    instance.create_convex_collision();instance.set_meta("matched_import_collision",true)
  for instance in w.props.chairs.find_children("*","MeshInstance3D",true,false):
   if instance.get_meta("native_model","")=="SchoolChair_01":
    instance.create_trimesh_collision();instance.set_meta("matched_import_collision",true)
 # New colliders follow their visible box's pose, rather than stale sibling poses.
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("solid_visual"): detail_count+=1

func surface_at(point: Vector3) -> String:
 # Called only for an actual downward floor hit; the carpet is a thin overlay.
 if absf(point.y-.008)<.04 and Rect2(-6.275,-22.15,9.95,8.6).has_point(Vector2(point.x,point.z-ServiceAnnex.OFFSET.z)): return "carpet"
 return "concrete"
