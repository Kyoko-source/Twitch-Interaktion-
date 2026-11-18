class_name SoftPlayFinish
extends Node3D

# 4.11.0 soft-play finish. The padding on posts, beams, mats and the ball-pit rim
# is coated PVC, not plaster: an even dye without the mottled print, a fine
# leatherette grain at its true scale on every side, a satin top coat that
# catches the lamps. Colours and material identity stay, so anomaly logic and
# every check that compares materials keep working.
var w: PlayWorld

func build(world: PlayWorld) -> void:
 w=world;name="SoftPlayFinish"
 var grain: Texture2D=load("res://assets/pbr/fabric_leather_01/normal.jpg")
 for id in ["blue","red","gold","teal"]:
  var m: StandardMaterial3D=w.materials[id]
  m.albedo_texture=null;m.albedo_color=m.albedo_color.lightened(.04)
  m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*2.6;m.uv1_world_triplanar=false
  m.normal_enabled=true;m.normal_texture=grain;m.normal_scale=.34
  # Uneven sheen: polished where hands and feet go, dull and grimy elsewhere.
  m.roughness_texture=wear();m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED;m.roughness=.62;m.metallic_specular=.55
  m.clearcoat_enabled=true;m.clearcoat=.55;m.clearcoat_roughness=.2
  m.rim_enabled=true;m.rim=.08;m.rim_tint=.6
  m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 _party_table()
 _stereo()
 _post_caps()

# Soft-play posts end in a domed padded cap, never a cut-off tube.
func _post_caps() -> void:
 var padding:=[w.materials.blue,w.materials.red,w.materials.gold,w.materials.teal]
 var dome:=SphereMesh.new();dome.radius=1.;dome.height=1.;dome.is_hemisphere=true;dome.radial_segments=32;dome.rings=10
 var roots: Array[Node]=[w.props.structure]
 var tower:=w.find_child("EastTower",true,false)
 if tower:roots.append(tower)
 var capped:=0
 for root in roots:
  for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
   var tube:=mesh.mesh as CylinderMesh
   if not tube or not (mesh.material_override in padding) or tube.top_radius<.06:continue
   var up:=mesh.global_basis.y
   if absf(up.normalized().dot(Vector3.UP))<.98:continue
   var cap:=MeshInstance3D.new();cap.name="PaddedPostCap";cap.mesh=dome;cap.material_override=mesh.material_override
   mesh.add_child(cap);cap.position=Vector3(0,tube.height*.5*(1. if up.y>0 else -1.),0);cap.scale=Vector3(tube.top_radius,tube.top_radius*.55,tube.top_radius)
   if up.y<0:cap.rotation.x=PI
   capped+=1
 set_meta("post_caps",capped)

# The 1970s stereo (tools/model-after-play-stereo-v4110.py) replaces the fitted
# hulls of the party stereo. Its collision, the party mode's VU lamps and the
# printed label stay from the original build and sit on the new front plates.
func _stereo() -> void:
 var stereo: Node3D=w.party.stereo
 if not stereo:return
 for mesh: MeshInstance3D in stereo.find_children("*","MeshInstance3D",true,false):
  if not (mesh.material_override in w.party.vu):mesh.hide()
 var model: Node3D=(load("res://assets/party-v4110/party-stereo.glb") as PackedScene).instantiate();model.name="VintageHappylandStereo"
 stereo.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC

# The birthday table: a modelled folding table under a draped paper party cloth
# (tools/model-after-play-party-table-v4110.py). The old slab and legs only stop
# being drawn; their collision and the table setting on top stay as they were.
func _party_table() -> void:
 var table: Node3D=w.props.party_table
 for child in table.get_children():
  if child is MeshInstance3D:
   var p: Vector3=child.position
   var slab: bool=p.distance_to(Vector3(8.5,.78,-7))<.01
   var leg: bool=absf(p.y-.37)<.01 and (absf(p.x-7.65)<.01 or absf(p.x-9.35)<.01)
   if slab or leg:child.hide()
 var model: Node3D=(load("res://assets/party-v4110/party-table.glb") as PackedScene).instantiate();model.name="DrapedBirthdayTable"
 # A few millimetres lower: the runner, napkins and plates rest on the paper, never in it.
 table.add_child(model);model.position=Vector3(8.5,-.003,-7)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC

static var wear_map: NoiseTexture2D
static func wear() -> NoiseTexture2D:
 if wear_map:return wear_map
 var noise:=FastNoiseLite.new();noise.seed=4111;noise.frequency=.012;noise.fractal_octaves=5;noise.fractal_gain=.55
 wear_map=NoiseTexture2D.new();wear_map.width=512;wear_map.height=512;wear_map.seamless=true;wear_map.noise=noise
 var ramp:=Gradient.new();ramp.set_color(0,Color(.38,.38,.38));ramp.set_color(1,Color(.98,.98,.98));wear_map.color_ramp=ramp
 return wear_map
