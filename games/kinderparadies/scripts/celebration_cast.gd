class_name CelebrationCast
extends RefCounted

static func cloth(w: PlayWorld,color: Color) -> StandardMaterial3D:
 var m:=w.mat(color,null,.88)
 m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");m.normal_scale=.16
 m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*4
 return m

static func meshes(root: Node3D) -> Array:
 var result: Array=root.find_children("*","MeshInstance3D",true,false)
 if root is MeshInstance3D:result.push_front(root)
 return result

static func oval(w: PlayWorld,parent: Node3D,p: Vector3,size: Vector3,m: Material) -> MeshInstance3D:
 var part:=w.sphere(parent,p,1,m);part.scale=size;return part

static func joint(parent: Node3D,title: String,p: Vector3) -> Node3D:
 var node:=Node3D.new();node.name=title;node.position=p;parent.add_child(node);return node

static func rabbit(w: PlayWorld,parent: Node3D,p: Vector3,size: float,tint: Color) -> Dictionary:
 var root: Node3D=(load("res://assets/celebration-v3813/celebration-rabbit.glb") as PackedScene).instantiate()
 parent.add_child(root);root.position=p;root.scale=Vector3.ONE*size
 for mesh in meshes(root):
  for i in range(mesh.mesh.get_surface_count()):
   var original:=mesh.get_active_material(i) as StandardMaterial3D
   var name_value: String=original.resource_name if original else ""
   var m:=cloth(w,tint if "oatmeal" in name_value else Color("b7dddb") if "sewn cloth" in name_value else Color("594744") if "dark thread" in name_value else Color("fff5da") if "Ivory" in name_value else Color("343039"))
   if "oatmeal" in name_value:
    var texture_path:="res://assets/plush-fur.png" if ResourceLoader.exists("res://assets/plush-fur.png") else "res://assets/pbr/fabric_pattern_07/albedo.jpg"
    m.albedo_texture=load(texture_path);m.uv1_scale=Vector3.ONE*6
   mesh.set_surface_override_material(i,m)
 return {"root":root,"head":root.find_child("HeadRig",true,false),"left":root.find_child("ArmL",true,false),"right":root.find_child("ArmR",true,false),"leg_l":root.find_child("LegL",true,false),"leg_r":root.find_child("LegR",true,false),"origin":p,"yaw":0.}

static func hat(w: PlayWorld,parent: Node3D,p: Vector3,color: Color) -> void:
 var cone:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=0;shape.bottom_radius=.14;shape.height=.30;shape.radial_segments=20;cone.mesh=shape;cone.material_override=cloth(w,color);cone.position=p;parent.add_child(cone)
 w.sphere(parent,p+Vector3.UP*.16,.045,w.mat(Color("fff3b9")))

static func smile(w: PlayWorld,parent: Node3D,p: Vector3,size: float) -> void:
 var ink:=w.mat(Color("785456"),null,.9)
 for i in range(8):
  var a:=PI+float(i)*PI/8.;var b:=PI+float(i+1)*PI/8.
  w.tube(parent,p+Vector3(cos(a)*size,sin(a)*size*.45,0),p+Vector3(cos(b)*size,sin(b)*size*.45,0),size*.065,ink)

static func visitor(w: PlayWorld,parent: Node3D,p: Vector3,kind: String,color: Color) -> Dictionary:
 var root: Node3D=(load("res://assets/revamp-v300/visitor-"+kind+".glb") as PackedScene).instantiate()
 parent.add_child(root);root.name="FriendlyVisitor_"+kind;root.position=p
 for mesh in meshes(root):
  for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,cloth(w,color if mesh.name in ["Torso","BurialHood"] else Color("fff0de")))
 var head:=root.find_child("HeadRig",true,false) as Node3D
 for part in head.get_children():
  if part.name!="BurialHood":part.hide()
 oval(w,head,Vector3(0,.25,.04),Vector3(.145,.20,.14),cloth(w,Color("fff1df")))
 for side in [-1,1]:
  oval(w,head,Vector3(side*.055,.285,.175),Vector3(.024,.033,.012),w.mat(Color("332b43"),null,.24))
  w.sphere(head,Vector3(side*.055-.006,.295,.187),.006,w.mat(Color.WHITE))
  oval(w,head,Vector3(side*.087,.23,.171),Vector3(.022,.013,.006),w.mat(Color("f8b2ba")))
 smile(w,head,Vector3(0,.22,.182),.040);hat(w,head,Vector3(0,.58,0),color.lightened(.18))
 var result:={"root":root,"head":head,"left":root.find_child("ArmL",true,false),"right":root.find_child("ArmR",true,false),"origin":p,"yaw":0.}
 for side in [-1,1]:
  var leg:=root.find_child("LegL" if side<0 else "LegR",true,false) as Node3D
  var pivot:=joint(root,"DancingHipL" if side<0 else "DancingHipR",Vector3(side*.14,.83,0))
  leg.reparent(pivot,true);result["leg_l" if side<0 else "leg_r"]=pivot
 return result

static func clown(w: PlayWorld,parent: Node3D,p: Vector3) -> Dictionary:
 var root:=joint(parent,"CelebratingKitchenClown",p)
 var mint:=cloth(w,Color("8dd9cb"));var pink:=cloth(w,Color("f1adc7"));var white:=cloth(w,Color("fff6e9"));var gold:=cloth(w,Color("f7db7b"))
 oval(w,root,Vector3(0,1.18,0),Vector3(.32,.43,.21),mint)
 for y in [1.02,1.22,1.42]:w.sphere(root,Vector3(0,y,.215),.035,gold)
 for side in [-1,1]:oval(w,root,Vector3(side*.16,1.60,.045),Vector3(.15,.065,.10),pink)
 var asset: Node3D=(load("res://assets/detail-v310/clown-v310.glb") as PackedScene).instantiate();root.add_child(asset)
 var head:=asset.find_child("Head",true,false) as Node3D
 head.reparent(root,true);asset.queue_free()
 for mesh in meshes(head):
  if "tooth" in str(mesh.name).to_lower() or "gum" in str(mesh.name).to_lower() or "oral" in str(mesh.name).to_lower() or "Hair" in str(mesh.name):mesh.hide();continue
  for i in range(mesh.mesh.get_surface_count()):
   var old: Material=mesh.get_active_material(i);var label: String=old.resource_name if old else ""
   var m:=w.mat(Color("84b6b9") if "irises" in label else Color("302b3b") if "cavit" in label else Color("fff3e5"),null,.74)
   mesh.set_surface_override_material(i,m)
 var hair: Node3D=(load("res://assets/encounter-v360/clown-blond-hair.glb") as PackedScene).instantiate();head.add_child(hair)
 var fibres:=ShaderMaterial.new();fibres.shader=load("res://assets/encounter-v360/blond_hair.gdshader")
 for mesh in meshes(hair):mesh.material_override=fibres
 w.sphere(head,Vector3(0,0,.173),.031,w.mat(Color("e4778d"),null,.4))
 oval(w,head,Vector3(0,-.085,.148),Vector3(.058,.040,.022),white)
 smile(w,head,Vector3(0,-.077,.172),.042)
 for side in [-1,1]:oval(w,head,Vector3(side*.09,-.044,.146),Vector3(.030,.022,.010),pink)
 var result:={"root":root,"head":head,"origin":p,"yaw":0.}
 for side in [-1,1]:
  var arm:=joint(root,"ShoulderL" if side<0 else "ShoulderR",Vector3(side*.32,1.47,0))
  w.tube(arm,Vector3.ZERO,Vector3(0,-.29,0),.09,mint)
  var elbow:=joint(arm,"Elbow",Vector3(0,-.29,0));w.tube(elbow,Vector3.ZERO,Vector3(0,-.26,0),.075,pink)
  w.sphere(elbow,Vector3(0,-.29,0),.09,white)
  var leg:=joint(root,"HipL" if side<0 else "HipR",Vector3(side*.16,.91,0))
  w.tube(leg,Vector3.ZERO,Vector3(0,-.35,0),.11,pink)
  var knee:=joint(leg,"Knee",Vector3(0,-.35,0));w.tube(knee,Vector3.ZERO,Vector3(0,-.36,0),.09,mint)
  oval(w,knee,Vector3(side*.045,-.42,.13),Vector3(.15,.10,.29),gold)
  result["left" if side<0 else "right"]=arm;result["leg_l" if side<0 else "leg_r"]=leg
  result["elbow_l" if side<0 else "elbow_r"]=elbow;result["knee_l" if side<0 else "knee_r"]=knee
 return result

static func horse(w: PlayWorld,parent: Node3D,p: Vector3) -> Dictionary:
 var root:=joint(parent,"HappyLongNeckHorse",p);var cream:=cloth(w,Color("f3deb3"));var pink:=cloth(w,Color("edb9c9"));var mane:=cloth(w,Color("9a76ba"))
 oval(w,root,Vector3(0,.45,0),Vector3(.44,.45,.38),pink)
 var links: Array[MeshInstance3D]=[]
 for i in range(20):
  var section:=w.tube(root,Vector3(0,.5+i*.1,0),Vector3(0,.62+i*.1,0),.13,cream)
  (section.mesh as CylinderMesh).height=1.;links.append(section)
 var head:=joint(root,"DancingHorseHead",Vector3(0,2.4,0))
 oval(w,head,Vector3(0,.09,0),Vector3(.25,.36,.25),cream)
 oval(w,head,Vector3(0,-.13,.30),Vector3(.25,.22,.30),cream)
 for side in [-1,1]:
  var ear:=oval(w,head,Vector3(side*.17,.46,-.02),Vector3(.08,.25,.075),cream);ear.rotation.z=-side*.3
  oval(w,head,Vector3(side*.19,.19,.20),Vector3(.055,.075,.045),w.mat(Color("433148"),null,.25))
  w.sphere(head,Vector3(side*.18,.212,.237),.016,w.mat(Color.WHITE))
  oval(w,head,Vector3(side*.15,-.10,.56),Vector3(.031,.022,.012),mane)
  oval(w,head,Vector3(side*.225,-.01,.36),Vector3(.035,.018,.025),pink)
 for i in range(7):oval(w,head,Vector3(0,.37-i*.11,-.20),Vector3(.13,.1,.10),mane)
 smile(w,head,Vector3(0,-.23,.568),.09)
 for side in [-1,1]:oval(w,root,Vector3(side*.16,1.07,.14),Vector3(.16,.09,.08),pink)
 return {"root":root,"head":head,"links":links,"origin":p,"yaw":0.}
