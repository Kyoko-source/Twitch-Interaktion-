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
   elif "black buttons" in name_value.to_lower():
    m.roughness=.28;m.metallic_specular=.65;m.albedo_color=Color("312d29");m.normal_enabled=false
   mesh.set_surface_override_material(i,m)
 CelebrationTailoring.bow(w,root,Vector3(0,.58,.20),Color("c38180"),1.05)
 # The original toy remains recognizable: stitched patches, glossy sewn
 # buttons, a tailored bow and soft cheek colour rather than a replacement face.
 var head:=root.find_child("HeadRig",true,false) as Node3D
 for side in [-1,1]:
  oval(w,head,Vector3(side*.14,-.075,.183),Vector3(.039,.019,.008),w.mat(Color("c99483"),null,.95))
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
 return CelebrationTailoring.performer(w,parent,p,kind,color)

static func clown(w: PlayWorld,parent: Node3D,p: Vector3) -> Dictionary:
 return CelebrationTailoring.performer(w,parent,p,"clown",Color("72afa7"),true)

static func horse(w: PlayWorld,parent: Node3D,p: Vector3) -> Dictionary:
 return CelebrationTailoring.horse(w,parent,p)
