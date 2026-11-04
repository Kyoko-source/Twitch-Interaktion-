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
var floor_number:=1
var floor_displays: Array[Label3D]=[]
var ticket:=ShiftTicket.new()

static func floor_text(value: int) -> String:
 return "%02d"%clampi(value,1,13)

func set_floor(value: int) -> void:
 floor_number=clampi(value,1,13)
 if is_instance_valid(ticket.paper):ticket.set_floor(floor_number)
 for indicator in floor_displays:indicator.text=floor_text(floor_number)

func build(w: PlayWorld, player: NightGuard) -> void:
 guard=player;name="ElevatorIntro"
 var cabin:=LiftCabin.new().build(w,self)
 ticket.build(w,cabin)
 set_floor(floor_number)
 phone=Node3D.new();phone.name="NightguardPhoneAndHand";guard.camera.add_child(phone);phone.position=Vector3(.115,-.145,-.385);phone.rotation=Vector3(-.10,-.17,-.035)
 var handset: Node3D=(load("res://assets/lift-v391/nightguard-handset.glb") as PackedScene).instantiate();handset.name="MachinedHandset";phone.add_child(handset)
 phone_status=Label3D.new();phone_status.hide();phone.add_child(phone_status)
 display=GuardPhoneDisplay.new();phone.add_child(display);display.build()
 var hand: Node3D=(load("res://assets/lift-v391/nightguard-phone-hand.glb") as PackedScene).instantiate();hand.name="FittedPhoneHand";phone.add_child(hand)
 var pores:=NoiseTexture2D.new();var noise:=FastNoiseLite.new();noise.seed=391;noise.frequency=.35;pores.noise=noise;pores.width=128;pores.height=128;pores.seamless=true;pores.as_normal_map=true;pores.bump_strength=.08
 for mesh in hand.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var source:=mesh.get_active_material(surface) as StandardMaterial3D
   if not source:continue
   var material:=source.duplicate() as StandardMaterial3D
   if "skin" in source.resource_name.to_lower():
    material.vertex_color_use_as_albedo=true;material.albedo_color=Color("d4bda5");material.roughness=.78;material.metallic_specular=.16
    material.normal_enabled=true;material.normal_texture=pores;material.normal_scale=.10;material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*48
   elif "cuff" in source.resource_name.to_lower():
    material.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg");material.normal_enabled=true;material.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");material.normal_scale=.15;material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*55
   mesh.set_surface_override_material(surface,material)
 for mesh in phone.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=2
 phone.hide()
 overlay=CanvasLayer.new();overlay.layer=8;add_child(overlay)
 var panel:=VBoxContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);panel.offset_left=160;panel.offset_right=-160;panel.offset_top=-205;panel.offset_bottom=-28;panel.add_theme_constant_override("separation",10);overlay.add_child(panel)
 status=Label.new();status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",18);panel.add_child(status)
 caption=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",23);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_outline_size",6);panel.add_child(caption)
 var centre:=CenterContainer.new();panel.add_child(centre)
 accept_button=Button.new();accept_button.text="Annehmen   [E]";accept_button.custom_minimum_size=Vector2(330,48);accept_button.pressed.connect(accept);centre.add_child(accept_button)
 var button_style:=StyleBoxFlat.new();button_style.bg_color=Color(.04,.07,.06,.84);button_style.border_color=Color("789382");button_style.set_border_width_all(1);button_style.set_corner_radius_all(4);accept_button.add_theme_stylebox_override("normal",button_style)
 var hover:=button_style.duplicate() as StyleBoxFlat;hover.bg_color=Color("284a3e");accept_button.add_theme_stylebox_override("hover",hover);accept_button.add_theme_stylebox_override("focus",hover);accept_button.add_theme_font_size_override("font_size",20)
 var hint:=Label.new();hint.text="LEERTASTE GEDRÜCKT HALTEN · INTRO ÜBERSPRINGEN";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",13);panel.add_child(hint)
 skip_bar=ProgressBar.new();skip_bar.max_value=1.35;skip_bar.custom_minimum_size.y=5;skip_bar.show_percentage=false;panel.add_child(skip_bar)
 ring=sound("res://assets/intro/ring.wav",-14);chime=sound("res://assets/intro/chime.wav",-9)
 motor=sound("res://assets/ambience/ventilation.ogg",-25);(motor.stream as AudioStreamOggVorbis).loop=true
 voice=sound("",-1.5);overlay.hide()

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

func start_return(wake: bool=false) -> void:
 stop();stage="return";clock=0;stage_clock=0;paused=false
 guard.release();guard.position=Vector3(-8,0,19.35);guard.rotation=Vector3.ZERO;guard.camera.rotation=Vector3(-.22 if wake else 0,0,0);guard.camera.fov=guard.base_fov
 for i in range(2): doors[i].position.x=(-.65 if i==0 else .65)
 chime.play()

func tick(delta: float) -> void:
 if stage in ["idle","done"]: return
 for audio in [ring,voice,motor,chime]:
  if audio.stream_paused!=paused: audio.stream_paused=paused
 if paused: status.text="PAUSE · ESC ZUM FORTSETZEN";return
 clock+=delta;stage_clock+=delta
 if stage=="return":
  for i in range(2): doors[i].position.x=(-1 if i==0 else 1)*(.65+smoothstep(.12,1.05,stage_clock)*1.24)
  guard.camera.rotation.x=lerpf(guard.camera.rotation.x,0,delta*3)
  if stage_clock>1.15: complete()
  return
 display.update_call(stage,stage_clock)
 phone.rotation.z=-.035+(sin(clock*1.3)*.005 if guard.motion else 0.0)
 phone.rotation.x=-.10+(sin(clock*.83)*.005 if guard.motion else 0.0)
 if guard.motion: guard.camera.position.y=1.65+sin(clock*18)*.0015
 skip_hold=minf(1.35,skip_hold+delta) if Input.is_action_pressed("jump") else 0.0;skip_bar.value=skip_hold
 if skip_hold>=1.35: skip();return
 phone.position.y=lerpf(-.49,-.105,smoothstep(.5,1.3,clock)) if stage in ["ringing","call"] else lerpf(phone.position.y,-.55,delta*4)
 if stage=="ringing":
  status.text="03:17 · EINGEHENDER ANRUF";accept_button.visible=clock>1.1
  if not ring.playing and fmod(clock,3.3)<.06: ring.play()
 elif stage=="call":
  status.text="CHEF · %02d:%02d"%[int(stage_clock)/60,int(stage_clock)%60]
  caption.text="" # Timed speech is displayed by AfterPlayCaptions, including the fallback call.
  status.text=AfterPlayLanguage.t(status.text)
  if stage_clock>=call_length or (recording and stage_clock>.3 and not voice.playing):
   stage="arrival";stage_clock=0;voice.stop();phone_status.text="Anruf\nbeendet";caption.text="";status.text=AfterPlayLanguage.t("KINDERPARADIES · ETAGE %s"%floor_text(floor_number));motor.stop();chime.play()
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
 return {"stage":stage,"clock":clock,"call_clock":stage_clock,"skip":skip_hold,"paused":paused,"recording":recording,"duration":call_length,"starts":starts,"voice_playing":voice.playing,"voice_paused":voice.stream_paused,"caption":caption.text,"floor":floor_number,"floor_texts":floor_displays.map(func(indicator):return indicator.text),"phone_visible":phone.visible,"screen_state":display.state_label.tr(display.state_label.text)}
