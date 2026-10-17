class_name SceneAudit
extends RefCounted

# QA-only callers: inspect actual mesh bounds and imported vertices, not merely
# intended constants. A normal round must have no accidental geometry anomaly.
static func inspect(w: PlayWorld) -> Dictionary:
 var walls: Array[AABB]=[];var mounted:=0;var text_count:=0
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("architecture_wall"): walls.append(mesh.global_transform*mesh.get_aabb())
  if mesh.has_meta("mounted_art"): mounted+=1
 for label in w.find_children("*","Label3D",true,false):
  if label.is_visible_in_tree(): text_count+=1
 var intersections: Array[String]=[]
 for branch in [w.props.structure,w.props.nets,w.props.slide,w.playground.get_node("EastTower"),w.playground.get_node("ConnectingBridge")]:
  for mesh in branch.find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree(): continue
   var bounds: AABB=mesh.global_transform*mesh.get_aabb()
   for wall in walls:
    if bounds.intersects(wall): intersections.append(str(mesh.get_path()))
 var minimum:=100.0
 # Godot's headless dummy renderer returns identity for every MultiMesh getter.
 # CPU checks inspect the exact submitted transforms; GPU/Web QA reads them back.
 var headless:=DisplayServer.get_name()=="headless"
 for i in range(w.balls.multimesh.instance_count):
  var point: Vector3=w.ball_render_transforms[i].origin if headless else w.balls.multimesh.get_instance_transform(i).origin
  for j in range(i):
   var other: Vector3=w.ball_render_transforms[j].origin if headless else w.balls.multimesh.get_instance_transform(j).origin
   minimum=minf(minimum,point.distance_to(other))
 var chair_back_dot:=1.0
 for chair in w.props.chairs.get_children():
  var away: Vector3=Vector3(chair.position.x-8.5,0,0).normalized()
  chair_back_dot=minf(chair_back_dot,chair.global_basis.z.dot(away))
  # Source chair back is verified from the actual imported mesh's upper vertices.
  for mesh in chair.find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree() or mesh.mesh.get_surface_count()==0: continue
   if not mesh.mesh is ArrayMesh or mesh.get_meta("native_model","")!="SchoolChair_01": continue
   var center:=Vector3.ZERO;var count:=0;var bounds: AABB=mesh.get_aabb()
   for surface in range(mesh.mesh.get_surface_count()):
    var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for point in vertices:
     if point.y>bounds.position.y+bounds.size.y*.7: center+=mesh.to_global(point);count+=1
   if count>0:
    var back: Vector3=center/count-chair.global_position;back.y=0
    chair_back_dot=minf(chair_back_dot,back.normalized().dot(away))
 var net_intrusions: Array[String]=[]
 var nets: Array[Node]=[]
 for net in w.get_tree().get_nodes_in_group("safety_nets"):
  if w.is_ancestor_of(net): nets.append(net)
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.has_meta("play_obstacle"): continue
  for net in nets:
   var bounds: AABB=(net.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
   var axis: String=net.get_meta("net_axis");var fixed: float=net.get_meta("net_fixed");var dimension:=0 if axis=="x" else 2
   if bounds.position[dimension]>=fixed-.005 or bounds.end[dimension]<=fixed+.005: continue
   var rect:=Rect2(Vector2(bounds.position.z if axis=="x" else bounds.position.x,bounds.position.y),Vector2(bounds.size.z if axis=="x" else bounds.size.x,bounds.size.y))
   rect=rect.intersection(net.get_meta("net_area"))
   if not rect.has_area(): continue
   var allowed:=false
   for hole in net.get_meta("net_holes"):
    if hole.grow(.01).encloses(rect): allowed=true
   if not allowed: net_intrusions.append(str(mesh.get_path())+" through "+str(net.name))
 return {"wall_intersections":intersections,"net_intrusions":net_intrusions,"net_panels":nets.size(),"wall_paintings":w.props.wall_paintings.get_child_count(),"ball_min_distance":minimum,"ball_source":"cpu_submission" if headless else "renderer","chair_back_dot":chair_back_dot,"mounted_art":mounted,"floating_labels":text_count}
