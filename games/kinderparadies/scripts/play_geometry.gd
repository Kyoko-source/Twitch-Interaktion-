class_name PlayGeometry
extends RefCounted

# Every net uses these same apertures for its ropes, padded edges and collision.
# u is z on an x-facing panel and x on a z-facing panel; v is always height.
static func point(axis: String, fixed: float, u: float, v: float) -> Vector3:
 return Vector3(fixed,v,u) if axis=="x" else Vector3(u,v,fixed)

static func segments(low: float, high: float, cuts: Array[Vector2]) -> Array[Vector2]:
 var result: Array[Vector2]=[Vector2(low,high)]
 for cut in cuts:
  var next: Array[Vector2]=[]
  for interval in result:
   if cut.y<=interval.x or cut.x>=interval.y: next.append(interval);continue
   if cut.x>interval.x: next.append(Vector2(interval.x,minf(cut.x,interval.y)))
   if cut.y<interval.y: next.append(Vector2(maxf(cut.y,interval.x),interval.y))
  result=next
 return result

static func strand(transforms: Array[Transform3D], a: Vector3, b: Vector3) -> void:
 var direction:=b-a
 if direction.length()<.01: return
 transforms.append(Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized()))*Basis.from_scale(Vector3(1,direction.length(),1)),(a+b)*.5))

static func panel(w: PlayWorld, parent: Node3D, name: String, axis: String, fixed: float, area: Rect2, holes: Array[Rect2]=[]) -> Node3D:
 var root:=Node3D.new();root.name=name;parent.add_child(root);root.add_to_group("safety_nets")
 root.set_meta("net_axis",axis);root.set_meta("net_fixed",fixed);root.set_meta("net_area",area);root.set_meta("net_holes",holes)
 var transforms: Array[Transform3D]=[]
 for row in range(ceili(area.size.y/.16)+1):
  var v:=minf(area.position.y+row*.16,area.end.y);var cuts: Array[Vector2]=[]
  for hole in holes:
   if v>hole.position.y and v<hole.end.y: cuts.append(Vector2(hole.position.x,hole.end.x))
  for segment in segments(area.position.x,area.end.x,cuts): strand(transforms,point(axis,fixed,segment.x,v),point(axis,fixed,segment.y,v))
 for col in range(ceili(area.size.x/.16)+1):
  var u:=minf(area.position.x+col*.16,area.end.x);var cuts: Array[Vector2]=[]
  for hole in holes:
   if u>hole.position.x and u<hole.end.x: cuts.append(Vector2(hole.position.y,hole.end.y))
  for segment in segments(area.position.y,area.end.y,cuts): strand(transforms,point(axis,fixed,u,segment.x),point(axis,fixed,u,segment.y))
 var ropes:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
 var rope:=CylinderMesh.new();rope.height=1;rope.top_radius=.009;rope.bottom_radius=.009;rope.radial_segments=6;mm.mesh=rope;mm.instance_count=transforms.size()
 for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
 ropes.multimesh=mm;ropes.material_override=w.materials.stitch;ropes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(ropes)
 # Rectangular subdivision excludes the apertures from physical barriers too.
 var us: Array[float]=[area.position.x,area.end.x];var vs: Array[float]=[area.position.y,area.end.y]
 for hole in holes:
  for u in [hole.position.x,hole.end.x]:
   var value:=clampf(u,area.position.x,area.end.x)
   if value not in us: us.append(value)
  for v in [hole.position.y,hole.end.y]:
   var value:=clampf(v,area.position.y,area.end.y)
   if value not in vs: vs.append(value)
 us.sort();vs.sort()
 for x in range(us.size()-1):
  for y in range(vs.size()-1):
   var rect:=Rect2(Vector2(us[x],vs[y]),Vector2(us[x+1]-us[x],vs[y+1]-vs[y]));var open:=false
   for hole in holes:
    if hole.has_point(rect.get_center()): open=true
   if open or rect.size.x<.001 or rect.size.y<.001: continue
   var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new()
   shape.size=Vector3(.04,rect.size.y,rect.size.x) if axis=="x" else Vector3(rect.size.x,rect.size.y,.04)
   collider.shape=shape;body.position=point(axis,fixed,rect.get_center().x,rect.get_center().y);body.add_child(collider);root.add_child(body)
 for hole in holes:
  var clipped:=hole.intersection(area)
  for side in [0,1]:
   var u: float=clipped.position.x+side*clipped.size.x;var v: float=clipped.position.y+side*clipped.size.y
   w.tube(root,point(axis,fixed,u,clipped.position.y),point(axis,fixed,u,clipped.end.y),.065,w.materials.gold)
   if side==1 or hole.position.y>area.position.y+.01:
    w.tube(root,point(axis,fixed,clipped.position.x,v),point(axis,fixed,clipped.end.x,v),.065,w.materials.gold)
 return root

static func west_nets(w: PlayWorld, root: Node3D) -> void:
 panel(w,root,"WestEntryNet","x",-.32,Rect2(-5.5,.3,9.3,4.2),[Rect2(-1.7,.28,1.4,1.85)])
 panel(w,root,"BridgeEntryNet","x",5.52,Rect2(-5.5,.3,9.3,4.2),[Rect2(2.6,2.15,1.2,2.3)])
 panel(w,root,"RearNet","z",-5.52,Rect2(-.3,.3,5.8,4.2))
 panel(w,root,"SlideExitNet","z",3.82,Rect2(-.3,.3,5.8,4.2),[Rect2(2.85,.28,1.65,4.17)])

static func arch(w: PlayWorld, root: Node3D, z: float) -> void:
 var node:=Node3D.new();root.add_child(node)
 var points: Array[Vector3]=[Vector3(.3,2.29,z),Vector3(.3,3.5,z)]
 for i in range(1,17):
  var a:=PI-i*PI/16;points.append(Vector3(1.1+cos(a)*.8,3.5+sin(a)*.8,z))
 points.append(Vector3(1.9,2.29,z))
 for p in points:
  var joint:=w.sphere(node,p,.11,w.materials.teal);joint.set_meta("play_obstacle",true)
 for i in range(points.size()-1):
  var mesh:=w.tube(node,points[i],points[i+1],.11,w.materials.teal);mesh.set_meta("play_obstacle",true)
  var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();var direction:=points[i+1]-points[i]
  shape.radius=.11;shape.height=direction.length()+.22;collider.shape=shape;body.position=(points[i]+points[i+1])*.5;body.quaternion=Quaternion(Vector3.UP,direction.normalized());body.add_child(collider);node.add_child(body)

static func entry_ramp(w: PlayWorld, root: Node3D) -> MeshInstance3D:
 # A flat landing crosses the net plane. The old tilted box left the capsule
 # below the deck when walking out, so floor snapping caught the edge repeatedly.
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var profile: Array[Vector2]=[Vector2(-1.65,-.018),Vector2(-.55,.305),Vector2(.35,.305)]
 for i in range(2):
  var a:=Vector3(profile[i].x,profile[i].y,-1.67);var b:=Vector3(profile[i].x,profile[i].y,-.33)
  var c:=Vector3(profile[i+1].x,profile[i+1].y,-1.67);var d:=Vector3(profile[i+1].x,profile[i+1].y,-.33)
  triangle(tool,a,c,b,true);triangle(tool,c,d,b,true)
  for z in [-1.67,-.33]:
   var p:=Vector3(a.x,a.y,z);var q:=Vector3(c.x,c.y,z)
   triangle(tool,p,Vector3(p.x,-.06,z),q,z< -1);triangle(tool,q,Vector3(p.x,-.06,z),Vector3(q.x,-.06,z),z< -1)
 tool.generate_normals();var mesh:=MeshInstance3D.new();mesh.name="ContinuousEntryRamp";mesh.mesh=tool.commit();mesh.material_override=w.materials.red;root.add_child(mesh);mesh.create_trimesh_collision()
 return mesh

static func slide_height(t: float) -> float:
 return lerpf(2.29,.54,smoothstep(0,1,t))

static func solid_obstacle(mesh: MeshInstance3D, shape: Shape3D) -> void:
 # Inherit the visual's exact pose, including the enlarged parent frame.
 var body:=StaticBody3D.new();body.add_to_group("padded_obstacles")
 var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);mesh.add_child(body)
 mesh.set_meta("play_obstacle",true)

static func slide(w: PlayWorld, root: Node3D) -> void:
 var top:=SurfaceTool.new();top.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cross: Array[Vector2]=[Vector2(-.72,.22),Vector2(-.68,.13),Vector2(-.59,.025),Vector2(-.4,.004),Vector2(0,0),Vector2(.4,.004),Vector2(.59,.025),Vector2(.68,.13),Vector2(.72,.22)]
 for lower in [false,true]:
  for row in range(40):
   for col in range(cross.size()-1):
    var corners: Array[Vector2i]=[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
    if lower: corners.reverse()
    for corner in corners:
     var t: float=(row+corner.y)/40.0;var p:=cross[col+corner.x]
     top.set_uv(Vector2((p.x+.72)/1.44,t*3));top.add_vertex(Vector3(3.65+p.x,slide_height(t)+p.y-(.075 if lower else 0),.8+t*5.6))
 # Close the shell along both lips and ends; it is a thick moulding, not a sheet.
 for row in range(40):
  for edge in [0,cross.size()-1]:
   var t: float=row/40.0;var nt: float=(row+1)/40.0;var p:=cross[edge]
   var a:=Vector3(3.65+p.x,slide_height(t)+p.y,.8+t*5.6);var b:=Vector3(3.65+p.x,slide_height(nt)+p.y,.8+nt*5.6)
   triangle(top,a,b,a-Vector3.UP*.075,edge==0);triangle(top,b,b-Vector3.UP*.075,a-Vector3.UP*.075,edge==0)
 for end in [0,1]:
  for col in range(cross.size()-1):
   var p:=cross[col];var q:=cross[col+1];var a:=Vector3(3.65+p.x,slide_height(end)+p.y,.8+end*5.6);var b:=Vector3(3.65+q.x,slide_height(end)+q.y,.8+end*5.6)
   triangle(top,a,b,a-Vector3.UP*.075,end==1);triangle(top,b,b-Vector3.UP*.075,a-Vector3.UP*.075,end==1)
 top.generate_normals();var mesh:=MeshInstance3D.new();mesh.name="MouldedSlide";mesh.mesh=top.commit();mesh.material_override=w.materials.red;mesh.set_meta("play_obstacle",true);root.add_child(mesh)
 mesh.create_trimesh_collision()
 for t in [.17,.52,.88]:
  for side in [-1,1]: w.tube(root,Vector3(3.65+side*.53,.1,.8+t*5.6),Vector3(3.65+side*.53,slide_height(t)-.075,.8+t*5.6),.045,w.materials.metal)

static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, reverse: bool=false) -> void:
 var points: Array[Vector3]=[a,b,c]
 if not reverse: points.reverse()
 for p in points: tool.set_uv(Vector2(p.x*.7,p.z*.5));tool.add_vertex(p)

static func bridge_height(t: float) -> float:
 return lerpf(2.977,2.15,t)-sin(t*PI)*.15

static func bridge_collision(parent: Node3D) -> void:
 var faces:=PackedVector3Array()
 for i in range(40):
  var t: float=i/40.0;var nt: float=(i+1)/40.0
  var a:=Vector3(lerpf(4.43,10.5,t),bridge_height(t),3);var b:=Vector3(a.x,a.y,4.2)
  var c:=Vector3(lerpf(4.43,10.5,nt),bridge_height(nt),3);var d:=Vector3(c.x,c.y,4.2)
  faces.append_array(PackedVector3Array([a,c,b,c,d,b]))
 var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);collider.shape=shape;body.add_child(collider);parent.add_child(body)
