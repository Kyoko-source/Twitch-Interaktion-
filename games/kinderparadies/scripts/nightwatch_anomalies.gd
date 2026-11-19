class_name NightwatchAnomalies
extends RefCounted

# Nightwatch Protocol: anomalies that appear while the world keeps running and
# are undone exactly when they are reported or expire. Nothing here touches the
# shared PlayWorld anomaly setup, so the other modes never see these changes.

const VISITORS:=["res://assets/visitors-v421/visitor-ragged.glb","res://assets/visitors-v421/visitor-split.glb","res://assets/visitors-v421/visitor-hooded.glb"]
# Obvious kinds dominate the first stages, subtle ones grow later.
const OBVIOUS:=["visitor","missing","floating","light","apparition"]
const SUBTLE:=["moved","extra","motion"]

var w: PlayWorld
var rng:=RandomNumberGenerator.new()
var ghost_material: ShaderMaterial
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
   for kind in NightwatchConfig.SPOT_KINDS:
    out.append({"room":room.id,"area":area.id,"kind":kind,"spec":"","weight":_weight(kind,stage)})
   for row in area.objects:
    for kind in row[2]:
     out.append({"room":room.id,"area":area.id,"kind":kind,"spec":row[0],"label":row[1],"weight":_weight(kind,stage)})
 return out

func _weight(kind: String, stage: int) -> float:
 var late:=clampf((stage-1)/6.0,0,1)
 if kind in OBVIOUS:return lerpf(3.,1.,late)*(.7 if kind in NightwatchConfig.SPOT_KINDS else 1.)
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
 var record:={"uid":uid+1,"room":option.room,"area":option.area,"kind":option.kind,"label":str(option.get("label","")),"detect":detect,"left":detect,"state":"active","node":null,"added":[],"restore":{},"phase":rng.randf()*TAU,"base":Transform3D()}
 var cam_pos: Vector3=camera_spec.p
 var look_at_point: Vector3=camera_spec.at;var right: Vector3=(look_at_point-cam_pos).cross(Vector3.UP);right.y=0;right=right.normalized() if right.length()>.01 else Vector3.RIGHT
 var side:=-1. if rng.randf()<.5 else 1.
 if option.kind in NightwatchConfig.SPOT_KINDS:
  var spots: Array=area.spots
  var spot: Vector3=spots[rng.randi_range(0,spots.size()-1)]
  match str(option.kind):
   "visitor":record.added.append(_visitor(spot,cam_pos,false));record.label="ein Besucher"
   "apparition":record.added.append(_visitor(spot,cam_pos,true));record.label="eine Erscheinung"
   "light":record.added.append(_light(spot));record.label="rotes Licht"
 else:
  var count:=group_size(w,option.spec)
  var node:=resolve(w,option.spec,rng.randi_range(0,maxi(count-1,0)))
  if not is_instance_valid(node) or not node.is_visible_in_tree():return {}
  record.node=node;record.restore={"transform":node.transform,"visible":node.visible,"layers":_layers(node)}
  record.base=node.global_transform
  var box:=bounds(node)
  match str(option.kind):
   "missing":
    node.hide();_set_layers(node,0)
   "floating":
    var lift:=rng.randf_range(.85,1.35)
    node.global_position.y+=lift;record.base=node.global_transform
   "moved":
    node.global_position+=right*side*rng.randf_range(.75,1.15);node.rotate_y(side*deg_to_rad(rng.randf_range(28.,55.)))
   "extra":
    var copy:=node.duplicate() as Node3D
    node.get_parent().add_child(copy);copy.global_transform=node.global_transform
    copy.global_position+=right*side*(maxf(box.size.x,box.size.z)*1.05+.3)
    _set_layers(copy,0);copy.set_meta("nightwatch_extra",true);record.added.append(copy)
   "motion":
    pass
 uid+=1
 return record

func _visitor(spot: Vector3, cam_pos: Vector3, ghost: bool) -> Node3D:
 var root:=Node3D.new();root.name="NightwatchApparition" if ghost else "NightwatchVisitor";w.add_child(root)
 var body:=(load(VISITORS[2 if ghost else rng.randi_range(0,VISITORS.size()-1)]) as PackedScene).instantiate() as Node3D
 root.add_child(body);CharacterFinish.dynamic_only(body)
 root.global_position=spot+Vector3(0,.32 if ghost else 0,0)
 var face:=Vector3(cam_pos.x,root.global_position.y,cam_pos.z)
 if face.distance_to(root.global_position)>.1:root.look_at(face,Vector3.UP,true)
 if ghost:
  for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
   mesh.material_override=_ghost();mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var glow:=OmniLight3D.new();glow.light_color=Color("b8d6ff");glow.light_energy=1.4;glow.omni_range=3.2;glow.position=Vector3(0,1.3,.3);root.add_child(glow)
 return root

func _ghost() -> ShaderMaterial:
 if ghost_material:return ghost_material
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float flicker=1.0;
void fragment(){
 float rim=pow(1.0-abs(dot(NORMAL,VIEW)),1.6);
 float band=.75+.25*sin(TIME*7.0+VERTEX.y*9.0);
 ALBEDO=vec3(.55,.75,1.0)*(.35+rim*1.4)*band*flicker;
 ALPHA=1.0;
}"""
 ghost_material=ShaderMaterial.new();ghost_material.shader=shader;return ghost_material

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
  "visitor":
   for added in record.added:
    if is_instance_valid(added):(added as Node3D).rotation.z=sin(t*.8)*.025
  "apparition":
   for added in record.added:
    if is_instance_valid(added):
     (added as Node3D).position.y+=sin(t*1.1)*.0015
     if ghost_material:ghost_material.set_shader_parameter("flicker",.55+.45*absf(sin(t*13.)*sin(t*3.7)))
  "light":
   for added in record.added:
    if is_instance_valid(added) and added.get_child_count()>0:
     (added.get_child(0) as OmniLight3D).light_energy=5.*(.55+.45*absf(sin(t*9.)*sin(t*2.3+1.)))

func revert(record: Dictionary) -> void:
 for added in record.added:
  if is_instance_valid(added):(added as Node).queue_free()
 record.added=[]
 var node: Node3D=record.node if is_instance_valid(record.node) else null
 if node and not record.restore.is_empty():
  node.transform=record.restore.transform;node.visible=record.restore.visible
  for row in record.restore.layers:
   if is_instance_valid(row[0]):(row[0] as CollisionObject3D).collision_layer=row[1];(row[0] as CollisionObject3D).collision_mask=row[2]
 record.node=null
