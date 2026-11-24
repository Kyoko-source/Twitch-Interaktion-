class_name RoomMood
extends Node3D

# 5.3.0: every room gets its own light mood instead of one olive murk, and the
# light moves. Accent lights per room (colour, motion), a tinted haze volume
# per room on Forward+, the hall pendants swing on their cords, and when a car
# passes outside (AmbientLife) its headlights sweep through the window.
# Same in every round and on its own random stream: never a clue. Deliberately
# no red accents (anomaly "lights_red") and the party accents go dark with the
# party lights (anomaly "party_dark"). Street and moon light are "outdoor": the
# blackout leaves them on, so the dark venue still has a shape.
# 5.6.1: "ceiling" is the measured underside of the real ceiling above a
# batten (the room table in SecretPlushEnding is only a rough height and left
# the tubes hanging up to a metre below the ceiling or inside a wall).
const LIGHTS:=[
 # Empfang: warm amber neon over the counter, pink sign glow.
 {"room":"Empfang","pos":Vector3(-9.5,2.72,6.4),"color":"ffad4a","energy":1.5,"range":6.5,"motion":"neon","wall":Vector3(-9.95,2.72,6.4)},
 {"room":"Empfang","pos":Vector3(-4.2,2.0,14.5),"color":"ff5fb0","energy":.75,"range":5.0,"motion":"breathe"},
 # Halle: cold blue night light against the warm pendants and the sodium window.
 {"room":"Halle","pos":Vector3(-9.2,3.2,-6.0),"color":"6f93ff","energy":.9,"range":10.0,"motion":"shimmer"},
 # Bällebad: deep blue fill, coloured reflections low over the pit, arcade glow.
 {"room":"Bällebad","pos":Vector3(9.0,3.4,11.5),"color":"2f58ff","energy":1.6,"range":13.0,"motion":"breathe"},
 {"room":"Bällebad","pos":Vector3(2.4,.9,6.2),"color":"ffd43a","energy":.6,"range":3.6,"motion":"steady"},
 {"room":"Bällebad","pos":Vector3(5.0,.9,8.2),"color":"39ff7a","energy":.5,"range":3.4,"motion":"steady"},
 {"room":"Bällebad","pos":Vector3(7.5,1.6,15.6),"color":"c34bff","energy":1.1,"range":5.5,"motion":"arcade"},
 {"room":"Bällebad","pos":Vector3(15.5,1.6,15.6),"color":"28d8ff","energy":.9,"range":5.0,"motion":"arcade"},
 # Party Raum: gold and magenta, slow breathing like a party that never ended.
 {"room":"Party Raum","pos":Vector3(13.0,2.9,-8.0),"color":"ffb43a","energy":1.3,"range":10.0,"motion":"breathe","party":true},
 {"room":"Party Raum","pos":Vector3(17.6,1.4,-15.5),"color":"e04bff","energy":.9,"range":6.5,"motion":"breathe","party":true},
 {"room":"Party Raum","pos":Vector3(8.0,1.4,-1.0),"color":"ff8a2a","energy":.6,"range":5.0,"motion":"steady","party":true},
 # Wartung: sick green tube that never quite catches.
 {"room":"Wartung","pos":Vector3(-14.9,2.25,-6.0),"color":"7dffb0","energy":1.1,"range":6.5,"motion":"tube","ceiling":3.08},
 # Personalflur: green exit sign at the far end, cold tube halfway.
 {"room":"Personalflur","pos":Vector3(-7.35,2.25,-35.0),"color":"2bff6a","energy":.9,"range":4.5,"motion":"steady","sign":true},
 {"room":"Personalflur","pos":Vector3(-7.35,2.3,-19.5),"color":"cfe6ff","energy":.7,"range":5.5,"motion":"tube","ceiling":3.49,"along_z":true},
 # Küche: warm pilot glow and an old yellow strip (cold light is the anomaly "cold_breath").
 {"room":"Küche","pos":Vector3(-15.8,1.1,-33.6),"color":"ff8a2a","energy":.55,"range":3.0,"motion":"breathe","kitchen":true},
 {"room":"Küche","pos":Vector3(-11.0,2.3,-26.0),"color":"ffd27a","energy":.8,"range":6.0,"motion":"tube","kitchen":true,"ceiling":3.49},
 # Kino: the blank screen still throws blue, flickering light into the seats.
 {"room":"Kino","pos":Vector3(2.4,2.0,-29.6),"color":"7fa8ff","energy":1.5,"range":9.0,"motion":"screen"},
 # Kinder-WC: cyan tile glow.
 {"room":"Kinder-WC","pos":Vector3(22.4,2.1,7.5),"color":"5fe0d0","energy":.8,"range":5.5,"motion":"tube","ceiling":3.2},
 # Eingang: orange sodium street light through the old door.
 {"room":"Eingang","pos":Vector3(-15.4,2.3,9.4),"color":"ff9a3c","energy":.9,"range":6.0,"motion":"shimmer","outdoor":true}]
# Tinted haze per room (Forward+): the colour the air picks up from the light.
const HAZE:={"Empfang":"ffc890","Halle":"a8bcff","Bällebad":"7f9cff","Party Raum":"ffc0e0","Wartung":"a8ffc8","Personalflur":"d8e8ff","Küche":"ffe6b0","Kino":"9fb8ff","Kinder-WC":"a8fff0","Eingang":"ffb880"}
# A car crossing the parking lot behind the hall window and the old entrance:
# where it drives (start, end) and where its lights fall inside. The walls
# cast the beam's shadow, so only what comes through the glass reaches in.
const WINDOWS:=[[Vector3(-26.,.9,-8.),Vector3(-24.,.9,11.),Vector3(-2.,1.6,1.7)],[Vector3(-30.,.9,2.),Vector3(-28.,.9,17.),Vector3(-11.,.6,9.4)]]
const SODIUM:="ffa552"
var w: PlayWorld
var advanced:=false
var rng:=RandomNumberGenerator.new()
var accents: Array[Dictionary]=[]
var hazes: Array[FogVolume]=[]
var swings: Array[Dictionary]=[]
var beams: Array[SpotLight3D]=[]
var sweep:=-1.
var sweep_window:=0
var sweeps:=0
var clock:=0.
var anomaly:="none"

func build(world: PlayWorld) -> void:
 w=world;name="RoomMood";rng.randomize()
 advanced=not OS.has_feature("web") and RenderingServer.get_current_rendering_method()=="forward_plus"
 # Web (Compatibility: eight lights per object) keeps its look, like LookPass.
 if OS.has_feature("web"):return
 for spec in LIGHTS:
  var light:=OmniLight3D.new();light.name="Mood_"+str(spec.room).replace(" ","")
  light.position=spec.pos;light.light_color=Color(spec.color);light.light_energy=spec.energy;light.omni_range=spec.range;light.omni_attenuation=1.4
  # No glow in the haze: a light without a lamp must not hang in the air as
  # a bright orb (5.3.1). Lights that can be seen get a real fixture below.
  light.shadow_enabled=false;light.light_specular=.6;light.light_volumetric_fog_energy=0.
  if spec.get("outdoor",false):light.set_meta("outdoor",true)
  add_child(light)
  if spec.get("sign",false):_sign(spec.pos,Color(spec.color))
  var tube: StandardMaterial3D=_batten(light,spec) if spec.motion in ["tube","neon"] else null
  accents.append({"light":light,"spec":spec,"base":float(spec.energy),"color":Color(spec.color),"phase":rng.randf()*TAU,"event":-1.,"wait":rng.randf_range(2,9),"on":true,"tube":tube})
 if advanced:
  for room in SecretPlushEnding.ROOMS:
   if not HAZE.has(room[0]):continue
   var volume:=FogVolume.new();volume.name="Haze_"+str(room[0]).replace(" ","")
   var x0: float=room[1];var x1: float=room[2];var z0: float=room[3];var z1: float=room[4];var h: float=room[5]
   volume.position=Vector3((x0+x1)*.5,h*.5,(z0+z1)*.5);volume.size=Vector3(x1-x0,h,z1-z0);volume.shape=RenderingServer.FOG_VOLUME_SHAPE_BOX
   var fog:=FogMaterial.new();fog.density=.018;fog.albedo=Color(HAZE[room[0]]);fog.edge_fade=.25;volume.material=fog
   add_child(volume);hazes.append(volume)
 _swinging_pendants()
 _sodium_lot()
 for i in range(WINDOWS.size()):
  var beam:=SpotLight3D.new();beam.name="Headlights%d"%i;beam.light_color=Color("fff0cc");beam.light_energy=0.;beam.spot_range=34.;beam.spot_angle=11.;beam.spot_angle_attenuation=.8
  beam.shadow_enabled=true;beam.light_volumetric_fog_energy=2.5 if advanced else 0.;beam.set_meta("outdoor",true);beam.position=WINDOWS[i][0];beam.light_size=.12;add_child(beam);beam.hide();beams.append(beam)

# An emissive green exit sign where the exit light hangs.
func _sign(p: Vector3,color: Color) -> void:
 var glow:=StandardMaterial3D.new();glow.albedo_color=color;glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=3.
 var sign_mesh:=w.box(self,p+Vector3(0,.15,.18),Vector3(.42,.17,.04),glow);sign_mesh.name="ExitSign";sign_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# The parking lot lamps outside burn orange sodium: warm outside, cold inside.
func _sodium_lot() -> void:
 var lot: HappylandExterior=w.graphics.exterior if w.graphics else null
 if not lot:return
 for lamp in lot.lamps:lamp.light_color=Color(SODIUM);lamp.light_energy*=1.15
 if lot.window_light:lot.window_light.light_color=Color("ffb070")

# A ceiling batten for every stuttering tube and neon light: the light comes
# from a lamp, and the lamp's tube flickers with it (and dies in the blackout,
# which dims every emissive material).
func _batten(light: OmniLight3D,spec: Dictionary) -> StandardMaterial3D:
 var height:=2.5
 for room in SecretPlushEnding.ROOMS:
  if room[0]==spec.room:height=room[5]
 height=float(spec.get("ceiling",height))
 var root:=Node3D.new();root.name="MoodBatten_"+str(spec.room).replace(" ","");add_child(root)
 if spec.has("wall"):
  # On the wall: the batten turned along it, its back against the plaster.
  # Tube along the wall (+Z), the lamp facing into the room (+X).
  root.position=spec.wall;root.basis=Basis(Vector3(0,0,1),Vector3(-1,0,0),Vector3(0,-1,0))
 else:
  light.position.y=height-.22;root.position=Vector3(spec.pos.x,height,spec.pos.z)
  if spec.get("along_z",false):root.rotation.y=PI/2
 var housing:=w.box(root,Vector3(0,-.035,0),Vector3(1.22,.07,.16),w.materials.metal);housing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var glow:=StandardMaterial3D.new();var color:=Color(spec.color);glow.albedo_color=color.lerp(Color.WHITE,.55);glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=2.2
 var lamp:=w.tube(root,Vector3(-.56,-.085,0),Vector3(.56,-.085,0),.022,glow);lamp.name="MoodTube";lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in [-.58,.58]:w.box(root,Vector3(x,-.08,0),Vector3(.03,.05,.06),w.materials.dark).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return glow

# LookPass pendants hang from a pivot at the top of their cord and swing.
func _swinging_pendants() -> void:
 if not w.look:return
 for light in w.look.pendants:
  var root: Node3D=light.get_parent();var parent:=root.get_parent()
  var pivot:=Node3D.new();pivot.name="PendantPivot";pivot.position=root.position+Vector3(0,1.6,0);parent.add_child(pivot)
  parent.remove_child(root);pivot.add_child(root);root.position=Vector3(0,-1.6,0)
  swings.append({"pivot":pivot,"phase":rng.randf()*TAU,"speed":rng.randf_range(1.55,1.85),"amount":deg_to_rad(rng.randf_range(2.2,4.)),"yaw":rng.randf()*TAU})

func configure(id: String) -> void:
 anomaly=id
 for accent in accents:
  var spec: Dictionary=accent.spec
  accent.on=not ((spec.get("party",false) and id=="party_dark") or (spec.get("kitchen",false) and id=="cold_breath"))
  # Red ceiling lights: every indoor accent burns red with them.
  accent.light.light_color=Color("e22c28") if id=="lights_red" and not spec.get("outdoor",false) and not spec.get("sign",false) else accent.color
  if accent.tube:accent.tube.emission=accent.light.light_color

# Called by AmbientLife when a car passes outside: headlights sweep the room.
func headlights(near: Vector3) -> void:
 if beams.is_empty():return
 var best:=0
 for i in range(WINDOWS.size()):
  if WINDOWS[i][0].distance_to(near)<WINDOWS[best][0].distance_to(near):best=i
 sweep_window=best;sweep=0.;sweeps+=1;beams[best].show()

func _level(accent: Dictionary,delta: float) -> float:
 var t:=clock+float(accent.phase)
 match str(accent.spec.motion):
  "breathe":return 1.+.22*sin(t*.55)+.06*sin(t*1.7)
  "shimmer":return 1.+.12*sin(t*2.3)*sin(t*.37)+.05*sin(t*7.1)
  "arcade":return .85+.15*sin(t*3.)+(.25 if fmod(t,2.2)<.09 else 0.)
  "screen":return .55+.25*sin(t*13.)*sin(t*2.1)+.2*sin(t*31.)*sin(t*.7)+(.5 if fmod(t,4.7)<.12 else 0.)
  "neon","tube":
   # Steady with a hum, then now and then a burst of stutter or a dropout.
   accent.wait-=delta
   if accent.wait<=0 and accent.event<0:accent.event=0.
   if accent.event>=0:
    accent.event+=delta
    var e: float=accent.event;var length:=.9 if accent.spec.motion=="tube" else .45
    if e>length:accent.event=-1.;accent.wait=rng.randf_range(4,14) if accent.spec.motion=="tube" else rng.randf_range(6,18);return 1.
    return .08 if fmod(e,.16)<.07+.05*sin(e*31.) else .9
   return 1.+.03*sin(t*50.)
 return 1.

func tick(delta: float,active: bool) -> void:
 if not active:return
 clock+=delta
 for accent in accents:
  var level:=_level(accent,delta) if accent.on else 0.
  accent.light.light_energy=float(accent.base)*level
  if accent.tube:accent.tube.emission_energy_multiplier=2.2*level
 for swing in swings:
  var a: float=sin(clock*float(swing.speed)+float(swing.phase))*float(swing.amount)
  swing.pivot.rotation=Vector3(a*cos(swing.yaw),0,a*sin(swing.yaw))
 if sweep>=0:
  sweep+=delta
  var beam:=beams[sweep_window];var spec: Array=WINDOWS[sweep_window]
  var t:=sweep/4.5
  # The car rolls across the lot; its lights swing over the inside wall.
  var from: Vector3=(spec[0] as Vector3).lerp(spec[1],clampf(t,0,1))
  var aim: Vector3=spec[2]+Vector3(0,0,lerpf(6.,-6.,clampf(t,0,1)))
  beam.look_at_from_position(from,aim,Vector3.UP)
  beam.light_energy=26.*smoothstep(0.,.2,t)*smoothstep(1.,.8,t)
  if t>=1.:sweep=-1.;beam.light_energy=0.;beam.hide()

func snapshot() -> Dictionary:
 return {"accents":accents.size(),"lit":accents.filter(func(a):return a.on).size(),"hazes":hazes.size(),"swings":swings.size(),"sweeps":sweeps,"sweeping":sweep>=0,"anomaly":anomaly}
