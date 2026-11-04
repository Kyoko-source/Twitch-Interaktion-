class_name GuardPresence
extends Node

var guard: NightGuard
var breath: AudioStreamPlayer
var cloth: AudioStreamPlayer
var effort:=0.
var breath_clock:=0.
var cloth_clock:=0.
var motion_amount:=.65
var sound_amount:=.55
var previous_velocity:=Vector3.ZERO
var spring:=Vector3.ZERO
var spring_speed:=Vector3.ZERO
var offset:=Vector3.ZERO
var tilt:=Vector3.ZERO
var cloth_count:=0
var suspended:=true

func build(player: NightGuard) -> void:
 guard=player;name="PlayerBodyPresence"
 breath=AudioStreamPlayer.new();breath.name="NightguardBreathing";breath.stream=load("res://assets/player-v402/breathing.ogg");breath.stream.loop=true;breath.volume_db=-80;breath.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(breath)
 cloth=AudioStreamPlayer.new();cloth.name="UniformAgainstCrawlTube";cloth.stream=load("res://assets/polish/impact-cloth.wav");cloth.volume_db=-31;cloth.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(cloth)

func set_active(active: bool) -> void:
 if suspended and active:previous_velocity=Vector3(guard.velocity.x,0,guard.velocity.z)
 suspended=not active;breath.stream_paused=not active;cloth.stream_paused=not active

func tick(delta: float) -> void:
 if suspended:return
 var velocity:=Vector3(guard.velocity.x,0,guard.velocity.z)
 var speed:=velocity.length()
 effort=move_toward(effort,1. if speed>3.4 and guard.is_on_floor() else 0.,delta*(.17 if speed>3.4 else .055))
 breath_clock+=delta*(1.+effort*.8)
 var volume:=clampf(sound_amount,0.,1.)
 if effort>.06 and volume>0:
  if not breath.playing:breath.play()
  # Fatigue changes loudness only. Pitch shifting a close nasal recording makes
  # the guard sound like one of the creatures, especially during recovery.
  breath.volume_db=linear_to_db(volume)+lerpf(-23.,-10.,effort)
 else:breath.stop()
 cloth_clock=maxf(0.,cloth_clock-delta)
 var g:=guard.get_parent()
 var in_tube: bool=is_instance_valid(g.world) and (g.world.tubes.inside or g.world.tubes.contains(guard.position))
 if guard.crouching and in_tube and speed>.25 and cloth_clock<=0 and volume>0:
  cloth_clock=.76;cloth.pitch_scale=.93+float(cloth_count%3)*.06;cloth.volume_db=-28.+linear_to_db(volume);cloth.play();cloth_count+=1
 # A damped spring follows actual deceleration, including an abrupt stop.
 var local_accel:=guard.camera.global_basis.inverse()*((velocity-previous_velocity)/maxf(delta,.001));previous_velocity=velocity
 spring_speed+=local_accel.clamp(Vector3.ONE*-22.,Vector3.ONE*22.)*delta*.008
 var remaining:=minf(delta,.1)
 while remaining>0:
  var dt:=minf(remaining,.008);spring_speed+=(-spring*105.-spring_speed*15.)*dt;spring+=spring_speed*dt;remaining-=dt
 var amount:=motion_amount if guard.motion else 0.
 offset=spring.clamp(Vector3.ONE*-.022,Vector3.ONE*.022)*amount+Vector3(0,sin(breath_clock*TAU*.23)*effort*.0025,0)*amount
 tilt=Vector3(offset.z*.9,-offset.x*.7,-offset.x*.9)

func reset() -> void:
 effort=0.;spring=Vector3.ZERO;spring_speed=Vector3.ZERO;offset=Vector3.ZERO;tilt=Vector3.ZERO;previous_velocity=Vector3.ZERO;breath_clock=0.;cloth_clock=0.
 if breath:breath.stop()
 if cloth:cloth.stop()

func snapshot() -> Dictionary:
 return {"effort":effort,"breathing":breath.playing,"paused":suspended,"cloth":cloth_count,"motion":motion_amount,"sound":sound_amount,"offset":[offset.x,offset.y,offset.z]}
