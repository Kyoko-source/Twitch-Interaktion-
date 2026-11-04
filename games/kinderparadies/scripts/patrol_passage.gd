class_name PatrolPassage
extends Node3D

signal boarded(red: bool)
signal ambushed(red: bool)
signal sealed(red: bool)
const CENTERS:=[-4.3,-2.15]
const ENTRY_Z:=-12.2
const SHIFTS:=[-.4,.8]
var w: PlayWorld
var lanes: Array[Dictionary]=[]
var chosen:=-1
var closing:=false
var clock:=0.0
var fired:=false
var motor: AudioStreamPlayer3D
var floor_number:=1
var floor_displays: Array[Label3D]=[]
var red_locked:=false
var horse_note: Node3D

func set_floor(value: int) -> void:
 floor_number=clampi(value,1,13)
 for lane in lanes:lane.lift.set_floor(floor_number)

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
 var path: Array[Vector2]=[Vector2(0,.15),Vector2(0,-1.4),Vector2(SHIFTS[index],-4.),Vector2(SHIFTS[index],-7.43)]
 _corridor(root,path,ground,wall,steel,colour)
 for x in [-.88,.88]: w.box(root,Vector3(x,1.5,0),Vector3(.20,3,.30),wall,true)
 w.box(root,Vector3(0,2.98,0),Vector3(1.6,.12,.30),w.materials.dark,true)
 var hinge:=Node3D.new();hinge.name="DecisionDoor";hinge.position=Vector3(-.75,0,.02);root.add_child(hinge)
 var leaf:=w.box(hinge,Vector3(.75,1.45,0),Vector3(1.5,2.9,.10),w.mat(colour,load("res://assets/paint.png"),.63,.2),true)
 var body: StaticBody3D=leaf.get_child(0);body.set_meta("interaction","red" if index else "green")
 w.props["door_red" if index else "door_green"]=hinge
 for face in [-1,1]:
  w.box(hinge,Vector3(1.22,1.22,face*.08),Vector3(.09,.28,.04),steel)
  w.tube(hinge,Vector3(1.02,1.25,face*.13),Vector3(1.31,1.25,face*.13),.024,steel)
 if index==1:
  horse_note=Node3D.new();horse_note.name="HorseClueOnRedDoor";horse_note.position=Vector3(.75,1.94,.073);hinge.add_child(horse_note)
  w.box(horse_note,Vector3.ZERO,Vector3(1.10,.55,.008),w.mat(Color("b2a47c"),load("res://assets/aged-plaster.png"),.97))
  for x in [-.42,.42]:
   var tape:=w.box(horse_note,Vector3(x,.24,.008),Vector3(.21,.07,.004),w.mat(Color("817b60"),null,.98));tape.rotation.z=x*.34
  var writing:=Label3D.new();writing.text="Pferde mögen\nkeine Clowns";writing.font=load("res://assets/backstage-v270/Caveat.ttf");writing.font_size=96;writing.pixel_size=.0021;writing.position.z=.012;writing.modulate=Color("302820");writing.outline_size=0;writing.shaded=true;writing.no_depth_test=false;writing.alpha_cut=Label3D.ALPHA_CUT_DISCARD;horse_note.add_child(writing);horse_note.hide()

 var glow:=w.mat(colour);glow.emission_enabled=true;glow.emission=colour;glow.emission_energy_multiplier=1.6
 w.box(root,Vector3(0,3.35,.24),Vector3(1.7,.40,.11),glow)
 w.mounted_sign(root,"red" if index else "green",Vector3(0,3.35,.31),Vector2(1.5,.3))
 # The two cabin pockets are separated; neither intersects the other cabin
 # or the adjacent service passage. The doors remain in their original place.
 for z in [-1.0,-4.8]:
  var x: float=SHIFTS[index] if z< -4. else 0.
  w.box(root,Vector3(x,2.91,z),Vector3(.65,.1,.45),steel)
  var glass:=w.mat(Color("b1beac"));glass.emission_enabled=true;glass.emission=Color("b1beac");glass.emission_energy_multiplier=.7
  w.box(root,Vector3(x,2.85,z),Vector3(.52,.022,.32),glass)
  var light:=OmniLight3D.new();light.position=Vector3(x,2.65,z);light.light_color=Color("c1cbb4");light.light_energy=.65;light.omni_range=3.2;root.add_child(light)
 var lift:=PassageLift.new();root.add_child(lift);lift.build(w,Vector3(SHIFTS[index],0,-9.08));lift.set_floor(floor_number)
 lift.hide()
 floor_displays.append_array(lift.floor_displays)
 w.box(root,Vector3(SHIFTS[index],2.945,-7.51),Vector3(2.85,.27,.20),wall,true)
 lanes.append({"root":root,"hinge":hinge,"body":body,"open":false,"doors":lift.doors,"lift":lift,"path":path})

func _corridor(root: Node3D,path: Array[Vector2],ground: Material,wall: Material,steel: Material,colour: Color) -> void:
 var edges: Array[Vector2]=[]
 for i in range(path.size()):
  var incoming: Vector2=(path[i]-path[maxi(0,i-1)]).normalized() if i>0 else (path[1]-path[0]).normalized()
  var outgoing: Vector2=(path[mini(i+1,path.size()-1)]-path[i]).normalized() if i<path.size()-1 else incoming
  var a:=Vector2(-incoming.y,incoming.x);var b:=Vector2(-outgoing.y,outgoing.x);var miter:=(a+b).normalized()
  edges.append(miter*1.05/maxf(.8,miter.dot(b)))
 for ceiling in [false,true]:
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var height:=3.02 if ceiling else .011;var normal:=Vector3.DOWN if ceiling else Vector3.UP
  for i in range(path.size()-1):
   var a:=path[i]-edges[i];var b:=path[i]+edges[i];var c:=path[i+1]-edges[i+1];var d:=path[i+1]+edges[i+1]
   SurfaceDetails.triangle(tool,Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(c.x,height,c.y),normal)
   SurfaceDetails.triangle(tool,Vector3(b.x,height,b.y),Vector3(d.x,height,d.y),Vector3(c.x,height,c.y),normal)
  tool.generate_tangents()
  var mesh:=MeshInstance3D.new();mesh.name="ContinuousPassageCeiling" if ceiling else "ContinuousPassageFloor";mesh.mesh=tool.commit();mesh.material_override=w.materials.dark if ceiling else ground;root.add_child(mesh)
  var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();mesh.add_child(body);body.add_child(shape);mesh.set_meta("foot_surface","concrete")
 for i in range(path.size()-1):
  var delta:=path[i+1]-path[i];var midpoint: Vector2=(path[i]+path[i+1])*.5
  var segment:=Node3D.new();segment.position=Vector3(midpoint.x,0,midpoint.y);segment.rotation.y=atan2(-delta.x,-delta.y);root.add_child(segment)
  for side in [-1,1]:
   var length:=delta.length()+.12
   var solid:=w.box(segment,Vector3(side,1.5,0),Vector3(.16,3.,length),wall,true);solid.set_meta("architecture_wall",true)
   w.box(segment,Vector3(side*.90,.65,0),Vector3(.025,1.2,length),w.mat(colour,load("res://assets/paint.png"),.87))
   for y in [.15,1.28]:w.box(segment,Vector3(side*.88,y,0),Vector3(.04,.07,length),steel)
   w.tube(segment,Vector3(side*.84,2.7,-length*.5),Vector3(side*.84,2.7,length*.5),.025,w.materials.rust)

func open(red: bool) -> void:
 if red and red_locked:return
 if closing: return
 var index:=1 if red else 0
 if chosen>=0 and chosen!=index: return
 lanes[index].open=true
 lanes[1-index].open=false

func set_red_locked(value: bool) -> void:
 red_locked=value
 if horse_note:horse_note.visible=value
 if value:
  lanes[1].open=false;lanes[1].hinge.rotation.y=0;lanes[1].body.collision_layer=1
  if chosen==1:chosen=-1;closing=false;fired=false

func tick(delta: float, active: bool, player: NightGuard, correct_red: bool, completed: bool) -> void:
 motor.stream_paused=not active
 if not active: return
 if red_locked:lanes[1].open=false
 for i in range(2):
  var lane: Dictionary=lanes[i]
  lane.lift.visible=lane.open and (chosen<0 or chosen==i)
  lane.lift.ticket.tick(delta,lane.lift.visible)
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
   if absf(p.x-SHIFTS[i])<1.23 and p.z< -9.50:
    closing=true;clock=0;motor.position=player.position;motor.play();boarded.emit(bool(i));return
 if closing:
  clock+=delta
  for i in range(2):lanes[chosen].doors[i].position.x=(-1 if i==0 else 1)*lerpf(1.89,.65,smoothstep(0,.72,clock))
  if clock>=.85 and not fired: fired=true;sealed.emit(bool(chosen))

func safe_pose(p: Vector3) -> bool:
 if p.y<-.1 or p.y>2.7:return false
 for lane in lanes:
  var local: Vector3=lane.root.to_local(p)
  var cabin: Node3D=lane.lift.cabin
  var inside:=cabin.to_local(p)
  if absf(inside.x)<1.24 and absf(inside.z)<1.50:return true
  for i in range(lane.path.size()-1):
   var nearest:=Geometry2D.get_closest_point_to_segment(Vector2(local.x,local.z),lane.path[i],lane.path[i+1])
   if nearest.distance_to(Vector2(local.x,local.z))<.85:return true
 return false

func boarding_position() -> Vector3:
 return lanes[chosen].lift.cabin.to_global(Vector3(0,0,.55))

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
 if red_locked:set_red_locked(true)

func snapshot() -> Dictionary:
 return {"red_locked":red_locked,"horse_note":horse_note.visible,"chosen":chosen,"open":[lanes[0].open,lanes[1].open],"closing":closing,"clock":clock,"doors":[lanes[0].doors[0].position.x,lanes[1].doors[0].position.x],"floor":floor_number,"floor_texts":floor_displays.map(func(indicator):return indicator.text)}
