class_name NightTerrors
extends Node3D

# Every encounter has a distinct physical anchor and a bounded, one-shot timeline.
const SCENARIOS:={
 "wc_stall_watcher":{"p":Vector3(23.5,.02,8.85),"mode":"peek","zone":"Kinder-WC","sound":"gasp-snap"},
 "wc_ceiling_guest":{"p":Vector3(24.0,3.03,7.15),"mode":"ceiling","zone":"Kinder-WC","ceiling":3.11,"sound":"metal-shriek"},
 "snackbar_visitor":{"p":Vector3(12.0,.02,-1.05),"mode":"ambush","zone":"Party Raum","sound":"ragged-scream"},
 "throne_guest":{"p":Vector3(13.4,.20,-10.97),"mode":"throne","zone":"Party Raum","sound":"crowd-burst"},
 "reception_counter_burst":{"p":Vector3(-7.25,0,6.35),"mode":"ambush","zone":"Empfang","sound":"gasp-snap"},
 "reception_overhead":{"p":Vector3(-4.8,3.2,6.7),"mode":"drop","zone":"Empfang","sound":"metal-shriek"},
 "pit_runner":{"p":Vector3(5.52,.02,6.2),"mode":"rush","zone":"Bällebad","sound":"bass-roar"},
 "frame_drop":{"p":Vector3(1.8,3.9,1.8),"mode":"drop","zone":"Bällebad","sound":"dry-impact"},
 "party_mascot_guest":{"p":Vector3(16.0,0,-.8),"mode":"ambush","zone":"Party Raum","sound":"crowd-burst"},
 "party_under_table":{"p":Vector3(10.5,0,-5.4),"mode":"crawl","zone":"Party Raum","sound":"crawl-scream"},
 "maintenance_blackout":{"p":Vector3(-6.8,0,-6.9),"mode":"ambush","zone":"Wartungsgang","sound":"ragged-scream"},
 "server_rush":{"p":Vector3(-13.2,0,-4.1),"mode":"rush","zone":"Wartungsgang","sound":"metal-shriek"},
 "kitchen_cupboard_face":{"p":Vector3(-15.5,.9,-21.7),"mode":"mouth","zone":"Küche","sound":"gasp-snap"},
 "kitchen_floor_crawler":{"p":Vector3(-14.9,0,-15.5),"mode":"crawl","zone":"Küche","sound":"crawl-scream"},
 "cinema_aisle_rush":{"p":Vector3(1.2,0,-17.65),"mode":"rush","zone":"Kino","sound":"bass-roar"},
 "cinema_seat_ambush":{"p":Vector3(-2.2,0,-14.35),"mode":"ambush","zone":"Kino","sound":"crowd-burst"},
 "tube_burst":{"p":Vector3.ZERO,"mode":"tube","zone":"Krabbelröhre","sound":"window-hit"},
 "reception_peeker":{"p":Vector3(-9.15,.02,6.55),"mode":"peek","zone":"Empfang"},
 "reception_charge":{"p":Vector3(-5.7,0,1.0),"mode":"pursuit","zone":"Empfang"},
 "reception_queue":{"p":Vector3(-8.1,.02,9.5),"mode":"queue","zone":"Empfang"},
 "pit_hands":{"p":Vector3(3.6,.3,7.1),"mode":"hands","zone":"Bällebad"},
 "frame_stalker":{"p":Vector3(2.0,.31,2.2),"mode":"crawl","zone":"Bällebad"},
 "slide_crawler":{"p":Vector3(3.7,0,10.9),"mode":"crawl","zone":"Bällebad"},
 "party_portrait":{"p":Vector3(9.3,0,-.35),"mode":"pursuit","zone":"Party Raum"},
 "party_guests":{"p":Vector3(12.4,.02,-5.5),"mode":"queue","zone":"Party Raum"},
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
var anticipation: AudioStreamPlayer3D
var primed:=false
var elapsed:=0.0
var attack:=0.0
var triggered:=false
var finished:=false
var shock:=0.0
var origin:=Vector3.ZERO
var path_s:=0.0
var window_normal:=Vector3.ZERO
var warning_light: OmniLight3D
var tether: MeshInstance3D
var lunge_at:=-1.0
var lunge_from:=Vector3.ZERO
var scream: AudioStreamPlayer
var face_light: OmniLight3D

func build(world: PlayWorld) -> void:
 w=world;name="NightTerrors"
 audio=AudioStreamPlayer3D.new();audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.max_distance=20;audio.unit_size=6;audio.volume_db=-4;add_child(audio)
 audio.stream=load("res://assets/annex/clown-sting.wav")
 scream=AudioStreamPlayer.new();scream.name="FaceScream";scream.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;scream.volume_db=0;add_child(scream)
 footsteps=AudioStreamPlayer3D.new();footsteps.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;footsteps.max_distance=13;footsteps.unit_size=2;footsteps.volume_db=-14;add_child(footsteps)
 var steps: AudioStreamWAV=load("res://assets/ambience-v193/ghost-run.wav").duplicate();steps.loop_mode=AudioStreamWAV.LOOP_FORWARD;steps.loop_end=int(steps.get_length()*steps.mix_rate);footsteps.stream=steps

func configure(value: String) -> void:
 id=value
 if not SCENARIOS.has(id): return
 spec=SCENARIOS[id];origin=spec.p
 if spec.zone in ["Küche","Kino"]: origin+=ServiceAnnex.OFFSET
 # Match the dry human voice to the actual granny head, including crawlers.
 var voice_id: String="granny_"+id if spec.mode not in ["hands","window","vent","throne"] else id
 ScareBank.select(audio,voice_id,spec.mode)
 anticipation=ScareBank.lead(self,voice_id,spec.mode)
 actor=CharacterBody3D.new();actor.name="EncounterBody";actor.collision_layer=0;actor.collision_mask=1;add_child(actor);actor.position=origin
 visual=(load(CharacterFinish.visitor(id,spec.mode)) as PackedScene).instantiate();visual.name="ArticulatedVisitor";actor.add_child(visual)
 # v421 visitors already come fully headed, dressed and painted; the old
 # generic head-swap and loft-built costume would only undo that work.
 CharacterFinish.dynamic_only(visual)
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
  w.tube(self,Vector3(origin.x,float(spec.get("ceiling",7.29)),origin.z),origin-Vector3(0,.4,0),.009,w.materials.fabric)
 elif spec.mode in ["hands","window"]:
  for child in visual.find_children("*","MeshInstance3D",true,false): child.visible=child.name.begins_with("Arm")
  visual.rotation.z=PI;visual.position.y=1.0;shape.disabled=true
  if id=="pot_arms": visual.scale.x=.65
 elif spec.mode=="mouth":
  visual.scale=Vector3.ONE*.70;visual.position.y=-1.08;shape.disabled=true
  for child in visual.find_children("*","MeshInstance3D",true,false):
   if child.name.begins_with("Arm") or child.name.begins_with("Leg") or child.name=="Torso": child.hide()
 elif spec.mode=="vent": actor.hide();shape.disabled=true
 elif spec.mode=="drop":
  visual.rotation.z=PI;shape.disabled=true
  tether=w.tube(self,Vector3(origin.x,7.29,origin.z),origin,.007,w.materials.dark)
 if spec.mode=="ambush": actor.hide()
 if spec.mode=="throne":
  shape.disabled=true
 if spec.mode in ["pursuit","tube"]:
  face_light=OmniLight3D.new();face_light.light_color=Color("d6c8b4");face_light.light_energy=0;face_light.omni_range=2.2;face_light.position=Vector3(0,1.25,.55);actor.add_child(face_light)
 if spec.mode in ["ambush","rush","drop"]:
  warning_light=OmniLight3D.new();warning_light.light_color=Color("bba788");warning_light.light_energy=0;warning_light.omni_range=2.8;warning_light.position=Vector3(0,1.6,.8);actor.add_child(warning_light)
 if spec.mode=="queue":
  var offsets: Array=[Vector3(0,0,1.05),Vector3(0,0,2.10)] if id=="reception_queue" else [Vector3(0,0,-1.4),Vector3(-.9,0,1.0)]
  for offset in offsets:
   var echo:=visual.duplicate() as Node3D;echo.position=origin+offset;add_child(echo);echo.rotation.y=.7+echo.position.x;echoes.append(echo)
 if spec.mode in ["tube","window"]:
  path_s=9.8 if id=="tube_burst" else 5.0 if spec.mode=="tube" else 11.8
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
 if spec.mode in ["ceiling","drop"]: marker.position.y=0
 if spec.mode=="vent": marker.position=Vector3(-1.3,.025,-20.15)+ServiceAnnex.OFFSET
 if spec.mode in ["tube","window"]: marker.position=CrawlTubes.route(path_s)+Vector3(0,-.74,0);marker.hide()

func tick(delta: float, active: bool, player: NightGuard) -> void:
 audio.stream_paused=not active
 scream.stream_paused=not active
 footsteps.stream_paused=not active
 if anticipation: anticipation.stream_paused=not active
 if spec.is_empty(): return
 var in_tube:=w.tubes.contains_original(player.position)
 if spec.mode in ["tube","window"]:
  actor.visible=in_tube;marker.visible=in_tube
 if not active: return
 elapsed+=delta;shock=move_toward(shock,0,delta*2.2)
 var target:=focus_point()
 var eligible:=in_tube if spec.mode in ["tube","window"] else true
 var radius:=3.6 if spec.mode=="ambush" else 4.2 if spec.mode=="rush" else 5.4
 if not triggered and not primed and elapsed>.25 and eligible and w.encounters.visible_to(player,target,radius):
  primed=true;anticipation.position=target;anticipation.play()
 if not triggered and elapsed>.8 and eligible and w.encounters.visible_to(player,target,radius):
  triggered=true;attack=0;audio.position=target;ScareBank.play(audio);anticipation.stop();shock=1.0;actor.show()
  if spec.mode in ["ceiling","drop"]:
   # Hanging guests shriek right into your ear, not a distant low drone.
   scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream);player.fright=maxf(player.fright,1.)
 if not triggered:
  visual.rotation.y=sin(elapsed*.53)*.12
  if primed and spec.mode not in ["hands","window","vent"]:
   var head:=visual.find_child("HeadRig",true,false) as Node3D
   if head:
    var direction:=player.position-actor.position
    head.rotation.y=lerp_angle(head.rotation.y,clampf(atan2(direction.x,direction.z)-actor.rotation.y,-.6,.6),minf(1,delta*4))
  return
 if finished: footsteps.stop();return
 footsteps.position=actor.position
 if spec.mode in ["pursuit","crawl","crossing","tube","rush","ambush"] and not footsteps.playing: footsteps.play()
 attack+=delta
 if warning_light: warning_light.light_energy=maxf(0,(1-attack/1.0))*.8
 animate_attack(delta,player,in_tube)

func focus_point() -> Vector3:
 var target:=actor.position+Vector3(0,1.4,0)
 if spec.mode in ["hands","mouth","window","tube"]: target=actor.position+Vector3(0,.35,0)
 if spec.mode=="crawl": target=actor.position+Vector3(0,.70,0)
 if spec.mode=="window": target=actor.position
 if spec.mode in ["ceiling","drop"]: target=actor.position-Vector3(0,1.6,0)
 if spec.mode=="vent": target=w.room_horror.creature.global_position+Vector3(0,-1.5,.7)
 if spec.mode=="throne": target=actor.position+Vector3(0,1.87,0)
 return target

func animate_attack(delta: float, player: NightGuard, in_tube: bool) -> void:
 if spec.mode=="pursuit" and _face_lunge(player,1.9,4.2):return
 if spec.mode in ["pursuit","crawl","crossing","peek","rush","ambush"]:
  var to_player:=player.position-actor.position;to_player.y=0
  var duration:=4.7 if spec.mode in ["pursuit","crawl"] else 2.3 if spec.mode=="rush" else 1.3
  var clearance:=1.85 if spec.mode=="crawl" else .85
  if attack<duration and to_player.length()>clearance:
   var direction:=to_player.normalized();var speed:=5.7 if spec.mode=="rush" else 4.5 if spec.mode=="ambush" else 2.6 if spec.mode=="pursuit" else 3.9 if spec.mode=="crossing" else 1.9
   var collision:=actor.move_and_collide(direction*minf(speed*delta,maxf(0,to_player.length()-clearance)))
   if collision:
    var slide:=direction.slide(collision.get_normal())
    if slide.length()<.1: slide=Vector3(direction.z,0,-direction.x)
    actor.move_and_collide(slide*speed*delta)
   actor.rotation.y=atan2(direction.x,direction.z)
   var stride:=attack*(7. if spec.mode=="crawl" else 13. if spec.mode=="rush" else 8.)
   visual.position.y=(.20 if spec.mode=="crawl" else 0)+absf(sin(stride))*(.012 if spec.mode=="peek" else .035)
   visual.rotation.z=sin(stride*.5)*(.075 if spec.mode=="crawl" else .025)
   for i in range(arms.size()):
    arms[i].rotation.x=(-.65+sin(stride+i*PI)*.38) if spec.mode=="crawl" else (-.52+sin(stride+i*PI)*.12) if spec.mode=="rush" else sin(stride+i*PI)*.09
  elif attack>duration:
   finished=true
   # Hold the contorted visitor as an unmistakable clue, never replay the sting.
   visual.rotation.z=.17;visual.position.y-=.12
 elif spec.mode=="throne":
  var pulse:=sin(clampf(attack/.75,0,1)*PI)
  visual.position.z=pulse*.47;visual.rotation.x=pulse*.32;visual.rotation.z=.18*clampf(attack,0,1)
  for arm in arms: arm.rotation.x=-pulse*.8
  if attack>1.3: finished=true
 elif spec.mode=="drop":
  # A quick fall followed by a crooked suspended pose; no player overlap.
  var pulse:=sin(clampf(attack/.72,0,1)*PI*.5)
  actor.position.y=origin.y-pulse*minf(1.15,maxf(0,origin.y-2.25))
  var ceiling:=Vector3(origin.x,7.29,origin.z)
  tether.position=(ceiling+actor.position)*.5;(tether.mesh as CylinderMesh).height=ceiling.distance_to(actor.position)
  visual.rotation.z=PI+sin(attack*17)*maxf(0,1-attack)*.20
  if attack>1.6: finished=true
 elif spec.mode=="tube":
  if in_tube and _face_lunge(player,1.5,2.2 if id=="tube_burst" else 3.4):return
  if in_tube:
   var nearest:=CrawlTubes.nearest(player.position);path_s=move_toward(path_s,maxf(.9,nearest.s-(1.0 if id=="tube_burst" else 1.7)),delta*(3.2 if id=="tube_burst" else 1.5))
   actor.position=CrawlTubes.route(path_s)+Vector3(0,-.76,0)
   var direction:=CrawlTubes.tangent(path_s);actor.rotation.y=atan2(direction.x,direction.z)
   # Clawing itself forward hand over hand, head up and fixed on you.
   var stride:=attack*9.
   for i in range(arms.size()):arms[i].rotation=Vector3(-1.55+sin(stride+i*PI)*.45,0,(-.25 if i==0 else .25))
   visual.position.y=.20+absf(sin(stride))*.03
  if attack>4.8: finished=true
 elif spec.mode=="vent":
  var pulse:=sin(clampf(attack/1.6,0,1)*PI)
  w.room_horror.creature.attack_gain=pulse;shock=maxf(shock,pulse*.85)
  if attack>1.6: finished=true;w.room_horror.creature.attack_gain=0
 else:
  var pulse:=sin(clampf(attack/1.6,0,1)*PI)
  if spec.mode=="window": visual.position=-window_normal*(.42+pulse*.02)
  else: visual.position.z=(pulse*.14 if spec.mode=="mouth" else -pulse*.45);visual.rotation.y=sin(attack*7)*pulse*.18
  if spec.mode=="mouth":
   var direction:=player.position-actor.position;actor.rotation.y=atan2(direction.x,direction.z)
  if spec.mode=="hands": visual.position.y=1.0+pulse*.28
  elif spec.mode=="mouth": visual.position.y=-1.08+pulse*.30
  elif spec.mode=="ceiling":
   # Swings on its rope like a pendulum, head first, straight at you.
   var snap:=1.-pow(1.-clampf(attack/.2,0,1),4)
   var toward:=player.global_position-actor.global_position;toward.y=0
   if toward.length()>.05:
    var axis:=Vector3.UP.cross(toward.normalized()).normalized()
    var swing:=(.62*snap-.18*clampf((attack-.5)/1.,0,1))*(1.+.06*sin(attack*31.))
    actor.quaternion=Quaternion(axis,-swing)
   visual.rotation.y=sin(attack*23.)*.25*pulse
   for i in range(arms.size()):arms[i].rotation.x=-1.3*snap+sin(attack*29.+i)*.15
  if attack>1.6:
   finished=true
   if spec.mode=="mouth": visual.position.y=-.88
   if spec.mode=="ceiling": actor.quaternion=Quaternion(Vector3.FORWARD,.12)

# A pursuing visitor that reaches you does not just stop: in a split second
# it is in your face, arms up, screaming, under a stuttering light. Then it is
# back where it stood, twisted, as the clue for the red door.
func _face_lunge(player: NightGuard,reach: float,patience: float) -> bool:
 var to_player:=player.position-actor.position
 if spec.mode!="tube":to_player.y=0
 if lunge_at<0:
  if to_player.length()>reach and attack<patience:return false
  lunge_at=attack;lunge_from=actor.global_position
  scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream);shock=1.0;footsteps.stop()
  player.fright=maxf(player.fright,1.)
 var t:=attack-lunge_at
 if t>.72 or attack>5.6:
  finished=true;lunge_at=1e9;face_light.light_energy=0
  if spec.mode=="tube":
   # Gone back into the dark end of the tube, flat on its belly again.
   actor.global_position=origin;visual.rotation=Vector3(1.25,0,0);visual.position=Vector3(0,.20,0)
   var rig:=visual.find_child("HeadRig",true,false) as Node3D
   if rig:rig.rotation=Vector3(-1.25,0,0)
  else:actor.global_position=origin;visual.position=Vector3(0,-.12,0);visual.rotation=Vector3(0,0,.17)
  for arm in arms:arm.rotation=Vector3.ZERO
  return true
 var eye:=player.camera.global_transform;var forward:=-eye.basis.z;forward.y=0;forward=forward.normalized() if forward.length()>.1 else Vector3.FORWARD
 # Head level with the eyes, a forearm's length away.
 var head_rig:=visual.find_child("HeadRig",true,false) as Node3D
 var head_offset:=(head_rig.global_position-actor.global_position) if head_rig else Vector3(0,1.75,0)
 var target:=eye.origin+forward*(.42 if spec.mode=="tube" else .5)-head_offset-Vector3(0,.04,0)
 var k:=1.-pow(1.-clampf(t/.14,0,1),4)
 var jerk:=Vector3(sin(floorf(t*16.)*12.9)*.05,0,0)*clampf(t/.14,0,1)
 actor.global_position=lunge_from.lerp(target,k)+jerk
 actor.rotation.y=atan2(-forward.x,-forward.z)
 if spec.mode=="tube":visual.rotation=Vector3(1.25-.3*k+.05*sin(t*41.),.06*sin(t*29.),.08*sin(t*37.))
 else:visual.position=Vector3.ZERO;visual.rotation=Vector3(-.16*k+.05*sin(t*41.),.06*sin(t*29.),.08*sin(t*37.))
 var head:=visual.find_child("HeadRig",true,false) as Node3D
 var crawler: bool=spec.mode=="tube"
 if head:head.rotation=Vector3((-.95 if crawler else 0.)+.1*sin(t*47.),.18*sin(t*39.),.14*sin(t*53.))
 for i in range(arms.size()):
  if crawler:arms[i].rotation=Vector3(-1.75+.2*sin(t*33.+i),0,(-.45 if i==0 else .45)*k)
  else:arms[i].rotation=Vector3(-1.5*k+.12*sin(t*33.+i),0,(-.55 if i==0 else .55)*k)
 face_light.light_energy=(1.4 if int(t*22.)%3 else .25)*k
 shock=1.0
 return true

func snapshot() -> Dictionary:
 return {"id":id,"elapsed":elapsed,"triggered":triggered,"finished":finished,"attack":attack,"shock":shock,"position":[actor.position.x,actor.position.y,actor.position.z] if is_instance_valid(actor) else [],"visible":is_instance_valid(actor) and actor.visible,"zone":spec.get("zone",""),"mode":spec.get("mode",""),"audio":audio.playing,"sound":audio.stream.resource_path,"paused":audio.stream_paused,"steps":footsteps.playing,"steps_paused":footsteps.stream_paused,"remnant":is_instance_valid(marker)}
