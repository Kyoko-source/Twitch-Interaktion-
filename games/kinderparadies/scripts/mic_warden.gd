class_name MicWarden
extends CanvasLayer

# 5.4.0: microphone mode. Something sleeps in the building, and it is not an
# anomaly: it never decides a door and never has to be reported. It only wakes
# when the guard is too loud for too long.
#  1st time: every lamp flickers at once, "DU BIST ZU LAUT. WECK ES NICHT AUF."
#  2nd time: a scream through the building, harder flicker, "PROVOZIER ES NICHT."
#  3rd time: the flicker goes wild, the scream comes closer, then everything
#   falls silent. The guard is frozen, something whispers right behind them,
#   their head turns round on its own, slowly. Nothing is there. Two seconds of
#   nothing. Then its face fills the screen, and the night is lost.
# Three calm minutes take one step back. A scream during another scare counts.
# The level is always on screen while the mode is on, and the red zone grows
# every round: it gets more sensitive the longer the shift goes.
signal awakened
signal finished

const HOLD:=.5
const PER_ROUND:=1.1
const ROUND_CAP:=13
const HUD_W:=240.
const COOLDOWN:=10.
const FORGET:=180.
const TURN:=3.4
const STILL:=2.
const WHISPER_FILES:=["res://assets/mic-v540/whisper.ogg","res://assets/mic-v540/whisper.wav","res://assets/mic-v540/whisper.mp3"]
const TEXTS:=["","DU BIST ZU LAUT.\nWECK ES NICHT AUF.","PROVOZIER ES NICHT."]
const NOTE:="Mikrofon-Modus · Das ist keine Anomalie."

var g: Node
var strikes:=0
var loud:=0.
var cooldown:=0.
var calm:=0.
var pending:=false
var stage:="idle"
var clock:=0.
var whisper_length:=2.6
var yaw_from:=0.
var pitch_from:=0.
var flicker_left:=0.
var flicker_power:=0.
var flicker_wait:=0.
var lights: Array[Light3D]=[]
var light_state: Array[bool]=[]
var text_left:=0.
var silenced: Array[Node]=[]
var title: Label
var note: Label
var scream: AudioStreamPlayer
var roar: AudioStreamPlayer
var whisper: AudioStreamPlayer3D
var rng:=RandomNumberGenerator.new()
var count:=0
var hud: Control
var hud_red: ColorRect
var hud_fill: ColorRect
var hud_mark: ColorRect
var hud_label: Label
var hud_dots: Array[ColorRect]=[]

func build(game: Node) -> void:
 g=game;name="MicWarden";layer=108;rng.randomize()
 var box:=Control.new();box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(box)
 title=Label.new();title.name="MicWarning";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 title.set_anchors_and_offsets_preset(Control.PRESET_CENTER);title.offset_left=-900;title.offset_right=900;title.offset_top=-170;title.offset_bottom=110
 if g.title_font:title.add_theme_font_override("font",g.title_font)
 title.add_theme_font_size_override("font_size",84);title.add_theme_color_override("font_color",Color("e0141b"))
 title.add_theme_color_override("font_outline_color",Color(0,0,0,.95));title.add_theme_constant_override("outline_size",14)
 title.add_theme_color_override("font_shadow_color",Color(.35,0,0,.8));title.add_theme_constant_override("shadow_offset_x",0);title.add_theme_constant_override("shadow_offset_y",6)
 box.add_child(title)
 note=Label.new();note.name="MicNote";note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 note.set_anchors_and_offsets_preset(Control.PRESET_CENTER);note.offset_left=-600;note.offset_right=600;note.offset_top=118;note.offset_bottom=150
 note.add_theme_font_size_override("font_size",20);note.add_theme_color_override("font_color",Color(.86,.8,.74,.85))
 note.add_theme_color_override("font_outline_color",Color(0,0,0,.9));note.add_theme_constant_override("outline_size",6);box.add_child(note)
 title.hide();note.hide()
 _build_hud(box)
 scream=AudioStreamPlayer.new();scream.name="MicScream";add_child(scream);ScareBank.loud(scream)
 roar=AudioStreamPlayer.new();roar.name="MicRoar";add_child(roar);ScareBank.loud(roar)

func base_threshold() -> float:
 return lerpf(-8.,-44.,clampf(float(g.settings.get("mic_sensitivity",.5)),0.,1.))

# Every round it sleeps lighter.
func threshold() -> float:
 var round:=1
 if g.state and g.has_session:round=int(g.state.round_number())
 return base_threshold()-PER_ROUND*clampi(round-1,0,ROUND_CAP)

# Always-on meter, bottom left: the red zone starts at the threshold.
func _build_hud(box: Control) -> void:
 hud=Control.new();hud.name="MicHud";hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);hud.offset_left=32;hud.offset_top=-74;hud.offset_right=32+HUD_W+90;hud.offset_bottom=-30;box.add_child(hud)
 hud_label=Label.new();hud_label.add_theme_font_size_override("font_size",14);hud_label.add_theme_color_override("font_color",Color(.9,.86,.78,.8))
 hud_label.add_theme_color_override("font_outline_color",Color(0,0,0,.8));hud_label.add_theme_constant_override("outline_size",4);hud.add_child(hud_label)
 var back:=ColorRect.new();back.color=Color(0,0,0,.55);back.position=Vector2(0,22);back.size=Vector2(HUD_W,12);back.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(back)
 hud_red=ColorRect.new();hud_red.color=Color(.55,.03,.05,.75);hud_red.position=Vector2(0,22);hud_red.size=Vector2(0,12);hud_red.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(hud_red)
 hud_fill=ColorRect.new();hud_fill.color=Color("8fb38a");hud_fill.position=Vector2(0,24);hud_fill.size=Vector2(0,8);hud_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(hud_fill)
 hud_mark=ColorRect.new();hud_mark.color=Color("ff2a2a");hud_mark.position=Vector2(0,19);hud_mark.size=Vector2(2,18);hud_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(hud_mark)
 for i in range(3):
  var dot:=ColorRect.new();dot.size=Vector2(12,12);dot.position=Vector2(HUD_W+12+i*17,22);dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(dot);hud_dots.append(dot)
 hud.hide()

func _hud_x(db: float) -> float:
 return clampf((db+60.)/60.,0.,1.)*HUD_W

func _hud(show: bool) -> void:
 hud.visible=show
 if not show:return
 var level: float=g.mic.level_db if g.mic else -80.
 var limit:=threshold()
 var x:=_hud_x(limit)
 hud_mark.position.x=x-1.;hud_red.position.x=x;hud_red.size.x=HUD_W-x
 hud_fill.size.x=_hud_x(level)
 var over:=level>limit
 hud_fill.color=Color("ff2a2a") if over else Color("8fb38a").lerp(Color("e8c15a"),clampf((level-(limit-12.))/12.,0.,1.))
 hud_label.text=AfterPlayLanguage.t("MIKROFON")+("   "+AfterPlayLanguage.t("ZU LAUT") if over else "")
 hud_label.add_theme_color_override("font_color",Color("ff3b3b") if over else Color(.9,.86,.78,.8))
 for i in range(3):hud_dots[i].color=Color("d81e24") if i<strikes else Color(1,1,1,.18)

func listening() -> bool:
 return bool(g.settings.get("mic",false)) and g.mic and g.mic.enabled

func running() -> bool:
 return stage!="idle"

func _busy() -> bool:
 var w=g.world
 if not is_instance_valid(w):return true
 if g.jumpscare and g.jumpscare.running():return true
 if w.tubes.contains(g.player.position):return true
 if w.horse_hunt.phase!="idle" or w.blackout.phase not in ["idle","waiting"]:return true
 if w.encounters.triggered and not w.encounters.finished:return true
 return false

func tick(delta: float,active: bool) -> void:
 _hud(stage=="idle" and active and listening())
 if stage!="idle":
  _final(delta);_flicker(delta);_text(delta);return
 if active or flicker_left>0.:_flicker(delta)
 _text(delta)
 if not active or not listening():
  loud=0.;return
 cooldown=maxf(0.,cooldown-delta);calm+=delta
 if strikes>0 and calm>=FORGET and not pending:strikes-=1;calm=0.
 if pending:
  if not _busy():pending=false;_begin_final()
  return
 if cooldown>0.:loud=0.;return
 if g.mic.level_db>threshold():loud+=delta
 else:loud=maxf(0.,loud-delta*2.)
 if loud>=HOLD:strike()

func strike() -> void:
 strikes=mini(strikes+1,3);loud=0.;cooldown=COOLDOWN;calm=0.;count+=1
 match strikes:
  1:
   flicker(1.7,.55);show_text(1)
  2:
   flicker(2.3,.8);show_text(2)
   scream.stream=load(ScareBank.track("crowd",rng.randi_range(1,4)));scream.pitch_scale=.86;scream.volume_db=-7.;scream.play()
  3:
   if _busy():pending=true
   else:_begin_final()

func show_text(level: int) -> void:
 title.text=AfterPlayLanguage.t(TEXTS[level]);note.text=AfterPlayLanguage.t(NOTE)
 text_left=3.4;title.show();note.show();title.modulate.a=1.;note.modulate.a=1.

func _text(delta: float) -> void:
 if text_left<=0.:return
 text_left-=delta
 var strobe:=bool(g.settings.get("strobe",true))
 var a:=clampf(text_left/.6,0.,1.)
 # It stutters in like a dying sign, then holds.
 if strobe and text_left>2.9:a*=(1. if rng.randf()>.35 else .15)
 title.modulate.a=a;note.modulate.a=a*.9
 if text_left<=0.:title.hide();note.hide()

# ---- Lamps ---------------------------------------------------------------
func flicker(seconds: float,power: float) -> void:
 if flicker_left<=0.:
  lights.clear();light_state.clear()
  var w=g.world
  if not is_instance_valid(w) or w.blackout.dark():return
  for light: Light3D in w.find_children("*","Light3D",true,false):
   if light.has_meta("outdoor") or not light.is_visible_in_tree():continue
   lights.append(light);light_state.append(light.visible)
 flicker_left=maxf(flicker_left,seconds);flicker_power=maxf(flicker_power,power);flicker_wait=0.

func _flicker(delta: float) -> void:
 if flicker_left<=0.:return
 flicker_left-=delta;flicker_wait-=delta
 if flicker_left<=0.:
  _restore_lights();return
 if flicker_wait>0.:return
 var strobe:=bool(g.settings.get("strobe",true))
 flicker_wait=rng.randf_range(.04,.11)/(1.+flicker_power) if strobe else rng.randf_range(.28,.45)
 # All at once: the whole building blinks together, with a few stragglers.
 var off:=rng.randf()<.35+flicker_power*.35
 for i in range(lights.size()):
  if is_instance_valid(lights[i]):lights[i].visible=light_state[i] and (not off if rng.randf()>.12*flicker_power else off)

func _restore_lights() -> void:
 flicker_left=0.;flicker_power=0.
 for i in range(lights.size()):
  if is_instance_valid(lights[i]):lights[i].visible=light_state[i]
 lights.clear();light_state.clear()

# ---- The third time ------------------------------------------------------
func _begin_final() -> void:
 stage="rage";clock=0.;count+=1
 awakened.emit()
 flicker(2.,1.)
 scream.stream=load(ScareBank.track("charge",rng.randi_range(1,4)));scream.pitch_scale=.78;scream.volume_db=0.;scream.play()
 roar.stream=load(ScareBank.track("clown",rng.randi_range(1,4)));roar.pitch_scale=.62;roar.volume_db=-3.;roar.play()

func _final(delta: float) -> void:
 clock+=delta
 var p: NightGuard=g.player
 match stage:
  "rage":
   if clock>=2.:
    _restore_lights();_silence();stage="silence";clock=0.
  "silence":
   if clock>=.9:
    _whisper(p);stage="whisper";clock=0.
  "whisper":
   if clock>=whisper_length+.35:
    yaw_from=p.rotation.y;pitch_from=p.camera.rotation.x;stage="turn";clock=0.
  "turn":
   var k:=smoothstep(0.,TURN,clock)
   p.rotation.y=yaw_from+PI*k;p.camera.rotation.x=lerpf(pitch_from,-.04,k)
   if clock>=TURN:stage="still";clock=0.
  "still":
   if clock>=STILL:_scare(p);stage="scare";clock=0.
  "scare":
   if clock>=2.7:stage="done";clock=0.;finished.emit()

func _silence() -> void:
 scream.stop();roar.stop()
 for source in g.find_children("*","AudioStreamPlayer",true,false)+g.find_children("*","AudioStreamPlayer3D",true,false):
  if source==whisper or is_ancestor_of(source) or source==g.jumpscare.boom or source==g.jumpscare.hiss:continue
  if source.playing and not source.stream_paused:source.stream_paused=true;silenced.append(source)

func _whisper(p: NightGuard) -> void:
 if not whisper:
  whisper=AudioStreamPlayer3D.new();whisper.name="MicWhisper";whisper.unit_size=1.2;whisper.max_distance=6.;whisper.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
 if whisper.get_parent()!=p.camera:
  if whisper.get_parent():whisper.get_parent().remove_child(whisper)
  p.camera.add_child(whisper)
 ScareBank.loud(whisper)
 # Right behind the left ear.
 whisper.position=Vector3(-.12,-.04,.42);whisper.stream=whisper_stream();whisper.volume_db=4.;whisper.play()
 whisper_length=clampf(whisper.stream.get_length(),1.,6.) if whisper.stream.get_length()>0. else 2.6

static func whisper_stream() -> AudioStream:
 for path in WHISPER_FILES:
  if ResourceLoader.exists(path):return load(path)
 return _placeholder_whisper()

# Until the real voice line arrives: breathy, band-limited noise shaped into
# a run of hissed syllables.
static func _placeholder_whisper() -> AudioStreamWAV:
 var rate:=22050;var n:=int(rate*2.6);var data:=PackedByteArray();data.resize(n*2)
 var r:=RandomNumberGenerator.new();r.seed=540
 var syllables: Array[Vector3]=[]
 var at:=.12
 while at<2.4:
  var length:=r.randf_range(.14,.3);syllables.append(Vector3(at,length,r.randf()));at+=length+r.randf_range(.04,.13)
 var low:=0.;var high:=0.;var formant:=0.
 for i in range(n):
  var t:=float(i)/rate;var white:=r.randf_range(-1.,1.)
  low+=(white-low)*.55;high+=(low-high)*.12
  var band:=low-high
  var env:=0.;var hiss:=0.
  for s in syllables:
   if t>=s.x and t<s.x+s.y:
    var k:=(t-s.x)/s.y;env=sin(PI*k);hiss=1. if s.z>.72 else 0.
  formant=.5+.5*sin(t*TAU*(5.+2.*sin(t*3.)))
  var v:=(band*(.55+.45*formant)*(1.-hiss)+white*.35*hiss)*env*.9
  data.encode_s16(i*2,int(clampf(v,-1.,1.)*32000))
 var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=rate;w.data=data;return w

func _scare(_p: NightGuard) -> void:
 JumpscareFX.fire_godless()
 scream.stream=load(ScareBank.track("clown",rng.randi_range(1,4)));scream.pitch_scale=.7;scream.volume_db=1.;scream.play()
 roar.stream=load(ScareBank.track("charge",rng.randi_range(1,4)));roar.pitch_scale=.55;roar.volume_db=0.;roar.play()

func reset() -> void:
 strikes=0;loud=0.;cooldown=0.;calm=0.;pending=false;stage="idle";clock=0.
 _restore_lights();text_left=0.;title.hide();note.hide();scream.stop();roar.stop()
 if whisper:whisper.stop()
 for source in silenced:
  if is_instance_valid(source):source.stream_paused=false
 silenced.clear()

func snapshot() -> Dictionary:
 return {"hud":hud.visible,"strikes":strikes,"stage":stage,"pending":pending,"loud":loud,"cooldown":cooldown,"count":count,"listening":listening(),"threshold":threshold(),"level":g.mic.level_db if g.mic else -80.,"text":title.text if title.visible else ""}
