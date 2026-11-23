class_name PowerBlackout
extends Node3D

# Event anomaly (4.9.0): a few seconds into the round the whole venue loses
# power. Lights, party mode, film, machines and cabinet glow all die; only the
# guard's torch is left. The red door stays shut until the main breaker in the
# maintenance room is thrown again. Every 40 seconds in the dark the guard's
# nerve breaks: something is in their face, screaming. Then the dark goes on.

signal restored
const ID:="power_blackout"
const TEST_CODE:="40404040"
const CLUE:="Ohne Strom bleibt die Tür zu"
const NERVE:=40.0
const WAIT:=6.5
const FLICKER:=1.7
# Main breaker on the transformer cabinet at the back of the maintenance room.
const CABINET:=Vector3(-15.85,0,-6.63)
# On the right half of the cabinet, clear of the workbench edge, under the breaker row.
const LEVER_OFFSET:=Vector3(.2,.15,0)
const LEVER_ON:=.55
const LEVER_OFF:=2.55
var w: PlayWorld
var enabled:=false
# idle → waiting → flicker → dark → restoring → resolved
var phase:="idle"
var clock:=0.0
var phase_clock:=0.0
var fear:=0.0
var shock:=0.0
var scares:=0
var torch_wait:=4.0
var lever: Node3D
var lever_angle:=LEVER_ON
var warning_led: StandardMaterial3D
var warning_light: OmniLight3D
var crackle: AudioStreamPlayer3D
var thud: AudioStreamPlayer
var clunk: AudioStreamPlayer3D
var scream: AudioStreamPlayer
var breath: AudioStreamPlayer
# Everything the outage switches off, with the value it gets back.
var lights: Array[Light3D]=[]
var light_visible: Array[bool]=[]
var glows: Array[StandardMaterial3D]=[]
var glow_energy: Array[float]=[]
var hums: Array[AudioStreamPlayer3D]=[]
var hum_db: Array[float]=[]
var ambient:=0.0
var fog_light:=0.0
var fog_inject:=0.0
# Self-lit screens, displays and labels ignore darkness: they are switched off.
var screens: Array[Node3D]=[]
var screen_visible: Array[bool]=[]
var party_was_on:=false
var collected:=false
# Jumpscare visitor.
var visitor: Node3D
var visitor_visual: Node3D
var visitor_arms: Array[Node3D]=[]
var visitor_head: Node3D
var face_light: OmniLight3D
var scare_clock:=-1.0
var power:=1.0

func build(world: PlayWorld) -> void:
 w=world;name="PowerBlackout";process_priority=1000
 _cabinet()
 thud=AudioStreamPlayer.new();thud.name="MainsCutOut";thud.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;thud.stream=load("res://assets/scares-v260/dry-impact.wav");thud.volume_db=-4;add_child(thud)
 clunk=AudioStreamPlayer3D.new();clunk.name="BreakerClunk";clunk.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;clunk.stream=load("res://assets/feedback-v403/switch.ogg");clunk.position=CABINET+LEVER_OFFSET+Vector3(0,.85,.1);clunk.unit_size=4;clunk.max_distance=18;clunk.volume_db=4;add_child(clunk)
 crackle=AudioStreamPlayer3D.new();crackle.name="DeadCabinetCrackle";crackle.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var tick: AudioStreamWAV=load("res://assets/ambience/relay-tick.wav").duplicate();tick.loop_mode=AudioStreamWAV.LOOP_FORWARD;tick.loop_end=int(tick.get_length()*tick.mix_rate);crackle.stream=tick
 crackle.position=CABINET+LEVER_OFFSET+Vector3(0,1.,.1);crackle.unit_size=2.2;crackle.max_distance=16;crackle.volume_db=-9;add_child(crackle)
 scream=AudioStreamPlayer.new();scream.name="PanicScream";scream.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(scream);ScareBank.loud(scream)
 breath=AudioStreamPlayer.new();breath.name="PanicBreathing";breath.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var air: AudioStreamOggVorbis=load("res://assets/player-v402/breathing.ogg").duplicate();air.loop=true;breath.stream=air;breath.volume_db=-80;add_child(breath)
 _visitor()

func _cabinet() -> void:
 var steel:=w.mat(Color("2c3433"),null,.55,.6)
 var root:=Node3D.new();root.name="MainBreaker";root.position=CABINET+LEVER_OFFSET;add_child(root)
 # Housing below the existing breaker row, with a hazard plate and label.
 w.box(root,Vector3(0,.86,.03),Vector3(.24,.3,.07),steel)
 var hazard:=w.mat(Color("b8952a"),null,.7)
 # Label printed black on the yellow hazard strip, above the workbench edge.
 w.box(root,Vector3(0,1.035,.068),Vector3(.24,.042,.005),hazard)
 var label:=w.text(root,"HAUPTSCHALTER",Vector3(0,1.035,.0715),.024,Color("1b1a17"));label.name="BreakerLabel"
 lever=Node3D.new();lever.name="BreakerLever";lever.position=Vector3(0,.86,.07);root.add_child(lever)
 w.box(lever,Vector3(0,.09,0),Vector3(.035,.18,.035),w.materials.metal)
 var grip:=w.mat(Color("8f1d18"),null,.45)
 w.box(lever,Vector3(0,.19,0),Vector3(.13,.045,.05),grip)
 lever.rotation.x=LEVER_ON
 warning_led=w.mat(Color("5a0d0a"),null,.4);warning_led.emission_enabled=true;warning_led.emission=Color("ff2a1c");warning_led.emission_energy_multiplier=0
 w.sphere(root,Vector3(.09,.98,.07),.014,warning_led)
 warning_light=OmniLight3D.new();warning_light.name="BreakerWarning";warning_light.light_color=Color("ff3322");warning_light.light_energy=0;warning_light.omni_range=1.6;warning_light.position=Vector3(.09,.98,.2);root.add_child(warning_light)
 var body:=StaticBody3D.new();body.name="BreakerInteraction";body.set_meta("interaction","power_lever");body.position=Vector3(0,.9,.09);root.add_child(body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.32,.42,.12);shape.shape=bounds;body.add_child(shape)

func _visitor() -> void:
 visitor=Node3D.new();visitor.name="PanicVisitor";add_child(visitor);visitor.hide()
 visitor_visual=(load(CharacterFinish.visitor(ID,"ambush")) as PackedScene).instantiate();visitor_visual.name="ArticulatedVisitor";visitor.add_child(visitor_visual)
 CharacterFinish.dynamic_only(visitor_visual)
 for key in ["ArmL","ArmR"]:
  var arm:=visitor_visual.find_child(key,true,false) as Node3D
  if arm:visitor_arms.append(arm)
 visitor_head=visitor_visual.find_child("HeadRig",true,false) as Node3D
 face_light=OmniLight3D.new();face_light.name="PanicFaceLight";face_light.light_color=Color("d6c8b4");face_light.light_energy=0;face_light.omni_range=2.2;face_light.position=Vector3(0,1.25,.55);face_light.light_volumetric_fog_energy=0.;visitor.add_child(face_light)

func configure(id: String) -> void:
 enabled=id==ID;phase="waiting" if enabled else "idle"
 clock=0;phase_clock=0;fear=0;shock=0;scares=0;scare_clock=-1;power=1;torch_wait=4.;party_was_on=false
 lever_angle=LEVER_ON;lever.rotation.x=LEVER_ON
 if enabled:w.passages.set_red_locked(true,false)

func red_locked() -> bool:
 return enabled and phase!="resolved"

func dark() -> bool:
 return enabled and phase in ["flicker","dark","restoring"]

func prompt() -> String:
 if phase=="dark":return "E · Hauptschalter umlegen"
 if phase=="restoring":return ""
 return "Hauptschalter · An"

# Returns true when this pull brings the power back.
func pull() -> bool:
 if phase!="dark":return false
 phase="restoring";phase_clock=0;scare_clock=-1;visitor.hide();face_light.light_energy=0
 clunk.play();crackle.stop()
 return true

func _collect() -> void:
 if collected:return
 collected=true
 var own:=[warning_light,face_light]
 for light in w.find_children("*","Light3D",true,false):
  if light in own or is_ancestor_of(light) or light.has_meta("outdoor"):continue
  lights.append(light);light_visible.append(light.visible)
 var seen:={}
 for mesh: MeshInstance3D in w.find_children("*","MeshInstance3D",true,false):
  if is_ancestor_of(mesh) or not mesh.mesh:continue
  for i in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(i) as StandardMaterial3D
   if not material or not material.emission_enabled or seen.has(material):continue
   seen[material]=true;glows.append(material);glow_energy.append(material.emission_energy_multiplier)
  if _self_lit(mesh):screens.append(mesh);screen_visible.append(mesh.visible)
 for label: Label3D in w.find_children("*","Label3D",true,false):
  if not label.shaded and not is_ancestor_of(label):screens.append(label);screen_visible.append(label.visible)
 for source: AudioStreamPlayer3D in w.find_children("*","AudioStreamPlayer3D",true,false):
  if is_ancestor_of(source):continue
  if source.has_meta("machinery_file") or source.name=="ServerVentilation":hums.append(source);hum_db.append(source.volume_db)
 var env:=w.environment.environment
 ambient=env.ambient_light_energy;fog_light=env.fog_light_energy;fog_inject=env.volumetric_fog_ambient_inject

# Unshaded surfaces glow at full strength in total darkness. A black unshaded
# surface is a deliberate void (the horror room's darkness) and stays.
func _self_lit(mesh: MeshInstance3D) -> bool:
 for i in range(mesh.mesh.get_surface_count()):
  var material:=mesh.get_active_material(i)
  if material is StandardMaterial3D and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and material.albedo_color.v>.05:return true
  if material is ShaderMaterial and material.shader and "unshaded" in material.shader.code:return true
 return false

func _cut() -> void:
 _collect()
 party_was_on=party_was_on or w.party.enabled
 if w.party.enabled:w.party.set_enabled(false)
 if w.film.playing:w.film.stop()
 thud.play();crackle.play()

func _restore_power() -> void:
 for i in range(lights.size()):
  if is_instance_valid(lights[i]):lights[i].visible=light_visible[i]
 for i in range(glows.size()):glows[i].emission_energy_multiplier=glow_energy[i]
 for i in range(hums.size()):
  if is_instance_valid(hums[i]):hums[i].volume_db=hum_db[i]
 if collected:
  var env:=w.environment.environment
  env.ambient_light_energy=ambient;env.fog_light_energy=fog_light;env.volumetric_fog_ambient_inject=fog_inject
 for i in range(screens.size()):
  if is_instance_valid(screens[i]):screens[i].visible=screen_visible[i]
 if party_was_on and not w.party.enabled:w.party.set_enabled(true)
 party_was_on=false

# Holds the venue at the given power level. Runs after every other node, so
# animated lamps and screens are overridden for the frame that gets drawn.
func _apply(level: float) -> void:
 var on:=level>.5
 for i in range(lights.size()):
  if is_instance_valid(lights[i]):lights[i].visible=light_visible[i] and on
 for i in range(glows.size()):glows[i].emission_energy_multiplier=glow_energy[i]*(1. if on else 0.)
 for i in range(hums.size()):
  if is_instance_valid(hums[i]):hums[i].volume_db=hum_db[i] if on else -80.
 var env:=w.environment.environment
 # Nothing but the guard's torch: no ambient fill, no glowing fog.
 env.ambient_light_energy=ambient*level;env.fog_light_energy=fog_light*level;env.volumetric_fog_ambient_inject=fog_inject*level
 for i in range(screens.size()):
  if is_instance_valid(screens[i]):screens[i].visible=screen_visible[i] and on
 if not on and w.party.enabled:party_was_on=true;w.party.set_enabled(false)

func _process(delta: float) -> void:
 if not enabled:return
 var game:=w.get_parent()
 step(delta,game.get("phase")=="play",game.get("player"))

func step(delta: float,active: bool,player: NightGuard) -> void:
 crackle.stream_paused=not active;breath.stream_paused=not active;scream.stream_paused=not active
 lever.rotation.x=move_toward(lever.rotation.x,lever_angle,delta*14.)
 if phase in ["flicker","dark"]:
  var blink:=fmod(clock,1.1)<.12
  warning_led.emission_energy_multiplier=3. if blink else .08;warning_light.light_energy=.9 if blink else 0.
 else:warning_led.emission_energy_multiplier=0;warning_light.light_energy=0
 if active:
  clock+=delta;phase_clock+=delta;shock=move_toward(shock,0,delta*1.6)
  _advance(delta,player)
 if phase=="flicker":
  # Mains stutters before it dies: hard random on/off, never a fade.
  power=1. if fmod(phase_clock*13.7+sin(phase_clock*31.)*2.,3.)>1.3 and phase_clock<FLICKER-.25 else 0.
  _apply(power)
 elif phase=="dark":_apply(0)
 elif phase=="restoring":
  power=1. if phase_clock>.18 and (phase_clock>.95 or fmod(phase_clock*11.,2.)>.8) else 0.
  _apply(power)
 _breathing(delta,active)

func _advance(delta: float,player: NightGuard) -> void:
 if phase=="waiting":
  if clock>=WAIT:phase="flicker";phase_clock=0;_collect()
 elif phase=="flicker":
  if phase_clock>=FLICKER:
   phase="dark";phase_clock=0;fear=0;_cut();lever_angle=LEVER_OFF;shock=.8
   if player:player.torch_body.trigger()
 elif phase=="dark":
  if scare_clock>=0:_scare_pose(delta,player)
  else:
   fear=minf(1.,fear+delta/NERVE)
   torch_wait-=delta
   if torch_wait<=0 and player:
    player.torch_body.trigger();torch_wait=lerpf(7.,1.4,fear)*randf_range(.7,1.3)
   if fear>=1. and player:_start_scare(player)
 elif phase=="restoring":
  if phase_clock>=1.1:
   phase="resolved";fear=0;_restore_power();w.passages.set_red_locked(false);restored.emit()

func _start_scare(player: NightGuard) -> void:
 scare_clock=0;scares+=1;shock=1.
 JumpscareFX.fire(1.,.1)
 scream.stream=ScareBank.flat("door_death");ScareBank.play_flat(scream)
 visitor.show();_scare_pose(0,player)
 player.fright=maxf(player.fright,1.)

func _scare_pose(delta: float,player: NightGuard) -> void:
 scare_clock+=delta;var t:=scare_clock
 if t>.85 or not player:
  visitor.hide();face_light.light_energy=0;scare_clock=-1;fear=0;shock=maxf(shock,.55)
  if player:player.torch_body.trigger()
  return
 var eye:=player.camera.global_transform;var forward:=-eye.basis.z;forward.y=0;forward=forward.normalized() if forward.length()>.1 else Vector3.FORWARD
 visitor.global_position=Vector3.ZERO;visitor.rotation=Vector3(0,atan2(-forward.x,-forward.z),0)
 var head_offset:=(visitor_head.global_position-visitor.global_position) if visitor_head else Vector3(0,1.75,0)
 var k:=1.-pow(1.-clampf(t/.12,0,1),4)
 var jerk:=Vector3(sin(floorf(t*16.)*12.9)*.05,0,0)*clampf(t/.12,0,1)
 visitor.global_position=eye.origin+forward*lerpf(1.1,.5,k)-head_offset-Vector3(0,.04,0)+jerk
 visitor_visual.rotation=Vector3(-.16*k+.05*sin(t*41.),.06*sin(t*29.),.08*sin(t*37.))
 if visitor_head:visitor_head.rotation=Vector3(.1*sin(t*47.),.18*sin(t*39.),.14*sin(t*53.))
 for i in range(visitor_arms.size()):visitor_arms[i].rotation=Vector3(-1.5*k+.12*sin(t*33.+i),0,(-.55 if i==0 else .55)*k)
 face_light.light_energy=(1.4 if int(t*22.)%3 else .25)*k
 shock=1.

func _breathing(delta: float,active: bool) -> void:
 var wanted:=phase=="dark" and active
 if wanted and not breath.playing:breath.play()
 var target:=lerpf(-34.,-12.,smoothstep(.15,1.,fear)) if wanted else -80.
 breath.volume_db=move_toward(breath.volume_db,target,delta*(30. if wanted else 14.))
 breath.pitch_scale=lerpf(1.,1.12,fear)
 if not wanted and breath.volume_db<=-79.:breath.stop()

# Fright fed to the guard's camera: a slow rising tremble, spiking on scares.
func fright() -> float:
 return maxf(shock,fear*.42 if phase=="dark" else 0.)

func _exit_tree() -> void:
 if is_instance_valid(breath):breath.stop()

func serialize() -> Dictionary:
 if not enabled:return {}
 return {"version":1,"phase":phase,"clock":clock,"phase_clock":phase_clock,"fear":fear,"scares":scares,"party_was_on":party_was_on}

func restore(data: Variant) -> void:
 if not enabled or not data is Dictionary or data.get("version",0)!=1:return
 var saved: String=str(data.get("phase",""))
 if saved not in ["waiting","flicker","dark","restoring","resolved"]:return
 for key in ["clock","phase_clock","fear"]:
  var value=data.get(key,0)
  if not (value is float or value is int) or not is_finite(float(value)) or float(value)<0 or float(value)>100000:return
 clock=float(data.clock);fear=clampf(float(data.fear),0,1);scares=int(data.get("scares",0))
 party_was_on=data.get("party_was_on",false)==true
 if saved in ["flicker","dark"]:
  # A reload mid-outage lands straight back in the dark.
  _collect();phase="dark";phase_clock=0;lever_angle=LEVER_OFF;lever.rotation.x=LEVER_OFF
  if w.party.enabled:party_was_on=true;w.party.set_enabled(false)
  crackle.play();_apply(0)
 elif saved in ["restoring","resolved"]:
  phase="resolved";fear=0;w.passages.set_red_locked(false)
 else:phase="waiting";phase_clock=float(data.get("phase_clock",0))

func snapshot() -> Dictionary:
 return {"enabled":enabled,"phase":phase,"clock":clock,"fear":fear,"scares":scares,"red_locked":red_locked(),"lights":lights.size(),"glows":glows.size(),"screens":screens.size(),"hums":hums.size(),"lever":lever.rotation.x,"visitor":visitor.visible}
