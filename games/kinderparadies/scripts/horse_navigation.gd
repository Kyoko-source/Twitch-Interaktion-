class_name HorseNavigation
extends RefCounted

const CELL:=.5
const REGION:=Rect2i(-46,-72,98,116)
var graph:=AStarGrid2D.new()
var w: PlayWorld
var heights: Dictionary={}
var cells: Array[Vector2i]=[]
var cursor:=0
var ready:=false
var shape:=CapsuleShape3D.new()
var query:=PhysicsShapeQueryParameters3D.new()

func setup(world: PlayWorld) -> void:
 w=world;graph.region=REGION;graph.cell_size=Vector2.ONE*CELL;graph.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;graph.update();graph.fill_solid_region(REGION,true)
 # Match the guard's walking clearance. The previous wider probe split the
 # washroom approach from the hall even though the player could walk through.
 shape.radius=.28;shape.height=1.7;query.shape=shape;query.collision_mask=1;query.margin=.002

func cell_point(id: Vector2i) -> Vector3:
 return Vector3((id.x+.5)*CELL,float(heights.get(id,0)),(id.y+.5)*CELL)

func tick(player: NightGuard, budget: int=160) -> void:
 if ready:return
 query.exclude=[player.get_rid()]
 var space:=w.get_world_3d().direct_space_state
 for unused in range(budget):
  if cursor>=REGION.size.x*REGION.size.y:ready=true;return
  var id:=REGION.position+Vector2i(cursor%REGION.size.x,cursor/REGION.size.x);cursor+=1
  var p:=cell_point(id)
  var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.36,p-Vector3.UP*.35,1);ray.exclude=[player.get_rid()]
  var hit:=space.intersect_ray(ray)
  if hit.is_empty() or hit.normal.y<.65 or hit.position.y>.27:continue
  p.y=hit.position.y
  query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.90)
  if not space.intersect_shape(query,1).is_empty():continue
  graph.set_point_solid(id,false);heights[id]=p.y;cells.append(id)

func nearest(point: Vector3) -> Vector2i:
 var closest:=Vector2i(99999,99999);var best:=INF
 for id in cells:
  var distance:=Vector2(point.x,point.z).distance_squared_to(Vector2((id.x+.5)*CELL,(id.y+.5)*CELL))
  if distance<best:best=distance;closest=id
 return closest

func path(from: Vector3,to: Vector3) -> PackedVector3Array:
 if not ready or cells.is_empty():return PackedVector3Array()
 var ids:=graph.get_id_path(nearest(from),nearest(to));var result:=PackedVector3Array()
 for id in ids:result.append(cell_point(id))
 return result

func reachable_floor(point: Vector3) -> bool:
 if cells.is_empty():return false
 var nearby:=cell_point(nearest(point))
 return absf(nearby.y-point.y)<.32 and Vector2(nearby.x,nearby.z).distance_to(Vector2(point.x,point.z))<.65
