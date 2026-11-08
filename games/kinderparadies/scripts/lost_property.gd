class_name LostProperty
extends RefCounted

# The lost-and-found cubbies hold things children actually leave behind:
# shoes, a lunchbox, a hoodie, a bottle and hat, toys, a backpack, wellies,
# a one-eyed plush rabbit and odd mittens - each with a paper "found" tag.

static func _soft(parent: Node3D,p: Vector3,size: Vector3,material: Material,rot:=Vector3.ZERO) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=.5;shape.height=1.;shape.radial_segments=28;shape.rings=14
 mesh.mesh=shape;mesh.material_override=material;mesh.position=p;mesh.rotation=rot;mesh.scale=size;parent.add_child(mesh);return mesh

static func _capsule(parent: Node3D,p: Vector3,radius: float,height: float,material: Material,rot:=Vector3.ZERO) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CapsuleMesh.new();shape.radius=radius;shape.height=height;shape.radial_segments=24;shape.rings=6
 mesh.mesh=shape;mesh.material_override=material;mesh.position=p;mesh.rotation=rot;parent.add_child(mesh);return mesh

static func _fabric(w: PlayWorld,color: Color,folder:="fabric_pattern_07") -> StandardMaterial3D:
 var m:=w.mat(color,load("res://assets/pbr/%s/albedo.jpg"%folder),.96)
 m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/%s/normal.jpg"%folder);m.normal_scale=.6;m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*6
 return m

static func _plastic(w: PlayWorld,color: Color,rough:=.45) -> StandardMaterial3D:
 var m:=w.mat(color,load("res://assets/aged-plaster.png"),rough);m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*3;return m

static func _tag(w: PlayWorld,parent: Node3D,p: Vector3,text: String,yaw: float) -> void:
 var paper:=w.mat(Color("cdbf98"),load("res://assets/aged-plaster.png"),.95)
 var card:=w.box(parent,p,Vector3(.055,.032,.002),paper);card.rotation=Vector3(-.25,yaw,.12)
 var label:=w.text(card,text,Vector3(0,0,.0016),.0075,Color("3b3226"));label.remove_from_group("caption_signs")
 w.tube(parent,p+Vector3(-.026,.012,0),p+Vector3(-.05,.04,-.02),.0012,w.mat(Color("8a7a5a"),null,.9))

static func build(w: PlayWorld,shelf: Node3D) -> void:
 var dark:=_plastic(w,Color("1d1c1b"),.7)
 var white:=_plastic(w,Color("c9c3b0"),.6)
 var cells: Array[Vector3]=[]
 for row in range(3):
  for col in range(3):cells.append(Vector3(-.56+col*.56,.104+row*.35,.03))
 # 1 - a pair of small trainers, laces open.
 var c:=cells[0]
 for i in range(2):
  var shoe:=Node3D.new();shoe.position=c+Vector3(-.085+i*.17,0,.0);shoe.rotation.y=.25-i*.55;shelf.add_child(shoe)
  var upper:=_fabric(w,Color("4d5f7a") if i==0 else Color("4a5a73"))
  w.box(shoe,Vector3(0,.012,0),Vector3(.075,.022,.18),white)
  _soft(shoe,Vector3(0,.045,.015),Vector3(.072,.06,.17),upper)
  _soft(shoe,Vector3(0,.05,-.05),Vector3(.07,.075,.07),upper)
  for k in range(4):w.box(shoe,Vector3(0,.074-k*.002,.0-k*.022),Vector3(.045,.004,.005),white)
  w.tube(shoe,Vector3(.01,.075,-.01),Vector3(.05,.02,.08),.002,white)
 _tag(w,shelf,c+Vector3(.12,.05,.13),"14.3.",.3)
 # 2 - a dented tin lunchbox with handle and a faded sticker.
 c=cells[1]
 var tin:=_plastic(w,Color("3f7f7a"),.38);tin.metallic=.55
 var box:=w.box(shelf,c+Vector3(0,.07,0),Vector3(.30,.13,.19),tin);box.rotation.y=-.12
 w.box(box,Vector3(0,.07,0),Vector3(.31,.012,.2),tin)
 w.tube(box,Vector3(-.07,.105,0),Vector3(-.07,.08,0),.006,dark);w.tube(box,Vector3(.07,.105,0),Vector3(.07,.08,0),.006,dark)
 w.tube(box,Vector3(-.075,.108,0),Vector3(.075,.108,0),.009,dark)
 var sticker:=w.mat(Color("d7b54a"),null,.8);var star:=w.box(box,Vector3(.05,0,.097),Vector3(.07,.06,.002),sticker);star.rotation.z=.4
 w.box(box,Vector3(0,.055,.097),Vector3(.04,.02,.006),white)
 # 3 - a folded child's hoodie, sleeves tucked, the hood flopped over.
 c=cells[2]
 var hoodie:=_fabric(w,Color("7a3b3b"))
 w.box(shelf,c+Vector3(0,.035,0),Vector3(.30,.07,.26),hoodie).rotation.y=.08
 _soft(shelf,c+Vector3(-.02,.085,-.05),Vector3(.2,.05,.14),hoodie,Vector3(0,.3,0))
 _capsule(shelf,c+Vector3(.01,.078,.07),.022,.26,hoodie,Vector3(0,.1,PI/2))
 for x in [-.03,.03]:w.tube(shelf,c+Vector3(x,.08,.12),c+Vector3(x*1.6,.01,.15),.003,white)
 _tag(w,shelf,c+Vector3(-.13,.08,.14),"2.4.",-.2)
 # 4 - a drinking bottle on its side and a knitted beanie with a pompom.
 c=cells[3]
 var bottle:=_plastic(w,Color("c25a8a"),.3)
 var b:=w.tube(shelf,c+Vector3(-.15,.035,.02),c+Vector3(.02,.035,.08),.034,bottle)
 w.tube(shelf,c+Vector3(.02,.035,.08),c+Vector3(.06,.035,.095),.024,white)
 var knit:=_fabric(w,Color("c9a23a"),"curly_teddy_natural")
 _soft(shelf,c+Vector3(.13,.06,-.02),Vector3(.15,.12,.15),knit)
 w.tube(shelf,c+Vector3(.13,.012,-.02),c+Vector3(.13,.035,-.02),.077,_fabric(w,Color("a8822e")))
 _soft(shelf,c+Vector3(.13,.13,-.02),Vector3(.05,.05,.05),_fabric(w,Color("d8d0bc"),"curly_teddy_natural"))
 # 5 - the rubber duck and a small toy car.
 c=cells[4]
 var duck:=(load("res://assets/models/rubber_duck_toy/rubber_duck_toy.gltf") as PackedScene).instantiate() as Node3D
 duck.position=c+Vector3(-.1,0,0);duck.rotation.y=.6;duck.scale=Vector3.ONE*.9;shelf.add_child(duck)
 var car:=Node3D.new();car.position=c+Vector3(.12,0,.05);car.rotation.y=-.5;shelf.add_child(car)
 var paint:=_plastic(w,Color("b33a2c"),.3);paint.metallic=.4
 w.box(car,Vector3(0,.028,0),Vector3(.075,.03,.15),paint);w.box(car,Vector3(0,.052,-.01),Vector3(.065,.025,.08),paint)
 for x in [-.04,.04]:
  for z in [-.045,.045]:w.tube(car,Vector3(x-.008,.015,z),Vector3(x+.008,.015,z),.016,dark)
 _tag(w,shelf,c+Vector3(-.17,.06,.12),"9.5.",.2)
 # 6 - a small backpack slumped against the back.
 c=cells[5]
 var pack:=_fabric(w,Color("3d6a4c"))
 var bag:=Node3D.new();bag.position=c+Vector3(0,0,-.04);bag.rotation=Vector3(-.18,-.15,0);shelf.add_child(bag)
 _soft(bag,Vector3(0,.12,0),Vector3(.25,.24,.14),pack)
 _soft(bag,Vector3(0,.08,.065),Vector3(.17,.11,.06),_fabric(w,Color("2f5640")))
 w.tube(bag,Vector3(-.07,.13,.07),Vector3(.07,.13,.07),.003,dark)
 w.box(bag,Vector3(.05,.13,.075),Vector3(.012,.03,.004),white)
 for x in [-.06,.06]:w.box(bag,Vector3(x,.12,-.075),Vector3(.035,.22,.01),_fabric(w,Color("2a2a28")))
 # 7 - yellow wellies, one fallen over.
 c=cells[6]
 var rubber:=_plastic(w,Color("c8a127"),.35)
 var boot:=Node3D.new();boot.position=c+Vector3(-.09,0,0);shelf.add_child(boot)
 w.tube(boot,Vector3(0,.0,0),Vector3(0,.2,0),.04,rubber);w.box(boot,Vector3(0,.022,.04),Vector3(.075,.044,.12),rubber)
 w.tube(boot,Vector3(0,.2,0),Vector3(0,.21,0),.043,rubber)
 var fallen:=Node3D.new();fallen.position=c+Vector3(.1,.04,.02);fallen.rotation=Vector3(0,.9,PI/2);shelf.add_child(fallen)
 w.tube(fallen,Vector3(0,.0,0),Vector3(0,.2,0),.04,rubber);w.box(fallen,Vector3(0,.022,.04),Vector3(.075,.044,.12),rubber)
 _tag(w,shelf,c+Vector3(-.15,.16,.12),"27.6.",.3)
 # 8 - a plush rabbit slumped sideways, one button eye missing.
 c=cells[7]
 var fur:=_fabric(w,Color("b8aa94"),"curly_teddy_natural")
 var rabbit:=Node3D.new();rabbit.position=c+Vector3(0,0,0);rabbit.rotation=Vector3(0,.3,.35);shelf.add_child(rabbit)
 _soft(rabbit,Vector3(0,.06,0),Vector3(.13,.12,.11),fur)
 _soft(rabbit,Vector3(0,.15,.01),Vector3(.1,.09,.09),fur)
 _soft(rabbit,Vector3(-.03,.22,-.01),Vector3(.03,.12,.02),fur,Vector3(0,0,.3))
 _soft(rabbit,Vector3(.035,.20,-.01),Vector3(.03,.1,.02),fur,Vector3(.9,0,-.6))
 w.sphere(rabbit,Vector3(-.022,.16,.052),.009,dark)
 w.tube(rabbit,Vector3(.022,.16,.05),Vector3(.022,.16,.056),.002,_fabric(w,Color("2b2420")))
 for x in [-.05,.05]:_soft(rabbit,Vector3(x,.015,.05),Vector3(.05,.04,.07),fur)
 # 9 - odd mittens, a scarf hanging out over the edge and child sunglasses.
 c=cells[8]
 var wool:=_fabric(w,Color("4b5b8f"),"curly_teddy_natural")
 _soft(shelf,c+Vector3(-.12,.02,.0),Vector3(.09,.035,.12),wool,Vector3(0,.4,0))
 _soft(shelf,c+Vector3(-.03,.02,.03),Vector3(.09,.035,.12),_fabric(w,Color("8f3f55"),"curly_teddy_natural"),Vector3(0,-.3,0))
 var scarf:=_fabric(w,Color("7d8b4c"))
 w.box(shelf,c+Vector3(.1,.02,-.02),Vector3(.12,.04,.2),scarf).rotation.y=.2
 w.box(shelf,c+Vector3(.12,-.05,.21),Vector3(.09,.15,.012),scarf).rotation.x=.15
 var lens:=_plastic(w,Color("151515"),.15)
 var shades:=Node3D.new();shades.position=c+Vector3(-.07,.045,-.09);shades.rotation=Vector3(-.4,.2,0);shelf.add_child(shades)
 for x in [-.028,.028]:w.tube(shades,Vector3(x,0,-.002),Vector3(x,0,.002),.022,lens)
 w.box(shades,Vector3(0,.012,0),Vector3(.11,.006,.006),_plastic(w,Color("d65a8c")))
 _tag(w,shelf,c+Vector3(.17,.08,.13),"31.10.",-.3)
