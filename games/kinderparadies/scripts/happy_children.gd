class_name HappyChildren
extends RefCounted

# The children of Happyland coming back (secret ending, 4.10.0). Small, bright,
# friendly figures from shared primitives: one sphere and one cylinder mesh for
# all thirty of them, coloured clothes, varied hair and skin. Facing +Z.

const SKIN: Array[Color]=[Color("f3d2bb"),Color("e8b996"),Color("c98e68"),Color("9a6545"),Color("f6dccb"),Color("6e4632")]
const HAIR: Array[Color]=[Color("3a2518"),Color("8a5a2b"),Color("e3c27a"),Color("1c1714"),Color("b5532c"),Color("5c3a22")]
const CLOTHES: Array[Color]=[Color("f4bad1"),Color("b1e1d5"),Color("ffe5a3"),Color("c9c1ee"),Color("aadbec"),Color("ff9a8a"),Color("9fd98b"),Color("ffc27a")]
static var ball: SphereMesh
static var rod: CylinderMesh
static var paints: Dictionary={}

static func _paint(color: Color) -> StandardMaterial3D:
 var key:=color.to_html()
 if not paints.has(key):
  var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.82
  paints[key]=m
 return paints[key]

static func _part(parent: Node3D,mesh: Mesh,p: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
 var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=_paint(color);part.position=p;part.scale=size
 part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(part);return part

static func _limb(parent: Node3D,title: String,p: Vector3,length: float,radius: float,color: Color,end_color: Color,end_size: Vector3) -> Node3D:
 var joint:=Node3D.new();joint.name=title;joint.position=p;parent.add_child(joint)
 _part(joint,rod,Vector3(0,-length*.5,0),Vector3(radius*2,length,radius*2),color)
 _part(joint,ball,Vector3(0,-length,end_size.z*.25),end_size,end_color)
 return joint

# Returns {root, body, legs[2], arms[2], height}; `seed` picks the look.
static func build(parent: Node3D,seed: int) -> Dictionary:
 if ball==null:
  ball=SphereMesh.new();ball.radius=.5;ball.height=1.;ball.radial_segments=16;ball.rings=8
  rod=CylinderMesh.new();rod.top_radius=.5;rod.bottom_radius=.5;rod.height=1.;rod.radial_segments=10
 var rng:=RandomNumberGenerator.new();rng.seed=seed*7919+13
 var h:=rng.randf_range(.95,1.3)
 var skin:=SKIN[rng.randi()%SKIN.size()];var hair:=HAIR[rng.randi()%HAIR.size()]
 var shirt:=CLOTHES[rng.randi()%CLOTHES.size()];var bottom:=CLOTHES[(rng.randi()+3)%CLOTHES.size()].darkened(.25)
 var shoes:=Color("f2f2ee") if rng.randf()<.4 else CLOTHES[rng.randi()%CLOTHES.size()].darkened(.35)
 var root:=Node3D.new();root.name="HappylandChild%d"%seed;parent.add_child(root)
 var body:=Node3D.new();body.name="Body";root.add_child(body)
 var hip:=h*.46
 var legs: Array[Node3D]=[]
 for side in [-1,1]:
  legs.append(_limb(body,"Leg",Vector3(side*h*.055,hip,0),hip-.04,h*.042,bottom if rng.randf()<.5 else skin,shoes,Vector3(h*.1,h*.06,h*.15)))
 var skirt:=rng.randf()<.4
 _part(body,ball,Vector3(0,hip+h*.02,0),Vector3(h*.26,h*(.2 if skirt else .13),h*.2),bottom)
 _part(body,ball,Vector3(0,h*.64,0),Vector3(h*.25,h*.3,h*.19),shirt)
 var arms: Array[Node3D]=[]
 for side in [-1,1]:
  var arm:=_limb(body,"Arm",Vector3(side*h*.13,h*.75,0),h*.27,h*.032,shirt,skin,Vector3(h*.06,h*.06,h*.06))
  arm.rotation.z=side*.12;arms.append(arm)
 var head:=Vector3(0,h*.9,0)
 _part(body,ball,head,Vector3.ONE*h*.24,skin)
 _part(body,ball,head+Vector3(0,h*.035,-h*.02),Vector3(h*.25,h*.2,h*.25),hair)
 match rng.randi()%3:
  0:
   for side in [-1,1]:_part(body,ball,head+Vector3(side*h*.13,-h*.01,-h*.03),Vector3(h*.07,h*.09,h*.07),hair)
  1:_part(body,ball,head+Vector3(0,-h*.06,-h*.12),Vector3(h*.08,h*.12,h*.06),hair)
 for side in [-1,1]:
  _part(body,ball,head+Vector3(side*h*.045,h*.01,h*.112),Vector3(h*.028,h*.034,h*.012),Color("2a2220"))
  _part(body,ball,head+Vector3(side*h*.075,-h*.03,h*.098),Vector3(h*.035,h*.02,h*.01),Color("ffadb5"))
 _part(body,ball,head+Vector3(0,-h*.04,h*.115),Vector3(h*.05,h*.016,h*.01),Color("b4434e"))
 return {"root":root,"body":body,"legs":legs,"arms":arms,"height":h,"phase":rng.randf()*TAU}

# Running, crawling, wading and cheering poses for one frame.
static func pose(child: Dictionary,mode: String,amount: float,clock: float) -> void:
 var body: Node3D=child.body;var swing:=sin(child.phase)
 body.rotation=Vector3.ZERO;body.position=Vector3.ZERO;body.scale=Vector3.ONE
 match mode:
  "run":
   for i in range(2):
    child.legs[i].rotation.x=swing*.75*amount*(1 if i==0 else -1)
    child.arms[i].rotation.x=-swing*.8*amount*(1 if i==0 else -1)
   body.position.y=absf(swing)*.05*amount;body.rotation.x=.12*amount
  "crawl":
   body.rotation.x=1.25;body.position=Vector3(0,.12,-child.height*.35)
   for i in range(2):
    child.legs[i].rotation.x=-1.25+swing*.35*(1 if i==0 else -1)
    child.arms[i].rotation.x=-1.6-swing*.4*(1 if i==0 else -1)
  "wade":
   body.position.y=-.32+absf(sin(clock*3.1+child.phase))*.22
   for i in range(2):child.arms[i].rotation.x=-2.6+sin(clock*6.+i*PI)*.35
  "cheer":
   body.position.y=absf(sin(clock*4.+child.phase))*.08
   for i in range(2):
    child.legs[i].rotation.x=0
    child.arms[i].rotation.x=-2.7+sin(clock*7.+i*PI+child.phase)*.3
  _:
   for i in range(2):child.legs[i].rotation.x=0;child.arms[i].rotation.x=sin(clock*2.+i+child.phase)*.15
