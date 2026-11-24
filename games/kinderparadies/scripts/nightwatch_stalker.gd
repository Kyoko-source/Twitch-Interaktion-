class_name NightwatchStalker
extends RefCounted

# The crawler at the stair door on the left. It does not walk the cameras: it
# is simply there when you look. Drop the rolling shutter in time (20 % of the
# power at once) and it bangs, gives up and goes; the shutter rolls up again
# by itself. Too slow, or not enough power for the shutter: it comes in.
# 5.6.0: how often it comes depends on its level for the night (0-20).

const DOOR_Z:=.55
const DOOR_W:=1.1
const DOOR_H:=2.2
const WALL_X:=-2.65
const SHUTTER_OPEN_Y:=DOOR_H*.5+2.15
const SHUTTER_CLOSED_Y:=DOOR_H*.5

var nw: Nightwatch
var rng:=RandomNumberGenerator.new()
var guest: Node3D
var shutter: Node3D
var lamp_open: StandardMaterial3D
var lamp_closed: StandardMaterial3D
var status_lamp: MeshInstance3D
var corridor_light: OmniLight3D
var face_light: OmniLight3D
var steps: AudioStreamPlayer
var scrape: AudioStreamPlayer
var bang: AudioStreamPlayer
var roll: AudioStreamPlayer

var state:="idle"
var clock:=0.
var next:=0.
var wait:=0.
var closed:=false
var shut_clock:=0.
var shutter_y:=SHUTTER_OPEN_Y
var visits:=0
var repelled:=0

func build(owner: Nightwatch) -> void:
 nw=owner
 var metal:=nw._pbr("rusty_painted_metal",Color(.42,.45,.44),1.2)
 var plate:=nw._pbr("metal_plate",Color(.5,.52,.5),1.6)
 var wall:=nw._pbr("painted_plaster_wall",Color(.4,.44,.41),.55)
 var floor_mat:=nw._pbr("concrete_floor_worn_001",Color(.45,.45,.43),.45)
 var root:=Node3D.new();root.name="StairDoor";nw.room.add_child(root)
 # Door frame, the corridor behind it and a bulb that barely works.
 nw._box(root,Vector3(WALL_X+.02,DOOR_H+.04,DOOR_Z),Vector3(.16,.08,DOOR_W+.16),metal)
 for dz in [-1.,1.]:nw._box(root,Vector3(WALL_X+.02,DOOR_H*.5,DOOR_Z+dz*(DOOR_W*.5+.04)),Vector3(.16,DOOR_H,.08),metal)
 nw._box(root,Vector3(-4.4,-.05,DOOR_Z),Vector3(3.5,.1,DOOR_W+.2),floor_mat)
 nw._box(root,Vector3(-4.4,DOOR_H+.35,DOOR_Z),Vector3(3.5,.1,DOOR_W+.2),wall)
 for dz in [-1.,1.]:nw._box(root,Vector3(-4.4,1.3,DOOR_Z+dz*(DOOR_W*.5+.12)),Vector3(3.5,2.7,.1),wall)
 nw._box(root,Vector3(-6.1,1.3,DOOR_Z),Vector3(.1,2.7,DOOR_W+.2),wall)
 # A few stairs going up at the far end.
 for k in range(5):nw._box(root,Vector3(-5.5-k*.12,.09+k*.18,DOOR_Z),Vector3(.3,.18+k*.36,DOOR_W),floor_mat)
 corridor_light=OmniLight3D.new();corridor_light.name="StairBulb";corridor_light.position=Vector3(-4.3,2.2,DOOR_Z);corridor_light.light_color=Color("ffcf8a");corridor_light.light_energy=.35;corridor_light.omni_range=3.4;corridor_light.light_cull_mask=Nightwatch.ROOM_LAYER;corridor_light.light_volumetric_fog_energy=0.;root.add_child(corridor_light)
 # The rolling shutter: a ribbed steel curtain that drops into the doorway.
 shutter=Node3D.new();shutter.name="RollingShutter";root.add_child(shutter);shutter.position=Vector3(WALL_X+.05,SHUTTER_OPEN_Y,DOOR_Z)
 nw._box(shutter,Vector3.ZERO,Vector3(.04,DOOR_H,DOOR_W),plate)
 for k in range(14):nw._box(shutter,Vector3(.024,-DOOR_H*.5+.08+k*.155,0),Vector3(.012,.03,DOOR_W-.02),metal)
 nw._box(shutter,Vector3(.03,-DOOR_H*.5+.03,0),Vector3(.03,.06,DOOR_W),metal)
 # Control panel beside the door: a big button and a status lamp.
 var panel:=Node3D.new();panel.name="ShutterPanel";root.add_child(panel);panel.position=Vector3(WALL_X+.08,1.25,DOOR_Z-.95)
 nw._box(panel,Vector3.ZERO,Vector3(.05,.36,.24),metal)
 var button_mat:=StandardMaterial3D.new();button_mat.albedo_color=Color("b3161b");button_mat.roughness=.4
 var button:=MeshInstance3D.new();var cyl:=CylinderMesh.new();cyl.top_radius=.05;cyl.bottom_radius=.055;cyl.height=.05;button.mesh=cyl;button.material_override=button_mat;button.rotation.z=PI/2;button.position=Vector3(.045,-.04,0);panel.add_child(button)
 lamp_open=StandardMaterial3D.new();lamp_open.albedo_color=Color("4fd36a");lamp_open.emission_enabled=true;lamp_open.emission=Color("4fd36a");lamp_open.emission_energy_multiplier=2.
 lamp_closed=StandardMaterial3D.new();lamp_closed.albedo_color=Color("ff3b2e");lamp_closed.emission_enabled=true;lamp_closed.emission=Color("ff3b2e");lamp_closed.emission_energy_multiplier=2.5
 status_lamp=MeshInstance3D.new();var bulb:=SphereMesh.new();bulb.radius=.022;bulb.height=.044;status_lamp.mesh=bulb;status_lamp.material_override=lamp_open;status_lamp.position=Vector3(.035,.12,0);panel.add_child(status_lamp)
 var label:=Label3D.new();label.text="ROLLTOR";label.font=load("res://assets/Oswald.ttf");label.font_size=30;label.pixel_size=.0008;label.position=Vector3(.03,.075,0);label.rotation.y=PI/2;label.modulate=Color(.85,.85,.8);label.shaded=true;panel.add_child(label)
 nw._clickable(panel,Vector3(.04,0,0),Vector3(.14,.4,.3),"shutter")
 nw._clickable(shutter,Vector3.ZERO,Vector3(.1,DOOR_H,DOOR_W),"shutter")
 for mesh: GeometryInstance3D in root.find_children("*","GeometryInstance3D",true,false):mesh.layers=Nightwatch.ROOM_LAYER
 for l: Label3D in root.find_children("*","Label3D",true,false):l.layers=Nightwatch.ROOM_LAYER
 # The one at the door, crouched in the corridor light.
 guest=CharacterFinish.crawler(1.05);guest.name="DoorCrawler";root.add_child(guest)
 guest.position=Vector3(-3.35,0,DOOR_Z);guest.rotation.y=PI/2
 for mesh: GeometryInstance3D in guest.find_children("*","GeometryInstance3D",true,false):mesh.layers=Nightwatch.ROOM_LAYER
 face_light=OmniLight3D.new();face_light.name="DoorFaceLight";face_light.light_color=Color("ff6a4a");face_light.light_energy=0.;face_light.omni_range=1.8;face_light.light_cull_mask=Nightwatch.ROOM_LAYER;face_light.light_volumetric_fog_energy=0.;face_light.position=Vector3(-2.8,.9,DOOR_Z);root.add_child(face_light)
 guest.hide()
 steps=nw._player(load("res://assets/ambience/crawl-contact.wav"),-30.)
 scrape=nw._player(load("res://assets/ambience/crawl-contact.wav"),-14.)
 bang=nw._player(load("res://assets/scares-v260/dry-impact.wav"),-2.)
 roll=nw._player(nw._wav(.9,func(t: float):return (.35*signf(sin(TAU*38.*t))+.25*(randf()-.5))*clampf(t/.05,0,1)*clampf((.9-t)/.15,0,1)),-12.)

func start() -> void:
 rng.seed=nw.rng.randi();corridor_light.show()
 state="idle";clock=0.;next=0.;visits=0;repelled=0;closed=false;shut_clock=0.;shutter_y=SHUTTER_OPEN_Y
 shutter.position.y=shutter_y;status_lamp.material_override=lamp_open
 guest.position=Vector3(-3.35,0,DOOR_Z);guest.rotation=Vector3(0,PI/2,0)
 face_light.position=Vector3(-2.8,.9,DOOR_Z);face_light.omni_range=1.8
 guest.hide();face_light.light_energy=0.
 for p in [steps,scrape]:p.stop()

func stop() -> void:
 state="idle"
 if guest:guest.hide()
 if face_light:face_light.light_energy=0.
 for p in [steps,scrape,roll]:if p:p.stop()

func at_door() -> bool:
 return state=="door"

func set_shutter(down: bool) -> void:
 if down==closed:return
 closed=down;shut_clock=0.;roll.pitch_scale=.9 if down else 1.1;roll.play()
 status_lamp.material_override=lamp_closed if down else lamp_open

# The shutter moving and the stair bulb flickering.
func animate(delta: float, seconds: float) -> void:
 var target:=SHUTTER_CLOSED_Y if closed else SHUTTER_OPEN_Y
 shutter_y=move_toward(shutter_y,target,delta*6.);shutter.position.y=shutter_y
 corridor_light.light_energy=.35*(.55+.45*float(sin(seconds*23.)>-.7))*(1. if state!="door" else .7+.3*sin(seconds*9.))

# Power is gone: the shutter rolls up, the bulb dies.
func blackout() -> void:
 state="idle";clock=0.;closed=false;roll.pitch_scale=.7;roll.play()
 status_lamp.material_override=null;corridor_light.hide()
 guest.hide();face_light.light_energy=0.
 for p in [steps,scrape]:p.stop()

# Power is back after a blackout.
func restore() -> void:
 corridor_light.show();status_lamp.material_override=lamp_open;guest.hide();face_light.light_energy=0.;state="idle";clock=0.

func _arrive() -> void:
 state="door";clock=0.;visits+=1;wait=NightwatchConfig.door_wait(rng)
 guest.show();face_light.light_energy=1.4
 # Barely audible: you have to look.
 steps.volume_db=-26.;steps.pitch_scale=.85;steps.play()

# Returns "caught" when it gets in, else "".
func tick(delta: float, level: int, seconds: float) -> String:
 animate(delta,seconds)
 match state:
  "idle":
   if closed:
    shut_clock+=delta
    if shut_clock>=NightwatchConfig.SHUTTER_HOLD:set_shutter(false)
   if level<=0:return ""
   if next<=0.:next=NightwatchConfig.first_visit(level)
   clock+=delta
   if clock>=next:_arrive()
  "door":
   clock+=delta
   if not closed:
    if clock>=NightwatchConfig.grace(level):return "caught"
   else:
    if not scrape.playing and rng.randf()<delta*.8:scrape.pitch_scale=rng.randf_range(.7,.95);scrape.play()
    wait-=delta
    if wait<=0.:
     bang.play();repelled+=1;guest.hide();face_light.light_energy=0.;scrape.stop()
     state="idle";clock=0.;next=NightwatchConfig.rest(level,rng)
     # It is gone; the shutter goes up again a moment later.
     shut_clock=NightwatchConfig.SHUTTER_HOLD-1.2
     nw._say("Es zieht sich zurück.",3.)
 return ""

func snapshot() -> Dictionary:
 return {"state":state,"clock":snappedf(clock,.1),"next":snappedf(next,.1),"closed":closed,"visits":visits,"repelled":repelled}
