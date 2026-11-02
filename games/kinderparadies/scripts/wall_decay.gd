class_name WallDecay
extends Node3D

const ROOT:="res://assets/wall-v383/"
const PATCHES:=[
 {"p":Vector3(-16.35,1.10,-4.35),"n":Vector3.RIGHT,"r":Vector2(1.20,.95),"room":"maintenance"},
 {"p":Vector3(-12.8,.85,-6.85),"n":Vector3.BACK,"r":Vector2(1.15,.70),"room":"maintenance"},
 {"p":Vector3(-16.35,2.61,-6.12),"n":Vector3.RIGHT,"r":Vector2(.60,.43),"room":"maintenance"},
 {"p":Vector3(-9.31,2.10,-21.70),"n":Vector3.RIGHT,"r":Vector2(1.10,.65),"room":"corridor"},
 {"p":Vector3(-6.49,2.40,-24.30),"n":Vector3.LEFT,"r":Vector2(1.20,.70),"room":"corridor"},
 {"p":Vector3(-9.31,2.05,-32.70),"n":Vector3.RIGHT,"r":Vector2(1.15,.75),"room":"corridor"},
 {"p":Vector3(-4.40,3.05,-34.45),"n":Vector3.BACK,"r":Vector2(1.05,.38),"room":"cinema"},
 {"p":Vector3(1.30,2.90,-12.05),"n":Vector3.BACK,"r":Vector2(1.50,1.50),"room":"hall"},
 {"p":Vector3(6.90,2.55,-2.70),"n":Vector3.RIGHT,"r":Vector2(.80,.90),"room":"party"}
]
var walls: Array[MeshInstance3D]=[]
var original_materials: Dictionary={}
var finish: ShaderMaterial

func build(w: PlayWorld) -> void:
 name="PhotographedPlasterDamage"
 var path:=ROOT+("web/" if OS.has_feature("web") else "desktop/")
 finish=ShaderMaterial.new();finish.shader=load(ROOT+"broken-plaster.gdshader")
 finish.set_shader_parameter("albedo_map",load(path+"albedo.jpg"));finish.set_shader_parameter("normal_map",load(path+"normal.jpg"));finish.set_shader_parameter("rough_map",load(path+"roughness.jpg"))
 var centres:=PackedVector4Array();var shapes:=PackedVector4Array();var directions:=PackedVector3Array()
 for i in range(12):
  var spec: Dictionary=PATCHES[i] if i<PATCHES.size() else {"p":Vector3.ZERO,"n":Vector3.ZERO,"r":Vector2.ONE}
  centres.append(Vector4(spec.p.x,spec.p.y,spec.p.z,0));shapes.append(Vector4(spec.r.x,spec.r.y,float(i)*7.13,0));directions.append(spec.n)
 finish.set_shader_parameter("centres",centres);finish.set_shader_parameter("shapes",shapes);finish.set_shader_parameter("directions",directions);finish.set_shader_parameter("patch_count",PATCHES.size())
 # Draw on the existing wall mesh itself. Its collision, silhouette and base
 # material stay intact; there are no floating rectangular decal planes.
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.get_meta("architecture_wall",false) or not mesh.is_visible_in_tree():continue
  var bounds: AABB=mesh.global_transform*mesh.get_aabb()
  for spec in PATCHES:
   if not bounds.intersects(region(spec)):continue
   original_materials[mesh.get_instance_id()]=mesh.material_override
   mesh.material_overlay=finish;walls.append(mesh);break

static func region(spec: Dictionary) -> AABB:
 var size:=Vector3(.06,spec.r.y*2.5,spec.r.x*2.5) if absf(spec.n.x)>.5 else Vector3(spec.r.x*2.5,spec.r.y*2.5,.06)
 return AABB(spec.p-size*.5,size)
