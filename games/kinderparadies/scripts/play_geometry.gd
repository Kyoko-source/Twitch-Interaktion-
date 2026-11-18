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
   if v>=hole.position.y and v<=hole.end.y: cuts.append(Vector2(hole.position.x,hole.end.x))
  for segment in segments(area.position.x,area.end.x,cuts): strand(transforms,point(axis,fixed,segment.x,v),point(axis,fixed,segment.y,v))
 for col in range(ceili(area.size.x/.16)+1):
  var u:=minf(area.position.x+col*.16,area.end.x);var cuts: Array[Vector2]=[]
  for hole in holes:
   if u>=hole.position.x and u<=hole.end.x: cuts.append(Vector2(hole.position.y,hole.end.y))
  for segment in segments(area.position.y,area.end.y,cuts): strand(transforms,point(axis,fixed,u,segment.x),point(axis,fixed,u,segment.y))
 knotted_net(root,axis,fixed,area,holes)
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
   # Openings have side padding and a lintel, without a trip bar at the feet.
   if side==1:w.tube(root,point(axis,fixed,clipped.position.x,v),point(axis,fixed,clipped.end.x,v),.065,w.materials.gold)
 return root

static func west_nets(w: PlayWorld, root: Node3D) -> void:
 panel(w,root,"WestEntryNet","x",-.32,Rect2(-5.5,.3,9.3,4.2),[Rect2(-1.7,.28,1.4,1.85)])
 panel(w,root,"BridgeEntryNet","x",5.52,Rect2(-5.5,.3,9.3,4.2),[Rect2(2.6,2.15,1.2,2.3),Rect2(-4.95,2.95,1.86,1.55)])
 panel(w,root,"RearNet","z",-5.52,Rect2(-.3,.3,5.8,4.2),[Rect2(2.6,3.14,2.9,1.36)])
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
 var profile: Array[Vector2]=[Vector2(-1.65,-.018),Vector2(-.55,.29),Vector2(.35,.29)]
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

# 4.11.0 knotted safety net: diagonal twisted rope in a diamond mesh, a knot at
# every crossing, a heavier border rope, and the gentle belly a real net has
# between its posts. Same apertures as the collision boxes above.
const MESH:=.17
const BELLY:=.035
static var rope_material: StandardMaterial3D
static func _rope_material() -> StandardMaterial3D:
 if rope_material:return rope_material
 var m:=StandardMaterial3D.new();m.resource_name="KnottedSafetyNetRope";m.albedo_color=Color("23262a");m.roughness=.78
 m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");m.normal_scale=.8
 m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*22.;m.specular_mode=BaseMaterial3D.SPECULAR_SCHLICK_GGX
 rope_material=m;return m

static func _clip(a: Vector2,b: Vector2,area: Rect2,holes: Array[Rect2]) -> Array[Vector2]:
 # Parameter intervals of segment a-b inside the area and outside every hole.
 var t0:=0.;var t1:=1.;var d:=b-a
 for axis in [0,1]:
  var lo:=area.position[axis];var hi:=area.end[axis]
  if absf(d[axis])<1e-6:
   if a[axis]<lo or a[axis]>hi:return []
  else:
   var ta:=(lo-a[axis])/d[axis];var tb:=(hi-a[axis])/d[axis]
   t0=maxf(t0,minf(ta,tb));t1=minf(t1,maxf(ta,tb))
 if t1<=t0:return []
 var keep: Array[Vector2]=[Vector2(t0,t1)]
 for hole in holes:
  var h0:=0.;var h1:=1.;var inside:=true
  for axis in [0,1]:
   var lo:=hole.position[axis];var hi:=hole.end[axis]
   if absf(d[axis])<1e-6:
    if a[axis]<lo or a[axis]>hi:inside=false
   else:
    var ta:=(lo-a[axis])/d[axis];var tb:=(hi-a[axis])/d[axis]
    h0=maxf(h0,minf(ta,tb));h1=minf(h1,maxf(ta,tb))
  if not inside or h1<=h0:continue
  keep=segments_of(keep,Vector2(h0,h1))
 return keep

static func segments_of(intervals: Array[Vector2],cut: Vector2) -> Array[Vector2]:
 var next: Array[Vector2]=[]
 for interval in intervals:
  if cut.y<=interval.x or cut.x>=interval.y:next.append(interval);continue
  if cut.x>interval.x:next.append(Vector2(interval.x,cut.x))
  if cut.y<interval.y:next.append(Vector2(cut.y,interval.y))
 return next

static func _bulge(axis: String,fixed: float,area: Rect2,p: Vector2) -> Vector3:
 var k:=sin(PI*clampf((p.x-area.position.x)/area.size.x,0,1))*sin(PI*clampf((p.y-area.position.y)/area.size.y,0,1))
 var at:=point(axis,fixed,p.x,p.y)
 if axis=="x":at.x+=BELLY*k
 else:at.z+=BELLY*k
 return at

static func _tube(st: SurfaceTool,points: Array[Vector3],radius: float) -> void:
 if points.size()<2:return
 var sides:=4
 var rings: Array=[]
 for i in range(points.size()):
  var forward:=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
  var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized();var up:=side.cross(forward)
  var ring: Array=[]
  for k in range(sides):
   var a:=TAU*k/sides+(i*.9)
   var n:=(side*cos(a)+up*sin(a)).normalized();ring.append([points[i]+n*radius,n])
  rings.append(ring)
 for i in range(rings.size()-1):
  for k in range(sides):
   var a: Array=rings[i][k];var b: Array=rings[i][(k+1)%sides];var c: Array=rings[i+1][(k+1)%sides];var e: Array=rings[i+1][k]
   for v in [a,b,c,a,c,e]:st.set_normal(v[1]);st.add_vertex(v[0])

static func _knot(st: SurfaceTool,at: Vector3,r: float) -> void:
 var axes:=[Vector3.RIGHT*r,Vector3.UP*r,Vector3.BACK*r*.8]
 var tips:=[at+axes[0],at-axes[0],at+axes[1],at-axes[1],at+axes[2],at-axes[2]]
 for f in [[0,2,4],[2,1,4],[1,3,4],[3,0,4],[2,0,5],[1,2,5],[3,1,5],[0,3,5]]:
  var n: Vector3=((tips[f[1]]-tips[f[0]]).cross(tips[f[2]]-tips[f[0]])).normalized()
  for i in f:st.set_normal(n);st.add_vertex(tips[i])

static func knotted_net(root: Node3D,axis: String,fixed: float,area: Rect2,holes: Array[Rect2]) -> void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var span:=area.size.x+area.size.y
 var origin:=area.position
 # Diagonals u-v=c and u+v=c across the panel, cut at its apertures.
 for dir in [1.,-1.]:
  var count:=int(ceil(span/MESH))+2
  for i in range(-count,count+1):
   var c:=i*MESH
   # Rising diagonals (u-v constant) and falling ones (u+v constant), long enough to span the panel.
   var start:=Vector2(origin.x+c-span,origin.y-span*dir)
   var end:=start+Vector2(span*2.,span*2.*dir)
   for interval in _clip(start,end,area,holes):
    var a2:=start.lerp(end,interval.x);var b2:=start.lerp(end,interval.y)
    var steps:=maxi(1,int(ceil(a2.distance_to(b2)/(MESH*.7))))
    var line: Array[Vector3]=[]
    for k in range(steps+1):line.append(_bulge(axis,fixed,area,a2.lerp(b2,float(k)/steps)))
    _tube(st,line,.0055)
 # Knots where the diagonals cross.
 var n:=int(ceil(span/MESH))+2
 for i in range(-n,n+1):
  for j in range(-n,n+1):
   var p:=origin+Vector2((i+j)*MESH*.5,(j-i)*MESH*.5)
   if not area.grow(-.01).has_point(p):continue
   var blocked:=false
   for hole in holes:
    if hole.grow(.01).has_point(p):blocked=true
   if not blocked:_knot(st,_bulge(axis,fixed,area,p),.012)
 # A heavier border rope along the panel edge.
 var corners:=[area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y),area.position]
 for k in range(4):
  for interval in _clip(corners[k],corners[k+1],area.grow(.001),holes):
   var a3:Vector2=corners[k].lerp(corners[k+1],interval.x);var b3:Vector2=corners[k].lerp(corners[k+1],interval.y)
   _tube(st,[point(axis,fixed,a3.x,a3.y),point(axis,fixed,b3.x,b3.y)] as Array[Vector3],.011)
 var mesh:=MeshInstance3D.new();mesh.name="KnottedSafetyNet";mesh.mesh=st.commit();mesh.material_override=_rope_material()
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;root.add_child(mesh)
