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

func start(world: PlayWorld, camera: Camera3D) -> void:
 archive_mode=false;patrol_mode=false
 for child in get_children(): child.queue_free()
 if get_parent(): get_parent().remove_child(self)
 camera.add_child(self);transform=Transform3D.IDENTITY
 figure=HorrorFigures.clown(world,self);figure.root.position=Vector3(0,-1.96,-3.8)
 # An actual lit model approaches the camera; no full-screen face image.
 fill=OmniLight3D.new();fill.position=Vector3(.32,-.12,-.15);fill.light_color=Color("dfaa88");fill.light_energy=.9;fill.omni_range=5;add_child(fill)
 audio=AudioStreamPlayer.new();audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.stream=load("res://assets/scares-v260/dry-impact.wav");audio.volume_db=-5;add_child(audio)
 clock=0;running=true;shown+=1;show()

func start_patrol(world: PlayWorld, camera: Camera3D) -> void:
 start(world,camera);patrol_mode=true;figure.root.hide();claws.clear()
 attacker=(load("res://assets/creatures/night-visitor-v21.glb") as PackedScene).instantiate();add_child(attacker)
 attacker.position=Vector3(0,-1.7,-4.8)
 for mesh in attacker.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var m:=mesh.get_active_material(surface) as StandardMaterial3D
   if m:
    m=m.duplicate();m.albedo_texture=load("res://assets/aged-plaster.png");m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*5;m.normal_enabled=true;m.normal_texture=world.atmosphere.micro_normal;m.normal_scale=.45;m.roughness=.8;mesh.set_surface_override_material(surface,m)
 var old_head:=attacker.find_child("HeadRig",true,false) as Node3D
 if old_head: old_head.hide()
 var head: Node3D=(load("res://assets/passage-v280/passage-head.glb") as PackedScene).instantiate()
 attacker.add_child(head);head.position=Vector3(0,1.95,.02)
 for key in ["ArmL","ArmR"]:
  var arm:=attacker.find_child(key,true,false) as Node3D
  if arm: claws.append(arm)
 audio.stream=load("res://assets/scares-v260/ragged-scream.wav");audio.volume_db=-2.5;audio.pitch_scale=.86

func _patrol_tick() -> void:
 if clock>.13 and clock<.30 and not audio.playing: audio.play()
 var t:=clampf((clock-.13)/.29,0,1)
 attacker.position=Vector3(sin(clock*37)*.045,-1.74+sin(t*PI)*.22,lerpf(-4.8,-.68,1-pow(1-t,4)))
 attacker.rotation=Vector3(.05*sin(clock*23),.035*sin(clock*29),-.13+.04*sin(clock*31))
 for i in range(claws.size()): claws[i].rotation.x=-1.25*t;claws[i].rotation.z=(-1 if i==0 else 1)*.45*t
 fill.light_color=Color("c6c9b9");fill.light_energy=.05 if clock<.13 else 1.25 if clock<.6 else .65
 if clock>=1.32: running=false;hide();audio.stop();finished.emit()

func start_archive(world: PlayWorld, camera: Camera3D) -> void:
 start(world,camera);archive_mode=true
 audio.stream=load("res://assets/finale/cook-scream.wav");audio.volume_db=-.5

func _archive_tick() -> void:
 if clock>.055 and not audio.playing and clock<.3: audio.play()
 var t:=clampf((clock-.055)/.19,0,1)
 figure.root.position=Vector3(sin(clock*48)*.026,-1.91+sin(t*PI)*.12,lerpf(-3.8,-.54,1-pow(1-t,4)))
 figure.head.rotation=Vector3(-.07+sin(clock*27)*.045,sin(clock*21)*.045,-.16+sin(clock*34)*.04)
 fill.light_color=Color("e4b5a3");fill.light_energy=.13 if clock<.055 else 1.65 if clock<.5 else .85
 var hand:=Vector3(-.16,1.75,.48)
 HorrorFigures.link(figure.upper,Vector3(-.28,1.48,0),Vector3(-.4,1.7,.15));HorrorFigures.link(figure.forearm,Vector3(-.4,1.7,.15),hand);figure.hand.position=hand
 figure.spoon.hide();figure.bowl.hide()
 if clock>=1.08: running=false;hide();audio.stop();finished.emit()

func tick(delta: float) -> void:
 if not running: return
 clock+=delta
 if patrol_mode: _patrol_tick();return
 if archive_mode: _archive_tick();return
 if clock<.12:
  figure.root.position.z=-3.8;fill.light_energy=.15
 elif clock<.42:
  if not audio.playing: audio.play()
  var t:=clampf((clock-.12)/.3,0,1);figure.root.position=Vector3(sin(clock*21)*.045,-1.91+sin(t*PI)*.1,lerpf(-3.8,-.68,1-pow(1-t,3)))
  figure.head.rotation=Vector3(.04,sin(clock*18)*.08,-.13);fill.light_energy=.9
 elif clock<.78:
  figure.root.position=Vector3(sin(clock*34)*.018,-1.91,-.68);figure.head.rotation.z=-.13+sin(clock*15)*.035
 else:
  figure.root.position.z=lerpf(-.68,-2.5,clampf((clock-.78)/.35,0,1));fill.light_energy=maxf(0,.9*(1-(clock-.78)/.35))
 var hand:=Vector3(-.22,1.65,.4)
 HorrorFigures.link(figure.upper,Vector3(-.28,1.48,0),Vector3(-.4,1.7,.15));HorrorFigures.link(figure.forearm,Vector3(-.4,1.7,.15),hand);figure.hand.position=hand
 figure.spoon.hide();figure.bowl.hide()
 if clock>=1.16:
  running=false;hide();audio.stop();finished.emit()
