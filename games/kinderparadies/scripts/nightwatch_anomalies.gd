class_name NightwatchAnomalies
extends RefCounted

# Nightwatch Protocol: anomalies that appear while the world keeps running and
# are undone exactly when they are reported or expire. Nothing here touches the
# shared PlayWorld anomaly setup, so the other modes never see these changes.
# 5.6.0: only the rooms change, never a figure; a click on the change in the
# full-screen picture puts it back (hits()).

# Obvious kinds dominate the first nights, subtle ones grow later.
const OBVIOUS:=["missing","floating","light","balls","room"]
const SUBTLE:=["moved","extra","motion"]
const BALL_COLOURS:=[Color("d8322a"),Color("f2c230"),Color("2f6fd6"),Color("3fa34d"),Color("e07a24")]

var w: PlayWorld
var rng:=RandomNumberGenerator.new()
var uid:=0

func _init(world: PlayWorld, seed_value: int) -> void:
 w=world;rng.seed=seed_value

static func resolve(world: PlayWorld, spec: String, pick: int=-1) -> Node3D:
 var kind:=spec.get_slice(":",0);var key:=spec.get_slice(":",1)
 if kind=="prop":
  var group:=key.trim_suffix("/*")
  var node: Variant=world.props.get(group)
  if not node is Node3D:return null
  if key.ends_with("/*"):
   var children:=(node as Node3D).get_children().filter(func(c):return c is Node3D)
   if children.is_empty():return null
   return children[clampi(pick,0,children.size()-1) if pick>=0 else 0]
  return node
 return world.find_child(key,true,false) as Node3D

static func group_size(world: PlayWorld, spec: String) -> int:
 if not spec.ends_with("/*"):return 1
 var node: Variant=world.props.get(spec.get_slice(":",1).trim_suffix("/*"))
 return (node as Node3D).get_child_count() if node is Node3D else 0

static func bounds(node: Node3D) -> AABB:
 var box:=AABB();var first:=true
 var meshes: Array=node.find_children("*","MeshInstance3D",true,false)
 if node is MeshInstance3D:meshes.append(node)
 for mesh: MeshInstance3D in meshes:
  if mesh.mesh==null or not mesh.is_visible_in_tree():continue
  var b: AABB=mesh.global_transform*mesh.get_aabb()
  if first:box=b;first=false
  else:box=box.merge(b)
 if first:box=AABB(node.global_position,Vector3.ZERO)
 return box

# Every (room, area, kind, target) the spawner may choose for this stage.
func options(stage: int, busy: Dictionary) -> Array:
 var out: Array=[]
 for room in NightwatchConfig.ROOMS:
  for area in room.areas:
   var key: String=str(room.id)+"/"+str(area.id)
   if busy.has(key):continue
   for kind in ["light","room"]+area.get("special",[]):
    out.append({"room":room.id,"area":area.id,"kind":kind,"spec":"","weight":_weight(kind,stage)*(1.6 if kind=="balls" else .55 if kind=="room" else 1.)})
   for row in area.objects:
    for kind in row[2]:
     out.append({"room":room.id,"area":area.id,"kind":kind,"spec":row[0],"label":row[1],"weight":_weight(kind,stage)})
 return out

func _weight(kind: String, stage: int) -> float:
 var late:=clampf((stage-1)/4.0,0,1)
 if kind in OBVIOUS:return lerpf(3.,1.,late)
 return lerpf(.6,2.4,late)

func pick(stage: int, busy: Dictionary) -> Dictionary:
 var pool:=options(stage,busy)
 var total:=0.
 for item in pool:total+=float(item.weight)
 var roll:=rng.randf()*total
 for item in pool:
  roll-=float(item.weight)
  if roll<=0:return item
 return pool.back() if not pool.is_empty() else {}

# Applies a chosen option; returns the live anomaly record or {} if the target
# is unavailable in this world.
func apply(option: Dictionary, camera_spec: Dictionary, detect: float) -> Dictionary:
 var area:=NightwatchConfig.area(option.room,option.area)
 var record:={"uid":uid+1,"room":option.room,"area":option.area,"kind":option.kind,"label":str(option.get("label","")),"detect":detect,"left":detect,"state":"active","node":null,"added":[],"restore":{},"phase":rng.randf()*TAU,"base":Transform3D(),"boxes":[],"others":[]}
 var cam_pos: Vector3=camera_spec.p
 var look_at_point: Vector3=camera_spec.at;var right: Vector3=(look_at_point-cam_pos).cross(Vector3.UP);right.y=0;right=right.normalized() if right.length()>.01 else Vector3.RIGHT
 var side:=-1. if rng.randf()<.5 else 1.
 if option.kind in NightwatchConfig.SPOT_KINDS:
  var spots: Array=area.spots
  var spot: Vector3=spots[rng.randi_range(0,spots.size()-1)]
  match str(option.kind):
   "light":record.added.append(_light(spot));record.label="rotes Licht";record.boxes=[AABB(spot+Vector3(-1.2,0,-1.2),Vector3(2.4,2.4,2.4))]
   "balls":record.added.append(_balls(spot));record.label="schwebende Bälle"
   "room":
    # Everything in the camera's picture turned and shoved at once.
    for a in NightwatchConfig.room(option.room).areas:
     if a.camera!=area.camera:continue
     for row in a.objects:
      var target:=resolve(w,str(row[0]),rng.randi_range(0,maxi(group_size(w,str(row[0]))-1,0)))
      if not is_instance_valid(target) or not target.is_visible_in_tree():continue
      record.others.append({"node":target,"transform":target.transform})
      var turn:=-1. if rng.randf()<.5 else 1.
      var box_before:=bounds(target)
      # Every piece turned, shoved, and on its side or its head, back on the floor.
      var tip:=Basis(right,PI if record.others.size()%2==1 else PI*.5)*Basis(Vector3.UP,turn*deg_to_rad(rng.randf_range(70.,180.)))
      spin(target,tip);target.global_position+=right*turn*rng.randf_range(.8,1.4)
      var box_after:=bounds(target)
      target.global_position.y+=box_before.position.y-box_after.position.y
    if record.others.size()<2:
     for row in record.others:(row.node as Node3D).transform=row.transform
     return {}
    var tint:=_light(spot);(tint.get_child(0) as OmniLight3D).light_color=Color("6dffb0");(tint.get_child(0) as OmniLight3D).light_energy=1.1;tint.global_position.y+=.8;record.added.append(tint)
    record.label="der ganze Raum"
 else:
  var count:=group_size(w,option.spec)
  var node:=resolve(w,option.spec,rng.randi_range(0,maxi(count-1,0)))
  if not is_instance_valid(node) or not node.is_visible_in_tree():return {}
  record.node=node;record.restore={"transform":node.transform,"visible":node.visible,"layers":_layers(node)}
  record.base=node.global_transform
  var box:=bounds(node)
  match str(option.kind):
   "missing":
    record.boxes=[box];node.hide();_set_layers(node,0)
   "floating":
    var lift:=rng.randf_range(.85,1.35)
    node.global_position.y+=lift;record.base=node.global_transform
   "moved":
    node.global_position+=right*side*rng.randf_range(.75,1.15);spin(node,Basis(Vector3.UP,side*deg_to_rad(rng.randf_range(28.,55.))))
   "extra":
    var copy:=node.duplicate() as Node3D
    node.get_parent().add_child(copy);copy.global_transform=node.global_transform
    copy.global_position+=right*side*(maxf(box.size.x,box.size.z)*1.05+.3)
    _set_layers(copy,0);copy.set_meta("nightwatch_extra",true);record.added.append(copy)
   "motion":
    pass
 uid+=1
 return record

# Turns a node about the middle of what it shows, not about its origin:
# some prop groups keep their origin far away from their furniture.
static func spin(node: Node3D, turn: Basis) -> void:
 var pivot:=bounds(node).get_center()
 var t:=node.global_transform
 node.global_transform=Transform3D(turn*t.basis,pivot+turn*(t.origin-pivot))

# A cloud of pit balls hanging in the air above the ball pit.
func _balls(spot: Vector3) -> Node3D:
 var root:=Node3D.new();root.name="NightwatchFloatingBalls";w.add_child(root);root.global_position=spot+Vector3(.6,0,-.4)
 var mesh:=SphereMesh.new();mesh.radius=.11;mesh.height=.22;mesh.radial_segments=16;mesh.rings=8
 for i in range(34):
  var ball:=MeshInstance3D.new();ball.mesh=mesh;ball.name="Ball%d"%i
  var m:=StandardMaterial3D.new();m.albedo_color=BALL_COLOURS[i%BALL_COLOURS.size()];m.roughness=.35;ball.material_override=m
  ball.position=Vector3(rng.randf_range(-1.3,1.3),rng.randf_range(1.4,2.8),rng.randf_range(-1.,1.))
  ball.set_meta("bob",rng.randf()*TAU);root.add_child(ball)
 return root

func _light(spot: Vector3) -> Node3D:
 var root:=Node3D.new();root.name="NightwatchRedLight";w.add_child(root);root.global_position=spot+Vector3(0,1.9,0)
 var lamp:=OmniLight3D.new();lamp.light_color=Color("ff2a1c");lamp.light_energy=5.;lamp.omni_range=5.5;lamp.omni_attenuation=.8;root.add_child(lamp)
 return root

func _layers(node: Node3D) -> Array:
 var out: Array=[]
 for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):out.append([body,body.collision_layer,body.collision_mask])
 return out

func _set_layers(node: Node3D, value: int) -> void:
 for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):body.collision_layer=value;body.collision_mask=value

# Continuous changes: bobbing, rocking, swaying figures, flickering light.
func tick(record: Dictionary, delta: float) -> void:
 record.phase=float(record.phase)+delta
 var t: float=record.phase
 var node: Node3D=record.node if is_instance_valid(record.node) else null
 match str(record.kind):
  "floating":
   if node:
    var base: Transform3D=record.base
    node.global_transform=base.translated(Vector3(0,sin(t*1.3)*.07,0))
    node.rotate_y(sin(t*.45)*.004)
  "motion":
   if node:
    var base: Transform3D=record.base
    var rock:=Basis(Vector3.FORWARD,sin(t*3.2)*deg_to_rad(11.))*Basis(Vector3.UP,sin(t*2.1)*deg_to_rad(9.))
    node.global_transform=Transform3D(rock*base.basis,base.origin+Vector3(0,absf(sin(t*3.2))*.04,0))
  "balls":
   for added in record.added:
    if is_instance_valid(added):
     for ball: Node3D in (added as Node3D).get_children():
      var p: float=ball.get_meta("bob",0.)
      ball.position.y+=sin(t*1.4+p)*.0012
  "light":
   for added in record.added:
    if is_instance_valid(added) and added.get_child_count()>0:
     (added.get_child(0) as OmniLight3D).light_energy=5.*(.55+.45*absf(sin(t*9.)*sin(t*2.3+1.)))

# 5.5.0: a figure removed while a feed is drawing it first drops its own
# materials and hides, and is freed a moment later. Freeing it at once let the
# renderer ask for materials that were already gone.
static func retire(node: Node) -> void:
 if not is_instance_valid(node):return
 for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
  mesh.material_override=null
  if mesh.mesh:
   for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,null)
 if node is Node3D:(node as Node3D).hide()
 var tree:=node.get_tree()
 # Bound to the node: the connection dies with it if the world goes first.
 if tree:tree.create_timer(.25).timeout.connect(node.queue_free)
 else:node.queue_free()

# Boxes a click has to land in: what changed, where it is now (or where it
# was, for a missing thing).
func targets(record: Dictionary) -> Array:
 var out: Array=record.get("boxes",[]).duplicate()
 var node: Node3D=record.node if is_instance_valid(record.node) else null
 if node and node.visible:out.append(bounds(node))
 for added in record.added:
  if not is_instance_valid(added):continue
  if str(record.kind)=="balls":
   for ball: Node3D in (added as Node3D).get_children():out.append(AABB(ball.global_position-Vector3.ONE*.12,Vector3.ONE*.24))
  elif str(record.kind)=="extra":out.append(bounds(added))
 for row in record.get("others",[]):
  if is_instance_valid(row.node):out.append(bounds(row.node))
 return out

# Does a point in the feed picture of this camera land on the change?
func hits(record: Dictionary, feed_camera: Camera3D, point: Vector2) -> bool:
 for box: AABB in targets(record):
  var rect:=Rect2();var first:=true
  for i in range(8):
   var corner:=box.get_endpoint(i)
   if feed_camera.is_position_behind(corner):continue
   var px:=feed_camera.unproject_position(corner)
   if first:rect=Rect2(px,Vector2.ZERO);first=false
   else:rect=rect.expand(px)
  if not first and rect.grow(NightwatchConfig.HIT_MARGIN).has_point(point):return true
 return false

func revert(record: Dictionary, immediate: bool=false) -> void:
 for row in record.get("others",[]):
  if is_instance_valid(row.node):(row.node as Node3D).transform=row.transform
 record.others=[]
 for added in record.added:
  if is_instance_valid(added):
   if immediate:(added as Node).queue_free()
   else:retire(added as Node)
 record.added=[]
 var node: Node3D=record.node if is_instance_valid(record.node) else null
 if node and not record.restore.is_empty():
  node.transform=record.restore.transform;node.visible=record.restore.visible
  for row in record.restore.layers:
   if is_instance_valid(row[0]):(row[0] as CollisionObject3D).collision_layer=row[1];(row[0] as CollisionObject3D).collision_mask=row[2]
 record.node=null
