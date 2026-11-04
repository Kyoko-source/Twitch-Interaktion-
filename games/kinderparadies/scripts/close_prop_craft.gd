class_name ClosePropCraft
extends RefCounted

static var plate_geometry: ArrayMesh
static var ceramic: ShaderMaterial

static func fixing(w: PlayWorld,parent: Node3D,p: Vector3,material: Material) -> void:
 w.tube(parent,p,p+Vector3(0,0,.003),.0055,material)
 w.box(parent,p+Vector3(0,0,.0035),Vector3(.0065,.0012,.0008),w.materials.dark)

static func cabinet_details(w: PlayWorld,root: Node3D) -> void:
 var detail:=Node3D.new();detail.name="FittedArcadeServiceHardware";root.add_child(detail)
 var zinc:=w.mat(Color("8a8b75"),null,.46,.72)
 # Fixings fit the existing front coin-service panel and do not change its size.
 for x in [-.086,.086]:
  for y in [.49,.71]:fixing(w,detail,Vector3(x,y,.412),zinc)
 for y in [.51,.69]:
  w.tube(detail,Vector3(-.106,y-.018,.414),Vector3(-.106,y+.018,.414),.006,zinc)
 w.tube(detail,Vector3(-.049,.646,.414),Vector3(-.049,.646,.420),.012,zinc)
 w.box(detail,Vector3(-.049,.646,.421),Vector3(.002,.010,.001),w.materials.dark)
 for side in [-1,1]:
  # Recessed rear vent openings and bolts live on the cabinet's actual back.
  for i in range(4):w.box(detail,Vector3(side*.18,.36+i*.039,-.372),Vector3(.13,.010,.004),w.materials.dark)
 CelebrationTailoring.merge_joint(detail)

static func plate(w: PlayWorld,parent: Node3D,p: Vector3,radius: float) -> void:
 if not plate_geometry:
  # Closed cross-section: foot ring, underside, rolled rim and shallow well.
  var profile: Array[Vector2]=[Vector2(0,.046),Vector2(.40,.046),Vector2(.43,.023),Vector2(.48,.023),Vector2(.51,.050),Vector2(.78,.065),Vector2(.97,.119),Vector2(1.,.136),Vector2(.985,.15),Vector2(.94,.148),Vector2(.75,.108),Vector2(.56,.075),Vector2(0,.075)]
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in range(profile.size()-1):
   for side in range(64):
    var a:=TAU*side/64.;var b:=TAU*(side+1)/64.;var q:=profile[row];var r:=profile[row+1]
    var normal:=Vector3(cos((a+b)*.5)*(r.y-q.y),q.x-r.x,sin((a+b)*.5)*(r.y-q.y)).normalized()
    var aa:=Vector3(cos(a)*q.x,q.y,sin(a)*q.x);var ab:=Vector3(cos(b)*q.x,q.y,sin(b)*q.x)
    var ba:=Vector3(cos(a)*r.x,r.y,sin(a)*r.x);var bb:=Vector3(cos(b)*r.x,r.y,sin(b)*r.x)
    SurfaceDetails.triangle(st,aa,ba,bb,normal);SurfaceDetails.triangle(st,aa,bb,ab,normal)
  st.generate_normals();st.generate_tangents();st.index();plate_geometry=st.commit()
 if not ceramic:
  ceramic=ShaderMaterial.new();ceramic.shader=load("res://assets/quality-v410/ceramic.gdshader")
 var root:=Node3D.new();root.name="UsedPlate";root.position=p;parent.add_child(root)
 var dish:=MeshInstance3D.new();dish.name="GlazedRolledRimPlate";dish.mesh=plate_geometry;dish.material_override=ceramic;dish.scale=Vector3.ONE*radius;root.add_child(dish)

static func phone(w: PlayWorld,root: Node3D) -> void:
 for child in root.get_children():
  if child is GeometryInstance3D:child.hide()
 var model: Node3D=(load(QualityAssets.ROOT+"desktop/desk-phone.glb") as PackedScene).instantiate();model.name="ManufacturedReceptionTelephone";root.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.set_meta("nonblocking_atmosphere",true)

static func refine(w: PlayWorld) -> void:
 var phone_root:=w.find_child("ReceptionDeskPhone",true,false) as Node3D
 if phone_root and not OS.has_feature("web"):phone(w,phone_root)
 for id in ["Arcade_arcade","Arcade_orbit"]:
  var cabinet:=w.details.find_child(id,true,false) as Node3D
  if cabinet:cabinet_details(w,cabinet)
 # Small underside fixings follow existing seats. No leg/caster colliders.
 for chair in w.props.chairs.get_children() if OS.has_feature("web") else []:
  var detail:=Node3D.new();detail.name="SeatManufacturingDetails";chair.add_child(detail)
  var rubber:=w.mat(Color("1a211d"),null,.93)
  var steel:=w.mat(Color("778076"),null,.43,.70)
  for x in [-.18,.18]:
   for z in [-.18,.18]:
    w.tube(detail,Vector3(x,.014,z),Vector3(x,.043,z),.021,rubber)
    var bolt:=w.sphere(detail,Vector3(x,.374,z),.008,steel);bolt.scale.y=.3
  CelebrationTailoring.merge_joint(detail)
 # A fitted cash drawer under the existing PC, with a recessed lock and rails.
 var pc:=w.props.counter.get_node("ReceptionPC") as Node3D
 var drawer:=Node3D.new();drawer.name="ReceptionCashDrawer";drawer.position=Vector3(0,1.006,-.35);drawer.rotation.y=pc.rotation.y;w.props.counter.add_child(drawer)
 var steel:=w.mat(Color("444f45"),null,.64,.48)
 w.box(drawer,Vector3.ZERO,Vector3(.30,.022,.24),steel)
 for x in [-.145,.145]:w.box(drawer,Vector3(x,.002,0),Vector3(.008,.024,.25),w.materials.dark)
 w.box(drawer,Vector3(0,0,.125),Vector3(.286,.017,.008),steel)
 w.tube(drawer,Vector3(0,0,.130),Vector3(0,0,.134),.005,w.materials.metal)
 w.box(drawer,Vector3(0,0,.135),Vector3(.001,.005,.0005),w.materials.dark)
 CelebrationTailoring.merge_joint(drawer)
