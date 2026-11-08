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
   book_row(w,unit,y,-.535,.535,int(absf(pos.x)*131+absf(pos.z)*57)+row*17)
 unit.set_meta("stocked_shelf",true)
 unit.set_meta("furniture_volume",AABB(Vector3(-.63,.02,-.28),Vector3(1.26,2.12,.57)))

static func _part(w: PlayWorld,parent: Node3D,frame: Transform3D,p: Vector3,s: Vector3,m: Material) -> void:
 var mesh:=w.box(parent,Vector3.ZERO,s,m);mesh.transform=frame*Transform3D(Basis.IDENTITY,p)

# A real hardback: two boards, a spine, a recessed page block that shows
# between the boards, raised bands and sometimes a paper title label.
static func book(w: PlayWorld,parent: Node3D,frame: Transform3D,size: Vector3,cover: Material,band: Material,label: bool) -> void:
 var t:=size.x;var h:=size.y;var d:=size.z
 for side in [-1.,1.]:_part(w,parent,frame,Vector3(side*(t*.5-.0016),0,0),Vector3(.0032,h,d),cover)
 _part(w,parent,frame,Vector3(0,0,d*.5-.0022),Vector3(t,h,.0044),cover)
 _part(w,parent,frame,Vector3(0,-.002,-.003),Vector3(t-.006,h-.012,d-.008),w.materials.paper)
 for y in [h*.5-.028,-h*.5+.03]:_part(w,parent,frame,Vector3(0,y,d*.5+.0005),Vector3(t+.0008,.005,.0046),band)
 if label:_part(w,parent,frame,Vector3(0,h*.14,d*.5+.0008),Vector3(t*.62,minf(.045,h*.18),.0042),w.materials.paper)

static func book_row(w: PlayWorld,unit: Node3D,y: float,x0: float,x1: float,seed_value: int) -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var row:=Node3D.new();row.name="BookRow";unit.add_child(row)
 var colours:=[Color("5a2621"),Color("1f2f45"),Color("2f4430"),Color("5b4529"),Color("6e5426"),Color("3a2a38"),Color("6a6656"),Color("40251c")]
 var covers: Array[Material]=[];var bands: Array[Material]=[]
 for c in colours:
  covers.append(w.mat(c,load("res://assets/paint.png"),.82));bands.append(w.mat(c.darkened(.45) if rng.randf()<.6 else Color("8f7a43"),null,.6))
 var x:=x0
 var stack_left:=x1-.25 if rng.randf()<.55 else x1
 while x<stack_left-.06:
  var t:=rng.randf_range(.022,.055);var h:=rng.randf_range(.19,.31);var d:=rng.randf_range(.16,.22)
  if x+t>stack_left-.01:break
  var k:=rng.randi_range(0,colours.size()-1)
  book(w,row,Transform3D(Basis.IDENTITY,Vector3(x+t*.5,y+h*.5,.2-d*.5)),Vector3(t,h,d),covers[k],bands[k],rng.randf()<.35)
  x+=t+rng.randf_range(0,.003)
  # A gap now and then, with the next book slumped against its neighbour.
  if rng.randf()<.12 and x<stack_left-.14:
   var lean:=rng.randf_range(.18,.38);var lh:=rng.randf_range(.2,.28);var lt:=rng.randf_range(.025,.045)
   # Rests on its bottom-left corner; the top-left edge touches the neighbour.
   var pivot:=Vector3(x+lh*sin(lean),y,0)
   var frame:=Transform3D(Basis(Vector3.BACK,lean),pivot)*Transform3D(Basis.IDENTITY,Vector3(lt*.5,lh*.5,.2-.095))
   k=rng.randi_range(0,colours.size()-1)
   book(w,row,frame,Vector3(lt,lh,.19),covers[k],bands[k],false)
   x=pivot.x+lt*cos(lean)+.004
 if stack_left<x1:
  # Books lying flat on top of each other, spines out, slightly askew.
  var level:=y
  for i in range(rng.randi_range(3,5)):
   var t:=rng.randf_range(.026,.05);var h:=rng.randf_range(.19,.24);var d:=rng.randf_range(.16,.2)
   var frame:=Transform3D(Basis(Vector3.UP,rng.randf_range(-.12,.12))*Basis(Vector3.BACK,PI*.5),Vector3(stack_left+.12,level+t*.5,.2-d*.5))
   var k:=rng.randi_range(0,colours.size()-1)
   book(w,row,frame,Vector3(t,h,d),covers[k],bands[k],rng.randf()<.3)
   level+=t
 CelebrationTailoring.merge_joint(row)

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
  WrappedPresent.build(w,unit,Vector3(-.22+k*.35,.96+(.04 if k%2 else 0),.02),Vector3(.28,.24+(.08 if k%2 else 0),.32),k)

 # Wall board and pennants share a mounting rail, not empty air.
 var fresco:=Node3D.new();fresco.name="TheFourEmptyChairs";fresco.position=Vector3(12.0,3.95,1.485);fresco.rotation.y=PI;parent.add_child(fresco)
 var painting:=MeshInstance3D.new();var canvas:=QuadMesh.new();canvas.size=Vector2(6.0,3.0);painting.mesh=canvas
 var paint:=w.mat(Color("c6beaa"),load("res://assets/creatures/party-fresco-v21.png"),.99)
 paint.normal_enabled=true;paint.normal_texture=w.atmosphere.micro_normal;paint.normal_scale=.16;painting.material_override=paint;fresco.add_child(painting)
 # A cracked toy-theatre cornice is fixed to the wall above the mural.
 w.box(fresco,Vector3(0,1.58,-.005),Vector3(6.2,.10,.12),timber)
 for x in [-2.85,0,2.85]:
  w.box(fresco,Vector3(x,1.48,-.025),Vector3(.08,.28,.11),w.materials.rust)
  w.sphere(fresco,Vector3(x,1.48,.035),.018,w.materials.metal)
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
