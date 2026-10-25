class_name NightGuard
extends CharacterBody3D

var camera: Camera3D
var lamp: SpotLight3D
var active := false
var sensitivity := 0.0022
var motion := true
var base_fov:=75.0
var invert_y:=false
var walk_clock := 0.0
var step_clock := 0.0
var step_player: AudioStreamPlayer
var lamp_on := true
var torch_body: GuardTorch
var carried: NightProp
var jump_buffer := 0.0
var coyote := 0.0
var landing_offset := 0.0
var was_airborne := false
var fright := 0.0
var bounce_speed := 6.2
var crouching:=false
var capsule: CapsuleShape3D
var collider: CollisionShape3D
var stand_clearance: CapsuleShape3D
var crawl_sound: AudioStream
var look_warmup:=0.0
var capture_motion_pending:=false
var surface_sounds: Dictionary={}
var surface_name:="concrete"
var last_step_variant:=-1
var footstep_count:=0
var equipment: GuardEquipment

func _ready() -> void:
 var shape:=CapsuleShape3D.new();shape.radius=.28;shape.height=1.7
 var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=.85;add_child(collision)
 capsule=shape;collider=collision;stand_clearance=CapsuleShape3D.new();stand_clearance.radius=.28;stand_clearance.height=.65
 camera=Camera3D.new();camera.fov=base_fov;camera.near=.06;camera.far=70;camera.position.y=1.65;add_child(camera)
 lamp=SpotLight3D.new();lamp.light_color=Color("fff1cc");lamp.light_energy=4.2;lamp.spot_range=22;lamp.spot_angle=24;lamp.spot_angle_attenuation=1.1;lamp.shadow_enabled=true;lamp.shadow_bias=.025;lamp.position=Vector3(.18,-.1,-.12);camera.add_child(lamp)
 torch_body=GuardTorch.new();camera.add_child(torch_body);torch_body.build(lamp)
 equipment=GuardEquipment.new();add_child(equipment);equipment.build(self)
 step_player=AudioStreamPlayer.new();step_player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;step_player.stream=load(FootSurfaces.ROOT+"footstep_concrete_000.ogg");step_player.volume_db=-19;add_child(step_player)
 crawl_sound=load("res://assets/ambience/crawl-contact.wav")
 for surface in FootSurfaces.TYPES:
  var sounds: Array[AudioStream]=[]
  for i in range(5): sounds.append(load(FootSurfaces.ROOT+"footstep_"+surface+"_%03d.ogg"%i))
  surface_sounds[surface]=sounds

func capture() -> void:
 active=true
 look_warmup=.12
 capture_motion_pending=true
 torch_body.show()
 # A long phone call can outlive the browser's user-activation window.
 # Wait for the next real click instead of issuing a denied pointer-lock request.
 var can_lock:=not OS.has_feature("web") or bool(JavaScriptBridge.eval("navigator.userActivation?.isActive===true"))
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if ((OS.has_feature("editor") or OS.has_feature("qa")) and "--render-qa" in OS.get_cmdline_user_args()) or not can_lock else Input.MOUSE_MODE_CAPTURED

func release() -> void:
 drop_prop()
 active=false;velocity=Vector3.ZERO;camera.rotation.z=0;camera.fov=base_fov;step_player.stop()
 jump_buffer=0;coyote=0
 torch_body.hide()
 equipment.stop()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
 if active and event.is_action_pressed("jump"): jump_buffer=.14
 if active and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  apply_mouse_look(event.relative)

func apply_mouse_look(relative: Vector2) -> void:
 # Pointer lock can dispatch its first synthetic recenter after a slow WebGL
 # frame, once the time-based warmup has elapsed. Never turn on that event.
 if capture_motion_pending: capture_motion_pending=false;return
 if look_warmup>0: return
 rotate_y(-relative.x*sensitivity)
 camera.rotation.x=clampf(camera.rotation.x-relative.y*sensitivity*(-1 if invert_y else 1),-1.35,1.35)

func _physics_process(delta: float) -> void:
 if not active: return
 look_warmup=maxf(0,look_warmup-delta)
 var low:=Input.is_action_pressed("crouch")
 if crouching and not low:
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=stand_clearance;query.transform=Transform3D(global_basis,global_position+Vector3(0,1.39,0));query.collision_mask=1;query.exclude=[get_rid()];query.margin=.005
  low=not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
 set_crouch(low)
 var eye_height:=.8 if crouching else 1.65
 var direction:=Input.get_vector("left","right","forward","back")
 var aim:=transform.basis*Vector3(direction.x,0,direction.y)
 var speed:=1.35 if crouching else 4.5 if Input.is_action_pressed("sprint") else 2.8
 var target:=aim*speed
 velocity.x=move_toward(velocity.x,target.x,delta*18)
 velocity.z=move_toward(velocity.z,target.z,delta*18)
 jump_buffer=maxf(0,jump_buffer-delta)
 coyote=.1 if is_on_floor() else maxf(0,coyote-delta)
 if jump_buffer>0 and coyote>0 and not crouching:
  velocity.y=bounce_speed;jump_buffer=0;coyote=0
 elif not is_on_floor(): velocity.y-=20*delta
 else: velocity.y=-.1
 move_and_slide()
 bounce_speed=6.2
 camera.rotation.z=sin(Time.get_ticks_msec()*.055)*fright*.035 if motion else 0.0
 camera.fov=base_fov+fright*5 if motion else base_fov
 # Close jumping faces otherwise leave the narrow torch cone entirely. The
 # brief spill follows the existing scare pulse and returns to the normal beam.
 torch_body.tick(delta,lamp_on,fright)
 equipment.tick(self,delta)
 for i in range(get_slide_collision_count()):
  var hit:=get_slide_collision(i);var body:=hit.get_collider()
  if hit.get_normal().y>.6 and body.has_meta("bounce_speed"): bounce_speed=float(body.get_meta("bounce_speed"))
  if body is NightProp and not body.freeze and not body.held:
   var push: Vector3=-hit.get_normal();push.y=0
   body.apply_central_impulse(push*minf(body.mass,1.8)*speed*delta*10)
 if was_airborne and is_on_floor():
  landing_offset=-.075 if motion else 0.0;play_step(true)
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
  camera.position.y=lerpf(camera.position.y,eye_height+landing_offset+(sin(walk_clock)*(.009 if crouching else .018) if motion else 0.0),delta*12)
  if step_clock>(.75 if crouching else .32 if speed>3 else .48):
   step_clock=0;play_step()
 else:
  camera.position.y=lerpf(camera.position.y,eye_height+landing_offset,delta*12)

func prop_target() -> NightProp:
 var origin:=camera.global_position
 var query:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*2.5,3)
 query.exclude=[get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 return hit.collider as NightProp if hit and hit.collider is NightProp else null

func play_step(landing: bool=false) -> void:
 surface_name=FootSurfaces.at(self)
 var variant:=randi_range(0,3)
 if variant>=last_step_variant: variant+=1
 last_step_variant=variant;footstep_count+=1
 step_player.stream=crawl_sound if crouching and surface_name=="plastic" else surface_sounds[surface_name][variant]
 step_player.volume_db=(-23 if crouching else -16 if landing else -20)+(-2 if surface_name=="metal" else 0)
 step_player.pitch_scale=randf_range(.88,.97) if landing else randf_range(.96,1.05)
 step_player.play()
 if active: equipment.step(Vector2(velocity.x,velocity.z).length()>3.0,landing)

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
 set_crouch(false)
 drop_prop()
 global_position=Vector3(-6.2,0,8.5);rotation.y=0;camera.rotation=Vector3.ZERO;velocity=Vector3.ZERO
 jump_buffer=0;coyote=0;was_airborne=false;landing_offset=0;fright=0;bounce_speed=6.2

func set_crouch(value: bool) -> void:
 crouching=value
 if capsule: capsule.height=.95 if value else 1.7;collider.position.y=capsule.height*.5
