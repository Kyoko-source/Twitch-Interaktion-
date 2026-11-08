class_name DoorFailure
extends Node3D

signal finished
var figure: Dictionary
var audio: AudioStreamPlayer
var fill: OmniLight3D
var clock:=0.0
var running:=false
var shown:=0
var archive_mode:=false
var patrol_mode:=false
var attacker: Node3D
var claws: Array[Node3D]=[]
var sound_started:=false

func start(world: PlayWorld, camera: Camera3D) -> void:
 archive_mode=false;patrol_mode=false
 for child in get_children(): child.queue_free()
 if get_parent(): get_parent().remove_child(self)
 camera.add_child(self);transform=Transform3D.IDENTITY
 figure=HorrorFigures.clown(world,self);figure.root.position=Vector3(0,-1.96,-3.8)
 # An actual lit model approaches the camera; no full-screen face image.
 fill=OmniLight3D.new();fill.position=Vector3(.32,-.12,-.15);fill.light_color=Color("dfaa88");fill.light_energy=.9;fill.omni_range=5;add_child(fill)
 audio=AudioStreamPlayer.new();audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.stream=ScareBank.flat("clown_lunge");audio.volume_db=-5;add_child(audio)
 clock=0;running=true;sound_started=false;shown+=1;show()

func start_patrol(world: PlayWorld, camera: Camera3D) -> void:
 start(world,camera);patrol_mode=true;figure.root.hide();claws.clear()
 # The rebuilt ragged visitor: dislocated jaw, sewn-shut eyes, clawed hands.
 attacker=(load(CharacterFinish.visitor("door","pursuit")) as PackedScene).instantiate();add_child(attacker)
 attacker.position=Vector3(0,-1.74,-6.0)
 CharacterFinish.dynamic_only(attacker)
 for key in ["ArmL","ArmR"]:
  var arm:=attacker.find_child(key,true,false) as Node3D
  if arm: claws.append(arm)
 # Lit from below and in front, like a torch dropped at its feet.
 fill.position=Vector3(.1,-1.1,-.35)
 audio.stream=ScareBank.flat("door_death");audio.volume_db=0;audio.pitch_scale=1.0

func _patrol_tick() -> void:
 _cue_sound(.13)
 var t:=clampf((clock-.13)/.22,0,1)
 var lunge:=1-pow(1-t,5)
 # While screaming in your face it does not hold still: hard stutter-jerks
 # every few frames plus a fast, violent head shake.
 var scream:=clampf((clock-.3)/.1,0,1)*(1-clampf((clock-1.1)/.15,0,1))
 var step:=floorf(clock*14.0)
 var jerk:=Vector3(sin(step*12.9898)*.06,sin(step*78.233)*.035,0)*scream
 attacker.position=Vector3(sin(clock*41)*.03,-1.74+sin(t*PI)*.18,lerpf(-6.0,-.52,lunge))+jerk
 attacker.rotation=Vector3(.06*sin(clock*23)-.12*lunge,.05*sin(clock*29)+.04*scream*sin(clock*47),-.10+.06*sin(clock*31)+.05*scream*sin(clock*53))
 # Claws come in wide from both sides of the view, not straight into the lens.
 for i in range(claws.size()):
  claws[i].rotation.x=-.95*lunge+.15*scream*sin(clock*39+i)
  claws[i].rotation.z=(-1 if i==0 else 1)*(.95*lunge+.1*scream*sin(clock*33))
 fill.light_color=Color("d9c8b0")
 if clock<.13: fill.light_energy=.03
 else: fill.light_energy=(.32 if int(clock*22)%3 else .06) if clock<.75 else .22+.1*sin(clock*60)
 if clock>=1.32: running=false;hide();audio.stop();finished.emit()

func start_archive(world: PlayWorld, camera: Camera3D) -> void:
 start(world,camera);archive_mode=true
 audio.stream=load("res://assets/finale/cook-scream.wav");audio.volume_db=-.5

func _archive_tick() -> void:
 _cue_sound(.055)
 var t:=clampf((clock-.055)/.19,0,1)
 figure.root.position=Vector3(sin(clock*48)*.026,-1.91+sin(t*PI)*.12,lerpf(-3.8,-.54-HorrorFigures.HEAD_REACH,1-pow(1-t,4)))
 figure.head.rotation=Vector3(-.07+sin(clock*27)*.045,sin(clock*21)*.045,-.16+sin(clock*34)*.04)
 fill.light_color=Color("e4b5a3");fill.light_energy=.13 if clock<.055 else 1.65 if clock<.5 else .85
 HorrorFigures.strike(figure,1.);HorrorFigures.gape(figure,t)
 figure.spoon.hide();figure.bowl.hide()
 if clock>=1.08: running=false;hide();audio.stop();finished.emit()

func tick(delta: float) -> void:
 if not running: return
 clock+=delta
 if patrol_mode: _patrol_tick();return
 if archive_mode: _archive_tick();return
 _cue_sound(.12)
 if clock<.12:
  figure.root.position.z=-3.8;fill.light_energy=.15
 elif clock<.42:
  var t:=clampf((clock-.12)/.3,0,1);figure.root.position=Vector3(sin(clock*21)*.045,-1.91+sin(t*PI)*.1,lerpf(-3.8,-.68-HorrorFigures.HEAD_REACH,1-pow(1-t,3)))
  figure.head.rotation=Vector3(.04,sin(clock*18)*.08,-.13);fill.light_energy=.9
 elif clock<.78:
  figure.root.position=Vector3(sin(clock*34)*.018,-1.91,-.68-HorrorFigures.HEAD_REACH);figure.head.rotation.z=-.13+sin(clock*15)*.035
 else:
  figure.root.position.z=lerpf(-.68-HorrorFigures.HEAD_REACH,-2.5,clampf((clock-.78)/.35,0,1));fill.light_energy=maxf(0,.9*(1-(clock-.78)/.35))
 HorrorFigures.strike(figure,1.);HorrorFigures.gape(figure,clampf((clock-.12)/.3,0,1))
 figure.spoon.hide();figure.bowl.hide()
 if clock>=1.16:
  running=false;hide();audio.stop();finished.emit()

func _cue_sound(at: float) -> void:
 # Cross the timeline marker once. A slow frame must not skip the entire
 # narrow sound window, or restart a short voice while the figure is visible.
 if clock>=at and not sound_started:
  sound_started=true;ScareBank.play_flat(audio)
