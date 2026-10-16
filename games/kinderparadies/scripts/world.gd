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
var current := "none"
var clock := 0.0
var zones := {"Empfang":Vector3(-7,0,4.4),"Bällebad":Vector3(4.5,0,7.0),"Partyraum":Vector3(8.6,0,-6.4),"Wartungsgang":Vector3(-7.5,0,-7.2)}
var source: AudioStreamPlayer3D
var mesh_cache := {}
var last_sound := 0
var atmosphere: NurseryAtmosphere

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
 if solid:
  var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=size;shape.shape=bounds;body.position=pos;body.add_child(shape);parent.add_child(body)
 return mesh

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=14;mesh.mesh=shape;mesh.material_override=material;mesh.position=(a+b)*.5;parent.add_child(mesh)
 var direction:=(b-a).normalized()
 if absf(direction.dot(Vector3.UP))<.999: mesh.quaternion=Quaternion(Vector3.UP,direction)
 return mesh

func sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=radius;shape.height=radius*2;shape.radial_segments=16;shape.rings=8;mesh.mesh=shape;mesh.material_override=material;mesh.position=pos;parent.add_child(mesh);return mesh

func text(parent: Node3D, value: String, pos: Vector3, size: float, color: Color=Color("e6dbc1")) -> Label3D:
 var label:=Label3D.new();label.text=value;label.font_size=64;label.pixel_size=size/64;label.position=pos;label.modulate=color;label.outline_size=0;label.no_depth_test=false;label.shaded=false;parent.add_child(label);return label

func group(id: String) -> Node3D:
 var node:=Node3D.new();node.name=id;add_child(node);props[id]=node;return node

func lamp(pos: Vector3, color: Color, energy: float=1.4, distance: float=7.0) -> OmniLight3D:
 var light:=OmniLight3D.new();light.position=pos;light.light_color=color;light.light_energy=energy;light.omni_range=distance;light.omni_attenuation=1.25;add_child(light);practicals.append(light);return light

func build() -> void:
 var vinyl: Texture2D=load("res://assets/vinyl.png");var rubber: Texture2D=load("res://assets/floor.png")
 materials={"blue":mat(NAVY,vinyl,.28),"red":mat(CORAL,vinyl,.3),"gold":mat(GOLD,vinyl,.36),"teal":mat(TEAL,vinyl,.36),"wall":mat(Color("d8d1b9"),load("res://assets/paint.png"),.95),"dark":mat(Color("182127"),null,.65,.35),"metal":mat(Color("536169"),null,.32,.75),"wood":mat(Color("b2a28d"),load("res://assets/wood.png"),.48),"cream":mat(Color("c9c4a9"),vinyl,.7)}
 materials.wall.uv1_triplanar=true;materials.wall.uv1_scale=Vector3.ONE*.5
 _environment();_architecture(rubber);_play_structure();_reception();_party_room();_service();_doors();_details()
 atmosphere=NurseryAtmosphere.new();add_child(atmosphere);atmosphere.build(self)
 source=AudioStreamPlayer3D.new();source.stream=load("res://assets/pipe.ogg");source.unit_size=3;source.max_distance=14;source.volume_db=-19;source.position=Vector3(7,2,-6);add_child(source)

func _environment() -> void:
 environment=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("071014");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("738c8b");env.ambient_light_energy=.16;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.fog_enabled=true;env.fog_light_color=Color("35433b");env.fog_light_energy=.55;env.fog_density=.025;environment.environment=env;add_child(environment)
 var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("233a43");sky_material.sky_horizon_color=Color("8f8068");sky_material.ground_bottom_color=Color("101b22");sky_material.ground_horizon_color=Color("8f8068");sky.sky_material=sky_material;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY

func _architecture(rubber: Texture2D) -> void:
 box(self,Vector3(0,-.138,-1),Vector3(21,.3,24),materials.dark,true)
 # Four instanced tile materials keep the floor inexpensive to render.
 var colors: Array[Color]=[Color("38413e"),Color("3c423d"),Color("343d3b"),Color("41443e")]
 for color_index in range(4):
  var transforms: Array[Transform3D]=[]
  for x in range(20):
   for z in range(23):
    if (x*7+z*3)%4==color_index: transforms.append(Transform3D(Basis.IDENTITY,Vector3(x-9.5,-.008,z-12)))
  var instance:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var tile:=BoxMesh.new();tile.size=Vector3(.987,.04,.987);mm.mesh=tile;mm.instance_count=transforms.size()
  for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
  instance.multimesh=mm;instance.material_override=mat(colors[color_index],rubber,.26,.16);add_child(instance)
 box(self,Vector3(-10.2,2.7,-1),Vector3(.3,5.4,24),materials.wall,true)
 box(self,Vector3(10.2,2.7,-1),Vector3(.3,5.4,24),materials.wall,true)
 box(self,Vector3(0,2.7,-12.2),Vector3(20.4,5.4,.3),materials.wall,true)
 box(self,Vector3(0,2.7,10.8),Vector3(20.4,5.4,.3),materials.wall,true)
 box(self,Vector3(0,5.4,-1),Vector3(20.5,.2,24),mat(Color("343a3b")),true)
 for side in [-1,1]:
  box(self,Vector3(side*10.01,.12,-1),Vector3(.08,.23,23.8),materials.dark)
  box(self,Vector3(side*10.01,1.1,-1),Vector3(.06,.045,23.8),materials.teal)
 for z in [-10,-5,0,5,10]:
  box(self,Vector3(0,5.08,z),Vector3(20.2,.18,.14),materials.metal)
  tube(self,Vector3(-10,4.9,z),Vector3(10,4.9,z),.035,materials.dark)
 tube(self,Vector3(-7,4.72,10),Vector3(-7,4.72,-12),.22,materials.metal)
 for z in range(-11,11,2): tube(self,Vector3(-7.01,4.72,z),Vector3(-7.01,4.72,z+.05),.239,materials.dark)
 for z in [-8,0,7]:
  tube(self,Vector3(-5.5,5.1,z),Vector3(-5.5,4.3,z),.02,materials.dark)
  var shade:=sphere(self,Vector3(-5.5,4.25,z),.23,materials.metal);shade.scale.y=.35
  var practical:=lamp(Vector3(-5.5,4,z),Color("ffdb9e"),.85,8.5)
  practical.shadow_enabled=z==0
 lamp(Vector3(5.8,4.3,-3),Color("66c9d0"),1.1,10)
 lamp(Vector3(-8,2.8,8),Color("78bbc7"),.7,6)
 # Room divider leaves an actual doorway into the party room.
 box(self,Vector3(6.8,2.5,-10),Vector3(.2,5,4.1),materials.wall,true)
 box(self,Vector3(6.8,2.5,-1),Vector3(.2,5,5.4),materials.wall,true)
 box(self,Vector3(6.8,4.25,-5.8),Vector3(.25,1.5,3.2),materials.wood,true)
 box(self,Vector3(8.5,2.5,1.6),Vector3(3.4,5,.2),materials.wall,true)
 var sign:=text(self,"PARTYRAUM",Vector3(6.62,3.3,-5.8),.19);sign.rotation.y=-PI/2

func _play_structure() -> void:
 var structure:=group("structure")
 var palette: Array=[materials.blue,materials.red,materials.gold]
 for x in [-.3,2.6,5.5]:
  for z in [-5.5,-2.4,.7,3.8]:
   tube(structure,Vector3(x,.18,z),Vector3(x,4.65,z),.14,palette[(int(x+z+20))%3])
   for y in [1.8,3.8]:
    tube(structure,Vector3(x,y-.09,z),Vector3(x,y+.09,z),.165,materials.dark)
 for y in [.3,2.25,4.5]:
  for x in [-.3,5.5]: tube(structure,Vector3(x,y,-5.5),Vector3(x,y,3.8),.13,materials.blue if y<3 else materials.gold)
  for z in [-5.5,.7,3.8]: tube(structure,Vector3(-.3,y,z),Vector3(5.5,y,z),.13,materials.red if z>.5 else materials.gold)
 for y in [.2,2.2]: box(structure,Vector3(2.6,y,-.85),Vector3(5.7,.18,9.2),materials.blue)
 box(structure,Vector3(2.6,1.5,-.85),Vector3(6.1,3,9.6),materials.dark,true).visible=false
 var shader:=Shader.new();shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){vec2 cell=fract(UV*vec2(32.0,28.0));if(min(cell.x,cell.y)>0.038)discard;ALBEDO=vec3(0.065,0.075,0.07);ROUGHNESS=0.9;}"
 var net_material:=ShaderMaterial.new();net_material.shader=shader;var nets:=group("nets")
 for x in [-.32,5.52]:
  var net:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(9.25,4.25);net.mesh=plane;net.material_override=net_material;net.rotation=Vector3(PI/2,PI/2,0);net.position=Vector3(x,2.4,-.85);nets.add_child(net)
 for z in [-5.52,3.82]:
  var net:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(5.8,4.2);net.mesh=plane;net.material_override=net_material;net.position=Vector3(2.6,2.4,z);nets.add_child(net)
 # Tube bridge, circular windows and raised access steps.
 tube(structure,Vector3(.3,3.2,-1),Vector3(4.9,3.2,-1),.65,materials.gold)
 for x in [.9,2.6,4.3]:
  var window:=sphere(structure,Vector3(x,3.2,-.4),.4,materials.dark);window.scale=Vector3(1,1,.15)
  var ring:=MeshInstance3D.new();var rim:=TorusMesh.new();rim.inner_radius=.37;rim.outer_radius=.44;rim.rings=24;rim.ring_segments=12;ring.mesh=rim;ring.material_override=materials.metal;ring.position=Vector3(x,3.2,-.34);ring.rotation.x=PI/2;structure.add_child(ring)
 var slide:=group("slide");var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(32):
  for col in range(8):
   for corner in [[0,0],[0,1],[1,0],[1,0],[0,1],[1,1]]:
    var t: float=(row+int(corner[1]))/32.0;var cross: float=(col+int(corner[0]))/8.0;var x:=(cross-.5)*1.25
    tool.set_uv(Vector2(cross,t));tool.add_vertex(Vector3(4.4+x,2.15*(1-t)*(1-t)+.3+pow(absf(x/.625),4)*.22,1.2+t*4.5))
 tool.generate_normals();var slide_mesh:=MeshInstance3D.new();slide_mesh.mesh=tool.commit();var slide_mat: StandardMaterial3D=materials.red.duplicate();slide_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;slide_mesh.material_override=slide_mat;slide.add_child(slide_mesh)
 for i in range(3): box(structure,Vector3(.15,.16+i*.13,4.5-i*.37),Vector3(.9,.32+i*.26,.4),palette[i])
 var pit:=group("pit")
 for x in [-.7,5.8]: box(pit,Vector3(x,.35,6),Vector3(.25,.65,3.4),materials.blue,true)
 for z in [4.4,7.6]: box(pit,Vector3(2.55,.35,z),Vector3(6.5,.65,.25),materials.red,true)
 # A single instanced mesh for every ball, with per-instance colors.
 balls=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
 var ball_mesh:=SphereMesh.new();ball_mesh.radius=.14;ball_mesh.height=.28;ball_mesh.radial_segments=12;ball_mesh.rings=6;mm.mesh=ball_mesh;mm.instance_count=360
 var material:=mat(Color.WHITE,null,.23);material.vertex_color_use_as_albedo=true;balls.material_override=material;balls.multimesh=mm;pit.add_child(balls)
 var rng:=RandomNumberGenerator.new();rng.seed=71;var colors: Array[Color]=[NAVY,CORAL,GOLD,TEAL,Color("b0a873")]
 for i in range(360):
  var p:=Vector3(rng.randf_range(-.4,5.5),rng.randf_range(.22,.46),rng.randf_range(4.65,7.35));var t:=Transform3D(Basis.IDENTITY,p);ball_transforms.append(t);mm.set_instance_transform(i,t);mm.set_instance_color(i,colors[i%colors.size()])
 var giant:=sphere(self,Vector3(2.2,1.3,6),1.2,materials.red);giant.visible=false;props.giant=giant
 var loose:=sphere(self,Vector3(-1.6,.17,4.8),.17,materials.gold);props.loose=loose
 # Keep a comfortable patrol passage between the structure and party-room wall.
 for part in [structure,nets,slide,pit]: part.position.x=-.6
 giant.position.x-=.6;loose.position.x-=.6

func _reception() -> void:
 box(self,Vector3(-8.45,.56,5.4),Vector3(2.65,1.12,4.5),materials.cream,true)
 box(self,Vector3(-8.45,1.15,5.4),Vector3(2.85,.13,4.7),materials.wood)
 box(self,Vector3(-8.4,1.45,4.8),Vector3(.58,.42,.07),materials.dark)
 text(self,"NACHTDIENST",Vector3(-8.38,1.47,4.85),.075)
 var hours:=text(self,"KINDERPARADIES\n10:00 – 18:00",Vector3(-9.98,2.1,7.6),.18);hours.rotation.y=PI/2;props.hours=hours
 for z in [1.4,2.6]:
  box(self,Vector3(-9.4,1.1,z),Vector3(1.05,2.1,1.1),materials.wood,true)
  for y in [.4,.95,1.5,2]: box(self,Vector3(-9.35,y,z),Vector3(1.13,.06,1.12),materials.cream)
  for y in [.65,1.2,1.75]: box(self,Vector3(-9.35,y,z),Vector3(1.13,.5,.04),materials.teal)
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
 box(self,Vector3(8.5,.78,-7),Vector3(2.1,.12,3.1),materials.cream,true)
 for x in [7.65,9.35]:
  for z in [-8.25,-5.75]: box(self,Vector3(x,.37,z),Vector3(.09,.75,.09),materials.metal)
 var chairs:=group("chairs")
 for i in range(6):
  var chair:=Node3D.new();chair.position=Vector3(7.25 if i<3 else 9.75,0,-8.05+(i%3)*1.05);chairs.add_child(chair)
  box(chair,Vector3(0,.42,0),Vector3(.48,.09,.48),materials.gold if i%2==0 else materials.teal)
  box(chair,Vector3(0,.7,.23),Vector3(.48,.5,.07),materials.red)
  for x in [-.18,.18]:
   for z in [-.18,.18]: box(chair,Vector3(x,.2,z),Vector3(.045,.4,.045),materials.metal)
 var balloons:=group("balloons")
 for i in range(3):
  var node:=Node3D.new();node.position=Vector3(7.5+i*.7,2.6,-9.7);balloons.add_child(node)
  var ball:=sphere(node,Vector3.ZERO,.23,[materials.red,materials.gold,materials.teal][i]);ball.scale.y=1.22
  tube(node,Vector3(0,-.24,0),Vector3(0,-1.6,0),.004,materials.cream)
 for i in range(4): tube(self,Vector3(8.3+i*.13,1.07,-7),Vector3(8.3+i*.13,1.24,-7),.014,materials.cream)
 party_light=lamp(Vector3(8.5,3.8,-7),Color("ffca88"),1.1,7)
 party_light.shadow_enabled=true
 text(self,"ALLES GUTE!",Vector3(8.4,3.2,-12.0),.23,Color("d4c28a"))
 for i in range(12):
  var flag:=box(self,Vector3(7.1+i*.24,3,-11.98),Vector3(.17,.23,.01),materials.red if i%2==0 else materials.gold);flag.rotation.z=.2 if i%2==0 else -.2

func _service() -> void:
 var mural:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(3.8,2.55);mural.mesh=plane;mural.material_override=mat(Color.WHITE,load("res://assets/mural.png"),.95);mural.position=Vector3(-7.1,2.2,-12.0);add_child(mural);props.mural=mural
 box(self,Vector3(-9.3,1.2,-7.6),Vector3(1.1,2.4,.8),materials.metal,true)
 for y in [.4,1.2,2]: box(self,Vector3(-9.3,y,-7.12),Vector3(.9,.035,.04),materials.dark)
 text(self,"WARTUNG",Vector3(-9.3,2.2,-7.12),.12)
 var extinguisher:=group("extinguisher");extinguisher.position=Vector3(-9.9,.65,-4.3)
 tube(extinguisher,Vector3(0,0,0),Vector3(0,.5,0),.11,materials.red);tube(extinguisher,Vector3(0,.5,0),Vector3(.13,.5,0),.025,materials.dark)
 var footprints:=group("footprints");footprints.visible=false
 for i in range(14):
  var mark:=sphere(footprints,Vector3(-7.3+(i%2)*.25,.035,-3.5-i*.48),.09,materials.dark);mark.scale=Vector3(.65,.06,1.6)
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
  text(body,"ANOMALIE" if red else "NORMAL",Vector3(0,1.85,.08),.19,Color("e8f3de"))
  lamp(Vector3(x,3.6,-11),color,1.1,4)

func _details() -> void:
 # Plaques, paper forms, bins, inspection marks and handrails give scale.
 for z in [-8,-2,4,9]:
  box(self,Vector3(-9.99,2.9,z),Vector3(.045,.28,.14),materials.metal)
  lamp(Vector3(-9.75,2.9,z),Color("e8cf9b"),.35,3.5)
 for z in [-2,2,6]:
  tube(self,Vector3(-2.6,.6,z),Vector3(-2.6,.6,z+1.4),.035,materials.metal)
  for zz in [z,z+1.4]: tube(self,Vector3(-2.6,0,zz),Vector3(-2.6,.6,zz),.035,materials.metal)
 var paper:=mat(Color("d5cab2"),load("res://assets/floor.png"),.95)
 for i in range(4):
  var sheet:=box(self,Vector3(-8.2,1.23,5+i*.25),Vector3(.32,.006,.42),paper);sheet.rotation.y=i*.17
  for row in range(4): box(self,Vector3(-8.21,1.236,4.88+i*.25+row*.055),Vector3(.23,.001,.008),materials.dark)
 # Reception details are actual geometry rather than a flat background image.
 for row in range(3):
  for key in range(10): box(self,Vector3(-8.7+key*.045,1.237,4.88+row*.04),Vector3(.037,.014,.03),materials.dark)
 tube(self,Vector3(-7.8,1.23,5.5),Vector3(-7.8,1.39,5.5),.055,materials.metal)
 for i in range(4): tube(self,Vector3(-7.84+i*.025,1.3,5.5),Vector3(-7.84+i*.025,1.53,5.5),.007,materials.gold if i%2 else materials.red)
 for z in [1.4,2.6]:
  for y in [.48,1.03,1.58]:
   for side in [-1,1]:
    var shoe:=sphere(self,Vector3(-9.28,y+.1,z+side*.25),.17,materials.blue if y<1 else materials.red);shoe.scale=Vector3(1.3,.4,.5)
    box(self,Vector3(-9.28,y+.025,z+side*.25),Vector3(.48,.04,.19),materials.cream)
 tube(self,Vector3(-8.1,0,8.7),Vector3(-8.1,.55,8.7),.23,materials.dark)
 var lid:=sphere(self,Vector3(-8.1,.55,8.7),.25,materials.metal);lid.scale.y=.2
 for z in [-4,1,6]:
  box(self,Vector3(-9.98,1.95,z),Vector3(.035,.65,.48),materials.wood)
  box(self,Vector3(-9.95,1.95,z),Vector3(.012,.55,.38),paper)
  var plaque:=text(self,"SPIELREGELN\nSOCKENPFLICHT\nKEIN ESSEN",Vector3(-9.93,1.95,z),.064);plaque.rotation.y=PI/2
 for x in [6.7,6.9]:
  box(self,Vector3(x,1.55,-7.55),Vector3(.14,3.1,.13),materials.wood)
  box(self,Vector3(x,1.55,-4.05),Vector3(.14,3.1,.13),materials.wood)
 var board:=text(self,"PARTYRAUM",Vector3(6.61,3.45,-5.8),.18);board.rotation.y=-PI/2
 for y in [1.3,2.5,3.7]:
  tube(self,Vector3(-9.85,y,-10.5),Vector3(-9.85,y,-8.7),.018,materials.metal)
  box(self,Vector3(-9.85,y,-9.6),Vector3(.2,.08,.4),materials.dark)
 text(self,"DIENSTANWEISUNG\nALLE 4 BEREICHE KONTROLLIEREN\nNORMAL → GRÜN   ANOMALIE → ROT",Vector3(-6.1,2.3,10.62),.14)
 for i in range(3): box(self,Vector3(6.3,.23,8.4-i*.55),Vector3(.5,.45,.5),[materials.blue,materials.red,materials.gold][i],true)

func set_anomaly(id: String) -> void:
 current=id;clock=0
 atmosphere.anomaly(id)
 # Fresh world per round means every normal state starts from the exact same layout.
 if id=="chair_ceiling":
  for chair in props.chairs.get_children(): chair.position.y=4.8;chair.rotation.x=PI
 elif id=="chairs_missing": props.chairs.visible=false
 elif id=="chair_stack":
  for i in range(props.chairs.get_child_count()): props.chairs.get_child(i).position=Vector3(7.5,i*.65,-5.2)
 elif id=="balls_red":
  for i in range(balls.multimesh.instance_count): balls.multimesh.set_instance_color(i,Color("a72d2d"))
 elif id=="ball_giant": props.giant.visible=true
 elif id=="balls_missing": balls.visible=false
 elif id=="mural_upside": props.mural.rotation.z=PI
 elif id=="mural_mirror": props.mural.scale.x=-1;props.mural.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
 elif id=="mural_red": props.mural.material_override.albedo_color=Color("e34238");props.mural.material_override.emission_enabled=true;props.mural.material_override.emission=Color("70100b")
 elif id=="mural_missing": props.mural.visible=false
 elif id=="car_giant": props.car.scale=Vector3.ONE*2.6
 elif id=="car_float": props.car.position.y=1.7
 elif id=="car_missing": props.car.visible=false
 elif id=="stars_upside":
  for star in props.stars.get_children(): star.rotation.z=PI
 elif id=="footprints": props.footprints.visible=true
 elif id=="lights_red":
  for light in practicals: light.light_color=Color("e22c28")
 elif id=="party_dark": party_light.light_energy=0
 elif id=="balloons_many":
  for i in range(17):
   var balloon: Node3D=props.balloons.get_child(i%3).duplicate();balloon.position=Vector3(7.3+(i%4)*.7,1.8+(i%3)*.55,-9.8+floori(i/4.0)*.8);props.balloons.add_child(balloon)
 elif id=="balloons_floor":
  for balloon in props.balloons.get_children(): balloon.position.y=.3;balloon.rotation.x=PI
 elif id=="slide_green":
  for part in props.slide.get_children(): part.material_override=mat(Color("43a76c"),load("res://assets/vinyl.png"),.38)
 elif id=="slide_missing": props.slide.visible=false
 elif id=="net_missing": props.nets.visible=false
 elif id=="star_giant": props.stars.get_child(0).scale=Vector3.ONE*4
 elif id=="extinguisher_float": props.extinguisher.position.y=2.8
 elif id=="hours_wrong": props.hours.text="KINDERPARADIES\n03:33 – 03:33"

func tick(delta: float, active: bool) -> void:
 atmosphere.tick(delta,active)
 if not active: return
 clock+=delta
 if int(clock/25)>last_sound:
  last_sound=int(clock/25);source.pitch_scale=.75;source.play()
 props.clock_hand.rotation.z=clock*(-2.5 if current=="clock_fast" else .8 if current=="clock_reverse" else -.004)
 if current=="balls_float":
  for i in range(0,360,3):
   var t:=ball_transforms[i];t.origin.y+=1.0+sin(clock*.7+i)*.4;balls.multimesh.set_instance_transform(i,t)
 elif current=="ball_moves": props.loose.position=Vector3(-1.6,.17,4.8+sin(clock*.8)*2)
 elif current=="car_moves": props.car.position.z=5.5+sin(clock*.6)*1.5
 elif current=="car_float": props.car.position.y=1.7+sin(clock)*.2
 elif current=="extinguisher_float": props.extinguisher.rotation.z=sin(clock)*.16

func brightness(value: float) -> void:
 environment.environment.tonemap_exposure=value

func quality(value: int) -> void:
 atmosphere.quality(value)
 for light in practicals: light.shadow_enabled=value>0 and (light==party_light or light.position.distance_to(Vector3(-5.5,4,0))<.1)

func open_door(red: bool) -> void:
 var leaf: Node3D=props["door_red" if red else "door_green"]
 create_tween().tween_property(leaf,"rotation:y",-1.15,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
