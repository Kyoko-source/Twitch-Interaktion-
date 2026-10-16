class_name NightProp
extends RigidBody3D

var title := "Spielzeug"
var held := false:
 set(value):
  held=value;lock_rotation=value
  cooldown=.35 if value else .06
  if value:
   angular_velocity=Vector3.ZERO
   if impact: impact.stop()
var carry_target := Vector3.ZERO
var impact: AudioStreamPlayer3D
var cooldown := .6
var impact_count := 0
var previous_speed := 0.0
var suspended_linear := Vector3.ZERO
var suspended_angular := Vector3.ZERO

func _ready() -> void:
 collision_layer=2;collision_mask=3;continuous_cd=true
 linear_damp=.35;angular_damp=.65
 contact_monitor=true;max_contacts_reported=3
 var sound:="rubber" if title=="Spielball" else "wood" if title=="Holzbaustein" else "cloth" if title=="Stoffhase" else "plastic"
 impact=AudioStreamPlayer3D.new();impact.stream=load("res://assets/polish/impact-"+sound+".wav")
 impact.volume_db=-26;impact.unit_size=2;impact.max_distance=9;add_child(impact)
 body_entered.connect(_impact)

func _physics_process(delta: float) -> void:
 cooldown=maxf(0,cooldown-delta)
 previous_speed=linear_velocity.length()
 if held and not freeze:
  sleeping=false
  var displacement:=carry_target-global_position
  apply_central_force((displacement.limit_length(.75)*65-linear_velocity*16+Vector3.UP*9.8)*mass)

func _impact(_other: Node) -> void:
 var speed:=maxf(previous_speed,linear_velocity.length())
 if held or speed<1.8 or cooldown>0 or freeze or impact.playing: return
 cooldown=.35;impact.volume_db=clampf(-29+speed*.8,-29,-22)
 impact.pitch_scale=randf_range(.94,1.06);impact.play();impact_count+=1

func suspend(value: bool) -> void:
 if freeze==value: return
 if value:
  suspended_linear=linear_velocity;suspended_angular=angular_velocity
  impact.stop()
 freeze=value
 if not value:
  linear_velocity=suspended_linear;angular_velocity=suspended_angular
