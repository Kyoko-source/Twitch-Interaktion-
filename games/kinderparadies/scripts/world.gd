class_name PlayWorld
extends Node3D

const NAVY := Color("294d70")
const CORAL := Color("974442")
const GOLD := Color("b49842")
const TEAL := Color("3c7370")
var props := {}
var materials := {}
var environment: WorldEnvironment
var practicals: Array[OmniLight3D] = []
var party_light: OmniLight3D
var balls: MultiMeshInstance3D
var ball_transforms: Array[Transform3D] = []
var ball_render_transforms: Array[Transform3D] = []
var current := "none"
var clock := 0.0
var zones := {"Empfang":Vector3(-7,0,4.4),"Bällebad":Vector3(9.3,0,12.2),"Party Raum":Vector3(12,0,-6.4),"Wartungsgang":Vector3(-7.5,0,-7.2),"Küche":Vector3(-13.8,0,-17.4),"Kino":Vector3(-3,0,-17.65)}
var source: AudioStreamPlayer3D
var mesh_cache := {}
var last_sound := 0
var atmosphere: NurseryAtmosphere
var native_art: NativeArt
var playground: ExpandedPlayground
var tubes: CrawlTubes
var soundscape: NightSoundscape
var encounters: NightEncounters
var annex: ServiceAnnex
var room_horror: RoomHorror
var archive: LostArchive
var terrors: NightTerrors
var server_room: ServiceRoom
var polish: AfterPlayPolish
var backstage: BackstageExpansion

func bevel(size: Vector3) -> ArrayMesh:
 var key:=str(size)
 if mesh_cache.has(key): return mesh_cache[key]
 var radius:=minf(.055,minf(size.x,minf(size.y,size.z))*.24)
 var inner:=size*.5-Vector3.ONE*radius
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
 var axes: Array[Vector3]=[Vector3.RIGHT,Vector3.UP,Vector3.BACK]
 for axis in range(3):
  for sign_value in [-1,1]:
   var normal: Vector3=axes[axis]*sign_value;var u:=axes[(axis+1)%3];var v:=axes[(axis+2)%3];var half_u:=size[(axis+1)%3]*.5;var half_v:=size[(axis+2)%3]*.5
   var us: Array[float]=[-half_u,-half_u+radius*.3,-half_u+radius,half_u-radius,half_u-radius*.3,half_u]
   var vs: Array[float]=[-half_v,-half_v+radius*.3,-half_v+radius,half_v-radius,half_v-radius*.3,half_v]
   var offset:=vertices.size()
   for y in range(6):
    for x in range(6):
     var point: Vector3=normal*size[axis]*.5+u*us[x]+v*vs[y];var nearest: Vector3=point.clamp(-inner,inner);var n: Vector3=(point-nearest).normalized()
     vertices.append(nearest+n*radius);normals.append(n);uvs.append(Vector2(us[x]/size[(axis+1)%3]+.5,vs[y]/size[(axis+2)%3]+.5))
   for y in range(5):
    for x in range(5):
     var a:=offset+y*6+x;var b:=a+1;var c:=a+6;var d:=c+1
     if sign_value>0: indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
     else: indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh_cache[key]=result;return result

func mat(color: Color, texture: Texture2D=null, roughness: float=.65, metal: float=0.0) -> StandardMaterial3D:
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=roughness;material.metallic=metal
 if texture: material.albedo_texture=texture;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return material

func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, solid: bool=false) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.mesh=bevel(size);mesh.material_override=material;mesh.position=pos;parent.add_child(mesh)
 if solid and parent==self and material==materials.get("wall"): mesh.set_meta("architecture_wall",true)
 if solid:
  var body:=StaticBody3D.new();body.name="Solid";var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=size;shape.shape=bounds;body.add_child(shape);mesh.add_child(body)
  mesh.set_meta("solid_visual",true)
 return mesh

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=14 if OS.has_feature("web") else 32;mesh.mesh=shape;mesh.material_override=material;mesh.position=(a+b)*.5;parent.add_child(mesh)
 var direction:=(b-a).normalized()
 if absf(direction.dot(Vector3.UP))<.999: mesh.quaternion=Quaternion(Vector3.UP,direction)
 return mesh

func sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=radius;shape.height=radius*2;shape.radial_segments=16 if OS.has_feature("web") else 40;shape.rings=8 if OS.has_feature("web") else 20;mesh.mesh=shape;mesh.material_override=material;mesh.position=pos;parent.add_child(mesh);return mesh

func text(parent: Node3D, value: String, pos: Vector3, size: float, color: Color=Color("e6dbc1")) -> Label3D:
 var label:=Label3D.new();label.text=value;label.font_size=64;label.pixel_size=size/64;label.position=pos;label.modulate=color;label.outline_size=0;label.no_depth_test=false;label.shaded=true;label.alpha_cut=Label3D.ALPHA_CUT_DISCARD;parent.add_child(label);return label

func artwork(parent: Node3D, pos: Vector3, size: Vector2, texture: Texture2D, yaw: float=0, cell: int=-1) -> MeshInstance3D:
 var image:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size
 if cell>=0:
  var arrays:=quad.surface_get_arrays(0);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var offset:=Vector2(cell%2,floori(cell/2.0))*.5
  for i in range(uv.size()): uv[i]=offset+Vector2.ONE*.012+uv[i]*.476
  arrays[Mesh.ARRAY_TEX_UV]=uv;var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);image.mesh=geometry
 else: image.mesh=quad
 image.material_override=mat(Color("c5c0ac"),texture,.96);image.position=pos;image.rotation.y=yaw;parent.add_child(image)
 image.set_meta("mounted_art",true)
 # Separate frame, backing and opaque canvas avoid coplanar text/decal layers.
 box(image,Vector3(0,0,-.024),Vector3(size.x+.12,size.y+.12,.035),materials.wood)
 for side in [-1,1]:
  box(image,Vector3(side*(size.x*.5+.025),0,.012),Vector3(.055,size.y+.12,.06),materials.wood)
  box(image,Vector3(0,side*(size.y*.5+.025),.012),Vector3(size.x+.12,.055,.06),materials.wood)
 return image

func mounted_sign(parent: Node3D, id: String, pos: Vector3, size: Vector2, yaw: float=0) -> MeshInstance3D:
 return artwork(parent,pos,size,load("res://assets/polish/"+id+".png"),yaw)

func painting(parent: Node3D, cell: int, pos: Vector3, size: Vector2, yaw: float=0) -> MeshInstance3D:
 return artwork(parent,pos,size,load("res://assets/polish/paintings.png"),yaw,cell)

func group(id: String) -> Node3D:
 var node:=Node3D.new();node.name=id;add_child(node);props[id]=node;return node

func lamp(pos: Vector3, color: Color, energy: float=1.4, distance: float=7.0) -> OmniLight3D:
 var light:=OmniLight3D.new();light.position=pos;light.light_color=color;light.light_energy=energy;light.omni_range=distance;light.omni_attenuation=1.25;add_child(light);practicals.append(light);return light

func build() -> void:
 var vinyl: Texture2D=load("res://assets/vinyl.png");var rubber: Texture2D=load("res://assets/floor.png")
 materials={"blue":mat(NAVY,vinyl,.28),"red":mat(CORAL,vinyl,.3),"gold":mat(GOLD,vinyl,.36),"teal":mat(TEAL,vinyl,.36),"wall":mat(Color("d8d1b9"),load("res://assets/paint.png"),.95),"dark":mat(Color("182127"),null,.65,.35),"metal":mat(Color("536169"),null,.32,.75),"wood":mat(Color("b2a28d"),load("res://assets/wood.png"),.48),"cream":mat(Color("c9c4a9"),vinyl,.7)}
 materials.wall.uv1_triplanar=true;materials.wall.uv1_scale=Vector3.ONE*.5
 materials.stitch=mat(Color("39342b"),null,.98)
 _environment();_architecture(rubber);_play_structure();_reception();_party_room();_service();_doors();_details()
 atmosphere=NurseryAtmosphere.new();add_child(atmosphere);atmosphere.build(self)
 _wall_paintings()
 playground=ExpandedPlayground.new();add_child(playground);playground.build(self)
 _enlarge_climbing_frame()
 if not OS.has_feature("web"):
  native_art=NativeArt.new();add_child(native_art);native_art.build(self)
 tubes=CrawlTubes.new();add_child(tubes);tubes.build(self)
 annex=ServiceAnnex.new();add_child(annex);annex.build(self)
 server_room=ServiceRoom.new();add_child(server_room);server_room.build(self)
 RoomDressing.build(self)
 room_horror=RoomHorror.new();add_child(room_horror);room_horror.build(self)
 terrors=NightTerrors.new();add_child(terrors);terrors.build(self)
 soundscape=NightSoundscape.new();add_child(soundscape);soundscape.build(self)
 source=AudioStreamPlayer3D.new();source.stream=load("res://assets/pipe.ogg");source.unit_size=3;source.max_distance=14;source.volume_db=-19;source.position=Vector3(7,2,-6);add_child(source)
 if native_art: source.bus="Interior"
 encounters=NightEncounters.new();add_child(encounters);encounters.build(self)
 archive=LostArchive.new();add_child(archive);archive.build(self)
 polish=AfterPlayPolish.new();add_child(polish);polish.build(self)
 if native_art: native_art.finish()
 backstage=BackstageExpansion.new();add_child(backstage);backstage.build(self)
 FootSurfaces.tag(self)

func _wall_paintings() -> void:
 var root:=group("wall_paintings")
 var placements: Array[Dictionary]=[
  {"cell":0,"pos":Vector3(6.65,2.8,-.3),"size":Vector2(2.8,3.7),"yaw":-PI/2},
  {"cell":0,"pos":Vector3(-9.99,2.8,12.5),"size":Vector2(3.0,3.8),"yaw":PI/2},
  {"cell":1,"pos":Vector3(19.59,2.9,11.8),"size":Vector2(3.7,3.9),"yaw":-PI/2},
  {"cell":2,"pos":Vector3(-9.99,4.6,5.6),"size":Vector2(3.4,2.5),"yaw":PI/2},
  {"cell":3,"pos":Vector3(19.59,3.6,4.3),"size":Vector2(3.5,3.6),"yaw":-PI/2}]
 for placement in placements:
  var quad:=QuadMesh.new();quad.size=placement.size;var arrays:=quad.surface_get_arrays(0);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var cell: int=placement.cell;var offset:=Vector2(cell%2,floori(cell/2.0))*.5
  for i in range(uv.size()): uv[i]=offset+Vector2.ONE*.004+uv[i]*.492
  arrays[Mesh.ARRAY_TEX_UV]=uv;var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material:=mat(Color("b8b4a2"),load("res://assets/polish/wall-motifs.png"),.98)
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
  material.normal_enabled=true;material.normal_texture=atmosphere.micro_normal;material.normal_scale=.12
  var mesh:=MeshInstance3D.new();mesh.mesh=geometry;mesh.material_override=material;mesh.position=placement.pos;mesh.rotation.y=placement.yaw;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mesh)

func _environment() -> void:
 environment=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("071014");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("738c8b");env.ambient_light_energy=.16;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.fog_enabled=true;env.fog_light_color=Color("35433b");env.fog_light_energy=.55;env.fog_density=.025;environment.environment=env;add_child(environment)
 var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("233a43");sky_material.sky_horizon_color=Color("8f8068");sky_material.ground_bottom_color=Color("101b22");sky_material.ground_horizon_color=Color("8f8068");sky.sky_material=sky_material;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY

func _architecture(rubber: Texture2D) -> void:
 # Collision top matches the visible tiles; the hidden backing mustn't z-fight them.
 box(self,Vector3(4.8,-.138,2.4),Vector3(30,.3,29.4),materials.dark,true).hide()
 # Four instanced tile materials keep the floor inexpensive to render.
 var colors: Array[Color]=[Color("38413e"),Color("3c423d"),Color("343d3b"),Color("41443e")]
 props.floor_tiles=[]
 for color_index in range(4):
  var transforms: Array[Transform3D]=[]
  for x in range(30):
   for z in range(29):
    if (x*7+z*3)%4==color_index: transforms.append(Transform3D(Basis.IDENTITY,Vector3(x-9.5,-.008,z-12)))
  var instance:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var tile:=BoxMesh.new();tile.size=Vector3(.987,.04,.987);mm.mesh=tile;mm.instance_count=transforms.size()
  for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
  instance.multimesh=mm;instance.material_override=mat(colors[color_index],rubber,.26,.16);add_child(instance)
  props.floor_tiles.append(instance)
 # A real opening to the archive replaces the western wall behind its door.
 box(self,Vector3(-10.2,3.7,-11.5),Vector3(.3,7.4,1.6),materials.wall,true)
 box(self,Vector3(-10.2,3.7,-7.675),Vector3(.3,7.4,2.85),materials.wall,true)
 box(self,Vector3(-10.2,4.95,-5.4),Vector3(.3,4.9,1.7),materials.wall,true)
 # Real delivery corridor opening, separate from the decision doors.
 box(self,Vector3(-10.2,3.7,1.975),Vector3(.3,7.4,13.05),materials.wall,true)
 box(self,Vector3(-10.2,3.7,13.7),Vector3(.3,7.4,6.8),materials.wall,true)
 box(self,Vector3(-10.2,5.1,9.4),Vector3(.3,4.6,1.8),materials.wall,true)
 box(self,Vector3(-10.2,4.95,-9.9),Vector3(.3,4.9,1.6),materials.wall,true)
 box(self,Vector3(19.8,3.7,2.4),Vector3(.3,7.4,29.4),materials.wall,true)
 box(self,Vector3(-9.8,3.7,-12.2),Vector3(.8,7.4,.3),materials.wall,true)
 box(self,Vector3(.2,3.7,-12.2),Vector3(13.2,7.4,.3),materials.wall,true)
 box(self,Vector3(11.625,3.7,-12.2),Vector3(9.65,7.4,.3),materials.wall,true)
 box(self,Vector3(18.975,3.7,-12.2),Vector3(1.65,7.4,.3),materials.wall,true)
 box(self,Vector3(17.3,5.2,-12.2),Vector3(1.7,4.4,.3),materials.wall,true)
 box(self,Vector3(-7.9,5.05,-12.2),Vector3(3,4.7,.3),materials.wall,true)
 box(self,Vector3(-9.75,3.7,17.2),Vector3(.9,7.4,.3),materials.wall,true)
 box(self,Vector3(6.55,3.7,17.2),Vector3(26.5,7.4,.3),materials.wall,true)
 box(self,Vector3(-8.0,5.05,17.2),Vector3(2.6,4.7,.3),materials.wall,true)
 box(self,Vector3(4.8,7.4,2.4),Vector3(30,.2,29.4),mat(Color("343a3b")),true)
 for x in [-10.01,19.61]:
  for strip in ([Vector2(-11.5,1.3),Vector2(-7.675,2.85),Vector2(1.975,13.05),Vector2(13.7,6.8)] if x<0 else [Vector2(2.4,29.1)]):
   box(self,Vector3(x,.12,strip.x),Vector3(.08,.23,strip.y),materials.dark)
   box(self,Vector3(x,1.1,strip.x),Vector3(.06,.045,strip.y),materials.teal)
 for z in [-10,-5,0,5,10,15]:
  box(self,Vector3(4.8,7.22,z),Vector3(29.8,.16,.14),materials.metal)
  tube(self,Vector3(-10,6.9,z),Vector3(19.6,6.9,z),.035,materials.dark)
 tube(self,Vector3(-7,6.72,17),Vector3(-7,6.72,-12),.22,materials.metal)
 for z in range(-11,11,2): tube(self,Vector3(-7.01,6.72,z),Vector3(-7.01,6.72,z+.05),.239,materials.dark)
 for pos in [Vector3(-5.5,6.02,-8),Vector3(-5.5,6.02,0),Vector3(-5.5,6.02,7),Vector3(12.4,6.0,11.4),Vector3(10.2,6.0,-7)]:
  box(self,Vector3(pos.x,7.285,pos.z),Vector3(.2,.03,.2),materials.dark)
  tube(self,Vector3(pos.x,7.28,pos.z),Vector3(pos.x,pos.y+.72,pos.z),.018,materials.dark)
  var stem:=tube(self,Vector3(pos.x,pos.y+.72,pos.z),Vector3(pos.x,pos.y+.31,pos.z),.018,materials.dark);stem.set_meta("basic_lamp_shade",true)
  var shade:=sphere(self,Vector3(pos.x,pos.y+.23,pos.z),.23,materials.metal);shade.scale.y=.35;shade.set_meta("basic_lamp_shade",true)
  var practical:=lamp(pos,Color("ffdb9e"),.65,8.5);practical.shadow_enabled=pos.z==0
 for z in [-10,-5,0,5,10,15]:
  for x in [-7.0,4.0,16.0]: tube(self,Vector3(x,7.30,z),Vector3(x,6.9,z),.014,materials.metal)
 for z in [-10,-5,0,5,10,15]: tube(self,Vector3(-7,7.30,z),Vector3(-7,6.72,z),.016,materials.rust if materials.has("rust") else materials.dark)
 # Room divider leaves an actual doorway into the party room.
 box(self,Vector3(6.8,3.7,-10.975),Vector3(.2,7.4,2.15),materials.wall,true)
 box(self,Vector3(6.8,3.7,-2.9),Vector3(.2,7.4,9.2),materials.wall,true)
 box(self,Vector3(6.8,5.2,-8.7),Vector3(.2,4.4,2.4),materials.wall,true)
 box(self,Vector3(13.3,3.7,1.6),Vector3(13,7.4,.2),materials.wall,true)
 var entry:=group("party_entry");entry.position=Vector3(6.8,0,-8.7)
 var timber:=mat(Color("7e705c"),load("res://assets/wood.png"),.85);timber.uv1_triplanar=true;timber.uv1_scale=Vector3.ONE*2
 for side in [-1,1]: box(entry,Vector3(0,1.5,side*1.2),Vector3(.34,3,.12),timber,true)
 box(entry,Vector3(0,3.03,0),Vector3(.34,.14,2.68),timber,true)
 entry.set_meta("clear_opening",AABB(Vector3(-.35,0,-1.14),Vector3(.7,2.96,2.28)))
 mounted_sign(self,"party",Vector3(6.61,3.55,-8.7),Vector2(1.35,.67),-PI/2)

func _play_structure() -> void:
 var structure:=group("structure")
 var palette: Array=[materials.blue,materials.red,materials.gold]
 for x in [-.3,2.6,5.5]:
  for z in [-5.5,-2.4,.7,3.8]:
   tube(structure,Vector3(x,.18,z),Vector3(x,4.65,z),.14,palette[(int(x+z+20))%3])
   box(structure,Vector3(x,2.32,z),Vector3(.28,4.64,.28),materials.dark,true).hide()
   for y in [1.8,3.8]:
    tube(structure,Vector3(x,y-.09,z),Vector3(x,y+.09,z),.165,materials.dark)
 for y in [.3,2.25,4.5]:
  for x in [-.3,5.5]:
   if x==-.3 and y==.3:
    tube(structure,Vector3(x,y,-5.5),Vector3(x,y,-1.7),.13,materials.blue);tube(structure,Vector3(x,y,-.3),Vector3(x,y,3.8),.13,materials.blue)
   elif x==5.5 and y==2.25: tube(structure,Vector3(x,y,-5.5),Vector3(x,y,2.6),.13,materials.blue)
   else: tube(structure,Vector3(x,y,-5.5),Vector3(x,y,3.8),.13,materials.blue if y<3 else materials.gold)
  for z in [-5.5,.7,3.8]:
   if z>=.7 and y<4:
    tube(structure,Vector3(-.3,y,z),Vector3(2.85,y,z),.13,materials.red)
    tube(structure,Vector3(4.5,y,z),Vector3(5.5,y,z),.13,materials.red)
   else: tube(structure,Vector3(-.3,y,z),Vector3(5.5,y,z),.13,materials.red if z>.5 else materials.gold)
 box(structure,Vector3(2.6,.2,-.85),Vector3(5.7,.18,9.2),materials.blue,true)
 # Actual upper-floor aperture, aligned with the slide launch instead of a
 # ramp visually descending through a continuous hidden platform collider.
 box(structure,Vector3(2.6,2.2,-2.35),Vector3(5.7,.18,6.2),materials.blue,true)
 box(structure,Vector3(1.3,2.2,2.25),Vector3(3.1,.18,3),materials.blue,true)
 box(structure,Vector3(4.975,2.2,2.25),Vector3(.95,.18,3),materials.blue,true)
 var nets:=group("nets");PlayGeometry.west_nets(self,nets)
 for z in [-3.4,-1.2,1.0]: PlayGeometry.arch(self,structure,z)
 var slide:=group("slide");PlayGeometry.slide(self,slide)
 props.play_threshold=PlayGeometry.entry_ramp(self,structure)
 var pit:=group("pit")
 for x in [-.7,5.8]: box(pit,Vector3(x,.35,6),Vector3(.25,.65,3.4),materials.blue,true)
 for z in [4.4,7.6]: box(pit,Vector3(2.55,.35,z),Vector3(6.5,.65,.25),materials.red,true)
 # A single instanced mesh for every ball, with per-instance colors.
 balls=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
 var ball_mesh:=SphereMesh.new();ball_mesh.radius=.14;ball_mesh.height=.28;ball_mesh.radial_segments=16 if OS.has_feature("web") else 24;ball_mesh.rings=10;mm.mesh=ball_mesh;mm.instance_count=360
 var material:=mat(Color.WHITE,null,.46);material.vertex_color_use_as_albedo=true;balls.material_override=material;balls.multimesh=mm;pit.add_child(balls)
 var rng:=RandomNumberGenerator.new();rng.seed=71;var colors: Array[Color]=[NAVY,CORAL,GOLD,TEAL,Color("b0a873")]
 for i in range(360):
  var p: Vector3=BallPacking.POSITIONS[i]
  var t:=Transform3D(Basis.IDENTITY,p);ball_transforms.append(t);ball_render_transforms.append(t);mm.set_instance_transform(i,t);mm.set_instance_color(i,colors[rng.randi_range(0,colors.size()-1)])
 var giant:=sphere(self,Vector3(2.2,1.3,6),1.2,materials.red);giant.visible=false;props.giant=giant
 var loose:=sphere(self,Vector3(-1.6,.17,4.8),.17,materials.gold);props.loose=loose
 # Keep a comfortable patrol passage between the structure and party-room wall.
 for part in [structure,nets,slide,pit]: part.position.x=-.6
 giant.position.x-=.6;loose.position.x-=.6

func _reception() -> void:
 var counter:=group("counter");counter.position=Vector3(-8.85,0,5.8)
 props.counter_base=box(counter,Vector3(0,.46,0),Vector3(.82,.92,2.7),materials.cream,true)
 props.counter_top=box(counter,Vector3(0,.96,0),Vector3(.96,.08,2.9),materials.wood,true)
 props.counter_top.set_meta("foot_surface","wood")
 # Staff stand behind the narrow counter on its west side. The screen, stand,
 # keyboard and cables share that orientation and all rest on the actual top.
 var pc:=Node3D.new();pc.name="ReceptionPC";pc.position=Vector3(0,1.025,-.35);pc.rotation.y=-PI/2;counter.add_child(pc)
 var pc_plastic:=mat(Color("6e746a"),load("res://assets/paint.png"),.78)
 box(pc,Vector3(0,.015,0),Vector3(.31,.03,.25),materials.dark)
 box(pc,Vector3(0,.07,-.025),Vector3(.075,.11,.07),materials.metal)
 var screen:=Node3D.new();screen.position=Vector3(0,.255,-.015);screen.rotation.x=-.07;pc.add_child(screen)
 box(screen,Vector3(0,0,-.085),Vector3(.42,.32,.24),pc_plastic)
 box(screen,Vector3(0,.012,.043),Vector3(.365,.245,.018),materials.dark)
 var display:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.32,.19);display.mesh=quad;display.position=Vector3(0,.012,.056);screen.add_child(display)
 var display_mat:=mat(Color("9aaf92"),load("res://assets/annex/terminal.png"),.4);display_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;display.material_override=display_mat
 var power:=mat(Color("72995b"));power.emission_enabled=true;power.emission=Color("72995b");sphere(screen,Vector3(.155,-.132,.05),.006,power)
 for i in range(7): box(screen,Vector3(0,-.12+i*.035,-.209),Vector3(.31,.012,.015),materials.dark)
 box(pc,Vector3(0,.025,.255),Vector3(.39,.033,.135),materials.cream)
 for row in range(3):
  for col in range(11): box(pc,Vector3(-.165+col*.032,.044,.21+row*.032),Vector3(.026,.009,.025),materials.dark)
 for i in range(14):
  var a:=i/13.0;var b:=(i+1)/13.0
  tube(counter,Vector3(.12,1.04-a*.7,-.52-a*.35),Vector3(.12,1.04-b*.7,-.52-b*.35),.008,materials.dark)
 props.hours=mounted_sign(self,"hours",Vector3(-9.97,2.1,7.6),Vector2(1.3,.75),PI/2)
 var shelves:=group("reception_shelves")
 var car:=group("car");car.position=Vector3(-5.2,0,5.5)
 box(car,Vector3(0,.25,0),Vector3(.7,.32,1.1),materials.red)
 var hood:=sphere(car,Vector3(0,.46,-.12),.34,materials.gold);hood.scale=Vector3(1,.75,1.15)
 var seat:=sphere(car,Vector3(0,.46,.32),.23,materials.dark);seat.scale=Vector3(.95,.33,1.1)
 var backrest:=sphere(car,Vector3(0,.6,.48),.22,materials.red);backrest.scale=Vector3(1,1,.3)
 for side in [-1,1]:
  tube(car,Vector3(side*.27,.28,-.55),Vector3(side*.27,.28,.55),.065,materials.metal)
  sphere(car,Vector3(side*.23,.44,-.445),.07,materials.cream)
 tube(car,Vector3(0,.45,0),Vector3(0,.7,-.05),.023,materials.metal)
 var steering:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.095;torus.outer_radius=.12;torus.rings=24;torus.ring_segments=8;steering.mesh=torus;steering.material_override=materials.dark;steering.position=Vector3(0,.7,-.05);steering.rotation.x=PI/3;car.add_child(steering)
 for x in [-.4,.4]:
  for z in [-.35,.35]:
   tube(car,Vector3(x-.05,.18,z),Vector3(x+.05,.18,z),.17,materials.dark)
   tube(car,Vector3(x-.055,.18,z),Vector3(x+.055,.18,z),.085,materials.metal)
 var face:=group("clock");face.position=Vector3(-9.98,2.8,4);face.rotation.y=PI/2
 tube(face,Vector3(0,0,-.03),Vector3(0,0,.015),.37,materials.metal)
 tube(face,Vector3(0,0,.02),Vector3(0,0,.04),.32,materials.cream)
 for i in range(12):
  var a:=float(i)*TAU/12;var mark:=box(face,Vector3(sin(a)*.27,cos(a)*.27,.07),Vector3(.017,.055,.01),materials.dark);mark.rotation.z=-a
 var hand:=Node3D.new();face.add_child(hand);box(hand,Vector3(0,.105,.08),Vector3(.018,.21,.01),materials.dark);props.clock_hand=hand
 var hour:=box(face,Vector3(-.07,.05,.075),Vector3(.16,.025,.01),materials.dark);hour.rotation.z=-.5

func _party_room() -> void:
 var table:=group("party_table");table.position.x=1.7
 box(table,Vector3(8.5,.78,-7),Vector3(2.1,.12,3.1),materials.cream,true)
 for x in [7.65,9.35]:
  for z in [-8.25,-5.75]: box(table,Vector3(x,.37,z),Vector3(.09,.75,.09),materials.metal)
 var chairs:=group("chairs")
 chairs.reparent(table,false)
 for i in range(6):
  var chair:=Node3D.new();chair.position=Vector3(7.25 if i<3 else 9.75,0,-8.05+(i%3)*1.05);chairs.add_child(chair)
  chair.rotation.y=-PI/2 if i<3 else PI/2
  box(chair,Vector3(0,.42,0),Vector3(.48,.09,.48),materials.gold if i%2==0 else materials.teal,true)
  box(chair,Vector3(0,.7,.23),Vector3(.48,.5,.07),materials.red,true)
  for x in [-.18,.18]:
   for z in [-.18,.18]: box(chair,Vector3(x,.2,z),Vector3(.045,.4,.045),materials.metal)
 var balloons:=group("balloons")
 for i in range(3):
  var node:=Node3D.new();node.position=Vector3(7.5+i*.7,2.6,-9.7);balloons.add_child(node)
  var ball:=sphere(node,Vector3.ZERO,.23,[materials.red,materials.gold,materials.teal][i]);ball.scale.y=1.22
  tube(node,Vector3(0,-.24,0),Vector3(0,-2.55,0),.004,materials.cream)
  box(node,Vector3(0,-2.565,0),Vector3(.13,.07,.13),materials.dark)
 for i in range(4): tube(table,Vector3(8.3+i*.13,1.07,-7),Vector3(8.3+i*.13,1.24,-7),.014,materials.cream)
 party_light=lamp(Vector3(10.2,5.9,-7),Color("ffca88"),1.1,7)
 party_light.shadow_enabled=true
 painting(self,1,Vector3(8.5,2.1,-11.96),Vector2(1.45,1.0))
 for i in range(12):
  var flag:=box(self,Vector3(7.1+i*.24,3,-11.98),Vector3(.17,.23,.01),materials.red if i%2==0 else materials.gold);flag.rotation.z=.2 if i%2==0 else -.2

func _service() -> void:
 props.mural=painting(self,0,Vector3(-9.96,2.2,-2.3),Vector2(3.8,2.55),PI/2)
 var extinguisher:=group("extinguisher");extinguisher.position=Vector3(-9.89,.85,-7.5)
 tube(extinguisher,Vector3(0,0,0),Vector3(0,.5,0),.11,materials.red);tube(extinguisher,Vector3(0,.5,0),Vector3(.13,.5,0),.025,materials.dark)
 var stars:=group("stars")
 for i in range(7):
  var mesh:=MeshInstance3D.new();var points:=PackedVector3Array();var angles:=[]
  for p in range(10):
   var a:=p*TAU/10-PI/2;angles.append(Vector3(cos(a),sin(a),0)*(.35 if p%2==0 else .16))
  for p in range(10): points.append(Vector3.ZERO);points.append(angles[p]);points.append(angles[(p+1)%10])
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points
  var normals:=PackedVector3Array();normals.resize(points.size());normals.fill(Vector3.FORWARD);arrays[Mesh.ARRAY_NORMAL]=normals
  var star_mesh:=ArrayMesh.new();star_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.mesh=star_mesh
  var material: StandardMaterial3D=materials.gold.duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=material
  mesh.position=Vector3(-8.7+i*1.75,4.25,-12.0);stars.add_child(mesh)

func _doors() -> void:
 for i in range(2):
  var x:=-4.3+i*2.15;var red:=i==1;var color:=Color("bd4940") if red else Color("499a73")
  var body:=StaticBody3D.new();body.position=Vector3(x,1.45,-11.98);body.set_meta("interaction","red" if red else "green");add_child(body)
  var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.5,2.9,.14);collision.shape=shape;body.add_child(collision)
  var leaf:=Node3D.new();leaf.position.x=-.75;body.add_child(leaf);props["door_red" if red else "door_green"]=leaf
  box(leaf,Vector3(.75,0,0),Vector3(1.5,2.9,.13),mat(color*.55,null,.4,.25))
  for dx in [-.8,.8]: box(body,Vector3(dx,0,.04),Vector3(.11,3.05,.2),materials.dark)
  box(body,Vector3(0,1.52,.04),Vector3(1.7,.13,.2),materials.dark)
  box(leaf,Vector3(.75,.15,.08),Vector3(.28,1.2,.015),materials.metal)
  box(leaf,Vector3(1.25,-.2,.12),Vector3(.23,.06,.1),materials.metal)
  var glow:=mat(color);glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=1.7
  box(body,Vector3(0,1.85,0),Vector3(1.6,.38,.12),glow)
  mounted_sign(body,"red" if red else "green",Vector3(0,1.85,.09),Vector2(1.4,.29))
  lamp(Vector3(x,3.6,-11),color,1.1,4)

func _details() -> void:
 # Plaques, paper forms, bins, inspection marks and handrails give scale.
 for z in [-8,-2,4,10.6]:
  box(self,Vector3(-9.99,2.9,z),Vector3(.045,.28,.14),materials.metal)
  lamp(Vector3(-9.75,2.9,z),Color("e8cf9b"),.35,3.5)
 for z in [2,6]:
  tube(self,Vector3(-2.6,.6,z),Vector3(-2.6,.6,z+1.4),.035,materials.metal)
  for zz in [z,z+1.4]: tube(self,Vector3(-2.6,0,zz),Vector3(-2.6,.6,zz),.035,materials.metal)
 var paper:=mat(Color("d5cab2"),load("res://assets/floor.png"),.95)
 var counter: Node3D=props.counter
 for i in range(3):
  var sheet:=box(counter,Vector3(.08,1.005,.1+i*.22),Vector3(.26,.005,.32),paper);sheet.rotation.y=i*.15
  for row in range(4): box(counter,Vector3(.08,1.009,.02+i*.22+row*.045),Vector3(.18,.001,.005),materials.dark)
 tube(counter,Vector3(.21,1,.68),Vector3(.21,1.12,.68),.045,materials.metal)
 for i in range(4): tube(counter,Vector3(.18+i*.02,1.05,.68),Vector3(.18+i*.02,1.25,.68),.005,materials.gold if i%2 else materials.red)
 tube(self,Vector3(-8.1,0,8.7),Vector3(-8.1,.55,8.7),.23,materials.dark)
 var lid:=sphere(self,Vector3(-8.1,.55,8.7),.25,materials.metal);lid.scale.y=.2
 for z in [14.7]:
  mounted_sign(self,"rules",Vector3(-9.96,1.95,z),Vector2(.65,.4),PI/2)
 # Keep the cable run above the archive lintel, never across the moving leaf.
 for y in [3.7]:
  tube(self,Vector3(-9.85,y,-10.5),Vector3(-9.85,y,-8.7),.018,materials.metal)
  box(self,Vector3(-9.85,y,-9.6),Vector3(.2,.08,.4),materials.dark)
 mounted_sign(self,"duty",Vector3(-5.4,3.4,16.98),Vector2(1.65,.85),PI)
 for i in range(3): box(self,Vector3(18.8,.23,8.4-i*.55),Vector3(.5,.45,.5),[materials.blue,materials.red,materials.gold][i],true)

func set_anomaly(id: String) -> void:
 id=PatrolState.REPLACEMENTS.get(id,id)
 annex.configure(id)
 tubes.set_anomaly(id)
 current=id;clock=0
 atmosphere.anomaly(id)
 encounters.configure(id)
 terrors.configure(id)
 backstage.configure(id)
 if native_art: native_art.anomaly(id)
 # Fresh world per round means every normal state starts from the exact same layout.
 if id=="chair_ceiling":
  for chair in props.chairs.get_children(): chair.position.y=6.8;chair.rotation.x=PI
 elif id=="ball_giant": props.giant.visible=true
 elif id=="balls_missing": balls.visible=false
 elif id=="mural_missing": props.mural.visible=false
 elif id=="car_giant": props.car.scale=Vector3.ONE*2.6
 elif id=="car_missing": props.car.visible=false
 elif id=="lights_red":
  for light in practicals: light.light_color=Color("e22c28")
 elif id=="party_dark":
  party_light.light_energy=0
  for light in polish.party_mascot.get_parent().find_children("*","SpotLight3D",true,false): light.light_energy=0
 elif id=="balloons_many":
  for i in range(17):
   var balloon: Node3D=props.balloons.get_child(i%3).duplicate();balloon.position=Vector3(7.3+(i%4)*.7,1.8+(i%3)*.55,-9.8+floori(i/4.0)*.8);props.balloons.add_child(balloon)
 elif id=="balloons_floor":
  for balloon in props.balloons.get_children(): balloon.position.y=.3;balloon.rotation.x=PI
 elif id=="net_missing":
  props.nets.visible=false
  for net in get_tree().get_nodes_in_group("safety_nets"):
   if is_ancestor_of(net):
    net.hide()
    for body in net.find_children("*","StaticBody3D",true,false): body.collision_layer=0
 elif id=="star_giant": props.stars.get_child(0).scale=Vector3.ONE*4

func tick(delta: float, active: bool) -> void:
 annex.tick(delta,active)
 atmosphere.tick(delta,active)
 playground.tick(active)
 if native_art: native_art.tick(delta,active)
 room_horror.tick(delta,active)
 if not active: return
 clock+=delta
 props.clock_hand.rotation.z=clock*(-2.5 if current=="clock_fast" else -.004)
 if current=="balls_float":
  for i in range(0,360,3):
   var t:=ball_transforms[i];t.origin.y+=1.0+sin(clock*.7)*.25;ball_render_transforms[i]=t;balls.multimesh.set_instance_transform(i,t)

func brightness(value: float) -> void:
 environment.environment.tonemap_exposure=value

func quality(value: int) -> void:
 atmosphere.quality(value)
 if native_art: native_art.quality(value)
 backstage.quality(value)
 for light in practicals: light.shadow_enabled=value>0 and (light==party_light or light.has_meta("shadow_practical") or light.has_meta("kitchen_flicker") or light.position.distance_to(Vector3(-5.5,4,0))<.1)

func open_door(red: bool) -> void:
 var leaf: Node3D=props["door_red" if red else "door_green"]
 create_tween().tween_property(leaf,"rotation:y",-1.15,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _enlarge_climbing_frame() -> void:
 for id in ["structure","nets","slide"]:
  props[id].scale=Vector3(1.15,1.3,1.12)
  props[id].position.x=-1.8
 # Ball pit stays low enough to jump into. It grows with the larger frame.
 props.pit.scale=Vector3(1.15,1,1.12);props.pit.position.x=-1.8
 props.giant.position=Vector3(1.38,1.3,6.7)
