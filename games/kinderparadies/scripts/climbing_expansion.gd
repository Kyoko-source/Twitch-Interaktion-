class_name ClimbingExpansion
extends Node3D

var w: PlayWorld
var sky: SkyTube
var lookout: Node3D
var carved: Array[Dictionary]=[]
var timber: Material
var fasteners: Array[Transform3D]=[]
var ties: Array[Transform3D]=[]
var repaired_post_count:=0

func low_clearance(p: Vector3) -> bool:
 # Older saves may stand on the former upper deck beneath the new cabin.
 return p.x>.6 and p.x<4.7 and p.z> -6.2 and p.z< -3.2 and p.y>2.8 and p.y<3.25

static func portal_wall(world: PlayWorld,axis: String,fixed: float,area: Rect2,center: Vector2) -> void:
 # Square subtraction plus a physical annular reveal makes a real round hole.
 # No continuous hidden wall is left behind the visible tube.
 var cut:=Rect2(center-Vector2.ONE*.99,Vector2.ONE*1.98)
 var pieces: Array[Rect2]=[
  Rect2(area.position,Vector2(cut.position.x-area.position.x,area.size.y)),
  Rect2(Vector2(cut.end.x,area.position.y),Vector2(area.end.x-cut.end.x,area.size.y)),
  Rect2(Vector2(cut.position.x,area.position.y),Vector2(cut.size.x,cut.position.y-area.position.y)),
  Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,area.end.y-cut.end.y))]
 for rect in pieces:
  var size:=Vector3(.2,rect.size.y,rect.size.x) if axis=="x" else Vector3(rect.size.x,rect.size.y,.2)
  world.box(world,PlayGeometry.point(axis,fixed,rect.get_center().x,rect.get_center().y),size,world.materials.wall,true)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(64):
  var a:=i*TAU/64;var b: float=(i+1)*TAU/64
  var u:=Vector2(cos(a),sin(a));var v:=Vector2(cos(b),sin(b))
  var outer_a:=center+u*(.99/maxf(absf(u.x),absf(u.y)));var outer_b:=center+v*(.99/maxf(absf(v.x),absf(v.y)))
  var inner_a:=center+u*.94;var inner_b:=center+v*.94
  for side in [-1,1]:
   var p:=PlayGeometry.point(axis,fixed+side*.1,outer_a.x,outer_a.y);var q:=PlayGeometry.point(axis,fixed+side*.1,outer_b.x,outer_b.y)
   var r:=PlayGeometry.point(axis,fixed+side*.1,inner_a.x,inner_a.y);var s:=PlayGeometry.point(axis,fixed+side*.1,inner_b.x,inner_b.y)
   SkyTube.quad(tool,p,q,r,s,(Vector3.RIGHT if axis=="x" else Vector3.BACK)*side)
  var p:=PlayGeometry.point(axis,fixed-.1,inner_a.x,inner_a.y);var q:=PlayGeometry.point(axis,fixed+.1,inner_a.x,inner_a.y)
  var r:=PlayGeometry.point(axis,fixed-.1,inner_b.x,inner_b.y);var s:=PlayGeometry.point(axis,fixed+.1,inner_b.x,inner_b.y)
  var n:=PlayGeometry.point(axis,0,-cos((a+b)*.5),-sin((a+b)*.5))
  SkyTube.quad(tool,p,q,r,s,n)
 var mesh:=MeshInstance3D.new();mesh.name="RoundTubeWallReveal";mesh.mesh=tool.commit();mesh.material_override=world.materials.wall;world.add_child(mesh);mesh.create_trimesh_collision()
 mesh.set_meta("tube_portal",true);mesh.set_meta("portal_center",PlayGeometry.point(axis,fixed,center.x,center.y));mesh.set_meta("portal_axis",axis)
 for collider in mesh.find_children("*","CollisionShape3D",true,false):(collider.shape as ConcavePolygonShape3D).backface_collision=true

func build(world: PlayWorld) -> void:
 w=world;name="AbandonedClimbingAdventure";set_meta("foot_surface","rubber")
 timber=w.mat(Color("8a7e61"),load("res://assets/wood.png"),.94);timber.uv1_triplanar=true;timber.uv1_scale=Vector3(1,4,1)
 _lookout();_east_landing();_repaired_frame()
 sky=SkyTube.new();add_child(sky);sky.build(w)
 # Reinforced collars finish both sides of each penetration in the wall.
 for portal in [{"axis":"x","fixed":6.8,"u":-4.5},{"axis":"z","fixed":1.6,"u":16.05}]:
  for side in [-1,1]:
   for i in range(48):
    var a:=i*TAU/48;var b: float=(i+1)*TAU/48
    var p:=PlayGeometry.point(portal.axis,portal.fixed+side*.15,portal.u+cos(a)*.98,SkyTube.HEIGHT+sin(a)*.98)
    var q:=PlayGeometry.point(portal.axis,portal.fixed+side*.15,portal.u+cos(b)*.98,SkyTube.HEIGHT+sin(b)*.98)
    PlayGeometry.strand(ties,p,q)
    if i%6==0:fasteners.append(Transform3D(Basis.IDENTITY,p))
 var strap:=CylinderMesh.new();strap.height=1;strap.top_radius=.055;strap.bottom_radius=.055;strap.radial_segments=8
 sky.instances(ties,strap,w.materials.dark,"RepairBandsAndPortalCollars")
 var screw:=SphereMesh.new();screw.radius=.025;screw.height=.05;screw.radial_segments=8;screw.rings=4
 sky.instances(fasteners,screw,w.materials.rust,"TowerAndPortalBolts")

func ramp(parent: Node3D,a: Vector3,b: Vector3,width: float,id: String) -> MeshInstance3D:
 var side:=Vector3.UP.cross((b-a).normalized()).normalized()*width*.5
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var n: Vector3=(b-a).cross(side).normalized()
 if n.y<0:n=-n
 SkyTube.quad(tool,a-side,a+side,b-side,b+side,n)
 for sign_value in [-1,1]:SkyTube.quad(tool,a+side*sign_value,b+side*sign_value,a+side*sign_value-Vector3.UP*.14,b+side*sign_value-Vector3.UP*.14,side.normalized()*sign_value)
 var mesh:=MeshInstance3D.new();mesh.name=id;mesh.mesh=tool.commit();mesh.material_override=w.materials.red;parent.add_child(mesh);mesh.create_trimesh_collision()
 mesh.set_meta("foot_surface","rubber")
 for sign_value in [-1,1]:w.tube(parent,a+side*sign_value+Vector3.UP*.035,b+side*sign_value+Vector3.UP*.035,.045,w.materials.gold)
 return mesh

func _lookout() -> void:
 lookout=Node3D.new();lookout.name="NamesInTheLookout";lookout.set_meta("foot_surface","wood");add_child(lookout)
 # A short internal climb starts on the existing deck, clear of the slide.
 ramp(lookout,Vector3(2.05,2.977,-.40),Vector3(2.05,4.15,-3.45),1.4,"ContinuousLookoutApproach")
 w.box(lookout,Vector3(2.8575,4.055,-4.81),Vector3(3.335,.19,2.70),timber,true)
 for x in [1.19,4.525]:
  for z in [-6.16,-3.46]:
   # Rear uprights extend the original columns on the same centreline.
   var start:=6.045 if z== -6.16 else 2.977
   w.tube(lookout,Vector3(x,start,z),Vector3(x,6.47,z),.14,w.materials.gold)
   if z== -3.46:
    w.box(lookout,Vector3(x,3.01,z),Vector3(.36,.065,.36),w.materials.dark)
   for y in [4.05,5.25,6.35]:fasteners.append(Transform3D(Basis.IDENTITY,Vector3(x-.115,y,z)))
  for y in [4.02,6.38]:w.tube(lookout,Vector3(x,y,-6.16),Vector3(x,y,-3.46),.07,w.materials.gold)
 # Wood knee walls, glazing and safety nets frame views over the old attractions.
 var rear:=w.box(lookout,Vector3(2.8575,4.47,-6.16),Vector3(3.335,.64,.11),timber,true)
 w.box(lookout,Vector3(1.19,4.47,-4.81),Vector3(.11,.64,2.70),timber,true)
 var left:=w.box(lookout,Vector3(1.43,4.65,-3.46),Vector3(.48,1,.12),timber,true)
 var right:=w.box(lookout,Vector3(3.62,4.65,-3.46),Vector3(1.65,1,.12),timber,true)
 PlayGeometry.panel(w,lookout,"LookoutRearWindow","z",-6.16,Rect2(1.19,4.79,3.335,1.55))
 PlayGeometry.panel(w,lookout,"LookoutHallWindow","x",1.19,Rect2(-6.16,4.79,2.70,1.55))
 # Tube mouth remains open. The two small side guards protect the lookout edge.
 for z in [-5.75,-3.50]:w.box(lookout,Vector3(4.45,4.68,z),Vector3(.12,1.05,.42),timber,true)
 for side in [-1,1]:
  var roof:=w.box(lookout,Vector3(2.8575,6.48,-4.81+side*.72),Vector3(3.65,.11,1.60),w.materials.gold,true);roof.rotation.x=side*.13
 w.tube(lookout,Vector3(1.04,6.58,-4.81),Vector3(4.68,6.58,-4.81),.055,w.materials.dark)
 var sign:=w.box(lookout,Vector3(2.65,6.02,-3.365),Vector3(2.35,.36,.075),timber)
 var label:=w.text(sign,"HAPPYLAND · AUSSICHT",Vector3(0,0,.045),.14,Color("444436"));label.font=load("res://assets/Oswald.ttf")
 _engraving("Mia 1998",Vector2(95,110),92,.04)
 _engraving("LEON + TOM",Vector2(530,210),76,-.035)
 CarvedTimber.apply(rear,carved.duplicate())
 _engraving("Wir waren hier.",Vector2(60,110),82,.025)
 CarvedTimber.apply(right,[carved[2]])
 _engraving("ANNA",Vector2(85,130),145,-.06)
 CarvedTimber.apply(left,[carved[3]])
 # Old slot viewer, a forgotten wristband and a tiny abandoned child's shoe.
 var viewer:=Node3D.new();viewer.position=Vector3(1.52,4.15,-5.50);viewer.rotation.y=PI;lookout.add_child(viewer)
 w.tube(viewer,Vector3(0,0,0),Vector3(0,.88,0),.055,w.materials.rust)
 w.box(viewer,Vector3(0,.96,0),Vector3(.45,.24,.27),w.materials.teal)
 for side in [-1,1]:w.tube(viewer,Vector3(side*.12,.98,.08),Vector3(side*.12,.98,.22),.065,w.materials.dark)
 var shoe:=w.sphere(lookout,Vector3(3.65,4.20,-5.60),.15,w.materials.red);shoe.scale=Vector3(.6,.4,1.1)
 w.box(lookout,Vector3(3.65,4.16,-5.60),Vector3(.18,.035,.33),w.materials.cream)
 for z in [-5.66,-5.61,-5.56]:w.tube(lookout,Vector3(3.61,4.25,z),Vector3(3.70,4.25,z),.006,w.materials.stitch)
 var glow:=w.lamp(Vector3(2.5,6.12,-4.9),Color("b3b18b"),.36,4.3);glow.light_volumetric_fog_energy=.05
 w.box(lookout,Vector3(2.5,6.24,-5.7),Vector3(.48,.11,.18),w.materials.dark)

func _engraving(value: String,p: Vector2,size: int,angle: float) -> void:
 carved.append({"text":value,"p":p,"size":size,"angle":angle})

func _east_landing() -> void:
 var tower:=w.playground.get_node("EastTower")
 # Replace the overhanging tilted box with a flush upper-ramp landing.
 for child in tower.get_children():
  if child is Node3D and child.position.distance_to(Vector3(16.2,3.27,3.6))<.01:
   tower.remove_child(child);child.queue_free()
 ramp(self,Vector3(16.2,2.15,8.25),Vector3(16.2,4.15,3.90),1.25,"ContinuousEastUpperRamp")
 w.box(self,Vector3(16.12,4.065,3.36),Vector3(1.94,.17,1.10),w.materials.blue,true)
 w.box(self,Vector3(15.33,4.065,3.35),Vector3(.38,.17,1.12),w.materials.blue,true)

func _repaired_frame() -> void:
 # Flush the oversized deck rail below its surface. Formerly this tube was
 # proud of the padding and visually cut through the slide launch opening.
 for mesh in w.props.structure.get_children():
  if mesh is MeshInstance3D and mesh.mesh is CylinderMesh and mesh.mesh.height>1 and absf(mesh.basis.y.normalized().dot(Vector3.UP))<.01:
   if absf(mesh.position.y-2.25)<.01 or absf(mesh.position.y-.3)<.01:mesh.position.y-=.16
 # Repairs are attached to existing posts and rendered in two instanced batches.
 var rng:=RandomNumberGenerator.new();rng.seed=3700712
 for branch: Node3D in [w.props.structure,w.playground.get_node("EastTower")]:
  for mesh in branch.get_children():
   if not mesh is MeshInstance3D or not mesh.mesh is CylinderMesh or mesh.mesh.height<4:continue
   # Cylinder height also describes horizontal rails. Repair bands belong only
   # to upright support columns, never to a rail's midpoint in empty space.
   if absf(mesh.basis.y.normalized().dot(Vector3.UP))<.99:continue
   repaired_post_count+=1
   for y in [.9,1.15,3.7]:
    var center:=branch.to_global(Vector3(mesh.position.x,y,mesh.position.z))
    var radius: float=.19 if branch==w.props.structure else .205
    for j in range(12):
     var a:=j*TAU/12;var b: float=(j+1)*TAU/12
     PlayGeometry.strand(ties,center+Vector3(cos(a)*radius,0,sin(a)*radius),center+Vector3(cos(b)*radius,0,sin(b)*radius))
   var seam:=branch.to_global(mesh.position+Vector3(.11,0,.08))
   for i in range(3):fasteners.append(Transform3D(Basis.IDENTITY,seam+Vector3(0,rng.randf_range(-1.8,1.8),0)))
 # A faded tactile activity panel occupies a closed bay, leaving access open.
 var panel:=Node3D.new();panel.name="ForgottenActivityBoard";panel.position=Vector3(-2.19,1.35,-4.8);panel.rotation.y=-PI/2;add_child(panel)
 w.box(panel,Vector3.ZERO,Vector3(1.65,1.14,.12),timber)
 for i in range(5):
  var x: float=-.6+i*.3
  w.tube(panel,Vector3(x,-.31,.09),Vector3(x,.34,.09),.015,w.materials.rust)
  var bead:=w.sphere(panel,Vector3(x,sin(i*2.1)*.22,.11),.09,[w.materials.red,w.materials.gold,w.materials.teal][i%3]);bead.scale.z=.55
 var title:=w.text(panel,"ZÄHL MIT MIR",Vector3(0,.46,.07),.13,Color("554a35"));title.font=load("res://assets/Oswald.ttf")
