class_name GuardTorch
extends Node3D

const MODEL:="res://assets/props/nightguard-torch.glb"
var lamp: SpotLight3D
var clock:=0.0
var wait:=26.0
var burst:=-1.0
var strength:=1.0
var count:=0
var rng:=RandomNumberGenerator.new()
var emitter: StandardMaterial3D

func build(light: SpotLight3D) -> void:
 lamp=light;rng.randomize();wait=rng.randf_range(20,42)
 var scene: PackedScene=load(MODEL);var model:=scene.instantiate();add_child(model)
 model.scale=Vector3.ONE*.78
 position=Vector3(.23,-.245,-.39);rotation=Vector3(-.035,-.09,-.08)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if mesh.name=="Emitter":
   emitter=(mesh.get_active_material(0) as StandardMaterial3D).duplicate();mesh.material_override=emitter

func trigger() -> void:
 if burst>=0: return
 burst=0;count+=1

func tick(delta: float, on: bool, fright: float) -> void:
 if on:
  clock+=delta;wait-=delta
  if wait<=0: trigger();wait=rng.randf_range(24,48)
  if burst>=0:
   burst+=delta
   strength=.12 if (burst<.065 or (burst>.14 and burst<.2) or (burst>.31 and burst<.35)) else .72 if burst<.45 else 1.0
   if burst>.58: burst=-1;strength=1
 else: strength=1
 lamp.light_energy=4.2*strength;lamp.spot_angle=24+fright*30
 if emitter: emitter.emission_energy_multiplier=(.6*strength if on else 0.0)
