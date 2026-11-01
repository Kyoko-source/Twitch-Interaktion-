class_name VenueCraft
extends Node3D

const ROOT:="res://assets/craft-v340/"
const RUBBER:=Rect2(-2.55,-6.2,8.6,10.45)
var w: PlayWorld
var parts:=0
var floors: Dictionary={}
var lights: Array[Dictionary]=[]
var emitters: Array[StandardMaterial3D]=[]
var obstacles: Array[AABB]=[]
var litter_zones: Array[Rect2]=[]
var handle_styles:=0
var worn_surfaces:=0
var velvet: StandardMaterial3D

func box(parent: Node3D,p: Vector3,s: Vector3,m: Material,solid: bool=false) -> MeshInstance3D:
 parts+=1
 var mesh:=w.box(parent,p,s,m,solid)
 if solid:obstacles.append(mesh.global_transform*mesh.get_aabb())
 return mesh

func finish_floor(id: String,kind: int,rect: Rect2) -> ShaderMaterial:
 var native:=not OS.has_feature("web") or id=="dirty_carpet"
 var path:="res://assets/pbr/"+id+"/"
 var m:=ShaderMaterial.new();m.shader=load(ROOT+"floor-finish.gdshader")
 m.set_shader_parameter("albedo_map",load(path+"albedo.jpg") if native else load("res://assets/floor.png"))
 m.set_shader_parameter("normal_map",load(path+"normal.jpg") if native else w.atmosphere.micro_normal)
 m.set_shader_parameter("rough_map",load(path+"roughness.jpg") if native else w.graphics.gloss_noise)
 m.set_shader_parameter("finish",kind);m.set_shader_parameter("bounds",Vector4(rect.position.x,rect.position.y,rect.end.x,rect.end.y))
 return m

func service_material(color: Color,kind: int) -> ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=load(ROOT+"service-wear.gdshader")
 m.set_shader_parameter("grain",load("res://assets/paint.png"));m.set_shader_parameter("normal_map",w.atmosphere.micro_normal)
 m.set_shader_parameter("paint",color);m.set_shader_parameter("kind",kind);return m

func build(world: PlayWorld) -> void:
 w=world;name="HappylandMaterialAndSceneryCraft"
 velvet=w.polish.pbr("fabric_pattern_07",Color("69434a"),5.);velvet.roughness=.96;velvet.normal_scale=.26;velvet.cull_mode=BaseMaterial3D.CULL_DISABLED
 _floors();_cinema();_kitchen();_walls();_litter();_lighting()

func _floors() -> void:
 var carpet: MeshInstance3D=w.annex.get_node("CinemaCarpet")
 carpet.material_override=finish_floor("dirty_carpet",0,Rect2(-6.275,-34.15,9.95,8.6));floors.carpet=carpet
 var tiles:=w.revamp.find_child("KitchenTileFloor",true,false) as MeshInstance3D
 tiles.material_override=finish_floor("dirty_tiles",1,Rect2(-17.19,-34.32,7.66,8.92));floors.tiles=tiles
 var rubber:=box(self,Vector3(RUBBER.get_center().x,.020,RUBBER.get_center().y),Vector3(RUBBER.size.x,.005,RUBBER.size.y),finish_floor("rubberized_track",2,RUBBER))
 rubber.name="FittedSoftPlaySafetyFloor";floors.rubber=rubber
 # These are finish strips, not raised independent collision boxes.
 for x in [RUBBER.position.x,RUBBER.end.x]:box(self,Vector3(x,.021,RUBBER.get_center().y),Vector3(.032,.004,RUBBER.size.y),w.materials.dark)
 for z in [RUBBER.position.y,RUBBER.end.y]:box(self,Vector3(RUBBER.get_center().x,.021,z),Vector3(RUBBER.size.x,.004,.032),w.materials.dark)
 for x in [-9.4,-6.4]:
  var sill:=box(self,Vector3(x,.014,-29.65),Vector3(.38,.004,1.86),w.revamp.steel);sill.name="FlushKitchenSill" if x< -8 else "FlushCinemaSill"
  for xx in [-.14,-.07,0,.07,.14]:box(sill,Vector3(xx,.0025,0),Vector3(.009,.001,1.71),w.materials.dark)
 # A flush irregular repair at the tile perimeter, outside the newspaper/stove.
 var repair:=box(self,Vector3(-15.85,.018,-33.96),Vector3(.62,.002,.36),w.materials.dark);repair.name="KitchenPerimeterTileRepair"
 for i in range(3):box(repair,Vector3(-.20+i*.2,.002,0),Vector3(.19,.002,.34),w.materials.cream if i==1 else w.materials.teal)
 # Short skirting pieces stop at the actual kitchen/cinema door jambs.
 for x in [-17.215,-9.535,-6.225,3.60]:
  for span in [Vector2(-34.31,-30.72),Vector2(-28.60,-25.55)]:
   box(self,Vector3(x,.066,(span.x+span.y)*.5),Vector3(.035,.10,span.y-span.x),w.materials.dark)

func curtain(parent: Node3D,p: Vector3,width: float,height: float,yaw: float) -> void:
 var root:=Node3D.new();root.position=p;root.rotation.y=yaw;parent.add_child(root)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(12):
  for col in range(24):
   var points: Array[Vector3]=[];var uvs: Array[Vector2]=[]
   for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
    var u: float=(col+corner.x)/24.;var v: float=(row+corner.y)/12.
    points.append(Vector3((u-.5)*width,.035+v*height+.009*sin(u*41.)*(1.-v),.045*cos(u*TAU*5.)))
    uvs.append(Vector2(u*2.,v*4.))
   for i in [0,2,1,1,2,3]:st.set_uv(uvs[i]);st.add_vertex(points[i])
 st.generate_normals();st.generate_tangents()
 var mesh:=MeshInstance3D.new();mesh.name="FadedEntranceVelvet";mesh.mesh=st.commit();mesh.material_override=velvet;root.add_child(mesh);parts+=1
 for i in range(6):w.tube(root,Vector3(-width*.44+i*width*.176,height+.035,.005),Vector3(-width*.44+i*width*.176,height+.125,.005),.008,w.materials.metal)

func _cinema() -> void:
 var root:=Node3D.new();root.name="CinemaFacadeAndProscenium";add_child(root)
 # Two narrow, fully drawn-back drapes leave the complete aperture open.
 for z in [-30.94,-28.36]:curtain(root,Vector3(-6.59,0,z),.31,2.48,PI/2)
 box(root,Vector3(-6.59,2.69,-29.65),Vector3(.13,.19,2.98),velvet)
 w.tube(root,Vector3(-6.59,2.78,-31.14),Vector3(-6.59,2.78,-28.16),.022,w.materials.metal)
 for z in [-31.10,-28.20]:box(root,Vector3(-6.49,2.78,z),Vector3(.27,.055,.075),w.materials.metal)
 # Upgrade the existing poster in place: never place another box over its art.
 for poster in w.find_children("*","MeshInstance3D",true,false):
  if not poster.get_meta("mounted_art",false) or poster.global_position.distance_to(Vector3(-6.265,2.23,-32.9))>.03:continue
  poster.name="RecessedCinemaProgramme";poster.global_position.x=-6.18
  for frame in poster.get_children():frame.hide()
  var mat:=poster.material_override.duplicate() as StandardMaterial3D
  mat.emission_enabled=true;mat.emission_texture=mat.albedo_texture;mat.emission=Color("a49b7b");mat.emission_energy_multiplier=.32;poster.material_override=mat;emitters.append(mat)
  box(poster,Vector3(0,0,-.07),Vector3(1.30,1.51,.09),w.materials.dark)
  for x in [-.63,.63]:box(poster,Vector3(x,0,.015),Vector3(.045,1.51,.16),w.revamp.steel)
  for y in [-.735,.735]:box(poster,Vector3(0,y,.015),Vector3(1.30,.04,.16),w.revamp.steel)
  w.venue.text(poster,"HEUTE / HAPPYLAND LICHTSPIEL",Vector3(0,.84,.03),.064,Color("bdb08d"))
 # A wall-backed ticket desk occupies the space below that programme.
 var desk:=Node3D.new();desk.name="CinemaTicketInspection";desk.position=Vector3(-6.08,0,-33.10);root.add_child(desk);desk.set_meta("environment_dressing",true)
 box(desk,Vector3(0,.47,0),Vector3(.43,.88,.88),w.materials.wood,true)
 box(desk,Vector3(.025,.935,0),Vector3(.48,.05,.94),w.revamp.steel,true)
 for z in [-.37,.37]:box(desk,Vector3(.222,.46,z),Vector3(.012,.76,.035),w.materials.teal)
 for i in range(7):
  var ticket:=box(desk,Vector3(.03,.967+i*.0015,.12),Vector3(.19,.0015,.085),w.materials.paper);ticket.rotation.y=.05*i
  box(ticket,Vector3(-.065,.001,0),Vector3(.018,.001,.072),w.materials.red)
 var punch:=box(desk,Vector3(.04,.982,-.19),Vector3(.13,.025,.15),w.materials.dark);punch.rotation.y=.18
 w.tube(punch,Vector3(-.04,.02,-.03),Vector3(.04,.065,.03),.014,w.materials.metal)
 box(desk,Vector3(.228,.75,0),Vector3(.008,.10,.42),w.materials.cream)
 w.venue.text(desk,"KARTENKONTROLLE",Vector3(.237,.731,0),.044,Color("554c35"),PI/2)
 # Remove the duplicate cylindrical folds; retain the authored sewn curtain mesh.
 for mesh in w.graphics.get_node("CinemaCurtainAndWiring").get_children():
  if mesh is MeshInstance3D and mesh.position.x>3.1:mesh.hide()
 for mesh in w.annex.find_children("TornSewnCinemaCurtain*","MeshInstance3D",true,false):mesh.material_override=velvet
 for z in [-33.98,-25.42]:
  box(root,Vector3(3.36,1.76,z),Vector3(.14,3.50,.19),w.materials.wood)
  for y in [.22,3.28]:box(root,Vector3(3.34,y,z),Vector3(.18,.09,.24),w.materials.gold)
 box(root,Vector3(3.34,3.44,-29.70),Vector3(.18,.14,8.75),w.materials.wood)
 box(root,Vector3(3.232,3.42,-29.70),Vector3(.025,.055,8.58),w.materials.gold)
 box(root,Vector3(3.34,.105,-29.70),Vector3(.18,.19,8.75),w.materials.dark)
 for speaker in w.venue.get_node("CinemaShowHistory").get_children():
  if speaker is Node3D and speaker.get_child_count()>8 and speaker.position.x>2.8 and speaker.position.y>2.7 and speaker.position.y<3.1:
   speaker.rotation.y=-PI/2
   w.tube(root,speaker.global_position+Vector3(.12,0,0),Vector3(3.32,speaker.global_position.y,speaker.global_position.z),.022,w.materials.metal)

func _kitchen() -> void:
 var root:=Node3D.new();root.name="KitchenUseAndRepairs";add_child(root)
 var kit:=w.annex.get_node("ManufacturedKitchen")
 var green:=service_material(Color("718575"),0);var steel:=service_material(Color("939e93"),1);var grease:=service_material(Color("667260"),2)
 for mesh in kit.find_children("*","MeshInstance3D",true,false):
  var title:=str(mesh.name).to_lower().replace(" ","_")
  if "cabinet_handle" in title:mesh.hide()
  elif "water_damaged_cabinet_panels" in title:
   for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,green)
   worn_surfaces+=1
  elif "hand_polished_worktops" in title:
   for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,steel)
   worn_surfaces+=1
 for i in range(5):
  var z: float=-32.30+i*1.15;var metal: Material=w.materials.rust if i==0 else w.materials.metal if i%2 else w.materials.gold
  var reach:=.06 if i!=3 else .045
  for side in [-1,1]:w.tube(root,Vector3(-16.115,.8,z+side*.13),Vector3(-16.115+reach,.8,z+side*.13),.014,metal)
  if i==3:
   for side in [-1,1]:box(root,Vector3(-16.065,.81,z+side*.13),Vector3(.028,.08,.035),metal)
   box(root,Vector3(-16.026,.80,z),Vector3(.035,.038,.29),w.materials.wood)
  else:w.tube(root,Vector3(-16.115+reach,.80,z-.13),Vector3(-16.115+reach,.80,z+.13),.020 if i==2 else .014,metal)
  handle_styles+=1
  # Lifted laminate is attached to each door's lower edge, with uneven fibres.
  var strip:=SurfaceTool.new();strip.begin(Mesh.PRIMITIVE_TRIANGLES)
  for chip in range(18):
   var a:=float(chip)/18.;var b:=float(chip+1)/18.
   var points:=[Vector3(-16.126,.264,z-.43+a*.86),Vector3(-16.126,.264,z-.43+b*.86),Vector3(-16.123-sin(a*21.+i)*.003,.245+sin(a*43.+i)*.004,z-.43+a*.86),Vector3(-16.123-sin(b*21.+i)*.003,.245+sin(b*43.+i)*.004,z-.43+b*.86)]
   for corner in [0,2,1,1,2,3]:strip.set_uv(Vector2(points[corner].z*3.,points[corner].y*3.));strip.add_vertex(points[corner])
  strip.generate_normals();strip.generate_tangents()
  var edge:=MeshInstance3D.new();edge.name="LiftedCabinetLaminate";edge.mesh=strip.commit();edge.material_override=w.materials.wood;root.add_child(edge);parts+=1
 for hood in w.annex.get_children():
  if hood is MeshInstance3D and hood.global_position.distance_to(Vector3(-13.25,2.8,-31.25))<.01:hood.material_override=grease
 # A tightly bounded wall stain sits above the pan rail, not across other props.
 var stain:=w.atmosphere.decal(root,2,Vector3(-17.177,2.78,-31.5),Vector2(1.58,.65),Vector3(0,PI/2,0),Color(.25,.19,.10,.62));stain.name="HobWallGrease"
 # A real U-trap is visible at the sink toe-kick, with clips at its ends.
 w.tube(root,Vector3(-16.10,.26,-28.65),Vector3(-16.10,.14,-28.65),.026,w.materials.metal)
 for j in range(12):
  var a:=PI+j*PI/12.;var b:=PI+(j+1)*PI/12.
  w.tube(root,Vector3(-16.10,.14+sin(a)*.07,-28.58+cos(a)*.07),Vector3(-16.10,.14+sin(b)*.07,-28.58+cos(b)*.07),.025,w.materials.metal)
 w.tube(root,Vector3(-16.10,.14,-28.51),Vector3(-16.10,.27,-28.51),.025,w.materials.metal)
 for z in [-28.65,-28.51]:box(root,Vector3(-16.12,.25,z),Vector3(.04,.035,.065),w.materials.rust)

func _walls() -> void:
 var root:=Node3D.new();root.name="RecessesAndBuildingJoinery";add_child(root)
 # These are claddings joined to real walls and ceiling, not freestanding props.
 for spec in [Vector2(-9.87,-3.45),Vector2(19.47,8.95)]:
  box(root,Vector3(spec.x,3.64,spec.y),Vector3(.25,7.25,.22),w.materials.teal)
  for y in [.18,1.15,7.20]:box(root,Vector3(spec.x,y,spec.y),Vector3(.28,.055,.27),w.materials.metal)
 _case(root,Vector3(-10.025,1.85,16.2),PI/2,"FUNDBÄNDER / 1998",false)
 _case(root,Vector3(19.625,2.02,14.65),-PI/2,"ERSATZTEILE / HAPPYLAND",true)

func _case(parent: Node3D,p: Vector3,yaw: float,words: String,toys: bool) -> void:
 var root:=Node3D.new();root.name="RecessedDisplayCase";root.position=p;root.rotation.y=yaw;parent.add_child(root)
 var backing:=box(root,Vector3(0,0,.012),Vector3(1.17,.87,.025),w.materials.dark);backing.set_meta("mounted_art",true)
 for x in [-.59,.59]:box(root,Vector3(x,0,.055),Vector3(.045,.92,.20),w.materials.wood)
 for y in [-.44,.44]:box(root,Vector3(0,y,.055),Vector3(1.22,.04,.20),w.materials.wood)
 for i in range(5):
  var x: float=-.43+i*.215
  w.tube(root,Vector3(x,.26,0),Vector3(x,.26,.065),.012,w.materials.metal)
  if toys:
   var button:=w.sphere(root,Vector3(x,.1,.052),.063,w.materials.gold if i%2 else w.materials.cream);button.scale.z=.33
   for side in [-1,1]:w.tube(root,Vector3(x+side*.016,.11,.075),Vector3(x+side*.016,.09,.075),.005,w.materials.dark)
  else:
   box(root,Vector3(x,.11,.05),Vector3(.105,.27,.008),w.materials.red if i%2 else w.materials.teal)
   w.venue.text(root,"%02d"%(i+1),Vector3(x,.11,.059),.036,Color("cabc9f"))
  box(root,Vector3(x,-.18,.034),Vector3(.14,.075,.002),w.materials.paper)
 w.venue.text(root,words,Vector3(0,-.36,.04),.048,Color("baa882"))
 var glass:=w.mat(Color(.32,.39,.35,.10),null,.24);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.normal_enabled=true;glass.normal_texture=w.atmosphere.micro_normal;glass.normal_scale=.035
 var face:=box(root,Vector3(0,0,.13),Vector3(1.13,.83,.003),glass);face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _litter() -> void:
 # Rehome old uniformly spread cinema litter under seats and beside the bin.
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.get_meta("cinema_litter",false):mesh.hide()
 var rng:=RandomNumberGenerator.new();rng.seed=340
 for center in [Vector2(-4.22,-33.0),Vector2(-2.75,-31.9),Vector2(-1.28,-28.6),Vector2(.24,-26.4),Vector2(-5.39,-33.9)]:
  litter_zones.append(Rect2(center-Vector2(.22,.23),Vector2(.44,.46)))
  for i in range(11):
   var point:=Vector3(center.x+rng.randf_range(-.18,.18),.023,center.y+rng.randf_range(-.19,.19))
   var kernel:=w.sphere(self,point,.012,w.materials.cream);kernel.scale=Vector3(1.1,.9,1.3);parts+=1
   if i%3==0:
    var crumb:=w.sphere(kernel,Vector3(.008,.004,-.005),.007,w.materials.gold);crumb.scale.y=.8
  var wrapper:=box(self,Vector3(center.x+.12,.014,center.y+.1),Vector3(.13,.003,.09),w.materials.paper);wrapper.rotation.y=rng.randf_range(-1,1)
  var crease:=box(wrapper,Vector3(.04,.012,0),Vector3(.04,.002,.09),w.materials.paper);crease.rotation.z=-.55
 for i in range(7):
  var wrap:=box(self,Vector3(-8.36+i*.065,.016,8.42+sin(i*2.)*.10),Vector3(.06,.003,.08),w.materials.paper if i%2 else w.materials.red);wrap.rotation.y=i*.81

func spot(parent: Node3D,p: Vector3,target: Vector3,color: Color,power: float,angle: float,reach: float,role: String) -> SpotLight3D:
 var light:=SpotLight3D.new();light.position=p;parent.add_child(light)
 var straight:=absf((target-light.global_position).normalized().dot(Vector3.UP))>.99
 light.look_at(target,Vector3.FORWARD if straight else Vector3.UP)
 light.light_color=color;light.light_energy=power;light.spot_angle=angle;light.spot_range=reach;light.spot_angle_attenuation=1.6;light.light_volumetric_fog_energy=.55;light.shadow_enabled=not OS.has_feature("web");light.shadow_bias=.025
 lights.append({"light":light,"role":role});return light

func _lighting() -> void:
 # Preserve actual lamps, but shorten broad fills so darkness separates rooms.
 w.party_light.light_energy=.32;w.party_light.omni_range=4.8
 if w.native_art:
  for light in w.native_art.spots:
   if light.position.x>6.8 and light.position.z<1.6:light.light_energy=.45;light.spot_angle=39
 for item in w.room_horror.bulbs:
  if item.light.global_position.x> -6.45 and item.light.global_position.z< -24.1:item.energy=.24
 for light in w.practicals:
  if light.position.z< -24.1 and light.position.x> -6.45 and light.position.y>1:light.light_energy=minf(light.light_energy,.27)
  if light.position.distance_to(Vector3(2.8,2.2,-29.7))<.1:light.light_energy=.48;light.omni_range=5.2;light.light_color=Color("91b4cc")
  if absf(light.position.x+7.9)<.1 and light.position.z< -12.3:light.light_energy=.58;light.omni_range=3.5
 for light in w.annex.get_children():
  if light is SpotLight3D:light.light_energy=.72;light.light_color=Color("91b4cc");light.spot_angle=22
 # Complete the existing suspended party fixture with a down-facing reflector.
 var p:=Vector3(10.2,6.72,-7)
 w.tube(self,p-Vector3(0,.11,0),p,.16,w.materials.metal)
 var glow:=w.mat(Color("c7ad77"),null,.5);glow.emission_enabled=true;glow.emission=Color("e3bc72");glow.emission_energy_multiplier=.65;emitters.append(glow)
 w.tube(self,p-Vector3(0,.115,0),p-Vector3(0,.107,0),.125,glow)
 spot(self,p-Vector3(0,.14,0),Vector3(10.2,.84,-7),Color("e3b77b"),3.5,34,7.3,"party")
 spot(self,Vector3(-5.78,2.5,-32.9),Vector3(-4.8,1.5,-32.9),Color("d6cba5"),.22,53,2.5,"cinema")
 for z in [-33.45,-25.95]:
  w.tube(self,Vector3(3.33,3.35,z),Vector3(2.95,3.35,z),.016,w.materials.metal)
  var can:=box(self,Vector3(2.95,3.25,z),Vector3(.12,.19,.13),w.materials.dark);can.name="AttachedStageWash"
  spot(self,Vector3(2.94,3.15,z),Vector3(3.42,1.4,z),Color("91b4cc"),1.4,36,3.4,"cinema")
 w.backstage.old_light.light_color=Color("82a88d");w.backstage.old_light.light_energy=.32;w.backstage.old_light.omni_range=3.7

func configure(id: String) -> void:
 for record in lights:
  if id=="party_dark" and record.role=="party":record.light.light_energy=0
  if id=="lights_red":record.light.light_color=Color("e22c28")
 if id=="lights_red":
  for m in emitters:m.emission=Color("e22c28")

func quality(value: int) -> void:
 for record in lights:record.light.shadow_enabled=value>0 and not OS.has_feature("web")

func clear_pose(point: Vector3) -> bool:
 var guard:=AABB(point+Vector3(-.28,.08,-.28),Vector3(.56,1.62,.56))
 for bounds in obstacles:
  if guard.intersects(bounds):return false
 return true

func surface_at(point: Vector3) -> String:
 return "rubber" if absf(point.y-.014)<.04 and RUBBER.has_point(Vector2(point.x,point.z)) else ""

func snapshot() -> Dictionary:
 return {"parts":parts,"floor_finishes":floors.size(),"handles":handle_styles,"worn_surfaces":worn_surfaces,"litter_clusters":litter_zones.size(),"ticket_desk":has_node("CinemaFacadeAndProscenium/CinemaTicketInspection"),"light_islands":lights.size()}
