class_name HorrorFigures
extends RefCounted

# The authored fingers curl around local X, below the palm and in front of it.
# Align the handle with that actual opening instead of the palm's origin.
const SPOON_GRIP:=Vector3(0,-.057,.030)
# The stooped figure stands on the root origin; its head hangs this far forward.
const HEAD_REACH:=.60
const SHOULDER_STIR:=Vector3(-.25,1.52,.37)
const SHOULDER_IDLE:=Vector3(.25,1.52,.37)
const UPPER_LENGTH:=.47
const FOREARM_LENGTH:=.45
const HAND_SCALE:=1.16
const WRIST:=Vector3(0,.078,0)
const ELBOW_OUT:=Vector3(-1.,-.3,-.25)
const ELBOW_IDLE:=Vector3(.6,-.2,-.5)
const ELBOW_DOWN:=Vector3(.7,-.7,0)

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

# Two-bone solve: limbs keep their length, so the sleeves never stretch.
static func reach(upper: MeshInstance3D,forearm: MeshInstance3D,shoulder: Vector3,wrist: Vector3,pole: Vector3) -> void:
 var span:=wrist-shoulder;var distance:=clampf(span.length(),.1,UPPER_LENGTH+FOREARM_LENGTH-.001);var axis:=span.normalized()
 var along:=(UPPER_LENGTH*UPPER_LENGTH-FOREARM_LENGTH*FOREARM_LENGTH+distance*distance)/(2.*distance)
 var elbow:=shoulder+axis*along+pole.slide(axis).normalized()*sqrt(maxf(UPPER_LENGTH*UPPER_LENGTH-along*along,0.))
 link(upper,shoulder,elbow);link(forearm,elbow,shoulder+axis*distance)

static func claw(hand: Node3D,upper: MeshInstance3D,forearm: MeshInstance3D,shoulder: Vector3,target: Vector3,pole: Vector3) -> void:
 var back:=(shoulder-target).normalized();var side:=back.cross(Vector3.FORWARD).normalized()
 hand.transform=Transform3D(Basis(side,back,side.cross(back))*Basis.from_scale(Vector3.ONE*HAND_SCALE),target)
 reach(upper,forearm,shoulder,hand.transform*WRIST,pole)

# Both arms open toward the victim. Amount 0 leaves the free arm hanging.
static func strike(figure: Dictionary,amount: float) -> void:
 claw(figure.hand,figure.upper,figure.forearm,SHOULDER_STIR,Vector3(-.21,1.62,1.00),ELBOW_DOWN*Vector3(-1,1,1))
 claw(figure.idle_hand,figure.idle_upper,figure.idle_forearm,SHOULDER_IDLE,Vector3(.40,.78,.50).lerp(Vector3(.19,1.50,1.04),amount),ELBOW_IDLE.lerp(ELBOW_DOWN,amount))

static func rest(figure: Dictionary) -> void:
 figure.idle_hand.transform=Transform3D(Basis.from_scale(Vector3.ONE*HAND_SCALE),Vector3(.40,.78,.50))
 reach(figure.idle_upper,figure.idle_forearm,SHOULDER_IDLE,figure.idle_hand.transform*WRIST,ELBOW_IDLE)
 gape(figure,0.)

static func gape(figure: Dictionary,amount: float) -> void:
 var head: MeshInstance3D=figure.head
 head.set_blend_shape_value(head.find_blend_shape_by_name("Gape"),amount)

static func sleeve(parent: Node3D, part: String) -> MeshInstance3D:
 var scene: Node3D=(load("res://assets/clown-v420/sleeve-"+part+".glb") as PackedScene).instantiate()
 var mesh:=scene.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
 mesh.get_parent().remove_child(mesh);scene.free();parent.add_child(mesh)
 var cloth:=StandardMaterial3D.new();cloth.albedo_color=Color("6b4440");cloth.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg")
 cloth.normal_enabled=true;cloth.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");cloth.normal_scale=.4;cloth.roughness=.96
 cloth.uv1_triplanar=true;cloth.uv1_scale=Vector3.ONE*6;mesh.material_override=cloth;return mesh

static func bone(parent: Node3D, radius: float, material: Material) -> MeshInstance3D:
 var node:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=radius*.8;cylinder.bottom_radius=radius;cylinder.radial_segments=24;node.mesh=cylinder;node.material_override=material;parent.add_child(node);return node

static func spoon_head(parent: Node3D,material: Material) -> MeshInstance3D:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for underside in [false,true]:
  for row in range(8):
   for side in range(32):
    var points: Array[Vector3]=[]
    for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
     var r: float=(row+corner.y)/8.;var a: float=(side+corner.x)*TAU/32.
     points.append(Vector3(cos(a)*.040*r,-.015+.023*r*r-(.004 if underside else 0.),sin(a)*.052*r))
    var normal:=Vector3.DOWN if underside else Vector3.UP
    SurfaceDetails.triangle(st,points[0],points[1],points[2],normal)
    SurfaceDetails.triangle(st,points[1],points[3],points[2],normal)
 for i in range(32):
  var a:=i*TAU/32.;var b:=(i+1)*TAU/32.
  var aa:=Vector3(cos(a)*.040,.008,sin(a)*.052);var ab:=Vector3(cos(b)*.040,.008,sin(b)*.052)
  SurfaceDetails.triangle(st,aa,ab,aa-Vector3.UP*.004,Vector3(cos(a),0,sin(a)))
  SurfaceDetails.triangle(st,ab,ab-Vector3.UP*.004,aa-Vector3.UP*.004,Vector3(cos(a),0,sin(a)))
 var mesh:=MeshInstance3D.new();mesh.name="ConcaveWoodenSpoonHead";mesh.mesh=st.commit();mesh.material_override=material;parent.add_child(mesh);return mesh

static func clown(w: PlayWorld, parent: Node3D) -> Dictionary:
 var scene: PackedScene=load("res://assets/clown-v420/clown-web.glb" if OS.has_feature("web") else "res://assets/clown-v420/clown-desktop.glb")
 var root:=scene.instantiate();root.name="KitchenClown";parent.add_child(root)
 var head:=root.find_child("Head",true,false) as Node3D
 assert(head!=null,"Sculpted clown head is missing")
 var hair: Node3D=(load("res://assets/clown-v404/clown-hair-web.glb" if OS.has_feature("web") else "res://assets/clown-v404/clown-hair-desktop.glb") as PackedScene).instantiate()
 head.add_child(hair)
 var fibres:=ShaderMaterial.new();fibres.shader=load("res://assets/encounter-v360/blond_hair.gdshader")
 for mesh in hair.find_children("*","MeshInstance3D",true,false):
  mesh.material_override=fibres;mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  mesh.set_meta("nonblocking_atmosphere",true)
 var cap: Node3D=(load("res://assets/clown-v404/patched-costume-cap.glb") as PackedScene).instantiate()
 cap.name="PatchedCostumeCap";head.add_child(cap)
 for mesh in cap.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;mesh.set_meta("nonblocking_atmosphere",true)
  if str(mesh.name).begins_with("FauxLeatherPanel"):
   var material:=ShaderMaterial.new();material.shader=load("res://assets/clown-v404/patched-cap.gdshader")
   var original:=mesh.get_active_material(0) as StandardMaterial3D
   if original:material.set_shader_parameter("tint",original.albedo_color)
   var panel:=clampi(str(mesh.name).trim_prefix("FauxLeatherPanel").to_int(),0,5)
   material.set_shader_parameter("patch_level",[.33,.52,.45,.58,.38,.64][panel]);material.set_shader_parameter("patch_shade",[.83,1.14,.77,1.08,.86,1.12][panel])
   mesh.material_override=material
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
  for surface in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(surface) as StandardMaterial3D
   if material and material.resource_name=="Photographic clown complexion":
    var skin:=ShaderMaterial.new();skin.shader=load("res://assets/clown-v420/clown_skin.gdshader")
    skin.set_shader_parameter("skin",load("res://assets/clown-v420/clown-skin-albedo.png"));skin.set_shader_parameter("pores",load("res://assets/detail-v310/clown-normal.jpg"));mesh.set_surface_override_material(surface,skin)
   if material and material.resource_name=="Cracked greasepaint and blood":
    var neck:=w.mat(Color("a39b8e"),null,.74);neck.normal_enabled=true;neck.normal_texture=w.atmosphere.micro_normal;neck.normal_scale=.18;mesh.set_surface_override_material(surface,neck)
   if material and material.resource_name in ["Blood stained woven costume","Dirty pleated linen"]:
    var cloth:=ShaderMaterial.new();cloth.shader=load(ScareBank.ROOT+"soaked_cloth.gdshader")
    cloth.set_shader_parameter("textile",load("res://assets/pbr/fabric_pattern_07/albedo.jpg"));cloth.set_shader_parameter("fibres",load("res://assets/pbr/fabric_pattern_07/normal.jpg"))
    cloth.set_shader_parameter("blood_map",load("res://assets/presentation-v250/blood-texture.png"));cloth.set_shader_parameter("apron",material.resource_name=="Dirty pleated linen")
    cloth.set_shader_parameter("tint",Color("a9a18a") if material.resource_name=="Dirty pleated linen" else Color("743b36"));mesh.set_surface_override_material(surface,cloth)
 var arm:=sleeve(root,"upper");var forearm:=sleeve(root,"forearm")
 var hand: Node3D=(load("res://assets/clown-v420/clown-hand-web.glb" if OS.has_feature("web") else "res://assets/clown-v420/clown-hand-desktop.glb") as PackedScene).instantiate();hand.name="StirringHand";root.add_child(hand)
 CharacterFinish.hand(hand,Color("c9c2b4"));hand.scale=Vector3.ONE*HAND_SCALE
 var idle_upper:=sleeve(root,"upper");var idle_forearm:=sleeve(root,"forearm")
 var idle:=hand.duplicate();root.add_child(idle)
 var spoon:=bone(root,.012,w.materials.wood);spoon.name="GrippedWoodenSpoonHandle"
 var bowl:=spoon_head(root,w.materials.wood)
 var figure:={"root":root,"head":head,"upper":arm,"forearm":forearm,"hand":hand,"spoon":spoon,"bowl":bowl,"idle_upper":idle_upper,"idle_forearm":idle_forearm,"idle_hand":idle}
 reach(arm,forearm,SHOULDER_STIR,Vector3(-.12,1.52,.92),ELBOW_OUT);hand.position=Vector3(-.12,1.42,.92)
 rest(figure);return figure
