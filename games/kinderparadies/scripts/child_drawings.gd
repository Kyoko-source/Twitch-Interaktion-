class_name ChildDrawings
extends Node3D

const ATLAS:="res://assets/child-art-v382/crayon-atlas.png"
# Height is the centre of each drawing. Children left these below the handrails.
const PLACEMENTS:=[
 {"p":Vector3(0,.72,-12.028),"s":Vector2(.46,.37),"id":0,"paper":true,"room":"hall"},
 {"p":Vector3(.64,.79,-12.028),"s":Vector2(.43,.35),"id":1,"paper":true,"room":"hall"},
 {"p":Vector3(-.67,.70,-12.028),"s":Vector2(.48,.40),"id":2,"paper":false,"room":"hall"},
 {"p":Vector3(-10.042,.58,-3.4),"s":Vector2(.42,.45),"id":3,"paper":false,"yaw":PI/2,"room":"hall"},
 {"p":Vector3(-10.042,.78,4.40),"s":Vector2(.36,.32),"id":5,"paper":true,"yaw":PI/2,"room":"hall"},
 {"p":Vector3(6.943,.80,-6.8),"s":Vector2(.42,.36),"id":4,"paper":true,"yaw":PI/2,"room":"party"},
 {"p":Vector3(6.943,.73,-6.2),"s":Vector2(.40,.40),"id":3,"paper":true,"yaw":PI/2,"room":"party"},
 {"p":Vector3(6.943,.63,-5.5),"s":Vector2(.58,.38),"id":6,"paper":false,"yaw":PI/2,"room":"party"},
 {"p":Vector3(6.943,.80,-2.7),"s":Vector2(.43,.36),"id":2,"paper":true,"yaw":PI/2,"room":"party"},
 {"p":Vector3(6.943,.73,-1.9),"s":Vector2(.43,.38),"id":0,"paper":false,"yaw":PI/2,"room":"party"},
 {"p":Vector3(-6.575,.76,-22.15),"s":Vector2(.40,.32),"id":1,"paper":true,"yaw":-PI/2,"room":"corridor"},
 {"p":Vector3(-6.575,.73,-23.15),"s":Vector2(.42,.34),"id":4,"paper":false,"yaw":-PI/2,"room":"corridor"},
 {"p":Vector3(-9.225,.77,-21.5),"s":Vector2(.40,.34),"id":5,"paper":true,"yaw":PI/2,"room":"corridor"},
 {"p":Vector3(-9.225,.73,-27.0),"s":Vector2(.42,.33),"id":7,"paper":true,"yaw":PI/2,"room":"corridor"},
 {"p":Vector3(-9.225,.64,-32.2),"s":Vector2(.50,.38),"id":8,"paper":false,"yaw":PI/2,"room":"corridor"}
]
var pieces: Array[MeshInstance3D]=[]
var tape: Material
var print_shader: Shader
var wall_shader: Shader

func build(w: PlayWorld) -> void:
 name="ChildHeightDrawings"
 print_shader=load("res://assets/child-art-v382/aged-paper.gdshader")
 wall_shader=load("res://assets/child-art-v382/wall-crayon.gdshader")
 tape=w.mat(Color("a99a6c"),load("res://assets/paint.png"),.98)
 for i in range(PLACEMENTS.size()):
  var spec: Dictionary=PLACEMENTS[i]
  var mount:=Node3D.new();mount.name="ChildDrawing%02d"%i;mount.position=spec.p;mount.rotation.y=spec.get("yaw",0);add_child(mount)
  if spec.paper:mount.rotation.z=sin(i*2.71)*.045
  var face:=MeshInstance3D.new();face.name="TapedPaper" if spec.paper else "CrayonOnWall";face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mount.add_child(face)
  face.mesh=_paper(spec.s,i) if spec.paper else _quad(spec.s)
  var material:=ShaderMaterial.new();material.shader=print_shader if spec.paper else wall_shader
  material.set_shader_parameter("drawings",load(ATLAS));material.set_shader_parameter("cell",Vector2(int(spec.id)%3,int(spec.id)/3))
  material.set_shader_parameter("age",.58+fmod(i*.13,.25));material.set_shader_parameter("seed",float(i))
  face.material_override=material;face.set_meta("mounted_art",true);face.set_meta("child_drawing",true);face.set_meta("room",spec.room);face.set_meta("paper",spec.paper);pieces.append(face)
  if spec.paper:
   for side in [-1,1]:
    var strip:=MeshInstance3D.new();strip.name="YellowedTapeL" if side<0 else "YellowedTapeR";strip.mesh=_quad(Vector2(.095,.030));strip.material_override=tape;strip.position=Vector3(side*spec.s.x*.37,spec.s.y*.48,.008);strip.rotation.z=side*.19+sin(i)*.1;strip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mount.add_child(strip)

func _quad(size: Vector2) -> QuadMesh:
 var quad:=QuadMesh.new();quad.size=size;return quad

func _paper(size: Vector2,seed_value: int) -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(6):
  for col in range(8):
   for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
    var uv:=Vector2((col+corner.x)/8.,(row+corner.y)/6.)
    # Most of the sheet lies against the wall; only the lower corners lift.
    var curl: float=pow(uv.y,5)*pow(absf(uv.x-.5)*2,3)*.007
    st.set_uv(uv);st.add_vertex(Vector3((uv.x-.5)*size.x,(.5-uv.y)*size.y,.001+curl+.0004*sin(uv.x*17+seed_value)*sin(uv.y*PI)))
 st.generate_normals();return st.commit()
