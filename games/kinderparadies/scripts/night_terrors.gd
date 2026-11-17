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
 "pit_hands":{"p":Vector3(3.6,.3,7.1),"mode":"pit","zone":"Bällebad"},
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
var shape: CollisionShape3D
var rope: MeshInstance3D
var vanished:=false
var stare:=0.0
var stuck:=0.0
var cross_dir:=Vector3.ZERO
var lunged:=false
# Ball-pit skeletal arms (mode "pit"): one dictionary per arm, see PitBones.
var bones: Array=[]
var bones_placed:=false
var splash: AudioStreamPlayer3D
var pit_box:=AABB()
# Ground visitors: [freeze before the dash, dash speed m/s, reach that starts the face lunge].
const CHARGE:={"pursuit":[.12,7.2,1.45],"rush":[0.,9.,1.45],"ambush":[0.,8.,1.4],"peek":[.22,7.5,1.45],"crawl":[.14,6.,1.35],"queue":[.32,7.,1.45]}

func build(world: PlayWorld) -> void:
 w=world;name="NightTerrors"
 audio=AudioStreamPlayer3D.new();audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.max_distance=20;audio.unit_size=6;audio.volume_db=3;add_child(audio)
 audio.stream=load("res://assets/annex/clown-sting.wav")
 scream=AudioStreamPlayer.new();scream.name="FaceScream";scream.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;scream.volume_db=0;add_child(scream);ScareBank.loud(scream)
 footsteps=AudioStreamPlayer3D.new();footsteps.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;footsteps.max_distance=13;footsteps.unit_size=2;footsteps.volume_db=-14;add_child(footsteps)
 var steps: AudioStreamWAV=load("res://assets/ambience-v193/ghost-run.wav").duplicate();steps.loop_mode=AudioStreamWAV.LOOP_FORWARD;steps.loop_end=int(steps.get_length()*steps.mix_rate);footsteps.stream=steps

func configure(value: String) -> void:
 id=value
 if not SCENARIOS.has(id): return
 spec=SCENARIOS[id];origin=spec.p
 if spec.zone in ["Küche","Kino"]: origin+=ServiceAnnex.OFFSET
 # Match the dry human voice to the actual granny head, including crawlers.
 var voice_id: String="granny_"+id if spec.mode not in ["hands","pit","window","vent","throne"] else id
 ScareBank.select(audio,voice_id,spec.mode)
 audio.volume_db=3;audio.unit_size=10;audio.max_distance=32;ScareBank.loud(audio)
 anticipation=ScareBank.lead(self,voice_id,spec.mode)
 actor=CharacterBody3D.new();actor.name="EncounterBody";actor.collision_layer=0;actor.collision_mask=1;add_child(actor);actor.position=origin
 if spec.mode=="pit":
  visual=Node3D.new();visual.name="BoneArms";actor.add_child(visual)
 else:
  visual=(load(CharacterFinish.visitor(id,spec.mode)) as PackedScene).instantiate();visual.name="ArticulatedVisitor";actor.add_child(visual)
  # v421 visitors already come fully headed, dressed and painted; the old
  # generic head-swap and loft-built costume would only undo that work.
  CharacterFinish.dynamic_only(visual)
 shape=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.75;shape.shape=capsule;shape.position.y=.91;actor.add_child(shape)
 for key in ["ArmL","ArmR"]:
  var arm:=visual.find_child(key,true,false) as Node3D
  if arm: arms.append(arm)
 if spec.mode in ["crawl","tube"]:
  visual.rotation.x=1.25;visual.position.y=.20;visual.scale=Vector3.ONE*.67;capsule.height=.60;shape.position.y=.4
  var head_rig:=visual.find_child("HeadRig",true,false) as Node3D
  if head_rig: head_rig.rotation.x=-1.25
 elif spec.mode=="ceiling":
  visual.rotation.z=PI;shape.disabled=true
  rope=w.tube(self,Vector3(origin.x,float(spec.get("ceiling",7.29)),origin.z),origin-Vector3(0,.4,0),.009,w.materials.fabric)
 elif spec.mode in ["hands","window"]:
  for child in visual.find_children("*","MeshInstance3D",true,false): child.visible=child.name.begins_with("Arm")
  visual.rotation.z=PI;visual.position.y=1.0;shape.disabled=true
  if id=="pot_arms": visual.scale.x=.65
 elif spec.mode=="pit":
  _build_pit();shape.disabled=true;actor.hide()
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
 if spec.mode=="pit": _pit_clue()

func tick(delta: float, active: bool, player: NightGuard) -> void:
 audio.stream_paused=not active
 scream.stream_paused=not active
 footsteps.stream_paused=not active
 if anticipation: anticipation.stream_paused=not active
 if splash: splash.stream_paused=not active
 if spec.is_empty(): return
 var in_tube:=w.tubes.contains_original(player.position)
 if spec.mode in ["tube","window"]:
  actor.visible=in_tube and not vanished;marker.visible=in_tube
 if not active: return
 elapsed+=delta;shock=move_toward(shock,0,delta*2.2)
 var target:=focus_point()
 var eligible:=in_tube if spec.mode in ["tube","window"] else true
 # Close trigger radius: the visitor waits until you are really near it.
 var radius:=trigger_radius()
 var seen:=not triggered and eligible and w.encounters.visible_to(player,target,radius+2.6)
 if seen and not primed and elapsed>.25:
  primed=true;anticipation.position=target;anticipation.play()
 # A visitor you stare at from further away comes for you after a moment.
 stare=stare+delta if seen and primed else maxf(0,stare-delta*2)
 var close:=eligible and w.encounters.visible_to(player,target,radius)
 var stared: bool=stare>(1.5 if spec.mode=="peek" else 2.1) and (spec.mode in CHARGE or spec.mode in ["crossing","pit"])
 if not triggered and elapsed>.8 and (close or stared):
  triggered=true;attack=0;audio.position=target;ScareBank.play(audio);anticipation.stop();shock=1.0
  # The vent strike is the horse skull alone; its placeholder visitor must stay hidden.
  if spec.mode!="vent":actor.show()
  if spec.mode in ["ceiling","drop"]:
   # Hanging guests shriek right into your ear, not a distant low drone.
   scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream);player.fright=maxf(player.fright,1.)
  if spec.mode=="pit":
   # Bones cracking out of the balls and a shriek right in your ear.
   scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream);player.fright=maxf(player.fright,1.)
 if not triggered:
  if spec.mode!="pit": visual.rotation.y=sin(elapsed*.53)*.12
  if primed and spec.mode not in ["hands","pit","window","vent"]:
   var head:=visual.find_child("HeadRig",true,false) as Node3D
   if head:
    var direction:=player.position-actor.position
    head.rotation.y=lerp_angle(head.rotation.y,clampf(atan2(direction.x,direction.z)-actor.rotation.y,-.6,.6),minf(1,delta*4))
  return
 if finished: footsteps.stop();return
 footsteps.position=actor.position
 if spec.mode in ["pursuit","crawl","crossing","tube","rush","ambush","peek","queue"] and lunge_at<0 and not footsteps.playing:
  footsteps.volume_db=-6;footsteps.pitch_scale=1.3 if spec.mode in ["rush","ambush","crossing"] else 1.15;footsteps.play()
 attack+=delta
 if warning_light: warning_light.light_energy=maxf(0,(1-attack/1.0))*.8
 animate_attack(delta,player,in_tube)

func focus_point() -> Vector3:
 var target:=actor.position+Vector3(0,1.4,0)
 if spec.mode in ["hands","mouth","window","tube"]: target=actor.position+Vector3(0,.35,0)
 if spec.mode=="crawl": target=actor.position+Vector3(0,.70,0)
 if spec.mode=="pit": target=actor.position+Vector3(0,.5,0)
 if spec.mode=="window": target=actor.position
 if spec.mode in ["ceiling","drop"]: target=actor.position-Vector3(0,1.6,0)
 if spec.mode=="vent": target=w.room_horror.creature.global_position+Vector3(0,-1.5,.7)
 if spec.mode=="throne": target=actor.position+Vector3(0,1.87,0)
 return target

func trigger_radius() -> float:
 match spec.mode:
  "ambush":return 3.3
  "pit":return 3.6
  "peek":return 3.4
  "crawl":return 3.8
  "pursuit":return 4.4
  "rush":return 5.6
  "crossing":return 6.0
  "queue":return 4.0
  "tube","window":return 5.4
 return 4.2

func animate_attack(delta: float, player: NightGuard, in_tube: bool) -> void:
 # Hard ceiling: no encounter can ever hang around after its scare.
 if attack>4.5: _vanish(player);return
 if spec.mode in CHARGE: _charge(delta,player);return
 if spec.mode=="crossing": _cross(delta,player);return
 if spec.mode=="pit": _pit(player);return
 if spec.mode=="throne":
  var k:=1.-pow(1.-clampf(attack/.16,0,1),4)
  visual.position.z=k*.9+sin(attack*37.)*.03*k;visual.rotation.x=k*.42;visual.rotation.z=.18*k
  for arm in arms: arm.rotation.x=-1.5*k+sin(attack*31.)*.12
  shock=maxf(shock,k*.9)
  if attack>1.05: _vanish(player)
 elif spec.mode=="drop":
  # Snaps down on its rope, bounces at the end of it, then is gone.
  var f:=clampf(attack/.26,0,1);var fall:=f*f
  if attack>.26: fall=1.+sin((attack-.26)*24.)*exp(-(attack-.26)*6.)*.14
  actor.position.y=origin.y-fall*minf(1.25,maxf(0,origin.y-2.15))
  var ceiling:=Vector3(origin.x,7.29,origin.z)
  tether.position=(ceiling+actor.position)*.5;(tether.mesh as CylinderMesh).height=ceiling.distance_to(actor.position)
  visual.rotation.z=PI+sin(attack*19)*maxf(0,1.2-attack)*.22
  for i in range(arms.size()):arms[i].rotation.x=-1.4*f+sin(attack*27.+i)*.18
  if attack>1.25: _vanish(player)
 elif spec.mode=="tube":
  if in_tube and _face_lunge(player,1.5,2.0 if id=="tube_burst" else 2.8):return
  if in_tube:
   var nearest:=CrawlTubes.nearest(player.position);path_s=move_toward(path_s,maxf(.9,nearest.s-(1.0 if id=="tube_burst" else 1.4)),delta*(6.5 if id=="tube_burst" else 4.5))
   actor.position=CrawlTubes.route(path_s)+Vector3(0,-.76,0)
   var direction:=CrawlTubes.tangent(path_s);actor.rotation.y=atan2(direction.x,direction.z)
   # Clawing itself forward hand over hand, head up and fixed on you.
   var stride:=attack*16.
   for i in range(arms.size()):arms[i].rotation=Vector3(-1.55+sin(stride+i*PI)*.5,0,(-.25 if i==0 else .25))
   visual.position.y=.20+absf(sin(stride))*.04
  if attack>3.2: _vanish(player)
 elif spec.mode=="vent":
  var pulse:=sin(clampf(attack/1.6,0,1)*PI)
  w.room_horror.creature.attack_gain=pulse;shock=maxf(shock,pulse*.85)
  if attack>1.6: finished=true;w.room_horror.creature.attack_gain=0
 else:
  # hands, mouth, window and ceiling: an instant snap out, a trembling hold, gone.
  var k:=1.-pow(1.-clampf(attack/.16,0,1),4);var tremble:=sin(attack*43.)*k
  if spec.mode=="window": visual.position=-window_normal*(.42+k*.06+tremble*.01)
  elif spec.mode!="ceiling": visual.position.z=(k*.30 if spec.mode=="mouth" else -k*.6);visual.rotation.y=tremble*.14
  if spec.mode=="mouth":
   var direction:=player.position-actor.position;actor.rotation.y=atan2(direction.x,direction.z)
   visual.position.y=-1.08+k*.42
  if spec.mode=="hands":
   visual.position.y=1.0+k*.45
   for i in range(arms.size()):arms[i].rotation.x=sin(attack*31.+i*2.)*.25*k
  elif spec.mode=="ceiling":
   # Swings on its rope like a pendulum, head first, straight at you.
   var snap:=1.-pow(1.-clampf(attack/.2,0,1),4)
   var toward:=player.global_position-actor.global_position;toward.y=0
   if toward.length()>.05:
    var axis:=Vector3.UP.cross(toward.normalized()).normalized()
    var swing:=(.62*snap-.18*clampf((attack-.5)/1.,0,1))*(1.+.06*sin(attack*31.))
    actor.quaternion=Quaternion(axis,-swing)
   visual.rotation.y=sin(attack*23.)*.25*snap
   for i in range(arms.size()):arms[i].rotation.x=-1.3*snap+sin(attack*29.+i)*.15
  shock=maxf(shock,k*.8)
  if attack>(1.35 if spec.mode=="ceiling" else 1.0): _vanish(player)

# Ground visitors: a split-second freeze with the head snapping round, then a
# flat-out sprint straight at you that ends in your face. If furniture or a
# wall stops it, it never stands there stuck: it lunges if it can see you,
# otherwise it is simply gone.
func _charge(delta: float, player: NightGuard) -> void:
 var cfg: Array=CHARGE[spec.mode]
 var windup: float=cfg[0];var speed: float=cfg[1];var reach: float=cfg[2]
 if lunge_at>=0:
  _face_lunge(player,reach,0.);return
 var to_player:=player.position-actor.position;to_player.y=0
 var direction:=to_player.normalized() if to_player.length()>.01 else -actor.global_basis.z
 var head:=visual.find_child("HeadRig",true,false) as Node3D
 if attack<windup:
  # The freeze: whole body locks on to you, a violent tremor, arms rising.
  actor.rotation.y=lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),minf(1,delta*22))
  if head and spec.mode!="crawl": head.rotation=Vector3(0,0,sin(attack*61.)*.12)
  visual.rotation.z=sin(attack*53.)*.05
  for i in range(arms.size()):arms[i].rotation.x=-1.1*attack/windup
  for echo in echoes:
   var eh:=echo.find_child("HeadRig",true,false) as Node3D
   if eh: eh.rotation.y=lerp_angle(eh.rotation.y,atan2(player.position.x-echo.position.x,player.position.z-echo.position.z)-echo.rotation.y,minf(1,delta*14))
  return
 var run:=attack-windup
 if to_player.length()<=reach:
  _start_lunge(player);return
 var step:=direction*speed*minf(1,run/.07+.35)*delta
 var before:=actor.global_position
 var collision:=actor.move_and_collide(step)
 if collision:
  var slide:=step.slide(collision.get_normal())
  if slide.length()>step.length()*.2: actor.move_and_collide(slide)
 var moved:=actor.global_position.distance_to(before)
 stuck=stuck+delta if moved<step.length()*.35 else maxf(0,stuck-delta)
 actor.rotation.y=atan2(direction.x,direction.z)
 var crawler: bool=spec.mode=="crawl"
 var stride:=run*(17. if crawler else 15.)
 visual.position=Vector3(0,(.20 if crawler else 0.)+absf(sin(stride))*(.04 if crawler else .06),0)
 visual.rotation=Vector3(1.25 if crawler else -.2,0,sin(stride*.5)*(.09 if crawler else .05))
 if head and not crawler: head.rotation=Vector3(.2,0,sin(run*29.)*.1)
 for i in range(arms.size()):
  arms[i].rotation.x=(-.75+sin(stride+i*PI)*.5) if crawler else (-1.35+sin(stride+i*PI)*.22)
 if stuck>.12 or run>1.4:
  # Blocked by a counter or a seat row: if it can see you, it leaps over it.
  if to_player.length()<6.5 and _clear(player): _start_lunge(player)
  else: _vanish(player)

# A visitor darting across your view, close enough to brush past, then gone.
func _cross(delta: float, player: NightGuard) -> void:
 var to_player:=player.position-actor.position;to_player.y=0
 if cross_dir==Vector3.ZERO:
  var side:=Vector3(to_player.z,0,-to_player.x).normalized()
  var left:=_free(side);var right:=_free(-side)
  if maxf(left,right)<1.2:
   # Nowhere to run sideways: it comes straight for you instead.
   cross_dir=to_player.normalized()
  else:
   cross_dir=((side if left>=right else -side)+to_player.normalized()*.35).normalized()
 var step:=cross_dir*8.5*delta;var collision:=actor.move_and_collide(step)
 if collision: _vanish(player);return
 actor.rotation.y=atan2(cross_dir.x,cross_dir.z)
 var stride:=attack*16.
 visual.position.y=absf(sin(stride))*.06;visual.rotation=Vector3(-.3,0,sin(stride*.5)*.06)
 for i in range(arms.size()):arms[i].rotation.x=sin(stride+i*PI)*.9
 if attack>.62 or to_player.length()<1.: _vanish(player)

func _free(direction: Vector3) -> float:
 var from:=actor.global_position+Vector3(0,.9,0)
 var query:=PhysicsRayQueryParameters3D.create(from,from+direction*4.,1);query.exclude=[actor.get_rid()]
 var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
 return from.distance_to(hit.position) if hit else 4.

func _clear(player: NightGuard) -> bool:
 var head:=actor.global_position+Vector3(0,1.5 if spec.mode!="crawl" else .6,0)
 var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,head,1);query.exclude=[player.get_rid(),actor.get_rid()]
 return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _start_lunge(player: NightGuard) -> void:
 if lunge_at>=0: return
 if face_light==null:
  face_light=OmniLight3D.new();face_light.light_color=Color("d6c8b4");face_light.light_energy=0;face_light.omni_range=2.2;face_light.position=Vector3(0,1.25,.55);actor.add_child(face_light)
 if spec.mode=="crawl":
  # Rears up off the floor for the final lunge.
  visual.rotation=Vector3.ZERO;visual.position=Vector3.ZERO;visual.scale=Vector3.ONE*.85
  var rig:=visual.find_child("HeadRig",true,false) as Node3D
  if rig: rig.rotation=Vector3.ZERO
 lunge_at=attack;lunge_from=actor.global_position;lunged=true
 scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream);shock=1.0;footsteps.stop()
 player.fright=maxf(player.fright,1.)

# Every visitor disappears after its scare. The torch stutters at that moment
# so it never visibly pops; only the claw marks stay behind as the clue.
func _vanish(player: NightGuard) -> void:
 if vanished: return
 vanished=true;finished=true;lunge_at=1e9
 actor.hide()
 for echo in echoes: echo.hide()
 if tether: tether.hide()
 if rope: rope.hide()
 if face_light: face_light.light_energy=0
 if warning_light: warning_light.light_energy=0
 if shape: shape.set_deferred("disabled",true)
 footsteps.stop()
 if spec.mode=="vent": return
 shock=maxf(shock,.55)
 if player and player.torch_body: player.torch_body.trigger()

# A pursuing visitor that reaches you does not just stop: in a split second
# it is in your face, arms up, screaming, under a stuttering light. Then it is
# back where it stood, twisted, as the clue for the red door.
func _face_lunge(player: NightGuard,reach: float,patience: float) -> bool:
 var to_player:=player.position-actor.position
 if spec.mode!="tube":to_player.y=0
 if lunge_at<0:
  if to_player.length()>reach and attack<patience:return false
  _start_lunge(player)
 var t:=attack-lunge_at
 if t>.8 or attack>4.5:
  _vanish(player)
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

# --- Ball-pit skeletal arms -------------------------------------------------
func _build_pit() -> void:
 var bone:=PitBones.material(w);var dark:=PitBones.grime(w)
 var first:=true
 for body in w.pit_physics.starts:
  pit_box=AABB(body,Vector3.ZERO) if first else pit_box.expand(body);first=false
 pit_box=pit_box.grow(-.2)
 # Five arms; the first is the long one that comes for your face.
 for i in range(5):
  var a:=PitBones.arm(visual,bone,dark,1.5 if i==0 else 1.15+i*.06,1.3 if i==0 else 1.1)
  a.lead=i==0;a.delay=[.07,0.,.03,.1,.15][i];a.hold=[1.25,.95,1.1,1.0,1.18][i]
  a.burst=false;a.sunk=false;a.depth=float(a.upper)+float(a.reach)+.15;a.top=.4
  (a.root as Node3D).position.y=-float(a.depth);bones.append(a)
 splash=AudioStreamPlayer3D.new();splash.name="BallBurst";splash.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 splash.stream=load("res://assets/ballpit-v433/wade-2.ogg");splash.volume_db=8;splash.pitch_scale=.8;splash.unit_size=6;splash.max_distance=24;add_child(splash)

func _pit_surface(p: Vector3) -> float:
 var top:=.35
 for body in w.pit_physics.starts:
  if Vector2(body.x-p.x,body.z-p.z).length()<.24: top=maxf(top,body.y+.14)
 return top

# The lasting clue: two bony hands left standing upright between the balls,
# claws just breaking the surface. Each is baked into a single mesh.
func _pit_clue() -> void:
 var bone:=PitBones.material(w);var dark:=PitBones.grime(w)
 for spot in [[Vector3(.5,0,.2),.4,.55,.5],[Vector3(-.22,0,.62),-.8,.35,.4]]:
  var offset: Vector3=spot[0];var at: Vector3=origin+offset;var a:=PitBones.arm(marker,bone,dark,1.)
  var root: Node3D=a.root;root.rotation.y=spot[1]
  (a.shoulder as Node3D).rotation.x=.12;(a.elbow as Node3D).rotation.x=.18;(a.wrist as Node3D).rotation.x=.35
  PitBones.curl(a,spot[2],1.2)
  root.position=Vector3(offset.x,0,offset.z)
  var clue:=PitBones.flatten(a,marker,bone,"BoneClue%d"%marker.get_child_count())
  clue.position.y=_pit_surface(at)+float(spot[3])-clue.get_aabb().end.y-origin.y

func _place_bones(player: NightGuard) -> void:
 bones_placed=true
 var toward:=player.global_position-actor.global_position;toward.y=0
 toward=toward.normalized() if toward.length()>.05 else Vector3.BACK
 var side:=Vector3(toward.z,0,-toward.x)
 # The long arm breaks out at the rim right in front of you, the rest in a
 # ragged cluster behind it.
 var guard:=player.global_position
 var rim:=Vector3(clampf(guard.x,pit_box.position.x,pit_box.end.x),0,clampf(guard.z,pit_box.position.z,pit_box.end.z))
 var lead:=rim-toward*.15;lead.y=actor.global_position.y
 var offsets:=[Vector3.ZERO,side*.5-toward*.35,-side*.55-toward*.3,side*.95-toward*.8,-side*1.0-toward*.75]
 for i in range(bones.size()):
  var p: Vector3=lead+offsets[i]
  for clue in marker.get_children():
   if clue.name.begins_with("BoneClue"):
    var gap:=Vector2(p.x-clue.global_position.x,p.z-clue.global_position.z)
    if gap.length()<.3: p+=(Vector3(gap.x,0,gap.y).normalized()*(.3-gap.length())) if gap.length()>.01 else side*.3
  p.x=clampf(p.x,pit_box.position.x,pit_box.end.x);p.z=clampf(p.z,pit_box.position.z,pit_box.end.z)
  var a: Dictionary=bones[i];(a.root as Node3D).position.x=p.x-actor.global_position.x;(a.root as Node3D).position.z=p.z-actor.global_position.z
  a.top=(.8 if a.lead else .7)-actor.global_position.y

func side_of(node: Node3D) -> Vector3:
 return node.global_basis.x.normalized()

func _splash(at: Vector3, power: float) -> void:
 for body in w.pit_physics.bodies:
  if body.freeze: continue
  var o:=body.global_position-at;o.y=0;var d:=o.length()
  if d>.7: continue
  # Surface balls fly highest; buried ones only heave.
  var k:=(1.-d/.7)*power*clampf((body.global_position.y-.05)/.3,.6,1.);body.sleeping=false
  body.linear_velocity+=(Vector3.UP*(5.2+fmod(d*37.,1.)*2.4)+(o/maxf(d,.01))*2.2)*k
 splash.global_position=at+Vector3(0,.5,0)
 if power>.8 or not splash.playing: splash.pitch_scale=.8 if power>.8 else 1.05;splash.play()

# Bursting out (staggered, overshooting), clawing for you with the long arm
# going straight for your face, then yanked back under in a spray of balls.
func _pit(player: NightGuard) -> void:
 if not bones_placed: _place_bones(player)
 if not actor.visible and not vanished: actor.show()
 var eye:=player.camera.global_position
 var gone:=true
 for i in range(bones.size()):
  var a: Dictionary=bones[i];var root: Node3D=a.root;var t:=attack-float(a.delay)
  var up:=0.
  if t>0:
   var e:=clampf(t/.13,0,1);up=1.-pow(1.-e,3)+sin(clampf(t/.32,0,1)*PI)*.1
   if not a.burst: a.burst=true;_splash(Vector3(root.global_position.x,.4,root.global_position.z),1.15 if a.lead else .9)
  var back:=clampf((t-float(a.hold))/.2,0,1);back*=back
  if back>0 and not a.sunk: a.sunk=true;_splash(Vector3(root.global_position.x,.4,root.global_position.z),.55)
  if back<1.: gone=false
  root.position.y=lerpf(-float(a.depth),float(a.top),up*(1.-back))
  if t<=0: continue
  # Aim: the long arm goes for the face but stops a hand's width short,
  # the others claw at the air between the balls and you.
  var shoulder: Vector3=root.global_position
  var flat:=eye-shoulder;flat.y=0
  root.rotation.y=atan2(flat.x,flat.z)
  var span: float=float(a.upper)+float(a.reach)
  var target: Vector3
  if a.lead:
   var to_eye:=eye-shoulder;target=shoulder+to_eye.normalized()*minf(span*.97,to_eye.length()-.3)
  else:
   target=shoulder+(flat.normalized()+side_of(root)*(.25 if i%2 else -.25)).normalized()*span*.74+Vector3(0,span*.4+sin(attack*5.+i)*.08,0)
  var local:=root.global_transform.affine_inverse()*target
  var reach:=clampf((t-.05)/.22,0,1);reach=1.-pow(1.-reach,2)
  var solve:=PitBones.reach(a,local)
  var shake:=sin(attack*47.+i*1.7)*.05+sin(attack*29.+i*2.3)*.03
  (a.shoulder as Node3D).rotation=Vector3(lerpf(.05,solve.x,reach)+shake,0,sin(attack*23.+i)*.06)
  (a.elbow as Node3D).rotation=Vector3(lerpf(.25,solve.y,reach)-shake*.6,0,0)
  (a.wrist as Node3D).rotation=Vector3((-1.05 if a.lead else .35+sin(attack*9.+i)*.25),sin(attack*13.+i)*.15,0)
  var claw:=(.22+.12*sin(attack*21.)) if a.lead and back==0. else .3+.55*(.5+.5*sin(attack*15.+i*2.1))
  PitBones.curl(a,lerpf(claw,1.,back),1.5 if a.lead else 1.)
 shock=maxf(shock,.9*clampf(1.-attack/1.4,0,1))
 if gone and attack>.5: _vanish(player)

func snapshot() -> Dictionary:
 return {"id":id,"elapsed":elapsed,"triggered":triggered,"finished":finished,"attack":attack,"shock":shock,"position":[actor.position.x,actor.position.y,actor.position.z] if is_instance_valid(actor) else [],"visible":is_instance_valid(actor) and actor.visible,"zone":spec.get("zone",""),"mode":spec.get("mode",""),"audio":audio.playing,"sound":audio.stream.resource_path,"paused":audio.stream_paused,"steps":footsteps.playing,"steps_paused":footsteps.stream_paused,"remnant":is_instance_valid(marker),"vanished":vanished}
