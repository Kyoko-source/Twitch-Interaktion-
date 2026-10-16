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

func _ready() -> void:
 var shape:=CapsuleShape3D.new();shape.radius=.28;shape.height=1.7
 var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=.85;add_child(collision)
 camera=Camera3D.new();camera.fov=75;camera.near=.06;camera.far=70;camera.position.y=1.65;add_child(camera)
 lamp=SpotLight3D.new();lamp.light_color=Color("fff1cc");lamp.light_energy=2.8;lamp.spot_range=22;lamp.spot_angle=26;lamp.spot_angle_attenuation=1.1;lamp.shadow_enabled=true;lamp.shadow_bias=.025;lamp.position=Vector3(.18,-.1,-.12);camera.add_child(lamp)
 # Physical handheld torch, attached to the camera, below the crosshair.
 var body:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.075;mesh.bottom_radius=.048;mesh.height=.3;body.mesh=mesh
 var material:=StandardMaterial3D.new();material.albedo_color=Color("252b2d");material.metallic=.8;material.roughness=.35;body.material_override=material;body.position=Vector3(.28,-.27,-.44);body.rotation.x=PI/2;camera.add_child(body)
 torch_body=body
 torch_body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 step_player=AudioStreamPlayer.new();step_player.stream=load("res://assets/step.ogg");step_player.volume_db=-19;add_child(step_player)

func capture() -> void:
 active=true
 torch_body.show()
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func release() -> void:
 active=false;velocity=Vector3.ZERO;step_player.stop()
 torch_body.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
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
 if not is_on_floor(): velocity.y-=20*delta
 else: velocity.y=-.1
 move_and_slide()
 if global_position.y < -5: global_position=Vector3(-6.2,0,8.5)
 if direction.length()>.1 and is_on_floor():
  walk_clock+=delta*(9 if speed>3 else 6)
  step_clock+=delta
  camera.position.y=1.65+(sin(walk_clock)*.018 if motion else 0.0)
  if step_clock>(.32 if speed>3 else .48):
   step_clock=0;step_player.pitch_scale=randf_range(.78,1.05);step_player.play()
 else:
  camera.position.y=lerpf(camera.position.y,1.65,delta*8)

func toggle_lamp() -> void:
 lamp_on=not lamp_on;lamp.visible=lamp_on

func reset_pose() -> void:
 global_position=Vector3(-6.2,0,8.5);rotation.y=0;camera.rotation=Vector3.ZERO;velocity=Vector3.ZERO
