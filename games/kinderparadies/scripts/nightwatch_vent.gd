class_name NightwatchVent
extends RefCounted

# 5.6.0: the clown in the ventilation shaft on the right. It does not walk the
# cameras: now and then it is simply sitting in the opening, barely visible in
# the dark. Shine the torch (F, 10 % of the power) into the shaft and it crawls
# away; leave it there too long and it comes through.

const WALL_X:=2.65
const Z:=-.75
const Y:=.42
const W:=.8
const H:=.56
const DEPTH:=1.6
# Only the torch, its own faint glow and the lunge light reach this render
# layer, so the room lamps never light the clown.
const LAYER:=1<<10
const HEAD_AT:=Vector3(WALL_X+.3,Y-.02,Z)
const GLOW:=.07
const KNOCKS:=["res://assets/ambience/pipe-knock.wav","res://assets/ambient-v527/radiator-knock-1.ogg","res://assets/ambient-v527/radiator-knock-2.ogg","res://assets/ambient-v527/metal-creak-1.ogg","res://assets/ambient-v527/metal-creak-2.ogg"]

var nw: Nightwatch
var rng:=RandomNumberGenerator.new()
var root: Node3D
var clown: Node3D
var head: Node3D
var rest_basis:=Basis()
var glow: OmniLight3D
var face_light: OmniLight3D
var knock: AudioStreamPlayer3D
var breath: AudioStreamPlayer3D
var shriek: AudioStreamPlayer3D

var state:="idle"
var clock:=0.
var next:=0.
var lit_time:=0.
var visits:=0
var repelled:=0
var dark:=false

func build(owner: Nightwatch) -> void:
 nw=owner
 var metal:=nw._pbr("rusty_painted_metal",Color(.36,.38,.37),1.4)
 var plate:=nw._pbr("metal_plate",Color(.3,.32,.31),2.)
 var inner:=StandardMaterial3D.new();inner.albedo_color=Color(.07,.075,.075);inner.roughness=.55;inner.metallic=.7
 root=Node3D.new();root.name="VentShaft";nw.room.add_child(root)
 # Frame round the opening and the duct behind it, ending in a bend.
 var fx:=WALL_X-.06
 nw._box(root,Vector3(fx,Y+H*.5+.03,Z),Vector3(.07,.06,W+.12),metal)
 nw._box(root,Vector3(fx,Y-H*.5-.03,Z),Vector3(.07,.06,W+.12),metal)
 for dz: float in [-1.,1.]:nw._box(root,Vector3(fx,Y,Z+dz*(W*.5+.03)),Vector3(.07,H,.06),metal)
 var cx:=WALL_X+DEPTH*.5
 nw._box(root,Vector3(cx,Y-H*.5-.02,Z),Vector3(DEPTH,.04,W+.04),inner)
 nw._box(root,Vector3(cx,Y+H*.5+.02,Z),Vector3(DEPTH,.04,W+.04),inner)
 for dz: float in [-1.,1.]:nw._box(root,Vector3(cx,Y,Z+dz*(W*.5+.02)),Vector3(DEPTH,H+.08,.04),inner)
 nw._box(root,Vector3(WALL_X+DEPTH,Y,Z+.2),Vector3(.04,H+.08,W*.6),inner)
 # Broken-off grille stubs round the opening, so it reads as a vent.
 for k in range(5):nw._box(root,Vector3(fx-.005,Y+H*.5-.03,Z-W*.5+.08+k*.16),Vector3(.04,.06,.02),metal)
 for k in range(5):nw._box(root,Vector3(fx-.005,Y-H*.5+.02,Z-W*.5+.08+k*.16),Vector3(.04,.04,.02),metal)
 # Seams in the duct, so the light shows depth.
 for k in range(4):nw._box(root,Vector3(WALL_X+.3+k*.38,Y-H*.5,Z),Vector3(.025,.012,W),metal)
 # The grille it already pushed out, lying on the floor below.
 var grille:=nw._box(root,Vector3(2.25,.012,Z+.12),Vector3(.62,.016,.84),plate);grille.rotation.y=.3;grille.name="FallenVentGrille"
 for k in range(8):nw._box(grille,Vector3(0,.012,-.35+k*.1),Vector3(.56,.012,.03),metal)
 for mesh: GeometryInstance3D in root.find_children("*","GeometryInstance3D",true,false):mesh.layers=Nightwatch.ROOM_LAYER
 nw._clickable(root,Vector3(WALL_X-.05,Y,Z),Vector3(.14,H,W),"vent")
 # The clown: only its head is needed in the duct; the body stays hidden.
 var figure:=HorrorFigures.clown(nw.w,root)
 clown=figure.root;head=figure.head;clown.name="VentClown"
 for child in clown.get_children():if child!=head and child is Node3D:(child as Node3D).hide()
 # Layers change only outside the tree: changing them on paired meshes left
 # the renderer with stale light pairs and crashed it on exit.
 root.remove_child(clown)
 for mesh: GeometryInstance3D in clown.find_children("*","GeometryInstance3D",true,false):mesh.layers=LAYER
 root.add_child(clown)
 clown.rotation.y=-PI/2;rest_basis=clown.basis
 clown.position=HEAD_AT-clown.basis*head.position
 face_light=OmniLight3D.new();face_light.name="VentFaceLight";face_light.light_color=Color("ffd2b0");face_light.light_energy=0.;face_light.omni_range=1.2;face_light.light_cull_mask=LAYER;root.add_child(face_light)
 # Just enough to make out a shape in the dark opening.
 glow=OmniLight3D.new();glow.name="VentGlow";glow.light_color=Color("9a6a5a");glow.light_energy=0.;glow.omni_range=.9;glow.light_cull_mask=LAYER;root.add_child(glow);glow.position=HEAD_AT+Vector3(-.45,.1,0)
 clown.hide()
 knock=_sound3d(null,-20.);breath=_sound3d(load("res://assets/ambience-v180/breathing.wav"),-24.)
 shriek=_sound3d(load(ScareBank.track("clown",1)),-6.)

func _sound3d(stream: AudioStream, volume: float) -> AudioStreamPlayer3D:
 var p:=AudioStreamPlayer3D.new();p.stream=stream;p.volume_db=volume;p.unit_size=4.;p.max_db=6.;root.add_child(p);p.position=Vector3(WALL_X+.6,Y,Z);return p

func start() -> void:
 rng.seed=nw.rng.randi()
 state="idle";clock=0.;next=0.;lit_time=0.;visits=0;repelled=0;dark=false
 clown.hide();clown.basis=rest_basis;clown.position=HEAD_AT-clown.basis*head.position;clown.rotation.z=0.
 glow.light_energy=0.;face_light.light_energy=0.
 for p in [knock,breath,shriek]:p.stop()

func stop() -> void:
 state="idle";dark=false
 if clown:clown.hide()
 if glow:glow.light_energy=0.
 for p in [knock,breath,shriek]:if p:p.stop()

func at_opening() -> bool:
 return state=="vent"

func blackout() -> void:
 dark=true;state="idle";clock=0.;clown.hide();glow.light_energy=0.;breath.stop()

func restore() -> void:
 dark=false

func _arrive() -> void:
 state="vent";clock=0.;lit_time=0.;visits+=1
 clown.basis=rest_basis;clown.position=HEAD_AT-clown.basis*head.position;clown.show();glow.light_energy=GLOW
 # A faint knock in the duct: easy to miss.
 knock.stream=load(KNOCKS[rng.randi_range(0,KNOCKS.size()-1)]);knock.volume_db=-22.;knock.pitch_scale=rng.randf_range(.8,1.);knock.play()
 breath.play()

# Lit by the torch long enough: it crawls back into the dark.
func _retreat(level: int) -> void:
 state="idle";clock=0.;next=NightwatchConfig.rest(level,rng);repelled+=1
 clown.hide();glow.light_energy=0.;breath.stop()
 shriek.stream=load(ScareBank.track("clown",rng.randi_range(1,4)));shriek.volume_db=-12.;shriek.pitch_scale=1.25;shriek.play()
 nw._say("Es kriecht zurück in den Schacht.",3.)

# Returns "caught" when it comes through, else "".
func tick(delta: float, level: int, seconds: float, torch_on_vent: bool) -> String:
 if dark or level<=0:return ""
 match state:
  "idle":
   if next<=0.:next=NightwatchConfig.first_visit(level)+12.
   clock+=delta
   if clock>=next:_arrive()
  "vent":
   clock+=delta
   clown.rotation.z=sin(seconds*1.3)*.05
   glow.light_energy=GLOW*(.8+.2*sin(seconds*2.))
   if torch_on_vent:
    lit_time+=delta
    if lit_time>=NightwatchConfig.TORCH_REPEL:_retreat(level);return ""
   if clock>=NightwatchConfig.grace(level):return "caught"
 return ""

# It comes through the opening, into your face.
func lunge(cam: Camera3D) -> void:
 breath.stop();clown.show();glow.light_energy=1.2
 clown.look_at(cam.global_position,Vector3.UP,true)
 var offset:=head.global_position-clown.global_position
 var from:=clown.global_position
 var to:=cam.global_position-cam.global_basis.z*.3-Vector3(0,.06,0)-offset
 JumpscareFX.fire(1.,.12)
 var scream:=nw._player(load(ScareBank.track("clown",rng.randi_range(1,4))),0.);ScareBank.loud(scream);scream.play();ScareBank.sting()
 face_light.light_energy=.7
 var t:=0.
 while t<.3 and is_instance_valid(clown):
  t+=nw.get_process_delta_time();var k:=smoothstep(0.,.3,t)
  clown.global_position=from.lerp(to,k)
  face_light.global_position=cam.global_position-cam.global_basis.z*.05+Vector3(0,.12,0)
  await nw.get_tree().process_frame
 await nw.get_tree().create_timer(.9).timeout
 if is_instance_valid(clown):clown.hide()
 face_light.light_energy=0.;glow.light_energy=0.

func snapshot() -> Dictionary:
 return {"state":state,"clock":snappedf(clock,.1),"next":snappedf(next,.1),"visits":visits,"repelled":repelled,"visible":clown.visible if clown else false}
