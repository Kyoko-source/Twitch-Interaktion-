class_name NightTerrors
extends Node3D

# Every encounter has a distinct physical anchor and a bounded, one-shot timeline.
const SCENARIOS:={
 "reception_peeker":{"p":Vector3(-8.4,0,4.2),"mode":"peek","zone":"Empfang"},
 "reception_charge":{"p":Vector3(-5.7,0,1.0),"mode":"pursuit","zone":"Empfang"},
 "reception_queue":{"p":Vector3(-8.2,0,7.2),"mode":"queue","zone":"Empfang"},
 "pit_hands":{"p":Vector3(3.6,.3,7.1),"mode":"hands","zone":"Bällebad"},
 "frame_stalker":{"p":Vector3(2.0,.31,2.2),"mode":"crawl","zone":"Bällebad"},
 "slide_crawler":{"p":Vector3(3.7,0,10.9),"mode":"crawl","zone":"Bällebad"},
 "party_portrait":{"p":Vector3(13.3,0,.65),"mode":"pursuit","zone":"Party Raum"},
 "party_guests":{"p":Vector3(11.5,0,-6.9),"mode":"queue","zone":"Party Raum"},
 "cake_mouth":{"p":Vector3(10.2,.87,-7.0),"mode":"mouth","zone":"Party Raum"},
 "corridor_crossing":{"p":Vector3(-6.1,0,-6.6),"mode":"crossing","zone":"Wartungsgang"},
 "service_pursuit":{"p":Vector3(-7.7,0,-8.1),"mode":"pursuit","zone":"Wartungsgang"},
 "service_ceiling":{"p":Vector3(-8.9,3.9,-5.0),"mode":"ceiling","zone":"Wartungsgang"},
 "fridge_occupant":{"p":Vector3(-11.0,0,-20.4),"mode":"peek","zone":"Küche"},
 "pot_arms":{"p":Vector3(-13.35,1.22,-19.25),"mode":"hands","zone":"Küche"},
 "kitchen_double":{"p":Vector3(-11.1,0,-15.3),"mode":"pursuit","zone":"Küche"},
 "screen_visitor":{"p":Vector3(2.3,0,-17.7),"mode":"pursuit","zone":"Kino"},
 "cinema_last_row":{"p":Vector3(-5.65,0,-20.25),"mode":"pursuit","zone":"Kino"},
 "vent_strike":{"p":Vector3(-1.3,1.3,-20.15),"mode":"vent","zone":"Kino"},
 "tube_chase":{"p":Vector3.ZERO,"mode":"tube","zone":"Krabbelröhre"},
 "tube_window_hands":{"p":Vector3.ZERO,"mode":"window","zone":"Krabbelröhre"}
}
var w: PlayWorld
var id:="none"
var spec: Dictionary={}
var actor: CharacterBody3D
var visual: Node3D
var arms: Array[Node3D]=[]
var echoes: Array[Node3D]=[]
var marker: Node3D
var audio: AudioStreamPlayer3D
var footsteps: AudioStreamPlayer3D
var elapsed:=0.0
var attack:=0.0
var triggered:=false
var finished:=false
var shock:=0.0
var origin:=Vector3.ZERO
var vent_origin:=Vector3.ZERO
var path_s:=0.0
var window_normal:=Vector3.ZERO

func build(world: PlayWorld) -> void:
 w=world;name="NightTerrors"
 audio=AudioStreamPlayer3D.new();audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.max_distance=20;audio.unit_size=3;audio.volume_db=-14;add_child(audio)
 audio.stream=load("res://assets/annex/clown-sting.wav")
 footsteps=AudioStreamPlayer3D.new();footsteps.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;footsteps.max_distance=13;footsteps.unit_size=2;footsteps.volume_db=-14;add_child(footsteps)
 var steps: AudioStreamWAV=load("res://assets/ambience-v193/ghost-run.wav").duplicate();steps.loop_mode=AudioStreamWAV.LOOP_FORWARD;steps.loop_end=int(steps.get_length()*steps.mix_rate);footsteps.stream=steps

func configure(value: String) -> void:
 id=value
 if not SCENARIOS.has(id): return
 spec=SCENARIOS[id];origin=spec.p;vent_origin=w.room_horror.creature.position
 var track: String="croc-snap.wav" if spec.mode in ["hands","window"] else "rabbit-scare.wav" if spec.mode in ["peek","mouth"] else "party-burst.wav" if spec.mode in ["ceiling","vent"] else "annex/clown-sting.wav"
 audio.stream=load("res://assets/"+track);audio.pitch_scale=.68 if spec.mode in ["pursuit","tube"] else .82 if spec.mode=="ceiling" else 1.0
 actor=CharacterBody3D.new();actor.name="EncounterBody";actor.collision_layer=0;actor.collision_mask=1;add_child(actor);actor.position=origin
 visual=(load("res://assets/creatures/night-visitor-v21.glb") as PackedScene).instantiate();visual.name="ArticulatedVisitor";actor.add_child(visual)
 for mesh in visual.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for surface in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   if material:
    material=material.duplicate();mesh.set_surface_override_material(surface,material)
    material.albedo_texture=load("res://assets/aged-plaster.png");material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*4
    material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.34
    material.roughness=.98;material.metallic_specular=.08
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.75;shape.shape=capsule;shape.position.y=.91;actor.add_child(shape)
 for key in ["ArmL","ArmR"]:
  var arm:=visual.find_child(key,true,false) as Node3D
  if arm: arms.append(arm)
 if spec.mode in ["crawl","tube"]:
  visual.rotation.x=1.25;visual.position.y=.20;visual.scale=Vector3.ONE*.67;capsule.height=.60;shape.position.y=.4
  var head_rig:=visual.find_child("HeadRig",true,false) as Node3D
  if head_rig: head_rig.rotation.x=-1.25
 elif spec.mode=="ceiling":
  visual.rotation.z=PI;shape.disabled=true
  w.tube(self,Vector3(origin.x,7.29,origin.z),origin-Vector3(0,.4,0),.009,w.materials.fabric)
 elif spec.mode in ["hands","window"]:
  for child in visual.find_children("*","MeshInstance3D",true,false): child.visible=child.name.begins_with("Arm")
  visual.rotation.z=PI;visual.position.y=1.0;shape.disabled=true
  if id=="pot_arms": visual.scale.x=.65
 elif spec.mode=="mouth":
  visual.scale=Vector3.ONE*.70;visual.position.y=-1.08;shape.disabled=true
  for child in visual.find_children("*","MeshInstance3D",true,false):
   if child.name.begins_with("Arm") or child.name.begins_with("Leg") or child.name=="Torso": child.hide()
 elif spec.mode=="vent": actor.hide();shape.disabled=true
 if spec.mode=="queue":
  for offset in [Vector3(.9,0,.8),Vector3(-.8,0,1.15)]:
   var echo:=visual.duplicate() as Node3D;echo.position=origin+offset;add_child(echo);echo.rotation.y=.7+echo.position.x;echoes.append(echo)
 if spec.mode in ["tube","window"]:
  path_s=5.0 if spec.mode=="tube" else 11.8
  actor.position=CrawlTubes.route(path_s)+Vector3(0,-.76,0) if spec.mode=="tube" else CrawlTubes.surface(path_s,PI,CrawlTubes.RADIUS+.13)
  if spec.mode=="window":
   window_normal=(actor.position-CrawlTubes.route(path_s)).normalized()
   visual.quaternion=Quaternion(Vector3.UP,window_normal);visual.scale=Vector3.ONE*.65;visual.position=-window_normal*.42
  origin=actor.position;actor.hide()
 # The clawed remnant stays after the moving encounter: a fair visible clue.
 marker=Node3D.new();marker.name="EncounterRemnant";marker.position=origin;add_child(marker)
 var stain:=w.mat(Color("251410"),null,.97)
 for k in range(5):
  var a:=Vector3(-.18+k*.075,.026,-.1);w.tube(marker,a,a+Vector3(.035,0,.5+sin(k)*.1),.009,stain)
 if spec.mode=="ceiling": marker.position.y=0
 if spec.mode=="vent": marker.position=Vector3(-1.3,.025,-20.15)
 if spec.mode in ["tube","window"]: marker.position=CrawlTubes.route(path_s)+Vector3(0,-.74,0);marker.hide()

func tick(delta: float, active: bool, player: NightGuard) -> void:
 audio.stream_paused=not active
 footsteps.stream_paused=not active
 if spec.is_empty(): return
 var in_tube:=w.tubes.contains(player.position)
 if spec.mode in ["tube","window"]:
  actor.visible=in_tube;marker.visible=in_tube
 if not active: return
 elapsed+=delta;shock=move_toward(shock,0,delta*2.2)
 var target:=actor.position+Vector3(0,1.4,0)
 if spec.mode in ["hands","mouth","window","tube"]: target=actor.position+Vector3(0,.35,0)
 if spec.mode=="crawl": target=actor.position+Vector3(0,.70,0)
 if spec.mode=="window": target=actor.position
 if spec.mode=="ceiling": target=actor.position-Vector3(0,1.6,0)
 if spec.mode=="vent": target=w.room_horror.creature.position+Vector3(0,-1.5,.7)
 var eligible:=in_tube if spec.mode in ["tube","window"] else true
 if not triggered and elapsed>.8 and eligible and w.encounters.visible_to(player,target,5.4):
  triggered=true;attack=0;audio.position=target;audio.play();shock=.85
 if not triggered:
  visual.rotation.y=sin(elapsed*.53)*.12
  return
 if finished: footsteps.stop();return
 footsteps.position=actor.position
 if spec.mode in ["pursuit","crawl","crossing","tube"] and not footsteps.playing: footsteps.play()
 attack+=delta
 if spec.mode in ["pursuit","crawl","crossing","peek"]:
  var to_player:=player.position-actor.position;to_player.y=0
  var duration:=4.7 if spec.mode in ["pursuit","crawl"] else 1.3
  var clearance:=1.85 if spec.mode=="crawl" else .85
  if attack<duration and to_player.length()>clearance:
   var direction:=to_player.normalized();var speed:=2.6 if spec.mode=="pursuit" else 3.9 if spec.mode=="crossing" else 1.9
   var collision:=actor.move_and_collide(direction*minf(speed*delta,maxf(0,to_player.length()-clearance)))
   if collision:
    var slide:=direction.slide(collision.get_normal())
    if slide.length()<.1: slide=Vector3(direction.z,0,-direction.x)
    actor.move_and_collide(slide*speed*delta)
   actor.rotation.y=atan2(direction.x,direction.z)
   visual.position.y=(.20 if spec.mode=="crawl" else 0)+absf(sin(attack*12))*.025
   for i in range(arms.size()): arms[i].rotation.x=sin(attack*11+i*PI)*.16
  elif attack>duration:
   finished=true
   # Hold the contorted visitor as an unmistakable clue, never replay the sting.
   visual.rotation.z=.17;visual.position.y-=.12
 elif spec.mode=="tube":
  if in_tube:
   var nearest:=CrawlTubes.nearest(player.position);path_s=move_toward(path_s,maxf(.9,nearest.s-1.7),delta*1.5)
   actor.position=CrawlTubes.route(path_s)+Vector3(0,-.76,0)
   var direction:=CrawlTubes.tangent(path_s);actor.rotation.y=atan2(direction.x,direction.z)
  if attack>4.8: finished=true
 elif spec.mode=="vent":
  var pulse:=sin(clampf(attack/1.6,0,1)*PI)
  w.room_horror.creature.position=vent_origin+Vector3(0,-pulse*.52,pulse*.30)
  w.room_horror.creature.rotation.z=sin(attack*12)*pulse*.055;shock=maxf(shock,pulse*.85)
  if attack>1.6: finished=true;w.room_horror.creature.position=vent_origin;w.room_horror.creature.rotation.z=.13
 else:
  var pulse:=sin(clampf(attack/1.6,0,1)*PI)
  if spec.mode=="window": visual.position=-window_normal*(.42+pulse*.02)
  else: visual.position.z=(pulse*.14 if spec.mode=="mouth" else -pulse*.45);visual.rotation.y=sin(attack*7)*pulse*.18
  if spec.mode=="mouth":
   var direction:=player.position-actor.position;actor.rotation.y=atan2(direction.x,direction.z)
  if spec.mode=="hands": visual.position.y=1.0+pulse*.28
  elif spec.mode=="mouth": visual.position.y=-1.08+pulse*.30
  elif spec.mode=="ceiling": visual.position.y=-pulse*.38
  if attack>1.6:
   finished=true
   if spec.mode=="mouth": visual.position.y=-.88

func snapshot() -> Dictionary:
 return {"id":id,"elapsed":elapsed,"triggered":triggered,"finished":finished,"attack":attack,"shock":shock,"position":[actor.position.x,actor.position.y,actor.position.z] if is_instance_valid(actor) else [],"visible":is_instance_valid(actor) and actor.visible,"zone":spec.get("zone",""),"mode":spec.get("mode",""),"audio":audio.playing,"paused":audio.stream_paused,"steps":footsteps.playing,"steps_paused":footsteps.stream_paused,"remnant":is_instance_valid(marker)}
