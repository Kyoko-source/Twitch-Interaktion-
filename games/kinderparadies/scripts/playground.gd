class_name ExpandedPlayground
extends Node3D

var w: PlayWorld
var inflatable: Node3D
var inflatable_skin: Node3D
var fan: AudioStreamPlayer3D
const CROCODILE_PATH := "res://assets/creatures/night-crocodile.glb"
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
  for x in [10.5,17.3]: w.tube(tower,Vector3(x,y,.7),Vector3(x,y,6.5),.14,w.materials.blue)
 w.box(tower,Vector3(13.9,2.05,3.6),Vector3(6.8,.2,5.8),w.materials.blue,true)
 # Leave a real opening over the upper ramp so a standing player can emerge.
 w.box(tower,Vector3(13.6,4.05,3.6),Vector3(3.6,.2,5.8),w.materials.blue,true)
 w.box(tower,Vector3(11.15,4.05,2.65),Vector3(1.3,.2,3.9),w.materials.blue,true)
 w.box(tower,Vector3(17.1,4.05,3.6),Vector3(.4,.2,5.8),w.materials.blue,true)
 w.box(tower,Vector3(16.15,4.05,1.3),Vector3(1.5,.2,1.2),w.materials.blue,true)
 # Mesh nets, not a wall-sized opaque texture. Instanced rope keeps draw calls low.
 var transforms: Array[Transform3D]=[]
 for x in [10.5,17.3]:
  for i in range(31):
   var y:=.3+i*.19
   if x==10.5 and y<4:
    strand(transforms,Vector3(x,y,.7),Vector3(x,y,4.8));strand(transforms,Vector3(x,y,6),Vector3(x,y,6.5))
   else: strand(transforms,Vector3(x,y,.7),Vector3(x,y,6.5))
  for i in range(30):
   var z:=.7+i*.2
   strand(transforms,Vector3(x,4 if x==10.5 and z>4.8 and z<6 else .3,z),Vector3(x,6.15,z))
 for z in [.7,6.5]:
  for i in range(31): strand(transforms,Vector3(10.5,.3+i*.19,z),Vector3(17.3,.3+i*.19,z))
  for i in range(35): strand(transforms,Vector3(10.5+i*.2,.3,z),Vector3(10.5+i*.2,6.15,z))
 var ropes:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
 var rope:=CylinderMesh.new();rope.height=1;rope.top_radius=.009;rope.bottom_radius=.009;rope.radial_segments=5;mm.mesh=rope;mm.instance_count=transforms.size()
 for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
 ropes.multimesh=mm;ropes.material_override=w.materials.stitch;ropes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tower.add_child(ropes)
 # A high bridge connects the two structures, leaving the patrol lane underneath.
 for i in range(23):
  var x:=5.05+i*.24;var y:=lerpf(2.98,2.18,i/22.0)-sin(i/22.0*PI)*.18
  w.box(tower,Vector3(x,y,2.15),Vector3(.22,.07,1.35),w.materials.wood,true)
  for side in [-1,1]:
   w.tube(tower,Vector3(x,y,2.15+side*.7),Vector3(x,y+.9,2.15+side*.7),.016,w.materials.fabric)
   if i<22: w.tube(tower,Vector3(x,y+.9,2.15+side*.7),Vector3(x+.24,lerpf(2.98,2.18,(i+1)/22.0)-sin((i+1)/22.0*PI)*.18+.9,2.15+side*.7),.025,w.materials.fabric)
 # Open lower play bays have padded obstacles and a crawl tunnel.
 for i in range(5):
  var x:=11.2+i*1.2
  w.tube(tower,Vector3(x,1.9,3.7),Vector3(x,1.7,3.7),.025,w.materials.stitch)
  w.tube(tower,Vector3(x,.55,3.7),Vector3(x,1.65,3.7),.22,[w.materials.red,w.materials.gold,w.materials.teal][i%3])
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
  var pos:=Vector3(17.2+(i%2)*.8,.25+floori(i/6.0)*.48,-10.3+(i%3)*.56)
  var gift:=w.box(party,pos,Vector3(.62,.48,.52),[w.materials.blue,w.materials.gold,w.materials.red][i%3],true)
  w.box(gift,Vector3(0,.25,0),Vector3(.075,.012,.53),w.materials.cream)
  w.box(gift,Vector3(0,.25,0),Vector3(.63,.013,.075),w.materials.cream)
  w.tube(gift,Vector3(-.11,.27,0),Vector3(0,.35,0),.02,w.materials.cream);w.tube(gift,Vector3(.11,.27,0),Vector3(0,.35,0),.02,w.materials.cream)
 w.box(party,Vector3(18.8,.9,-4.3),Vector3(.6,1.8,3.5),w.materials.wood,true)
 for z in [-5.4,-4.3,-3.2]:
  for y in [.35,.95,1.55]:
   w.box(party,Vector3(18.4,y,z),Vector3(.65,.045,1),w.materials.cream)
   for i in range(3): w.tube(party,Vector3(18.35+i*.1,y+.025,z),Vector3(18.35+i*.1,y+.18,z),.045,w.materials.paper)
 for i in range(22):
  var x:=7.2+i*.53;var y:=4.6-sin(i/21.0*PI)*.5
  w.tube(party,Vector3(x,y,-9.8),Vector3(x+.53,y-.01,-9.8),.006,w.materials.stitch)
  var flag:=w.box(party,Vector3(x,y-.16,-9.8),Vector3(.32,.32,.012),[w.materials.red,w.materials.gold,w.materials.teal][i%3]);flag.rotation.z=sin(i)*.2
 w.mounted_sign(party,"birthday",Vector3(14,3.6,-11.95),Vector2(2.5,1.05))
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
 for i in range(5):
  w.painting(party,(i+1)%4,Vector3(10.6+i*1.75,2.1,-11.95),Vector2(1.15,.95))
 # Layered table runner and rounded serving trays give the preparation area purpose.
 w.box(party,Vector3(15,.695,-7.6),Vector3(.7,.014,1.23),w.materials.fabric)
 for z in [-8,-7.25]:
  w.tube(party,Vector3(15.9,.7,z),Vector3(15.9,.72,z),.23,w.materials.metal)
  for j in range(3):
   var cake:=w.sphere(party,Vector3(15.75+j*.15,.76,z),.065,w.materials.cream);cake.scale.y=.65
 w.lamp(Vector3(15.7,4.2,-7.6),Color("c5a278"),.65,9)

func _hall_dressing() -> void:
 var dressing:=Node3D.new();dressing.name="HallDressing";add_child(dressing)
 # Quiet corners give the larger hall purpose, with adult-size benches beside
 # child-size toys, shoe storage and a gated toddler zone.
 for i in range(4):
  var x:=-7.7+i*1.15
  w.box(dressing,Vector3(x,.2,13.4),Vector3(.85,.36,.85),[w.materials.gold,w.materials.blue,w.materials.teal][i%3],true)
  w.sphere(dressing,Vector3(x,.48,13.4),.2,w.materials.red)
 for x in [-9.7,-2.8]:
  for z in [12.2,15.7]:
   w.tube(dressing,Vector3(x,0,z),Vector3(x,1.05,z),.06,w.materials.wood)
 for i in range(23): w.tube(dressing,Vector3(-9.7+i*.3,.12,15.7),Vector3(-9.7+i*.3,1,15.7),.026,w.materials.wood)
 for y in [.18,.95]: w.tube(dressing,Vector3(-9.7,y,15.7),Vector3(-2.8,y,15.7),.05,w.materials.wood)
 w.mounted_sign(dressing,"nursery",Vector3(-6.2,3.55,16.97),Vector2(1.65,.75),PI)
 for i in range(3): w.painting(dressing,i,Vector3(-8+i*2.15,2.15,16.97),Vector2(1.1,.9),PI)
 for i in range(8):
  var x:=-.8+i*.65;var pad:=w.box(dressing,Vector3(x,.08,14),Vector3(.58,.14,2),[w.materials.red,w.materials.blue,w.materials.gold][i%3],true)
  pad.rotation.y=sin(i)*.1
 for i in range(6):
  var x:=.5+i*.7
  w.tube(dressing,Vector3(x,.05,16.5),Vector3(x,1.3,16.5),.055,w.materials.gold)
  w.sphere(dressing,Vector3(x,1.3,16.5),.1,w.materials.red)
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
