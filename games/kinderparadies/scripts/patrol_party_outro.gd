class_name PatrolPartyOutro
extends RefCounted

const TEST_CODE:="07122000"
const DURATION:=48.0
const SONG_START:=55.25
const PALETTE: Array[Color]=[Color("f4bad1"),Color("b1e1d5"),Color("ffe5a3"),Color("c9c1ee"),Color("aadbec")]
const POSITIONS: Array[Vector3]=[Vector3(8.1,3.8,-10.5),Vector3(8.4,3.7,-7.4),Vector3(9.0,2.5,-.4),Vector3(13.0,2.6,-3.2),Vector3(17.6,3.0,-5.0),Vector3(16.0,3.2,-10.6),Vector3(9.3,3.0,-9.9)]
const TARGETS: Array[Vector3]=[Vector3(16.3,1.8,-6.1),Vector3(9.3,2.4,-3.8),Vector3(16.3,1.5,-6.1),Vector3(17.4,2.5,-.9),Vector3(12.5,1.5,-8.0),Vector3(17.1,1.8,-10.7),Vector3(14.3,2.0,-4.9)]
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
 prior_reflections=w.party.dots.position
 # A separate, reversible stage dresses the real party room. No gameplay
 # materials or shared character resources are modified by the celebration.
 original_environment=w.environment.environment
 environment=original_environment.duplicate();w.environment.environment=environment
 environment.fog_enabled=false;environment.volumetric_fog_enabled=false
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("fff0df");environment.ambient_light_energy=.25
 environment.tonemap_exposure=1.03;environment.adjustment_enabled=false
 # Keep the actual venue, furniture and surfaces. Only the original bloody
 # mascot is replaced by its clean celebration counterpart for this sequence.
 var mascot: Node3D=w.polish.party_mascot.get_parent()
 hidden.append({"node":mascot,"visible":mascot.visible});mascot.hide()
 for light in w.find_children("*","Light3D",true,false):
  lighting.append({"node":light,"energy":light.light_energy,"shadows":light.shadow_enabled})
  if OS.has_feature("web"):light.shadow_enabled=false
  if not w.party.is_ancestor_of(light):light.light_energy*=.6 if light.global_position.x>6.8 and light.global_position.z<1.6 else .15
 _room()
 await g.get_tree().process_frame
 if not _valid():dispose();return
 bunny=CelebrationCast.rabbit(w,root,Vector3(17.4,.08,-.9),3.1,Color("f1d6ad"));bunny.root.name="GiantRabbitWithCola";bunny.yaw=-2.5;bunny.root.rotation.y=bunny.yaw
 cola=_cola(bunny.left)
 await g.get_tree().process_frame
 if not _valid():dispose();return
 var clown:=CelebrationCast.clown(w,root,Vector3(16.3,.016,-6.1));clown.yaw=-1.7;actors.append(clown)
 for spec in [{"p":Vector3(12.5,.016,-8.0),"kind":"hooded","color":PALETTE[3],"yaw":-.7},{"p":Vector3(11.3,.016,-1.25),"kind":"ragged","color":PALETTE[1],"yaw":-2.2},{"p":Vector3(17.3,.016,-4.4),"kind":"split","color":PALETTE[0],"yaw":-1.1},{"p":Vector3(17.1,.216,-10.8),"kind":"hooded","color":PALETTE[4],"yaw":0.0}]:
  var visitor:=CelebrationCast.visitor(w,root,spec.p,spec.kind,spec.color);visitor.yaw=spec.yaw;visitor.root.rotation.y=spec.yaw;actors.append(visitor)
  await g.get_tree().process_frame
  if not _valid():dispose();return
 horse=CelebrationCast.horse(w,root,Vector3(9.3,.016,-3.8));horse.yaw=-.35
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
 # Small additions above the original room, with its real stage, murals,
 # tables, snacks and flooring visible throughout the camera ride.
 for p in [Vector3(10,4.4,-7),Vector3(16.5,4.4,-3),Vector3(14,4.6,-9.5)]:
  var light:=OmniLight3D.new();light.position=p;light.light_color=Color("fff0dc");light.light_energy=1.4;light.omni_range=10;light.shadow_enabled=not OS.has_feature("web") and p.x==10;light.light_size=.12;root.add_child(light)
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
 var desk:=w.mat(Color("8f7055"),load("res://assets/wood.png"),.62);w.box(root,Vector3(17.1,1.13,-10.1),Vector3(2.1,.12,.85),desk)
 for x in [16.2,18.0]:w.box(root,Vector3(x,.67,-10.1),Vector3(.08,.94,.6),w.mat(PALETTE[3]))
 w.box(root,Vector3(17.1,1.24,-10.1),Vector3(1.7,.10,.65),w.mat(Color("675879"),null,.4))
 for x in [16.6,17.6]:
  w.tube(root,Vector3(x,1.30,-10.1),Vector3(x,1.32,-10.1),.22,w.mat(Color("cfbddf"),null,.3))
  w.tube(root,Vector3(x,1.321,-10.1),Vector3(x,1.325,-10.1),.075,w.mat(PALETTE[0]))
 for i in range(7):w.sphere(root,Vector3(16.85+i*.08,1.315,-9.9),.018,w.mat(PALETTE[i%5]))

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
 var obstacles: Array[Dictionary]=[{"p":Vector3(17.4,0,-.9),"r":3.0},{"p":Vector3(9.3,0,-3.8),"r":1.25}]
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
  var wave:=smoothstep(9.,10.,sip_clock)*(1.-smoothstep(11.,12.,sip_clock))
  bunny.left.rotation=Vector3(-2.1*sip,0,.8*sip)
  bunny.right.rotation=Vector3(-1.1*wave,0,-.45*wave+.12*sin(beat*.25))
  bunny.head.rotation=Vector3(.08*sip,sin(clock*.4)*.10,0)
  bunny.leg_r.rotation.x=sin(beat*.5)*.045
  bunny.root.position.y=bunny.origin.y+absf(sin(beat*.5))*.025
  cola.rotation.x=1.1*sip;cola.rotation.z=-.2*sip
 for i in range(actors.size()):
  var a: Dictionary=actors[i];var t: float=beat+i*1.7;var swing:=sin(t*.5)
  var bounce: float=-.025*(.5+.5*sin(t))
  a.root.position=a.origin+Vector3(swing*.065,bounce,0)
  a.root.rotation.y=a.yaw+sin(t*.25)*.15
  a.torso.rotation=Vector3(sin(t*.5)*.022,0,swing*.035)
  a.head.rotation=Vector3(sin(t*.5)*.045,sin(t*.25)*.14,sin(t)*.045)
  if i==4:
   # The DJ actually reaches down to the decks instead of doing the same
   # overhead animation as the guests on the floor.
   a.root.position=a.origin
   a.left.rotation=Vector3(-1.05,.18,-.13);a.right.rotation=Vector3(-1.05,-.18,.13)
   a.elbow_l.rotation.x=-.25+sin(t*.5)*.08;a.elbow_r.rotation.x=-.25+cos(t*.5)*.08
   a.wrist_l.rotation.x=.65;a.wrist_r.rotation.x=.65
  elif i%3==0:
   a.left.rotation=Vector3(-.3+sin(t*.5)*.35,0,-.32)
   a.right.rotation=Vector3(-.5-sin(t*.5)*.35,0,.32)
   a.elbow_l.rotation.x=-.7-.25*cos(t*.5);a.elbow_r.rotation.x=-.7+.25*cos(t*.5)
  elif i%3==1:
   a.left.rotation=Vector3(-.3,0,-.35-.25*sin(t*.5))
   a.right.rotation=Vector3(-.45,0,.7+.45*sin(t*.25))
   a.elbow_l.rotation.x=-.7;a.elbow_r.rotation.x=-.9
  else:
   a.left.rotation=Vector3(-.8+sin(t*.5)*.12,.25,-.22)
   a.right.rotation=Vector3(-.8-sin(t*.5)*.12,-.25,.22)
   a.elbow_l.rotation.x=-.6-.20*sin(t);a.elbow_r.rotation.x=-.6-.20*sin(t)
  _feet(a,t,0. if i==4 else bounce,i==4)
 if not horse.is_empty():
  horse.root.rotation.y=horse.yaw+sin(beat*.25)*.35
  for i in range(horse.skeleton.get_bone_count()):
   var t: float=float(i)/(horse.skeleton.get_bone_count()-1)
   var rest: Transform3D=horse.skeleton.get_bone_rest(i)
   horse.skeleton.set_bone_pose_position(i,rest.origin+Vector3(sin(clock*1.1+t*2.)*.15*t,0,cos(clock*1.2+t*2.)*.09*t))
   horse.skeleton.set_bone_pose_rotation(i,Quaternion(Vector3.FORWARD,sin(clock*1.1+t*2.)*.07*t))
  horse.head.position=Vector3(sin(clock*1.1+2.)*.15,2.38,.25+cos(clock*1.2+2.)*.09)
  horse.head.rotation=Vector3(sin(beat*.5)*.065,0,cos(beat*.5)*.075)
  horse.tail.rotation.z=sin(beat*.25)*.25
  for i in range(horse.legs.size()):horse.legs[i].rotation.x=sin(beat*.5+i*PI*.5)*.10
 for i in range(minis.size()):
  var mini: Dictionary=minis[i];var angle:=clock*.16-i*.42
  mini.root.position=Vector3(13.7+cos(angle)*2.05,.03+absf(sin(beat+i))*.025,-3.8+sin(angle)*1.95)
  mini.root.rotation.y=-angle;mini.left.rotation.x=-1.1;mini.right.rotation.x=-1.1
  mini.leg_l.rotation.x=sin(beat+i)*.20;mini.leg_r.rotation.x=-sin(beat+i)*.20;mini.head.rotation.z=sin(beat*.5+i)*.10
 if is_instance_valid(confetti):
  for i in range(confetti.multimesh.instance_count):
   var p:=Vector3(7.8+fmod(i*1.371,10.7)+sin(clock*.6+i)*.20,6.4-fposmod(clock*.45+i*.23,5.9),-10.5+fmod(i*2.137,10.7))
   confetti.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(clock+i,i*.7,clock*.5+i)),p))
 positions_changed+=1

func _feet(actor: Dictionary,time: float,bounce: float,dj: bool) -> void:
 # Two-bone placement leaves the supporting shoe on the original floor while
 # the other takes a small step. Ankles counter-rotate instead of stiff tilting.
 for side in [-1,1]:
  var suffix: String="l" if side<0 else "r"
  var step:=sin(time*.5+(PI if side<0 else 0.))
  var lift:=maxf(0.,step)*(.045 if not dj else 0.)
  var forward:=step*(.075 if not dj else .008)
  var drop:=.86+bounce-(.13+lift)
  var distance:=clampf(Vector2(drop,forward).length(),.4,.739)
  var flex:=acos(clampf(distance/.74,-1.,1.))
  var hip: float=atan2(-forward,drop)-flex
  actor["leg_"+suffix].rotation.x=hip;actor["knee_"+suffix].rotation.x=2.*flex
  actor["ankle_"+suffix].rotation.x=-hip-2.*flex

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
  if is_instance_valid(item.node):item.node.light_energy=item.energy;item.node.shadow_enabled=item.shadows
 if is_instance_valid(camera) and camera.get_viewport().get_camera_3d()==camera and is_instance_valid(prior) and prior.is_inside_tree():prior.make_current()
 if is_instance_valid(root):root.hide();root.queue_free()
 if is_instance_valid(camera):camera.queue_free()

func snapshot() -> Dictionary:
 return {"party":true,"clock":clock,"finished":finished,"started":started,"camera":is_instance_valid(camera),"camera_position":[camera.position.x,camera.position.y,camera.position.z] if is_instance_valid(camera) else [],"dancers":actors.size()+minis.size()+2,"teddies":minis.size(),"rabbit_cola":is_instance_valid(cola),"dance_updates":positions_changed,"track":"Rolling Acid","party_music":is_instance_valid(w) and w.party.audio.playing,"music_box":is_instance_valid(w) and w.room_horror.music.playing,"clean_stage":is_instance_valid(root) and not disposed}
