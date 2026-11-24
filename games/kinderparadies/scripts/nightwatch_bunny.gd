class_name NightwatchBunny
extends RefCounted

# 5.6.1: the plush rabbit, from night 3. Unlike the crawler and the clown it
# really walks the cameras: from the costume store, room by room, to the stair
# door. It only moves while nobody watches it: while its camera is on the main
# monitor (or full screen) and you look at the monitor wall, it stays where it
# is. At the stair door the shutter sends it back to the start; with the
# shutter up it comes in.

# Its way through the venue, far to near: camera, floor point, the way it faces.
const ROUTE:=[
 {"camera":"kostuem","p":Vector3(14.6,0,-15.4),"name":"Kostümfundus"},
 {"camera":"party_bar","p":Vector3(16.2,0,-4.2),"name":"Snackbar"},
 {"camera":"party_tisch","p":Vector3(10.4,0,-4.4),"name":"Party Raum"},
 {"camera":"halle","p":Vector3(-4.2,0,-7.4),"name":"Halle"},
 {"camera":"empfang","p":Vector3(-6.0,0,8.3),"name":"Empfang"},
]
const SCALE:=1.55
# In the stair corridor, a little behind where the crawler crouches.
const DOOR_AT:=Vector3(-4.25,0,NightwatchStalker.DOOR_Z)
const DOOR_SCALE:=1.35
# With the shutter down this long it gives up and goes back to the start.
const DOOR_GIVE_UP:=2.2

var nw: Nightwatch
var rng:=RandomNumberGenerator.new()
var body: Node3D
var door_body: Node3D
var door_light: OmniLight3D
var squeak: AudioStreamPlayer
var bang: AudioStreamPlayer

# -1: not out tonight; 0..ROUTE.size()-1: on that camera; ROUTE.size(): at the door.
var stage:=-1
var clock:=0.
var next:=0.
var door_clock:=0.
var shut_for:=0.
var moves:=0
var repelled:=0
var watched_time:=0.

func build(owner: Nightwatch) -> void:
 nw=owner
 # The one that comes to the door lives in the control room.
 door_body=nw.w.atmosphere.plush(nw.room,DOOR_AT,DOOR_SCALE);door_body.name="DoorRabbit";door_body.rotation.y=PI/2
 _eyes(door_body,Nightwatch.ROOM_LAYER)
 for mesh: GeometryInstance3D in door_body.find_children("*","GeometryInstance3D",true,false):mesh.layers=Nightwatch.ROOM_LAYER
 door_body.hide()
 # Just enough light in the stair corridor to make out its shape.
 door_light=OmniLight3D.new();door_light.name="RabbitDoorLight";door_light.light_color=Color("ffb08a");door_light.light_energy=0.;door_light.omni_range=1.6;door_light.light_cull_mask=Nightwatch.ROOM_LAYER;door_light.position=DOOR_AT+Vector3(.75,1.1,0);nw.room.add_child(door_light)
 squeak=nw._player(load("res://assets/ambient-v527/squeak-toy-1.ogg"),-30.)
 bang=nw._player(load("res://assets/scares-v260/dry-impact.wav"),-4.)

# Two dull red points where the stitched eyes are.
func _eyes(parent: Node3D, layer: int) -> void:
 var glow:=StandardMaterial3D.new();glow.albedo_color=Color("2a0402");glow.emission_enabled=true;glow.emission=Color("ff2a12");glow.emission_energy_multiplier=1.6;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 for side in [-1,1]:
  var eye:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.024;ball.height=.048;eye.mesh=ball;eye.material_override=glow
  eye.position=Vector3(side*.078,.655,.226);eye.layers=layer;parent.add_child(eye)

func start(level: int) -> void:
 rng.seed=nw.rng.randi()
 _free_body()
 stage=-1;clock=0.;door_clock=0.;shut_for=0.;moves=0;repelled=0;watched_time=0.
 door_body.hide();door_light.light_energy=0.
 if level<=0:return
 # The one on the cameras belongs to the world the feeds show.
 body=nw.w.atmosphere.plush(nw.w,ROUTE[0].p,SCALE);body.name="NightwatchRabbit"
 _eyes(body,1)
 _place(0)
 next=NightwatchConfig.bunny_first(level)

func stop() -> void:
 stage=-1;_free_body()
 if door_body:door_body.hide()
 if door_light:door_light.light_energy=0.
 if squeak:squeak.stop()

func _free_body() -> void:
 if is_instance_valid(body):body.queue_free()
 body=null

func active() -> bool:
 return stage>=0

func at_door() -> bool:
 return stage==ROUTE.size()

func camera_id() -> String:
 return str(ROUTE[stage].camera) if stage>=0 and stage<ROUTE.size() else ""

func _place(index: int) -> void:
 stage=index;clock=0.
 if index>=ROUTE.size():
  if is_instance_valid(body):body.hide()
  door_body.show();door_light.light_energy=.6;door_clock=0.;shut_for=0.
  return
 door_body.hide();door_light.light_energy=0.
 if not is_instance_valid(body):return
 body.show()
 var spot: Vector3=ROUTE[index].p;body.position=spot
 # It always faces the camera that shows it, a little turned.
 var cam_spec: Dictionary=NightwatchConfig.CAMERAS[NightwatchConfig.camera_index(str(ROUTE[index].camera))]
 var to: Vector3=cam_spec.p-spot
 body.rotation=Vector3(0,atan2(to.x,to.z)+rng.randf_range(-.25,.25),rng.randf_range(-.08,.08))
 _refresh_feed(str(ROUTE[index].camera))
 if index>0:_refresh_feed(str(ROUTE[index-1].camera))

func _refresh_feed(id: String) -> void:
 var i:=NightwatchConfig.camera_index(id)
 if i>=0 and i<nw.feeds.size():(nw.feeds[i] as SubViewport).render_target_update_mode=SubViewport.UPDATE_ONCE

# On the main monitor (or full screen) while you look at the monitor wall.
func watched() -> bool:
 if stage<0 or stage>=ROUTE.size():return false
 return nw.view=="monitors" and nw.qte.is_empty() and NightwatchConfig.CAMERAS[nw.selected].id==camera_id()

# Returns "caught" when it gets in, else "".
func tick(delta: float, level: int) -> String:
 if stage<0 or level<=0:return ""
 if at_door():
  door_clock+=delta
  if nw.stalker and nw.stalker.closed:
   shut_for+=delta
   if shut_for>=DOOR_GIVE_UP:
    bang.play();repelled+=1;nw._say("Der Hase ist weg. Er fängt wieder hinten an.",3.)
    _place(0);next=NightwatchConfig.bunny_move(level,rng);return ""
  else:
   shut_for=0.
   if door_clock>=NightwatchConfig.bunny_door(level):return "caught"
  return ""
 if watched():
  watched_time+=delta;return ""
 clock+=delta
 if clock>=next:
  moves+=1;_place(stage+1);next=NightwatchConfig.bunny_move(level,rng)
  squeak.pitch_scale=rng.randf_range(.7,.9);squeak.volume_db=-30.+stage*2.;squeak.play()
  if at_door():nw._say("Etwas Weiches tappt die Treppe herunter.",3.)
 return ""

# A click into the full-screen picture on the rabbit (feed pixels).
func hit(feed_camera: Camera3D, point: Vector2) -> bool:
 if not is_instance_valid(body) or not body.visible or NightwatchConfig.CAMERAS[nw.selected].id!=camera_id():return false
 var rect:=Rect2();var first:=true
 for y in [0.,.6,1.15]:
  for dx in [-.35,.35]:
   var corner:=body.global_position+Vector3(dx,y*SCALE,0)
   if feed_camera.is_position_behind(corner):continue
   var px:=feed_camera.unproject_position(corner)
   if first:rect=Rect2(px,Vector2.ZERO);first=false
   else:rect=rect.expand(px)
 return not first and rect.grow(NightwatchConfig.HIT_MARGIN).has_point(point)

func snapshot() -> Dictionary:
 return {"stage":stage,"camera":camera_id(),"door":at_door(),"clock":snappedf(clock,.1),"next":snappedf(next,.1),"moves":moves,"repelled":repelled}
