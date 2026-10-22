class_name ElevatorIntro
extends Node3D

signal finished
const LINES: Array[String]=[
 "Gut, du bist da. Die Nachtschicht gehört dir.",
 "Präg dir das Kinderparadies ein. Der erste Rundgang ist dein Vergleich: So soll alles aussehen.",
 "Keine Veränderung? Grüne Tür. Etwas stimmt nicht? Rote Tür.",
 "Dreizehn richtige Entscheidungen in Folge. Eine falsche Tür kostet dich die ganze Schicht.",
 "Der Clown rührt am Herd. Kinderstimmen sind hier normal. Verlass dich auf deine Augen.",
 "Und wenn dir etwas zu nahe kommt … bleib nicht stehen. Bis morgen."
]
var guard: NightGuard
var doors: Array[Node3D]=[]
var phone: Node3D
var overlay: CanvasLayer
var caption: Label
var status: Label
var phone_status: Label3D
var accept_button: Button
var skip_bar: ProgressBar
var ring: AudioStreamPlayer
var voice: AudioStreamPlayer
var motor: AudioStreamPlayer
var chime: AudioStreamPlayer
var stage:="idle"
var clock:=0.0
var stage_clock:=0.0
var skip_hold:=0.0
var paused:=false
var recording:=false
var call_length:=33.0
var starts:=0
var display: GuardPhoneDisplay

func build(w: PlayWorld, player: NightGuard) -> void:
 guard=player;name="ElevatorIntro"
 var cabin:=Node3D.new();cabin.position=Vector3(-8.0,0,18.8);add_child(cabin)
 var steel:=w.mat(Color("66736e"),load("res://assets/paint.png"),.46,.65)
 var trim:=w.mat(Color("272e2d"),null,.5,.7)
 var rubber:=w.mat(Color("292d27"),load("res://assets/floor.png"),.93)
 w.box(cabin,Vector3(0,-.074,0),Vector3(2.75,.18,3.3),rubber,true)
 w.box(cabin,Vector3(0,2.82,0),Vector3(2.85,.14,3.3),trim,true)
 w.box(cabin,Vector3(0,1.4,1.62),Vector3(2.85,2.8,.14),steel,true)
 for side in [-1,1]:
  w.box(cabin,Vector3(side*1.4,1.4,0),Vector3(.14,2.8,3.3),steel,true)
  w.tube(cabin,Vector3(side*1.29,.94,-1.15),Vector3(side*1.29,.94,1.32),.032,trim)
  for z in [-1.15,1.32]: w.tube(cabin,Vector3(side*1.29,.94,z),Vector3(side*1.39,.94,z),.023,trim)
  for z in [-.8,.0,.8]: w.box(cabin,Vector3(side*1.32,1.4,z),Vector3(.012,2.7,.008),trim)
  var door:=Node3D.new();door.position=Vector3(side*.65,1.3,-1.5);cabin.add_child(door);doors.append(door)
  w.box(door,Vector3.ZERO,Vector3(1.295,2.6,.065),steel)
  for k in range(5): w.box(door,Vector3(-.5+k*.25,0,-.037),Vector3(.009,2.56,.006),trim)
 w.box(cabin,Vector3(0,2.72,-1.5),Vector3(2.75,.12,.16),trim)
 var diffuser:=w.mat(Color("c1c9b6"));diffuser.emission_enabled=true;diffuser.emission=Color("c9ccad");diffuser.emission_energy_multiplier=.8
 w.box(cabin,Vector3(0,2.73,0),Vector3(.65,.04,1.5),diffuser)
 for x in [-.37,.37]: w.box(cabin,Vector3(x,2.75,0),Vector3(.055,.07,1.62),trim)
 var light:=OmniLight3D.new();light.position=Vector3(0,2.4,.2);light.light_color=Color("d5d4b3");light.light_energy=1.3;light.omni_range=4;light.shadow_enabled=true;cabin.add_child(light)
 w.box(cabin,Vector3(1.30,1.35,-.8),Vector3(.04,.65,.24),trim)
 for y in [1.12,1.32,1.52]: w.tube(cabin,Vector3(1.275,y,-.8),Vector3(1.25,y,-.8),.035,steel)
 _cabin_details(w,cabin,steel,trim)
 # Bevelled, metre-scale handset with front glass, lenses and physical ports.
 phone=Node3D.new();guard.camera.add_child(phone);phone.position=Vector3(.12,-.16,-.43);phone.rotation=Vector3(-.04,-.12,-.045)
 var handset: Node3D=(load("res://assets/polish-v240/guard-phone.glb") as PackedScene).instantiate();phone.add_child(handset)
 phone_status=Label3D.new();phone_status.font=load("res://assets/Oswald.ttf");phone_status.font_size=42;phone_status.pixel_size=.00027;phone_status.position=Vector3(0,.01,.008);phone_status.no_depth_test=false;phone_status.outline_size=0;phone.add_child(phone_status)
 var phone_top:=Label3D.new();phone_top.text="03:17       82%";phone_top.font_size=20;phone_top.pixel_size=.00022;phone_top.position=Vector3(0,.061,.008);phone_top.outline_size=0;phone.add_child(phone_top)
 var phone_bottom:=Label3D.new();phone_bottom.text="ANRUF";phone_bottom.font=load("res://assets/Oswald.ttf");phone_bottom.font_size=24;phone_bottom.pixel_size=.00027;phone_bottom.modulate=Color("8cc6b1");phone_bottom.position=Vector3(0,-.056,.008);phone_bottom.outline_size=0;phone.add_child(phone_bottom)
 phone_status.hide();phone_top.hide();phone_bottom.hide()
 display=GuardPhoneDisplay.new();phone.add_child(display);display.build()
 var hand: Node3D=(load("res://assets/polish-v240/phone-hand.glb") as PackedScene).instantiate();hand.position=Vector3.ZERO;phone.add_child(hand)
 var cuff:=w.mat(Color("282e29"),load("res://assets/paint.png"),.95)
 w.tube(phone,Vector3(.004,-.083,-.018),Vector3(.035,-.32,.03),.028,cuff)
 phone.hide()
 overlay=CanvasLayer.new();overlay.layer=8;add_child(overlay)
 var panel:=VBoxContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);panel.offset_left=160;panel.offset_right=-160;panel.offset_top=-205;panel.offset_bottom=-28;panel.add_theme_constant_override("separation",10);overlay.add_child(panel)
 status=Label.new();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",18);panel.add_child(status)
 caption=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",23);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_outline_size",6);panel.add_child(caption)
 accept_button=Button.new();accept_button.text="Annehmen   [E]";accept_button.custom_minimum_size.y=48;accept_button.pressed.connect(accept);panel.add_child(accept_button)
 var hint:=Label.new();hint.text="LEERTASTE GEDRÜCKT HALTEN · INTRO ÜBERSPRINGEN";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",13);panel.add_child(hint)
 skip_bar=ProgressBar.new();skip_bar.max_value=1.35;skip_bar.custom_minimum_size.y=5;skip_bar.show_percentage=false;panel.add_child(skip_bar)
 ring=sound("res://assets/intro/ring.wav",-14);chime=sound("res://assets/intro/chime.wav",-9)
 motor=sound("res://assets/ambience/ventilation.ogg",-25);(motor.stream as AudioStreamOggVorbis).loop=true
 voice=sound("",-1.5);overlay.hide()

func _cabin_details(w: PlayWorld, cabin: Node3D, steel: Material, trim: Material) -> void:
 var brass:=w.mat(Color("7f795e"),null,.48,.8)
 # Physical skirting, corner channels, handrail brackets and screw heads.
 for side in [-1,1]:
  for y in [.12,2.64]: w.box(cabin,Vector3(side*1.315,y,0),Vector3(.035,.09,3.1),trim)
  for z in [-1.4,1.45]:
   w.box(cabin,Vector3(side*1.315,1.38,z),Vector3(.04,2.6,.055),trim)
   for y in [.24,2.5]: w.tube(cabin,Vector3(side*1.28,y,z),Vector3(side*1.32,y,z),.012,brass)
  for z in [-.72,.24,1.12]:
   w.tube(cabin,Vector3(side*1.29,.94,z),Vector3(side*1.33,.94,z),.044,steel)
  for z in [-1.2,-.4,.4,1.2]: w.box(cabin,Vector3(side*1.307,1.42,z),Vector3(.014,2.25,.004),trim)
 for x in [-1.19,1.19]:
  w.box(cabin,Vector3(x,1.39,1.53),Vector3(.035,2.64,.04),trim)
  for y in [.25,2.52]: w.tube(cabin,Vector3(x,y,1.50),Vector3(x,y,1.54),.013,brass)
 w.tube(cabin,Vector3(-1.17,.94,1.42),Vector3(1.17,.94,1.42),.032,steel)
 for x in [-1.0,1.0]: w.tube(cabin,Vector3(x,.94,1.42),Vector3(x,.94,1.54),.026,trim)
 # Recessed threshold grooves stay below the walking surface.
 for z in [-1.52,-1.45,-1.38]: w.box(cabin,Vector3(0,.015,z),Vector3(2.58,.009,.014),steel)
 w.box(cabin,Vector3(0,2.57,-1.435),Vector3(.42,.14,.024),trim)
 var display:=Label3D.new();display.text="03  ▲";display.font=load("res://assets/Oswald.ttf");display.font_size=48;display.pixel_size=.00145;display.position=Vector3(0,2.57,-1.416);display.modulate=Color("d1a46c");display.outline_size=0;cabin.add_child(display)
 w.box(cabin,Vector3(1.265,1.67,-.8),Vector3(.035,.20,.25),trim)
 var side_display:=display.duplicate() as Label3D;side_display.position=Vector3(1.241,1.67,-.8);side_display.rotation.y=-PI/2;side_display.pixel_size=.001;cabin.add_child(side_display)
 for y in [1.80,1.82,1.84,1.86]:
  for z in [-.85,-.82,-.79,-.76]: w.sphere(cabin,Vector3(1.245,y,z),.0035,w.materials.dark)
 # A ceiling ventilation grille has an actual frame and recessed slots.
 w.box(cabin,Vector3(0,2.725,1.12),Vector3(.72,.035,.28),trim)
 for k in range(13): w.box(cabin,Vector3(-.3+k*.05,2.701,1.12),Vector3(.024,.009,.22),steel)
 for x in [-.31,.31]:
  for z in [.26,-.26]: w.sphere(cabin,Vector3(x,2.697,z),.009,brass)

func sound(path: String, db: float) -> AudioStreamPlayer:
 var node:=AudioStreamPlayer.new();node.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;node.volume_db=db
 if not path.is_empty(): node.stream=load(path)
 add_child(node);return node

func start() -> void:
 starts+=1;clock=0;stage_clock=0;skip_hold=0;paused=false;stage="ringing"
 guard.release();guard.position=Vector3(-8.0,0,19.35);guard.rotation=Vector3.ZERO;guard.camera.rotation=Vector3.ZERO;guard.camera.fov=66;guard.lamp.hide()
 for i in range(2): doors[i].position.x=(-.65 if i==0 else .65)
 phone.show();phone.position.y=-.49;overlay.show();accept_button.hide();caption.text="";status.text="03:17 · AUFWÄRTS"
 phone_status.text="CHEF\n\nEingehender\nAnruf";motor.play();ring.play()
 voice.stream=null
 var external:=OS.get_executable_path().get_base_dir().path_join("Intro/chef.mp3")
 if not OS.has_feature("web") and FileAccess.file_exists(external): voice.stream=AudioStreamMP3.load_from_file(external)
 elif ResourceLoader.exists("res://assets/intro/chef.mp3"): voice.stream=load("res://assets/intro/chef.mp3")
 recording=voice.stream!=null;call_length=voice.stream.get_length() if recording else 33.0

func accept() -> void:
 if stage!="ringing" or clock<1.1 or paused: return
 stage="call";stage_clock=0;ring.stop();accept_button.hide();phone_status.text="CHEF\n\nVerbunden";status.text="CHEF · VERBUNDEN"
 if recording: voice.play()

func tick(delta: float) -> void:
 if stage in ["idle","done"]: return
 for audio in [ring,voice,motor,chime]:
  if audio.stream_paused!=paused: audio.stream_paused=paused
 if paused: status.text="PAUSE · ESC ZUM FORTSETZEN";return
 clock+=delta;stage_clock+=delta
 display.update_call(stage,stage_clock)
 phone.rotation.z=-.045+(sin(clock*1.3)*.009 if guard.motion else 0.0)
 if guard.motion: guard.camera.position.y=1.65+sin(clock*18)*.0015
 skip_hold=minf(1.35,skip_hold+delta) if Input.is_action_pressed("jump") else 0.0;skip_bar.value=skip_hold
 if skip_hold>=1.35: skip();return
 phone.position.y=lerpf(-.49,-.12,smoothstep(.5,1.3,clock)) if stage in ["ringing","call"] else lerpf(phone.position.y,-.55,delta*4)
 if stage=="ringing":
  status.text="03:17 · EINGEHENDER ANRUF";accept_button.visible=clock>1.1
  if not ring.playing and fmod(clock,3.3)<.06: ring.play()
 elif stage=="call":
  status.text="CHEF · %02d:%02d"%[int(stage_clock)/60,int(stage_clock)%60]
  caption.text="" if recording else LINES[mini(LINES.size()-1,int(stage_clock/maxf(call_length,1)*LINES.size()))]
  if stage_clock>=call_length or (recording and stage_clock>.3 and not voice.playing):
   stage="arrival";stage_clock=0;voice.stop();phone_status.text="Anruf\nbeendet";caption.text="";status.text="KINDERPARADIES · 3. STOCK";motor.stop();chime.play()
 elif stage=="arrival":
  var amount:=smoothstep(.45,2.2,stage_clock)
  for i in range(2): doors[i].position.x=(-1 if i==0 else 1)*(.65+amount*1.24)
  if stage_clock>2.45: complete()

func skip() -> void:
 if stage in ["idle","done"]: return
 for i in range(2): doors[i].position.x=(-1 if i==0 else 1)*1.89
 complete()

func complete() -> void:
 stage="done";paused=false;overlay.hide();accept_button.hide();phone.hide()
 for audio in [ring,voice,motor,chime]: audio.stop()
 guard.camera.fov=guard.base_fov;finished.emit()

func stop() -> void:
 stage="idle";overlay.hide();accept_button.hide();phone.hide()
 for audio in [ring,voice,motor,chime]: audio.stop()

func snapshot() -> Dictionary:
 return {"stage":stage,"clock":clock,"call_clock":stage_clock,"skip":skip_hold,"paused":paused,"recording":recording,"duration":call_length,"starts":starts,"voice_playing":voice.playing,"voice_paused":voice.stream_paused,"caption":caption.text}
