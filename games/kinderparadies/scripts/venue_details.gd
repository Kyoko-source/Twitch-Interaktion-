class_name VenueDetails
extends Node3D

var w: PlayWorld
var count:=0
var solid_bounds: Array[AABB]=[]
var metal: Material
var paper: Material
var red: Material

func build(world: PlayWorld) -> void:
 w=world;name="LivedInHappyland";set_meta("environment_dressing",true)
 metal=w.revamp.steel;paper=w.mat(Color("b2a27e"),load("res://assets/paint.png"),.97)
 red=w.revamp.paint(Color("63372e"),.15,.71)
 _cinema();_arcade();_hall()
 for shape in find_children("*","CollisionShape3D",true,false):
  if shape.shape:solid_bounds.append(shape.global_transform*shape.shape.get_debug_mesh().get_aabb())

func box(parent: Node3D,p: Vector3,s: Vector3,m: Material,solid: bool=false) -> MeshInstance3D:
 count+=1;return w.box(parent,p,s,m,solid)

func text(parent: Node3D,words: String,p: Vector3,height: float,color: Color,yaw: float=0) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var letters:=TextMesh.new();letters.set_message_translation(false);letters.font=load("res://assets/Oswald.ttf");letters.text=words;letters.font_size=48;letters.pixel_size=height/48.;letters.depth=.0003
 mesh.mesh=letters;mesh.material_override=w.mat(color,null,.9);mesh.position=p;mesh.rotation.y=yaw;parent.add_child(mesh);count+=1
 mesh.add_to_group("caption_signs");mesh.set_meta("sign_text",words);mesh.set_meta("sign_rect",Vector2(maxf(height,letters.get_aabb().size.x),height*1.6));return mesh

func ring(parent: Node3D,p: Vector3,r: float,thickness: float,m: Material,rotation_value: Vector3=Vector3.ZERO) -> MeshInstance3D:
 var o:=MeshInstance3D.new();var t:=TorusMesh.new();t.inner_radius=r-thickness;t.outer_radius=r;t.rings=24;t.ring_segments=8;o.mesh=t;o.material_override=m;o.position=p;o.rotation=rotation_value;parent.add_child(o);count+=1;return o

func _cinema() -> void:
 var root:=Node3D.new();root.name="CinemaShowHistory";root.position=ServiceAnnex.OFFSET;add_child(root)
 # Seat backs, cups and numbers follow the actual transformed seat nodes.
 var index:=0
 w.artwork(root,Vector3(-1.3,2.15,-22.39),Vector2(2.45,1.35),load("res://assets/reception-v2120/birthday-memories.png"),0,2)
 text(root,"LETZTE VORSTELLUNG",Vector3(-1.3,2.99,-22.35),.17,Color("baa781"))
 text(root,"EIN TAG IM HAPPYLAND",Vector3(-1.3,1.32,-22.35),.10,Color("a29b83"))
 for seat in w.annex.get_children():
  if not seat.get_meta("cinema_seat",false):continue
  index+=1
  for side in [-1,1]:
   var holder:=SurfaceDetails.vessel(seat,Vector3(side*.37,.731,.17),.048,.062,.050,.008,w.materials.dark,w.materials.dark,"RecessedCupHolderL" if side<0 else "RecessedCupHolderR");count+=1
   if index%7==0 and side==1:
    var cup:=SurfaceDetails.vessel(holder,Vector3(0,.012,0),.14,.044,.032,.003,paper,w.materials.dark,"AbandonedCinemaCup");count+=1
    ring(cup,Vector3(0,.14,0),.044,.005,red)
    w.tube(cup,Vector3(.01,.09,0),Vector3(.012,.23,.006),.003,red)
  box(seat,Vector3(0,1.04,-.375),Vector3(.13,.055,.009),metal)
  text(seat,"%02d"%index,Vector3(0,1.021,-.382),.035,Color("c6b48c"),PI)
  # Back pocket is shallow cloth against the rear, never an aisle collision.
  box(seat,Vector3(0,.67,-.361),Vector3(.35,.21,.018),red)
  if index%5==0:box(seat,Vector3(.02,.79,-.373),Vector3(.20,.10,.004),paper)
 # Continuous shallow skirtings and anchored low aisle lights.
 for z in [-22.33,-13.18]:
  box(root,Vector3(-1.32,.12,z),Vector3(9.72,.20,.035),w.materials.dark)
  for x in [-5.65,-2.9,-.15,2.6]:
   var socket:=box(root,Vector3(x,.26,z+(.03 if z< -20 else -.03)),Vector3(.17,.10,.045),metal)
   var glow:=w.mat(Color("9f6d3c"),null,.64);glow.emission_enabled=true;glow.emission=Color("684a28");glow.emission_energy_multiplier=.18
   box(socket,Vector3(0,0,.026 if z< -20 else -.026),Vector3(.12,.035,.008),glow)
 # Waste collection belongs behind the last row, away from the entrance aisle.
 var bin:=Node3D.new();bin.name="CinemaWasteStation";bin.position=Vector3(-5.70,0,-21.83);root.add_child(bin)
 SurfaceDetails.vessel(bin,Vector3(0,.015,0),.64,.24,.20,.025,metal,w.materials.dark,"LinedCinemaBin");count+=1
 ring(bin,Vector3(0,.66,0),.24,.035,w.materials.dark)
 for i in range(6):
  var ticket:=box(root,Vector3(-5.4+i*.11,.035,-21.8+sin(i*2.)*.24),Vector3(.13,.005,.07),paper);ticket.rotation.y=i*.83;ticket.set_meta("cinema_litter",true)
 # Small litter clusters follow seat bases, leaving newspaper and all aisles open.
 for i in range(34):
  var x: float=-4.7+fmod(i*1.41,4.9);var z: float=-21.20+fmod(i*1.93,6.8)
  if absf(z+17.65)<.88:continue
  if Vector2(x-1.2,z+19.9).length()<.8:continue
  if i%4==0:
   var wrapper:=box(root,Vector3(x,.035,z),Vector3(.11,.009,.07),red if i%2 else paper);wrapper.rotation=Vector3(.04,i*.72,.08);wrapper.set_meta("cinema_litter",true)
  else:
   var kernel:=w.sphere(root,Vector3(x,.032,z),.017,paper);kernel.scale=Vector3(1.3,.75,.86);kernel.set_meta("cinema_litter",true);count+=1
 # An attached speaker system, with grilles instead of featureless wall cubes.
 for z in [-21.90,-13.55]:
  var speaker:=Node3D.new();speaker.position=Vector3(2.95,2.88,z);root.add_child(speaker)
  box(speaker,Vector3.ZERO,Vector3(.36,.49,.25),w.materials.dark)
  for row in range(9):box(speaker,Vector3(0,-.19+row*.045,.130),Vector3(.28,.012,.012),metal)
  box(speaker,Vector3(0,.21,-.09),Vector3(.12,.13,.22),metal)
 # Film tins and a service notebook sit on the existing projection table.
 var desk:=w.annex.find_child("ProjectionWorktable",true,false)
 if desk:
  for i in range(3):
   w.tube(desk,Vector3(.30,.86+i*.035,.05),Vector3(.30,.89+i*.035,.05),.135,metal);count+=1
   ring(desk,Vector3(.30,.891+i*.035,.05),.128,.009,w.materials.rust)
  var book:=box(desk,Vector3(.08,.88,-.27),Vector3(.18,.026,.24),red);book.rotation.y=.13
  box(book,Vector3(0,.014,0),Vector3(.15,.002,.20),paper)
 _projector(root)

func _projector(parent: Node3D) -> void:
 var root:=Node3D.new();root.name="ServicedProjectionApparatus";root.position=Vector3(-5.4,2.98,-17.7);parent.add_child(root)
 for x in [-.22,.22]:
  box(root,Vector3(x,0,-.235),Vector3(.035,.35,.025),metal)
 for row in range(8):box(root,Vector3(-.10,-.11+row*.033,.231),Vector3(.25,.010,.013),w.materials.dark)
 for x in [-.13,.08]:
  w.tube(root,Vector3(x,-.08,.23),Vector3(x,-.08,.27),.033,w.materials.dark)
  box(root,Vector3(x,-.08,.272),Vector3(.006,.043,.004),paper)
 for x in [.35,.40,.45]:
  var lens:=ring(root,Vector3(x,0,0),.09,.015,metal,Vector3(0,0,PI/2));lens.name="FocusLensRing"
 w.tube(root,Vector3(.44,0,0),Vector3(.47,0,0),.069,w.mat(Color("183132"),null,.18,.2))
 # Power cable ends at a real ceiling socket, beside the steel mounting rod.
 w.tube(root,Vector3(-.24,.13,-.13),Vector3(-.28,.45,-.13),.009,w.materials.dark)
 box(root,Vector3(-.28,.53,-.13),Vector3(.12,.025,.13),metal)

func _arcade() -> void:
 var root:=Node3D.new();root.name="ArcadeLounge";add_child(root)
 var rug:=box(root,Vector3(8.4,.025,15.30),Vector3(7.0,.008,2.30),w.revamp.pbr("dirty_carpet",Color("3c514b"),1.7));rug.name="WornArcadeFloorInset"
 for x in [4.9,11.9]:box(root,Vector3(x,.031,15.30),Vector3(.045,.004,2.30),w.materials.gold)
 # All cabinets share a service rail, front clearance and a low light canopy.
 box(root,Vector3(8.4,2.55,16.61),Vector3(7.2,.17,.56),red)
 for x in [4.9,8.4,11.9]:
  box(root,Vector3(x,2.83,16.80),Vector3(.055,.49,.055),metal)
  box(root,Vector3(x,3.07,16.91),Vector3(.15,.08,.12),metal)
 text(root,"HAPPYLAND  /  SPIELLOUNGE",Vector3(8.4,2.95,16.95),.21,Color("b09b6a"),PI)
 for x in [6.,7.5,9.5]:
  var light:=box(root,Vector3(x,2.45,16.59),Vector3(.35,.045,.31),metal)
  box(light,Vector3(0,-.029,0),Vector3(.29,.01,.25),w.materials.cream)
 box(root,Vector3(8.4,.09,16.82),Vector3(7.0,.12,.10),metal)
 var change:=Node3D.new();change.name="ArcadeTokenExchange";change.position=Vector3(11.2,0,16.38);change.rotation.y=PI;root.add_child(change)
 box(change,Vector3(0,.73,0),Vector3(.64,1.46,.54),red,true)
 box(change,Vector3(0,1.08,.28),Vector3(.50,.39,.022),metal)
 text(change,"JETONS",Vector3(0,1.33,.292),.074,Color("c9b987"))
 for x in [-.14,.14]:
  box(change,Vector3(x,1.09,.299),Vector3(.035,.11,.015),w.materials.dark)
  ring(change,Vector3(x,.91,.30),.037,.006,metal,Vector3(PI/2,0,0))
 box(change,Vector3(0,.50,.29),Vector3(.40,.18,.06),w.materials.dark)
 box(change,Vector3(0,.411,.34),Vector3(.41,.025,.16),metal)
 for i in range(7):w.tube(root,Vector3(10.45+i*.05,.036,15.8+sin(i)*.15),Vector3(10.45+i*.05,.040,15.8+sin(i)*.15),.019,metal);count+=1
 for i in range(8):
  var ticket:=box(root,Vector3(6.6+i*.27,.041,15.96+sin(i*.8)*.17),Vector3(.17,.003,.073),paper);ticket.rotation.y=i*.3
  box(ticket,Vector3(0,.002,0),Vector3(.026,.001,.055),red)

func _hall() -> void:
 var root:=Node3D.new();root.name="HallBuildingHistory";add_child(root)
 # Main supply duct is above the south concourse, clear of tubes and play towers.
 box(root,Vector3(2.4,6.98,16.15),Vector3(15.0,.37,.48),metal)
 for x in [-4.7,-2.0,.7,3.4,6.1,8.8]:
  box(root,Vector3(x,6.98,16.15),Vector3(.045,.41,.53),w.materials.dark)
  for z in [15.92,16.38]:
   w.tube(root,Vector3(x,7.19,z),Vector3(x,7.33,z),.012,metal)
 for x in [-2.8,3.2,8.5]:
  box(root,Vector3(x,6.75,16.15),Vector3(.80,.08,.43),w.materials.dark)
  for i in range(10):box(root,Vector3(x-.34+i*.075,6.702,16.15),Vector3(.026,.015,.34),metal)
 # An old child-height measuring board gives the empty west wall a human scale.
 var board:=box(root,Vector3(-9.91,1.0,11.0),Vector3(.045,1.8,.42),paper)
 for i in range(15):box(root,Vector3(-9.881,.24+i*.105,11.0),Vector3(.006,.006,.16 if i%5==0 else .08),red)
 text(root,"WIE GROSS BIST DU?",Vector3(-9.874,2.06,11.0),.075,Color("463e30"),PI/2)
 # Forgotten shoe bags and cleaning traces stay against walls, not door mouths.
 for p in [Vector3(-9.45,.016,11.4),Vector3(18.86,.016,14.2)]:
  var bag:=box(root,p+Vector3(0,.11,0),Vector3(.36,.22,.27),red)
  for side in [-1,1]:w.tube(bag,Vector3(side*.10,.12,-.08),Vector3(side*.10,.23,.0),.006,w.materials.stitch)
 for i in range(26):
  var x: float=-4.5+fmod(i*3.83,11.1);var z: float=10.95+fmod(i*1.41,1.6)
  if x> -2.6 and x<2.4:continue
  var scrap:=box(root,Vector3(x,.027,z),Vector3(.09,.004,.065),paper if i%3 else red);scrap.rotation.y=i*.63

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.27,.08,-.27),Vector3(.54,1.62,.54))
 for obstacle in solid_bounds:
  if guard.intersects(obstacle):return false
 return true

static func extinguisher(w: PlayWorld,parent: Node3D) -> void:
 var red: Material=w.revamp.paint(Color("7b3029"),.25,.48) if w.revamp else w.mat(Color("81382f"),load("res://assets/paint.png"),.58,.24)
 var steel: Material=w.materials.metal;var rubber: Material=w.materials.dark
 w.box(parent,Vector3(-.135,.27,0),Vector3(.035,.57,.18),steel)
 for y in [.05,.47]:
  w.box(parent,Vector3(-.06,y,0),Vector3(.16,.025,.14),steel)
  for z in [-.056,.056]:w.sphere(parent,Vector3(-.112,y,z),.011,steel)
 w.tube(parent,Vector3(0,.045,0),Vector3(0,.46,0),.105,red)
 var shoulder:=w.sphere(parent,Vector3(0,.46,0),.105,red);shoulder.scale.y=.55
 var bottom:=w.sphere(parent,Vector3(0,.047,0),.105,red);bottom.scale.y=.40
 w.tube(parent,Vector3(0,.47,0),Vector3(0,.59,0),.027,steel)
 for y in [.575,.615]:w.box(parent,Vector3(0,y,.05),Vector3(.045,.019,.18),rubber)
 w.tube(parent,Vector3(.015,.57,-.045),Vector3(.08,.57,-.045),.029,steel)
 var gauge:=w.sphere(parent,Vector3(.085,.57,-.045),.029,w.materials.cream);gauge.scale.x=.2
 w.tube(parent,Vector3(.092,.56,-.052),Vector3(.092,.58,-.038),.002,w.materials.red)
 var hose:=PackedVector3Array([Vector3(0,.55,-.04),Vector3(0,.53,-.15),Vector3(0,.26,-.16),Vector3(.02,.16,-.12)])
 for i in range(hose.size()-1):w.tube(parent,hose[i],hose[i+1],.014,rubber)
 w.box(parent,Vector3(.106,.28,0),Vector3(.006,.20,.105),w.materials.cream)
 for y in [.23,.25,.27,.29,.31,.34]:w.box(parent,Vector3(.110,y,0),Vector3(.003,.004,.074),rubber)

static func work_light(w: PlayWorld,parent: Node3D) -> void:
 var frame:=Node3D.new();frame.name="BracedInspectionLamp";frame.position=Vector3(18.6,0,10.6);frame.rotation.y=-PI/2;parent.add_child(frame)
 var steel: Material=w.materials.metal;var dark: Material=w.materials.dark
 for side in [-1,1]:
  w.tube(frame,Vector3(side*.32,.025,-.21),Vector3(side*.32,.025,.21),.025,dark)
  w.tube(frame,Vector3(side*.32,.03,0),Vector3(side*.16,.72,0),.024,steel)
 w.box(frame,Vector3(0,.89,0),Vector3(.40,.33,.17),steel)
 w.box(frame,Vector3(0,.89,.091),Vector3(.34,.26,.015),w.materials.cream)
 for x in [-.12,-.04,.04,.12]:w.tube(frame,Vector3(x,.77,.11),Vector3(x,1.01,.11),.006,dark)
 for y in [.80,.89,.98]:w.tube(frame,Vector3(-.17,y,.11),Vector3(.17,y,.11),.006,dark)
 w.lamp(Vector3(18.35,1.0,10.6),Color("a7b498"),.65,7)
