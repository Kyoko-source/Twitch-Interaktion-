class_name MechanicalProps
extends Node3D

const ROOT:="res://assets/mechanical-v405/"
const PROMPTS:={"bell":"E · Empfangsklingel drücken","gum":"E · Am leeren Kaugummiautomaten drehen","ticket":"E · Ticketentwerter herunterdrücken"}
var w: PlayWorld
var records: Dictionary={}
var sources: Array[AudioStreamPlayer3D]=[]
var metal: Material
var black: Material
var red: Material
var paused:=true

func build(world: PlayWorld) -> void:
 w=world;name="WorkingMechanicalProps"
 metal=w.craft.service_material(Color("acb4a3"),1)
 black=w.mat(Color("202921"),null,.83)
 red=w.craft.service_material(Color("8c4035"),0)
 _bell();_gum();_ticket()

func body(parent: Node3D,title: String,p: Vector3) -> Node3D:
 var root:=Node3D.new();root.name=title;root.position=p;parent.add_child(root);return root

func lathe(parent: Node3D,profile: Array[Vector2],material: Material) -> MeshInstance3D:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(profile.size()-1):
  for j in range(48):
   var a:=j*TAU/48.;var b:=(j+1)*TAU/48.
   var p:=profile[row];var q:=profile[row+1]
   var normal:=Vector3(cos((a+b)*.5)*(q.y-p.y),p.x-q.x,sin((a+b)*.5)*(q.y-p.y)).normalized()
   var aa:=Vector3(cos(a)*p.x,p.y,sin(a)*p.x);var ab:=Vector3(cos(b)*p.x,p.y,sin(b)*p.x)
   var ba:=Vector3(cos(a)*q.x,q.y,sin(a)*q.x);var bb:=Vector3(cos(b)*q.x,q.y,sin(b)*q.x)
   SurfaceDetails.triangle(st,aa,ba,bb,normal);SurfaceDetails.triangle(st,aa,bb,ab,normal)
 st.generate_normals();st.generate_tangents()
 var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material;parent.add_child(mesh);return mesh

func screw(root: Node3D,p: Vector3) -> void:
 w.tube(root,p,p+Vector3.BACK*.002,.006,metal)
 w.box(root,p+Vector3.BACK*.0025,Vector3(.008,.0015,.001),black)

func register(id: String,root: Node3D,pivot: Node3D,contact: Node3D,p: Vector3,size: Vector3,duration: float) -> void:
 # Interaction layer only: the existing counter owns movement collision.
 var target:=StaticBody3D.new();target.name="MechanicalInteraction";target.collision_layer=8;target.collision_mask=0
 target.set_meta("interaction","mechanical:"+id);root.add_child(target)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.position=p;target.add_child(shape)
 var sound:=AudioStreamPlayer3D.new();sound.name="MechanicalContactSound";sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 sound.stream=load(ROOT+id+".ogg");sound.volume_db=-11 if id=="bell" else -14;sound.unit_size=1.5;sound.max_distance=8.
 contact.add_child(sound);sources.append(sound)
 records[id]={"root":root,"pivot":pivot,"contact":contact,"sound":sound,"rest":pivot.transform,"time":duration,"duration":duration,"count":0,"played":false,"resume":false,"offset":0.,"voice":false}
 sound.finished.connect(func():records[id].voice=false)
 CelebrationTailoring.merge_joint(root)
 CelebrationTailoring.merge_joint(pivot)

func _bell() -> void:
 var root:=body(w.props.counter,"ReceptionServiceBell",Vector3(.23,1.001,-1.13))
 lathe(root,[Vector2(0,0),Vector2(.095,0),Vector2(.103,.009),Vector2(.102,.023),Vector2(.087,.032),Vector2(0,.032)],black)
 var brass:=w.mat(Color("b3a278"),null,.42,.72)
 var profile: Array[Vector2]=[]
 for i in range(25):
  var a:=i*1.46/24.;profile.append(Vector2(.090*cos(a),.031+.074*sin(a)))
 var dome:=lathe(root,profile,brass)
 dome.name="HollowBellDome"
 w.tube(root,Vector3(0,.025,0),Vector3(0,.119,0),.006,metal)
 var button:=body(root,"SpringLoadedBellPlunger",Vector3(0,.121,0))
 lathe(button,[Vector2(0,-.006),Vector2(.020,-.006),Vector2(.024,0),Vector2(.022,.009),Vector2(0,.013)],metal)
 var contact:=body(button,"BellFingerContact",Vector3(0,.014,0))
 register("bell",root,button,contact,Vector3(0,.070,0),Vector3(.23,.15,.23),.65)

func _gum() -> void:
 var root:=body(w.props.counter,"EmptyVintageGumballDispenser",Vector3(-.08,1.001,-1.13));root.rotation.y=PI/2
 lathe(root,[Vector2(0,0),Vector2(.145,0),Vector2(.147,.024),Vector2(.130,.044),Vector2(.108,.080),Vector2(.108,.28),Vector2(.125,.31)],red)
 w.box(root,Vector3(0,.183,.105),Vector3(.134,.166,.025),metal)
 for x in [-.052,.052]:
  for y in [.119,.247]:screw(root,Vector3(x,y,.120))
 w.box(root,Vector3(0,.245,.122),Vector3(.029,.006,.003),black)
 w.box(root,Vector3(0,.075,.118),Vector3(.095,.056,.022),black)
 var flap:=body(root,"EmptyChuteFlap",Vector3(0,.10,.131))
 w.box(flap,Vector3(0,-.023,0),Vector3(.088,.045,.006),metal)
 var crank:=body(root,"RatchetCrank",Vector3(0,.178,.132))
 w.tube(crank,Vector3.ZERO,Vector3.BACK*.024,.023,metal)
 w.box(crank,Vector3(.028,0,.028),Vector3(.070,.022,.020),metal)
 w.tube(crank,Vector3(.055,0,.028),Vector3(.055,0,.065),.012,black)
 var grip:=body(crank,"CrankGripContact",Vector3(.055,0,.068))
 var glass:=w.mat(Color(.63,.73,.64,.23),null,.16)
 glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;glass.cull_mode=BaseMaterial3D.CULL_BACK;glass.metallic=.05
 var globe:=w.sphere(root,Vector3(0,.435,0),.137,glass);globe.name="ScratchedEmptyGlassGlobe";globe.scale.y=1.10
 # Empty through the glass: feed cone and spindle, no fake sweets.
 lathe(root,[Vector2(.115,.315),Vector2(.050,.345),Vector2(.020,.350)],metal)
 w.tube(root,Vector3(0,.345,0),Vector3(0,.565,0),.008,metal)
 lathe(root,[Vector2(.065,.555),Vector2(.077,.567),Vector2(.060,.581),Vector2(.018,.586),Vector2(0,.589)],red)
 for x in [-.06,.06]:w.box(root,Vector3(x,.032,.134),Vector3(.007,.010,.002),w.materials.rust)
 register("gum",root,crank,grip,Vector3(0,.29,.02),Vector3(.30,.59,.32),1.12)
 records.gum.flap=flap

func _ticket() -> void:
 var desk:=w.craft.find_child("CinemaTicketInspection",true,false) as Node3D
 var root:=body(desk,"WorkingTicketValidator",Vector3(.04,.962,-.19));root.rotation.y=PI/2
 w.box(root,Vector3(0,.018,0),Vector3(.16,.036,.24),black)
 for x in [-.064,.064]:
  w.box(root,Vector3(x,.072,-.055),Vector3(.022,.09,.048),metal)
  screw(root,Vector3(x,.072,-.029))
 var pivot:=body(root,"ValidatorHingedHandle",Vector3(0,.104,-.068))
 w.tube(pivot,Vector3(-.076,0,0),Vector3(.076,0,0),.012,metal)
 for x in [-.050,.050]:w.tube(pivot,Vector3(x,0,0),Vector3(x,.061,.149),.012,metal)
 w.tube(pivot,Vector3(-.065,.061,.149),Vector3(.065,.061,.149),.018,black)
 w.box(pivot,Vector3(0,-.018,.083),Vector3(.085,.028,.022),metal)
 w.box(root,Vector3(0,.041,.080),Vector3(.105,.006,.025),metal)
 var ticket:=w.box(root,Vector3(0,.039,.105),Vector3(.09,.0015,.14),w.materials.paper)
 w.box(ticket,Vector3(-.027,.001,.005),Vector3(.013,.001,.12),w.materials.red)
 for i in range(4):w.box(ticket,Vector3(.008,.001,-.025+i*.015),Vector3(.031,.001,.002),black)
 var contact:=body(pivot,"ValidatorPalmContact",Vector3(0,.078,.149))
 register("ticket",root,pivot,contact,Vector3(0,.09,.03),Vector3(.19,.20,.28),.8)

func busy(id: String) -> bool:
 var key:=id.trim_prefix("mechanical:")
 return not records.has(key) or records[key].time<records[key].duration

func interact(id: String) -> bool:
 var key:=id.trim_prefix("mechanical:")
 if busy(id):return false
 var record: Dictionary=records[key]
 record.time=0.;record.count+=1;record.played=false
 return true

func prompt(id: String) -> String:
 return PROMPTS.get(id.trim_prefix("mechanical:"),"")

func tick(delta: float,active: bool) -> void:
 for id in records:
  var record: Dictionary=records[id]
  if not active:
   if not paused and (record.sound.playing or record.voice):
    record.resume=true;record.offset=record.sound.get_playback_position()
   record.sound.stop() # Also cancel a 3D start queued just before pause.
   continue
  if paused and record.resume:
   record.sound.play(record.offset);record.resume=false
  if not active or record.time>=record.duration:continue
  record.time=minf(record.duration,record.time+delta)
  var t: float=record.time/record.duration
  record.pivot.transform=record.rest
  if id=="bell":record.pivot.position.y-=.009*sin(minf(t/.28,1.)*PI)
  elif id=="gum":
   record.pivot.rotation.z=-TAU*smoothstep(0.,.85,t)
   record.flap.rotation.x=-.16*sin(t*PI)*sin(t*TAU*4.)
  else:record.pivot.rotation.x=.43*sin(minf(t/.8,1.)*PI)
  var strike: float=.03 if id=="bell" else .05 if id=="gum" else .24
  if record.time>=strike and not record.played:
   record.sound.play();record.played=true;record.voice=true
  if t>=1.:
   record.pivot.transform=record.rest
   if id=="gum":record.flap.rotation=Vector3.ZERO
 paused=not active

func snapshot() -> Dictionary:
 var data: Dictionary={}
 for id in records:
  var r: Dictionary=records[id]
  data[id]={"count":r.count,"time":r.time,"busy":r.time<r.duration,"paused":paused,"playing":r.sound.playing,"angle":r.pivot.rotation.z if id=="gum" else r.pivot.rotation.x,"point":[r.contact.global_position.x,r.contact.global_position.y,r.contact.global_position.z]}
 return data
