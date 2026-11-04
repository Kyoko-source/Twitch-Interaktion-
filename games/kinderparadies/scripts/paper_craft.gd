class_name PaperCraft
extends RefCounted

static func point(u: float,v: float,size: Vector2,curved: bool) -> Vector3:
 var bend:=pow(absf(u-.5)*2.,5.)*.009+sin(v*PI)*.0015+absf(u-.5)*.004+sin(v*9.)*.001
 if curved:bend=.037*(1.-exp(-(pow((u-.5)*size.x,2)+pow((v-.5)*size.y,2))*30.))+sin(v*PI)*.0015+sin(v*9.)*.001
 return Vector3((u-.5)*size.x,(.5-v)*size.y,bend)

static func finish(face: MeshInstance3D,size: Vector2,curved: bool=false) -> void:
 var front:=face.material_override as StandardMaterial3D
 var back:=front.duplicate() as StandardMaterial3D;back.albedo_texture=load("res://assets/story/paper.png");back.albedo_color=Color("c9bc99")
 front.roughness=.98;front.metallic_specular=.13;back.roughness=1.;back.metallic_specular=.10;front.cull_mode=BaseMaterial3D.CULL_BACK;back.cull_mode=BaseMaterial3D.CULL_BACK
 var mesh:=ArrayMesh.new()
 for reverse in [false,true]:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in range(16):
   for col in range(12):
    for corner in ([0,2,1,1,2,3] if reverse else [0,1,2,1,3,2]):
     var uv:=Vector2(col+(1 if corner in [1,3] else 0),row+(1 if corner in [2,3] else 0))/Vector2(12,16)
     var p:=point(uv.x,uv.y,size,curved);p.z+=-.00045 if reverse else .00045
     st.set_uv(Vector2(1.-uv.x,uv.y) if reverse else uv);st.add_vertex(p)
  st.generate_normals();st.generate_tangents();st.set_material(back if reverse else front);st.index();st.commit(mesh)
 face.mesh=mesh;face.material_override=null
 # Thin stacked folded edges read as paper, without adding a walking collider.
 var edge:=StandardMaterial3D.new();edge.albedo_color=Color("aa9979");edge.roughness=1.
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in range(4):
  for step in range(16):
   var a:=step/16.;var b:=(step+1)/16.
   var uv0:=Vector2(a,0) if side==0 else Vector2(1,a) if side==1 else Vector2(1.-a,1) if side==2 else Vector2(0,1.-a)
   var uv1:=Vector2(b,0) if side==0 else Vector2(1,b) if side==1 else Vector2(1.-b,1) if side==2 else Vector2(0,1.-b)
   var p:=point(uv0.x,uv0.y,size,curved);var q:=point(uv1.x,uv1.y,size,curved)
   for v in [p+Vector3.BACK*.00045,q+Vector3.BACK*.00045,p-Vector3.BACK*.00045,q+Vector3.BACK*.00045,q-Vector3.BACK*.00045,p-Vector3.BACK*.00045]:tool.add_vertex(v)
 tool.generate_normals();tool.set_material(edge);tool.commit(mesh)
