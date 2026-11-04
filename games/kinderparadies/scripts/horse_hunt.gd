class_name HorseHunt
extends Node3D

signal resolved
signal fatal_started
signal killed
const ID:="horse_clown_hunt"
const TEST_CODE:="07120712"
const CLUE:="Pferde mögen keine Clowns"
const MUSIC:="res://assets/music-v371/music-box-chase.mp3"
var music: AudioStreamPlayer
var music_gain:=0.0
var music_offset:=0.0
var w: PlayWorld
var horse: CeilingHorse
var navigation: HorseNavigation
var enabled:=false
var phase:="idle"
var clock:=0.0
var phase_clock:=0.0
var draw_clock:=0.0
var shock:=0.0
var trace:=PackedVector3Array()
var rotations:=PackedVector3Array()
var trail: Array[Dictionary]=[]
var trail_index:=0
var nav_route:=PackedVector3Array()
var nav_index:=0
var retreat_index:=-1
var head:=Vector3.ZERO
var head_rotation:=Vector3.ZERO
var low_head:=false
var clown_clock:=-1.0
var clown_start:=Vector3.ZERO
var clown_target:=Vector3.ZERO
var clown_transform:=Transform3D.IDENTITY
var clown_head_rotation:=Vector3.ZERO
var scream: AudioStreamPlayer3D
var warning: AudioStreamPlayer3D
var screamed:=false
var announced:=false
const CATCH_RADIUS:=1.35
var catch_count:=0
var catch_cooldown:=0.0
var recoil_left:=0.0
var rejoin_index:=0
var catch_audio: AudioStreamPlayer
var catch_view: Node3D
var catch_mask: Node3D
var catch_jaw: Node3D
const FATAL_SCREAM:="res://assets/encounter-v401/horse-final-scream.wav"
const MAX_HITS:=3
var injury_layer: CanvasLayer
var injury_screen: ColorRect
var injury_material: ShaderMaterial
var injury_strength:=0.0
var fatal_announced:=false
var catch_sounded:=false

func build(world: PlayWorld) -> void:
 w=world;name="HorseAndClownEncounter";horse=w.room_horror.creature
 scream=AudioStreamPlayer3D.new();scream.name="ClownRepelsHorse";scream.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;scream.max_distance=24;scream.unit_size=7;add_child(scream);ScareBank.select(scream,"clown_lunge")
 warning=ScareBank.lead(self,"vent_strike");warning.name="HorseUncoiling";warning.volume_db=-13
 if AudioServer.get_bus_index("Interior")>=0:scream.bus="Interior"
 catch_audio=AudioStreamPlayer.new();catch_audio.name="HorseContactScream";catch_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;catch_audio.stream=ScareBank.flat("horse_contact");catch_audio.volume_db=-3;add_child(catch_audio)
 music=AudioStreamPlayer.new();music.name="MusicBoxChase";music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;music.stream=load(MUSIC);(music.stream as AudioStreamMP3).loop=true;music.bus="Master";music.volume_db=-60;add_child(music)
 injury_layer=CanvasLayer.new();injury_layer.name="HorseInjury";injury_layer.layer=0;add_child(injury_layer)
 injury_screen=ColorRect.new();injury_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);injury_screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;injury_layer.add_child(injury_screen)
 injury_material=ShaderMaterial.new();injury_material.shader=load("res://assets/encounter-v401/bloodshot.gdshader");injury_screen.material=injury_material;injury_screen.hide()

func configure(id: String) -> void:
 music.stop();music_gain=0;music_offset=0;music.volume_db=-60
 enabled=id==ID;phase="emerging" if enabled else "idle"
 catch_count=0;injury_strength=0.;fatal_announced=false;injury_material.set_shader_parameter("injury",0.);injury_screen.hide()
 w.passages.set_red_locked(enabled)
 if not enabled:return
 horse.clock=0;horse.pose(0);head=horse.mask.global_position;head_rotation=horse.mask.rotation
 trace.append(head);rotations.append(head_rotation)
 navigation=HorseNavigation.new();navigation.setup(w)
 clown_transform=w.annex.clown.root.transform
 clown_head_rotation=w.annex.clown.head.rotation

func red_locked() -> bool:
 return enabled and phase!="resolved"

func tick(delta: float,active: bool,player: NightGuard) -> void:
 _music(delta,active)
 scream.stream_paused=not active;warning.stream_paused=not active;catch_audio.stream_paused=not active
 if not active or not enabled:return
 var injury_target:=0. if phase in ["resolved","dead"] else .36 if catch_count==1 else .82 if catch_count>=2 else 0.
 injury_strength=move_toward(injury_strength,injury_target,delta*1.7)
 injury_material.set_shader_parameter("injury",injury_strength);injury_material.set_shader_parameter("impact",shock)
 if phase in ["resolved","dead"]:return
 clock+=delta;phase_clock+=delta;shock=move_toward(shock,0,delta*2.5);catch_cooldown=maxf(0,catch_cooldown-delta)
 navigation.tick(player)
 if not announced:
  announced=true;warning.global_position=head;warning.play()
 _record_player(player)
 if clown_clock>=0:_clown_pose(delta)
 if phase=="emerging":
  horse.clock=clock;horse.pose(smoothstep(0.0,9.0,phase_clock));head=horse.mask.global_position;head_rotation=horse.mask.rotation;_remember()
  if phase_clock>=9 and navigation.ready:phase="following";phase_clock=0;_plan(player)
 elif phase=="following":
  _follow(delta,player)
  if head.x< -10.12 and head.x> -16.8 and head.z> -30.3 and head.z< -28.95 and player.position.x< -10.4:_repel()
  elif catch_cooldown<=0 and head.distance_to(player.camera.global_position)<=CATCH_RADIUS and _visible(player):_catch(player)
 elif phase=="catch":
  _catch_pose(player)
  if phase_clock>=1.05:
   catch_view.hide();horse.mask.show();catch_audio.stop();phase="recoiling";phase_clock=0;recoil_left=2.8;retreat_index=trace.size()-2
 elif phase=="fatal":
  if not fatal_announced:fatal_announced=true;fatal_started.emit()
  _catch_pose(player)
  if phase_clock>=1.18:
   phase="dead";catch_view.hide();catch_audio.stop();music.stop();music_gain=0.;killed.emit()
 elif phase=="recoiling":_recoil(delta)
 elif phase=="rejoining":_rejoin(delta)
 elif phase=="clown":
  shock=maxf(shock,.9*sin(clampf(phase_clock/.9,0,1)*PI))
  if phase_clock>=.92:
   _remember(true);retreat_index=trace.size()-2;phase="retreating";phase_clock=0
 elif phase=="retreating":_retreat(delta)
 draw_clock+=delta
 if draw_clock>=1.0/24.0 or phase=="resolved":draw_clock=0;_draw()

func _music(delta: float,active: bool) -> void:
 music.stream_paused=not active
 if not active:return
 var wanted:=enabled and phase not in ["resolved","dead"]
 if wanted and not music.playing:
  music.play(music_offset);music_offset=0
 # Leave space for the horse's scream and the clown's attack.
 var target:=db_to_linear(-32 if phase=="fatal" else -25 if phase in ["catch","clown"] else -16) if wanted else 0.0
 music_gain=move_toward(music_gain,target,delta*.22)
 music.volume_db=linear_to_db(maxf(.001,music_gain))
 if not wanted and music_gain<=0:music.stop()

func _exit_tree() -> void:
 if is_instance_valid(music):music.stop()

func _record_player(player: NightGuard) -> void:
 var foot:=player.global_position
 if not trail.is_empty() and foot.distance_to(trail[-1].foot)<.18 and trail[-1].low==player.crouching:return
 # Record genuine walkable travel, including ramps, bridges and crawl tubes.
 # A developer warp is routed through the floor graph instead of drawing a
 # straight neck through the intervening walls.
 if not trail.is_empty() and foot.distance_to(trail[-1].foot)>3.5:
  trail.clear();trail_index=0;nav_route.clear()
 var eye:=foot+Vector3.UP*(.86 if player.crouching else 2.03)
 var ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.95,foot+Vector3.UP*2.8,1);ray.exclude=[player.get_rid()]
 var roof:=w.get_world_3d().direct_space_state.intersect_ray(ray)
 if not roof.is_empty():eye.y=minf(eye.y,roof.position.y-.57)
 eye.y=maxf(foot.y+.84,eye.y)
 trail.append({"foot":foot,"head":eye,"low":player.crouching or eye.y-foot.y<1.55})

func _plan(player: NightGuard) -> void:
 if not navigation.ready or trail.is_empty():return
 var candidate:=trail.size()-1
 while candidate>0 and (not navigation.reachable_floor(trail[candidate].foot) or trail[candidate].low):candidate-=1
 nav_route=navigation.path(head,trail[candidate].foot);nav_index=0;trail_index=candidate
 # The first cell is a nearby centre, not a teleport of the actual mask.
 if nav_route.size()>0 and Vector2(head.x,head.z).distance_to(Vector2(nav_route[0].x,nav_route[0].z))<.2:nav_index=1

func _visible(player: NightGuard) -> bool:
 var ray:=PhysicsRayQueryParameters3D.create(head,player.camera.global_position,1);ray.exclude=[player.get_rid()]
 return w.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _follow(delta: float,player: NightGuard) -> void:
 if nav_route.is_empty():_plan(player)
 if nav_route.is_empty():return
 var destination:=head
 if nav_index<nav_route.size():destination=nav_route[nav_index]+Vector3.UP*2.03;low_head=false
 elif trail_index<trail.size():destination=trail[trail_index].head;low_head=trail[trail_index].low
 else:return
 if head.distance_to(player.camera.global_position)<=CATCH_RADIUS and _visible(player):return
 var difference:=destination-head;var speed:=3.15 if head.distance_to(player.position)>5 else 2.35
 var amount:=minf(difference.length(),speed*delta)
 if difference.length()>.001:
  head+=difference.normalized()*amount
  var flat:=Vector3(difference.x,0,difference.z)
  if flat.length()>.025:head_rotation.y=lerp_angle(head_rotation.y,atan2(-flat.x,-flat.z),minf(1,delta*9))
 var pitch:=_fit_head(destination.y)
 head_rotation.x=lerpf(head_rotation.x,pitch,minf(1,delta*9));head_rotation.z=sin(clock*1.3)*.025
 var through_low_door:=Vector2(head.x,head.z).distance_to(Vector2(destination.x,destination.z))<.035 and absf(head.y-destination.y)<.75
 if amount>=difference.length()-.001 or through_low_door:
  if nav_index<nav_route.size():nav_index+=1
  else:trail_index+=1
 _remember()

func _catch(player: NightGuard) -> void:
 catch_count=mini(MAX_HITS,catch_count+1);phase="fatal" if catch_count>=MAX_HITS else "catch";phase_clock=0;catch_cooldown=6;shock=1;warning.stop();_remember(true)
 catch_audio.stop();catch_audio.stream=load(FATAL_SCREAM) if phase=="fatal" else ScareBank.flat("horse_contact");catch_audio.pitch_scale=1.;catch_audio.volume_db=-1.5 if phase=="fatal" else -3.
 catch_sounded=false
 if phase=="fatal":fatal_announced=true;fatal_started.emit()
 horse.mask.hide();_catch_pose(player)

func present_contact(visible: bool) -> void:
 if is_instance_valid(catch_view):catch_view.visible=visible and phase in ["catch","fatal"]
 injury_screen.visible=visible and enabled and injury_strength>.001 and phase!="dead"

func _catch_pose(player: NightGuard) -> void:
 if not is_instance_valid(catch_view):
  catch_view=Node3D.new();catch_view.name="HorseContactCloseup";add_child(catch_view)
  catch_mask=horse.mask.duplicate() as Node3D;catch_mask.name="LungingHorseMask";catch_view.add_child(catch_mask);catch_mask.show();catch_mask.scale=Vector3.ONE*.68
  catch_jaw=catch_mask.find_child("JawHinge",true,false) as Node3D
  var fill:=OmniLight3D.new();fill.position=Vector3(.28,.18,-.35);fill.light_color=Color("bfc6b3");fill.light_energy=.9;fill.omni_range=4;catch_view.add_child(fill)
 catch_view.show();catch_view.global_transform=player.camera.global_transform
 var fatal:=phase=="fatal"
 var lunge:=smoothstep(.035,.20 if not fatal else .26,phase_clock);var withdraw:=0. if fatal else smoothstep(.72,1.05,phase_clock)
 var jitter:=1. if player.motion else 0.
 catch_mask.scale=Vector3.ONE*(.82 if fatal else .68)
 catch_mask.position=Vector3(.04+sin(phase_clock*35)*.018*jitter,.20,lerpf(lerpf(-3.2,-1.34 if fatal else -1.08,lunge),-3.0,withdraw))
 catch_mask.rotation=Vector3(lerpf(-.98,.15,lunge) if fatal else -.98,PI+lerpf(-.28,.08,lunge) if fatal else PI-.28,-.10)
 catch_mask.rotation+=Vector3(sin(phase_clock*29)*.025,sin(phase_clock*23)*.035,sin(phase_clock*31)*.025)*jitter
 if catch_jaw:catch_jaw.rotation.x=-.23-(1.12 if fatal else .50)*lunge*(1-withdraw)
 shock=maxf(shock,.85*(1-withdraw))
 if phase_clock>=.045 and not catch_sounded:
  catch_sounded=true
  if fatal:catch_audio.play()
  else:ScareBank.play_flat(catch_audio)

func _recoil(delta: float) -> void:
 var remaining:=minf(delta*4.5,recoil_left)
 while remaining>0 and retreat_index>=0:
  var target:=trace[retreat_index];var distance:=head.distance_to(target)
  var fraction:=minf(1,remaining/maxf(.0001,distance))
  head=head.lerp(target,fraction);head_rotation=rotations[retreat_index]
  remaining-=distance*fraction;recoil_left=maxf(0,recoil_left-distance*fraction)
  if fraction>=1:retreat_index-=1
  else:break
 if recoil_left<=.001 or retreat_index<0:
  phase="rejoining";phase_clock=0;rejoin_index=retreat_index+1

func _rejoin(delta: float) -> void:
 var remaining:=delta*1.8
 while remaining>0 and rejoin_index<trace.size():
  var target:=trace[rejoin_index];var distance:=head.distance_to(target)
  var fraction:=minf(1,remaining/maxf(.0001,distance))
  head=head.lerp(target,fraction);head_rotation=rotations[rejoin_index];remaining-=distance*fraction
  if fraction>=1:rejoin_index+=1
  else:break
 if rejoin_index>=trace.size():phase="following";phase_clock=0

func _fit_head(reference_height: float=-100.0) -> float:
 if low_head:return -.06
 if reference_height< -90:reference_height=head.y
 # Probe ahead and behind the actual long mask, so ears clear a lintel
 # before its centre enters the doorway. The recorded return uses this pose.
 var forward:=Vector3(-sin(head_rotation.y),0,-cos(head_rotation.y))
 var ceiling:=INF
 for offset in [Vector3.ZERO,forward*1.1,-forward*.55]:
  var p: Vector3=Vector3(head.x,reference_height,head.z)+offset
  var ray:=PhysicsRayQueryParameters3D.create(p-Vector3.UP*.4,p+Vector3.UP*1.6,1)
  var hit:=w.get_world_3d().direct_space_state.intersect_ray(ray)
  if not hit.is_empty() and hit.normal.y<-.5 and hit.position.y>reference_height-.4:ceiling=minf(ceiling,hit.position.y)
 if ceiling<reference_height+.85:
  head.y=maxf(reference_height-.55,minf(head.y,ceiling-.72))
  return -.48
 return -1.02

func _remember(force: bool=false) -> void:
 if not force and not trace.is_empty() and trace[-1].distance_to(head)<.12:return
 if not trace.is_empty() and trace[-1].distance_to(head)<.001:return
 trace.append(head);rotations.append(head_rotation)

func _repel() -> void:
 phase="clown";phase_clock=0;clown_clock=0;screamed=true;shock=1
 w.annex.scare=true;clown_start=w.annex.clown.root.global_position;clown_target=head-Vector3.UP*1.65
 scream.global_position=head;ScareBank.play(scream);warning.stop()

func _clown_pose(delta: float) -> void:
 clown_clock+=delta
 var actor: Node3D=w.annex.clown.root
 var launch:=Vector3(-14.5,clown_start.y,-29.35)
 if clown_clock<.32:actor.global_position=clown_start.lerp(launch,smoothstep(0.0,.32,clown_clock))
 elif clown_clock<.92:
  var t:=clampf((clown_clock-.32)/.60,0,1);actor.global_position=launch.lerp(clown_target,t)+Vector3.UP*sin(t*PI)*.65
 elif clown_clock<1.55:
  var t:=smoothstep(.92,1.55,clown_clock);actor.global_position=clown_target.lerp(launch,t)+Vector3.UP*sin(t*PI)*.35
 elif clown_clock<1.95:actor.global_position=launch.lerp(clown_start,smoothstep(1.55,1.95,clown_clock))
 else:
  actor.transform=clown_transform;w.annex.clown.head.rotation=clown_head_rotation;w.annex.clown.spoon.show();w.annex.clown.bowl.show();w.annex.scare=false;clown_clock=-1;return
 actor.rotation.y=atan2(head.x-actor.global_position.x,head.z-actor.global_position.z)
 actor.rotation.x=-sin(clampf((clown_clock-.32)/.60,0,1)*PI)*.2
 var figure: Dictionary=w.annex.clown
 if figure.has("head"):figure.head.rotation.x=-.12*sin(clown_clock*8)
 figure.spoon.hide();figure.bowl.hide()
 HorrorFigures.link(figure.upper,Vector3(-.28,1.48,0),Vector3(-.30,1.55,.42))
 HorrorFigures.link(figure.forearm,Vector3(-.30,1.55,.42),Vector3(-.18,1.68,.90));figure.hand.position=Vector3(-.18,1.68,.90)

func _retreat(delta: float) -> void:
 var remaining:=delta*5.3
 while remaining>0 and retreat_index>=0:
  var target:=trace[retreat_index];var distance:=head.distance_to(target)
  var fraction:=minf(1,remaining/maxf(.0001,distance))
  head=head.lerp(target,fraction);head_rotation=Vector3(lerp_angle(head_rotation.x,rotations[retreat_index].x,fraction),lerp_angle(head_rotation.y,rotations[retreat_index].y,fraction),lerp_angle(head_rotation.z,rotations[retreat_index].z,fraction))
  remaining-=distance*fraction
  if fraction>=1:retreat_index-=1
  else:break
 if retreat_index<0:
  phase="resolved";horse.clock=0;horse.pose(0);w.passages.set_red_locked(false);warning.stop();resolved.emit()

func _draw() -> void:
 if phase=="resolved":return
 var points:=trace.slice(0,retreat_index+1) if phase in ["retreating","recoiling"] else trace.slice(0,rejoin_index) if phase=="rejoining" else trace.duplicate()
 if points.is_empty() or points[-1].distance_to(head)>.001:points.append(head)
 horse.draw_trail(points,head_rotation,-.055 if low_head else -.26-.055*sin(clock*1.4))

static func vector_array(v: Vector3) -> Array:
 return [v.x,v.y,v.z]

func serialize() -> Dictionary:
 if not enabled:return {}
 var poses: Array=[];var breadcrumbs: Array=[]
 for i in range(trace.size()):poses.append(vector_array(trace[i])+vector_array(rotations[i]))
 for item in trail:breadcrumbs.append(vector_array(item.foot)+vector_array(item.head)+[item.low])
 return {"version":2,"phase":phase,"clock":clock,"phase_clock":phase_clock,"head":vector_array(head),"rotation":vector_array(head_rotation),"trace":poses,"trail":breadcrumbs,"trail_index":trail_index,"nav_route":Array(nav_route).map(func(p):return vector_array(p)),"nav_index":nav_index,"retreat_index":retreat_index,"clown_clock":clown_clock,"clown_start":vector_array(clown_start),"clown_target":vector_array(clown_target),"screamed":screamed,"announced":announced,"low_head":low_head,"sound_position":scream.get_playback_position(),"sound_playing":scream.playing,"catch_count":catch_count,"injury_strength":injury_strength,"catch_cooldown":catch_cooldown,"recoil_left":recoil_left,"rejoin_index":rejoin_index,"catch_sound_started":catch_sounded,"catch_sound_position":catch_audio.get_playback_position(),"catch_sound_playing":catch_audio.playing,"music_position":music_offset if music_offset>0 else music.get_playback_position(),"music_gain":music_gain}

static func valid_vector(value: Variant) -> bool:
 if not value is Array or value.size()!=3:return false
 for item in value:
  if not (item is float or item is int) or not is_finite(float(item)) or absf(float(item))>100:return false
 return true

static func read_vector(value: Array) -> Vector3:
 return Vector3(float(value[0]),float(value[1]),float(value[2]))

func restore(data: Variant) -> void:
 if not enabled or not data is Dictionary:return
 if data.get("version",0)!=1 and data.get("version",0)!=2:return
 if data.get("phase","") not in ["emerging","following","catch","fatal","recoiling","rejoining","clown","retreating","resolved"]:return
 for key in ["head","rotation","clown_start","clown_target"]:
  if not valid_vector(data.get(key,[])):return
 for key in ["clock","phase_clock","clown_clock","sound_position","music_position","music_gain"]:
  var value=data.get(key,0)
  if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>100000:return
 var poses=data.get("trace",[]);var crumbs=data.get("trail",[]);var routes=data.get("nav_route",[])
 if not poses is Array or poses.is_empty() or poses.size()>16384 or not crumbs is Array or crumbs.size()>16384 or not routes is Array or routes.size()>12000:return
 for row in poses:
  if not row is Array or row.size()!=6 or not valid_vector(row.slice(0,3)) or not valid_vector(row.slice(3,6)):return
 for row in crumbs:
  if not row is Array or row.size()!=7 or not valid_vector(row.slice(0,3)) or not valid_vector(row.slice(3,6)) or not row[6] is bool:return
 for row in routes:
  if not valid_vector(row):return
 for key in ["trail_index","nav_index","retreat_index"]:
  var value=data.get(key,0)
  if not (value is float or value is int) or not is_finite(float(value)) or float(value)!=float(int(value)):return
 if int(data.get("trail_index",0))<0 or int(data.get("trail_index",0))>crumbs.size() or int(data.get("nav_index",0))<0 or int(data.get("nav_index",0))>routes.size() or int(data.get("retreat_index",-1))< -1 or int(data.get("retreat_index",-1))>=poses.size():return
 for key in ["catch_count","catch_cooldown","recoil_left","rejoin_index","catch_sound_position"]:
  var value=data.get(key,0)
  if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0:return
 if float(data.get("catch_count",0))!=float(int(data.get("catch_count",0))) or float(data.get("catch_count",0))>100000:return
 if float(data.get("rejoin_index",0))!=float(int(data.get("rejoin_index",0))) or int(data.get("rejoin_index",0))>poses.size() or float(data.get("recoil_left",0))>2.801 or float(data.get("catch_cooldown",0))>6.001:return
 var stored_injury=data.get("injury_strength",0.)
 if not (stored_injury is float or stored_injury is int) or not is_finite(float(stored_injury)) or float(stored_injury)<0 or float(stored_injury)>1:return
 if data.get("version",1)==2:
  var hits:=int(data.get("catch_count",0))
  if hits>MAX_HITS or (str(data.phase)=="fatal")!=(hits==MAX_HITS):return
 phase=data.phase;clock=maxf(0,float(data.clock));phase_clock=maxf(0,float(data.phase_clock));head=read_vector(data.head);head_rotation=read_vector(data.rotation)
 trace.clear();rotations.clear();trail.clear();nav_route.clear()
 for row in poses:trace.append(read_vector(row.slice(0,3)));rotations.append(read_vector(row.slice(3,6)))
 for row in crumbs:trail.append({"foot":read_vector(row.slice(0,3)),"head":read_vector(row.slice(3,6)),"low":row[6]})
 for row in routes:nav_route.append(read_vector(row))
 trail_index=int(data.trail_index);nav_index=int(data.nav_index);retreat_index=int(data.retreat_index);clown_clock=clampf(float(data.clown_clock),-1,2)
 clown_start=read_vector(data.clown_start);clown_target=read_vector(data.clown_target);screamed=data.get("screamed",false)==true;announced=data.get("announced",false)==true;low_head=data.get("low_head",false)==true
 catch_count=mini(2 if data.get("version",1)==1 else MAX_HITS,int(data.get("catch_count",0)));injury_strength=float(stored_injury) if data.get("version",1)==2 else .36 if catch_count==1 else .82 if catch_count>=2 else 0.;fatal_announced=false;injury_material.set_shader_parameter("injury",injury_strength);catch_cooldown=float(data.get("catch_cooldown",0));recoil_left=float(data.get("recoil_left",0));rejoin_index=int(data.get("rejoin_index",0))
 if is_instance_valid(catch_view):catch_view.hide()
 catch_sounded=data.get("catch_sound_started",float(data.get("phase_clock",0))>=.045)==true
 horse.mask.visible=phase not in ["catch","fatal"];catch_audio.stop();catch_audio.stream=load(FATAL_SCREAM) if phase=="fatal" else ScareBank.flat("horse_contact");catch_audio.volume_db=-1.5 if phase=="fatal" else -3.
 if phase in ["catch","fatal"] and data.get("catch_sound_playing",false)==true and float(data.get("catch_sound_position",0))<catch_audio.stream.get_length():catch_audio.play(float(data.get("catch_sound_position",0)))
 music.stop();music_offset=fposmod(maxf(0,float(data.get("music_position",clock))),music.stream.get_length());music_gain=clampf(float(data.get("music_gain",0)),0,db_to_linear(-16))
 if phase=="resolved":music_offset=0;music_gain=0
 w.annex.scare=clown_clock>=0;w.passages.set_red_locked(red_locked())
 if clown_clock>=0:_clown_pose(0)
 if phase=="resolved":horse.clock=0;horse.pose(0)
 else:_draw()
 if data.get("sound_playing",false)==true and float(data.sound_position)<scream.stream.get_length():scream.play(maxf(0,float(data.sound_position)))

func snapshot() -> Dictionary:
 return {"enabled":enabled,"phase":phase,"locked":red_locked(),"clock":clock,"head":vector_array(head),"trace_points":trace.size(),"neck_sections":horse.sections.size(),"trail_points":trail.size(),"trail_index":trail_index,"nav_index":nav_index,"nav_points":nav_route.size(),"navigation_ready":navigation.ready if navigation else false,"navigation_cells":navigation.cells.size() if navigation else 0,"retreat_index":retreat_index,"screamed":screamed,"audio":scream.playing,"audio_paused":scream.stream_paused,"clown_clock":clown_clock,"catch_count":catch_count,"injury_strength":injury_strength,"catch_cooldown":catch_cooldown,"catch_audio":catch_audio.playing,"catch_paused":catch_audio.stream_paused,"closeup":is_instance_valid(catch_view) and catch_view.visible,"injury_visible":injury_screen.visible,"fatal":phase=="fatal","jaw":catch_jaw.rotation.x if is_instance_valid(catch_jaw) else 0.,"catch_track":catch_audio.stream.resource_path,"music":music.playing,"music_paused":music.stream_paused,"music_track":music.stream.resource_path,"music_position":music.get_playback_position(),"music_gain":music.volume_db}
