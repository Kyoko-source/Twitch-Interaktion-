class_name ZombiesNav
extends RefCounted

# Walkable floor grid for the horde (like the horse's), with a fast cell
# lookup and a local rebuild when a bought barrier comes down.
const CELL:=.5
const REGION:=Rect2i(-38,-74,96,112)
var graph:=AStarGrid2D.new()
var heights: Dictionary={}
var space: PhysicsDirectSpaceState3D
var shape:=CapsuleShape3D.new()
var query:=PhysicsShapeQueryParameters3D.new()
var exclude: Array[RID]=[]

func build(world_space: PhysicsDirectSpaceState3D, skip: Array[RID]) -> void:
	space=world_space;exclude=skip
	graph.region=REGION;graph.cell_size=Vector2.ONE*CELL;graph.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;graph.update()
	graph.fill_solid_region(REGION,true)
	shape.radius=.3;shape.height=1.4;query.shape=shape;query.collision_mask=1;query.margin=.002;query.exclude=exclude
	for y in range(REGION.position.y,REGION.end.y):
		for x in range(REGION.position.x,REGION.end.x):
			_probe(Vector2i(x,y))

func _probe(id: Vector2i) -> void:
	var p:=Vector3((id.x+.5)*CELL,0,(id.y+.5)*CELL)
	var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.35,1);ray.exclude=exclude
	var hit:=space.intersect_ray(ray)
	var ok: bool=not hit.is_empty() and hit.normal.y>.65 and hit.position.y<.3
	if ok:
		query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,hit.position.y+.85,p.z))
		ok=space.intersect_shape(query,1).is_empty()
	graph.set_point_solid(id,not ok)
	if ok:heights[id]=hit.position.y
	else:heights.erase(id)

# Re-probes every cell near a line (after a barrier opened).
func rebuild_line(a: Vector3, b: Vector3, margin: float=1.2) -> void:
	var lo:=Vector2(minf(a.x,b.x)-margin,minf(a.z,b.z)-margin);var hi:=Vector2(maxf(a.x,b.x)+margin,maxf(a.z,b.z)+margin)
	for y in range(floori(lo.y/CELL),ceili(hi.y/CELL)+1):
		for x in range(floori(lo.x/CELL),ceili(hi.x/CELL)+1):
			var id:=Vector2i(x,y)
			if REGION.has_point(id):_probe(id)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.z/CELL))

func point(id: Vector2i) -> Vector3:
	return Vector3((id.x+.5)*CELL,float(heights.get(id,0.)),(id.y+.5)*CELL)

func walkable(id: Vector2i) -> bool:
	return REGION.has_point(id) and not graph.is_point_solid(id)

# Closest open cell within a few rings.
func nearest(p: Vector3) -> Vector2i:
	var c:=cell_of(p)
	if walkable(c):return c
	for ring in range(1,6):
		var best:=Vector2i(999999,0);var best_d:=INF
		for dy in range(-ring,ring+1):
			for dx in range(-ring,ring+1):
				if maxi(absi(dx),absi(dy))!=ring:continue
				var id:=c+Vector2i(dx,dy)
				if walkable(id):
					var d:=Vector2(dx,dy).length_squared()
					if d<best_d:best_d=d;best=id
		if best.x!=999999:return best
	return Vector2i(999999,0)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a:=nearest(from);var b:=nearest(to);var out:=PackedVector3Array()
	if a.x==999999 or b.x==999999:return out
	for id in graph.get_id_path(a,b,true):out.append(point(id))
	return out

# Every open cell reachable from a point (flood fill), as a dictionary set.
func reachable(from: Vector3, limit: int=40000) -> Dictionary:
	var start:=nearest(from);var seen:={}
	if start.x==999999:return seen
	var queue:=[start];seen[start]=true
	while not queue.is_empty() and seen.size()<limit:
		var c: Vector2i=queue.pop_back()
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n: Vector2i=c+d
			if not seen.has(n) and walkable(n):seen[n]=true;queue.append(n)
	return seen
