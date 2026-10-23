class_name NightEncounters
extends Node3D

var w: PlayWorld
var id := "none"
var elapsed := 0.0
var triggered := false
var finished := false
var attack_time := 0.0
var origin := Vector3.ZERO
var end := Vector3.ZERO
var shock := 0.0
var audio: AudioStreamPlayer3D
var face: Node3D
var baseline_bunny := Vector3.ZERO
var baseline_balloon := Vector3.ZERO
var clown_origin:=Vector3.ZERO
var clown_end:=Vector3.ZERO
var clown_rotation:=0.0

func build(world: PlayWorld) -> void:
 w=world
 baseline_bunny=w.atmosphere.horrors.bunny.position
 baseline_balloon=w.props.balloons.position
 audio=AudioStreamPlayer3D.new();audio.max_distance=25;audio.unit_size=6;audio.volume_db=-4;add_child(audio)
 audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 if w.native_art: audio.bus="Interior"
 face=Node3D.new();w.atmosphere.horrors.bunny.add_child(face);face.hide()

func configure(anomaly: String) -> void:
 id=anomaly
 # Every round owns a new controller. No wall-clock tweens: pause freezes
 # proximity checks, animation, audio and camera reaction at the same instant.
 for target in [w.atmosphere.horrors.bunny,w.props.inflatable_skin,w.props.balloons,w.atmosphere.horrors.horse]:
  for mesh in target.find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC

func visible_to(player: NightGuard, target: Vector3, distance: float) -> bool:
 var from:=player.camera.global_position;var direction:=target-from
 if direction.length()>distance: return false
 if -player.camera.global_basis.z.dot(direction.normalized())<.4: return false
 var query:=PhysicsRayQueryParameters3D.create(from,target,1);query.exclude=[player.get_rid()]
 var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
 return not hit or from.distance_to(hit.position)>direction.length()-.35

func tick(delta: float, active: bool, player: NightGuard) -> void:
 audio.stream_paused=not active
 if not active: return
 elapsed+=delta;shock=move_toward(shock,0,delta*2.8)
 if id=="clown_lunge":
  _clown(delta,player);return
 var bunny: Node3D=w.atmosphere.horrors.bunny
 if id=="balloons_follow":
  var target:=Vector3(clampf(player.position.x-8.5,-.5,9),0,clampf(player.position.z+8,-1,5))
  w.props.balloons.position=w.props.balloons.position.lerp(target,1-exp(-delta*.35))
 elif id=="horse_rocks":
  w.atmosphere.horrors.horse.rotation.x=sin(elapsed*2.7)*.22
 if id not in ["bunny_lunge","croc_snap","party_burst"]: return
 if not triggered and elapsed>1:
  var target: Vector3=bunny.global_position+Vector3(0,.7,0) if id=="bunny_lunge" else w.props.inflatable.to_global(Vector3(0,2,2.7)) if id=="croc_snap" else Vector3(8.5,1.5,-7)
  var proximity:=3.0 if id=="bunny_lunge" else 5.2 if id=="croc_snap" else 3.4
  if visible_to(player,target,proximity):
   triggered=true;origin=bunny.global_position;attack_time=0;shock=1
   audio.global_position=target
   audio.stream=load("res://assets/"+("scares-v260/gasp-snap.wav" if id=="bunny_lunge" else "scares-v260/bass-roar.wav" if id=="croc_snap" else "scares-v260/crowd-burst.wav"));audio.play()
   if id=="bunny_lunge":
    end=player.camera.global_position-player.camera.global_basis.z*.62-Vector3(0,.64,0);face.show()
   elif id=="party_burst": w.props.balloons.scale=Vector3.ONE*1.8
 if not triggered or finished: return
 attack_time+=delta
 if id=="bunny_lunge":
  if attack_time<.34:
   var t:=clampf(attack_time/.34,0,1);bunny.global_position=origin.lerp(end,1-pow(1-t,3))+Vector3.UP*sin(t*PI)*.5
   bunny.rotation.y=atan2(player.camera.global_position.x-bunny.global_position.x,player.camera.global_position.z-bunny.global_position.z)
   shock=maxf(shock,sin(t*PI)*.9)
  elif attack_time<.48: bunny.global_position=end
  elif attack_time<1.25:
   var t:=(attack_time-.48)/.77;bunny.global_position=end.lerp(origin+Vector3(.3,-.6,.3),t);bunny.rotation.z=sin(t*PI)*.25
  else: finished=true;face.hide()
 elif id=="croc_snap":
  var pulse:=sin(clampf(attack_time/.65,0,1)*PI)
  w.playground.set_croc_jaw(pulse*.46)
  w.props.inflatable_skin.position.z=pulse*.22
  if attack_time>.8:
   finished=true;w.playground.set_croc_jaw(.12);w.props.inflatable_skin.position.z=0
 else:
  w.props.balloons.rotation.z=sin(attack_time*13)*maxf(0,1-attack_time)*.25
  if attack_time>1.2: finished=true

func _clown(delta: float, player: NightGuard) -> void:
 var actor: Node3D=w.annex.clown.root
 if not triggered and elapsed>1 and visible_to(player,actor.global_position+Vector3(0,1.95,0),3):
  triggered=true;w.annex.scare=true;clown_origin=actor.position;clown_rotation=actor.rotation.y;attack_time=0
  clown_end=player.camera.global_position-player.camera.global_basis.z*.8-Vector3(0,1.85,0)
  audio.global_position=actor.global_position+Vector3(0,1.7,0);audio.stream=load("res://assets/scares-v260/ragged-scream.wav");audio.volume_db=-4;audio.play()
 if not triggered or finished: return
 attack_time+=delta
 if attack_time<.48:
  var t:=attack_time/.48;actor.position=clown_origin.lerp(clown_end,1-pow(1-t,3))+Vector3.UP*sin(t*PI)*.22
  actor.rotation.y=atan2(player.position.x-actor.position.x,player.position.z-actor.position.z);shock=maxf(shock,sin(t*PI)*.9)
 elif attack_time<.7: actor.position=clown_end
 elif attack_time<1.6:
  actor.position=clown_end.lerp(clown_origin,(attack_time-.7)/.9)
 else:
  actor.position=clown_origin;finished=true;w.annex.scare=false;w.annex.settled=true
