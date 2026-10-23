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
 for branch in [w.props.structure,w.props.nets,w.props.slide,w.playground.get_node("EastTower"),w.playground.get_node("ConnectingBridge"),w.tubes]:
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
 var layout:=placement(w)
 return {"wall_intersections":intersections,"net_intrusions":net_intrusions,"net_panels":nets.size(),"wall_paintings":w.props.wall_paintings.get_child_count(),"ball_min_distance":minimum,"ball_source":"cpu_submission" if headless else "renderer","chair_back_dot":chair_back_dot,"mounted_art":mounted,"floating_labels":text_count,"door_obstructions":layout.doors,"art_overlaps":layout.art,"furniture_wall_intrusions":layout.furniture}

static func placement(w: PlayWorld) -> Dictionary:
 # Actual visible mesh bounds, including purely decorative geometry. Floors,
 # door frames and the interactive door leaves sit outside these swept volumes.
 var passages: Array[Dictionary]=[
  {"name":"Party Raum","box":AABB(Vector3(6.39,.09,-9.43),Vector3(.82,2.25,1.46))},
  {"name":"Wartungsraum","box":AABB(Vector3(-10.62,.09,-6.12),Vector3(.84,2.25,1.44))},
  {"name":"Küche","box":AABB(Vector3(-9.81,.09,-18.40),Vector3(.82,2.25,1.50))},
  {"name":"Kino","box":AABB(Vector3(-6.81,.09,-18.40),Vector3(.82,2.25,1.50))},
  {"name":"Nebenraum-Flur","box":AABB(Vector3(-9.0,.09,-12.64),Vector3(2.2,2.25,.88))},
  {"name":"Fahrstuhl","box":AABB(Vector3(-9.12,.09,16.76),Vector3(2.24,2.25,.88))},
  {"name":"Archiv-Vorbereich","box":AABB(Vector3(-9.75,.09,-10.5),Vector3(1.0,2.25,1.2))},
  {"name":"Grüne Tür","box":AABB(Vector3(-4.95,.09,-11.52),Vector3(1.3,2.25,1.2))},
  {"name":"Rote Tür","box":AABB(Vector3(-2.80,.09,-11.52),Vector3(1.3,2.25,1.2))}]
 if w.archive.leaf.rotation.y< -1.5: passages.append({"name":"Offene Archivtür","box":AABB(Vector3(-10.62,.09,-10.58),Vector3(.84,2.25,1.36))})
 var blocked: Array[String]=[];var art: Array[MeshInstance3D]=[];var furniture: Array[String]=[];var walls: Array[AABB]=[]
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("architecture_wall"): walls.append(mesh.global_transform*mesh.get_aabb())
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree() or mesh.has_meta("nonblocking_atmosphere"): continue
  var bounds: AABB=mesh.global_transform*mesh.get_aabb()
  for passage in passages:
   if bounds.intersects(passage.box): blocked.append(passage.name+": "+str(mesh.get_path())+" at "+str(bounds))
  var furnishing: bool=mesh.get_meta("native_model","")=="cardboard_box_01"
  var cursor: Node=mesh.get_parent()
  while cursor!=null and cursor!=w:
   if cursor in [w.props.counter,w.props.party_table,w.props.chairs] or str(cursor.name) in ["StockedShelf","PartySideboard","ProjectionWorktable","GroundedRepairBench","MountedServerRack"]: furnishing=true;break
   cursor=cursor.get_parent()
  if furnishing:
   for wall in walls:
    var overlap:=bounds.intersection(wall)
    if overlap.size.x>.035 and overlap.size.y>.06 and overlap.size.z>.035: furniture.append(str(mesh.get_path())+" at "+str(bounds))
  if mesh.has_meta("mounted_art") or mesh.get_parent()==w.props.wall_paintings or (mesh.get_parent().name=="TheFourEmptyChairs" and mesh.mesh is QuadMesh): art.append(mesh)
 var overlaps: Array[String]=[]
 for i in range(art.size()):
  var a:=art[i];var local_a:=a.get_aabb();var rect_a:=Rect2(Vector2(local_a.position.x,local_a.position.y),Vector2(local_a.size.x,local_a.size.y)).grow(.055)
  if rect_a.size.x<.2 or rect_a.size.y<.2: continue
  for j in range(i):
   var b:=art[j]
   if a.global_basis.z.normalized().dot(b.global_basis.z.normalized())<.99: continue
   var projected: AABB=(a.global_transform.affine_inverse()*b.global_transform)*b.get_aabb()
   if absf(projected.get_center().z)>.13: continue
   var rect_b:=Rect2(Vector2(projected.position.x,projected.position.y),Vector2(projected.size.x,projected.size.y)).grow(.055)
   if rect_b.size.x<.2 or rect_b.size.y<.2: continue
   var overlap:=rect_a.intersection(rect_b)
   if overlap.size.x>.035 and overlap.size.y>.035: overlaps.append(str(a.get_path())+" + "+str(b.get_path()))
 return {"doors":blocked,"art":overlaps,"furniture":furniture}
