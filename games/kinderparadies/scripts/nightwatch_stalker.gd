class_name NightwatchStalker
extends RefCounted

# 5.5.0: something comes to the control room. The crawler creeps from camera
# to camera towards the stairs; while its camera is on the main monitor it
# slows down. Out of the last room it is in the stairwell (only heard), then at
# the door on the left. The rolling shutter keeps it out but costs power. If
# the shutter is not down in time, or goes up while it waits, it gets in.
# It is NOT an anomaly and is never reported.

const ROUTES:=[
 ["kino","kueche","wartung","empfang"],
 ["kostuem","party_bar","party_tisch","halle","empfang"],
 ["baellebad","spielhalle","halle","wartung"],
 ["party_bar","party_tisch","halle","wartung"],
]
const DOOR_Z:=.55
const DOOR_W:=1.1
const DOOR_H:=2.2
const WALL_X:=-2.65
const SHUTTER_OPEN_Y:=DOOR_H*.5+2.15
const SHUTTER_CLOSED_Y:=DOOR_H*.5

var nw: Nightwatch
var rng:=RandomNumberGenerator.new()
var body: Node3D
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
var route: Array=[]
var index:=0
var clock:=0.
var step_time:=30.
var wait:=0.
var closed:=false
var shutter_y:=SHUTTER_OPEN_Y
var visits:=0
var repelled:=0
var watched:=false

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

# The figure in the world the cameras see.
func _world_body() -> Node3D:
 if is_instance_valid(body) and body.get_parent()==nw.w:return body
 body=CharacterFinish.crawler(1.05);body.name="WatchCrawler";nw.w.add_child(body);body.hide()
 return body

func start() -> void:
 rng.seed=nw.rng.randi()
 state="idle";index=0;clock=0.;visits=0;repelled=0;closed=false;shutter_y=SHUTTER_OPEN_Y;watched=false
 shutter.position.y=shutter_y;status_lamp.material_override=lamp_open
 guest.position=Vector3(-3.35,0,DOOR_Z);guest.rotation=Vector3(0,PI/2,0)
 face_light.position=Vector3(-2.8,.9,DOOR_Z);face_light.omni_range=1.8
 guest.hide();face_light.light_energy=0.
 _world_body().hide()
 for p in [steps,scrape]:p.stop()

func stop() -> void:
 state="idle"
 # Hidden, never freed mid-frame: freeing it while a feed was drawing it
 # tripped the headless renderer. It goes with the world when that is rebuilt.
 if is_instance_valid(body):body.hide()
 if guest:guest.hide()
 for p in [steps,scrape,roll]:if p:p.stop()

func camera() -> String:
 return str(route[index]) if state=="room" and index<route.size() else ""

func _spot(camera_id: String) -> Vector3:
 var spots: Array=[]
 for r in NightwatchConfig.ROOMS:
  for a in r.areas:
   if a.camera==camera_id:spots.append_array(a.spots)
 if spots.is_empty():return NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(camera_id)].at
 return spots[rng.randi_range(0,spots.size()-1)]

# A free bit of floor in plain view of the camera: on the floor, nothing
# standing there, and nothing between the lens and the crawler.
func open_floor(camera_id: String) -> Array:
 var spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(camera_id)]
 var space:=nw.w.get_world_3d().direct_space_state
 var eye: Vector3=spec.p;var ahead: Vector3=spec.at-eye;ahead.y=0;ahead=ahead.normalized()
 var side:=ahead.cross(Vector3.UP)
 var probe:=Camera3D.new();probe.keep_aspect=Camera3D.KEEP_WIDTH;probe.fov=Nightwatch.feed_fov(spec);nw.main_view.add_child(probe);probe.global_position=eye;probe.look_at(spec.at)
 var found: Array=[]
 for d: float in [3.5,4.5,2.8,5.5,2.,6.5,7.5]:
  for o: float in [0.,-.7,.7,-1.4,1.4,-2.1,2.1]:
   var p:=Vector3(eye.x,0,eye.z)+ahead*d+side*o
   var down:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,2.2,0),p+Vector3(0,-1.,0),1))
   # Flat floor (raised stages and tiers count), not a table top.
   if down.is_empty() or float(down.position.y)>.6 or float(down.position.y)<-.3 or (down.normal as Vector3).y<.9:continue
   var foot: Vector3=down.position
   var sphere:=SphereShape3D.new();sphere.radius=.38
   var q:=PhysicsShapeQueryParameters3D.new();q.shape=sphere;q.transform=Transform3D(Basis(),foot+Vector3(0,.55,0));q.collision_mask=1
   if not space.intersect_shape(q,1).is_empty():continue
   var head:=foot+Vector3(0,.5,0)
   if probe.is_position_behind(head):continue
   var px:=probe.unproject_position(head)
   if px.x<40 or px.y<40 or px.x>nw.main_view.size.x-40 or px.y>nw.main_view.size.y-40:continue
   var sight:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,head,1))
   if not sight.is_empty() and eye.distance_to(sight.position)<eye.distance_to(head)-.3:continue
   found.append(foot)
 probe.queue_free()
 return found

func _place() -> void:
 var b:=_world_body()
 var id:=camera()
 if id=="":b.hide();return
 var spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(id)]
 var spots:=open_floor(id)
 var spot:Vector3=spots[rng.randi_range(0,mini(spots.size(),4)-1)] if not spots.is_empty() else _spot(id)
 b.global_position=spot
 var to_cam: Vector3=spec.p-b.global_position;to_cam.y=0
 if to_cam.length()>.1:b.rotation.y=atan2(to_cam.x,to_cam.z)
 b.show()
 # The camera that shows it refreshes at once so the move is never missed.
 var i:=NightwatchConfig.camera_index(id)
 if i>=0 and i<nw.feeds.size():(nw.feeds[i] as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE

func _begin(stage: int) -> void:
 route=ROUTES[rng.randi_range(0,ROUTES.size()-1)]
 index=0;state="room";clock=0.;visits+=1
 step_time=NightwatchConfig.stalker_step(stage)*rng.randf_range(.85,1.15)
 _place()

func set_shutter(down: bool) -> void:
 if down==closed:return
 closed=down;roll.pitch_scale=.9 if down else 1.1;roll.play()
 status_lamp.material_override=lamp_closed if down else lamp_open

func toggle() -> void:
 set_shutter(not closed)

func drain() -> float:
 return NightwatchConfig.SHUTTER_DRAIN if closed else 0.

# Returns "caught" when it gets in, else "".
func tick(delta: float, stage: int, seconds: float) -> String:
 var target:=SHUTTER_CLOSED_Y if closed else SHUTTER_OPEN_Y
 shutter_y=move_toward(shutter_y,target,delta*6.);shutter.position.y=shutter_y
 corridor_light.light_energy=.35*(.55+.45*float(sin(seconds*23.)>-.7))*(1. if state!="door" else .7+.3*sin(seconds*9.))
 match state:
  "idle":
   if seconds>=NightwatchConfig.STALKER_START:
    clock+=delta
    if clock>=NightwatchConfig.stalker_rest(stage):_begin(stage)
  "room":
   # Watched on the main monitor it hardly moves.
   watched=nw.selected==NightwatchConfig.camera_index(camera()) and (nw.fullscreen or nw.view=="monitors")
   clock+=delta*(NightwatchConfig.WATCH_SLOW if watched else 1.)
   if is_instance_valid(body) and body.visible:body.rotation.y+=sin(seconds*1.7)*.002
   if clock>=step_time:
    clock=0.;index+=1
    if index>=route.size():
     state="stairs";_world_body().hide();steps.volume_db=-30.;steps.play()
    else:_place()
  "stairs":
   clock+=delta
   var k:=clampf(clock/(step_time*.8),0.,1.)
   steps.volume_db=lerpf(-30.,-10.,k);steps.pitch_scale=.8+k*.2
   if not steps.playing:steps.play()
   if clock>=step_time*.8:
    steps.stop();state="door";clock=0.;wait=NightwatchConfig.door_wait(rng)
    guest.show();face_light.light_energy=1.4
    if not closed:nw._say("Etwas steht an der Tür.",3.)
  "door":
   clock+=delta
   # Open shutter: a short grace to drop it. Up again while it waits: in.
   if not closed and clock>=NightwatchConfig.DOOR_GRACE:return "caught"
   if closed:
    if not scrape.playing and rng.randf()<delta*.8:scrape.pitch_scale=rng.randf_range(.7,.95);scrape.play()
    if clock>=wait:
     bang.play();repelled+=1;guest.hide();face_light.light_energy=0.;scrape.stop()
     state="idle";clock=0.
     nw._say("Es zieht sich zurück.",3.)
 return ""

# Shutter up while it is at the door: it comes through almost at once.
func peek_risk() -> bool:
 return state=="door" and not closed

func snapshot() -> Dictionary:
 return {"state":state,"camera":camera(),"index":index,"clock":snappedf(clock,.1),"closed":closed,"visits":visits,"repelled":repelled,"watched":watched}
