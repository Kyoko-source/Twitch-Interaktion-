class_name NightProp
extends RigidBody3D

var title := "Spielzeug"
var held := false
var carry_target := Vector3.ZERO
var impact: AudioStreamPlayer3D
var cooldown := 0.0
var suspended_linear := Vector3.ZERO
var suspended_angular := Vector3.ZERO

func _ready() -> void:
 collision_layer=2;collision_mask=3;continuous_cd=true
 linear_damp=.35;angular_damp=.65
 contact_monitor=true;max_contacts_reported=3
 impact=AudioStreamPlayer3D.new();impact.stream=load("res://assets/step.ogg")
 impact.volume_db=-26;impact.unit_size=2;impact.max_distance=9;add_child(impact)
 body_entered.connect(_impact)

func _physics_process(delta: float) -> void:
 cooldown=maxf(0,cooldown-delta)
 if held and not freeze:
  sleeping=false
  var displacement:=carry_target-global_position
  apply_central_force((displacement*65-linear_velocity*12+Vector3.UP*9.8)*mass)
  apply_torque(-angular_velocity*mass*4)

func _impact(_other: Node) -> void:
 var speed:=linear_velocity.length()
 if speed<1.4 or cooldown>0 or freeze: return
 cooldown=.22;impact.volume_db=clampf(-29+speed*1.2,-29,-17)
 impact.pitch_scale=.65 if mass>.8 else 1.3;impact.play()

func suspend(value: bool) -> void:
 if freeze==value: return
 if value:
  suspended_linear=linear_velocity;suspended_angular=angular_velocity
  impact.stop()
 freeze=value
 if not value:
  linear_velocity=suspended_linear;angular_velocity=suspended_angular
