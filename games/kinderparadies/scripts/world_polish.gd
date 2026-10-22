class_name AfterPlayPolish
extends Node3D

const MASCOT_POS:=Vector3(18.0,.016,15.10)
var w: PlayWorld
var mascot: Node3D
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

func _mascot() -> void:
 var root:=Node3D.new();root.name="MascotCorner";root.position=MASCOT_POS;root.rotation.y=-1.9;root.set_meta("foot_surface","carpet");add_child(root)
 mascot=(load("res://assets/polish-v240/mascot-rabbit.glb") as PackedScene).instantiate();mascot.name="GiantDeformedMascot";root.add_child(mascot)
 for mesh in mascot.find_children("*","MeshInstance3D",true,false):
  mesh.set_meta("mascot_mesh",true)
  for s in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(s) as StandardMaterial3D
   if material and material.resource_name.begins_with("CC0 teddy fur"):
    var fur:=pbr("curly_teddy_natural",Color.WHITE,2.1);fur.vertex_color_use_as_albedo=true;fur.cull_mode=BaseMaterial3D.CULL_DISABLED;fur.normal_scale=.7
    mesh.set_surface_override_material(s,fur)
 # Separate fitted shapes preserve open space around the arms and ears.
 for piece in [{"p":Vector3(0,1.45,0),"size":Vector3(1.8,2.7,1.25)},{"p":Vector3(-.72,.35,.64),"size":Vector3(1.1,.66,1.6)},{"p":Vector3(.72,.35,.64),"size":Vector3(1.1,.66,1.6)}]:
  var body:=StaticBody3D.new();body.name="MascotSolid";var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=piece.size;collider.shape=shape;body.position=piece.p;body.add_child(collider);root.add_child(body)
 var head_body:=StaticBody3D.new();head_body.name="MascotHeadSolid";head_body.position=Vector3(-.22,3.12,.20);root.add_child(head_body)
 var head_shape:=CollisionShape3D.new();var skull:=SphereShape3D.new();skull.radius=.76;head_shape.shape=skull;head_body.add_child(head_shape)
 for side in [-1,1]:
  var arm:=StaticBody3D.new();arm.name="MascotArmSolid";arm.position=Vector3(side*1.04,1.48,.10);root.add_child(arm)
  var shape:=CollisionShape3D.new();var bounds:=CapsuleShape3D.new();bounds.radius=.34;bounds.height=1.7;shape.shape=bounds;arm.add_child(shape)
 for ends in [[Vector3(-.65,3.57,.09),Vector3(-.90,4.6,-.02)],[Vector3(-.90,4.6,-.02),Vector3(-.39,4.86,.4)],[Vector3(.2,3.66,.04),Vector3(.63,4.32,.05)],[Vector3(.63,4.32,.05),Vector3(1.02,3.83,.46)]]:
  var body:=StaticBody3D.new();body.name="MascotEarSolid";body.position=(ends[0]+ends[1])*.5;body.quaternion=Quaternion(Vector3.UP,(ends[1]-ends[0]).normalized());root.add_child(body)
  var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.16;capsule.height=ends[0].distance_to(ends[1])+.32;shape.shape=capsule;body.add_child(shape)
 var sign:=Node3D.new();sign.name="MascotSafetyPlaque";sign.position=Vector3(-1.0,.0,1.65);sign.rotation.x=-.12;root.add_child(sign)
 w.box(sign,Vector3(0,.23,0),Vector3(.68,.46,.055),w.materials.rust,true)
 w.artwork(sign,Vector3(0,.23,.035),Vector2(.61,.39),load("res://assets/polish-v240/mascot-sign.png"))
 for x in [-.22,.22]: w.tube(sign,Vector3(x,.012,0),Vector3(x,.2,0),.017,w.materials.dark)
 var key:=SpotLight3D.new();key.position=Vector3(-1.7,5.6,2.65);root.add_child(key);key.look_at(root.to_global(Vector3(0,2.4,0)))
 key.light_color=Color("dfbb83");key.light_energy=1.8;key.spot_range=7;key.spot_angle=36;key.shadow_enabled=true
 # The light really sits on a bracket, not unsupported in the room.
 w.box(root,Vector3(-1.7,5.6,2.65),Vector3(.23,.15,.12),w.materials.dark)
 w.tube(root,Vector3(-1.7,5.68,2.65),Vector3(-1.7,7.27,2.65),.018,w.materials.rust)
 w.box(root,Vector3(-1.7,7.27,2.65),Vector3(.18,.04,.18),w.materials.dark)
 w.atmosphere.decal(self,0,Vector3(17.5,.033,15.1),Vector2(1.35,1.1),Vector3(-PI/2,.2,0),Color(.55,.25,.22,.8))
 for i in range(7):
  var cotton:=w.sphere(root,Vector3(-.5+i*.14,.07,1.23+sin(i)*.19),.10,w.materials.fabric);cotton.scale=Vector3(1,.45,.7)

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
 w.atmosphere.decal(workbench,0,Vector3(-.22,.922,.08),Vector2(.37,.25),Vector3(-PI/2,0,0),Color(.7,.27,.21,.9))
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
 for i in range(3): reel(desk,Vector3(-.25+i*.25,.89,.04),.13,i*.35)
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
  w.box(root,Vector3(-9.97,2.8,z),Vector3(.08,.32,.12),w.materials.rust)
 for y in [2.72,2.9]:
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
 if absf(point.y-.008)<.04 and Rect2(-6.275,-22.15,9.95,8.6).has_point(Vector2(point.x,point.z)): return "carpet"
 return "concrete"
