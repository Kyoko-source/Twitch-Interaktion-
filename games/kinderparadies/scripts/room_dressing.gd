class_name RoomDressing
extends RefCounted

static func build(w: PlayWorld) -> void:
 var root:=w.group("RoomDressing")
 # The same stocked furniture is used in both editions, with real shelf boards.
 w.props.reception_shelves.hide()
 for z in [1.4,2.8]: shelf(w,root,Vector3(-9.64,.016,z),PI/2)
 shelf(w,root,Vector3(18.99,.016,-1.65),-PI/2)
 party_sideboard(w,root)
 elevator_landing(w,root)

static func shelf(w: PlayWorld, parent: Node3D, pos: Vector3, yaw: float) -> void:
 var unit:=Node3D.new();unit.name="StockedShelf";unit.position=pos;unit.rotation.y=yaw;parent.add_child(unit)
 var wood:=w.mat(Color("796349"),load("res://assets/wood.png"),.85)
 w.box(unit,Vector3(0,1.04,-.235),Vector3(1.14,2.08,.035),wood)
 for x in [-.57,.57]: w.box(unit,Vector3(x,1.04,0),Vector3(.055,2.08,.5),wood,true)
 for level in [.14,.65,1.16,1.67,2.08]: w.box(unit,Vector3(0,level,0),Vector3(1.2,.055,.51),wood,true)
 for row in range(4):
  var y:=.1675+row*.51
  if row%2==0:
   for col in range(2):
    var x:=-.29+col*.58
    w.box(unit,Vector3(x,y+.12,.0),Vector3(.48,.24,.37),w.materials.dark)
    for k in range(9): w.box(unit,Vector3(x-.22+k*.055,y+.13,.191),Vector3(.027,.24,.018),wood)
    w.box(unit,Vector3(x,y+.24,.0),Vector3(.49,.025,.4),wood)
    for k in range(3):
     var ball:=w.sphere(unit,Vector3(x-.12+k*.12,y+.255,.015),.075,[w.materials.red,w.materials.gold,w.materials.teal][k]);ball.scale.y=.8
  else:
   for k in range(8):
    var h:=.25+sin(k*3.1+row)*.045
    w.box(unit,Vector3(-.45+k*.095,y+h*.5,.02),Vector3(.075,h,.27),[w.materials.teal,w.materials.cream,w.materials.red][k%3])
    for stripe in [.04,h-.045]: w.box(unit,Vector3(-.45+k*.095,y+stripe,.158),Vector3(.062,.012,.008),w.materials.gold)
   for k in range(3): w.box(unit,Vector3(.36,y+.025+k*.04,.02),Vector3(.22,.038,.29),w.materials.cream if k%2 else w.materials.teal)
 unit.set_meta("stocked_shelf",true)

static func party_sideboard(w: PlayWorld, parent: Node3D) -> void:
 var unit:=Node3D.new();unit.name="PartySideboard";unit.position=Vector3(19.12,.016,-3.9);unit.rotation.y=-PI/2;parent.add_child(unit)
 var timber:=w.mat(Color("827057"),load("res://assets/wood.png"),.9)
 for x in [-1.35,1.35]:
  for z in [-.25,.25]: w.box(unit,Vector3(x,.1,z),Vector3(.09,.2,.09),w.materials.dark)
 w.box(unit,Vector3(0,.47,0),Vector3(3,.6,.64),timber,true)
 w.box(unit,Vector3(0,.805,0),Vector3(3.12,.07,.75),timber,true)
 for x in [-1.0,0,1.0]:
  w.box(unit,Vector3(x,.48,.335),Vector3(.95,.53,.035),w.materials.teal)
  w.tube(unit,Vector3(x-.12,.64,.365),Vector3(x+.12,.64,.365),.014,w.materials.rust)
 for k in range(12): w.tube(unit,Vector3(-.94,.847+k*.015,.02),Vector3(-.94,.857+k*.015,.02),.24,w.materials.cream)
 for k in range(4):
  var gift:=w.box(unit,Vector3(-.22+k*.35,.96+(.04 if k%2 else 0),.02),Vector3(.28,.24+(.08 if k%2 else 0),.32),[w.materials.red,w.materials.gold,w.materials.teal][k%3])
  w.box(gift,Vector3(0,0,.163),Vector3(.035,.245+(.08 if k%2 else 0),.008),w.materials.cream)
  w.box(gift,Vector3(0,.123+(.04 if k%2 else 0),0),Vector3(.035,.008,.32),w.materials.cream)
 # Wall board and pennants share a mounting rail, not empty air.
 var fresco:=Node3D.new();fresco.name="TheFourEmptyChairs";fresco.position=Vector3(12.0,2.85,1.485);fresco.rotation.y=PI;parent.add_child(fresco)
 var painting:=MeshInstance3D.new();var canvas:=QuadMesh.new();canvas.size=Vector2(7.6,3.8);painting.mesh=canvas
 var paint:=w.mat(Color("c6beaa"),load("res://assets/creatures/party-fresco-v21.png"),.99)
 paint.normal_enabled=true;paint.normal_texture=w.atmosphere.micro_normal;paint.normal_scale=.16;painting.material_override=paint;fresco.add_child(painting)
 # A cracked toy-theatre cornice is fixed to the wall above the mural.
 w.box(fresco,Vector3(0,1.98,-.005),Vector3(7.8,.10,.12),timber)
 for x in [-3.65,0,3.65]:
  w.box(fresco,Vector3(x,1.88,-.025),Vector3(.08,.28,.11),w.materials.rust)
  w.sphere(fresco,Vector3(x,1.88,.035),.018,w.materials.metal)
 w.tube(parent,Vector3(19.51,3.15,-5.4),Vector3(19.51,3.15,-2.4),.018,w.materials.stitch)
 for k in range(10):
  var flag:=w.box(parent,Vector3(19.50,3.02,-5.26+k*.29),Vector3(.014,.25,.19),w.materials.gold if k%2 else w.materials.red);flag.rotation.x=.11 if k%2 else -.11

static func elevator_landing(w: PlayWorld, parent: Node3D) -> void:
 # A genuine opening through the south wall connects the cabin to the hall.
 var steel:=w.mat(Color("58605c"),load("res://assets/paint.png"),.48,.7)
 for x in [-9.32,-6.68]: w.box(parent,Vector3(x,1.36,17.2),Vector3(.13,2.72,.42),steel,true)
 w.box(parent,Vector3(-8.0,2.72,17.2),Vector3(2.78,.16,.42),steel,true)
 w.box(parent,Vector3(-8.0,.012,17.2),Vector3(2.5,.024,.55),steel)
 for x in [-8.7,-8.3,-7.9,-7.5,-7.1]: w.box(parent,Vector3(x,.027,17.2),Vector3(.018,.006,.48),w.materials.dark)
