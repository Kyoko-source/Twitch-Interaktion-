class_name SurfaceDetails
extends RefCounted

# Real single-sided inner and outer surfaces, rather than an uncapped primitive.
static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
 var vertices: Array=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
 for p in vertices:
  st.set_normal(normal);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)

static func vessel(parent: Node3D, base: Vector3, height: float, top: float, bottom: float, thickness: float, outside: Material, inside: Material, label: String) -> Node3D:
 var root:=Node3D.new();root.name=label;root.position=base;parent.add_child(root)
 for inner in [false,true]:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var y0: float=thickness if inner else 0.0
  var r0: float=bottom-thickness if inner else bottom
  var r1: float=top-thickness if inner else top
  for i in range(64):
   var a:=i*TAU/64;var b:=(i+1)*TAU/64
   var aa:=Vector3(cos(a)*r0,y0,sin(a)*r0);var ab:=Vector3(cos(b)*r0,y0,sin(b)*r0)
   var ba:=Vector3(cos(a)*r1,height,sin(a)*r1);var bb:=Vector3(cos(b)*r1,height,sin(b)*r1)
   var normal:=Vector3(cos((a+b)*.5),(r0-r1)/(height-y0),sin((a+b)*.5)).normalized()*(-1.0 if inner else 1.0)
   triangle(st,aa,ba,bb,normal);triangle(st,aa,bb,ab,normal)
   triangle(st,Vector3(0,y0,0),aa,ab,Vector3.UP if inner else Vector3.DOWN)
   if inner:
    var oa:=Vector3(cos(a)*top,height,sin(a)*top);var ob:=Vector3(cos(b)*top,height,sin(b)*top)
    triangle(st,ba,oa,ob,Vector3.UP);triangle(st,ba,ob,bb,Vector3.UP)
  var mesh:=MeshInstance3D.new();mesh.name="Interior" if inner else "Exterior";mesh.mesh=st.commit();mesh.material_override=inside if inner else outside;root.add_child(mesh)
 return root

static func sink(w: PlayWorld, parent: Node3D, steel: Material) -> void:
 var root:=Node3D.new();root.name="RecessedKitchenSink";root.position=Vector3(-16.63,0,-16.65);parent.add_child(root)
 var grime:=w.mat(Color("454d41"),load("res://assets/aged-plaster.png"),.86,.45);grime.uv1_triplanar=true;grime.uv1_scale=Vector3.ONE*4
 # Rounded rectangle rings descend inward to a recessed drain, with a thick rim.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings: Array[Vector3]=[Vector3(.42,1.08,.49),Vector3(.385,1.065,.455),Vector3(.34,.89,.41),Vector3(.27,.85,.34)]
 var points: Array[PackedVector3Array]=[]
 for ring in rings:
  var row:=PackedVector3Array()
  for i in range(64):
   var a:=i*TAU/64;var c:=cos(a);var s:=sin(a)
   row.append(Vector3(signf(c)*pow(absf(c),.35)*ring.x,ring.y,signf(s)*pow(absf(s),.35)*ring.z))
  points.append(row)
 for r in range(3):
  for i in range(64):
   var j: int=(i+1)%64;var a: Vector3=points[r][i];var b: Vector3=points[r][j];var c: Vector3=points[r+1][j];var d: Vector3=points[r+1][i]
   var normal: Vector3=(b-a).cross(d-a).normalized()
   if normal.dot(Vector3(-a.x,.3,-a.z))<0: normal=-normal
   triangle(st,a,b,c,normal);triangle(st,a,c,d,normal)
 for i in range(64): triangle(st,Vector3(0,.85,0),points[3][i],points[3][(i+1)%64],Vector3.UP)
 var bowl:=MeshInstance3D.new();bowl.name="SinkBowl";bowl.mesh=st.commit();bowl.material_override=grime;root.add_child(bowl)
 w.tube(root,Vector3(0,.851,0),Vector3(0,.855,0),.048,w.materials.dark)
 for i in range(5): w.tube(root,Vector3(-.033+i*.016,.856,-.032),Vector3(-.033+i*.016,.856,.032),.003,steel)
 # Vertical supply, a swan-neck in one plane, and a downward-facing open spout.
 var mount:=Vector3(-.45,1.08,0)
 w.tube(root,mount,mount+Vector3(0,.35,0),.023,steel)
 w.tube(root,mount,mount+Vector3(0,.035,0),.047,steel)
 for i in range(20):
  var a:=PI-i*PI/20;var b:=PI-(i+1)*PI/20
  w.tube(root,Vector3(-.29+cos(a)*.16,1.43+sin(a)*.16,0),Vector3(-.29+cos(b)*.16,1.43+sin(b)*.16,0),.022,steel)
 w.tube(root,Vector3(-.13,1.43,0),Vector3(-.13,1.31,0),.023,steel)
 w.tube(root,Vector3(-.13,1.309,0),Vector3(-.13,1.313,0),.017,w.materials.dark)
 for side in [-1,1]:
  var p:=mount+Vector3(0,.055,side*.14)
  w.tube(root,p-Vector3(0,.025,0),p+Vector3(0,.045,0),.026,steel)
  w.tube(root,p+Vector3(-.048,.045,0),p+Vector3(.048,.045,0),.012,steel)
