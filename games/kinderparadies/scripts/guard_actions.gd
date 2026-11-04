class_name GuardActions
extends Node3D

var guard: NightGuard
var rig: Node3D
var skeleton: Skeleton3D
var held: Node3D
var kind:=""
var clock:=0.
var duration:=.8
var enabled:=true
var point:=Vector3.ZERO
var count:=0
var sound: AudioStreamPlayer
var contact_node: Node3D
var rest_bones: Dictionary={}
var object_start:=Transform3D.IDENTITY
var world_item: Node3D
var torch_dip:=Vector3.ZERO
var sleeve: MeshInstance3D
var cloth: ShaderMaterial
var fill: OmniLight3D
var on_contact:=Callable()
var close_contact:=false

func build(player: NightGuard) -> void:
 guard=player;name="VisibleInteractionHand";guard.camera.add_child(self)
 rig=(load(QualityAssets.model("interaction-hand","res://assets/tactile-v400/interaction-hand-web.glb")) as PackedScene).instantiate();add_child(rig)
 skeleton=rig.find_children("*","Skeleton3D",true,false)[0]
 for i in range(skeleton.get_bone_count()):rest_bones[i]=skeleton.get_bone_rest(i)
 CharacterFinish.hand(rig)
 for mesh in rig.find_children("*","MeshInstance3D",true,false):
  mesh.layers=2;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in range(mesh.mesh.get_surface_count()):
   var original:=mesh.get_active_material(surface) as StandardMaterial3D
   if original and "sleeve" in original.resource_name.to_lower():
    mesh.hide()
   elif original and "skin" in original.resource_name.to_lower():original.albedo_color=Color("e4cbb2")
 cloth=ShaderMaterial.new();cloth.shader=load("res://assets/quality-v410/guard-cloth.gdshader");cloth.set_shader_parameter("weave",load("res://assets/pbr/fabric_pattern_07/normal.jpg"))
 sleeve=MeshInstance3D.new();sleeve.name="ConnectedInteractionSleeve";sleeve.material_override=cloth;sleeve.layers=2;sleeve.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;guard.camera.add_child(sleeve);sleeve.hide()
 held=Node3D.new();held.name="HandledObject";guard.camera.add_child(held)
 sound=AudioStreamPlayer.new();sound.stream=load("res://assets/polish/impact-cloth.wav");sound.volume_db=-28;sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(sound)
 hide();held.hide()
 fill=OmniLight3D.new();fill.name="EquipmentBounceLight";fill.position=Vector3(.04,-.12,-.08);fill.light_color=Color("ffe4c3");fill.light_energy=.38;fill.omni_range=1.7;fill.omni_attenuation=1.1;fill.light_cull_mask=2;fill.light_volumetric_fog_energy=0.;fill.light_specular=.18;guard.camera.add_child(fill);fill.hide()

func begin(id: String,hit: Vector3) -> bool:
 if not enabled or not kind.is_empty() or is_instance_valid(guard.carried):return false
 if id not in ["red","green","delivery_exit","parking_key","party_control","archive_lock","archive_door","cinema_projector","archive_recording"] and not id.begins_with("paper:") and not id.begins_with("mechanical:"):return false
 var g:=guard.get_parent()
 if id.begins_with("mechanical:") and g.world.mechanics.busy(id):return false
 if id=="delivery_exit" and not g.archive.parking_key_found:return false
 if id=="red" and g.world.horse_hunt.red_locked():return false
 kind=id;clock=0.;duration=1.05 if id.begins_with("paper:") or id=="parking_key" else .9 if id=="delivery_exit" else .64;count+=1
 if id=="mechanical:gum":duration=1.55
 elif id=="mechanical:ticket":duration=.98
 point=g.world.tactile.point_for(id,hit);contact_node=g.world.tactile.contact.get(id)
 for child in held.get_children():child.free()
 world_item=null
 if id.begins_with("paper:"):
  var paper: Node3D=g.world.archive.items.get(id.trim_prefix("paper:"))
  if paper:
   var source:=paper.get_child(0) as MeshInstance3D
   var item:=MeshInstance3D.new();item.mesh=source.mesh;item.material_override=source.material_override;item.layers=2;held.add_child(item)
   object_start=paper.global_transform;world_item=item;held.show()
 elif id=="parking_key":
  _key(g.world);object_start=g.world.details.parking_key.global_transform;object_start.origin=g.world.details.parking_key.to_global(Vector3(0,-.025,.12));world_item=held.get_child(0);held.show()
 elif id=="delivery_exit":_key(g.world);held.show()
 g.world.tactile.touch("archive_lock" if id=="archive_door" else id)
 show();sound.play();pose();return true

func _key(w: PlayWorld) -> void:
 var key:=Node3D.new();key.name="ParkingKeyInHand";held.add_child(key)
 var metal:=w.mat(Color("ab9365"),null,.39,.78)
 var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.016;torus.outer_radius=.022;torus.rings=24;torus.ring_segments=8;ring.mesh=torus;ring.material_override=metal;ring.rotation.x=PI/2;key.add_child(ring)
 w.box(key,Vector3(0,-.048,0),Vector3(.009,.059,.009),metal)
 for y in [-.053,-.070]:w.box(key,Vector3(.009,y,0),Vector3(.023,.008,.009),metal)
 w.box(key,Vector3(.040,-.026,0),Vector3(.040,.065,.007),w.mat(Color("366556"),null,.74))
 CelebrationTailoring.merge_joint(key)
 for mesh in key.find_children("*","MeshInstance3D",true,false):mesh.layers=2;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func tick(delta: float,active: bool) -> void:
 sound.stream_paused=not active
 if kind.is_empty():return
 if not active:return
 clock+=delta
 if clock>=duration*.28 and on_contact.is_valid():
  var callback:=on_contact;on_contact=Callable();callback.call()
  if kind.is_empty():return
 if clock>=duration:cancel();return
 pose()

func pose() -> void:
 var t:=clock/duration
 var reach:=smoothstep(0.,.24,t)*(1.-smoothstep(.67,1.,t))
 var contact_point:=contact_node.global_position+contact_node.global_basis.z*.035 if is_instance_valid(contact_node) else point
 if kind.begins_with("mechanical:") and is_instance_valid(contact_node):contact_point=contact_node.global_position
 var local:=guard.camera.to_local(contact_point)
 var press_mechanism:=kind in ["mechanical:bell","mechanical:ticket"]
 close_contact=local.distance_to(Vector3(-.24,-.34,.03))<.90
 # A distant desk can still be operated, but never grows a rubber arm across
 # the view. The existing timed contact and mechanical movement still run.
 if kind.begins_with("mechanical:") and not close_contact:
  hide();sleeve.hide();fill.hide();torch_dip=Vector3.ZERO;return
 show()
 # Reach stays within a human arm length; it never teleports the player or
 # changes a collider. Close interactions align with the actual moving fitting.
 if not close_contact:local=local.limit_length(.72)
 local.z=minf(-.28,local.z)
 var door:=kind in ["red","green"]
 var unlocking:=kind=="delivery_exit"
 var wrist:=local+Vector3(.027,-.009,.12)
 if door:wrist=local+Vector3(-.055,-.01,.035)
 if unlocking:wrist=local+Vector3(-.04,-.015,.16)
 position=Vector3(-.29,-.52,-.17).lerp(wrist,reach)
 rotation=Vector3(-PI/2.,-.12,.08)
 if door:rotation=Vector3(0,PI,PI/2.)
 if unlocking:rotation=Vector3(-PI/2.,0,-.18)
 var take:=kind.begins_with("paper:") or kind=="parking_key"
 var crank:=kind=="mechanical:gum"
 if crank:rotation.z-=sin(TAU*smoothstep(.28,.89,t))*.65
 if press_mechanism:
  var forward: Vector3=-guard.camera.global_basis.z;forward.y=0.;forward=forward.normalized()
  # Palm faces down, wrist stays behind the knuckles. Only the index bends
  # onto the plunger; pointing the entire hand down put the wrist above it.
  basis=guard.camera.global_basis.inverse()*Basis(forward.cross(Vector3.DOWN),forward,Vector3.DOWN)
 if take and t>.30:
  var pull:=smoothstep(.30,.66,t)
  position=position.lerp(Vector3(-.24,-.20,-.46) if kind.begins_with("paper:") else Vector3(-.14,-.22,-.40),pull);rotation=rotation.lerp(Vector3(-.14,.12,-.25),pull)
 var turn:=sin(smoothstep(.25,.65,t)*PI)*.7 if kind=="delivery_exit" else 0.
 rotation.z+=turn
 for i in range(skeleton.get_bone_count()):
  var name:=skeleton.get_bone_name(i);var flex:=.0
  if name.begins_with("thumb"):flex=.12+reach*.18
  elif name not in ["wrist","palm"]:
   flex=(.62 if take or unlocking or crank else .55)*reach
   if door:flex=(.45 if name.ends_with("1") else .95 if name.ends_with("2") else .5)*reach
   if not take and not door and not unlocking and not crank:flex=(.85 if name.ends_with("1") else 1.05 if name.ends_with("2") else .45)*reach
   if name.begins_with("index") and not take and not door and not unlocking and not crank:
    flex=(.25 if name.ends_with("1") else .60 if name.ends_with("2") else .12)*reach if press_mechanism else .025
  var rest: Transform3D=rest_bones[i]
  skeleton.set_bone_pose_rotation(i,rest.basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,flex))
 if press_mechanism:
  skeleton.force_update_all_bone_transforms()
  var tip:=skeleton.get_bone_global_pose(skeleton.find_bone("index3"))*Vector3(0,.02125,0)
  var in_hand:=to_local(skeleton.to_global(tip))
  position+=(local-transform*in_hand)*reach
 if not held.get_children().is_empty():
  var pull:=smoothstep(.25,.65,t)
  held.position=position+basis*(Vector3(.165,.06,.003) if kind.begins_with("paper:") else Vector3(.030,.065,.055));held.rotation=Vector3(.04,-.16,.12) if kind.begins_with("paper:") else rotation+Vector3(.3,0,turn)
  if world_item and t<.65:
   held.global_transform=object_start.interpolate_with(held.global_transform,pull)
  if unlocking:
   held.position=Vector3(-.24,-.3,-.27).lerp(local+Vector3(0,0,.078),reach);held.rotation=Vector3(PI/2,0,turn)
 _sleeve()
 fill.visible=guard.lamp_on;fill.light_energy=.38*guard.torch_body.strength
 torch_dip=Vector3(.015,-.025,.04)*reach

func _sleeve() -> void:
 var end:=position+basis*Vector3(0,-.08,-.004)
 # Start below the frame, in front of the near plane. Crossing the camera
 # plane made the old sleeve appear as a huge black strip across the screen.
 var start:=Vector3(-.24,-.50,-.27);var elbow:=Vector3(-.28,-.36,-.39)
 if not sleeve.mesh:
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in range(16):
   for side in range(20):
    for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
     var t:=float(row+corner.y)/16.;var a:=float(side+corner.x)*TAU/20.
     tool.set_normal(Vector3(cos(a),0,sin(a)));tool.set_uv(Vector2(float(side+corner.x)/20.,t));tool.add_vertex(Vector3(cos(a),t,sin(a)))
  tool.index();tool.generate_tangents();sleeve.mesh=tool.commit()
 cloth.set_shader_parameter("start_point",start);cloth.set_shader_parameter("elbow_point",elbow);cloth.set_shader_parameter("wrist_point",end)
 sleeve.custom_aabb=AABB(start,Vector3.ZERO).expand(elbow).expand(end).grow(.055);sleeve.show()

func cancel() -> void:
 kind="";clock=0.;hide();held.hide();contact_node=null;world_item=null;torch_dip=Vector3.ZERO;on_contact=Callable()
 if sleeve:sleeve.hide()
 if fill:fill.hide()
 if sound:sound.stop()

func snapshot() -> Dictionary:
 return {"kind":kind,"clock":clock,"count":count,"visible":visible,"enabled":enabled,"held":held.get_child_count()}
