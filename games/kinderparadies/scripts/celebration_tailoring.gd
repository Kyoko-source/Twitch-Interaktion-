class_name CelebrationTailoring
extends RefCounted

static func cloth(w: PlayWorld,color: Color) -> StandardMaterial3D:
 var material:=w.mat(color,null,.84);material.normal_enabled=true
 material.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");material.normal_scale=.18
 material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*5.;material.cull_mode=BaseMaterial3D.CULL_DISABLED;return material

static func oval(w: PlayWorld,parent: Node3D,p: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
 var part:=w.sphere(parent,p,1,material);part.scale=size;return part

static func joint(parent: Node3D,title: String,p: Vector3) -> Node3D:
 var node:=Node3D.new();node.name=title;node.position=p;parent.add_child(node);return node

static func hat(w: PlayWorld,parent: Node3D,p: Vector3,color: Color) -> void:
 var cone:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=0;shape.bottom_radius=.14;shape.height=.30;shape.radial_segments=24
 cone.mesh=shape;cone.material_override=cloth(w,color);cone.position=p;parent.add_child(cone)
 w.sphere(parent,p+Vector3.UP*.16,.045,w.mat(Color("f2dbad")))

# Geometry is built once behind the credits. Pieces sharing a material are
# welded per rigid joint, so fingers, seams and curls do not add draw calls.
static func merge_joint(node: Node3D) -> void:
 var groups: Dictionary={}
 var originals: Array[MeshInstance3D]=[]
 for child in node.get_children():
  if child is MeshInstance3D and child.mesh and child.visible and child.skin==null:
   originals.append(child)
   for surface in range(child.mesh.get_surface_count()):
    var m: Material=child.get_active_material(surface)
    if not groups.has(m):groups[m]=[]
    groups[m].append({"mesh":child.mesh,"surface":surface,"transform":child.transform})
 for material in groups:
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for item in groups[material]:tool.append_from(item.mesh,item.surface,item.transform)
  tool.set_material(material)
  var mesh:=MeshInstance3D.new();mesh.name="TailoredSurface";mesh.mesh=tool.commit();node.add_child(mesh)
 for child in originals:child.free()
 for child in node.get_children():
  if child is MeshInstance3D:child.set_meta("tailored_batch",true)
  elif child is Node3D:merge_joint(child)

static func skin(w: PlayWorld,color: Color) -> StandardMaterial3D:
 var m:=w.mat(color,null,.73);m.metallic_specular=.24;return m

static func curve(parent: Node3D,points: Array[Vector3],radius: float,material: Material,sides: int=7) -> MeshInstance3D:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(points.size()-1):
  var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
  var axis:=Vector3.UP if absf(tangent.dot(Vector3.UP))<.95 else Vector3.RIGHT
  var u:=tangent.cross(axis).normalized();var v:=tangent.cross(u).normalized()
  for j in range(sides):
   var a:=TAU*j/sides;var b:=TAU*(j+1)/sides
   var vertices: Array[Vector3]=[points[i]+(u*cos(a)+v*sin(a))*radius,points[i+1]+(u*cos(a)+v*sin(a))*radius,points[i+1]+(u*cos(b)+v*sin(b))*radius,points[i]+(u*cos(b)+v*sin(b))*radius]
   for k in [0,1,2,0,2,3]:tool.add_vertex(vertices[k])
 tool.generate_normals();tool.index();var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit();mesh.material_override=material;parent.add_child(mesh);return mesh

static func profile(parent: Node3D,title: String,rows: Array[Vector3],material: Material,folds: float=0.,scallop: float=0.) -> MeshInstance3D:
 # Each row specifies y, horizontal radius, depth radius. A continuous surface
 # replaces the flat cardboard bodies and disconnected sleeve cylinders.
 var segments:=48;var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for r in range(rows.size()-1):
  for j in range(segments):
   var corners: Array[Vector3]=[]
   for pair in [Vector2i(r,j),Vector2i(r,j+1),Vector2i(r+1,j),Vector2i(r+1,j+1)]:
    var a: float=TAU*pair.y/segments;var row: Vector3=rows[pair.x]
    var fold:=1.+folds*(sin(a*11.+row.x*1.1)+.36*sin(a*19.-row.x*2.))
    var hem:=scallop*(.5+.5*cos(a*9.))*pow(1.-float(pair.x)/(rows.size()-1),7.)
    corners.append(Vector3(cos(a)*row.y*fold,row.x+hem,sin(a)*row.z*fold))
   for k in [0,1,2,1,3,2]:
    var pair: Vector2i=[Vector2i(r,j),Vector2i(r,j+1),Vector2i(r+1,j),Vector2i(r+1,j+1)][k]
    tool.set_uv(Vector2(float(pair.y)/segments,float(pair.x)/(rows.size()-1)));tool.add_vertex(corners[k])
 tool.generate_normals();tool.index();var mesh:=MeshInstance3D.new();mesh.name=title;mesh.mesh=tool.commit();mesh.material_override=material;parent.add_child(mesh);return mesh

static func ring(parent: Node3D,p: Vector3,radius: Vector2,material: Material,width: float=.008) -> void:
 var points: Array[Vector3]=[]
 for i in range(49):var a:=TAU*i/48.;points.append(p+Vector3(cos(a)*radius.x,0,sin(a)*radius.y))
 curve(parent,points,width,material)

static func face(w: PlayWorld,head: Node3D,color: Color,clown: bool=false) -> void:
 var flesh:=skin(w,color);var dark:=skin(w,Color("493c43"));var white:=skin(w,Color("fff9ed"))
 var iris:=w.mat(Color("648b83"),null,.25);var pupil:=w.mat(Color("242331"),null,.16)
 oval(w,head,Vector3(0,.06,0),Vector3(.205,.265,.175),flesh)
 oval(w,head,Vector3(0,-.095,.018),Vector3(.162,.14,.142),flesh)
 for side in [-1,1]:
  oval(w,head,Vector3(side*.202,.015,0),Vector3(.041,.072,.038),flesh)
  oval(w,head,Vector3(side*.22,.015,.019),Vector3(.016,.042,.020),skin(w,color.darkened(.13)))
  var eye:=Vector3(side*.084,.071,.153)
  oval(w,head,eye,Vector3(.054,.042,.030),white)
  oval(w,head,eye+Vector3(0,0,.025),Vector3(.024,.028,.010),iris)
  oval(w,head,eye+Vector3(0,0,.034),Vector3(.012,.018,.005),pupil)
  w.sphere(head,eye+Vector3(-.008,.011,.040),.008,white)
  var lid: Array[Vector3]=[];var brow: Array[Vector3]=[]
  for i in range(13):
   var t:=float(i)/12.;lid.append(eye+Vector3((t-.5)*.116,sin(t*PI)*.040,.019))
   brow.append(eye+Vector3((t-.5)*.12,.067+sin(t*PI)*.014,.001))
  curve(head,lid,.007,flesh);curve(head,brow,.008,dark)
  oval(w,head,Vector3(side*.115,-.022,.149),Vector3(.047,.024,.012),skin(w,Color("e8a0a1") if clown else color.lerp(Color("e5a7a4"),.5)))
 oval(w,head,Vector3(0,.005,.171),Vector3(.038,.062,.038),flesh)
 w.sphere(head,Vector3(0,-.010,.204),.039,skin(w,Color("d8757e")) if clown else flesh)
 var mouth: Array[Vector3]=[]
 for i in range(17):
  var a:=float(i)/16.;mouth.append(Vector3((a-.5)*.16,-.09-.032*sin(a*PI),.155+.016*sin(a*PI)))
 curve(head,mouth,.009,skin(w,Color("b46c71")))
 curve(head,[Vector3(-.053,-.105,.173),Vector3(0,-.112,.181),Vector3(.053,-.105,.173)],.006,white)
 if clown:
  for side in [-1,1]:
   oval(w,head,Vector3(side*.09,.163,.132),Vector3(.030,.033,.008),skin(w,Color("8ebcc2")))

static func hand(w: PlayWorld,parent: Node3D,side: int,material: Material) -> Node3D:
 var wrist:=joint(parent,"Wrist",Vector3(0,-.30,0))
 oval(w,wrist,Vector3(0,-.050,.008),Vector3(.062,.082,.033),material)
 for finger in range(4):
  var x: float=(finger-1.5)*.028;var length_value: float=[.080,.098,.091,.071][finger]
  curve(wrist,[Vector3(x,-.085,.012),Vector3(x*1.08,-.085-length_value*.55,.026),Vector3(x*1.14,-.085-length_value,.046)],.014,material,8)
  w.sphere(wrist,Vector3(x*1.14,-.085-length_value,.046),.014,material)
 curve(wrist,[Vector3(side*.047,-.02,.005),Vector3(side*.082,-.055,.025),Vector3(side*.076,-.097,.055)],.019,material,9)
 return wrist

static func limbs(w: PlayWorld,root: Node3D,torso: Node3D,cloth: Material,trim: Material,gloves: Material,boots: Material) -> Dictionary:
 var result:={}
 for side in [-1,1]:
  var suffix: String="l" if side<0 else "r"
  var shoulder:=joint(torso,"Shoulder"+suffix,Vector3(side*.29,1.40,0))
  oval(w,shoulder,Vector3(0,-.06,0),Vector3(.13,.16,.12),cloth)
  profile(shoulder,"ShapedUpperSleeve",[Vector3(-.34,.077,.078),Vector3(-.26,.091,.095),Vector3(-.10,.105,.107),Vector3(.025,.075,.083)],cloth,.025)
  var elbow:=joint(shoulder,"Elbow",Vector3(0,-.31,0))
  oval(w,elbow,Vector3(0,-.005,0),Vector3(.080,.082,.078),cloth)
  profile(elbow,"FoldedLowerSleeve",[Vector3(-.29,.069,.067),Vector3(-.25,.087,.084),Vector3(-.09,.082,.082),Vector3(.04,.073,.074)],cloth,.045)
  ring(elbow,Vector3(0,-.268,0),Vector2(.074,.073),trim,.014)
  var wrist:=hand(w,elbow,side,gloves)
  var hip:=joint(root,"Hip"+suffix,Vector3(side*.16,.86,0))
  profile(hip,"TailoredTrouser",[Vector3(-.39,.105,.10),Vector3(-.30,.12,.12),Vector3(-.05,.13,.13),Vector3(.035,.10,.10)],cloth,.04)
  var knee:=joint(hip,"Knee",Vector3(0,-.37,0))
  oval(w,knee,Vector3.ZERO,Vector3(.105,.10,.105),cloth)
  profile(knee,"TrouserLeg",[Vector3(-.37,.085,.085),Vector3(-.28,.095,.095),Vector3(-.05,.107,.11),Vector3(.03,.105,.10)],cloth,.045)
  ring(knee,Vector3(0,-.34,0),Vector2(.087,.087),trim,.012)
  var ankle:=joint(knee,"Ankle",Vector3(0,-.37,0))
  oval(w,ankle,Vector3(side*.018,-.030,.080),Vector3(.135,.095,.235),boots)
  oval(w,ankle,Vector3(side*.018,-.09,.080),Vector3(.137,.026,.238),trim)
  for lace in range(3):curve(ankle,[Vector3(-.06,.041-lace*.006,.07+lace*.035),Vector3(.06,.041-lace*.006,.09+lace*.035)],.005,trim)
  result["left" if side<0 else "right"]=shoulder;result["elbow_"+suffix]=elbow;result["wrist_"+suffix]=wrist
  result["leg_"+suffix]=hip;result["knee_"+suffix]=knee;result["ankle_"+suffix]=ankle
 return result

static func bow(w: PlayWorld,parent: Node3D,p: Vector3,color: Color,size: float=1.) -> void:
 var fabric:=cloth(w,color)
 for side in [-1,1]:
  var wing:=oval(w,parent,p+Vector3(side*.075*size,0,0),Vector3(.085,.048,.035)*size,fabric);wing.rotation.z=-side*.25
 w.sphere(parent,p,.036*size,fabric)

static func curls(w: PlayWorld,head: Node3D) -> void:
 var gold:=cloth(w,Color("d4a34f"));var light:=cloth(w,Color("e7c57a"))
 for row in range(4):
  for i in range(15):
   var angle:=TAU*i/15.;var y:=.04+row*.074
   # Leave the face open; curls wrap the temples, crown and back of the head.
   if row<3 and sin(angle)>.38:continue
   var p:=Vector3(cos(angle)*(.207-row*.012),y,sin(angle)*(.17-row*.014)-.017)
   oval(w,head,p,Vector3(.052,.049,.048),gold)
   var spiral: Array[Vector3]=[]
   for j in range(15):
    var t:=float(j)/14.;var a:=t*TAU*1.4;spiral.append(p+Vector3(cos(a)*.037*(1.-t*.7),sin(a)*.037*(1.-t*.7),.043))
   curve(head,spiral,.006,light,6)

static func performer(w: PlayWorld,parent: Node3D,p: Vector3,kind: String,color: Color,clown: bool=false) -> Dictionary:
 var root:=joint(parent,"TailoredClown" if clown else "TailoredGuest_"+kind,p)
 root.set_meta("celebration_tailored",true)
 var torso:=joint(root,"SoftTorso",Vector3.ZERO)
 var fabric:=cloth(w,color);var lining:=cloth(w,color.darkened(.14));var cream:=cloth(w,Color("f2e5ce"))
 var trim:=cloth(w,Color("d7b878"));var shoe:=w.mat(Color("775050") if clown else Color("786c78"),null,.55)
 var result:=limbs(w,root,torso,fabric,cream,skin(w,Color("f9edda")),shoe)
 result.merge({"root":root,"torso":torso,"origin":p,"yaw":0.,"style":0 if clown else 1 if kind=="hooded" else 2 if kind=="ragged" else 3})
 if clown:
  profile(torso,"TailoredWaistcoat",[Vector3(.79,.22,.16),Vector3(.90,.29,.19),Vector3(1.15,.31,.21),Vector3(1.36,.26,.18),Vector3(1.48,.19,.14)],fabric,.018)
  profile(torso,"GatheredWaistband",[Vector3(.78,.225,.165),Vector3(.83,.25,.18),Vector3(.88,.25,.18)],lining,.035)
  for side in [-1,1]:
   oval(w,torso,Vector3(side*.17,1.03,.18),Vector3(.087,.108,.034),lining)
   curve(torso,[Vector3(side*.08,1.08,.206),Vector3(side*.17,1.07,.224),Vector3(side*.25,1.08,.19)],.007,trim)
  for y in [1.12,1.29,1.43]:w.sphere(torso,Vector3(0,y,.21),.033,trim)
  var collar:=profile(torso,"PleatedRuff",[Vector3(1.48,.12,.12),Vector3(1.51,.26,.24),Vector3(1.57,.25,.22),Vector3(1.60,.10,.10)],cream,.12)
  collar.name="PleatedClownRuff";bow(w,torso,Vector3(0,1.48,.25),Color("d894a5"),1.15)
 else:
  var hem:=.08 if kind=="ragged" else .025
  profile(torso,"WovenRobeWithFolds",[Vector3(.33,.34,.26),Vector3(.42,.35,.26),Vector3(.66,.31,.23),Vector3(.90,.28,.21),Vector3(1.15,.27,.19),Vector3(1.38,.27,.19),Vector3(1.49,.18,.13)],fabric,.045,hem)
  ring(torso,Vector3(0,.38,0),Vector2(.345,.265),trim,.011)
  for y in [.92,1.10,1.28]:w.sphere(torso,Vector3(0,y,.215),.023,trim)
  bow(w,torso,Vector3(0,1.45,.18),Color("e5bc94"),.8)
  for side in [-1,1]:
   curve(torso,[Vector3(side*.14,1.30,.18),Vector3(side*.13,1.02,.205),Vector3(side*.17,.73,.229),Vector3(side*.24,.44,.25)],.006,lining)
  if kind=="split":
   for i in range(3):oval(w,torso,Vector3(-.14+i*.14,.65,.251),Vector3(.035,.052,.012),cream)
 var head:=joint(torso,"ExpressiveHead",Vector3(0,1.76,0));result.head=head
 if not clown:
  oval(w,head,Vector3(0,.045,-.075),Vector3(.245,.315,.19),fabric)
  oval(w,head,Vector3(0,.04,.04),Vector3(.22,.277,.15),lining)
 face(w,head,Color("fff1e1") if clown else Color("eedbc4"),clown)
 if clown:curls(w,head)
 else:
  hat(w,head,Vector3(0,.46,-.025),color.lightened(.1))
  var edge: Array[Vector3]=[]
  for i in range(33):
   var a: float=-PI*.85+i*PI*1.7/32.;edge.append(Vector3(sin(a)*.224,.055+cos(a)*.277,.107))
  curve(head,edge,.012,cream)
 merge_joint(root)
 return result

static func horse(w: PlayWorld,parent: Node3D,p: Vector3) -> Dictionary:
 var root:=joint(parent,"TailoredCelebratingHorse",p);root.set_meta("celebration_tailored",true)
 var coat:=cloth(w,Color("bfa47d"));var light:=cloth(w,Color("e4cda8"));var muzzle:=skin(w,Color("c8ad91"))
 var mane:=cloth(w,Color("775345"));var ribbon:=cloth(w,Color("ac899c"))
 var hoof:=w.mat(Color("5d5149"),null,.50)
 oval(w,root,Vector3(0,.49,-.17),Vector3(.38,.29,.65),coat)
 oval(w,root,Vector3(0,.63,.27),Vector3(.30,.29,.28),coat)
 var legs: Array[Node3D]=[]
 for x in [-.24,.24]:
  for z in [-.53,.24]:
   var leg:=joint(root,"DancingHorseLeg",Vector3(x,.45,z));legs.append(leg)
   profile(leg,"SoftHorseLeg",[Vector3(-.34,.066,.065),Vector3(-.23,.07,.08),Vector3(-.10,.085,.10),Vector3(.045,.10,.11)],coat,.015)
   oval(w,leg,Vector3(0,-.37,.025),Vector3(.095,.075,.13),hoof)
 bow(w,root,Vector3(0,.90,.44),Color("bb8a9e"),1.7)
 var tail:=joint(root,"SwishingTail",Vector3(0,.56,-.72))
 for i in range(7):
  curve(tail,[Vector3(0,0,0),Vector3((i-3)*.014,-.12,-.13),Vector3((i-3)*.027,-.30,-.19),Vector3((i-3)*.024,-.40,-.12)],.017,mane,8)
 # A single skinned cloth surface replaces the visibly disconnected rings.
 var skeleton:=Skeleton3D.new();skeleton.name="ContinuousNeckSkeleton";root.add_child(skeleton)
 var skin_resource:=Skin.new();var count:=18;var bottom:=.69;var length_value:=1.69
 for i in range(count):
  skeleton.add_bone("Neck%02d"%i)
  var rest:=Transform3D(Basis.IDENTITY,Vector3(0,bottom+length_value*i/(count-1),.25))
  skeleton.set_bone_rest(i,rest);skin_resource.add_bind(i,rest.affine_inverse())
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:=36;var sides:=32
 for row in range(rings):
  for side in range(sides):
   for pair in [Vector2i(row,side),Vector2i(row,side+1),Vector2i(row+1,side),Vector2i(row,side+1),Vector2i(row+1,side+1),Vector2i(row+1,side)]:
    var t:=float(pair.x)/rings;var angle: float=TAU*pair.y/sides
    var bone:=t*(count-1);var lo:=mini(int(bone),count-2);var blend:=bone-lo
    tool.set_bones(PackedInt32Array([lo,lo+1,0,0]));tool.set_weights(PackedFloat32Array([1.-blend,blend,0,0]))
    tool.set_color(Color(.48,.38,.31) if sin(angle)<-.82 else Color.WHITE)
    tool.set_uv(Vector2(float(pair.y)/sides,t*3.))
    var radius:=lerpf(.21,.14,smoothstep(0.,.8,t))
    tool.add_vertex(Vector3(cos(angle)*radius,bottom+t*length_value,.25+sin(angle)*radius*.90))
 var neck_material:=coat.duplicate() as StandardMaterial3D;neck_material.vertex_color_use_as_albedo=true
 tool.generate_normals();tool.index();var neck:=MeshInstance3D.new();neck.name="ContinuousTailoredNeck";neck.mesh=tool.commit();neck.material_override=neck_material;neck.skin=skin_resource;root.add_child(neck);neck.skeleton=neck.get_path_to(skeleton)
 var head:=joint(root,"ExpressiveHorseHead",Vector3(0,2.38,.25))
 oval(w,head,Vector3(0,.09,0),Vector3(.225,.335,.20),coat)
 oval(w,head,Vector3(0,-.10,.19),Vector3(.20,.24,.32),coat)
 oval(w,head,Vector3(0,-.25,.41),Vector3(.232,.17,.21),muzzle)
 oval(w,head,Vector3(0,-.35,.30),Vector3(.19,.085,.22),muzzle)
 var ink:=w.mat(Color("514238"),null,.48);var ivory:=w.mat(Color("fff9e9"),null,.27)
 for sign_value in [-1,1]:
  var ear:=joint(head,"SoftHorseEar",Vector3(sign_value*.15,.37,-.04));ear.rotation.z=-sign_value*.19
  oval(w,ear,Vector3(0,.11,0),Vector3(.075,.22,.06),coat)
  oval(w,ear,Vector3(0,.12,.048),Vector3(.040,.145,.012),ribbon)
  var eye:=joint(head,"KindHorseEye",Vector3(sign_value*.19,.12,.093));eye.rotation.y=sign_value*.61
  oval(w,eye,Vector3.ZERO,Vector3(.064,.070,.029),ivory)
  oval(w,eye,Vector3(0,.002,.023),Vector3(.035,.047,.015),ink)
  w.sphere(eye,Vector3(-.010,.018,.037),.011,ivory)
  curve(eye,[Vector3(-.064,.014,.007),Vector3(-.035,.066,.012),Vector3(.024,.070,.012),Vector3(.064,.030,.004)],.010,coat)
  oval(w,head,Vector3(sign_value*.145,-.19,.571),Vector3(.043,.031,.012),ink)
  curve(head,[Vector3(sign_value*.212,-.24,.44),Vector3(sign_value*.20,-.30,.51),Vector3(sign_value*.13,-.33,.58)],.009,ink)
 # Pale blaze, stitched halter and separate locks give it a horse silhouette.
 oval(w,head,Vector3(0,.08,.182),Vector3(.052,.18,.012),light)
 for i in range(9):
  var y:=.36-i*.09
  curve(head,[Vector3(0,y,-.16),Vector3(-.05,y-.025,-.24),Vector3(-.13,y-.08,-.22)],.029,mane,9)
 for i in range(7):curve(head,[Vector3((i-3)*.022,.36,-.04),Vector3((i-3)*.026,.32,.14),Vector3((i-3)*.022,.20,.19)],.014,mane,8)
 ring(head,Vector3(0,-.16,.29),Vector2(.212,.34),ribbon,.017)
 merge_joint(root)
 return {"root":root,"head":head,"skeleton":skeleton,"neck":neck,"legs":legs,"tail":tail,"origin":p,"yaw":0.}
