class_name NightFollower
extends Node3D

# 5.3.0: something keeps you company between the scares. Every minute or two
# one of these, reacting to the guard instead of playing on a timer:
#  - "follow": steps walk behind you on the path you just walked, a few metres
#    back, in time with your own. Stop, and they take one step too many. Turn
#    round, and they are gone. Never turned round? They close in until
#    something breathes right behind you and the torch stutters.
#  - "door": a door you just passed bangs shut behind you.
# Sound only (plus the guard's own torch). Same rules in every round and on its
# own random stream: it is never an anomaly and never changes the right door.
const STEPS:="res://assets/quality-v410/audio/step-concrete-%d.ogg"
const CARPET:="res://assets/quality-v410/audio/step-carpet-%d.ogg"
const DOORS:=["res://assets/quality-v410/audio/door-1.ogg","res://assets/quality-v410/audio/door-2.ogg","res://assets/quality-v410/audio/door-3.ogg","res://assets/quality-v410/audio/door-4.ogg"]
const BREATH:="res://assets/ambience-v180/breathing.wav"
const STRIDE:=.72
var w: PlayWorld
var rng:=RandomNumberGenerator.new()
var step: AudioStreamPlayer3D
var thud: AudioStreamPlayer3D
var breath: AudioStreamPlayer3D
var trail: Array[Vector3]=[]
var walked:=0.
var state:="idle"
var wait:=0.
var clock:=0.
var gap:=4.8
var stepped:=0.
var still:=0.
var extra_step:=false
var pending:=-1.
var steps_played:=0
var visits:=0
var caught:=0
var closed:=0
var doors:=0
var last_kind:=""

func build(world: PlayWorld) -> void:
 w=world;name="NightFollower";rng.randomize()
 step=_source("FollowerSteps",-9.,14.)
 thud=_source("FollowerDoor",-6.,24.)
 breath=_source("FollowerBreath",-12.,4.);breath.stream=load(BREATH);breath.unit_size=1.2
 reset()

func _source(id: String,db: float,reach: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.name=id;source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;source.volume_db=db;source.unit_size=2.4;source.max_distance=reach;source.attenuation_filter_cutoff_hz=5200
 if not OS.has_feature("web"):source.bus="Interior"
 add_child(source);return source

func reset() -> void:
 state="idle";wait=rng.randf_range(35,60);trail.clear();walked=0.;pending=-1.

# Other scares own the stage: no company during them or in the crawl tube.
func _busy(player: NightGuard) -> bool:
 if w.tubes.contains(player.position):return true
 if w.horse_hunt.phase!="idle" or w.blackout.phase not in ["idle","waiting"]:return true
 if w.encounters.triggered and not w.encounters.finished:return true
 return false

# The point on the guard's own path, `back` metres behind them.
func behind(back: float) -> Vector3:
 var left:=back
 for i in range(trail.size()-1,0,-1):
  var d:=trail[i].distance_to(trail[i-1])
  if d>=left:return trail[i].lerp(trail[i-1],left/maxf(d,.001))
  left-=d
 return trail[0] if not trail.is_empty() else Vector3.ZERO

func _looking_at(player: NightGuard,p: Vector3) -> bool:
 var to:=p+Vector3.UP*1.2-player.camera.global_position
 return (-player.camera.global_basis.z).dot(to.normalized())>.45

func tick(delta: float,active: bool,player: NightGuard) -> void:
 for source in [step,thud,breath]:
  if source.stream_paused==active:source.stream_paused=not active
 if not active or not player:return
 clock+=delta
 var at: Vector3=player.global_position;at.y=0.
 if trail.is_empty() or trail[-1].distance_to(at)>.25:
  if not trail.is_empty():walked+=trail[-1].distance_to(at)
  trail.append(at)
  if trail.size()>120:trail.remove_at(0)
 var moving: float=Vector2(player.velocity.x,player.velocity.z).length()
 match state:
  "idle":
   wait-=delta
   if wait<=0 and moving>.5 and walked>12. and not _busy(player):start(player)
  "follow":_follow(delta,player,moving)
  "door":
   pending-=delta
   if pending<=0:
    thud.stream=load(DOORS[rng.randi_range(0,DOORS.size()-1)]);thud.position=behind(7.)+Vector3.UP*1.4;thud.pitch_scale=rng.randf_range(.9,1.02);thud.play()
    doors+=1;_end()

func start(player: NightGuard) -> void:
 visits+=1;stepped=0.;still=0.;extra_step=false;steps_played=0;gap=rng.randf_range(4.4,5.4);clock=0.
 last_kind="door" if rng.randf()<.3 else "follow"
 state=last_kind
 if state=="door":pending=rng.randf_range(.6,1.4)

func _follow(delta: float,player: NightGuard,moving: float) -> void:
 var p:=behind(gap)
 if steps_played>0 and _looking_at(player,p):
  # Turned round: nothing there, not a sound.
  step.stop();caught+=1;_end();return
 if _busy(player):_end();return
 if moving>.5:
  still=0.;extra_step=false
  stepped+=moving*delta
  # Over twenty seconds they close the gap from five metres to arm's length.
  gap=maxf(gap-delta*.16,1.1)
  if stepped>=STRIDE:stepped-=STRIDE;_step(p,player)
 else:
  still+=delta
  if still>.42 and not extra_step and steps_played>0:extra_step=true;_step(p,player)
  if still>6.:_end();return
 if gap<=1.15:
  breath.position=behind(.9)+Vector3.UP*1.55;breath.play()
  if player.torch_body:player.torch_body.trigger()
  closed+=1;_end()

func _step(p: Vector3,player: NightGuard) -> void:
 var carpet: bool=player.get("surface_name")=="carpet"
 step.stream=load((CARPET if carpet else STEPS)%rng.randi_range(0,7));step.position=p+Vector3.UP*.1
 step.pitch_scale=rng.randf_range(.86,.94);step.volume_db=-9.+rng.randf_range(-1.5,1.);step.play();steps_played+=1

func _end() -> void:
 state="idle";wait=rng.randf_range(55,110);walked=0.

func stop_all() -> void:
 for source in [step,thud,breath]:source.stop()

func snapshot() -> Dictionary:
 return {"state":state,"wait":wait,"visits":visits,"caught":caught,"closed":closed,"doors":doors,"steps":steps_played,"gap":gap,"kind":last_kind}
