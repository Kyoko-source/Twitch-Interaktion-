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

static var fork_geometry: ArrayMesh
static var knife_geometry: ArrayMesh
static var roll_geometry: ArrayMesh
static var cutlery_steel: StandardMaterial3D
static var crust: StandardMaterial3D

# A closed, tapered flat bar along a centreline: rectangular sections with caps.
static func _bar(st: SurfaceTool,points: Array[Vector3],half_widths: Array[float],thickness: Array[float]) -> void:
 var rings: Array=[]
 for i in range(points.size()):
  var p:=points[i];var a:=half_widths[i];var t:=thickness[i]*.5
  rings.append([p+Vector3(-a,-t,0),p+Vector3(a,-t,0),p+Vector3(a,t,0),p+Vector3(-a,t,0)])
 for i in range(rings.size()-1):
  for k in range(4):
   var a: Vector3=rings[i][k];var b: Vector3=rings[i][(k+1)%4];var c: Vector3=rings[i+1][(k+1)%4];var d: Vector3=rings[i+1][k]
   st.add_vertex(a);st.add_vertex(c);st.add_vertex(b);st.add_vertex(a);st.add_vertex(d);st.add_vertex(c)
 for cap in [[0,true],[rings.size()-1,false]]:
  var r: Array=rings[cap[0]]
  if cap[1]:st.add_vertex(r[0]);st.add_vertex(r[1]);st.add_vertex(r[2]);st.add_vertex(r[0]);st.add_vertex(r[2]);st.add_vertex(r[3])
  else:st.add_vertex(r[0]);st.add_vertex(r[2]);st.add_vertex(r[1]);st.add_vertex(r[0]);st.add_vertex(r[3]);st.add_vertex(r[2])

static func _commit(st: SurfaceTool) -> ArrayMesh:
 st.generate_normals();st.index();return st.commit()

static func _handle(st: SurfaceTool) -> void:
 # Rounded handle end, gentle taper and the slight rise every real handle has.
 var pts: Array[Vector3]=[];var hw: Array[float]=[];var th: Array[float]=[]
 for i in range(9):
  var t:=i/8.0;var z:=lerpf(-.098,.012,t)
  pts.append(Vector3(0,.0035+.004*pow(1-t,2),z));hw.append(lerpf(.0065,.0042,t)*(.55+.45*sqrt(sin(minf(1,t*6)*PI*.5))));th.append(lerpf(.0034,.0026,t))
 _bar(st,pts,hw,th)

static func fork_mesh() -> ArrayMesh:
 if fork_geometry:return fork_geometry
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);_handle(st)
 var pts: Array[Vector3]=[];var hw: Array[float]=[];var th: Array[float]=[]
 for i in range(7):
  var t:=i/6.0;var z:=lerpf(.012,.052,t)
  pts.append(Vector3(0,.0018+.0028*t*t,z));hw.append(lerpf(.0042,.0026,smoothstep(0,.35,t))+lerpf(0,.0096,smoothstep(.45,1,t)));th.append(.0021)
 _bar(st,pts,hw,th)
 for x in [-.0101,-.0034,.0034,.0101]:
  var tp: Array[Vector3]=[];var tw: Array[float]=[];var tt: Array[float]=[]
  for i in range(6):
   var t:=i/5.0
   tp.append(Vector3(x*(1-.06*t),.0046+.0042*t*t,.0515+.036*t));tw.append(lerpf(.0019,.0008,t));tt.append(lerpf(.0021,.0012,t))
  _bar(st,tp,tw,tt)
 fork_geometry=_commit(st);return fork_geometry

static func knife_mesh() -> ArrayMesh:
 if knife_geometry:return knife_geometry
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);_handle(st)
 var pts: Array[Vector3]=[];var hw: Array[float]=[];var th: Array[float]=[]
 for i in range(10):
  var t:=i/9.0
  # Blade off-centre: straight back, curved belly rising to a rounded tip.
  var half:=lerpf(.0034,.0085,smoothstep(0,.18,t))*(1-pow(t,4)*.82)
  pts.append(Vector3(half*.35,.0017,lerpf(.012,.098,t)));hw.append(half);th.append(lerpf(.0019,.0009,t))
 _bar(st,pts,hw,th)
 knife_geometry=_commit(st);return knife_geometry

static func cutlery(w: PlayWorld,parent: Node3D,p: Vector3,yaw: float,knife: bool=false) -> MeshInstance3D:
 if not cutlery_steel:
  cutlery_steel=StandardMaterial3D.new();cutlery_steel.albedo_color=Color("8c8a80");cutlery_steel.metallic=.85;cutlery_steel.roughness=.38
 var mesh:=MeshInstance3D.new();mesh.name="TableKnife" if knife else "TableFork";mesh.mesh=knife_mesh() if knife else fork_mesh()
 mesh.material_override=cutlery_steel;mesh.position=p;mesh.rotation.y=yaw;parent.add_child(mesh);return mesh

# A baked bread roll: flat-bottomed, domed, with a scored crust and flour.
static func roll_mesh() -> ArrayMesh:
 if roll_geometry:return roll_geometry
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows:=14;var cols:=28;var grid: Array=[]
 for r in range(rows+1):
  var v:=PI*r/rows;var line: Array=[]
  for c in range(cols+1):
   var u:=TAU*c/cols
   var p:=Vector3(sin(v)*cos(u)*.062,cos(v)*.044,sin(v)*sin(u)*.047)
   if p.y<0:p.y*=.32
   var score:=exp(-pow(p.z/.0075,2))*smoothstep(.01,.04,p.y)
   p.y-=score*.0075
   p+=p.normalized()*.0018*sin(u*7+v*5)
   var top:=clampf(p.y/.044,0,1)
   var colour:=Color("a8743a").lerp(Color("5e3413"),top*.9)
   colour=colour.lerp(Color("e3d3b0"),score*.8)
   line.append([p,colour])
  grid.append(line)
 for r in range(rows):
  for c in range(cols):
   var quad:=[grid[r][c],grid[r+1][c],grid[r+1][c+1],grid[r][c+1]]
   for i in [0,1,2,0,2,3]:st.set_color(quad[i][1]);st.add_vertex(quad[i][0])
 roll_geometry=_commit(st);return roll_geometry

static func roll(w: PlayWorld,parent: Node3D,p: Vector3,yaw: float) -> MeshInstance3D:
 if not crust:
  crust=StandardMaterial3D.new();crust.vertex_color_use_as_albedo=true;crust.roughness=.86
  crust.normal_enabled=true;crust.normal_texture=w.atmosphere.micro_normal;crust.normal_scale=.35
 var mesh:=MeshInstance3D.new();mesh.name="BakedBreadRoll";mesh.mesh=roll_mesh();mesh.material_override=crust
 mesh.position=p;mesh.rotation.y=yaw;parent.add_child(mesh);return mesh

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
