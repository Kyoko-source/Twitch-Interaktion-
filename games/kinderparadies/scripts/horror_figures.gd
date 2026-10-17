class_name HorrorFigures
extends RefCounted

static func complexion(texture: Texture2D, stained: bool=false) -> ShaderMaterial:
 var shader:=Shader.new();shader.code="""
shader_type spatial;
render_mode depth_prepass_alpha;
uniform sampler2D face_map:source_color,filter_linear_mipmap_anisotropic;
uniform bool stained=false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){vec4 skin=texture(face_map,UV);vec3 c=skin.rgb*vec3(.77,.79,.73);float smear=0.0;
if(stained){vec2 p=UV+vec2(noise(UV*42.0)*.025,noise(UV*35.0)*.015);float a=1.0-smoothstep(.55,1.0,length((p-vec2(.29,.5))/vec2(.14,.35)));float b=1.0-smoothstep(.5,1.0,length((p-vec2(.63,.74))/vec2(.18,.19)));float d=step(.5,noise(vec2(p.x*68.0,2.0)))*(1.0-smoothstep(.015,.028,abs(p.x-.34)))*smoothstep(.23,.4,p.y)*(1.0-smoothstep(.75,.95,p.y));smear=clamp((a+b+d)*(.6+noise(UV*90.0)*.4),0.0,.92);c=mix(c,vec3(.20,.012,.022)*(0.5+noise(UV*63.0)*.4),smear);}
ALBEDO=c;ALPHA=skin.a;ROUGHNESS=mix(.95,.58,smear);SPECULAR=.18;}
"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("face_map",texture);material.set_shader_parameter("stained",stained);return material

static func face(w: PlayWorld, parent: Node3D, texture: Texture2D) -> Node3D:
 var root:=Node3D.new();root.name="Face";parent.add_child(root)
 var portrait:=SurfaceTool.new();portrait.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(40):
  for col in range(32):
   for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
    var u: float=(col+c.x)/32.0;var v: float=(row+c.y)/40.0;var x: float=(u-.5)*.58;var y: float=(.5-v)*.73
    var z: float=.02+.18*sqrt(maxf(.015,1-pow(x/.26,2)-pow(y/.37,2)))+.035*exp(-pow(x/.05,2)-pow((y+.08)/.08,2))
    portrait.set_uv(Vector2(u,v));portrait.add_vertex(Vector3(x,y,z))
 portrait.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=portrait.commit();mesh.material_override=complexion(texture);root.add_child(mesh)
 var back:=w.sphere(root,Vector3(0,0,-.04),.28,w.mat(Color("302b24"),null,.95));back.scale=Vector3(.8,1.2,.65)
 return root

static func link(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
 var direction:=b-a;mesh.position=(a+b)*.5;mesh.quaternion=Quaternion(Vector3.UP,direction.normalized());mesh.scale=Vector3(1,direction.length(),1)

static func bone(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=radius*.8;cylinder.bottom_radius=radius;cylinder.radial_segments=24;node.mesh=cylinder;node.material_override=material;parent.add_child(node);return node

static func clown(w: PlayWorld, parent: Node3D) -> Dictionary:
 var root:=Node3D.new();root.name="KitchenClown";parent.add_child(root)
 var suit:=w.mat(Color("562b2e"),load("res://assets/floor.png"),.95);suit.normal_enabled=true;suit.normal_texture=w.atmosphere.micro_normal;suit.normal_scale=.25
 var stripe:=w.mat(Color("8e794b"),load("res://assets/aged-plaster.png"),.96)
 var cuff:=w.mat(Color("b8ad91"),load("res://assets/paint.png"),.95)
 var glove:=w.mat(Color("a29b84"),load("res://assets/aged-plaster.png"),.85)
 # Soft layered tailoring and stitched panels, with real human limb proportions.
 var torso:=w.sphere(root,Vector3(0,1.12,0),.4,suit);torso.scale=Vector3(.93,1.35,.67)
 for side in [-1,1]:
  var leg:=w.sphere(root,Vector3(side*.18,.52,0),.23,stripe);leg.scale=Vector3(.8,2,.8)
  for i in range(5): w.tube(root,Vector3(side*.18-.13+i*.055,.15,.145),Vector3(side*.18-.13+i*.055,.9,.145),.012,suit)
  var shoe:=w.sphere(root,Vector3(side*.2,.12,.14),.2,w.materials.dark);shoe.scale=Vector3(1,.58,1.8)
  w.tube(root,Vector3(side*.17,.94,.22),Vector3(side*.18,1.54,.16),.022,stripe)
  var sleeve:=w.sphere(root,Vector3(side*.34,1.42,0),.18,suit);sleeve.scale=Vector3(1,1.25,1)
 for y in [1.03,1.25,1.47]: w.sphere(root,Vector3(0,y,.265),.045,stripe)
 # A layered pleated ruff catches narrow edge light around the neck.
 for layer in range(3):
  for i in range(18):
   var a:=i*TAU/18;var ruffle:=w.sphere(root,Vector3(sin(a)*(.21+layer*.018),1.66+layer*.027,cos(a)*(.17+layer*.018)),.07,cuff);ruffle.scale=Vector3(.7,.32,1.2);ruffle.rotation.y=a
 var head:=face(w,root,load("res://assets/annex/clown-face.png"));head.position=Vector3(0,1.96,.015)
 var hat:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=.015;cone.bottom_radius=.15;cone.height=.42;cone.radial_segments=32;hat.mesh=cone;hat.material_override=stripe;hat.position=Vector3(.055,2.45,-.04);hat.rotation.z=-.17;root.add_child(hat)
 var arm:=bone(root,.105,suit);var forearm:=bone(root,.078,suit);var hand:=w.sphere(root,Vector3.ZERO,.085,glove);hand.scale=Vector3(.85,.7,1.2)
 link(arm,Vector3(-.28,1.48,0),Vector3(-.25,1.15,.42))
 link(forearm,Vector3(-.25,1.15,.42),Vector3(-.18,1.3,.92))
 var idle_arm:=bone(root,.095,suit);link(idle_arm,Vector3(.3,1.44,0),Vector3(.39,.94,.16));w.sphere(root,Vector3(.39,.91,.16),.09,glove)
 var spoon:=bone(root,.016,w.materials.wood);var bowl:=w.sphere(root,Vector3.ZERO,.058,w.materials.wood);bowl.scale=Vector3(1,.3,1.35)
 return {"root":root,"head":head,"upper":arm,"forearm":forearm,"hand":hand,"spoon":spoon,"bowl":bowl}
