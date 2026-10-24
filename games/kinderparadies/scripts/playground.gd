class_name ExpandedPlayground
extends Node3D

var w: PlayWorld
var inflatable: Node3D
var inflatable_skin: Node3D
var fan: AudioStreamPlayer3D
const CROCODILE_PATH := "res://assets/creatures/night-crocodile-v4.glb"
var croc_visual: Node3D
var croc_jaw: Node3D
var jaw_rest := Vector3.ZERO

func build(world: PlayWorld) -> void:
 w=world
 _second_tower();_crocodile();_party_dressing();_hall_dressing()

func _second_tower() -> void:
 var tower:=Node3D.new();tower.name="EastTower";add_child(tower)
 # The party room ends at z=1.7. Keep the entire attraction on the hall side.
 tower.position.z=2.1
 for x in [10.5,13.9,17.3]:
  for z in [.7,3.6,6.5]:
   w.tube(tower,Vector3(x,.1,z),Vector3(x,6.25,z),.17,w.materials.gold if x<12 else w.materials.teal)
   w.box(tower,Vector3(x,3.12,z),Vector3(.34,6.24,.34),w.materials.dark,true).hide()
   for y in [2.15,4.15,6.15]:
    w.tube(tower,Vector3(x,y-.09,z),Vector3(x,y+.09,z),.19,w.materials.dark)
 for y in [.25,2.15,4.15,6.15]:
  for z in [.7,6.5]: w.tube(tower,Vector3(10.5,y,z),Vector3(17.3,y,z),.14,w.materials.red)
  for x in [10.5,17.3]:
   if x==10.5 and y==2.15:
    for segment in [Vector2(.7,.8),Vector2(2.2,4.7),Vector2(6.1,6.5)]: w.tube(tower,Vector3(x,y,segment.x),Vector3(x,y,segment.y),.14,w.materials.blue)
   elif x==10.5 and y==.25:
    w.tube(tower,Vector3(x,y,.7),Vector3(x,y,4.7),.14,w.materials.blue);w.tube(tower,Vector3(x,y,6.1),Vector3(x,y,6.5),.14,w.materials.blue)
   else: w.tube(tower,Vector3(x,y,.7),Vector3(x,y,6.5),.14,w.materials.blue)
 w.box(tower,Vector3(13.9,2.05,3.6),Vector3(6.8,.2,5.8),w.materials.blue,true)
 # Leave a real opening over the upper ramp so a standing player can emerge.
 w.box(tower,Vector3(13.6,4.05,3.6),Vector3(3.6,.2,5.8),w.materials.blue,true)
 w.box(tower,Vector3(11.15,4.05,2.65),Vector3(1.3,.2,3.9),w.materials.blue,true)
 w.box(tower,Vector3(17.1,4.05,3.6),Vector3(.4,.2,5.8),w.materials.blue,true)
 w.box(tower,Vector3(16.15,4.05,1.3),Vector3(1.5,.2,1.2),w.materials.blue,true)
 # The same net openings drive ropes and collisions, including both approaches.
 PlayGeometry.panel(w,tower,"EastWestNet","x",10.5,Rect2(.7,.3,5.8,5.85),[Rect2(.8,2.05,1.4,2.05),Rect2(4.7,.2,1.4,3.9)])
 PlayGeometry.panel(w,tower,"EastOuterNet","x",17.3,Rect2(.7,.3,5.8,5.85))
 PlayGeometry.panel(w,tower,"EastRearNet","z",.7,Rect2(10.5,.3,6.8,5.85))
 PlayGeometry.panel(w,tower,"EastFrontNet","z",6.5,Rect2(10.5,.3,6.8,5.85))
 # Bridge is in world hall coordinates so its portals line up on both towers.
 var bridge:=Node3D.new();bridge.name="ConnectingBridge";add_child(bridge)
 for i in range(28):
  var t: float=i/27.0;var x:=lerpf(4.43,10.5,t);var y:=PlayGeometry.bridge_height(t)
  var plank:=Node3D.new();plank.position=Vector3(x,y-.035,3.6)
  plank.rotation.z=atan2(PlayGeometry.bridge_height(minf(1,t+.01))-PlayGeometry.bridge_height(maxf(0,t-.01)),6.07*(minf(1,t+.01)-maxf(0,t-.01)));bridge.add_child(plank)
  var mesh:=w.box(plank,Vector3.ZERO,Vector3(.216,.07,1.2),w.materials.wood);mesh.set_meta("play_obstacle",true)
  for side in [-1,1]:
   w.tube(bridge,Vector3(x,y,3.6+side*.65),Vector3(x,y+.95,3.6+side*.65),.018,w.materials.fabric)
   if i<27:
    var nt: float=(i+1)/27.0
    w.tube(bridge,Vector3(x,y+.95,3.6+side*.65),Vector3(lerpf(4.43,10.5,nt),PlayGeometry.bridge_height(nt)+.95,3.6+side*.65),.027,w.materials.fabric)
 PlayGeometry.bridge_collision(bridge)
 # Open lower play bays have padded obstacles and a crawl tunnel.
 for i in range(5):
  var x:=11.2+i*1.2
  w.tube(tower,Vector3(x,1.9,3.7),Vector3(x,1.7,3.7),.025,w.materials.stitch)
  var roller:=w.tube(tower,Vector3(x,.55,3.7),Vector3(x,1.65,3.7),.22,[w.materials.red,w.materials.gold,w.materials.teal][i%3])
  var roller_shape:=CylinderShape3D.new();roller_shape.radius=.22;roller_shape.height=1.1;PlayGeometry.solid_obstacle(roller,roller_shape)
 # Walkable ramps use the same rotated shape as their visible padded mesh.
 # The lower bays remain open; no invisible box fills the whole attraction.
 ramp(tower,Vector3(8.6,1.1,5.4),Vector3(1.2,.16,5.2),.5,-PI/2)
 ramp(tower,Vector3(16.2,3.27,3.6),Vector3(1.2,.16,5.2),.48)
 w.mounted_sign(tower,"tower",Vector3(13.9,5.45,6.69),Vector2(1.8,.8))
 w.lamp(Vector3(16,5.4,6.4),Color("609da8"),.8,11)

func ramp(parent: Node3D, pos: Vector3, size: Vector3, angle: float, yaw: float=0) -> void:
 var node:=Node3D.new();parent.add_child(node);node.position=pos;node.rotation=Vector3(angle,yaw,0)
 w.box(node,Vector3.ZERO,size,w.materials.red,true)
 for side in [-1,1]: w.tube(node,Vector3(side*.6,.2,-size.z*.5),Vector3(side*.6,.2,size.z*.5),.06,w.materials.gold)

func strand(transforms: Array[Transform3D], a: Vector3, b: Vector3) -> void:
 var difference:=b-a
 transforms.append(Transform3D(Basis(Quaternion(Vector3.UP,difference.normalized()))*Basis.from_scale(Vector3(1,difference.length(),1)),(a+b)*.5))

func _crocodile() -> void:
 inflatable=Node3D.new();inflatable.name="KrokoKlub";inflatable.position=Vector3(12.4,0,11.3);inflatable.rotation.y=-PI/2;add_child(inflatable);w.props.inflatable=inflatable
 inflatable_skin=Node3D.new();inflatable.add_child(inflatable_skin);w.props.inflatable_skin=inflatable_skin
 # Both renderers use the authored mesh, UV skin and outward-facing normals.
 # The old Web approximation had no upper jaw and coplanar eye decorations.
 var scene: PackedScene=load(CROCODILE_PATH)
 croc_visual=scene.instantiate();inflatable_skin.add_child(croc_visual)
 croc_jaw=croc_visual.find_child("UpperJaw",true,false) as Node3D
 assert(croc_jaw!=null,"Shared crocodile upper jaw is missing")
 jaw_rest=croc_jaw.rotation
 for mesh in croc_visual.find_children("*","MeshInstance3D",true,false):
  for surface_index in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.get_active_material(surface_index)
   if material is StandardMaterial3D and material.resource_name=="Worn olive PVC":
    material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.16
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*.65
   elif material is StandardMaterial3D and material.resource_name in ["Faded ochre bed","Yellowed tapered teeth"]:
    material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*1.8
    material.albedo_color=Color("8e7940") if material.resource_name=="Faded ochre bed" else Color("c4b48b")
 var pvc:=w.mat(Color("343e23"),null,.8)
 # A flat compliant surface sits inside the visual PVC bed, with real collision.
 var deck:=StaticBody3D.new();deck.position=Vector3(0,.52,0);deck.set_meta("bounce_speed",8.0);inflatable.add_child(deck)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(3.3,.55,6.6);shape.shape=bounds;deck.add_child(shape)
 w.box(inflatable,Vector3(0,1.12,-.9),Vector3(3.1,1.9,2.7),pvc,true).hide()
 w.box(inflatable,Vector3(.1,.6,-3.2),Vector3(1.5,1.1,1.8),pvc,true).hide()
 for side in [-1,1]: w.box(inflatable,Vector3(side*2.1,.65,0),Vector3(.55,1.3,7.4),pvc,true).hide()
 for i in range(3): w.box(inflatable,Vector3(-2.65+i*.28,.1+i*.13,-1.4),Vector3(.32,.2+i*.26,1.4),w.materials.gold,true)
 # Branding belongs on a worn safety plaque, not floating across its mouth.
 w.mounted_sign(inflatable,"croc",Vector3(-2.45,.34,3.2),Vector2(.65,.35))
 w.tube(self,Vector3(16.1,.4,12.8),Vector3(17.2,.4,12.8),.19,w.materials.dark)
 w.box(self,Vector3(17.5,.35,12.8),Vector3(.65,.7,.65),w.materials.gold,true)
 w.mounted_sign(self,"blower",Vector3(17.5,.55,13.18),Vector2(.54,.28))
 fan=AudioStreamPlayer3D.new();var stream: AudioStreamWAV=load("res://assets/fan.wav");stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);fan.stream=stream;fan.position=Vector3(17.5,.5,12.8);fan.volume_db=-25;fan.max_distance=18;fan.unit_size=3;add_child(fan)
 w.lamp(Vector3(12.4,5.8,12.5),Color("a6b49a"),1.0,12)
 # A floor inspection light rakes the snout and reveals the material wear.
 var worklight:=Node3D.new();worklight.position=Vector3(5.7,0,14.8);add_child(worklight)
 for side in [-1,1]: w.tube(worklight,Vector3(side*.3,.02,.18),Vector3(0,.9,0),.025,w.materials.metal)
 w.box(worklight,Vector3(0,.95,0),Vector3(.35,.24,.14),w.materials.dark)
 w.lamp(Vector3(5.8,1.15,14.65),Color("b9c8af"),.8,8)

func set_croc_jaw(angle: float) -> void:
 croc_jaw.rotation=jaw_rest+Vector3(angle,0,0)

func _party_dressing() -> void:
 # The original six places remain the anomaly reference. The expanded room has
 # a separate cake preparation station, gift corner and children's craft area.
 var party:=Node3D.new();party.name="BirthdayDressing";add_child(party);w.props.party_dressing=party
 w.box(party,Vector3(15,.62,-7.6),Vector3(3.4,.12,1.25),w.materials.wood,true)
 for x in [13.55,16.45]:
  for z in [-8.05,-7.15]: w.box(party,Vector3(x,.29,z),Vector3(.08,.58,.08),w.materials.metal)
 for i in range(7):
  var x:=13.65+(i%4)*.73;var z:=-7.8+floori(i/4.0)*.5
  w.tube(party,Vector3(x,.7,z),Vector3(x,.71,z),.16,w.materials.cream)
  var page:=w.box(party,Vector3(x,.7,z+.15),Vector3(.25,.006,.2),w.materials.paper);page.rotation.y=i*.32
  for j in range(3): w.tube(party,Vector3(x-.09+j*.06,.715,z+.1),Vector3(x-.03+j*.06,.715,z+.2),.004,[w.materials.gold,w.materials.blue,w.materials.red][j])
 for i in range(7):
  var pos:=Vector3(18.72+(i%2)*.55,.25+floori(i/6.0)*.48,-9.1+(i%3)*.56)
  var gift:=w.box(party,pos,Vector3(.62,.48,.52),[w.materials.blue,w.materials.gold,w.materials.red][i%3],true)
  w.box(gift,Vector3(0,.25,0),Vector3(.075,.012,.53),w.materials.cream)
  w.box(gift,Vector3(0,.25,0),Vector3(.63,.013,.075),w.materials.cream)
  w.tube(gift,Vector3(-.11,.27,0),Vector3(0,.35,0),.02,w.materials.cream);w.tube(gift,Vector3(.11,.27,0),Vector3(0,.35,0),.02,w.materials.cream)
 for ends in [[Vector3(6.91,4.6,-9.8),Vector3(7.2,4.6,-9.8)],[Vector3(18.86,4.59,-9.8),Vector3(19.51,4.59,-9.8)]]:
  w.tube(party,ends[0],ends[1],.008,w.materials.stitch)
 for i in range(22):
  var x:=7.2+i*.53;var y:=4.6-sin(i/21.0*PI)*.5
  w.tube(party,Vector3(x,y,-9.8),Vector3(x+.53,y-.01,-9.8),.006,w.materials.stitch)
  var flag:=w.box(party,Vector3(x,y-.16,-9.8),Vector3(.32,.32,.012),[w.materials.red,w.materials.gold,w.materials.teal][i%3]);flag.rotation.z=sin(i)*.2
 w.mounted_sign(party,"birthday",Vector3(13.4,4.75,-11.95),Vector2(2.5,.85))
 # A second, lower activity table with child-sized stools gives the wider room
 # a distinct craft corner rather than merely stretching its walls.
 w.tube(party,Vector3(13.7,.58,-3.8),Vector3(13.7,.66,-3.8),1.1,w.materials.cream)
 for side in [-1,1]:
  for z in [-4.45,-3.15]: w.tube(party,Vector3(13.7+side*.65,.05,z),Vector3(13.7+side*.65,.58,z),.04,w.materials.metal)
 for i in range(5):
  var angle:=i*TAU/5;var pos:=Vector3(13.7+sin(angle)*1.4,0,-3.8+cos(angle)*1.4)
  w.tube(party,pos+Vector3(0,.32,0),pos+Vector3(0,.39,0),.23,[w.materials.gold,w.materials.teal,w.materials.red][i%3])
  for side in [-1,1]:
   for back in [-1,1]: w.tube(party,pos+Vector3(side*.13,.02,back*.13),pos+Vector3(side*.13,.33,back*.13),.025,w.materials.metal)
 for i in range(5):
  var x:=13.1+(i%3)*.45;var z:=-4.2+(i/3)*.5
  var page:=w.box(party,Vector3(x,.67,z),Vector3(.28,.005,.32),w.materials.paper);page.rotation.y=i*.47
  w.tube(party,Vector3(x-.1,.68,z-.08),Vector3(x+.1,.68,z+.1),.008,w.materials.red)
 # The stage owns the north wall; no old frames cover the new opening.
 w.painting(party,2,Vector3(10.15,2.1,-11.95),Vector2(1.05,.95))
 # Layered table runner and rounded serving trays give the preparation area purpose.
 w.box(party,Vector3(15,.695,-7.6),Vector3(.7,.014,1.23),w.materials.fabric)
 for z in [-8,-7.25]:
  w.tube(party,Vector3(15.9,.7,z),Vector3(15.9,.72,z),.23,w.materials.metal)
  for j in range(3):
   var cake:=w.sphere(party,Vector3(15.75+j*.15,.76,z),.065,w.materials.cream);cake.scale.y=.65
 w.lamp(Vector3(15.7,4.2,-7.6),Color("c5a278"),.65,9)

func _hall_dressing() -> void:
 var dressing:=Node3D.new();dressing.name="HallDressing";add_child(dressing)
 # The lift opens into a clear reception route, not the old fenced toddler pen.
 # Wall pictures stay on the solid wall beside the new aperture.
 for i in range(3): w.painting(dressing,i,Vector3(-4.8+i*2.15,2.15,16.97),Vector2(1.1,.9),PI)
 var seat_mat:=w.mat(Color("4b5b50"),load("res://assets/vinyl.png"),.88)
 w.box(dressing,Vector3(-9.65,.49,13.5),Vector3(.55,.14,1.9),seat_mat,true)
 w.box(dressing,Vector3(-9.91,.87,13.5),Vector3(.09,.65,1.9),seat_mat,true)
 for x in [-9.85,-9.45]:
  for z in [12.75,14.25]: w.box(dressing,Vector3(x,.22,z),Vector3(.045,.4,.045),w.materials.metal)
 w.box(dressing,Vector3(-8,.02,16.2),Vector3(1.9,.012,1.35),w.materials.dark)
 for i in range(8):
  var x:=-2.3+i*.55;var pad:=w.box(dressing,Vector3(x,.08,13.3),Vector3(.5,.14,1.3),[w.materials.red,w.materials.blue,w.materials.gold][i%3],true)
  pad.rotation.y=sin(i)*.1
 for i in range(6):
  var x:=5+i*.35
  w.tube(dressing,Vector3(x,.05,16.25),Vector3(x,1.3,16.25),.055,w.materials.gold)
  w.sphere(dressing,Vector3(x,1.3,16.25),.1,w.materials.red)
 w.mounted_sign(dressing,"pickup",Vector3(5.8,3.4,16.97),Vector2(2.1,.8),PI)
 for i in range(6):
  var z:=.5+i*2.8
  w.box(dressing,Vector3(19.59,.7,z),Vector3(.15,1.35,2.5),[w.materials.blue,w.materials.gold,w.materials.teal][i%3])
  w.tube(dressing,Vector3(19.48,.15,z-1.1),Vector3(19.48,1.25,z-1.1),.012,w.materials.stitch)
 w.lamp(Vector3(-4.5,5.8,13.5),Color("8aa8aa"),.6,10)
 w.lamp(Vector3(18.4,3,9),Color("c1a072"),.55,8)

func tick(active: bool) -> void:
 if active:
  if not fan.playing: fan.play()
 fan.stream_paused=not active
