class_name PatrolPartyOutro
extends RefCounted

const TEST_CODE:="07122000"
const DURATION:=48.0
const SONG_START:=55.25
const PALETTE: Array[Color]=[Color("f4bad1"),Color("b1e1d5"),Color("ffe5a3"),Color("c9c1ee"),Color("aadbec")]
const POSITIONS: Array[Vector3]=[Vector3(8.1,2.7,-10.5),Vector3(8.4,2.0,-7.4),Vector3(9.0,2.0,-.4),Vector3(13.0,2.6,-3.2),Vector3(17.6,3.0,-5.0),Vector3(16.0,3.2,-10.6),Vector3(9.3,3.0,-9.9)]
const TARGETS: Array[Vector3]=[Vector3(13.4,1.8,-5.4),Vector3(9.3,2.4,-4.8),Vector3(12.4,1.5,-5.4),Vector3(17.4,2.5,-.9),Vector3(15.1,1.5,-6.8),Vector3(13.7,1.6,-10.3),Vector3(14.3,2.0,-4.9)]
var g: Node3D
var w: PlayWorld
var owner_credits: Control
var camera: Camera3D
var prior: Camera3D
var root: Node3D
var clock:=0.0
var finished:=false
var disposed:=false
var started:=false
var hidden: Array[Dictionary]=[]
var lighting: Array[Dictionary]=[]
var environment: Environment
var original_environment: Environment
var actors: Array[Dictionary]=[]
var minis: Array[Dictionary]=[]
var bunny: Dictionary
var horse: Dictionary
var cola: Node3D
var confetti: MultiMeshInstance3D
var prior_bus: StringName
var prior_gain:=0.0
var prior_pan:=0.0
var prior_reflections:=Vector3.ZERO
var positions_changed:=0

func _valid() -> bool:
 return not disposed and is_instance_valid(w) and is_instance_valid(g) and g.world==w and g.phase=="ending" and g.end_credits==owner_credits

func build(game: Node3D) -> void:
 g=game;w=g.world;owner_credits=g.end_credits
 prior=g.get_viewport().get_camera_3d()
 root=Node3D.new();root.name="HappylandAfterHoursCelebration";w.add_child(root)
 prior_reflections=w.party.dots.position;w.party.dots.position.y+=.04
 # A separate, reversible stage dresses the real party room. No gameplay
 # materials or shared character resources are modified by the celebration.
 original_environment=w.environment.environment
 environment=original_environment.duplicate();w.environment.environment=environment
 environment.fog_enabled=false;environment.volumetric_fog_enabled=false
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("fff0df");environment.ambient_light_energy=.65
 environment.tonemap_exposure=1.2;environment.adjustment_enabled=false
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if root.is_ancestor_of(mesh) or w.party.is_ancestor_of(mesh):continue
  var middle: Vector3=mesh.global_transform*mesh.get_aabb().get_center()
  if middle.x>6.85 and middle.x<19.8 and middle.z> -12.15 and middle.z<1.5 and middle.y<3.3:
   hidden.append({"node":mesh,"visible":mesh.visible});mesh.hide()
 for light in w.find_children("*","Light3D",true,false):
  lighting.append({"node":light,"energy":light.light_energy})
  if not w.party.is_ancestor_of(light):light.light_energy=0
 _room()
 await g.get_tree().process_frame
 if not _valid():dispose();return
 bunny=CelebrationCast.rabbit(w,root,Vector3(17.4,.08,-.9),3.1,Color("f1d6ad"));bunny.root.name="GiantRabbitWithCola";bunny.yaw=-2.5;bunny.root.rotation.y=bunny.yaw
 cola=_cola(bunny.left)
 await g.get_tree().process_frame
 if not _valid():dispose();return
 var clown:=CelebrationCast.clown(w,root,Vector3(12.4,.08,-5.4));clown.yaw=-2.2;actors.append(clown)
 for spec in [{"p":Vector3(15.1,.08,-6.8),"kind":"hooded","color":PALETTE[3],"yaw":-1.0},{"p":Vector3(11.4,.08,-1.6),"kind":"ragged","color":PALETTE[1],"yaw":-2.7},{"p":Vector3(17.1,.08,-8.6),"kind":"split","color":PALETTE[0],"yaw":-.9},{"p":Vector3(13.7,.08,-10.3),"kind":"hooded","color":PALETTE[4],"yaw":0.0}]:
  var visitor:=CelebrationCast.visitor(w,root,spec.p,spec.kind,spec.color);visitor.yaw=spec.yaw;visitor.root.rotation.y=spec.yaw;actors.append(visitor)
  await g.get_tree().process_frame
  if not _valid():dispose();return
 horse=CelebrationCast.horse(w,root,Vector3(9.3,.08,-4.8));horse.yaw=-.35
 _dj_desk()
 for i in range(5):
  var mini:=CelebrationCast.rabbit(w,root,Vector3.ZERO,.47+i*.025,PALETTE[i]);mini.root.name="TeddyPolonaise%d"%i;minis.append(mini)
 await g.get_tree().process_frame
 if not _valid():dispose();return
 _confetti()
 camera=Camera3D.new();camera.name="HappyEndingPartyCamera";camera.fov=65;camera.near=.08;w.add_child(camera)
 _pose(0.);camera.make_current()
 # Render the prepared cast beneath the opaque credit screen so the first
 # visible party frame does not compile all character materials at once.
 await g.get_tree().process_frame
 if not _valid():dispose()

func _room() -> void:
 var floor:=w.mat(Color("fff3df"),null,.48)
 w.box(root,Vector3(13.3,.028,-5.2),Vector3(12.65,.035,13.0),floor)
 var tiles:=MultiMeshInstance3D.new();tiles.name="CleanPastelPartyFloor";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
 var tile:=BoxMesh.new();tile.size=Vector3(1.13,.014,1.13);mm.mesh=tile;mm.instance_count=11*11
 for z in range(11):
  for x in range(11):
   var index:=z*11+x;mm.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(7.6+x*1.14,.054,-10.9+z*1.14)))
   mm.set_instance_color(index,Color("f5e5d3") if (x+z)%2==0 else Color("bfe0d9"))
 var tile_mat:=w.mat(Color.WHITE,null,.55);tile_mat.vertex_color_use_as_albedo=true;tiles.multimesh=mm;tiles.material_override=tile_mat;root.add_child(tiles)
 for x in [6.99,19.61]:
  w.box(root,Vector3(x,3.65,-5.2),Vector3(.035,7.3,13.),w.mat(Color("fff0da"),null,.93))
  w.box(root,Vector3(x+(.025 if x<10 else -.025),.75,-5.2),Vector3(.015,1.5,13.),w.mat(PALETTE[1],null,.8))
 for z in [-11.73,1.31]:
  w.box(root,Vector3(13.3,3.65,z),Vector3(12.65,7.3,.035),w.mat(PALETTE[0].lightened(.32),null,.94))
  w.box(root,Vector3(13.3,.75,z+(.025 if z<0 else -.025)),Vector3(12.65,1.5,.015),w.mat(PALETTE[3].lightened(.24),null,.83))
 w.text(root,"FEIERABEND!",Vector3(13.3,4.85,-11.68),.46,Color("bf6a8e"))
 w.text(root,"HAPPYLAND",Vector3(13.3,3.65,-11.68),.25,Color("9575ab"))
 for p in [Vector3(10,4.4,-7),Vector3(16.5,4.4,-3),Vector3(14,4.6,-9.5)]:
  var light:=OmniLight3D.new();light.position=p;light.light_color=Color("fff0dc");light.light_energy=2.1;light.omni_range=10;light.shadow_enabled=not OS.has_feature("web") and p.x==10;light.light_size=.12;root.add_child(light)
 for i in range(10):
  var p:=Vector3(7.9+(i%5)*2.7,5.4,-10.9 if i<5 else .5)
  CelebrationCast.oval(w,root,p,Vector3(.28,.36,.28),w.mat(PALETTE[i%5],null,.28,.1))
  w.tube(root,p-Vector3.UP*.35,p-Vector3.UP*1.6,.005,w.mat(Color("e5d9ca")))
  if i>0 and i!=5:w.tube(root,p+Vector3(-2.7,.3,0),p+Vector3(0,.3,0),.012,w.mat(Color("e9dcae")))
 # Little star-shaped ceiling decorations, kept above the camera route.
 for i in range(12):
  var p:=Vector3(8.1+fmod(i*2.15,10.5),5.6+fmod(i*.17,.7),-10.5+fmod(i*2.47,10.6))
  for turn in [0.,PI/3,2*PI/3]:
   var bar:=w.box(root,p,Vector3(.05,.34,.035),w.mat(PALETTE[i%5]));bar.rotation.z=turn

func _cola(parent: Node3D) -> Node3D:
 var drink:=CelebrationCast.joint(parent,"ColaBottleInPaw",Vector3(0,-.32,.06))
 var brown:=w.mat(Color("492e23"),null,.19)
 w.tube(drink,Vector3(0,-.06,0),Vector3(0,.09,0),.052,brown)
 w.sphere(drink,Vector3(0,.09,0),.052,brown)
 w.tube(drink,Vector3(0,.10,0),Vector3(0,.18,0),.022,brown)
 w.tube(drink,Vector3(0,.177,0),Vector3(0,.19,0),.026,w.mat(Color("d7889c"),null,.38))
 w.tube(drink,Vector3(0,-.01,0),Vector3(0,.06,0),.053,w.mat(Color("ef9bac"),null,.7))
 w.text(drink,"COLA",Vector3(0,.025,.054),.032,Color("fff8ee"))
 return drink

func _dj_desk() -> void:
 var desk:=w.mat(Color("eadac0"),null,.5);w.box(root,Vector3(13.7,.93,-9.7),Vector3(2.1,.12,.85),desk)
 for x in [12.8,14.6]:w.box(root,Vector3(x,.47,-9.7),Vector3(.08,.94,.6),w.mat(PALETTE[3]))
 w.box(root,Vector3(13.7,1.04,-9.7),Vector3(1.7,.10,.65),w.mat(Color("675879"),null,.4))
 for x in [13.2,14.2]:
  w.tube(root,Vector3(x,1.10,-9.7),Vector3(x,1.12,-9.7),.22,w.mat(Color("cfbddf"),null,.3))
  w.tube(root,Vector3(x,1.121,-9.7),Vector3(x,1.125,-9.7),.075,w.mat(PALETTE[0]))
 for i in range(7):w.sphere(root,Vector3(13.45+i*.08,1.115,-9.5),.018,w.mat(PALETTE[i%5]))

func _confetti() -> void:
 confetti=MultiMeshInstance3D.new();confetti.name="PastelConfetti";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
 var paper:=QuadMesh.new();paper.size=Vector2(.045,.085);mm.mesh=paper;mm.instance_count=130
 var material:=w.mat(Color.WHITE,null,.9);material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 confetti.multimesh=mm;confetti.material_override=material;confetti.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(confetti)
 for i in range(mm.instance_count):mm.set_instance_color(i,PALETTE[i%5])

func start() -> void:
 if disposed or started:return
 started=true;camera.make_current()
 for source in w.find_children("*","AudioStreamPlayer",true,false)+w.find_children("*","AudioStreamPlayer3D",true,false):
  source.stop();source.stream_paused=true
 prior_bus=w.party.audio.bus;prior_gain=w.party.audio.volume_db;prior_pan=w.party.audio.panning_strength
 w.party.audio.bus="Master";w.party.audio.panning_strength=0;w.party.set_enabled(true)
 w.party.audio.stream_paused=false;w.party.audio.seek(SONG_START);w.party.audio.volume_db=-9
 g.menu_music.stop();g.room_audio.stop();g.effect.stop()

func _spline(points: Array[Vector3],amount: float) -> Vector3:
 var index:=mini(int(amount),points.size()-2);var t:=amount-index
 var a:=points[maxi(0,index-1)];var b:=points[index];var c:=points[index+1];var d:=points[mini(points.size()-1,index+2)]
 return .5*((b*2)+(-a+c)*t+(a*2-b*5+c*4-d)*t*t+(-a+b*3-c*3+d)*t*t*t)

func _camera_point(point: Vector3) -> Vector3:
 # Keep the continuous dolly outside the actual cast and the DJ desk, also
 # between the authored keys rather than checking only the still viewpoints.
 var obstacles: Array[Dictionary]=[{"p":Vector3(17.4,0,-.9),"r":3.0},{"p":Vector3(9.3,0,-4.8),"r":1.25}]
 for actor in actors:obstacles.append({"p":actor.origin,"r":1.3})
 for obstacle in obstacles:
  var offset:=Vector2(point.x-obstacle.p.x,point.z-obstacle.p.z)
  if offset.length()<obstacle.r:
   var normal:=offset.normalized() if offset.length()>.001 else Vector2(0,1)
   point.x=obstacle.p.x+normal.x*obstacle.r;point.z=obstacle.p.z+normal.y*obstacle.r
 return point

func _pose(delta: float) -> void:
 var beat: float=clock*TAU*(146.5/60.)
 var phase:=clampf(clock/(DURATION-3.),0,.9999)*(POSITIONS.size()-1)
 if is_instance_valid(camera):camera.position=_camera_point(_spline(POSITIONS,phase));camera.look_at(_spline(TARGETS,phase));camera.fov=lerpf(65,60,smoothstep(0.,DURATION,clock))
 if not bunny.is_empty():
  var sip_clock:=fposmod(clock,12.);var sip:=smoothstep(2.,4.,sip_clock)*(1.-smoothstep(8.,10.,sip_clock))
  bunny.left.rotation=Vector3(-2.1*sip,0,.8*sip);bunny.right.rotation.z=.12*sin(beat*.25)
  bunny.head.rotation.x=.08*sip;bunny.root.position.y=bunny.origin.y+absf(sin(beat*.5))*.035
  cola.rotation.x=1.1*sip;cola.rotation.z=-.2*sip
 for i in range(actors.size()):
  var a: Dictionary=actors[i];var t: float=beat+i*1.7;var swing:=sin(t*.5)
  a.root.position=a.origin+Vector3(swing*.12,absf(sin(t))*.06,cos(t*.5)*.06)
  a.root.rotation=Vector3(sin(t*.5)*.045,a.yaw+sin(t*.25)*.24,swing*.09)
  a.head.rotation.z=sin(t)*.09
  a.left.rotation=Vector3(-.65+sin(t*.5)*.55,0,-.60+cos(t*.5)*.34)
  a.right.rotation=Vector3(-.65-sin(t*.5)*.55,0,.60-cos(t*.5)*.34)
  a.leg_l.rotation.x=sin(t*.5)*.30;a.leg_r.rotation.x=-sin(t*.5)*.30
  if a.has("elbow_l"):
   a.elbow_l.rotation.x=-.6-absf(sin(t*.5))*.7;a.elbow_r.rotation.x=-.6-absf(cos(t*.5))*.7
   a.knee_l.rotation.x=absf(sin(t*.5))*.38;a.knee_r.rotation.x=absf(cos(t*.5))*.38
 if not horse.is_empty():
  horse.root.rotation.y=horse.yaw+sin(beat*.25)*.35
  for i in range(horse.links.size()):
   var a:=Vector3(sin(clock*1.1+i*.17)*.18,.52+i*.1,cos(clock*1.3+i*.14)*.13)
   var b:=Vector3(sin(clock*1.1+(i+1)*.17)*.18,.52+(i+1)*.1,cos(clock*1.3+(i+1)*.14)*.13)
   HorrorFigures.link(horse.links[i],a,b)
  horse.head.position=Vector3(sin(clock*1.1+20*.17)*.18,2.52,cos(clock*1.3+20*.14)*.13)
  horse.head.rotation=Vector3(sin(beat*.5)*.13,0,cos(beat*.5)*.16)
 for i in range(minis.size()):
  var mini: Dictionary=minis[i];var angle:=clock*.16-i*.42
  mini.root.position=Vector3(13.7+cos(angle)*2.,.08+absf(sin(beat+i))*.055,-4.2+sin(angle)*1.7)
  mini.root.rotation.y=-angle;mini.left.rotation.x=-1.1;mini.right.rotation.x=-1.1
  mini.leg_l.rotation.x=sin(beat+i)*.20;mini.leg_r.rotation.x=-sin(beat+i)*.20;mini.head.rotation.z=sin(beat*.5+i)*.10
 if is_instance_valid(confetti):
  for i in range(confetti.multimesh.instance_count):
   var p:=Vector3(7.8+fmod(i*1.371,10.7)+sin(clock*.6+i)*.20,6.4-fposmod(clock*.45+i*.23,5.9),-10.5+fmod(i*2.137,10.7))
   confetti.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(clock+i,i*.7,clock*.5+i)),p))
 positions_changed+=1

func tick(delta: float) -> void:
 if disposed or finished or not started:return
 clock=minf(clock+delta,DURATION);_pose(delta)
 # Master gain still follows the user's volume setting. Room acoustics do not
 # attenuate this music according to the parked, inactive player capsule.
 w.party.audio.volume_db=-9-45*smoothstep(DURATION-3.,DURATION,clock)
 finished=clock>=DURATION

func shade_alpha() -> float:
 return maxf(1.-smoothstep(0.,1.6,clock),smoothstep(DURATION-2.,DURATION,clock))

func dispose() -> void:
 if disposed:return
 disposed=true
 if is_instance_valid(w):
  w.party.set_enabled(false)
  w.party.dots.position=prior_reflections
  if started:w.party.audio.bus=prior_bus;w.party.audio.volume_db=prior_gain;w.party.audio.panning_strength=prior_pan
  w.environment.environment=original_environment
 for item in hidden:
  if is_instance_valid(item.node):item.node.visible=item.visible
 for item in lighting:
  if is_instance_valid(item.node):item.node.light_energy=item.energy
 if is_instance_valid(camera) and camera.get_viewport().get_camera_3d()==camera and is_instance_valid(prior) and prior.is_inside_tree():prior.make_current()
 if is_instance_valid(root):root.hide();root.queue_free()
 if is_instance_valid(camera):camera.queue_free()

func snapshot() -> Dictionary:
 return {"party":true,"clock":clock,"finished":finished,"started":started,"camera":is_instance_valid(camera),"camera_position":[camera.position.x,camera.position.y,camera.position.z] if is_instance_valid(camera) else [],"dancers":actors.size()+minis.size()+2,"teddies":minis.size(),"rabbit_cola":is_instance_valid(cola),"dance_updates":positions_changed,"track":"Rolling Acid","party_music":is_instance_valid(w) and w.party.audio.playing,"music_box":is_instance_valid(w) and w.room_horror.music.playing,"clean_stage":is_instance_valid(root) and not disposed}
