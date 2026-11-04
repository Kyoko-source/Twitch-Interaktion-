class_name WrappedPresent
extends RefCounted

static func ribbon(parent: Node3D,points: Array[Vector3],width: float,material: Material) -> void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 for i in range(points.size()-1):
  var side: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized().cross(Vector3(0,.7,.7)).normalized()*width*.5
  var next_side: Vector3=(points[mini(i+2,points.size()-1)]-points[i]).normalized().cross(Vector3(0,.7,.7)).normalized()*width*.5
  var vertices:=[points[i]-side,points[i]+side,points[i+1]-next_side,points[i+1]+next_side]
  for j in [0,2,1,1,2,3]:st.set_uv(Vector2(float(j%2),float(i+(1 if j>=2 else 0))/points.size()));st.add_vertex(vertices[j])
 st.index();st.generate_normals();st.generate_tangents()
 var mesh:=MeshInstance3D.new();mesh.name="SoftRibbonLoop";mesh.mesh=st.commit();mesh.material_override=material;parent.add_child(mesh)

static func build(w: PlayWorld,parent: Node3D,p: Vector3,size_value: Vector3,index: int,solid: bool=false,bow: bool=true) -> Node3D:
 var root:=Node3D.new();root.name="FoldedPaperPresent";root.position=p;root.set_meta("wrapped_present",true);parent.add_child(root)
 var material:=ShaderMaterial.new();material.shader=load("res://assets/restoration-v350/wrapping-paper.gdshader")
 material.set_shader_parameter("paper",[Color("385754"),Color("a18b51"),Color("89534f")][index%3]);material.set_shader_parameter("pattern",index%3);material.set_shader_parameter("grain",load("res://assets/paint.png"))
 var mesh:=MeshInstance3D.new();mesh.name="CrispWrappedCarton";mesh.mesh=w.bevel(size_value*10.);mesh.scale=Vector3.ONE*.1;mesh.material_override=material;root.add_child(mesh)
 if solid:
  var body:=StaticBody3D.new();root.add_child(body);var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_value;collider.shape=box;body.add_child(collider)
 var satin:=w.mat(Color("aa9e7d"),null,.53);satin.cull_mode=BaseMaterial3D.CULL_DISABLED
 satin.normal_enabled=true;satin.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");satin.normal_scale=.14;satin.uv1_scale=Vector3(7,28,1)
 root.set_meta("environment_dressing",true);root.set_meta("furniture_volume",AABB(-size_value*.5,size_value))
 var half:=size_value*.5;var band:=minf(size_value.x,size_value.z)*.065
 # Flat wrapping bands continue across all four faces, without wooden struts.
 for x in [-half.x-.0015,half.x+.0015]:w.box(root,Vector3(x,0,0),Vector3(.0015,size_value.y,band),satin)
 for z in [-half.z-.0015,half.z+.0015]:w.box(root,Vector3(0,0,z),Vector3(band,size_value.y,.0015),satin)
 for y in [-half.y-.0015,half.y+.0015]:
  w.box(root,Vector3(0,y,0),Vector3(size_value.x,.0015,band),satin)
  w.box(root,Vector3(0,y,0),Vector3(band,.0015,size_value.z),satin)
 # The folded end-paper triangles and seam follow the carton edges.
 for side in [-1,1]:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var vertices:=[Vector3(-half.x+.009,-half.y+.01,side*(half.z+.001)),Vector3(half.x-.009,-half.y+.01,side*(half.z+.001)),Vector3(0,half.y*.35,side*(half.z+.003))]
  for j in ([0,1,2] if side==1 else [0,2,1]):st.set_uv(Vector2(vertices[j].x/size_value.x+.5,vertices[j].y/size_value.y+.5));st.add_vertex(vertices[j])
  st.generate_normals();st.generate_tangents();var flap:=MeshInstance3D.new();flap.name="OverlappingPaperFoldFront" if side==1 else "OverlappingPaperFoldBack";flap.mesh=st.commit();flap.material_override=material;root.add_child(flap)
  var tape:=w.mat(Color("b3a17c"),load("res://assets/paint.png"),.29)
  w.box(root,Vector3(half.x*.42,-half.y*.50,side*(half.z+.004)),Vector3(size_value.x*.11,.024,.001),tape)
 if bow:
  var span:=minf(size_value.x,size_value.z)*.36
  for side in [-1,1]:
   var loop: Array[Vector3]=[]
   for i in range(31):
    var t: float=i/30.;loop.append(Vector3(side*span*sin(PI*t),half.y+.012+span*.53*sin(PI*t),span*.36*sin(TAU*t)))
   ribbon(root,loop,band*1.2,satin)
  var knot:=w.box(root,Vector3(0,half.y+.016,0),Vector3(band*1.7,.025,band*1.4),satin);knot.rotation.y=.25
  for side in [-1,1]:
   var tail: Array[Vector3]=[]
   for i in range(18):
    var t: float=i/17.;tail.append(Vector3(side*span*.24*t,half.y+.009+.012*sin(PI*t)-pow(t,8.)*.025,t*half.z*.90))
   ribbon(root,tail,band,satin)
 var tag_paper:=w.mat(Color("d8cdb0"),null,.98);tag_paper.metallic_specular=.08
 var tag:=w.box(root,Vector3(half.x*.58,half.y+.003,half.z*.42),Vector3(size_value.x*.23,.001,size_value.z*.16),tag_paper);tag.rotation.y=-.18
 var ink:=QuadMesh.new();ink.size=Vector2(size_value.x*.21,size_value.x*.0525)
 var print_material:=w.mat(Color.WHITE,load("res://assets/restoration-v350/parcel-tag-%d.png"%(index%3)),.95);print_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;print_material.alpha_scissor_threshold=.35
 var caption:=MeshInstance3D.new();caption.mesh=ink;caption.material_override=print_material;caption.position=Vector3(0,.001,0);caption.rotation.x=-PI/2;caption.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tag.add_child(caption)
 return root
