class_name KitchenFurniture
extends RefCounted

static func build(w: PlayWorld, parent: Node3D) -> void:
 var kit: Node3D=(load("res://assets/kitchen-v260/industrial-kitchen.glb") as PackedScene).instantiate();kit.name="ManufacturedKitchen";parent.add_child(kit)
 for mesh in kit.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(i) as StandardMaterial3D
   if not material: continue
   material=material.duplicate();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.22;material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*2.7
   if "enamel" in material.resource_name:
    material.albedo_texture=load("res://assets/paint.png");material.normal_scale=.35
   elif "steel" in material.resource_name:
    material.roughness_texture=load("res://assets/pbr/metal_grate_rusty/roughness.jpg");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
   mesh.set_surface_override_material(i,material)
 # Simple exact manufactured volumes, with a genuine opening for the sink.
 # Rendered and physical worktop pieces share their transform through w.box.
 var invisible:=w.mat(Color(0,0,0,0));invisible.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 for part in [{"p":Vector3(-16.7,.45,-18),"s":Vector3(.96,.65,5.8)}, {"p":Vector3(-13.25,.52,-19.25),"s":Vector3(.95,.78,1.1)}, {"p":Vector3(-11,1.015,-21.7),"s":Vector3(1.25,1.99,.95)}]:
  var body:=StaticBody3D.new();body.name="KitchenFittedSolid";body.position=part.p;parent.add_child(body)
  var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=part.s;shape.shape=bounds;body.add_child(shape)
 for segment in [Vector2(-21.05,-17.16),Vector2(-16.14,-14.95)]:
  var top:=w.box(parent,Vector3(-16.65,1.03,(segment.x+segment.y)*.5),Vector3(1.14,.08,segment.y-segment.x),invisible,true);top.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in [-17.165,-16.135]:
  var rim:=w.box(parent,Vector3(x,1.03,-16.65),Vector3(.11,.08,1.02),invisible,true);rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
