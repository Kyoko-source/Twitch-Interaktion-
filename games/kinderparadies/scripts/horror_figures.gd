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
 var direction:=b-a;var radius: float=mesh.get_meta("radius_scale",1.0);mesh.position=(a+b)*.5;mesh.quaternion=Quaternion(Vector3.UP,direction.normalized());mesh.scale=Vector3(radius,direction.length(),radius)

static func sleeve(parent: Node3D, radius: float) -> MeshInstance3D:
 var scene: Node3D=(load("res://assets/props/clown-sleeve.glb") as PackedScene).instantiate()
 var mesh:=scene.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
 mesh.get_parent().remove_child(mesh);scene.free();parent.add_child(mesh);mesh.set_meta("radius_scale",radius/.085)
 var cloth:=StandardMaterial3D.new();cloth.albedo_color=Color("875650");cloth.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg")
 cloth.normal_enabled=true;cloth.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");cloth.normal_scale=.4;cloth.roughness=.96
 cloth.uv1_triplanar=true;cloth.uv1_scale=Vector3.ONE*6;mesh.material_override=cloth;return mesh

static func bone(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=radius*.8;cylinder.bottom_radius=radius;cylinder.radial_segments=24;node.mesh=cylinder;node.material_override=material;parent.add_child(node);return node

static func clown(w: PlayWorld, parent: Node3D) -> Dictionary:
 var scene: PackedScene=load("res://assets/detail-v310/clown-v310.glb")
 var root:=scene.instantiate();root.name="KitchenClown";parent.add_child(root)
 var head:=root.find_child("Head",true,false) as Node3D
 assert(head!=null,"Sculpted clown head is missing")
 var old_hair:=head.find_child("MattedHairStrands",true,false)
 if old_hair:old_hair.hide()
 var hair: Node3D=(load("res://assets/encounter-v360/clown-blond-hair.glb") as PackedScene).instantiate()
 head.add_child(hair)
 var fibres:=ShaderMaterial.new();fibres.shader=load("res://assets/encounter-v360/blond_hair.gdshader")
 for mesh in hair.find_children("*","MeshInstance3D",true,false):
  mesh.material_override=fibres;mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  mesh.set_meta("nonblocking_atmosphere",true)
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for surface in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   if material and material.resource_name=="Photographic clown complexion":
    var skin:=ShaderMaterial.new();skin.shader=load("res://assets/detail-v310/clown_skin.gdshader")
    skin.set_shader_parameter("skin",load("res://assets/detail-v310/clown-skin-albedo.png"));skin.set_shader_parameter("pores",load("res://assets/detail-v310/clown-normal.jpg"));skin.set_shader_parameter("residue",load("res://assets/presentation-v250/blood-texture.png"));mesh.set_surface_override_material(surface,skin)
   if material and material.resource_name=="Cracked greasepaint and blood":
    var neck:=w.mat(Color("79614e"),null,.78);neck.normal_enabled=true;neck.normal_texture=w.atmosphere.micro_normal;neck.normal_scale=.18;mesh.set_surface_override_material(surface,neck)
   if material and material.resource_name in ["Blood stained woven costume","Dirty pleated linen"]:
    var cloth:=ShaderMaterial.new();cloth.shader=load(ScareBank.ROOT+"soaked_cloth.gdshader")
    cloth.set_shader_parameter("textile",load("res://assets/pbr/fabric_pattern_07/albedo.jpg"));cloth.set_shader_parameter("fibres",load("res://assets/pbr/fabric_pattern_07/normal.jpg"))
    cloth.set_shader_parameter("blood_map",load("res://assets/presentation-v250/blood-texture.png"));cloth.set_shader_parameter("apron",material.resource_name=="Dirty pleated linen")
    cloth.set_shader_parameter("tint",Color("a9a18a") if material.resource_name=="Dirty pleated linen" else Color("743b36"));mesh.set_surface_override_material(surface,cloth)
 var suit:=w.mat(Color("744a46"),null,.95);suit.normal_enabled=true;suit.normal_texture=w.atmosphere.micro_normal;suit.normal_scale=.25
 var arm:=sleeve(root,.085);var forearm:=sleeve(root,.067)
 var hand: Node3D=(load("res://assets/revamp-v300/anatomical-grip-v300.glb") as PackedScene).instantiate();hand.name="StirringHand";root.add_child(hand)
 CharacterFinish.hand(hand)
 link(arm,Vector3(-.28,1.48,0),Vector3(-.25,1.15,.42))
 link(forearm,Vector3(-.25,1.15,.42),Vector3(-.18,1.3,.92))
 var idle_arm:=sleeve(root,.075);link(idle_arm,Vector3(.27,1.44,0),Vector3(.32,.94,.08))
 var idle:=hand.duplicate();root.add_child(idle);idle.position=Vector3(.32,.9,.08)
 var spoon:=bone(root,.016,w.materials.wood);var bowl:=w.sphere(root,Vector3.ZERO,.058,w.materials.wood);bowl.scale=Vector3(1,.3,1.35)
 return {"root":root,"head":head,"upper":arm,"forearm":forearm,"hand":hand,"spoon":spoon,"bowl":bowl}
