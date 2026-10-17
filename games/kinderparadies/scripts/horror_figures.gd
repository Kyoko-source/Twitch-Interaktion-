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

static func link(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
 var direction:=b-a;mesh.position=(a+b)*.5;mesh.quaternion=Quaternion(Vector3.UP,direction.normalized());mesh.scale=Vector3(1,direction.length(),1)

static func bone(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=radius*.8;cylinder.bottom_radius=radius;cylinder.radial_segments=24;node.mesh=cylinder;node.material_override=material;parent.add_child(node);return node

static func clown(w: PlayWorld, parent: Node3D) -> Dictionary:
 var scene: PackedScene=load("res://assets/props/kitchen-clown-v2.glb")
 var root:=scene.instantiate();root.name="KitchenClown";parent.add_child(root)
 var head:=root.find_child("Head",true,false) as Node3D
 assert(head!=null,"Sculpted clown head is missing")
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for surface in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   if material and material.resource_name=="Cracked greasepaint and blood" and not material.normal_texture:
    material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.17;material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*12
 var suit:=w.mat(Color("744a46"),null,.95);suit.normal_enabled=true;suit.normal_texture=w.atmosphere.micro_normal;suit.normal_scale=.25
 var glove:=w.mat(Color("6b2422"),load("res://assets/aged-plaster.png"),.76)
 var arm:=bone(root,.085,suit);var forearm:=bone(root,.067,suit);var hand:=Node3D.new();root.add_child(hand)
 var palm:=w.sphere(hand,Vector3.ZERO,.047,glove);palm.scale=Vector3(.85,1.25,.55)
 for i in range(4):
  w.tube(hand,Vector3(-.035+i*.022,-.03,.006),Vector3(-.035+i*.022,-.079,.026),.012,glove)
  w.tube(hand,Vector3(-.035+i*.022,-.079,.026),Vector3(-.035+i*.022,-.071,.06),.01,glove)
 w.tube(hand,Vector3(.045,.015,0),Vector3(.03,-.025,.05),.016,glove)
 link(arm,Vector3(-.28,1.48,0),Vector3(-.25,1.15,.42))
 link(forearm,Vector3(-.25,1.15,.42),Vector3(-.18,1.3,.92))
 var idle_arm:=bone(root,.075,suit);link(idle_arm,Vector3(.27,1.44,0),Vector3(.32,.94,.08))
 var idle:=hand.duplicate();root.add_child(idle);idle.position=Vector3(.32,.9,.08)
 var spoon:=bone(root,.016,w.materials.wood);var bowl:=w.sphere(root,Vector3.ZERO,.058,w.materials.wood);bowl.scale=Vector3(1,.3,1.35)
 return {"root":root,"head":head,"upper":arm,"forearm":forearm,"hand":hand,"spoon":spoon,"bowl":bowl}
