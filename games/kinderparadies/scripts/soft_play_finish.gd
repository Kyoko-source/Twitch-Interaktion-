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
 _play_mats()
 _craft_corner()
 _arcade_cabinets()
 _prize_bunnies()
 _snack_machines()

# 4.12.0 craft corner: the round table and its five stools become modelled
# furniture (tools/model-after-play-craft-corner-v4120.py); the drawing sheets
# show real children's drawings on aged paper. Collisions stay as they were.
func _craft_corner() -> void:
 var party: Node3D=w.props.get("party_dressing")
 if not party:return
 var centre:=Vector3(13.7,0,-3.8)
 var seats: Array=[]
 var sheet:=0
 for child in party.get_children():
  if not child is MeshInstance3D:continue
  var mesh: MeshInstance3D=child;var p: Vector3=mesh.position
  var tube:=mesh.mesh as CylinderMesh
  if mesh.name=="RoundActivityTable":mesh.hide();continue
  if tube and absf(tube.top_radius-.04)<.001 and Vector2(p.x-centre.x,p.z-centre.z).length()<1.:mesh.hide();continue
  if tube and absf(tube.top_radius-.23)<.001 and Vector2(p.x-centre.x,p.z-centre.z).length()<1.7:seats.append({"p":Vector3(p.x,0,p.z),"m":mesh.material_override});mesh.hide();continue
  if tube and absf(tube.top_radius-.025)<.001 and p.y<.4 and Vector2(p.x-centre.x,p.z-centre.z).length()<1.8:mesh.hide();continue
  if mesh.material_override==w.materials.get("paper") and absf(p.y-.67)<.01 and Vector2(p.x-centre.x,p.z-centre.z).length()<1.:
   mesh.hide();_drawing(party,mesh,sheet);sheet+=1
 var table: Node3D=(load("res://assets/party-v4120/craft-table.glb") as PackedScene).instantiate();table.name="CraftTable";party.add_child(table);table.position=centre
 for seat in seats:
  var stool: Node3D=(load("res://assets/party-v4120/kid-stool.glb") as PackedScene).instantiate();stool.name="KidStool";party.add_child(stool);stool.position=seat.p
  stool.rotation.y=atan2(centre.x-seat.p.x,centre.z-seat.p.z)
  var colour:Color=(seat.m as StandardMaterial3D).albedo_color if seat.m is StandardMaterial3D else Color("c9a245")
  for part: MeshInstance3D in stool.find_children("*","MeshInstance3D",true,false):
   for i in range(part.mesh.get_surface_count()):
    var m:=part.mesh.surface_get_material(i) as StandardMaterial3D
    if m and m.resource_name=="StoolSeat":
     var tinted:=m.duplicate() as StandardMaterial3D;tinted.albedo_color=colour;part.set_surface_override_material(i,tinted)
 set_meta("craft_stools",seats.size());set_meta("craft_sheets",sheet)

func _drawing(parent: Node3D,old: MeshInstance3D,index: int) -> void:
 var paper:=MeshInstance3D.new();paper.name="ChildDrawingSheet";var quad:=PlaneMesh.new();quad.size=Vector2(.28,.32);paper.mesh=quad
 var m:=ShaderMaterial.new();m.shader=load("res://assets/child-art-v382/aged-paper.gdshader")
 m.set_shader_parameter("drawings",load("res://assets/child-art-v382/crayon-atlas.png"));m.set_shader_parameter("cell",Vector2(index%3,(index/3)%3))
 m.set_shader_parameter("age",.85);m.set_shader_parameter("seed",float(index))
 paper.material_override=m;parent.add_child(paper);paper.position=old.position+Vector3(0,.003,0);paper.rotation=old.rotation

# 4.12.0: interlocking foam puzzle mats over the bare concrete of the southern
# play area (ball pit, slide, crocodile). Reception and corridors keep their
# concrete; the rubber safety floor under the climbing frame lies above them.
const MAT_ZONE:=Rect2(-3.6,1.6,23.2,15.3)
func _play_mats() -> void:
 var plane:=PlaneMesh.new();plane.size=MAT_ZONE.size
 var mats:=MeshInstance3D.new();mats.name="FoamPuzzleMats";mats.mesh=plane
 var shader:=ShaderMaterial.new();shader.shader=load("res://assets/look-v4120/playmat.gdshader");mats.material_override=shader
 mats.position=Vector3(MAT_ZONE.get_center().x,.017,MAT_ZONE.get_center().y);mats.set_meta("foot_surface","rubber");add_child(mats)
 # A worn aluminium edge strip where the mats meet the concrete.
 var trim:=w.mat(Color("8d918c"),null,.4,.85)
 w.box(self,Vector3(MAT_ZONE.position.x,.019,MAT_ZONE.get_center().y),Vector3(.05,.01,MAT_ZONE.size.y),trim)
 w.box(self,Vector3(MAT_ZONE.get_center().x,.019,MAT_ZONE.position.y),Vector3(MAT_ZONE.size.x,.01,.05),trim)

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

# 4.12.0 arcade lounge: both cabinets become modelled machines with printed
# side art, T-moulding, bezel, control panel and a lit coin door
# (tools/model-after-play-arcade-v4120.py). The animated CRT picture and the
# marquee print stay; the old collision shell stays as it was.
func _arcade_cabinets() -> void:
 if not w.details:return
 for id in ["arcade","orbit"]:
  var root:=w.details.find_child("Arcade_"+id,true,false) as Node3D
  if not root:continue
  for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
   if not (mesh.material_override is ShaderMaterial or mesh.name=="PrintedLabel" or mesh.get_parent().name=="PrintedLabel"):mesh.hide()
  var model: Node3D=(load("res://assets/arcade-v4120/arcade-cabinet-%s.glb"%id) as PackedScene).instantiate();model.name="ModelledArcadeCabinet";root.add_child(model)
  root.set_meta("modelled_cabinet",true)

# 4.12.0 prize cabinet: the stacked-sphere toys become plush bunnies with a
# floppy ear, button eyes and a stitched smile, in the old toy colours.
func _prize_bunnies() -> void:
 var cabinet:=w.details.find_child("ArcadePrizeCabinet",true,false) as Node3D if w.details else null
 if not cabinet:return
 var scene:=load("res://assets/arcade-v4120/prize-bunny.glb") as PackedScene
 var fuzz:=load("res://assets/pbr/fabric_pattern_07/normal.jpg")
 var colours:=[Color("b39a5e"),Color("6c8f87"),Color("a8675e")]
 var index:=0
 for toy in cabinet.get_children():
  if not toy is Node3D or toy.find_children("*","MeshInstance3D",false,false).size()<4:continue
  if not toy.get_child(0).mesh is SphereMesh:continue
  for mesh: MeshInstance3D in toy.find_children("*","MeshInstance3D",false,false):mesh.hide()
  var column:=roundi((toy.position.x+.4)/.26)
  var bunny: Node3D=scene.instantiate();bunny.name="PlushPrizeBunny";toy.add_child(bunny)
  bunny.rotation=Vector3(0,(index%3-1)*.25,(index%2*2-1)*.06);bunny.scale=Vector3.ONE*(1.05+(index%3)*.06)
  for mesh: MeshInstance3D in bunny.find_children("*","MeshInstance3D",true,false):
   for i in range(mesh.mesh.get_surface_count()):
    var m:=mesh.get_active_material(i) as StandardMaterial3D
    if m and m.resource_name=="PlushFur":
     var fur:=m.duplicate() as StandardMaterial3D;fur.albedo_color=colours[column%3];fur.normal_enabled=true;fur.normal_texture=fuzz;fur.normal_scale=.6
     fur.uv1_triplanar=true;fur.uv1_scale=Vector3.ONE*14;fur.roughness=1.;fur.metallic_specular=.2;fur.rim_enabled=true;fur.rim=.22;fur.rim_tint=.7
     mesh.set_surface_override_material(i,fur)
  index+=1
 cabinet.set_meta("plush_prizes",index)

# 4.12.0 snack bar: modelled slush machines with clear bowls, cooling drum,
# auger and dried syrup crust in their old flavours, and a chrome napkin
# dispenser instead of the stacked blocks (tools/model-after-play-slush-v4120.py).
func _snack_machines() -> void:
 var snack: Node3D=w.life.snack if w.life else null
 if not snack:return
 var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.55,.64,.62,.09);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
 glass.roughness=.06;glass.metallic_specular=.9;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 var machines:=0
 for machine in snack.get_children():
  if not machine.get_meta("slush_dispenser",false):continue
  for mesh: MeshInstance3D in machine.find_children("*","MeshInstance3D",true,false):mesh.hide()
  var model: Node3D=(load("res://assets/snack-v4120/slush-machine.glb") as PackedScene).instantiate();model.name="ModelledSlushMachine";machine.add_child(model)
  var flavour:=Color("b8483a") if "Cherry" in str(machine.name) else Color("86a650")
  for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   for i in range(mesh.mesh.get_surface_count()):
    var m:=mesh.get_active_material(i) as StandardMaterial3D
    if not m:continue
    if m.resource_name=="SlushBowl":mesh.set_surface_override_material(i,glass);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    elif m.resource_name=="SlushCrust":
     var c:=m.duplicate() as StandardMaterial3D;c.albedo_color=flavour;c.albedo_texture=load("res://assets/aged-plaster.png");c.roughness=.8;c.clearcoat_enabled=true;c.clearcoat=.3
     mesh.set_surface_override_material(i,c)
  machines+=1
 for child in snack.get_children():
  var mesh:=child as MeshInstance3D
  if mesh and absf(mesh.position.x+1.72)<.01 and absf(mesh.position.z-.30)<.01 and mesh.position.y>1. and mesh.position.y<1.2:mesh.hide()
 var napkins: Node3D=(load("res://assets/snack-v4120/napkin-dispenser.glb") as PackedScene).instantiate();napkins.name="NapkinDispenser";snack.add_child(napkins);napkins.position=Vector3(-1.72,1.02,.30);napkins.rotation.y=.2
 snack.set_meta("modelled_slush",machines)
