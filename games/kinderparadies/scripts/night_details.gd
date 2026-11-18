class_name NightDetails
extends Node3D

# 4.12.0 small things that make the night feel lived in, and wrong:
# - failing tubes in the maintenance room and corridor stutter and click;
# - the guard leaves shoe prints in the dust, fading as new ones are made;
# - anomaly "dust_footprints": small children's prints run from the ball pit
#   to the south wall and stop there;
# - anomaly "cold_breath": in the kitchen the guard's breath shows, frost
#   creeps over the walls and the light turns cold;
# - stand still long enough and somebody whispers or giggles, somewhere else.
const FOOTPRINT_ID:="dust_footprints"
const BREATH_ID:="cold_breath"
const KITCHEN:=Rect2(-17.5,-35.5,9.2,11.5)
const WHISPERS:=["res://assets/quality-v410/audio/whisper-1.ogg","res://assets/quality-v410/audio/whisper-2.ogg","res://assets/quality-v410/audio/whisper-3.ogg","res://assets/quality-v410/audio/whisper-4.ogg","res://assets/ambience/children-laugh.ogg"]
var w: PlayWorld
var anomaly:="none"
var rng:=RandomNumberGenerator.new()
# Flickering tubes.
var tubes: Array[Dictionary]=[]
var click: AudioStreamPlayer3D
# The guard's own prints.
var prints: Array[Decal]=[]
var next_print:=0
var last_step:=Vector3.INF
var left_foot:=false
# Cold breath.
var breath_clock:=0.
var puffs: Array[CPUParticles3D]=[]
var puff_index:=0
var cold_light: OmniLight3D
# Whispers in the stillness.
var still:=0.
var whisper_cooldown:=40.
var whisper: AudioStreamPlayer3D
var whispered:=0

static var sole_map: ImageTexture
static func sole() -> ImageTexture:
 if sole_map:return sole_map
 var image:=Image.create(64,160,false,Image.FORMAT_RGBA8)
 for y in range(160):
  for x in range(64):
   var u:=(x-31.5)/32.;var v:=y/159.
   # Forefoot and heel ellipses joined by a narrow waist, with tread bars.
   var fore:=pow(u/(.92-.1*v),2.)+pow((v-.28)/.27,2.)
   var heel:=pow(u/.72,2.)+pow((v-.82)/.17,2.)
   var waist:=absf(u)<.5-.1*sin(v*PI) and v>.45 and v<.7
   var inside:=fore<1. or heel<1. or waist
   var tread:=.75+.25*float(int(v*40.)%2)
   image.set_pixel(x,y,Color(.12,.11,.1,(.85*tread) if inside else 0.))
 image.generate_mipmaps()
 sole_map=ImageTexture.create_from_image(image);return sole_map

static var frost_map: ImageTexture
static func frost() -> ImageTexture:
 if frost_map:return frost_map
 var noise:=FastNoiseLite.new();noise.seed=909;noise.frequency=.06;noise.fractal_octaves=5
 var image:=Image.create(128,128,false,Image.FORMAT_RGBA8)
 for y in range(128):
  for x in range(128):
   var r:=Vector2(x-63.5,y-63.5).length()/64.;var n:=noise.get_noise_2d(x,y)*.5+.5
   image.set_pixel(x,y,Color(.86,.93,1.,clampf((1.-r)*1.6*smoothstep(.35,.7,n),0,.9)))
 image.generate_mipmaps()
 frost_map=ImageTexture.create_from_image(image);return frost_map

func build(world: PlayWorld) -> void:
 w=world;name="NightDetails";rng.randomize();process_priority=950
 click=AudioStreamPlayer3D.new();click.name="TubeStarterClick";click.stream=load("res://assets/ambience/relay-tick.wav");click.volume_db=-8;click.unit_size=2.5;click.max_distance=14;add_child(click)
 whisper=AudioStreamPlayer3D.new();whisper.name="WhisperInTheStillness";whisper.unit_size=3.;whisper.max_distance=22;whisper.volume_db=-16;whisper.attenuation_filter_cutoff_hz=2600;add_child(whisper)
 _tubes()
 for i in range(36):
  var d:=Decal.new();d.name="GuardShoePrint";d.texture_albedo=sole();d.size=Vector3(.11,.3,.29);d.albedo_mix=0.;d.cull_mask=1;d.visible=false;add_child(d);prints.append(d)

# Two tubes have bad starters: the maintenance room strip and a corridor lamp.
func _tubes() -> void:
 for light: Light3D in w.find_children("*","OmniLight3D",true,false):
  var p:=light.global_position
  var server:=p.distance_to(Vector3(-13.35,2.89,-4.4))<.05
  var corridor:=p.distance_to(Vector3(-9.75,2.9,-8))<.05
  if not (server or corridor):continue
  var glow: StandardMaterial3D=null
  if server:
   for mesh: MeshInstance3D in w.server_room.find_children("*","MeshInstance3D",true,false):
    if mesh.position.distance_to(Vector3(-13.35,2.99,-4.4))<.05:glow=mesh.material_override as StandardMaterial3D
  tubes.append({"light":light,"energy":light.light_energy,"glow":glow,"glow_energy":glow.emission_energy_multiplier if glow else 0.,"wait":rng.randf_range(3.,9.),"burst":-1.,"on":true})

func configure(id: String) -> void:
 anomaly=id
 if id==FOOTPRINT_ID:_child_trail()
 if id==BREATH_ID:_cold_kitchen()

# Small prints from the ball pit straight to the south wall, where they end.
func _child_trail() -> void:
 var start:=Vector3(4.2,0,8.7);var end:=Vector3(5.1,0,16.75);var step:=.33
 var count:=int(start.distance_to(end)/step)
 var heading:=(end-start).normalized();var side:=heading.cross(Vector3.UP).normalized()
 for i in range(count):
  var d:=Decal.new();d.name="ChildFootprint";d.set_meta("night_detail","child_print");d.texture_albedo=sole();d.size=Vector3(.085,.3,.2);d.albedo_mix=1.;d.modulate=Color(.6,.55,.5);d.cull_mask=1;add_child(d)
  d.position=start+heading*i*step+side*(.06 if i%2 else -.06)+Vector3(0,.06,0)
  d.rotation.y=atan2(heading.x,heading.z)+(.08 if i%2 else -.08)

func _cold_kitchen() -> void:
 cold_light=OmniLight3D.new();cold_light.name="ColdKitchenLight";cold_light.light_color=Color("9fc6ff");cold_light.light_energy=.7;cold_light.omni_range=9;add_child(cold_light)
 cold_light.global_position=Vector3(KITCHEN.get_center().x,2.4,KITCHEN.get_center().y)
 for i in range(10):
  var d:=Decal.new();d.name="KitchenFrost";d.set_meta("night_detail","frost");d.texture_albedo=frost();d.albedo_mix=.8;d.size=Vector3(1.4,.6,1.2);d.cull_mask=1;add_child(d)
  var side:=i%4;var t:=rng.randf_range(.15,.85)
  var at: Vector3;var normal: Vector3
  match side:
   0:at=Vector3(KITCHEN.position.x,rng.randf_range(.6,2.2),lerpf(KITCHEN.position.y,KITCHEN.end.y,t));normal=Vector3.RIGHT
   1:at=Vector3(KITCHEN.end.x,rng.randf_range(.6,2.2),lerpf(KITCHEN.position.y,KITCHEN.end.y,t));normal=Vector3.LEFT
   2:at=Vector3(lerpf(KITCHEN.position.x,KITCHEN.end.x,t),rng.randf_range(.6,2.2),KITCHEN.position.y);normal=Vector3.BACK
   _:at=Vector3(lerpf(KITCHEN.position.x,KITCHEN.end.x,t),rng.randf_range(.6,2.2),KITCHEN.end.y);normal=Vector3.FORWARD
  var y:=normal;var x:=Vector3.UP.cross(y).normalized();d.basis=Basis(x,y,x.cross(y));d.position=at
 # A thin, soft wisp: a radial gradient, faint and short-lived.
 var soft:=GradientTexture2D.new();soft.fill=GradientTexture2D.FILL_RADIAL;soft.fill_from=Vector2(.5,.5);soft.fill_to=Vector2(1.,.5);soft.width=64;soft.height=64
 var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,1));ramp.set_color(1,Color(1,1,1,0));soft.gradient=ramp
 var dot:=QuadMesh.new();dot.size=Vector2(.09,.09)
 var mist:=StandardMaterial3D.new();mist.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mist.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mist.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mist.albedo_texture=soft;mist.albedo_color=Color(.92,.96,1.,.16);mist.vertex_color_use_as_albedo=true;mist.disable_receive_shadows=true;dot.material=mist
 for i in range(3):
  var puff:=CPUParticles3D.new();puff.name="GuardBreath";puff.one_shot=true;puff.emitting=false;puff.amount=9;puff.lifetime=1.2;puff.explosiveness=.8;puff.local_coords=false
  puff.mesh=dot;puff.direction=Vector3(0,.1,-1);puff.spread=18;puff.initial_velocity_min=.18;puff.initial_velocity_max=.35;puff.gravity=Vector3(0,.12,0);puff.damping_min=.4;puff.damping_max=.8
  puff.scale_amount_min=.6;puff.scale_amount_max=1.4;var curve:=Curve.new();curve.add_point(Vector2(0,.5));curve.add_point(Vector2(1,2.2));puff.scale_amount_curve=curve
  var fade:=Gradient.new();fade.set_color(0,Color(1,1,1,.9));fade.set_color(1,Color(1,1,1,0));puff.color_ramp=fade
  add_child(puff);puffs.append(puff)

func _process(delta: float) -> void:
 var game:=w.get_parent()
 if not game or game.get("phase")!="play":
  if whisper:whisper.stream_paused=game!=null and game.get("phase")!="play"
  return
 whisper.stream_paused=false
 delta=minf(delta,.1)
 var player: NightGuard=game.get("player")
 if not player:return
 _flicker(delta)
 _footsteps(player)
 if anomaly==BREATH_ID:_breathe(delta,player)
 _stillness(delta,player)

func _flicker(delta: float) -> void:
 for tube in tubes:
  var light: Light3D=tube.light
  if not is_instance_valid(light):continue
  if tube.burst<0:
   tube.wait-=delta
   if tube.wait<=0:tube.burst=0.;tube.length=rng.randf_range(.35,1.4)
   continue
  tube.burst+=delta
  var on:bool=fmod(tube.burst*rng.randf_range(9.,16.),1.)>.45 or tube.burst>tube.length
  if on!=tube.on:
   tube.on=on
   if on:click.global_position=light.global_position;click.pitch_scale=rng.randf_range(.9,1.15);click.play()
  light.light_energy=tube.energy*(1. if on else .05)
  if tube.glow:tube.glow.emission_energy_multiplier=tube.glow_energy*(1. if on else .05)
  if tube.burst>tube.length:tube.burst=-1.;tube.wait=rng.randf_range(4.,12.);light.light_energy=tube.energy

func _footsteps(player: NightGuard) -> void:
 var foot:=player.global_position
 if not player.is_on_floor() or player.velocity.length()<.4:return
 if last_step!=Vector3.INF and foot.distance_to(last_step)<.62:return
 var heading:=Vector3(player.velocity.x,0,player.velocity.z).normalized()
 var side:=heading.cross(Vector3.UP).normalized()
 left_foot=not left_foot;last_step=foot
 var d: Decal=prints[next_print];next_print=(next_print+1)%prints.size()
 d.visible=true;d.global_position=foot+side*(.1 if left_foot else -.1)+Vector3(0,.06,0);d.rotation=Vector3(0,atan2(heading.x,heading.z),0)
 # Newer prints are the clearest; the oldest fade out of the dust.
 for i in range(prints.size()):
  var age:=(next_print-1-i+prints.size())%prints.size()
  prints[i].albedo_mix=.32*(1.-float(age)/prints.size())

func _breathe(delta: float,player: NightGuard) -> void:
 var p:=player.global_position
 if not KITCHEN.has_point(Vector2(p.x,p.z)):return
 breath_clock-=delta
 if breath_clock>0:return
 breath_clock=rng.randf_range(2.1,2.8)
 var puff: CPUParticles3D=puffs[puff_index];puff_index=(puff_index+1)%puffs.size()
 var eye:=player.camera.global_transform
 puff.global_position=eye.origin-eye.basis.z*.22-eye.basis.y*.12
 puff.direction=(-eye.basis.z+Vector3(0,.15,0)).normalized();puff.restart()

func _stillness(delta: float,player: NightGuard) -> void:
 whisper_cooldown-=delta
 still=still+delta if Vector2(player.velocity.x,player.velocity.z).length()<.15 else 0.
 if still<7. or whisper_cooldown>0 or whisper.playing:return
 whisper_cooldown=rng.randf_range(45.,100.);still=0.
 if rng.randf()>.65:return
 var back:=player.camera.global_basis.z;back.y=0;back=back.normalized() if back.length()>.1 else Vector3.BACK
 var at:=player.global_position+back.rotated(Vector3.UP,rng.randf_range(-1.4,1.4))*rng.randf_range(6.,9.)+Vector3(0,1.1,0)
 whisper.stream=load(WHISPERS[rng.randi()%WHISPERS.size()]);whisper.pitch_scale=rng.randf_range(.92,1.05)
 whisper.global_position=at;whisper.play();whispered+=1

func snapshot() -> Dictionary:
 return {"anomaly":anomaly,"tubes":tubes.size(),"prints":prints.filter(func(d):return d.visible).size(),"child_prints":get_children().filter(func(n):return n.get_meta("night_detail","")=="child_print").size(),"frost":get_children().filter(func(n):return n.get_meta("night_detail","")=="frost").size(),"puffs":puffs.size(),"whispered":whispered}
