class_name CeilingHorse
extends Node3D

# One continuous, anchored neck, eight head surfaces. No torso or limbs.
const ROOT:="res://assets/horse-v420/"
const MODEL:=ROOT+"long-horse-head.glb"
const WEB_MODEL:=ROOT+"long-horse-head-web.glb"
# The neck mesh samples a smooth spline between the 32 animated support points.
const RINGS:=126
const SIDES:=32
const SOURCE:=Vector3(0,.65,.15)
const ROUTE: Array[Vector3]=[Vector3(-.2,-1.2,.2),Vector3(-.6,-.55,.65),Vector3(-1.9,-.55,1),Vector3(-3.4,-.55,2.3),Vector3(-4.4,-1.35,2.5),Vector3(-5.85,-1.37,2.5)]
var w: PlayWorld
var mask: Node3D
var jaw: Node3D
var neck: MeshInstance3D
var skin: ShaderMaterial
var mane: ShaderMaterial
var route: Curve3D
var clock:=0.0
var accumulator:=0.0
var progress:=0.0
var attack_gain:=0.0
var debug_hold:=false
var samples:=PackedVector4Array()
var normals:=PackedVector3Array()
var sections: Array[Dictionary]=[]

func build(world: PlayWorld) -> void:
 w=world;name="CinemaVentDweller"
 route=Curve3D.new();route.bake_interval=.025
 for i in range(ROUTE.size()):
  var tangent: Vector3=(ROUTE[mini(i+1,ROUTE.size()-1)]-ROUTE[maxi(0,i-1)])*.12
  if tangent.length()>.28: tangent=tangent.normalized()*.28
  route.add_point(ROUTE[i],-tangent,tangent)
 mask=(load(WEB_MODEL if OS.has_feature("web") else MODEL) as PackedScene).instantiate();mask.name="BloodiedHorseMask";add_child(mask);mask.scale=Vector3.ONE*.82
 jaw=mask.find_child("JawHinge",true,false)
 for mesh in mask.find_children("*","MeshInstance3D",true,false):
  mesh.set_meta("nonblocking_atmosphere",true)
  for s in range(mesh.mesh.get_surface_count()):
   var original: Material=mesh.get_active_material(s)
   if original is StandardMaterial3D:
    if "eye" in original.resource_name.to_lower():
     # Wet, clouded eyes deep in the sockets catch the guard's flashlight.
     var eye:=original.duplicate() as StandardMaterial3D;eye.vertex_color_use_as_albedo=true;eye.roughness=.05;eye.metallic_specular=.9
     eye.clearcoat_enabled=true;eye.clearcoat=1.;eye.clearcoat_roughness=.02;mesh.set_surface_override_material(s,eye)
    elif "darkness" in original.resource_name or "mane" in original.resource_name:
     var dark:=original.duplicate() as StandardMaterial3D;dark.vertex_color_use_as_albedo=true;dark.roughness=.98;dark.metallic_specular=.08;mesh.set_surface_override_material(s,dark)
    else:
     var detail:=ShaderMaterial.new();detail.shader=load(ROOT+"mask.gdshader");detail.set_shader_parameter("pores",w.atmosphere.micro_normal);mesh.set_surface_override_material(s,detail)
 _build_neck();pose(0)

func _build_neck() -> void:
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array();var ns:=PackedVector3Array()
 for ring in range(RINGS):
  for side in range(SIDES+1):
   vertices.append(Vector3(cos(side*TAU/SIDES)*.1,ring*.02,sin(side*TAU/SIDES)*.1));ns.append(Vector3.UP);uvs.append(Vector2(float(side)/SIDES,ring/float(RINGS-1)))
 for ring in range(RINGS-1):
  for side in range(SIDES):
   var a:=ring*(SIDES+1)+side;var b:=a+SIDES+1
   indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=ns;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 neck=MeshInstance3D.new();neck.name="ContinuousCeilingNeck";neck.mesh=geometry;neck.custom_aabb=AABB(Vector3(-7,-2.5,-2),Vector3(9,4,7));neck.set_meta("nonblocking_atmosphere",true);add_child(neck)
 skin=ShaderMaterial.new();skin.shader=load(ROOT+"neck.gdshader");skin.set_shader_parameter("pores",w.atmosphere.micro_normal);neck.material_override=skin
 # Long wet clumps hang from the dorsal ridge and share the skin's support points.
 vertices.clear();uvs.clear();indices.clear();ns.clear();var offsets:=PackedVector2Array();var shape:=PackedColorArray()
 for ring in range(3,RINGS):
  for strand in range(3):
   var seed:=ring*3+strand
   var turn:=(fmod(seed*.618034,1.)-.5)*.36
   var length_value:=.16+fmod(seed*.4142,1.)*.44
   var width_value:=.30+fmod(seed*.7321,1.)*.45
   var start:=vertices.size()
   for step in range(7):
    for edge in [-1.,1.]:
     vertices.append(Vector3.ZERO);ns.append(Vector3.UP);uvs.append(Vector2(turn,ring/float(RINGS-1)))
     offsets.append(Vector2(step/6.,edge));shape.append(Color(length_value,width_value,0,1))
   for step in range(6):
    var a:=start+step*2
    indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=ns;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_TEX_UV2]=offsets;arrays[Mesh.ARRAY_COLOR]=shape;arrays[Mesh.ARRAY_INDEX]=indices
 var hairs:=MeshInstance3D.new();hairs.name="MattedNeckMane";var hair_geometry:=ArrayMesh.new();hair_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);hairs.mesh=hair_geometry;hairs.custom_aabb=neck.custom_aabb;hairs.set_meta("nonblocking_atmosphere",true);add_child(hairs)
 mane=ShaderMaterial.new();mane.shader=load(ROOT+"mane.gdshader");hairs.material_override=mane
 sections.append({"neck":neck,"hair":hairs,"skin":skin,"mane":mane})

func tick(delta: float, active: bool) -> void:
 if not active or debug_hold: return
 # The reference horse is motionless. The puzzle controller owns the hunt.
 if w.current!="vent_strike":return
 clock+=delta;accumulator+=delta
 if accumulator<1.0/24.0: return
 accumulator=0
 pose(0)

func pose(amount: float) -> void:
 for i in range(1,sections.size()):sections[i].neck.hide();sections[i].hair.hide()
 progress=clampf(amount,0,1)
 var distance:=route.get_baked_length()*progress
 mask.position=route.sample_baked(distance,true)+Vector3(0,-attack_gain*.52,attack_gain*.30)
 # The mask turns from the auditorium towards the length of the corridor.
 var target:=route.sample_baked(minf(route.get_baked_length(),distance+.5),true)
 var facing:=target-mask.position
 if facing.length()<.1: facing=Vector3(0,0,1)
 facing.y=0;facing=facing.normalized().lerp(Vector3(0,0,1),smoothstep(.82,1.0,progress)).normalized()
 var droop:=lerpf(-.90,-.48,smoothstep(.65,1.0,progress))
 mask.rotation=Vector3(droop+.025*sin(clock*.7),atan2(-facing.x,-facing.z),.028*sin(clock*.9)*(1-progress))
 if jaw: jaw.rotation.x=-.21-.065*sin(clock*1.15)-attack_gain*.23
 var curve:=Curve3D.new();curve.bake_interval=.025
 var controls: Array[Vector3]=[SOURCE,Vector3(0,-.08,.15),Vector3(.15,-.38,.05)]
 if progress<.04:
  controls.append(Vector3(.2,-.7,-.05))
 else:
  for part in range(1,9):
   var d:=distance*part/10.0
   var curl:=sin(part*PI/9.0)*smoothstep(.02,.30,progress)
   controls.append(route.sample_baked(d,true)+Vector3(.12*sin(part*1.9+clock*.55),.12+.09*sin(part*1.7+clock*.8),.19*cos(part*1.8+clock*.5))*curl)
 var end:=mask.position+mask.basis.z*.14
 controls.append(end+mask.basis.z*.28);controls.append(end)
 for i in range(controls.size()):
  var tangent: Vector3=(controls[mini(i+1,controls.size()-1)]-controls[maxi(0,i-1)])*.105
  if tangent.length()>.18: tangent=tangent.normalized()*.18
  curve.add_point(controls[i],-tangent,tangent)
 samples.clear();normals.clear();var previous:=Vector3.RIGHT
 for i in range(32):
  var d:=curve.get_baked_length()*i/31.0;var p:=curve.sample_baked(d,true)
  var tangent: Vector3=curve.sample_baked(minf(curve.get_baked_length(),d+.025),true)-curve.sample_baked(maxf(0,d-.025),true)
  tangent=tangent.normalized();var side:=previous-tangent*previous.dot(tangent)
  if side.length()<.01: side=tangent.cross(Vector3.FORWARD)
  side=side.normalized();previous=side
  samples.append(Vector4(p.x,p.y,p.z,lerpf(.106,.082,i/31.0)*(1+.035*sin(clock*.8+i*.33))))
  normals.append(side)
 skin.set_shader_parameter("points",samples);skin.set_shader_parameter("frames",normals)
 mane.set_shader_parameter("points",samples);mane.set_shader_parameter("frames",normals)

func draw_trail(trace: PackedVector3Array, rotation_value: Vector3, jaw_value: float) -> void:
 if trace.is_empty():return
 mask.global_position=trace[-1];mask.rotation=rotation_value
 if jaw:jaw.rotation.x=jaw_value
 var points:=PackedVector3Array([SOURCE,Vector3(0,-.08,.15),Vector3(.15,-.38,.05),Vector3(.2,-.7,-.05)])
 for point in trace:points.append(to_local(point))
 points[-1]=mask.position+mask.basis.z*.14
 var lengths:=PackedFloat32Array([0.0])
 for i in range(1,points.size()):lengths.append(lengths[-1]+maxf(.0001,points[i].distance_to(points[i-1])))
 var total:=lengths[-1];var count:=maxi(1,ceili(total/4.5))
 while sections.size()<count:
  var segment:=MeshInstance3D.new();segment.name="GrowingNeckSection";segment.mesh=neck.mesh;segment.set_meta("nonblocking_atmosphere",true);add_child(segment)
  var hair:=MeshInstance3D.new();hair.name="GrowingManeSection";hair.mesh=sections[0].hair.mesh;hair.set_meta("nonblocking_atmosphere",true);add_child(hair)
  var material:=skin.duplicate() as ShaderMaterial;var hair_material:=mane.duplicate() as ShaderMaterial
  segment.material_override=material;hair.material_override=hair_material
  sections.append({"neck":segment,"hair":hair,"skin":material,"mane":hair_material})
 var previous:=Vector3.RIGHT
 for section_index in range(sections.size()):
  var section: Dictionary=sections[section_index];section.neck.visible=section_index<count;section.hair.visible=section_index<count
  if section_index>=count:continue
  var positions:=PackedVector4Array();var frames:=PackedVector3Array();var bound:=AABB()
  var a:=section_index*4.5;var b:=minf(total,a+4.5)
  for i in range(32):
   var d:=lerpf(a,b,i/31.0);var p:=_along(points,lengths,d)
   var tangent:=(_along(points,lengths,minf(total,d+.025))-_along(points,lengths,maxf(0,d-.025))).normalized()
   var side:=previous-tangent*previous.dot(tangent)
   if side.length()<.001:side=tangent.cross(Vector3.FORWARD)
   side=side.normalized();previous=side
   frames.append(side);positions.append(Vector4(p.x,p.y,p.z,lerpf(.105,.082,d/total)))
   bound=AABB(p,Vector3.ZERO) if i==0 else bound.expand(p)
  section.neck.custom_aabb=bound.grow(.4);section.hair.custom_aabb=bound.grow(.4)
  section.skin.set_shader_parameter("points",positions);section.skin.set_shader_parameter("frames",frames)
  section.mane.set_shader_parameter("points",positions);section.mane.set_shader_parameter("frames",frames)

func _along(points: PackedVector3Array,lengths: PackedFloat32Array,distance: float) -> Vector3:
 var low:=0;var high:=lengths.size()-1
 while low<high:
  var middle: int=(low+high)/2
  if lengths[middle]<distance:low=middle+1
  else:high=middle
 var i:=maxi(1,low)
 return points[i-1].lerp(points[i],clampf((distance-lengths[i-1])/maxf(.0001,lengths[i]-lengths[i-1]),0,1))

func snapshot() -> Dictionary:
 var p:=mask.global_position;var source:=to_global(SOURCE)
 return {"clock":clock,"progress":progress,"head":[p.x,p.y,p.z],"source":[source.x,source.y,source.z],"bodyless":true,"head_surfaces":8,"neck_samples":samples.size(),"jaw":is_instance_valid(jaw),"attack":attack_gain}

func head_bounds() -> AABB:
 var bounds:=AABB();var first:=true
 for mesh in mask.find_children("*","MeshInstance3D",true,false):
  var local: AABB=(mask.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
  bounds=local if first else bounds.merge(local);first=false
 return bounds
