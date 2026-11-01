class_name SpoiledFood
extends RefCounted

static func build(w: PlayWorld, parent: Node3D) -> ShaderMaterial:
 var shader:=Shader.new();shader.code="""
shader_type spatial;
uniform float clock=0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){vec2 p=UV*17.;float n=noise(p)*.58+noise(p*2.7)*.27+noise(p*8.)*.15;float colony=smoothstep(.41,.65,n);vec3 rot=mix(vec3(.054,.032,.012),vec3(.23,.28,.12),colony);float bloom=smoothstep(.58,.72,n)*(noise(p*16.)*.7+.3);ALBEDO=mix(rot,vec3(.54,.58,.37),bloom);ROUGHNESS=mix(.48,.99,colony);SPECULAR=.18;}
"""
 var material:=ShaderMaterial.new();material.shader=shader
 var noise:=FastNoiseLite.new();noise.seed=300;noise.frequency=14;noise.fractal_octaves=4
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:=20 if OS.has_feature("web") else 32;var sectors:=48 if OS.has_feature("web") else 72
 var rows: Array[PackedVector3Array]=[]
 for i in range(rings+1):
  var row:=PackedVector3Array();var radius:=.318*i/rings
  for j in range(sectors+1):
   var a:=TAU*j/sectors;var x:=cos(a)*radius;var z:=sin(a)*radius
   var n:=noise.get_noise_2d(x*13,z*13)
   row.append(Vector3(x,.010+n*.009*(1-pow(radius/.318,6)),z))
  rows.append(row)
 for i in range(rings):
  for j in range(sectors):
   var a: Vector3=rows[i][j];var b: Vector3=rows[i+1][j];var c: Vector3=rows[i+1][j+1];var d: Vector3=rows[i][j+1]
   var points: Array=[a,b,c] if i==0 else [a,b,c,a,c,d]
   for p in points:st.set_uv(Vector2(p.x,p.z)/.636+Vector2.ONE*.5);st.add_vertex(p)
 st.generate_normals()
 var mesh:=MeshInstance3D.new();mesh.name="PorousSpoiledFood";mesh.mesh=st.commit();mesh.material_override=material;mesh.position=Vector3(-13.25,1.234,-19.25);parent.add_child(mesh)
 return material
