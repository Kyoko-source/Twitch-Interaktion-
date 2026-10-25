class_name PatrolPassage
extends Node3D

signal boarded(red: bool)
signal ambushed(red: bool)
signal sealed(red: bool)
const CENTERS:=[-4.3,-2.15]
const ENTRY_Z:=-12.2
var w: PlayWorld
var lanes: Array[Dictionary]=[]
var chosen:=-1
var closing:=false
var clock:=0.0
var fired:=false
var motor: AudioStreamPlayer3D

func build(world: PlayWorld) -> void:
 w=world;name="PatrolPassages"
 for i in range(2): _lane(i)
 motor=AudioStreamPlayer3D.new();motor.stream=load("res://assets/door.ogg");motor.volume_db=-10;motor.unit_size=4;motor.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(motor)

func _lane(index: int) -> void:
 var root:=Node3D.new();root.name="RedPassage" if index else "GreenPassage";root.position=Vector3(CENTERS[index],0,ENTRY_Z);add_child(root)
 var colour:=Color("9f4038") if index else Color("497b62")
 var steel:=w.mat(Color("59635c"),load("res://assets/paint.png"),.48,.65)
 var wall:=w.mat(Color("8b8f7b"),load("res://assets/aged-plaster.png"),.94)
 w.box(root,Vector3(0,.014,0),Vector3(1.5,.012,.4),steel)
 wall.uv1_triplanar=true;wall.uv1_scale=Vector3.ONE*.65;wall.normal_enabled=true;wall.normal_texture=w.atmosphere.micro_normal;wall.normal_scale=.22
 var ground:=w.mat(Color("4e554a"),load("res://assets/floor.png"),.8);ground.uv1_triplanar=true;ground.uv1_scale=Vector3.ONE*.7
 var floor:=w.box(root,Vector3(0,-.09,-5.35),Vector3(1.94,.20,10.8),ground,true);floor.set_meta("foot_surface","concrete")
 for side in [-1,1]:
  w.box(root,Vector3(side*1.0,1.5,-5.35),Vector3(.16,3,10.8),wall,true)
  w.box(root,Vector3(side*.90,.65,-3.8),Vector3(.025,1.2,7.4),w.mat(colour,load("res://assets/paint.png"),.87))
  for y in [.15,1.28]: w.box(root,Vector3(side*.88,y,-3.8),Vector3(.04,.07,7.4),w.materials.metal)
  w.tube(root,Vector3(side*.84,2.7,-.3),Vector3(side*.84,2.7,-7.3),.035,w.materials.rust)
  for z in [-1.2,-3.3,-5.4,-7.0]:
   w.tube(root,Vector3(side*.84,2.7,z),Vector3(side*.98,2.7,z),.019,w.materials.metal)
 w.box(root,Vector3(0,3.04,-5.35),Vector3(2.10,.16,10.8),w.materials.dark,true)
 w.box(root,Vector3(0,1.5,-10.75),Vector3(2.10,3,.16),steel,true)
 for x in [-.88,.88]: w.box(root,Vector3(x,1.5,0),Vector3(.20,3,.30),wall,true)
 w.box(root,Vector3(0,2.98,0),Vector3(1.6,.12,.30),w.materials.dark,true)
 var hinge:=Node3D.new();hinge.name="DecisionDoor";hinge.position=Vector3(-.75,0,.02);root.add_child(hinge)
 var leaf:=w.box(hinge,Vector3(.75,1.45,0),Vector3(1.5,2.9,.10),w.mat(colour,load("res://assets/paint.png"),.63,.2),true)
 var body: StaticBody3D=leaf.get_child(0);body.set_meta("interaction","red" if index else "green")
 w.props["door_red" if index else "door_green"]=hinge
 for face in [-1,1]:
  w.box(hinge,Vector3(1.22,1.22,face*.08),Vector3(.09,.28,.04),steel)
  w.tube(hinge,Vector3(1.02,1.25,face*.13),Vector3(1.31,1.25,face*.13),.024,steel)
 var glow:=w.mat(colour);glow.emission_enabled=true;glow.emission=colour;glow.emission_energy_multiplier=1.6
 w.box(root,Vector3(0,3.35,.24),Vector3(1.7,.40,.11),glow)
 w.mounted_sign(root,"red" if index else "green",Vector3(0,3.35,.31),Vector2(1.5,.3))
 # Both corridors use identical fixtures and geometry; their state reveals no answer.
 for z in [-1.6,-5.6,-9.2]:
  w.box(root,Vector3(0,2.91,z),Vector3(.65,.1,.45),steel)
  var glass:=w.mat(Color("b1beac"));glass.emission_enabled=true;glass.emission=Color("b1beac");glass.emission_energy_multiplier=.7
  w.box(root,Vector3(0,2.85,z),Vector3(.52,.022,.32),glass)
  var light:=OmniLight3D.new();light.position=Vector3(0,2.65,z);light.light_color=Color("c1cbb4");light.light_energy=.65;light.omni_range=4;root.add_child(light)
 for side in [-1,1]:
  w.box(root,Vector3(side*.91,1.38,-9.15),Vector3(.04,2.7,3.08),steel)
  w.tube(root,Vector3(side*.83,.95,-8.1),Vector3(side*.83,.95,-10.45),.03,w.materials.metal)
  for z in [-8.1,-10.45]: w.tube(root,Vector3(side*.83,.95,z),Vector3(side*.94,.95,z),.022,steel)
 w.tube(root,Vector3(-.78,.95,-10.59),Vector3(.78,.95,-10.59),.03,w.materials.metal)
 for x in [-.92,.92]: w.box(root,Vector3(x,1.38,-7.58),Vector3(.1,2.76,.20),steel)
 w.box(root,Vector3(0,2.78,-7.58),Vector3(1.95,.16,.20),steel)
 for z in [-7.68,-7.58,-7.48]: w.box(root,Vector3(0,.018,z),Vector3(1.85,.009,.018),steel)
 var doors: Array[Node3D]=[]
 for side in [-1,1]:
  var door:=w.box(root,Vector3(side*1.36,1.36,-7.58),Vector3(.90,2.7,.07),steel);doors.append(door)
  for k in range(5): w.box(door,Vector3(-.35+k*.175,0,.042),Vector3(.009,2.64,.006),w.materials.dark)
 w.artwork(root,Vector3(0,2.57,-7.43),Vector2(.9,.18),EnvironmentPrint.texture(root,"lift"))
 var cabin_floor:=w.box(root,Vector3(0,.015,-9.18),Vector3(1.82,.01,3.07),steel,true);cabin_floor.set_meta("foot_surface","metal")
 lanes.append({"root":root,"hinge":hinge,"body":body,"open":false,"doors":doors})

func open(red: bool) -> void:
 if closing: return
 var index:=1 if red else 0
 if chosen>=0 and chosen!=index: return
 lanes[index].open=true

func tick(delta: float, active: bool, player: NightGuard, correct_red: bool, completed: bool) -> void:
 motor.stream_paused=not active
 if not active: return
 for i in range(2):
  var lane: Dictionary=lanes[i]
  lane.hinge.rotation.y=move_toward(lane.hinge.rotation.y,-1.56 if lane.open else 0,delta*2.7)
  # The moving panel has no collider while sweeping; its open leaf rests at the wall.
  lane.body.collision_layer=0 if lane.open and absf(lane.hinge.rotation.y)<1.55 else 1
  var p: Vector3=lane.root.to_local(player.position)
  if chosen<0 and lane.open and absf(p.x)<1.05 and p.z<-.7 and p.z> -10.6:
   chosen=i
   lanes[1-i].open=false
  if chosen==i and not closing and not fired:
   if not completed and bool(i)!=correct_red and p.z< -2.2:
    fired=true;ambushed.emit(bool(i));return
   if absf(p.x)<1.03 and p.z< -8.8:
    closing=true;clock=0;motor.position=player.position;motor.play();boarded.emit(bool(i));return
 if closing:
  clock+=delta
  for i in range(2): lanes[chosen].doors[i].position.x=(-1 if i==0 else 1)*lerpf(1.36,.45,smoothstep(0,.72,clock))
  if clock>=.85 and not fired: fired=true;sealed.emit(bool(chosen))

func safe_pose(p: Vector3) -> bool:
 return p.y>-.1 and p.y<2.7 and p.z<ENTRY_Z+.4 and p.z>ENTRY_Z-10.6 and (absf(p.x-CENTERS[0])<.88 or absf(p.x-CENTERS[1])<.88)

func serialize() -> Dictionary:
 return {"chosen":chosen,"open":[lanes[0].open,lanes[1].open]}

func restore(data: Variant) -> void:
 if not data is Dictionary: return
 var selected=data.get("chosen",-1)
 if typeof(selected) not in [TYPE_INT,TYPE_FLOAT]: return
 if not is_finite(float(selected)) or float(selected)!=float(int(selected)) or int(selected) not in [-1,0,1]: return
 var opened=data.get("open",[])
 if not opened is Array or opened.size()!=2 or not opened[0] is bool or not opened[1] is bool: return
 chosen=int(selected)
 for i in range(2):
  lanes[i].open=(opened[i] or chosen==i) and (chosen<0 or chosen==i)
  lanes[i].hinge.rotation.y=-1.56 if lanes[i].open else 0
  lanes[i].body.collision_layer=0 if lanes[i].open else 1

func snapshot() -> Dictionary:
 return {"chosen":chosen,"open":[lanes[0].open,lanes[1].open],"closing":closing,"clock":clock,"doors":[lanes[0].doors[0].position.x,lanes[1].doors[0].position.x]}
