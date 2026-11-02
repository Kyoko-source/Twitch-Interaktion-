class_name ReceptionFurniture
extends RefCounted

static func build(w: PlayWorld) -> void:
 var chair:=w.group("reception_chair");chair.name="ReceptionOfficeChair";chair.position=Vector3(-8.15,0,6.72);chair.rotation.y=PI
 chair.set_meta("environment_dressing",true)
 chair.set_meta("furniture_volume",AABB(Vector3(-.37,.02,-.39),Vector3(.74,1.14,.80)))
 var metal:=w.mat(Color("63685f"),load("res://assets/paint.png"),.44,.65)
 var plastic:=w.mat(Color("272c28"),load("res://assets/paint.png"),.86)
 var fabric:=w.mat(Color("5b645b"),load("res://assets/pbr/fabric_pattern_07/albedo.jpg"),.97)
 fabric.normal_enabled=true;fabric.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");fabric.normal_scale=.28;fabric.uv1_triplanar=true;fabric.uv1_scale=Vector3.ONE*5
 # Five connected castor arms, paired rubber wheels and a gas-lift column.
 for i in range(5):
  var a:=i*TAU/5.;var tip:=Vector3(sin(a)*.32,.09,cos(a)*.32)
  w.tube(chair,Vector3(0,.15,0),tip,.025,metal)
  w.tube(chair,tip,tip-Vector3(0,.04,0),.013,metal)
  var axle:=Vector3(cos(a),0,-sin(a))*.04
  w.tube(chair,tip-Vector3(0,.04,0)-axle,tip-Vector3(0,.04,0)+axle,.045,plastic)
 w.tube(chair,Vector3(0,.12,0),Vector3(0,.39,0),.026,metal)
 w.tube(chair,Vector3(0,.13,0),Vector3(0,.29,0),.043,plastic)
 w.box(chair,Vector3(0,.40,0),Vector3(.32,.07,.28),plastic)
 w.box(chair,Vector3(0,.46,0),Vector3(.50,.055,.48),plastic)
 var seat:=w.box(chair,Vector3(0,.50,-.015),Vector3(.51,.095,.47),fabric);seat.name="WornPaddedSeat"
 w.tube(chair,Vector3(0,.38,.18),Vector3(0,.89,.27),.027,metal)
 var back:=w.box(chair,Vector3(0,.89,.25),Vector3(.49,.52,.08),plastic);back.rotation.x=-.10
 var pad:=w.box(back,Vector3(0,0,-.05),Vector3(.455,.48,.065),fabric);pad.name="UpholsteredBackrest"
 for side in [-1,1]:
  w.tube(chair,Vector3(side*.18,.42,.08),Vector3(side*.30,.68,.06),.017,metal)
  w.box(chair,Vector3(side*.30,.70,-.025),Vector3(.075,.045,.35),plastic)
 w.tube(chair,Vector3(.12,.39,0),Vector3(.29,.37,-.08),.008,metal)
 w.box(chair,Vector3(.30,.37,-.09),Vector3(.09,.026,.04),plastic)
 # Only the seat and back collide; leg/mesh detail never creates snagging.
 var solid:=StaticBody3D.new();solid.name="SimpleOfficeChairCollision";chair.add_child(solid)
 for data in [{"p":Vector3(0,.38,0),"s":Vector3(.56,.52,.55)},{"p":Vector3(0,.89,.25),"s":Vector3(.51,.52,.16)}]:
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=data.s;shape.shape=box;shape.position=data.p;solid.add_child(shape)
