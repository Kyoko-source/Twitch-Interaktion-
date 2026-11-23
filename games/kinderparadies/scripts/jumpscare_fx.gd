class_name JumpscareFX
extends CanvasLayer

# 5.3.1: when a visitor or the crawler reaches you, the screen belongs to it
# for a second: a hard punch-in with barrel distortion, radial smear, RGB
# split, a blood-red grade, blood splatter closing in from the edges with drips
# running down, broken-signal glitch bands, noise, a white flash, a violent
# camera shake and a low boom with a burst of static under the scream.
# "strobe" off: no flash and no flickering bands. "motion" off: no shake.
const CODE:="""
shader_type canvas_item;
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
uniform float amount=0.0;
uniform float flash=0.0;
uniform float glitch=0.0;
uniform float blood=0.0;
uniform float drip=0.0;
uniform float seed=0.0;
// 5.4.0: a full-screen face for the microphone scare, shaken and punched in.
uniform sampler2D face_tex:filter_linear,repeat_disable;
uniform float face=0.0;
uniform float smear=1.0;
uniform float grade=0.62;
uniform float face_zoom=1.0;
uniform vec2 face_shift=vec2(0.0);
uniform float face_tilt=0.0;
uniform float screen_aspect=1.7778;
uniform float face_aspect=1.7768;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<5;i++){v+=a*noise(p);p*=2.03;a*=0.5;}return v;}
vec3 src(vec2 uv){
 vec3 c=texture(screen_texture,uv).rgb;
 if(face<=0.001)return c;
 vec2 f=uv-0.5;
 if(screen_aspect>face_aspect)f.y*=face_aspect/screen_aspect;else f.x*=screen_aspect/face_aspect;
 float cs=cos(face_tilt),sn=sin(face_tilt);f=vec2(f.x*cs-f.y*sn,f.x*sn+f.y*cs);
 f=f/face_zoom+0.5+face_shift;
 vec3 img=texture(face_tex,clamp(f,0.0,1.0)).rgb;
 return mix(c,img,face);
}
void fragment(){
 vec2 uv=SCREEN_UV;vec2 p=uv-0.5;float r2=dot(p,p);
 // Punch-in with barrel distortion: the face swells towards you.
 vec2 q=0.5+p*(1.0-amount*0.10)*(1.0+amount*0.22*r2);
 // Broken-signal bands tear the picture sideways.
 float band=floor(q.y*38.0+seed*7.0);
 float tear=step(0.86,hash(vec2(band,floor(seed*24.0))))*(hash(vec2(band,seed))-0.5)*0.09*glitch;
 q.x+=tear;
 // Radial smear and a hard RGB split, strongest at the edges.
 vec2 dir=(q-0.5);vec3 c=vec3(0.0);
 for(int i=0;i<8;i++){
  float k=float(i)/7.0*0.045*amount*smear;vec2 s=q-dir*k;
  vec2 split=dir*0.035*amount*(0.4+r2*3.0)*(0.35+0.65*smear);
  c+=vec3(src(s+split).r,src(s).g,src(s-split).b);
 }
 c/=8.0;
 // Blood-red grade: keep the light, push it into red, crush the blue.
 float l=dot(c,vec3(0.2126,0.7152,0.0722));
 vec3 red=vec3(l*1.55+c.r*0.5,l*0.32+c.g*0.12,l*0.28+c.b*0.08);
 c=mix(c,red,grade*min(amount,1.0));
 c*=1.0+0.35*amount;
 // Blood splatter closing in from the edges, wet with a dark core.
 float edge=sqrt(r2)*1.45+(fbm(uv*vec2(7.0,5.0)+seed*0.0)-0.5)*0.55;
 float splat=smoothstep(0.62,0.80,edge+blood*0.22-0.18)*blood;
 float spots=smoothstep(0.78,0.86,fbm(uv*16.0+3.1))*smoothstep(0.25,0.55,sqrt(r2))*blood;
 // Drips running down from the top edge.
 float col=floor(uv.x*70.0);float len=hash(vec2(col,3.7));float wide=hash(vec2(col,8.1));
 float run=step(0.62,wide)*step(uv.y,(0.06+len*0.42)*drip)*smoothstep(0.5,0.0,abs(fract(uv.x*70.0)-0.5)*2.0-wide*0.3);
 float b=clamp(max(max(splat,spots),run*blood),0.0,1.0);
 vec3 gore=mix(vec3(0.20,0.005,0.01),vec3(0.42,0.02,0.03),fbm(uv*30.0));
 gore+=vec3(0.35,0.12,0.12)*smoothstep(0.7,0.95,fbm(uv*44.0+1.7))*0.6;
 c=mix(c,gore,b*0.92);
 // Deep vignette, scanlines and noise like a dying camera.
 c*=max(0.0,1.0-smoothstep(0.2,0.85,sqrt(r2)*1.2)*0.75*min(amount,1.0)*(1.0-0.45*face));
 c*=1.0-0.10*amount*step(0.5,fract(FRAGCOORD.y*0.5));
 c+=(hash(FRAGCOORD.xy+seed*917.0)-0.5)*0.16*amount;
 // Thin white signal lines.
 float line=step(0.985,hash(vec2(floor(uv.y*240.0),floor(seed*30.0))))*glitch;
 c=mix(c,vec3(0.9,0.85,0.85),line*0.55*step(0.3,hash(vec2(floor(uv.x*14.0),band))));
 c=mix(c,vec3(1.0,0.92,0.9),flash);
 COLOR=vec4(clamp(c,0.0,1.0),1.0);
}
"""
static var current: JumpscareFX
var rect: ColorRect
var material: ShaderMaterial
var clock:=-1.
var delay:=0.
var strength:=1.
var count:=0
# 5.4.0: the "godless" scare of microphone mode runs longer and harder.
var length:=1.
var godless:=false
const FACE:="res://assets/mic-v540/es-face.jpg"
var face_texture: Texture2D
var camera: Camera3D
var strobe:=true
var motion:=true
var boom: AudioStreamPlayer
var hiss: AudioStreamPlayer
var rng:=RandomNumberGenerator.new()

func _ready() -> void:
 current=self;layer=110;name="JumpscareFX";rng.randomize()
 rect=ColorRect.new();rect.name="JumpscareScreen";rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;rect.set_anchors_preset(Control.PRESET_FULL_RECT)
 var shader:=Shader.new();shader.code=CODE;material=ShaderMaterial.new();material.shader=shader;rect.material=material;add_child(rect);rect.hide()
 boom=_voice("JumpscareBoom",_boom_wav(),-2.);hiss=_voice("JumpscareStatic",_static_wav(),-9.)

func _voice(id: String,stream: AudioStream,db: float) -> AudioStreamPlayer:
 var a:=AudioStreamPlayer.new();a.name=id;a.stream=stream;a.volume_db=db;add_child(a);return a

# A sub-bass hit falling from 90 to 32 Hz with a sharp attack.
static func _boom_wav() -> AudioStreamWAV:
 var rate:=22050;var n:=int(rate*.9);var data:=PackedByteArray();data.resize(n*2)
 var phase:=0.
 for i in range(n):
  var t:=float(i)/rate;var f:=lerpf(90.,32.,minf(t/.5,1.));phase+=TAU*f/rate
  var env:=minf(t/.006,1.)*exp(-t*4.2)
  var v:=clampf((sin(phase)+.35*sin(phase*2.)+.15*sin(phase*3.))*env*.9,-1.,1.)
  data.encode_s16(i*2,int(v*32000))
 var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=rate;w.data=data;return w

# Torn video static: noise gated in stutters.
static func _static_wav() -> AudioStreamWAV:
 var rate:=22050;var n:=int(rate*.85);var data:=PackedByteArray();data.resize(n*2)
 var r:=RandomNumberGenerator.new();r.seed=531;var held:=0.
 for i in range(n):
  var t:=float(i)/rate
  if i%3==0:held=r.randf_range(-1.,1.)
  var gate:=1. if fmod(t*23.,1.)<.7 else .25
  var env:=minf(t/.01,1.)*(1.-smoothstep(.55,.85,t))
  data.encode_s16(i*2,int(held*gate*env*.55*32000))
 var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=rate;w.data=data;return w

static func fire(power: float=1.,wait: float=0.) -> void:
 if current and is_instance_valid(current):current.trigger(power,wait)

# Longer hold, stronger smear and blood, repeated flashes and a second boom.
static func fire_godless(wait: float=0.) -> void:
 if current and is_instance_valid(current):
  current.clock=-1.;current.trigger(1.4,wait);current.length=2.1;current.godless=true

func trigger(power: float=1.,wait: float=0.) -> void:
 # A second hit inside the same scare does not restart it.
 if clock>=0. and clock<.5:return
 strength=clampf(power,0.,1.4);delay=wait;clock=0.;count+=1;length=1.;godless=false

func running() -> bool:
 return clock>=0.

func stop() -> void:
 clock=-1.;rect.hide();length=1.;godless=false;material.set_shader_parameter("face",0.)
 if camera and is_instance_valid(camera):camera.h_offset=0.;camera.v_offset=0.

func tick(delta: float,active: bool,cam: Camera3D,settings: Dictionary) -> void:
 camera=cam;strobe=bool(settings.get("strobe",true));motion=bool(settings.get("motion",true))
 if clock<0.:return
 if not active:return
 if delay>0.:delay-=delta;return
 if clock==0.:
  boom.play();hiss.play();ScareBank.sting()
 clock+=delta
 var t:=clock;var L:=length
 if godless and t>.9 and t-delta<=.9:boom.play()
 # Envelope: slam in within 40 ms, hold, then fall away.
 var amount:=minf(t/.04,1.)*(1.-smoothstep(.75*L,1.15*L,t))*strength
 var flash:=(1.-smoothstep(0.,.09,t))*.85*minf(strength,1.) if strobe else 0.
 if godless and strobe:
  for hit in [.45,.9,1.3]:flash=maxf(flash,(1.-smoothstep(0.,.05,absf(t-hit)))*.4)
 var glitch:=amount*(1. if strobe else .25)
 if strobe and t>.2:glitch*=.35+(.65 if rng.randf()>.5 else 0.)
 material.set_shader_parameter("amount",amount)
 material.set_shader_parameter("flash",flash)
 material.set_shader_parameter("glitch",glitch)
 material.set_shader_parameter("blood",minf(t/.12,1.)*(1.-smoothstep(.9*L,1.25*L,t))*minf(strength,1.2))
 material.set_shader_parameter("drip",smoothstep(.05,1.*L,t))
 material.set_shader_parameter("seed",float(int(t*30.))*.37 if strobe else 0.)
 if godless:
  if not face_texture:
   face_texture=load(FACE);material.set_shader_parameter("face_tex",face_texture)
   material.set_shader_parameter("face_aspect",float(face_texture.get_width())/maxf(1.,face_texture.get_height()))
  var view:=get_viewport().get_visible_rect().size
  material.set_shader_parameter("screen_aspect",view.x/maxf(1.,view.y))
  # It rushes in from further back, overshoots into the lens and keeps shaking.
  var rush:=smoothstep(0.,.11,t)
  var zoom:=lerpf(.45,.98,rush)-.1*smoothstep(.11,.3,t)+.025*sin(t*23.)*rush
  var s:=(1. if motion else .25)*rush
  var jerk:=Vector2(rng.randf_range(-1.,1.),rng.randf_range(-1.,1.))*(.018 if strobe else .006)*s
  material.set_shader_parameter("face",clampf(minf(t/.03,1.)*(1.-smoothstep(.9*L,1.15*L,t)),0.,1.))
  material.set_shader_parameter("face_zoom",zoom)
  material.set_shader_parameter("face_shift",Vector2(0.,-.045)+Vector2(sin(t*71.)+.6*sin(t*133.),cos(t*63.)+.5*sin(t*101.))*.014*s+jerk)
  material.set_shader_parameter("face_tilt",(sin(t*37.)*.035+sin(t*89.)*.015)*s)
  # Smeared only while it rushes in (and on each flash hit), then sharp.
  var hit_smear:=0.
  for hit in [.45,.9,1.3]:hit_smear=maxf(hit_smear,1.-smoothstep(0.,.08,absf(t-hit)))
  material.set_shader_parameter("smear",maxf(1.-smoothstep(.08,.22,t),hit_smear*.6)*.9+.08)
  material.set_shader_parameter("grade",.3)
 else:
  material.set_shader_parameter("face",0.);material.set_shader_parameter("smear",1.);material.set_shader_parameter("grade",.62)
 rect.visible=amount>.002 or flash>.002
 if cam and is_instance_valid(cam):
  var shake:=amount*(.055 if motion else 0.)
  cam.h_offset=sin(t*91.)*shake+sin(t*57.)*shake*.6;cam.v_offset=sin(t*77.)*shake*.8+sin(t*43.)*shake*.4
 if t>1.25*L:stop()

func snapshot() -> Dictionary:
 return {"running":running(),"clock":clock,"count":count,"visible":rect.visible,"godless":godless}
