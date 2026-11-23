class_name CharacterFinish
extends RefCounted

static func visitor(id: String, mode: String) -> String:
 if mode=="throne": return "res://assets/visitors-v421/seated-visitor.glb"
 var kind:="hooded" if mode in ["ceiling","drop","queue"] else "split" if mode in ["mouth","peek","window","rush"] else "ragged"
 return "res://assets/visitors-v421/visitor-"+kind+".glb"

# 5.3.1: the crawler (assets/crawler-v531, the owner's own image-to-3D model)
# takes the floor and tube scenes instead of a tipped-over standing visitor.
# The model faces +X and is centred on its bounds; the wrapper stands it on the
# floor, faces it along +Z like the visitors and marks its head for the lunge.
const CRAWLER:="res://assets/crawler-v531/crawler.glb"
const CRAWLER_HALF_HEIGHT:=.3434
const CRAWLER_MODES:=["crawl","tube"]
static func crawler(height: float=1.05) -> Node3D:
 var root:=Node3D.new();root.name="Crawler"
 var model: Node3D=(load(CRAWLER) as PackedScene).instantiate();model.name="CrawlerModel"
 var scale_value:=height/(CRAWLER_HALF_HEIGHT*2.)
 model.scale=Vector3.ONE*scale_value;model.rotation.y=-PI/2;model.position.y=CRAWLER_HALF_HEIGHT*scale_value
 root.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
 # Its face, low and at the front: where the lunge lifts it to your eyes.
 var head:=Node3D.new();head.name="HeadRig";head.position=Vector3(0,height*.45,.38*scale_value);root.add_child(head)
 root.set_meta("crawler",true)
 return root

# The v421 visitors arrive fully headed, clothed and painted from their own
# build script; only the dynamic GI flag is still needed, no recolouring.
static func dynamic_only(root: Node3D) -> void:
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  # Plain flat-coloured garments read as untextured renders; give them woven
  # cloth, filth climbing from the hem and blood running from the neck.
  for i in range(mesh.mesh.get_surface_count()):
   var original:=mesh.get_active_material(i) as StandardMaterial3D
   if not original:continue
   var label:=original.resource_name.to_lower()
   if label=="desiccated visitor skin":
    var dead:=ShaderMaterial.new();dead.shader=load("res://assets/visitors-v421/visitor_skin.gdshader")
    dead.set_shader_parameter("pores",load("res://assets/detail-v310/clown-normal.jpg"))
    mesh.set_surface_override_material(i,dead)
   elif "fabric" in label or "coat" in label or "gown" in label:
    var cloth:=ShaderMaterial.new();cloth.shader=load("res://assets/visitors-v421/visitor_cloth.gdshader")
    cloth.set_shader_parameter("textile",load("res://assets/pbr/fabric_pattern_07/albedo.jpg"))
    cloth.set_shader_parameter("fibres",load("res://assets/pbr/fabric_pattern_07/normal.jpg"))
    cloth.set_shader_parameter("blood_map",load("res://assets/presentation-v250/blood-texture.png"))
    cloth.set_shader_parameter("tint",original.albedo_color)
    mesh.set_surface_override_material(i,cloth)

static func apply(root: Node3D, world: PlayWorld) -> void:
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for i in range(mesh.mesh.get_surface_count()):
   var original:=mesh.get_active_material(i) as StandardMaterial3D
   if not original: continue
   var m:=original.duplicate() as StandardMaterial3D;var label:=m.resource_name.to_lower()
   m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   if "fabric" in label or "hood" in label:
    m.albedo_color=Color(.7,.72,.68);m.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg")
    m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*5
    m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");m.normal_scale=.42;m.roughness=.98
   elif "skin" in label:
    m.albedo_color=Color(.8,.8,.76);m.normal_enabled=true;m.normal_texture=world.atmosphere.micro_normal;m.normal_scale=.19;m.roughness=.71
   elif "cavit" in label or "face" in label or "dark" in label:
    m.albedo_texture=null;m.albedo_color=Color("080706");m.roughness=.56
   mesh.set_surface_override_material(i,m)

static func hand(root: Node3D,tint: Color=Color("ad9176")) -> void:
 var noise:=FastNoiseLite.new();noise.seed=300;noise.frequency=.48
 var pores:=NoiseTexture2D.new();pores.width=128;pores.height=128;pores.noise=noise;pores.seamless=true;pores.as_normal_map=true;pores.bump_strength=.13
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var source:=mesh.get_active_material(i) as StandardMaterial3D
   if source and "skin" in source.resource_name.to_lower():
    var m:=source.duplicate() as StandardMaterial3D;m.albedo_color=tint
    m.roughness=.83;m.metallic_specular=.12;m.normal_enabled=true;m.normal_texture=pores;m.normal_scale=.12
    m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*45;mesh.set_surface_override_material(i,m)
