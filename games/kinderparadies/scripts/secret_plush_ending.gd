class_name SecretPlushEnding
extends Node3D

# Secret ending (4.10.0). Find all five creator plushes (E puts a carried plush
# in the inventory), answer the ringing reception phone, seat the plushes on the
# chairs at the birthday table. Then the camera lifts out of the venue, every
# room gets its shine back, one after another, the old entrance opens and thirty
# children run in: into the ball pit, up the climbing frames, through the crawl
# tube and to the birthday table. Fade to black, then the credits.

signal finished
const CALL_TEXT:="„Du hast uns alle gefunden. Lass uns zum Abschluss einen Kuchen essen.“"
const TEST_CODE:="55555555"
const MUSIC:="res://assets/secret-v4100/birthday-music-box.ogg"
# The girl on the line, recorded for the game.
const CALL_VOICE:="res://assets/secret-v4100/girl-call.ogg"
const RISE_END:=4.5
const WIDE_END:=9.0
const ROOM_START:=6.0
const ROOM_STEP:=2.4
const DOOR_AT:=29.5
const KIDS_AT:=30.0
const KID_GAP:=.2
const FADE_AT:=54.0
const DURATION:=57.0
# Rooms in the order they get their shine back: name, x range, z range, lamp height.
const ROOMS:=[
 ["Party Raum",6.9,19.8,-18.7,1.5,3.6],["Halle",-10.2,6.9,-12.3,4.0,3.6],["Bällebad",-3.0,19.8,4.0,17.2,3.6],
 ["Empfang",-10.2,-3.0,4.0,17.2,2.6],["Eingang",-16.0,-10.2,8.2,10.6,2.5],["Wartung",-16.5,-10.2,-12.5,-1.8,2.5],
 ["Personalflur",-9.5,-0.5,-30.0,-12.3,2.5],["Küche",-17.5,-8.3,-35.5,-24.0,2.6],["Kino",-6.4,4.3,-35.5,-24.0,2.6],
 ["Kinder-WC",19.8,25.0,4.5,10.5,2.4]]
const GRIME:=["blood","stain","grime","mould","mold","spoiled","cobweb","claw","remnant","puddle","splatter","smear","decay","drip","corpse","remains","filth","dirt","bone","rot","plasterdamage"]
var g: Node3D
var w: PlayWorld
var phone: Node3D
var ring: AudioStreamPlayer3D
var phone_body: StaticBody3D
var chair_bodies: Array[StaticBody3D]=[]
var seated: Dictionary={}
var cloth: AudioStreamPlayer3D
var call_voice: AudioStreamPlayer
# Finale
var running:=false
var clock:=0.0
var camera: Camera3D
var start_pose:=Transform3D.IDENTITY
var environment: Environment
var base_ambient:=0.1
var base_exposure:=1.0
var music: AudioStreamPlayer
var chime: AudioStreamPlayer
var lifted:=false
var restored:=0
var room_lights: Array=[]
var grime: Array=[]
var children: Array[Dictionary]=[]
var spawned:=0
var door_glow: OmniLight3D
var shade: ColorRect
var done:=false

# Ceiling slabs: thin, wide boxes high above the floor. Lifting them turns the
# venue into a dollhouse for the closing camera. Returns what it hid.
static func lift_ceilings(world: PlayWorld) -> Array[Node3D]:
 var hidden: Array[Node3D]=[]
 # The climbing frame, its towers and the crawl tubes have real floors up there.
 var keep: Array[Node]=[world.tubes,world.playground,world.climbing]
 for id in ["structure","nets","slide","pit","giant"]:
  if world.props.has(id):keep.append(world.props[id])
 for geometry: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
  if not geometry.visible or geometry is Label3D:continue
  if keep.any(func(k):return is_instance_valid(k) and (k==geometry or k.is_ancestor_of(geometry))):continue
  var box:=geometry.global_transform*geometry.get_aabb()
  if box.position.y>2.6 and box.size.y<.6 and box.size.x*box.size.z>.04:
   geometry.hide();hidden.append(geometry)
 return hidden

static func plush_id(node: Node) -> String:
 if not node is NightProp:return ""
 for id in CreatorPlush.PLUSHES:
  if CreatorPlush.PLUSHES[id].node==node.name:return id
 return ""

func setup(game: Node3D) -> void:
 g=game;w=g.world;name="SecretPlushEnding";process_priority=900
 phone=w.find_child("ReceptionDeskPhone",true,false) as Node3D
 var at: Vector3=phone.global_position if phone else Vector3(-7.8,1.0,7.8)
 ring=AudioStreamPlayer3D.new();ring.name="ReceptionPhoneRing";ring.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var tone: AudioStreamWAV=load("res://assets/intro/ring.wav").duplicate();tone.loop_mode=AudioStreamWAV.LOOP_FORWARD;tone.loop_end=int(tone.get_length()*tone.mix_rate);ring.stream=tone
 ring.unit_size=9;ring.max_distance=70;ring.volume_db=-2;add_child(ring);ring.global_position=at+Vector3(0,.15,0)
 phone_body=StaticBody3D.new();phone_body.name="ReceptionPhoneInteraction";phone_body.collision_layer=2;phone_body.collision_mask=0;phone_body.set_meta("interaction","reception_phone");add_child(phone_body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.42,.26,.36);shape.shape=bounds;phone_body.add_child(shape);phone_body.global_position=at+Vector3(0,.1,0)
 call_voice=AudioStreamPlayer.new();call_voice.name="GirlOnTheLine";call_voice.stream=load(CALL_VOICE);call_voice.volume_db=-1;call_voice.bus="NightVoice" if AudioServer.get_bus_index("NightVoice")>=0 else "Master";add_child(call_voice)
 cloth=AudioStreamPlayer3D.new();cloth.name="PlushSeated";cloth.stream=load("res://assets/polish/impact-cloth.wav");cloth.volume_db=-6;add_child(cloth)

func ringing() -> bool:
 return ring.playing

func start_ring() -> void:
 if not ring.playing:ring.play()

func answer() -> void:
 ring.stop();call_voice.play()

func phone_prompt() -> String:
 return "E · Abheben" if ring.playing else ""

# The six birthday chairs take a plush each once the call is answered.
func open_chairs() -> void:
 if not chair_bodies.is_empty():return
 var chairs: Array=w.props.chairs.get_children()
 for i in range(chairs.size()):
  var body:=StaticBody3D.new();body.name="BirthdayChairSeat%d"%i;body.collision_layer=2;body.collision_mask=0;body.set_meta("interaction","plush_chair:%d"%i)
  var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.5,.82,.58);shape.shape=bounds;body.add_child(shape)
  # Tall enough to cover the backrest: a seat is easy to aim at from any side.
  chairs[i].add_child(body);body.position=Vector3(0,.86,.02);chair_bodies.append(body)

func next_plush(found: Array) -> String:
 for id in found:
  if id not in seated.values():return id
 return ""

func chair_prompt(index: int,found: Array) -> String:
 if seated.has(index):return ""
 var id:=next_plush(found)
 return "E · %s hinsetzen"%CreatorPlush.PLUSHES[id].title if id!="" else ""

# Seats the next plush on this chair, facing the table. True once all five sit.
func seat(index: int,found: Array) -> bool:
 var id:=next_plush(found)
 if id=="" or seated.has(index):return false
 var chair: Node3D=w.props.chairs.get_child(index)
 var model: Node3D=(load(CreatorPlush.PLUSHES[id].model) as PackedScene).instantiate();model.name="Seated"+CreatorPlush.PLUSHES[id].node
 chair.add_child(model);model.position=Vector3(0,.465,-.02);model.rotation.y=PI
 seated[index]=id;cloth.global_position=chair.global_position+Vector3(0,.6,0);cloth.play()
 return seated.size()>=CreatorPlush.PLUSHES.size()

# ---------------------------------------------------------------- finale
func start_finale() -> void:
 if running:return
 running=true;clock=0
 for source in w.find_children("*","AudioStreamPlayer",true,false)+w.find_children("*","AudioStreamPlayer3D",true,false):
  if is_ancestor_of(source):continue
  source.stop();source.stream_paused=true
 var eye: Camera3D=g.player.camera
 start_pose=eye.global_transform
 camera=Camera3D.new();camera.name="SecretEndingCamera";camera.fov=eye.fov;camera.near=.05;camera.far=260;add_child(camera)
 camera.global_transform=start_pose;camera.make_current()
 environment=w.environment.environment.duplicate();w.environment.environment=environment
 base_ambient=environment.ambient_light_energy;base_exposure=environment.tonemap_exposure
 music=AudioStreamPlayer.new();music.name="BirthdayMusicBox";var tune: AudioStreamOggVorbis=(load(MUSIC) as AudioStreamOggVorbis).duplicate();tune.loop=true;music.stream=tune;music.volume_db=-6;music.bus="Master";add_child(music)
 chime=AudioStreamPlayer.new();chime.name="RoomChime";chime.stream=load("res://assets/theraidenlena-v490/music-box.ogg");chime.volume_db=-30;chime.bus="Master";add_child(chime)
 for spec in ROOMS:room_lights.append([])
 _collect_grime()
 door_glow=OmniLight3D.new();door_glow.name="OpenEntranceGlow";door_glow.light_color=Color("ffe9c4");door_glow.light_energy=0;door_glow.omni_range=9;add_child(door_glow);door_glow.global_position=Vector3(-15.0,2.1,9.4)
 var layer:=CanvasLayer.new();layer.layer=50;add_child(layer)
 shade=ColorRect.new();shade.color=Color(0,0,0,0);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(shade)

func _collect_grime() -> void:
 for node: Node3D in w.find_children("*","Node3D",true,false):
  if node.get_parent()==w or is_ancestor_of(node):continue
  var title:=String(node.name).to_lower()
  if GRIME.any(func(word):return word in title) or (w.wall_decay and node.get_parent()==w.wall_decay):
   grime.append(node)

func _room_of(p: Vector3) -> int:
 for i in range(ROOMS.size()):
  var r: Array=ROOMS[i]
  if p.x>=r[1] and p.x<=r[2] and p.z>=r[3] and p.z<=r[4]:return i
 return -1

func _restore_room(index: int) -> void:
 var r: Array=ROOMS[index]
 var nx:=maxi(1,int(ceil((r[2]-r[1])/7.)));var nz:=maxi(1,int(ceil((r[4]-r[3])/7.)))
 for ix in range(nx):
  for iz in range(nz):
   var light:=OmniLight3D.new();light.light_color=Color("fff1dc");light.light_energy=0;light.omni_range=8.5;light.omni_attenuation=.9;light.shadow_enabled=false
   add_child(light);light.global_position=Vector3(lerpf(r[1],r[2],(ix+.5)/nx),r[5],lerpf(r[3],r[4],(iz+.5)/nz))
   room_lights[index].append(light)
 for node in grime:
  if is_instance_valid(node) and _room_of(node.global_position)==index:node.hide()
 var sparkle:=CPUParticles3D.new();sparkle.name="ShineReturns";sparkle.one_shot=true;sparkle.amount=160;sparkle.lifetime=2.2;sparkle.explosiveness=.55
 sparkle.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;sparkle.emission_box_extents=Vector3((r[2]-r[1])*.5,.9,(r[4]-r[3])*.5)
 sparkle.direction=Vector3.UP;sparkle.spread=35;sparkle.initial_velocity_min=.6;sparkle.initial_velocity_max=1.8;sparkle.gravity=Vector3(0,.4,0)
 sparkle.scale_amount_min=.6;sparkle.scale_amount_max=1.4
 var dot:=QuadMesh.new();dot.size=Vector2(.16,.16);var glow:=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow.albedo_color=Color("ffe7a6");glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;dot.material=glow
 sparkle.mesh=dot;add_child(sparkle);sparkle.global_position=Vector3((r[1]+r[2])*.5,1.2,(r[3]+r[4])*.5);sparkle.emitting=true
 chime.pitch_scale=1.+index*.06;chime.play()

func _camera_at(t: float) -> void:
 var above:=Vector3(10.2,10.,-.5);var above_look:=Vector3(10.2,0,-7.)
 var wide:=Vector3(3.,40.,20.);var wide_look:=Vector3(3.,0,-9.)
 var p: Vector3;var look: Vector3
 if t<RISE_END:
  var k:=smoothstep(0.,RISE_END,t)
  var start_look:=start_pose.origin-start_pose.basis.z*3.
  p=start_pose.origin.lerp(above,k);look=start_look.lerp(above_look,k)
 elif t<WIDE_END:
  var k:=smoothstep(RISE_END,WIDE_END,t);p=above.lerp(wide,k);look=above_look.lerp(wide_look,k)
 elif t<DOOR_AT:
  var drift:=Vector3(sin((t-WIDE_END)*.12)*3.,0,0);p=wide+drift;look=wide_look+drift*.5
 elif t<DOOR_AT+9.:
  # Down to the old entrance: the door swings open, the children pour in.
  var k:=smoothstep(DOOR_AT,DOOR_AT+4.,t);var drift:=Vector3(sin((DOOR_AT-WIDE_END)*.12)*3.,0,0)
  var door:=Vector3(-7.5,8.5,16.5);var door_look:=Vector3(-11.,0,9.4)
  p=(wide+drift).lerp(door,k);look=(wide_look+drift*.5).lerp(door_look,k)
 else:
  # Then slowly over the hall while they spread into every corner.
  var k:=smoothstep(DOOR_AT+9.,DOOR_AT+15.,t)
  var door:=Vector3(-7.5,8.5,16.5);var door_look:=Vector3(-11.,0,9.4)
  var over:=Vector3(4.,13.,19.)+Vector3(sin(t*.1)*1.5,0,0);var over_look:=Vector3(4.,0,3.)
  p=door.lerp(over,k);look=door_look.lerp(over_look,k)
 camera.global_position=p;camera.look_at(look,Vector3.UP)

func _kid_path(i: int) -> Dictionary:
 var lane:=float(i%3-1)*.45
 var path: Array=[Vector3(-19.5-(i%2)*.6,0,9.4+lane),Vector3(-15.0,0,9.4+lane),Vector3(-10.0,0,9.4+lane*.7),Vector3(-6.,0,9.6+lane*.5)]
 var crawl_from:=-1;var finish:="cheer"
 var rng:=RandomNumberGenerator.new();rng.seed=i*31+7
 match i%6:
  0:
   path.append(Vector3(-3.2,0,9.9));path.append(Vector3(rng.randf_range(-1.4,3.6),0,rng.randf_range(5.9,7.7)));finish="wade"
  1:
   path.append_array([Vector3(-3.2,0,9.9),Vector3(5.6,0,9.9),Vector3(6.4,0,7.5),Vector3(11.1,2.15,7.5)])
   match int(i/6)%3:
    0:path.append(Vector3(12.,2.15,5.4))
    1:path.append_array([Vector3(12.,2.15,3.6),Vector3(10.8,2.15,3.6),Vector3(4.6,2.977,3.6)])
    _:path.append_array([Vector3(12.,2.15,3.6),Vector3(10.8,2.15,3.6),Vector3(4.03,2.977,3.6),Vector3(2.05,2.977,-.1),Vector3(2.05,4.15,-3.2)])
  2:
   path.append(Vector3(-5.5,0,11.));crawl_from=path.size()
   var depth:=rng.randf_range(3.,10.)
   var s:=0.
   while s<=depth:path.append(CrawlTubes.route(s)+Vector3(0,-.75,0));s+=.8
   finish="crawl"
  3:
   var seats:=[Vector3(10.2,0,-9.3),Vector3(10.2,0,-4.75),Vector3(12.4,0,-8.5),Vector3(12.4,0,-5.5),Vector3(8.1,0,-9.35),Vector3(8.1,0,-4.7)]
   var seat: Vector3=seats[int(i/6)%seats.size()]
   path.append_array([Vector3(-6.,0,6.),Vector3(-6.,0,-8.7),Vector3(5.9,0,-8.7),Vector3(8.,0,-9.6)])
   if seat.x>11.:path.append(Vector3(12.4,0,-9.6))
   elif seat.z> -6.:path.append(Vector3(8.,0,-4.7))
   path.append(seat)
  4:
   var spots:=[Vector3(7.5,0,12.),Vector3(9.5,0,10.2),Vector3(17.5,0,10.5),Vector3(7.,0,15.5),Vector3(14.,0,9.8)]
   path.append_array([Vector3(-3.2,0,9.9),Vector3(5.6,0,9.9),spots[int(i/6)%spots.size()]])
  _:
   var spots:=[Vector3(-5.5,0,5.),Vector3(-4.5,0,2.5),Vector3(-7.5,0,1.5),Vector3(-4.8,0,-3.)]
   path.append_array([Vector3(-5.5,0,7.),spots[int(i/6)%spots.size()]])
 return {"path":path,"crawl_from":crawl_from,"finish":finish,"speed":rng.randf_range(2.8,3.4)}

func _spawn_kid() -> void:
 var child:=HappyChildren.build(self,spawned)
 var plan:=_kid_path(spawned)
 child.merge(plan);child.leg=0;child.at=(plan.path[0] as Vector3)
 (child.root as Node3D).global_position=child.at
 children.append(child);spawned+=1

func _kid_tick(child: Dictionary,delta: float) -> void:
 var path: Array=child.path
 if child.leg>=path.size()-1:
  HappyChildren.pose(child,child.finish,1.,clock);return
 var crawling: bool=child.crawl_from>=0 and child.leg+1>=child.crawl_from
 var target: Vector3=path[child.leg+1]
 var to:=target-(child.at as Vector3)
 var step: float=(1.6 if crawling else child.speed)*delta
 if to.length()<=step:child.at=target;child.leg+=1
 else:child.at=(child.at as Vector3)+to.normalized()*step
 var root: Node3D=child.root;root.global_position=child.at
 var flat:=Vector2(to.x,to.z)
 if flat.length()>.01:root.rotation.y=lerp_angle(root.rotation.y,atan2(to.x,to.z),minf(1,delta*10))
 child.phase+=delta*(7. if crawling else 9.5)
 HappyChildren.pose(child,"crawl" if crawling else "run",1.,clock)

func _process(delta: float) -> void:
 if not running or done:
  if is_instance_valid(g) and ring:
   ring.stream_paused=g.get("phase")!="play";call_voice.stream_paused=ring.stream_paused
  return
 if g.get("phase")!="secret_finale":return
 delta=minf(delta,.1);clock+=delta
 _camera_at(clock)
 if not lifted and clock>=1.2:lifted=true;lift_ceilings(w)
 if clock>=4. and not music.playing and clock<FADE_AT:music.play()
 while restored<ROOMS.size() and clock>=ROOM_START+restored*ROOM_STEP:
  _restore_room(restored);restored+=1
 for i in range(room_lights.size()):
  var age:=clock-(ROOM_START+i*ROOM_STEP)
  for light: OmniLight3D in room_lights[i]:light.light_energy=1.5*smoothstep(0.,1.6,age)
 var shine:=clampf((clock-ROOM_START)/(ROOMS.size()*ROOM_STEP),0,1)
 environment.ambient_light_energy=lerpf(base_ambient,.55,shine);environment.ambient_light_color=Color("738c8b").lerp(Color("fff0df"),shine)
 environment.fog_density=lerpf(.025,.002,shine);environment.volumetric_fog_density=lerpf(.047,.004,shine)
 environment.tonemap_exposure=lerpf(base_exposure,base_exposure*1.12,shine)
 environment.adjustment_enabled=true;environment.adjustment_saturation=lerpf(.93,1.18,shine);environment.adjustment_brightness=lerpf(1.,1.06,shine)
 if clock>=DOOR_AT:
  var k:=smoothstep(DOOR_AT,DOOR_AT+2.,clock)
  if w.backstage.exit_leaf:w.backstage.exit_leaf.rotation.y=PI*.49*k
  door_glow.light_energy=2.4*k
 while clock>=KIDS_AT and spawned<30 and clock>=KIDS_AT+spawned*KID_GAP:_spawn_kid()
 for child in children:_kid_tick(child,delta)
 if clock>=FADE_AT:
  var f:=smoothstep(FADE_AT,FADE_AT+2.5,clock);shade.color.a=f;music.volume_db=-6-50*f
 if clock>=DURATION:
  done=true;music.stop();finished.emit()

func snapshot() -> Dictionary:
 return {"ringing":ring.playing if ring else false,"chairs":chair_bodies.size(),"seated":seated.duplicate(),"running":running,"clock":clock,"restored":restored,"children":children.size(),"lifted":lifted,"done":done,
  "door":w.backstage.exit_leaf.rotation.y if w and w.backstage and w.backstage.exit_leaf else 0.}
