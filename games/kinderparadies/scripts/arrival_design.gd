class_name ArrivalDesign
extends Node3D

var w: PlayWorld
var parts:=0
var wall_materials:=0
var obstacles: Array[AABB]=[]
var lights: Array[Light3D]=[]

func box(parent: Node3D,p: Vector3,s: Vector3,m: Material,solid: bool=false) -> MeshInstance3D:
 parts+=1
 var mesh:=w.box(parent,p,s,m,solid)
 if solid:obstacles.append(mesh.global_transform*mesh.get_aabb())
 return mesh

func sign_plate(parent: Node3D,words: String,p: Vector3,size_value: Vector2,yaw: float=0) -> Node3D:
 var sign_value:=VenueSignage.plate(w,parent,words,p,size_value,yaw)
 parts+=sign_value.find_children("*","MeshInstance3D",true,false).size()+(1 if sign_value is MeshInstance3D else 0)
 return sign_value

func build(world: PlayWorld) -> void:
 w=world;name="AfterPlayArchitecturalRestoration"
 _entrance();_annex();_materials();_snackbar()

func _entrance() -> void:
 var root: Node3D=w.backstage.exit_root
 # Move the existing belongings rather than duplicating them over furniture.
 var rail:=w.details.find_child("ReceptionCoatRail",true,false) as Node3D
 rail.reparent(root,false);rail.position=Vector3(1.09,0,-2.55);rail.rotation.y=-PI/2
 var stroller:=w.details.find_child("AbandonedPushchair",true,false) as Node3D
 stroller.reparent(root,false);stroller.position=Vector3(-.85,.016,-.65);stroller.rotation.y=0
 # Recompute moved prop bounds used to reject embedded saved positions.
 w.details.obstacles.clear()
 for cluster in w.details.clusters:
  for shape in cluster.find_children("*","CollisionShape3D",true,false):
   if shape.shape and not shape.disabled:w.details.obstacles.append(shape.global_transform*shape.shape.get_debug_mesh().get_aabb())
 var wood:=w.materials.wood.duplicate() as StandardMaterial3D;wood.roughness=.78;wood.uv1_triplanar=true;wood.uv1_scale=Vector3(2,5,2)
 var cloth:=w.polish.pbr("fabric_pattern_07",Color("6d6250"),5.);cloth.roughness=.97
 var mat:=box(root,Vector3(0,.019,-4.65),Vector3(1.52,.012,1.25),w.polish.pbr("dirty_carpet",Color("354e47"),1.8));mat.set_meta("foot_surface","carpet")
 var bench:=Node3D.new();bench.name="EntranceCloakroomBench";bench.position=Vector3(-.94,.016,-3.0);root.add_child(bench)
 for x in [-.15,.15]:
  for z in [-.83,.83]:box(bench,Vector3(x,.20,z),Vector3(.055,.4,.055),w.materials.metal,true)
 for i in range(4):box(bench,Vector3(-.153+i*.102,.434,0),Vector3(.095,.055,2.06),wood,true)
 for z in [-.76,.76]:box(bench,Vector3(0,.20,z),Vector3(.37,.045,.07),w.materials.metal)
 box(bench,Vector3(-.18,.66,0),Vector3(.045,.40,2.06),wood)
 var tag_index:=1
 for z in [-4.0,-3.55,-1.1,-.65]:
  w.tube(root,Vector3(1.08,1.34,z),Vector3(.96,1.29,z),.015,w.materials.metal)
  w.tube(root,Vector3(.96,1.29,z),Vector3(.94,1.35,z),.015,w.materials.metal)
  sign_plate(root,"%02d"%tag_index,Vector3(1.09,1.49,z),Vector2(.12,.11),-PI/2);tag_index+=1
 # Shoe rack follows the wall; its visible boards match its physical bounds.
 for y in [.12,.34]:box(root,Vector3(.98,y,-2.65),Vector3(.32,.035,1.65),wood,true)
 for z in [-3.46,-1.84]:box(root,Vector3(.98,.22,z),Vector3(.32,.31,.035),wood,true)
 for i in range(3):
  var shoe:=box(root,Vector3(.97,.40,-3.14+i*.29),Vector3(.24,.095,.12),w.materials.red if i%2 else w.materials.teal);shoe.rotation.y=.08*i
  box(shoe,Vector3(0,-.035,0),Vector3(.25,.025,.125),w.materials.cream)
 var scarf:=box(bench,Vector3(.02,.476,-.43),Vector3(.31,.018,.40),cloth);scarf.rotation.y=.1
 sign_plate(root,"GARDEROBE",Vector3(1.09,2.24,-2.55),Vector2(1.60,.29),-PI/2)
 sign_plate(root,"HAPPYLAND  /  AUF WIEDERSEHEN",Vector3(0,2.85,-5.52),Vector2(1.52,.16))
 # Real wall-fixed umbrella basket with a closed underside and interior.
 var basket:=SurfaceDetails.vessel(root,Vector3(.86,.018,-4.61),.49,.15,.13,.012,w.materials.metal,w.materials.dark,"EntranceUmbrellaStand")
 for i in range(2):
  var p:=Vector3(.86+i*.04,.18,-4.61+i*.015)
  w.tube(root,p,p+Vector3(-.06,.75,.02),.026,w.materials.teal if i else w.materials.gold)
  w.tube(root,p+Vector3(-.06,.75,.02),p+Vector3(-.06,.86,.02),.012,w.materials.wood)
 # Facade, porch light, glazing seals and threshold drain are manufactured parts.
 var light:=OmniLight3D.new();light.position=Vector3(0,2.65,-6.22);light.light_color=Color("bac7bd");light.light_energy=.75;light.omni_range=5.;light.shadow_enabled=not OS.has_feature("web");root.add_child(light);lights.append(light)
 for i in range(22):box(root,Vector3(-.72+i*.068,.022,-5.81),Vector3(.025,.012,.14),w.materials.metal)

func _annex() -> void:
 var root:=Node3D.new();root.name="RememberedHappylandCorridor";add_child(root)
 var frame:=AgedArchway.new();root.add_child(frame);frame.build(w)
 for mesh in frame.solids:obstacles.append(mesh.global_transform*mesh.get_aabb())
 for mesh in w.annex.get_children():
  if mesh is MeshInstance3D and absf(mesh.position.x+7.9)<.02 and mesh.position.y>3.3 and mesh.position.y<3.56:mesh.hide()
 var green:=w.revamp.paint(Color("435e53"),.12,.67)
 var brass:=w.revamp.paint(Color("7c7253"),.65,.46)
 var plaster:=w.materials.wall.duplicate() as StandardMaterial3D;plaster.albedo_color=Color("a4a18a")
 # A continuous building finish, split around both real door openings.
 for side in [-1,1]:
  var x: float=-7.9+side*1.355
  for span in [Vector2(-28.59,-12.42),Vector2(-34.35,-30.71)]:
   var z: float=(span.x+span.y)*.5;var length: float=span.y-span.x
   box(root,Vector3(x,.57,z),Vector3(.05,1.08,length),green)
   box(root,Vector3(x-side*.018,1.13,z),Vector3(.08,.07,length),w.materials.wood)
   box(root,Vector3(x-side*.005,.10,z),Vector3(.07,.15,length),w.materials.dark)
   box(root,Vector3(x,2.90,z),Vector3(.045,.11,length),green)
  # Recessed stiles and screw heads follow the actual panelling.
  for z in [-13.1,-14.7,-16.3,-17.9,-19.5,-21.1,-22.7,-24.3,-25.9,-27.5,-31.3,-32.9]:
   box(root,Vector3(x-side*.032,.59,z),Vector3(.016,1.02,.045),w.materials.wood)
   w.tube(root,Vector3(x-side*.05,1.13,z),Vector3(x-side*.055,1.13,z),.008,brass)
 # A built-in radiator is shallow enough to retain over 2.1 m clear width.
 var radiator:=Node3D.new();radiator.name="BoltedCorridorRadiator";radiator.position=Vector3(-9.22,.28,-18.8);root.add_child(radiator)
 for i in range(13):box(radiator,Vector3(.02,.26,-.65+i*.108),Vector3(.15,.49,.07),w.revamp.enamel)
 for y in [.07,.45]:w.tube(radiator,Vector3(0,y,-.68),Vector3(0,y,.68),.025,w.materials.metal)
 w.tube(root,Vector3(-9.26,.29,-19.52),Vector3(-9.26,.29,-12.5),.021,brass)
 for z in [-19.9,-17.4,-15.0,-12.6]:box(root,Vector3(-9.28,.29,z),Vector3(.04,.07,.09),w.materials.metal)
 sign_plate(root,"HEIZKREIS 03",Vector3(-9.19,.88,-18.8),Vector2(.45,.13),PI/2)
 # Individually framed notices sit on separate wall spans, never over controls.
 for spec in [[-9.25,-23.2,PI/2,"PERSONAL / HYGIENE"],[-6.55,-25.6,-PI/2,"LETZTE VORSTELLUNG  18:00"]]:
  sign_plate(root,spec[3],Vector3(spec[0],2.13,spec[1]),Vector2(1.50,.31),spec[2])
 var hanging:=Node3D.new();hanging.name="HungKitchenCinemaWayfinder";hanging.position=Vector3(-7.9,2.95,-14.8);root.add_child(hanging)
 sign_plate(hanging,"KÜCHE  /  KINO",Vector3(0,0,.022),Vector2(1.78,.43))
 sign_plate(hanging,"HAPPYLAND / PERSONALGANG",Vector3(0,0,-.022),Vector2(1.78,.43),PI)
 for x in [-.64,.64]:
  w.tube(root,Vector3(-7.9+x,3.172,-14.8),Vector3(-7.9+x,3.58,-14.8),.009,w.materials.metal)
  box(root,Vector3(-7.9+x,3.584,-14.8),Vector3(.11,.022,.09),w.materials.metal)
 var display:=Node3D.new();display.name="PinnedBirthdayNoticeCase";display.position=Vector3(-9.18,1.87,-24.8);display.rotation.y=PI/2;root.add_child(display)
 box(display,Vector3.ZERO,Vector3(1.35,.92,.055),w.materials.wood)
 box(display,Vector3(0,0,.035),Vector3(1.23,.80,.02),w.materials.gold)
 for i in range(5):
  var note:=box(display,Vector3(-.46+i*.225,.05+sin(i*3.)*.08,.05),Vector3(.19,.45,.005),w.materials.cream);note.rotation.z=.045*sin(i*2.7)
  for j in range(5):box(note,Vector3(0,.09-j*.034,.003),Vector3(.13 if j else .15,.005,.001),w.materials.wood)
  w.sphere(note,Vector3(0,.198,.008),.012,w.materials.red)
 for x in [-.64,.64]:box(display,Vector3(x,0,.06),Vector3(.04,.92,.035),w.materials.wood)
 for y in [-.44,.44]:box(display,Vector3(0,y,.06),Vector3(1.35,.04,.035),w.materials.wood)
 # Connected conduit and a service hatch replace large expanses of blank plaster.
 for side in [-1,1]:
  for z in [-14.0,-18.0,-22.0,-26.0,-32.0]:
   box(root,Vector3(-7.9+side*1.32,3.25,z),Vector3(.055,.09,1.05),w.materials.metal)
  w.tube(root,Vector3(-7.9+side*1.32,3.25,-12.45),Vector3(-7.9+side*1.32,3.25,-34.3),.019,w.materials.metal)
 var hatch:=Node3D.new();hatch.name="RecessedAccessHatch";hatch.position=Vector3(-9.235,1.99,-26.1);hatch.rotation.y=PI/2;root.add_child(hatch)
 box(hatch,Vector3.ZERO,Vector3(.71,.79,.025),w.materials.metal)
 box(hatch,Vector3(0,0,.017),Vector3(.64,.72,.020),green)
 for y in [-.25,-.20,-.15,-.1,-.05]:box(hatch,Vector3(0,y,.029),Vector3(.44,.012,.005),w.materials.dark)
 sign_plate(hatch,"LÜFTUNG 03",Vector3(0,.21,.035),Vector2(.41,.13))
 # Fitted ceiling coffers with real diffuser, louvres, screws and wall bounce.
 for z in [-14.,-18.,-22.,-25.7,-30.9,-33.4]:
  var casing:=box(root,Vector3(-7.9,3.48,z),Vector3(1.22,.11,.40),w.materials.metal)
  box(casing,Vector3(0,-.065,0),Vector3(1.08,.027,.29),w.materials.cream)
  for x in [-.44,-.22,0,.22,.44]:box(casing,Vector3(x,-.086,0),Vector3(.012,.028,.31),w.materials.metal)
  for x in [-.55,.55]:w.tube(root,Vector3(-7.9+x,3.55,z),Vector3(-7.9+x,3.575,z),.013,w.materials.metal)
 for light in w.practicals:
  if absf(light.position.x+7.9)<.1 and light.position.z< -12.3:
   light.light_color=Color("c5c4ab");light.light_energy=.85
 # Floor expansion strips are flush, with no raised collision lips.
 for z in [-12.7,-18.4,-24.15,-28.45,-30.85,-34.1]:box(root,Vector3(-7.9,.013,z),Vector3(2.62,.003,.027),brass)

func _materials() -> void:
 var seen: Dictionary={}
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if not mesh.get_meta("architecture_wall",false):continue
  var m:=mesh.material_override as StandardMaterial3D
  if not m or seen.has(m.get_instance_id()):continue
  seen[m.get_instance_id()]=true;wall_materials+=1
  m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*.48;m.roughness=.92
  m.normal_enabled=true;m.normal_scale=.42
  if not OS.has_feature("web"):
   m.albedo_texture=load("res://assets/pbr/painted_plaster_wall/albedo.jpg");m.normal_texture=load("res://assets/pbr/painted_plaster_wall/normal.jpg")
   m.roughness_texture=load("res://assets/pbr/painted_plaster_wall/roughness.jpg");m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
  else:m.normal_texture=w.atmosphere.micro_normal

func _snackbar() -> void:
 # Real fluted motor vents, tray lips and fasteners on the two dispensers.
 for machine in w.life.snack.get_children():
  if not machine.get_meta("slush_dispenser",false):continue
  for i in range(8):box(machine,Vector3(-.20+i*.057,.15,.269),Vector3(.023,.11,.008),w.materials.dark)
  for x in [-.255,.255]:w.tube(machine,Vector3(x,.25,.272),Vector3(x,.25,.279),.007,w.materials.metal)
  for x in [-.16,.16]:box(machine,Vector3(x,.016,.40),Vector3(.012,.023,.18),w.materials.metal)
  for i in range(7):box(machine,Vector3(-.13+i*.043,.019,.40),Vector3(.012,.010,.16),w.materials.dark)

func quality(value: int) -> void:
 for light in lights:light.shadow_enabled=value>0 and not OS.has_feature("web")

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.28,.08,-.28),Vector3(.56,1.62,.56))
 for bounds in obstacles:
  if guard.intersects(bounds):return false
 return true

func snapshot() -> Dictionary:
 return {"parts":parts,"wall_materials":wall_materials,"entrance":true}
