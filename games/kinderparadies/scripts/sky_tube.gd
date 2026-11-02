class_name SkyTube
extends Node3D

# A continuous centreline drives the shell, floor, windows, collision and saves.
const HEIGHT:=4.87
const FLOOR:=4.15
const INNER:=.85
const OUTER:=.93
var points:=PackedVector3Array()
var lengths:=PackedFloat32Array()
var length:=0.0
var w: PlayWorld
var window_count:=0

func append_point(x: float,z: float) -> void:
 var p:=Vector3(x,HEIGHT,z)
 if not points.is_empty():length+=p.distance_to(points[-1])
 points.append(p);lengths.append(length)

func line(a: Vector2,b: Vector2) -> void:
 var steps:=ceili(a.distance_to(b)/.19)
 for i in range(steps+1):
  var p:=a.lerp(b,float(i)/steps)
  if not points.is_empty() and points[-1].distance_to(Vector3(p.x,HEIGHT,p.y))<.001:continue
  append_point(p.x,p.y)

func arc(center: Vector2,a: float,b: float) -> void:
 for i in range(1,19):
  var angle:=lerpf(a,b,i/18.0);var p:=center+Vector2(cos(angle),sin(angle))*1.5
  append_point(p.x,p.y)

func route(s: float) -> Vector3:
 s=clampf(s,0,length)
 for i in range(1,points.size()):
  if lengths[i]>=s:return points[i-1].lerp(points[i],(s-lengths[i-1])/maxf(.001,lengths[i]-lengths[i-1]))
 return points[-1]

func tangent(s: float) -> Vector3:
 s=clampf(s,0,length)
 return (route(minf(length,s+.035))-route(maxf(0,s-.035))).normalized()

func nearest(p: Vector3) -> Dictionary:
 var best:=INF;var distance:=0.0
 for i in range(1,points.size()):
  var a:=Vector2(points[i-1].x,points[i-1].z);var b:=Vector2(points[i].x,points[i].z);var q:=Vector2(p.x,p.z)
  var t:=clampf((q-a).dot(b-a)/(b-a).length_squared(),0,1);var d:=q.distance_to(a.lerp(b,t))
  if d<best:best=d;distance=lerpf(lengths[i-1],lengths[i],t)
 return {"distance":best,"s":distance}

func contains(p: Vector3) -> bool:
 if absf(p.y-FLOOR)>.42:return false
 var n:=nearest(p)
 return n.distance<.79 and n.s>.10 and n.s<length-.10

func near_entry(p: Vector3) -> bool:
 if absf(p.y-FLOOR)>.8:return false
 for s in [0.0,length]:
  if Vector2(p.x-route(s).x,p.z-route(s).z).length()<1.5:return true
 return false

func surface(s: float,a: float,r: float) -> Vector3:
 return route(s)+Vector3.UP.cross(tangent(s))*cos(a)*r+Vector3.UP*sin(a)*r

static func quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3) -> void:
 for vertices in [[a,b,c],[c,b,d]]:
  if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(n)>0:vertices.reverse()
  for p: Vector3 in vertices:tool.set_normal(n);tool.set_uv(Vector2(p.x*.8+p.z*.3,p.y));tool.add_vertex(p)

func finish(tool: SurfaceTool,id: String,material: Material,solid: bool=true) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.name=id;mesh.mesh=tool.commit();mesh.material_override=material;add_child(mesh)
 if solid:
  mesh.create_trimesh_collision()
  for collider in mesh.find_children("*","CollisionShape3D",true,false):(collider.shape as ConcavePolygonShape3D).backface_collision=true
 return mesh

func build(world: PlayWorld) -> void:
 w=world;name="PartySkyTube";set_meta("foot_surface","plastic")
 line(Vector2(3.75,-4.5),Vector2(8.4,-4.5));arc(Vector2(8.4,-3),-PI/2,0)
 line(Vector2(9.9,-3),Vector2(9.9,-1.5));arc(Vector2(11.4,-1.5),PI,PI/2)
 line(Vector2(11.4,0),Vector2(14.55,0));arc(Vector2(14.55,1.5),-PI/2,0)
 line(Vector2(16.05,1.5),Vector2(16.05,3.25))
 var tools: Array[SurfaceTool]=[]
 for i in range(6):var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tools.append(tool)
 for i in range(points.size()-1):
  var s: float=lengths[i];var ns: float=lengths[i+1];var mid: float=(s+ns)*.5
  var window:=fmod(mid,3.0)>.55 and fmod(mid,3.0)<2.45 and mid>.65 and mid<length-.65
  for j in range(40):
   var a:=j*TAU/40;var b: float=(j+1)*TAU/40;var angle: float=(a+b)*.5
   var glazed:=window and sin(angle)>-.35
   var index:=4 if glazed else int(mid/3.0)%4
   for radius in ([OUTER-.035] if glazed else [INNER,OUTER]):
    var n: Vector3=(surface(mid,angle,1)-route(mid))*(-1 if radius==INNER else 1)
    quad(tools[index],surface(s,a,radius),surface(ns,a,radius),surface(s,b,radius),surface(ns,b,radius),n)
  var left: Vector3=Vector3.UP.cross(tangent(s))*.43;var right: Vector3=Vector3.UP.cross(tangent(ns))*.43
  var p:=route(s);var q:=route(ns);p.y=FLOOR;q.y=FLOOR
  quad(tools[5],p-left,p+left,q-right,q+right,Vector3.UP)
 var colors: Array[Color]=[Color("526d65"),Color("9c874b"),Color("7c4940"),Color("3e586d")]
 for i in range(4):
  var pvc:=w.mat(colors[i],load("res://assets/vinyl.png"),.55);pvc.uv1_triplanar=true;pvc.normal_enabled=true;pvc.normal_texture=w.atmosphere.micro_normal;pvc.normal_scale=.2
  finish(tools[i],"WeatheredPVCShell"+str(i),pvc)
 var glass:=ShaderMaterial.new();glass.shader=load("res://assets/climbing-v370/scratched_polycarbonate.gdshader")
 var windows:=finish(tools[4],"ScratchedTransparentBays",glass);windows.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 finish(tools[5],"UnbrokenMouldedWalkway",w.mat(Color("575b4b"),load("res://assets/vinyl.png"),.82))
 var rings: Array[Transform3D]=[];var bolts: Array[Transform3D]=[];var stains: Array[Transform3D]=[]
 for k in range(ceili(length/1.5)+1):
  var s:=minf(length,k*1.5)
  for j in range(40):
   PlayGeometry.strand(rings,surface(s,j*TAU/40,OUTER+.025),surface(s,(j+1)*TAU/40,OUTER+.025))
   if j%5==0:bolts.append(Transform3D(Basis.IDENTITY,surface(s,j*TAU/40,OUTER+.055)))
  if k%2==1:window_count+=1
  # Dirt follows the lower flange and does not obscure the view through a pane.
  for j in range(15):PlayGeometry.strand(stains,surface(s-.045,j*PI/14+PI,OUTER+.005),surface(s+.045,j*PI/14+PI,OUTER+.005))
 instances(rings,cylinder(.035),w.materials.cream,"YellowedBoltedFlanges")
 var bolt:=SphereMesh.new();bolt.radius=.019;bolt.height=.038;bolt.radial_segments=8;bolt.rings=4
 instances(bolts,bolt,w.materials.rust,"RustyFasteners")
 instances(stains,cylinder(.025),w.mat(Color("373f2e"),null,.99),"SeamResidue")
 # Suspended cradles carry the tube at real room ceiling anchors.
 for s in [3.0,7.5,12.0,16.5]:
  if s>=length:continue
  for side in [-1,1]:
   var p:=surface(s,0 if side==1 else PI,OUTER+.03)
   w.tube(self,p,Vector3(p.x,7.15,p.z),.016,w.materials.rust)
   w.box(self,Vector3(p.x,7.17,p.z),Vector3(.2,.055,.2),w.materials.dark)

func cylinder(radius: float) -> CylinderMesh:
 var mesh:=CylinderMesh.new();mesh.height=1;mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.radial_segments=8;return mesh

func instances(poses: Array[Transform3D],mesh: Mesh,material: Material,id: String) -> void:
 var batch:=MultiMeshInstance3D.new();batch.name=id;var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=poses.size()
 for i in range(poses.size()):mm.set_instance_transform(i,poses[i])
 batch.multimesh=mm;batch.material_override=material;add_child(batch)
