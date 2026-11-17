class_name PitBones
extends RefCounted

# 4.8.0 ball-pit anomaly: real skeletal arms instead of an upside-down visitor's
# sleeves. Every rigid bone group is one merged mesh, so a whole arm is 13 draw
# calls; the lasting clue hands are flattened into a single mesh each.
# Pivot layout per arm (all local +Y along the limb, palm facing local +Z):
# root -> shoulder (humerus) -> elbow (radius + ulna) -> wrist (carpals,
# metacarpals) -> knuckle (proximal phalanx) -> joint (middle + clawed distal).

const UPPER:=.46
const FORE:=.44
const HAND:=.19
# Finger x offset on the palm, metacarpal length, three phalanx lengths, splay.
const FINGERS:=[[-.034,.072,.030,.019,.016,-.20],[-.012,.080,.041,.026,.019,-.06],[.010,.078,.046,.029,.020,.04],[.030,.072,.042,.026,.019,.14],[.046,.062,.032,.019,.017,.26]]

static func material(w: PlayWorld) -> StandardMaterial3D:
 var m:=w.mat(Color("9a8b69"),load("res://assets/aged-plaster.png"),.9)
 m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*9
 if w.atmosphere and w.atmosphere.micro_normal: m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.4
 return m

static func grime(w: PlayWorld) -> StandardMaterial3D:
 return w.mat(Color("3b2e22"),null,.9)

static func _basis(axis: Vector3) -> Basis:
 var n:=axis.normalized()
 if absf(n.dot(Vector3.UP))>.999: return Basis.IDENTITY if n.y>0 else Basis(Vector3.RIGHT,PI)
 return Basis(Quaternion(Vector3.UP,n))

# A long bone: waisted shaft (two cones) with knobbly joint heads.
static func long_bone(st: SurfaceTool, from: Vector3, to: Vector3, r: float, heads:=Vector2(1.6,1.35)) -> void:
 var axis:=to-from;var b:=_basis(axis);var mid:=from.lerp(to,.55)
 for part in [[from,mid,r,r*.66],[mid,to,r*.66,r*.82]]:
  var cone:=CylinderMesh.new();cone.bottom_radius=part[2];cone.top_radius=part[3];cone.height=(part[1] as Vector3).distance_to(part[0]);cone.radial_segments=9;cone.rings=1;cone.cap_top=false;cone.cap_bottom=false
  st.append_from(cone,0,Transform3D(b,((part[0] as Vector3)+(part[1] as Vector3))*.5))
 for end in [[from,heads.x,Vector3(1.25,.72,.95)],[to,heads.y,Vector3(1.1,.7,1.0)]]:
  if end[1]<=0.: continue
  var knob:=SphereMesh.new();knob.radius=r*end[1];knob.height=r*end[1]*2;knob.radial_segments=9;knob.rings=5
  st.append_from(knob,0,Transform3D(b*Basis.from_scale(end[2]),end[0]))

# A sharp, slightly hooked claw tip: bone worn to a point.
static func claw(st: SurfaceTool, from: Vector3, to: Vector3, r: float) -> void:
 var tip:=CylinderMesh.new();tip.bottom_radius=r;tip.top_radius=r*.12;tip.height=from.distance_to(to);tip.radial_segments=7;tip.rings=1;tip.cap_top=false
 st.append_from(tip,0,Transform3D(_basis(to-from),(from+to)*.5))

static func _mesh(parent: Node3D, title: String, st: SurfaceTool, m: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.name=title;mesh.mesh=st.commit();mesh.material_override=m;parent.add_child(mesh);return mesh

static func _tool() -> SurfaceTool:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st

static func _pivot(parent: Node3D, title: String, at: Vector3) -> Node3D:
 var node:=Node3D.new();node.name=title;node.position=at;parent.add_child(node);return node

# Builds one articulated arm. `stretch` lengthens the forearm for the lead arm,
# which makes it read as wrong even before it reaches you.
static func arm(parent: Node3D, m: Material, dark: Material, s: float, stretch: float=1.) -> Dictionary:
 var root:=_pivot(parent,"BoneArm",Vector3.ZERO)
 var shoulder:=_pivot(root,"Shoulder",Vector3.ZERO)
 var upper:=UPPER*s;var fore:=FORE*s*stretch;var hand:=HAND*s
 var st:=_tool();long_bone(st,Vector3.ZERO,Vector3(0,upper,0),.021*s,Vector2(2.1,1.5))
 _mesh(shoulder,"Humerus",st,m)
 var elbow:=_pivot(shoulder,"Elbow",Vector3(0,upper,0))
 st=_tool()
 long_bone(st,Vector3(-.011*s,0,-.006*s),Vector3(.013*s,fore,.004*s),.012*s,Vector2(1.5,1.6))
 long_bone(st,Vector3(.012*s,-.012*s,-.012*s),Vector3(-.012*s,fore-.004*s,-.002*s),.010*s,Vector2(2.0,1.2))
 _mesh(elbow,"RadiusUlna",st,m)
 var wrist:=_pivot(elbow,"Wrist",Vector3(0,fore,0))
 st=_tool()
 for c in [Vector3(-.022,.012,0),Vector3(-.006,.010,.004),Vector3(.010,.012,0),Vector3(.026,.013,-.002),Vector3(-.016,.028,.002),Vector3(.002,.029,.004),Vector3(.020,.028,0)]:
  var bead:=SphereMesh.new();bead.radius=.0115*s;bead.height=.023*s;bead.radial_segments=7;bead.rings=4
  st.append_from(bead,0,Transform3D(Basis.from_scale(Vector3(1.1,.8,.9)),c*s))
 for f in FINGERS:
  long_bone(st,Vector3(float(f[0])*.45,.034,0)*s,Vector3(float(f[0]),.034+float(f[1]),.004)*s,.0062*s,Vector2(1.3,1.55))
 # Thumb metacarpal sits low and to the side.
 long_bone(st,Vector3(-.026,.022,.006)*s,Vector3(-.058,.066,.026)*s,.0068*s,Vector2(1.3,1.5))
 _mesh(wrist,"Palm",st,m)
 var fingers: Array=[]
 for f in FINGERS:
  var knuckle:=_pivot(wrist,"Knuckle",Vector3(float(f[0]),.034+float(f[1]),.004)*s);knuckle.rotation.z=-float(f[5])
  st=_tool();long_bone(st,Vector3.ZERO,Vector3(0,float(f[2])*s,0),.0055*s,Vector2(1.2,1.35));_mesh(knuckle,"Proximal",st,m)
  var joint:=_pivot(knuckle,"Joint",Vector3(0,float(f[2])*s,0))
  st=_tool();var bend:=Vector3(0,float(f[3])*s,.004*s)
  long_bone(st,Vector3.ZERO,bend,.0048*s,Vector2(1.15,1.3));claw(st,bend,bend+Vector3(0,float(f[4])*s,.009*s),.0046*s)
  _mesh(joint,"Distal",st,m)
  fingers.append([knuckle,joint])
 var thumb_knuckle:=_pivot(wrist,"ThumbKnuckle",Vector3(-.058,.066,.026)*s);thumb_knuckle.rotation=Vector3(.3,0,.55)
 st=_tool();long_bone(st,Vector3.ZERO,Vector3(0,.034*s,0),.006*s,Vector2(1.2,1.3));_mesh(thumb_knuckle,"ThumbProximal",st,m)
 var thumb_joint:=_pivot(thumb_knuckle,"ThumbJoint",Vector3(0,.034*s,0))
 st=_tool();claw(st,Vector3.ZERO,Vector3(0,.03*s,.008*s),.0055*s);_mesh(thumb_joint,"ThumbDistal",st,m)
 fingers.append([thumb_knuckle,thumb_joint])
 # Grime in the joints: a dark ring at elbow and wrist.
 var ring:=SphereMesh.new();ring.radius=.026*s;ring.height=.03*s;ring.radial_segments=9;ring.rings=3
 for at in [elbow,wrist]:
  var dirt:=MeshInstance3D.new();dirt.name="JointGrime";dirt.mesh=ring;dirt.material_override=dark;dirt.scale=Vector3(1,.55,1)*(1. if at==elbow else .75);at.add_child(dirt)
 return {"root":root,"shoulder":shoulder,"elbow":elbow,"wrist":wrist,"fingers":fingers,"upper":upper,"reach":fore+hand}

# Curls every finger: 0 = splayed open claw, 1 = clenched.
static func curl(a: Dictionary, amount: float, spread: float=1.) -> void:
 var fingers: Array=a.fingers
 for i in range(fingers.size()):
  var knuckle: Node3D=fingers[i][0];var joint: Node3D=fingers[i][1]
  if i<FINGERS.size():
   knuckle.rotation=Vector3(.15+amount*1.15,0,-float(FINGERS[i][5])*spread)
   joint.rotation.x=.25+amount*1.35
  else:
   knuckle.rotation=Vector3(.3+amount*.6,0,.55-amount*.35);joint.rotation.x=.2+amount*.8

# Two-bone solve in the arm's own vertical plane (local Y up, +Z to the target).
# Returns [shoulder tilt, elbow bend]; the elbow always hooks back and up.
static func reach(a: Dictionary, target_local: Vector3) -> Vector2:
 var u: float=a.upper;var f: float=a.reach
 var d:=clampf(target_local.length(),absf(u-f)+.02,u+f-.002)
 var tilt:=atan2(Vector2(target_local.x,target_local.z).length(),target_local.y)
 var alpha:=acos(clampf((u*u+d*d-f*f)/(2.*u*d),-1.,1.))
 var gamma:=acos(clampf((u*u+f*f-d*d)/(2.*u*f),-1.,1.))
 return Vector2(tilt-alpha,PI-gamma)

# Bakes a posed arm into one static mesh: the lasting clue costs a single draw.
static func flatten(a: Dictionary, parent: Node3D, m: Material, title: String) -> MeshInstance3D:
 var root: Node3D=a.root;var st:=_tool()
 for mesh in root.find_children("*","MeshInstance3D",true,false):
  if mesh.name=="JointGrime": continue
  var local:=Transform3D.IDENTITY;var node: Node3D=mesh
  while node!=root: local=node.transform*local;node=node.get_parent()
  st.append_from(mesh.mesh,0,local)
 var merged:=MeshInstance3D.new();merged.name=title;merged.mesh=st.commit();merged.material_override=m
 merged.transform=root.transform;parent.add_child(merged);parent.remove_child(root);root.queue_free()
 return merged
