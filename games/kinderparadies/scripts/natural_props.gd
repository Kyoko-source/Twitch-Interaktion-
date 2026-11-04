class_name NaturalProps
extends RefCounted

static var kernels: Array[ArrayMesh]=[]

static func plant(w: PlayWorld,parent: Node3D) -> Node3D:
 var root:=Node3D.new();root.name="NeglectedAspidistra";root.position=Vector3(-9.3,.015,15.3);parent.add_child(root)
 var clay:=w.mat(Color("78634f"),load("res://assets/aged-plaster.png"),.94);clay.uv1_triplanar=true;clay.uv1_scale=Vector3.ONE*3.
 var soil:=w.mat(Color("302c21"),load("res://assets/paint.png"),.99);soil.uv1_triplanar=true;soil.uv1_scale=Vector3.ONE*12.
 SurfaceDetails.vessel(root,Vector3(0,.035,0),.44,.265,.202,.018,clay,clay,"OpenClayPlantPot")
 w.tube(root,Vector3(0,.015,0),Vector3(0,.041,0),.282,clay)
 var lip:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.244;torus.outer_radius=.273;torus.rings=48;torus.ring_segments=10;lip.mesh=torus;lip.material_override=clay;lip.position.y=.466;root.add_child(lip)
 w.tube(root,Vector3(0,.438,0),Vector3(0,.442,0),.245,soil)
 var stem:=w.mat(Color("586044"),null,.87)
 var veins:=w.mat(Color("889365"),null,.88)
 var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="""
shader_type spatial;
render_mode cull_disabled;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float mid=exp(-abs(UV.x-.5)*90.0);
 float ribs=pow(max(0.0,cos((UV.y+abs(UV.x-.5)*.42)*152.0)),22.0)*.055;
 float dry=COLOR.a;float edge=smoothstep(.28,.49,abs(UV.x-.5));
 vec3 c=mix(COLOR.rgb,vec3(.31,.235,.105),edge*(.22+dry*.7));
 c=mix(c,vec3(.32,.34,.17),mid*.32)+ribs;
 float fleck=step(.987,hash(floor(UV*vec2(75.,170.))));
 ALBEDO=pow(clamp(c,vec3(0.),vec3(1.)),vec3(2.2))*(1.-fleck*.38);ROUGHNESS=.86;SPECULAR=.17;
}
""";material.shader=shader
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rng:=RandomNumberGenerator.new();rng.seed=406
 for leaf in range(19):
  var a:=leaf*2.39996;var direction:=Vector3(sin(a),0,cos(a));var across:=Vector3(cos(a),0,-sin(a))
  var dry:=leaf%5==0 or leaf>15;var height:=rng.randf_range(.84,1.33)
  var start:=direction*.055+Vector3(0,.444,0)
  var base:=direction*.10+Vector3(0,height-.37,0)
  var control:=direction*.18+Vector3(0,height+.18,0)
  var end:=direction*rng.randf_range(.31,.46)+Vector3(0,height-(.41 if dry else .10),0)
  w.tube(root,start,base,.0045,stem)
  var width:=rng.randf_range(.044,.078)
  var tint:=Color("6e7240") if dry else Color("435b31").lightened(rng.randf_range(0,.12))
  tint.a=.85 if dry else .15
  var midrib: Array[Vector3]=[]
  for row in range(18):
   for col in range(4):
    for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
     var t: float=(row+corner.y)/18.;var u: float=(col+corner.x)/4.
     var center:=base*pow(1.-t,2.)+control*2.*(1.-t)*t+end*t*t
     var spread:=pow(maxf(.0,sin(t*PI)),.72)*width
     var p:=center+across*(u-.5)*2.*spread
     p.y+=absf(u-.5)*.023*sin(t*PI)+sin(t*33.+u*6.+leaf)*.0025
     tool.set_uv(Vector2(u,t));tool.set_color(tint);tool.add_vertex(p)
   var t:=row/17.;midrib.append(base*pow(1.-t,2.)+control*2.*(1.-t)*t+end*t*t+Vector3.UP*.0015)
  CelebrationTailoring.curve(root,midrib,.0013,veins,5)
 tool.generate_normals();tool.generate_tangents()
 var foliage:=MeshInstance3D.new();foliage.name="CurvedVeinedPlantLeaves";foliage.mesh=tool.commit();foliage.material_override=material;foliage.gi_mode=GeometryInstance3D.GI_MODE_STATIC;root.add_child(foliage)
 # A single round pot hull; leaf detail never catches feet or carried props.
 var body:=StaticBody3D.new();body.name="SimplePlantPotCollision";root.add_child(body)
 var shape:=CollisionShape3D.new();var hull:=CylinderShape3D.new();hull.radius=.265;hull.height=.47;shape.shape=hull;shape.position.y=.245;body.add_child(shape)
 CelebrationTailoring.merge_joint(root);return root

static func kernel_mesh(variant: int) -> ArrayMesh:
 if kernels.is_empty():
  for v in range(3):kernels.append(_kernel(v))
 return kernels[posmod(variant,3)]

static func _kernel(variant: int) -> ArrayMesh:
 var rng:=RandomNumberGenerator.new();rng.seed=406+variant*19
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;sphere.radial_segments=8;sphere.rings=4
 var arrays:=sphere.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for lobe in range(7):
  var a:=lobe*2.39996+variant
  var p:=Vector3(cos(a)*.0065,rng.randf_range(-.002,.006),sin(a)*.0065) if lobe>0 else Vector3(0,-.004,0)
  var scale:=Vector3(rng.randf_range(.004,.008),rng.randf_range(.004,.008),rng.randf_range(.004,.008)) if lobe>0 else Vector3(.0035,.003,.004)
  if lobe in [2,4]:scale=Vector3(.009,.0035,.006)
  var color:=Color("d8cda2").lightened(rng.randf_range(0,.12)) if lobe>0 else Color("77502a")
  for index in indices:
   var q: Vector3=vertices[index]
   var fold:=1.+.15*sin(q.x*8.+q.z*6.+lobe)*sin(q.y*9.+variant)
   tool.set_color(color.darkened(.12*maxf(0.,-q.y)));tool.set_uv(Vector2(q.x,q.z));tool.add_vertex(p+q*scale*fold)
 tool.generate_normals();tool.generate_tangents()
 var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.albedo_color=Color.WHITE;material.roughness=.96;material.metallic_specular=.12;tool.set_material(material)
 return tool.commit()

static func popcorn(w: PlayWorld,parent: Node3D) -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=406
 for variant in range(3):
  var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=kernel_mesh(variant);multi.instance_count=160
  for i in range(160):
   var a:=rng.randf()*TAU;var radius:=sqrt(rng.randf())*.193
   var p:=Vector3(cos(a)*radius,1.039+.063*(1.-pow(radius/.21,2))+rng.randf_range(-.010,.010),sin(a)*radius)
   var basis:=Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)).scaled(Vector3.ONE*rng.randf_range(.85,1.15))
   multi.set_instance_transform(i,Transform3D(basis,p))
  var mesh:=MultiMeshInstance3D.new();mesh.name="IrregularPoppedCorn_%d"%variant;mesh.multimesh=multi;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
