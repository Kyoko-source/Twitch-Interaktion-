class_name CostumeWorkshop
extends RefCounted

static func build(b: BackstageExpansion, room: Node3D) -> void:
 var w:=b.w
 var root:=Node3D.new();root.name="CostumeRepairWorkshop";room.add_child(root)
 var faded:=w.mat(Color("6c6351"),load("res://assets/wood.png"),.93)
 var iron:=w.mat(Color("252e29"),load("res://assets/paint.png"),.59,.6)
 var fabric:=w.polish.pbr("fabric_pattern_07",Color("7b5143"),5);fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
 # The workbench lives in the left alcove; the door and the right aisle stay clear.
 var bench:=Node3D.new();bench.name="SewingWorkbench";bench.position=Vector3(13.5,.20,-13.2);root.add_child(bench)
 w.box(bench,Vector3(0,.83,0),Vector3(3.1,.11,1.05),faded,true)
 for x in [-1.37,1.37]:
  for z in [-.4,.4]: w.box(bench,Vector3(x,.40,z),Vector3(.08,.8,.08),iron,true)
 w.box(bench,Vector3(0,.21,0),Vector3(2.9,.06,.85),faded)
 # Modelled sewing machine: bed, upright, overhanging arm, needle and flywheel.
 var machine:=Node3D.new();machine.position=Vector3(-.86,.90,0);bench.add_child(machine)
 w.box(machine,Vector3(0,.035,0),Vector3(.65,.07,.34),iron)
 w.box(machine,Vector3(.22,.22,0),Vector3(.14,.4,.21),iron)
 w.box(machine,Vector3(-.02,.41,0),Vector3(.54,.13,.2),iron)
 w.tube(machine,Vector3(-.24,.35,0),Vector3(-.24,.075,0),.013,w.materials.metal)
 w.box(machine,Vector3(-.24,.09,.025),Vector3(.07,.015,.09),w.materials.metal)
 w.tube(machine,Vector3(.30,.30,0),Vector3(.35,.30,0),.13,iron)
 w.tube(machine,Vector3(.06,.48,0),Vector3(.06,.58,0),.025,w.materials.cream)
 w.tube(machine,Vector3(.06,.58,0),Vector3(-.24,.4,0),.0015,w.materials.cream)
 # Draped fabric and a replacement face awaiting repair.
 b.curtain(bench,Vector3(.15,.91,.31),.67,.79,fabric)
 var head:=b.model(bench,"costume-mask",Vector3(.77,1.09,-.04));head.rotation=Vector3(-.8,.5,-.25);head.scale=Vector3.ONE*.8
 for i in range(7):
  var x:=-.25+i*.19
  w.tube(bench,Vector3(x,.9,-.34),Vector3(x,1.04,-.34),.043,w.materials.cream if i%2 else fabric)
  for y in [.90,1.04]: w.tube(bench,Vector3(x,y-.006,-.34),Vector3(x,y+.006,-.34),.056,faded)
 # Scissors, measuring tape and chalk sit above the tabletop without intersections.
 for side in [-1,1]:
  w.tube(bench,Vector3(.20,.90,-.05),Vector3(.48,.90,side*.09),.009,w.materials.metal)
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.025;torus.outer_radius=.038;ring.mesh=torus;ring.material_override=iron;ring.position=Vector3(.13,.905,side*.045);bench.add_child(ring)
 w.box(bench,Vector3(.15,.9,.16),Vector3(.62,.007,.028),w.materials.cream)
 for i in range(19): w.box(bench,Vector3(-.13+i*.03,.906,.16),Vector3(.002,.002,.012),iron)
 var foot:=w.box(root,Vector3(13.1,.25,-14.1),Vector3(.3,.09,.2),iron);foot.rotation.x=-.15
 # Old production patterns and a signed repair warning on the previously blank wall.
 b.print_board(root,"pattern",Vector3(13.4,2.34,-12.39),Vector2(2.3,1.25),PI)
 b.print_board(root,"costume_log",Vector3(15.30,2.18,-12.39),Vector2(1.0,1.28),PI)
 for z in [-16.4,-17.65]:
  w.box(root,Vector3(19.35,1.4,z),Vector3(.64,.08,1.0),faded,true)
  for dz in [-.36,.36]: w.tube(root,Vector3(19.66,1.03,z+dz),Vector3(19.05,1.36,z+dz),.014,iron)
  var spare:=b.model(root,"costume-mask",Vector3(19.31,1.72,z));spare.rotation=Vector3(-.15,-PI/2,.22);spare.scale=Vector3.ONE*.66
 # A low costume trunk, with a half-open lid and dark interior.
 var chest:=Node3D.new();chest.name="OpenCostumeTrunk";chest.position=Vector3(14.6,.2,-16.0);chest.rotation.y=-.23;root.add_child(chest)
 for x in [-.66,.66]: w.box(chest,Vector3(x,.31,0),Vector3(.07,.62,.78),faded,true)
 for z in [-.36,.36]: w.box(chest,Vector3(0,.31,z),Vector3(1.32,.62,.06),faded,true)
 w.box(chest,Vector3(0,.04,0),Vector3(1.3,.08,.7),iron,true)
 var lid:=Node3D.new();lid.position=Vector3(0,.62,-.37);lid.rotation.x=-.65;chest.add_child(lid);w.box(lid,Vector3(0,0,.38),Vector3(1.43,.07,.82),faded)
 b.curtain(chest,Vector3(.18,.68,.37),.50,.63,fabric)
 # A task lamp grounds the workbench and separates it from the cooler storage racks.
 var lamp:=b.fixture(root,Vector3(13.25,3.49,-13.8),Color("e6ba7a"),1.0,3.8);lamp.shadow_enabled=not OS.has_feature("web")
 for x in [11.39,19.66]:
  w.box(root,Vector3(x,.34,-15.45),Vector3(.05,.22,6.3),faded)
  for z in [-13.1,-15.3,-17.7]:
   w.atmosphere.decal(root,2,Vector3(x,1.3,z),Vector2(1.2,2.1),Vector3(0,PI/2 if x<12 else -PI/2,0),Color(.5,.49,.36,.5))
 # Variation is physical: crooked hangers, compressed limbs and missing heads.
 for i in range(b.costumes.size()):
  var costume: Node3D=b.costumes[i]
  var body:=costume.get_node("EmptyClothBody") as Node3D
  body.scale=Vector3(.92+(i%3)*.07,1.0,1.0)
  body.rotation.z=(i%3-1)*.045
  if i==3: b.masks[i].rotation.z=.36
  if i==6: b.masks[i].hide();costume.position.z-=.4
  # Yellowed identity tags are attached to the chest, rather than floating text.
  var tag:=w.box(costume,Vector3(.17,1.43,.27),Vector3(.09,.13,.008),w.materials.cream);tag.rotation.z=.12
  for k in range(3): w.box(tag,Vector3(0,.025-k*.025,.006),Vector3(.056,.005,.002),iron)
