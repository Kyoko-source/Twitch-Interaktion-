class_name LiftCabin
extends RefCounted

# All dressing stays behind the original cabin boundary. Collisions remain
# five simple slabs; decorative seams, rails and screws have no physics.
var w: PlayWorld
var owner: Node3D
var cabin: Node3D
var steel: ShaderMaterial
var paint: ShaderMaterial
var wood: ShaderMaterial
var rubber: ShaderMaterial
var dark: StandardMaterial3D
var brass: StandardMaterial3D
var edge: StandardMaterial3D
var assembly: Node3D

func surface(color: Color,kind: float,metal: float,rough: float) -> ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=load("res://assets/lift-v391/lift_surface.gdshader");m.set_shader_parameter("tint",color);m.set_shader_parameter("surface_kind",kind);m.set_shader_parameter("metalness",metal);m.set_shader_parameter("base_roughness",rough);return m

func plate(parent: Node3D,name: String,p: Vector3,s: Vector3,m: Material) -> MeshInstance3D:
 var part:=w.box(parent,p,s,m);part.name=name;return part

func screw(parent: Node3D,p: Vector3,axis: Vector3) -> void:
 w.tube(parent,p-axis*.001,p+axis*.002,.008,edge)
 var slot:=plate(parent,"RecessedScrewSlot",p+axis*.0025,Vector3(.009,.0017,.001),dark)
 if absf(axis.x)>.5:slot.rotation.y=PI/2
 if absf(axis.y)>.5:slot.rotation.x=PI/2

func label(parent: Node3D,value: String,p: Vector3,size: float,color: Color=Color("c9c5a6"),yaw: float=0.) -> Label3D:
 var text:=w.text(parent,value,p,size,color);text.rotation.y=yaw;return text

func arrow(parent: Node3D,p: Vector3,size: float,material: Material,angle: float=0.) -> MeshInstance3D:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 SurfaceDetails.triangle(tool,Vector3(-size*.5,-size*.45,0),Vector3(size*.5,-size*.45,0),Vector3(0,size*.55,0),Vector3.BACK)
 var mesh:=MeshInstance3D.new();mesh.name="PhysicalIndicatorArrow";mesh.mesh=tool.commit();mesh.material_override=material;mesh.position=p;mesh.rotation.z=angle;parent.add_child(mesh);return mesh

func amber() -> StandardMaterial3D:
 var m:=w.mat(Color("d7ac72"));m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;return m

func build(world: PlayWorld,intro: Node3D) -> Node3D:
 w=world;owner=intro
 cabin=Node3D.new();cabin.name="RestoredOriginalLiftCabin";cabin.position=Vector3(-8.,0,18.8);intro.add_child(cabin)
 assembly=Node3D.new();assembly.name="BatchedCabinCraft";cabin.add_child(assembly)
 steel=surface(Color("747d76"),0.,.65,.49);paint=surface(Color("485f55"),1.,.10,.58)
 wood=surface(Color("534131"),2.,.02,.63);rubber=surface(Color("323b32"),3.,0.,.9)
 dark=w.mat(Color("141d19"),null,.73,.24);brass=w.mat(Color("9c8d63"),null,.4,.73);edge=w.mat(Color("a1a79a"),null,.34,.84)
 # Existing walkable envelope; floor top .016 has no raised threshold.
 w.box(cabin,Vector3(0,-.074,0),Vector3(2.75,.18,3.3),rubber,true).name="SimpleCabinFloor"
 w.box(cabin,Vector3(0,2.82,0),Vector3(2.85,.14,3.3),dark,true)
 w.box(cabin,Vector3(0,1.4,1.62),Vector3(2.85,2.8,.14),paint,true)
 for side in [-1,1]:w.box(cabin,Vector3(side*1.4,1.4,0),Vector3(.14,2.8,3.3),paint,true)
 # Slightly inset carpet-coloured studded rubber, edging below shoe height.
 plate(assembly,"InsetCabinMat",Vector3(0,.019,.08),Vector3(2.41,.006,2.72),rubber)
 for side in [-1,1]:
  plate(assembly,"FlushMatTrim",Vector3(side*1.215,.019,.08),Vector3(.018,.005,2.75),brass)
  for z in [-1.30,1.46]:plate(assembly,"MatEndTrim",Vector3(0,.019,z),Vector3(2.44,.005,.018),brass)
  # Lower veneer panels and upper enamel sheets have recessed joints.
  for z in [-.99,-.19,.61,1.25]:
   var length: float=.76 if z<1. else .48
   plate(assembly,"LowerVeneerPanel",Vector3(side*1.316,.59,z),Vector3(.025,.91,length),wood)
   plate(assembly,"UpperEnamelPanel",Vector3(side*1.316,1.82,z),Vector3(.025,1.48,length),paint)
  for y in [.11,1.075,2.59]:plate(assembly,"RecessedPanelRail",Vector3(side*1.297,y,.03),Vector3(.034,.035,3.05),edge)
  for z in [-1.42,1.45]:
   plate(assembly,"PressedCornerChannel",Vector3(side*1.292,1.36,z),Vector3(.055,2.57,.055),steel)
   for y in [.18,2.51]:screw(assembly,Vector3(side*1.255,y,z),Vector3(-side,0,0))
  # Rails stop before control panel and printer, with actual wall standoffs.
  w.tube(assembly,Vector3(side*1.22,.93,-.40),Vector3(side*1.22,.93,1.28),.029,edge)
  for z in [-.36,1.24]:
   w.tube(assembly,Vector3(side*1.22,.93,z),Vector3(side*1.30,.93,z),.023,steel)
   w.tube(assembly,Vector3(side*1.297,.93,z),Vector3(side*1.310,.93,z),.052,steel)
 # Rear wall has the same panel rhythm, with a framed period route card.
 for x in [-.84,0.,.84]:
  plate(assembly,"RearLowerVeneer",Vector3(x,.59,1.531),Vector3(.80,.91,.025),wood)
  plate(assembly,"RearUpperPanel",Vector3(x,1.82,1.531),Vector3(.80,1.48,.025),paint)
 for y in [.11,1.075,2.59]:plate(assembly,"RearPanelRail",Vector3(0,y,1.505),Vector3(2.6,.035,.034),edge)
 w.tube(assembly,Vector3(-1.16,.93,1.44),Vector3(1.16,.93,1.44),.029,edge)
 for x in [-.98,.98]:w.tube(assembly,Vector3(x,.93,1.44),Vector3(x,.93,1.53),.023,steel)
 _rear_card()
 _portal()
 _ceiling()
 _controls()
 # Static dressing batches by material; doors keep separate moving batches.
 CelebrationTailoring.merge_joint(assembly)
 return cabin

func _portal() -> void:
 # Folded steel jambs mask door pockets instead of a thin floating top bar.
 for side in [-1,1]:
  plate(assembly,"FoldedDoorJamb",Vector3(side*1.293,1.32,-1.40),Vector3(.083,2.64,.20),steel)
  plate(assembly,"DoorPocketShadow",Vector3(side*1.242,1.32,-1.445),Vector3(.012,2.60,.055),dark)
  var door:=Node3D.new();door.name="BrushedSlidingLeaf";door.position=Vector3(side*.65,1.3,-1.5);cabin.add_child(door);owner.doors.append(door)
  plate(door,"BrushedDoorSkin",Vector3.ZERO,Vector3(1.295,2.6,.065),steel)
  for x in [-.628,.628]:plate(door,"FoldedLeafEdge",Vector3(x,0,.036),Vector3(.015,2.56,.009),edge)
  plate(door,"DoorLowerKickPlate",Vector3(0,-1.10,.036),Vector3(1.26,.28,.008),surface(Color("7e867b"),0.,.84,.42))
  # An actual dark meeting gasket and horizontal grain break.
  plate(door,"MeetingGasket",Vector3(-side*.642,0,.034),Vector3(.008,2.60,.012),dark)
  for x in [-.57,.57]:
   for y in [-1.18,1.19]:screw(door,Vector3(x,y,.036),Vector3.BACK)
  CelebrationTailoring.merge_joint(door)
 plate(assembly,"DeepDoorLintel",Vector3(0,2.67,-1.41),Vector3(2.68,.18,.20),steel)
 plate(assembly,"FlushDoorSill",Vector3(0,.018,-1.47),Vector3(2.58,.008,.21),edge)
 for z in [-1.53,-1.47,-1.41]:plate(assembly,"RecessedTrack",Vector3(0,.0225,z),Vector3(2.51,.001,.008),dark)
 # Raised floor displays remain readable from the original standing position.
 plate(assembly,"RecessedHeaderDisplay",Vector3(0,2.61,-1.297),Vector3(.53,.15,.018),dark)
 var display:=label(cabin,"",Vector3(-.045,2.61,-1.284),.067,Color("e5b776"));display.shaded=false;display.font=load("res://assets/Oswald.ttf");owner.floor_displays.append(display)
 arrow(assembly,Vector3(.085,2.61,-1.283),.033,amber())

func _ceiling() -> void:
 var warm:=w.mat(Color("b4b6a0"),null,.7);warm.emission_enabled=true;warm.emission=Color("ddd2ad");warm.emission_energy_multiplier=.62
 plate(assembly,"RecessedCeilingTray",Vector3(0,2.743,.0),Vector3(2.54,.035,2.94),paint)
 for x in [-.54,.54]:
  plate(assembly,"FluorescentHousing",Vector3(x,2.701,-.02),Vector3(.29,.062,1.83),steel)
  plate(assembly,"AgedPrismaticDiffuser",Vector3(x,2.665,-.02),Vector3(.24,.019,1.73),warm)
  for k in range(20):plate(assembly,"DiffuserPrism",Vector3(x,2.652,-.82+k*.084),Vector3(.23,.005,.004),warm)
  for z in [-.94,.90]:plate(assembly,"LampEndCap",Vector3(x,2.666,z),Vector3(.29,.04,.045),edge)
 plate(assembly,"VentRecess",Vector3(0,2.713,1.15),Vector3(.66,.018,.28),dark)
 for i in range(13):plate(assembly,"VentLouvre",Vector3(-.30+i*.05,2.695,1.15),Vector3(.023,.014,.25),steel)
 var light:=OmniLight3D.new();light.name="SoftCabinCeilingLight";light.position=Vector3(0,2.43,.15);light.light_color=Color("ded6bd");light.light_energy=.9;light.omni_range=4.1;light.omni_attenuation=1.3;light.light_size=.32;light.light_specular=.20;light.shadow_enabled=true;light.shadow_blur=2.;cabin.add_child(light)

func _controls() -> void:
 # The panel is a coherent built-in object on the right wall, not loose discs.
 var panel:=Node3D.new();panel.name="InsetLiftControlPanel";panel.position=Vector3(1.265,1.39,-.80);panel.rotation.y=-PI/2;cabin.add_child(panel)
 plate(panel,"ControlPanelShadowGap",Vector3(0,0,-.005),Vector3(.315,1.03,.014),dark)
 plate(panel,"BrushedFaceplate",Vector3.ZERO,Vector3(.292,1.,.013),steel)
 for x in [-.126,.126]:
  for y in [-.476,.476]:screw(panel,Vector3(x,y,.008),Vector3.BACK)
 plate(panel,"InsetFloorGlass",Vector3(0,.324,.009),Vector3(.232,.156,.007),dark)
 var readout:=label(panel,"",Vector3(-.030,.325,.014),.061,Color("e7b875"));readout.font=load("res://assets/Oswald.ttf");readout.shaded=false;owner.floor_displays.append(readout)
 arrow(panel,Vector3(.063,.325,.014),.027,amber())
 for row in range(3):
  var y:=.10-row*.142
  w.tube(panel,Vector3(0,y,.009),Vector3(0,y,.019),.039,edge)
  w.tube(panel,Vector3(0,y,.019),Vector3(0,y,.022),.030,brass if row==0 else dark)
  if row==0:
   var symbol:=label(panel,"1",Vector3(0,y-.008,.024),.026,Color("c9c8b1"));symbol.shaded=false
  elif row==1:
   arrow(panel,Vector3(-.011,y,.024),.014,edge,PI/2);arrow(panel,Vector3(.011,y,.024),.014,edge,-PI/2)
   plate(panel,"DoorButtonCentre",Vector3(0,y,.024),Vector3(.002,.025,.001),edge)
  else:
   var points: Array[Vector3]=[Vector3(-.014,y+.007,.025),Vector3(-.014,y,.025),Vector3(-.005,y-.008,.025),Vector3(.006,y-.012,.025),Vector3(.014,y-.007,.025)]
   for i in range(points.size()-1):w.tube(panel,points[i],points[i+1],.0023,edge)
  for dot in range(3):w.sphere(panel,Vector3(.060+dot*.008,y-.015,.012),.002,edge)
 for x in range(9):
  for y in range(3):w.tube(panel,Vector3(-.048+x*.012,.44+y*.010,.008),Vector3(-.048+x*.012,.44+y*.010,.010),.0027,dark)
 var note:=label(panel,"MAX. 6 PERSONEN\n450 kg",Vector3(0,-.381,.01),.018,Color("b9bea8"));note.set_meta("sign_text","MAX. 6 PERSONEN · 450 kg")
 CelebrationTailoring.merge_joint(panel)

func _rear_card() -> void:
 var card:=Node3D.new();card.name="PeriodLiftDirectory";card.position=Vector3(0,1.89,1.495);card.rotation.y=PI;cabin.add_child(card)
 plate(card,"DirectoryBacking",Vector3.ZERO,Vector3(.86,.78,.022),wood)
 for x in [-.421,.421]:plate(card,"BrassDirectoryRim",Vector3(x,0,.017),Vector3(.012,.78,.012),brass)
 for y in [-.383,.383]:plate(card,"BrassDirectoryRim",Vector3(0,y,.017),Vector3(.85,.012,.012),brass)
 CelebrationTailoring.merge_joint(card)
 var print_face:=w.artwork(card,Vector3(0,0,.016),Vector2(.79,.658),LiftDirectory.texture(card))
 print_face.material_override=w.mat(Color.WHITE,print_face.get_active_material(0).albedo_texture,.95)
 print_face.add_to_group("caption_signs");print_face.set_meta("sign_text","HAPPYLAND\nBitte Kinder an die Hand nehmen.\nAusgang im Erdgeschoss.");print_face.set_meta("sign_rect",Vector2(.79,.658))
