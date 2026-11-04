class_name ScareSculpt
extends RefCounted

static func head(parent: Node3D,kind: String,p: Vector3) -> Node3D:
 var root: Node3D=(load(QualityAssets.model(kind+"-head","res://assets/shift-v390/"+kind+"-head.glb")) as PackedScene).instantiate();root.name="DetailedScareAnatomy";root.position=p;parent.add_child(root)
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for i in range(mesh.mesh.get_surface_count()):
   var source:=mesh.get_active_material(i) as StandardMaterial3D
   if not source:continue
   var m:=source.duplicate() as StandardMaterial3D
   if "skin" in m.resource_name.to_lower():
    var skin:=ShaderMaterial.new();skin.shader=load("res://assets/shift-v390/aged_skin.gdshader");skin.set_shader_parameter("skin",load("res://assets/detail-v310/clown-skin-albedo.png"));skin.set_shader_parameter("pores",load("res://assets/detail-v310/clown-normal.jpg"));skin.set_shader_parameter("blood",load("res://assets/presentation-v250/blood-texture.png"));mesh.set_surface_override_material(i,skin);continue
   if "hair" in m.resource_name.to_lower():m.cull_mode=BaseMaterial3D.CULL_DISABLED
   mesh.set_surface_override_material(i,m)
 return root

static func costume(root: Node3D,w: PlayWorld,passage: bool=false) -> void:
 var torso:=root.find_child("Torso",true,false)
 if torso:torso.hide()
 for child in root.find_children("*","MeshInstance3D",true,false):
  if "ruff" in str(child.name).to_lower() or "collar" in str(child.name).to_lower():child.hide()
 var dress:=Node3D.new();dress.name="ShreddedLayeredCostume";root.add_child(dress)
 var fabric:=ShaderMaterial.new();fabric.shader=load("res://assets/revamp-v300/soaked_cloth.gdshader");fabric.set_shader_parameter("textile",load("res://assets/pbr/fabric_pattern_07/albedo.jpg"));fabric.set_shader_parameter("fibres",load("res://assets/pbr/fabric_pattern_07/normal.jpg"));fabric.set_shader_parameter("blood_map",load("res://assets/presentation-v250/blood-texture.png"));fabric.set_shader_parameter("tint",Color("465145") if not passage else Color("59483b"))
 var lining:=CelebrationTailoring.cloth(w,Color("64604d"));lining.normal_scale=.3
 var seam:=w.mat(Color("24271f"),null,.98)
 # Complete folded fabric surfaces with a ragged hem and a second inner skirt.
 loft(dress,"InnerTornLining",[Vector3(.15,.27,.19),Vector3(.38,.26,.19),Vector3(.72,.22,.17),Vector3(1.02,.23,.17),Vector3(1.24,.25,.16),Vector3(1.40,.27,.13),Vector3(1.50,.095,.09)],lining,.06,.10)
 loft(dress,"FoldedOuterDress",[Vector3(.24,.31,.20),Vector3(.42,.29,.20),Vector3(.79,.23,.18),Vector3(1.06,.245,.18),Vector3(1.29,.29,.19),Vector3(1.45,.32,.16),Vector3(1.57,.11,.10)],fabric,.085,.13)
 var skin:=w.mat(Color("726b56"),null,.84);skin.normal_enabled=true;skin.normal_texture=w.atmosphere.micro_normal;skin.normal_scale=.28
 loft(dress,"ConnectedTendinousNeck",[Vector3(1.48,.10,.088),Vector3(1.62,.076,.07),Vector3(1.76,.066,.065),Vector3(1.86,.075,.064)],skin,.04)
 for side in [-1,1]:
  var lapel:=CelebrationTailoring.curve(dress,[Vector3(side*.095,1.57,.094),Vector3(side*.18,1.42,.185),Vector3(side*.12,1.23,.192)],.005,lining);lapel.name="FrayedDressCollar"
 for i in range(8):
  var y:=.74+i*.097
  w.sphere(dress,Vector3(.01,y,.183+.014*sin(y*8.)),.009,w.materials.dark)
  CelebrationTailoring.curve(dress,[Vector3(-.013,y+.017,.19),Vector3(-.011,y-.017,.19)],.002,seam)
 # Small stitches and hanging threads belong to actual seams, not random floaters.
 for side in [-1,1]:
  for i in range(18):
   var y:=.37+i*.055;var x: float=side*(.27-.04*sin(y*2.))
   CelebrationTailoring.curve(dress,[Vector3(x-.007,y,.13),Vector3(x+.007,y+.007,.13)],.0016,lining,5)
  for i in range(9):
   var x: float=side*(.07+i*.023)
   CelebrationTailoring.curve(dress,[Vector3(x,.27,.18),Vector3(x+.01,.23,.18),Vector3(x+.005,.19+sin(i)*.025,.18)],.0013,seam,5)
 CelebrationTailoring.merge_joint(dress)
 for key in ["ArmL","ArmR"]:
  var arm:=root.find_child(key,true,false) as MeshInstance3D
  if not arm:continue
  arm.mesh=ArrayMesh.new()
  var sleeve:=Node3D.new();sleeve.name="FoldedScareSleeve";arm.add_child(sleeve)
  loft(sleeve,"GatheredSleeve",[Vector3(-.58,.045,.041),Vector3(-.54,.052,.05),Vector3(-.39,.059,.055),Vector3(-.29,.073,.063),Vector3(-.21,.068,.067),Vector3(-.06,.094,.078),Vector3(.025,.089,.073)],fabric,.095)
  var palm:=w.sphere(sleeve,Vector3(0,-.632,.01),.065,skin);palm.scale=Vector3(.65,1.15,.34)
  for finger in range(5):
   var x: float=(finger-2)*.015
   var length:=.095-.012*absf(finger-2)
   CelebrationTailoring.curve(sleeve,[Vector3(x,-.675,.018),Vector3(x*1.3,-.675-length*.55,.041),Vector3(x*1.45,-.675-length,.071)],.0065,skin)
   var nail:=w.sphere(sleeve,Vector3(x*1.45,-.672-length,.074),.006,w.materials.dark);nail.scale=Vector3(.65,1.4,.35)
  CelebrationTailoring.merge_joint(sleeve)
 for mesh in dress.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC

static func visitor(root: Node3D,w: PlayWorld,mode: String) -> void:
 if mode in ["hands","window","vent","throne"]:return
 var rig:=root.find_child("HeadRig",true,false) as Node3D
 if not rig:return
 for child in rig.get_children():
  if child is Node3D:child.hide()
 head(rig,"granny",Vector3(0,.245,.015))
 if mode!="mouth":costume(root,w)

static func loft(parent: Node3D,title: String,rows: Array[Vector3],material: Material,folds: float=0.,hem: float=0.) -> void:
 # SurfaceTool generates normals using Godot's clockwise front-face winding.
 CelebrationTailoring.profile(parent,title,rows,material,folds,hem)

static func passage(root: Node3D,w: PlayWorld) -> void:
 var rig:=root.find_child("HeadRig",true,false) as Node3D
 if rig:rig.hide()
 head(root,"passage",Vector3(0,1.94,.02));costume(root,w,true)
