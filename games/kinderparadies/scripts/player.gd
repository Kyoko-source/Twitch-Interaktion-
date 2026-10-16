class_name NightGuard
extends CharacterBody3D

var camera: Camera3D
var lamp: SpotLight3D
var active := false
var sensitivity := 0.0022
var motion := true
var walk_clock := 0.0
var step_clock := 0.0
var step_player: AudioStreamPlayer
var lamp_on := true
var torch_body: MeshInstance3D
var carried: NightProp
var jump_buffer := 0.0
var coyote := 0.0
var landing_offset := 0.0
var was_airborne := false

func _ready() -> void:
 var shape:=CapsuleShape3D.new();shape.radius=.28;shape.height=1.7
 var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=.85;add_child(collision)
 camera=Camera3D.new();camera.fov=75;camera.near=.06;camera.far=70;camera.position.y=1.65;add_child(camera)
 lamp=SpotLight3D.new();lamp.light_color=Color("fff1cc");lamp.light_energy=4.2;lamp.spot_range=22;lamp.spot_angle=24;lamp.spot_angle_attenuation=1.1;lamp.shadow_enabled=true;lamp.shadow_bias=.025;lamp.position=Vector3(.18,-.1,-.12);camera.add_child(lamp)
 # Physical handheld torch, attached to the camera, below the crosshair.
 var body:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.075;mesh.bottom_radius=.048;mesh.height=.3;body.mesh=mesh
 var material:=StandardMaterial3D.new();material.albedo_color=Color("252b2d");material.metallic=.8;material.roughness=.35;body.material_override=material;body.position=Vector3(.28,-.27,-.44);body.rotation.x=PI/2;camera.add_child(body)
 torch_body=body
 torch_body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var rim:=MeshInstance3D.new();var rim_mesh:=TorusMesh.new();rim_mesh.inner_radius=.064;rim_mesh.outer_radius=.083;rim_mesh.rings=24;rim_mesh.ring_segments=8;rim.mesh=rim_mesh;rim.material_override=material;rim.rotation.x=PI/2;rim.position.y=.15;body.add_child(rim)
 step_player=AudioStreamPlayer.new();step_player.stream=load("res://assets/step.ogg");step_player.volume_db=-19;add_child(step_player)

func capture() -> void:
 active=true
 torch_body.show()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if "--render-qa" in OS.get_cmdline_user_args() else Input.MOUSE_MODE_CAPTURED

func release() -> void:
 drop_prop()
 active=false;velocity=Vector3.ZERO;step_player.stop()
 jump_buffer=0;coyote=0
 torch_body.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
 if active and event.is_action_pressed("jump"): jump_buffer=.14
 if active and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  rotate_y(-event.relative.x*sensitivity)
  camera.rotation.x=clampf(camera.rotation.x-event.relative.y*sensitivity,-1.35,1.35)

func _physics_process(delta: float) -> void:
 if not active: return
 var direction:=Input.get_vector("left","right","forward","back")
 var aim:=transform.basis*Vector3(direction.x,0,direction.y)
 var speed:=4.5 if Input.is_action_pressed("sprint") else 2.8
 var target:=aim*speed
 velocity.x=move_toward(velocity.x,target.x,delta*18)
 velocity.z=move_toward(velocity.z,target.z,delta*18)
 jump_buffer=maxf(0,jump_buffer-delta)
 coyote=.1 if is_on_floor() else maxf(0,coyote-delta)
 if jump_buffer>0 and coyote>0:
  velocity.y=6.2;jump_buffer=0;coyote=0
 elif not is_on_floor(): velocity.y-=20*delta
 else: velocity.y=-.1
 move_and_slide()
 for i in range(get_slide_collision_count()):
  var hit:=get_slide_collision(i);var body:=hit.get_collider()
  if body is NightProp and not body.freeze and not body.held:
   var push: Vector3=-hit.get_normal();push.y=0
   body.apply_central_impulse(push*minf(body.mass,1.8)*speed*delta*10)
 if was_airborne and is_on_floor():
  landing_offset=-.075 if motion else 0.0;step_player.pitch_scale=.65;step_player.play()
 was_airborne=not is_on_floor();landing_offset=lerpf(landing_offset,0,delta*9)
 if is_instance_valid(carried):
  var origin:=camera.global_position;var destination:=origin-camera.global_basis.z*1.6
  var query:=PhysicsRayQueryParameters3D.create(origin,destination,1);query.exclude=[get_rid(),carried.get_rid()]
  var obstacle:=get_world_3d().direct_space_state.intersect_ray(query)
  carried.carry_target=obstacle.position+obstacle.normal*.3 if obstacle else destination
  if carried.global_position.distance_to(origin)>3.5: drop_prop()
 if global_position.y < -5: global_position=Vector3(-6.2,0,8.5)
 if direction.length()>.1 and is_on_floor():
  walk_clock+=delta*(9 if speed>3 else 6)
  step_clock+=delta
  camera.position.y=1.65+landing_offset+(sin(walk_clock)*.018 if motion else 0.0)
  if step_clock>(.32 if speed>3 else .48):
   step_clock=0;step_player.pitch_scale=randf_range(.78,1.05);step_player.play()
 else:
  camera.position.y=lerpf(camera.position.y,1.65+landing_offset,delta*8)

func prop_target() -> NightProp:
 var origin:=camera.global_position
 var query:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*2.5,3)
 query.exclude=[get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 return hit.collider as NightProp if hit and hit.collider is NightProp else null

func grab_prop() -> void:
 if is_instance_valid(carried): drop_prop();return
 carried=prop_target()
 if carried:
  carried.held=true;carried.sleeping=false;carried.add_collision_exception_with(self)
  carried.carry_target=carried.global_position

func drop_prop(throwing: bool=false) -> void:
 if not is_instance_valid(carried): carried=null;return
 var body:=carried;carried=null;body.held=false;body.remove_collision_exception_with(self)
 if throwing: body.apply_central_impulse(-camera.global_basis.z*body.mass*7+Vector3.UP*body.mass*.7)

func toggle_lamp() -> void:
 lamp_on=not lamp_on;lamp.visible=lamp_on

func reset_pose() -> void:
 drop_prop()
 global_position=Vector3(-6.2,0,8.5);rotation.y=0;camera.rotation=Vector3.ZERO;velocity=Vector3.ZERO
 jump_buffer=0;coyote=0;was_airborne=false;landing_offset=0
