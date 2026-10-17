class_name KitchenDressing
extends RefCounted

static func build(w: PlayWorld, parent: Node3D) -> void:
 var steel:=w.mat(Color("59635c"),load("res://assets/paint.png"),.48,.65)
 var enamel:=w.mat(Color("afa78a"),load("res://assets/aged-plaster.png"),.83)
 var grime:=w.mat(Color("49362b"),load("res://assets/wood.png"),.95)
 # Riveted grease duct, ceiling fluorescent fixture and real ventilation slats.
 w.box(parent,Vector3(-14.65,3.29,-19.25),Vector3(2.4,.33,.44),steel)
 for x in [-15.7,-14.9,-14.1]:
  for side in [-1,1]: w.sphere(parent,Vector3(x,3.27,-19.25+side*.23),.018,w.materials.rust)
 w.box(parent,Vector3(-15.2,3.48,-17),Vector3(.23,.1,2.2),steel)
 var diffuser:=w.mat(Color("9ba995"),null,.42);diffuser.emission_enabled=true;diffuser.emission=Color("b7bd9c");diffuser.emission_energy_multiplier=.45
 w.box(parent,Vector3(-15.2,3.415,-17),Vector3(.17,.035,2.0),diffuser)
 w.lamp(Vector3(-15.0,3.25,-16.9),Color("b7bd9c"),.55,5)
 w.box(parent,Vector3(-9.51,2.65,-20.6),Vector3(.05,.68,1.35),w.materials.dark)
 for i in range(10): w.box(parent,Vector3(-9.56,2.36+i*.06,-20.6),Vector3(.07,.025,1.27),steel)
 # Exposed brickwork in a damaged plaster patch on the rear wall.
 w.box(parent,Vector3(-13.2,2.35,-22.425),Vector3(2,.95,.035),grime)
 for row in range(6):
  for col in range(6):
   if (row==0 and col<2) or (row==5 and col>3): continue
   var brick:=w.box(parent,Vector3(-14.05+col*.29+(row%2)*.11,1.95+row*.145,-22.39),Vector3(.265,.125,.045),w.materials.rust if (row+col)%3 else grime);brick.rotation.z=sin(row*col)*.008
 # Mounted records, a worn menu and a small framed kitchen mascot painting.
 w.artwork(parent,Vector3(-10.65,2.25,-22.385),Vector2(1.3,.98),load("res://assets/annex/hygiene-board.png"))
 w.artwork(parent,Vector3(-13.9,2.3,-13.42),Vector2(1.55,1.16),load("res://assets/annex/old-menu.png"),PI)
 w.painting(parent,2,Vector3(-11.1,2.2,-13.42),Vector2(1.65,1.1),PI)
 # A wall cupboard stands open, with real shelves and stored crockery.
 var cupboard:=Node3D.new();cupboard.position=Vector3(-15.8,1.85,-22.15);parent.add_child(cupboard)
 w.box(cupboard,Vector3(0,0,-.18),Vector3(1.5,1.0,.06),enamel)
 for side in [-1,1]: w.box(cupboard,Vector3(side*.73,0,0),Vector3(.05,1,.4),steel)
 for y in [-.49,0,.49]: w.box(cupboard,Vector3(0,y,0),Vector3(1.5,.035,.4),steel)
 var hinge:=Node3D.new();hinge.position=Vector3(-.75,0,.22);hinge.rotation.y=-.65;cupboard.add_child(hinge)
 w.box(hinge,Vector3(.36,0,0),Vector3(.72,.97,.045),enamel);w.box(hinge,Vector3(.63,0,.04),Vector3(.025,.18,.035),w.materials.rust)
 for i in range(6):
  w.tube(cupboard,Vector3(.26,-.43+i*.025,.02),Vector3(.26,-.415+i*.025,.02),.18,enamel)
 for i in range(4): w.tube(cupboard,Vector3(-.4+i*.23,.04,0),Vector3(-.4+i*.23,.29,0),.072,w.materials.teal if i%2 else grime)
 # Hanging pans have hollow-looking dark interiors, rivets and handles.
 w.tube(parent,Vector3(-17.06,2.42,-20.5),Vector3(-17.06,2.42,-17),.024,steel)
 for i in range(4):
  var z:=-20.1+i*.77
  var pan:=w.tube(parent,Vector3(-17.08,2.0,z),Vector3(-16.99,2.0,z),.23,steel)
  w.tube(parent,Vector3(-16.98,2.0,z),Vector3(-16.965,2.0,z),.202,w.materials.dark)
  w.tube(parent,Vector3(-17.035,2.18,z),Vector3(-17.035,2.51,z),.03,grime)
  w.sphere(parent,Vector3(-16.95,2.17,z),.017,w.materials.rust)
 # Copper supply pipe and pressure valve make the wall machinery believable.
 w.tube(parent,Vector3(-9.57,.35,-14.5),Vector3(-9.57,2.75,-14.5),.035,w.materials.rust)
 w.tube(parent,Vector3(-9.57,2.75,-14.5),Vector3(-9.57,2.75,-16.1),.035,w.materials.rust)
 for y in [.6,1.35,2.4]: w.box(parent,Vector3(-9.57,y,-14.5),Vector3(.13,.045,.14),steel)
 var valve:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.1;torus.outer_radius=.13;torus.rings=32;torus.ring_segments=8;valve.mesh=torus;valve.material_override=w.materials.red;valve.position=Vector3(-9.69,1.4,-14.5);valve.rotation.z=PI/2;parent.add_child(valve)
 for i in range(3):
  var a:=i*TAU/3;w.tube(parent,Vector3(-9.69,1.4,-14.5),Vector3(-9.69,1.4+cos(a)*.12,-14.5+sin(a)*.12),.012,steel)
 # A narrow preparation trolley occupies the corner, clear of all walkways.
 var cart:=Node3D.new();cart.position=Vector3(-15.65,0,-20.7);parent.add_child(cart)
 for y in [.22,.89]: w.box(cart,Vector3(0,y,0),Vector3(.72,.035,.95),steel,true)
 for x in [-.32,.32]:
  for z in [-.42,.42]:
   w.tube(cart,Vector3(x,.08,z),Vector3(x,1.0,z),.025,steel)
   w.tube(cart,Vector3(x-.04,.08,z),Vector3(x+.04,.08,z),.075,w.materials.dark)
 for i in range(5):
  var dish:=w.box(cart,Vector3(0,.93+i*.018,0),Vector3(.49,.012,.68),enamel);dish.rotation.y=.035*i
 for i in range(7):
  var can:=w.tube(parent,Vector3(-16.5,1.08,-19.8+i*.27),Vector3(-16.5,1.28,-19.8+i*.27),.075,enamel if i%2 else grime)
  for y in [1.11,1.24]: w.tube(parent,Vector3(-16.5,y,-19.8+i*.27),Vector3(-16.5,y+.008,-19.8+i*.27),.079,steel)
 # Local flies circle the abandoned pot even in a normal reference round.
 var flies:=Node3D.new();flies.name="PotFlies";parent.add_child(flies)
 for i in range(9): w.sphere(flies,Vector3(-13.25,1.65,-19.25),.006,w.materials.dark)
