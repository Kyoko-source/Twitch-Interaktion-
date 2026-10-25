class_name AfterPlayDetails
extends Node3D

var w: PlayWorld
var clusters: Array[Node3D]=[]
var screens: Array[ShaderMaterial]=[]
var hum: AudioStreamPlayer3D
var clock:=0.0
var labels: Dictionary={}
var obstacles: Array[AABB]=[]
var steel: StandardMaterial3D
var enamel: StandardMaterial3D
var timber: StandardMaterial3D
var cloth: StandardMaterial3D

func build(world: PlayWorld) -> void:
 w=world;name="AfterPlayDetails"
 steel=w.mat(Color("53615a"),load("res://assets/paint.png"),.62,.62)
 enamel=w.mat(Color("b6ae91"),load("res://assets/aged-plaster.png"),.87)
 timber=w.mat(Color("776049"),load("res://assets/wood.png"),.86)
 cloth=w.mat(Color("665e49"),load("res://assets/pbr/fabric_pattern_07/albedo.jpg"),.98)
 for m in [steel,enamel,timber,cloth]:
  m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*2
  m.normal_enabled=true;m.normal_texture=w.atmosphere.micro_normal;m.normal_scale=.18
 _reception();_lost_property();_arcade();_party();_kitchen();_cinema();_maintenance();_service_hall()
 hum=AudioStreamPlayer3D.new();hum.name="ArcadeIdleHum";hum.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var loop: AudioStreamOggVorbis=load("res://assets/ambience/ventilation.ogg").duplicate();loop.loop=true;hum.stream=loop;hum.position=Vector3(8.5,1,16.2)
 hum.volume_db=-38;hum.max_distance=3;hum.unit_size=.7;hum.bus="Interior" if w.native_art else "Master";add_child(hum)
 for group in clusters:
  for shape in group.find_children("*","CollisionShape3D",true,false):
   if shape.shape and not shape.disabled: obstacles.append(shape.global_transform*shape.shape.get_debug_mesh().get_aabb())

func clear_pose(point: Vector3) -> bool:
 # A save made before the furniture update must not embed the guard in a cabinet.
 var guard:=AABB(point+Vector3(-.27,.08,-.27),Vector3(.54,1.62,.54))
 for obstacle in obstacles:
  if guard.intersects(obstacle): return false
 return true

func cluster(parent: Node3D, id: String, pos: Vector3, yaw: float=0) -> Node3D:
 var node:=Node3D.new();node.name=id;node.position=pos;node.rotation.y=yaw;parent.add_child(node)
 node.set_meta("environment_dressing",true);clusters.append(node);return node

func label(parent: Node3D, id: String, pos: Vector3, size: Vector2) -> void:
 if not labels.has(id): labels[id]=DressingPrint.texture(self,id)
 var face:=MeshInstance3D.new();face.name="PrintedLabel";var quad:=QuadMesh.new();quad.size=size;face.mesh=quad
 face.position=pos;face.material_override=w.mat(Color("bdb69e"),labels[id],.88);face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(face)

func ring(parent: Node3D, pos: Vector3, radius: float, material: Material, rotation_value: Vector3=Vector3.ZERO, width: float=.012) -> void:
 var node:=MeshInstance3D.new();var shape:=TorusMesh.new();shape.inner_radius=radius-width;shape.outer_radius=radius;shape.rings=20;shape.ring_segments=6
 node.mesh=shape;node.material_override=material;node.position=pos;node.rotation=rotation_value;parent.add_child(node)

func plate(parent: Node3D, pos: Vector3, radius: float=.17) -> void:
 SurfaceDetails.vessel(parent,pos,.026,radius,radius*.78,.009,enamel,enamel,"UsedPlate")
 w.tube(parent,pos+Vector3(0,.010,0),pos+Vector3(0,.012,0),radius*.58,w.mat(Color("685940"),null,.99))

func cup(parent: Node3D, pos: Vector3, material: Material) -> void:
 SurfaceDetails.vessel(parent,pos,.12,.052,.038,.007,material,enamel,"PaperCup")
 ring(parent,pos+Vector3(0,.12,0),.055,enamel,Vector3.ZERO,.004)

func bottle(parent: Node3D, pos: Vector3, height: float, material: Material) -> void:
 # A lathed shoulder and narrow neck preserve a real bottle silhouette.
 var profile: Array[Vector2]=[Vector2(.055,0),Vector2(.063,.025),Vector2(.063,height*.65),Vector2(.024,height*.79),Vector2(.024,height*.95)]
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(profile.size()-1):
  for i in range(24):
   var a:=TAU*i/24;var b:=TAU*(i+1)/24;var p:=profile[row];var q:=profile[row+1]
   var normal:=Vector3(cos((a+b)*.5),(p.x-q.x)/maxf(.001,q.y-p.y),sin((a+b)*.5)).normalized()
   var aa:=Vector3(cos(a)*p.x,p.y,sin(a)*p.x);var ab:=Vector3(cos(b)*p.x,p.y,sin(b)*p.x)
   var ba:=Vector3(cos(a)*q.x,q.y,sin(a)*q.x);var bb:=Vector3(cos(b)*q.x,q.y,sin(b)*q.x)
   SurfaceDetails.triangle(st,aa,ba,bb,normal);SurfaceDetails.triangle(st,aa,bb,ab,normal)
 var mesh:=MeshInstance3D.new();mesh.name="ShoulderedBottle";mesh.mesh=st.commit();mesh.material_override=material;mesh.position=pos;parent.add_child(mesh)
 w.tube(parent,pos+Vector3(0,height*.95,0),pos+Vector3(0,height,0),.028,steel)
 w.box(parent,pos+Vector3(0,height*.43,.064),Vector3(.068,.10,.004),enamel)

func _reception() -> void:
 var bench:=cluster(self,"ReceptionBenchBelongings",Vector3(-9.5,.016,13.5),PI/2)
 var bag:=w.box(bench,Vector3(.28,.654,.02),Vector3(.34,.22,.20),cloth)
 for side in [-1,1]:
  w.box(bag,Vector3(side*.10,0,.105),Vector3(.035,.22,.008),timber)
  ring(bag,Vector3(side*.09,.10,0),.045,steel,Vector3(PI/2,0,0),.006)
 w.tube(bag,Vector3(-.09,.10,0),Vector3(0,.23,0),.012,cloth);w.tube(bag,Vector3(0,.23,0),Vector3(.09,.10,0),.012,cloth)
 for side in [-1,1]:
  var shoe:=w.box(bench,Vector3(-.45+side*.09,.072,.03),Vector3(.12,.11,.27),w.materials.red);shoe.rotation.y=side*.1
  w.box(shoe,Vector3(0,-.04,.015),Vector3(.126,.035,.29),enamel)
  for z in [-.06,-.02,.02]: w.tube(shoe,Vector3(-.04,.057,z),Vector3(.04,.057,z+.015),.004,enamel)
 var rail:=cluster(self,"ReceptionCoatRail",Vector3(-10.02,0,15.8),PI/2)
 w.box(rail,Vector3(0,1.75,0),Vector3(1.45,.11,.06),timber)
 for x in [-.55,-.18,.18,.55]:
  w.tube(rail,Vector3(x,1.74,.03),Vector3(x,1.69,.13),.015,steel)
  w.tube(rail,Vector3(x,1.69,.13),Vector3(x,1.76,.14),.015,steel)
 _jacket(rail,Vector3(-.18,1.66,.12))
 var till:=cluster(w.props.counter,"AdmissionWristbands",Vector3(.07,1.005,1.03),-PI/2)
 w.box(till,Vector3(0,.08,0),Vector3(.23,.16,.21),steel)
 for i in range(3):
  w.tube(till,Vector3(-.07,.17,-.05+i*.06),Vector3(.07,.17,-.05+i*.06),.042,[w.materials.gold,w.materials.red,w.materials.teal][i])
  w.box(till,Vector3(.11,.16,-.05+i*.06),Vector3(.08,.012,.045),enamel)
 label(till,"tickets",Vector3(0,.075,.108),Vector2(.21,.055))

func _jacket(parent: Node3D, pos: Vector3) -> void:
 var root:=Node3D.new();root.name="ForgottenJacket";root.position=pos;parent.add_child(root)
 w.tube(root,Vector3(-.19,-.035,0),Vector3(0,.015,0),.008,steel);w.tube(root,Vector3(0,.015,0),Vector3(.19,-.035,0),.008,steel)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(14):
  for col in range(16):
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
    var u: float=(col+corner.x)/16.0;var v: float=(row+corner.y)/14.0
    var width:=.22+sin(v*PI)*.07
    st.set_uv(Vector2(u*2,v*3));st.add_vertex(Vector3((u-.5)*width*2,-.03-v*.64,.03+.027*sin(u*TAU*5)+v*.025))
 st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();var material:=cloth.duplicate() as StandardMaterial3D;material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=material;root.add_child(mesh)
 for side in [-1,1]:
  var arm:=w.box(root,Vector3(side*.28,-.29,.02),Vector3(.14,.43,.09),cloth);arm.rotation.z=side*.29
 w.tube(root,Vector3(0,-.07,.08),Vector3(0,-.62,.08),.005,steel)

func _arcade() -> void:
 _cabinet(Vector3(7.5,.016,16.50),PI,"arcade",w.materials.teal)
 _cabinet(Vector3(9.0,.016,16.50),PI,"orbit",w.materials.red)
 var prize:=cluster(self,"ArcadePrizeCabinet",Vector3(11.0,.016,16.50),PI)
 w.box(prize,Vector3(0,.36,0),Vector3(1.22,.72,.79),w.materials.gold,true)
 w.box(prize,Vector3(0,1.42,-.34),Vector3(1.22,1.38,.10),steel,true)
 for side in [-1,1]:
  w.box(prize,Vector3(side*.59,1.40,0),Vector3(.06,1.40,.75),steel,true)
  w.box(prize,Vector3(side*.59,1.40,.34),Vector3(.075,1.40,.075),steel)
 for y in [.75,1.94]: w.box(prize,Vector3(0,y,.34),Vector3(1.2,.06,.07),steel)
 w.box(prize,Vector3(0,2.02,0),Vector3(1.26,.19,.82),w.materials.teal)
 label(prize,"prizes",Vector3(0,2.02,.418),Vector2(1.17,.14))
 var glass:=w.mat(Color(.30,.39,.35,.11),null,.16);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
 var pane:=w.box(prize,Vector3(0,1.34,.337),Vector3(1.11,1.10,.012),glass,true);pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 w.box(prize,Vector3(0,1.28,0),Vector3(1.10,.035,.65),steel)
 for row in range(2):
  for i in range(4):
   var item:=Node3D.new();item.name="PrizeToy";item.position=Vector3(-.4+i*.26,.78+row*.52,0);prize.add_child(item)
   var fabric: Material=[w.materials.gold,w.materials.teal,w.materials.red][i%3]
   var body:=w.sphere(item,Vector3(0,.10,0),.095,fabric);body.scale=Vector3(.8,1.1,.7)
   w.sphere(item,Vector3(0,.24,0),.075,fabric)
   for side in [-1,1]:
    var ear:=w.sphere(item,Vector3(side*.035,.33,0),.027,fabric);ear.scale.y=2.0
    w.sphere(item,Vector3(side*.027,.25,.064),.009,w.materials.dark)
 w.box(prize,Vector3(0,.40,.405),Vector3(.62,.25,.04),steel)
 w.box(prize,Vector3(0,.40,.432),Vector3(.52,.16,.018),w.materials.dark)

func _cabinet(pos: Vector3, yaw: float, id: String, material: Material) -> void:
 var root:=cluster(self,"Arcade_"+id,pos,yaw)
 # Extruded side profile: plinth, control overhang, sloping CRT and marquee.
 var profile:=PackedVector2Array([Vector2(-.37,0),Vector2(.36,0),Vector2(.42,.88),Vector2(.49,.94),Vector2(.45,1.05),Vector2(.20,1.10),Vector2(.10,1.69),Vector2(.33,1.77),Vector2(.33,1.99),Vector2(-.37,1.99)])
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var triangles:=Geometry2D.triangulate_polygon(profile)
 for side in [-1,1]:
  for i in range(0,triangles.size(),3):
   var a:=profile[triangles[i]];var b:=profile[triangles[i+1]];var c:=profile[triangles[i+2]]
   SurfaceDetails.triangle(st,Vector3(side*.37,a.y,a.x),Vector3(side*.37,b.y,b.x),Vector3(side*.37,c.y,c.x),Vector3.RIGHT*side)
 for i in range(profile.size()):
  var a:=profile[i];var b:=profile[(i+1)%profile.size()];var normal:=Vector3(0,a.x-b.x,b.y-a.y).normalized()
  SurfaceDetails.triangle(st,Vector3(-.37,a.y,a.x),Vector3(.37,a.y,a.x),Vector3(.37,b.y,b.x),normal)
  SurfaceDetails.triangle(st,Vector3(-.37,a.y,a.x),Vector3(.37,b.y,b.x),Vector3(-.37,b.y,b.x),normal)
 var shell:=MeshInstance3D.new();shell.name="ShapedArcadeCabinet";shell.mesh=st.commit();shell.material_override=material;root.add_child(shell);shell.create_convex_collision()
 for side in [-1,1]: w.box(root,Vector3(side*.378,.58,.12),Vector3(.016,1.0,.36),enamel)
 label(root,id,Vector3(0,1.88,.337),Vector2(.65,.16))
 var screen:=Node3D.new();screen.position=Vector3(0,1.42,.174);screen.rotation.x=-.16;root.add_child(screen)
 w.box(screen,Vector3.ZERO,Vector3(.65,.56,.06),w.materials.dark)
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.56,.43);mesh.mesh=quad;mesh.position.z=.034;screen.add_child(mesh)
 var shader:=Shader.new();shader.code="""
shader_type spatial;render_mode unshaded;
uniform float clock=0.0;uniform vec3 tint:source_color=vec3(.24,.46,.35);
void fragment(){vec2 p=UV;vec2 q=floor(p*vec2(64.,48.));float grid=step(.92,fract(q.x*.17+q.y*.31));float star=step(.98,fract(sin(dot(q,vec2(12.9898,78.233)))*43758.5453));vec2 ball=vec2(.5+.25*sin(clock*.45),.48+.26*cos(clock*.6));float orb=1.-smoothstep(.023,.034,distance(p,ball));float scan=.78+.22*sin(p.y*550.);float edge=smoothstep(.52,.12,length(p-.5));ALBEDO=(tint*(.09+grid*.12+star*.32)+vec3(.8,.51,.19)*orb)*scan*edge;}
"""
 var screen_material:=ShaderMaterial.new();screen_material.shader=shader;screen_material.set_shader_parameter("tint",Color("497b68") if id=="arcade" else Color("8e5646"));mesh.material_override=screen_material;screens.append(screen_material)
 var deck:=w.box(root,Vector3(0,1.091,.32),Vector3(.65,.025,.28),w.materials.dark);deck.rotation.x=.197
 w.tube(root,Vector3(-.16,1.11,.31),Vector3(-.16,1.23,.31),.013,steel);w.sphere(root,Vector3(-.16,1.25,.31),.035,w.materials.red)
 for i in range(3): w.tube(root,Vector3(.05+i*.075,1.11,.31),Vector3(.05+i*.075,1.125,.31),.024,w.materials.gold)
 w.box(root,Vector3(0,.60,.401),Vector3(.21,.27,.018),steel)
 w.box(root,Vector3(.045,.65,.414),Vector3(.022,.10,.009),w.materials.dark)
 for i in range(7): w.box(root,Vector3(-.20+i*.066,.20,.381),Vector3(.026,.11,.012),w.materials.dark)
 for side in [-1,1]: w.tube(root,Vector3(side*.28,.003,-.27),Vector3(side*.28,.03,-.27),.03,steel)

func _party() -> void:
 var previous: Node3D=w.props.party_table.get_node_or_null("LegacyPartyTableware")
 if previous: previous.hide()
 var places:=cluster(w.props.party_table,"AbandonedBirthdayPlaces",Vector3(0,.852,0))
 for side in [-1,1]:
  for row in range(3):
   var x: float=8.5+side*.65;var z:=-8.0+row
   plate(places,Vector3(x,0,z));cup(places,Vector3(x+side*.19,.006,z+.23),w.materials.red if row%2 else w.materials.teal)
   var napkin:=w.box(places,Vector3(x,.012,z-.27),Vector3(.22,.012,.14),cloth);napkin.rotation.y=.13*(row-1)
   w.box(places,Vector3(x-side*.23,.01,z),Vector3(.018,.009,.22),steel)
   for i in range(3): w.tube(places,Vector3(x-side*.23-.012+i*.012,.016,z-.11),Vector3(x-side*.23-.012+i*.012,.016,z-.15),.003,steel)
 var trolley:=cluster(self,"PartyServiceTrolley",Vector3(18.9,.016,-7.0),-PI/2)
 _cart(trolley,Vector2(1.2,.54))
 for i in range(6): plate(trolley,Vector3(-.30,.87+i*.02,0),.18)
 for i in range(3): bottle(trolley,Vector3(.17+i*.13,.87,0),.28,w.materials.teal)
 for i in range(4): w.box(trolley,Vector3(-.3+i*.19,.29,0),Vector3(.16,.29,.34),enamel)
 label(trolley,"service",Vector3(0,.59,.283),Vector2(.98,.245))

func _cart(root: Node3D, size: Vector2) -> void:
 for y in [.25,.83]: w.box(root,Vector3(0,y,0),Vector3(size.x,.055,size.y),steel,true)
 for x in [-size.x*.43,size.x*.43]:
  for z in [-size.y*.38,size.y*.38]:
   w.tube(root,Vector3(x,.09,z),Vector3(x,.91,z),.018,steel)
   w.tube(root,Vector3(x-.035,.08,z),Vector3(x+.035,.08,z),.065,w.materials.dark)
 for z in [-size.y*.40,size.y*.40]: w.tube(root,Vector3(-size.x*.43,.93,z),Vector3(size.x*.43,.93,z),.016,steel)

func _kitchen() -> void:
 var prep:=cluster(w.annex,"KitchenBottleAndUtensilShelf",Vector3(-12.95,1.006,-22.33))
 for i in range(4): bottle(prep,Vector3(-.28+i*.14,0,0),.24+i*.02,w.materials.teal if i%2 else w.materials.gold)
 var rack:=cluster(w.annex,"KitchenDryingRack",Vector3(-16.65,1.075,-15.45))
 w.box(rack,Vector3(0,.015,0),Vector3(.67,.03,.48),steel)
 for i in range(6):
  var dish:=Node3D.new();dish.position=Vector3(-.23+i*.085,.20,0);dish.rotation.z=PI/2;dish.rotation.x=.12;rack.add_child(dish);plate(dish,Vector3.ZERO,.17)
 for z in [-.21,.21]: w.tube(rack,Vector3(-.30,.10,z),Vector3(.30,.10,z),.009,steel)
 var box:=cluster(w.annex,"KitchenProduceCrate",Vector3(-12.0,.018,-13.85))
 _crate(box,Vector3(.8,.34,.54))
 for i in range(10):
  var fruit:=w.sphere(box,Vector3(-.27+(i%4)*.17,.28+floori(i/4.0)*.045,-.13+floori(i/4.0)*.12),.075,w.materials.gold);fruit.scale=Vector3(1,.74,1.35)

func _crate(root: Node3D, size: Vector3) -> void:
 var body:=StaticBody3D.new();body.position.y=size.y*.5;root.add_child(body)
 var collider:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=size;collider.shape=bounds;body.add_child(collider)
 w.box(root,Vector3(0,.035,0),Vector3(size.x,.07,size.z),timber)
 for side in [-1,1]:
  for y in [size.y*.30,size.y*.76]:
   w.box(root,Vector3(side*size.x*.5,y,0),Vector3(.035,size.y*.28,size.z),timber)
   w.box(root,Vector3(0,y,side*size.z*.5),Vector3(size.x,size.y*.28,.035),timber)
  for z in [-size.z*.43,size.z*.43]: w.box(root,Vector3(side*size.x*.44,size.y*.5,z),Vector3(.045,size.y,.045),timber)

func _cinema() -> void:
 var cart:=cluster(w.annex,"ForgottenPopcornTrolley",Vector3(2.05,.018,-14.35),PI)
 _cart(cart,Vector2(.86,.58))
 var paint:=w.mat(Color("773e36"),load("res://assets/paint.png"),.76,.25)
 for side in [-1,1]:
  for z in [-.25,.25]: w.box(cart,Vector3(side*.39,1.13,z),Vector3(.045,.64,.045),paint)
 var window:=w.mat(Color(.38,.41,.31,.10),null,.18);window.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;window.cull_mode=BaseMaterial3D.CULL_DISABLED
 for side in [-1,1]:
  var pane:=w.box(cart,Vector3(side*.37,1.14,0),Vector3(.009,.50,.46),window);pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var front:=w.box(cart,Vector3(0,1.14,.263),Vector3(.71,.50,.009),window);front.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 w.box(cart,Vector3(0,1.46,0),Vector3(.92,.12,.65),paint)
 w.box(cart,Vector3(0,1.12,-.25),Vector3(.75,.52,.035),enamel)
 label(cart,"popcorn",Vector3(0,1.47,.332),Vector2(.84,.14))
 SurfaceDetails.vessel(cart,Vector3(0,.88,0),.17,.22,.16,.014,steel,w.materials.dark,"ColdPopcornKettle")
 for i in range(24): w.sphere(cart,Vector3(-.16+fmod(i*.127,.32),1.06+sin(i*3.1)*.012,-.14+fmod(i*.193,.28)),.023,enamel)
 for i in range(3): cup(cart,Vector3(-.25+i*.22,.28,0),paint)

func _maintenance() -> void:
 var cart:=cluster(w.server_room,"JanitorServiceCart",Vector3(-13.0,.018,-6.28))
 _cart(cart,Vector2(.9,.55))
 SurfaceDetails.vessel(cart,Vector3(-.18,.87,0),.24,.115,.09,.012,enamel,w.materials.dark,"CleaningBucket")
 ring(cart,Vector3(-.18,1.11,0),.12,steel,Vector3.ZERO,.006)
 for i in range(2): bottle(cart,Vector3(.13+i*.14,.87,.02),.27,w.materials.teal)
 var cloth_roll:=w.box(cart,Vector3(0,.31,0),Vector3(.57,.075,.39),cloth);cloth_roll.rotation.y=.08
 w.tube(cart,Vector3(.28,.2,-.19),Vector3(.36,1.50,-.19),.014,timber)
 w.box(cart,Vector3(.28,.16,-.19),Vector3(.32,.075,.12),cloth)
 var shelf:=cluster(w.server_room,"LabelledSpareParts",Vector3(-14.1,.95,-6.65))
 # The narrow shelf sits above the cart's left neighbour, below the wall notices.
 w.box(shelf,Vector3.ZERO,Vector3(1.3,.045,.30),steel)
 for i in range(4):
  var packet:=w.box(shelf,Vector3(-.47+i*.30,.13,0),Vector3(.23,.22,.24),timber)
  w.box(packet,Vector3(0,.02,.124),Vector3(.17,.07,.008),enamel)
 for x in [-.5,.5]: w.tube(shelf,Vector3(x,-.2,-.185),Vector3(x,-.02,.12),.013,steel)

func _service_hall() -> void:
 var notice:=cluster(self,"ServiceApproachNotice",Vector3(-9.295,0,-18.0),PI/2)
 w.box(notice,Vector3(0,1.9,0),Vector3(1.45,.52,.045),timber)
 label(notice,"maintenance",Vector3(0,1.9,.026),Vector2(1.34,.335))
 var board:=Node3D.new();board.name="ServiceKeyBoard";board.position=Vector3(0,1.32,.045);notice.add_child(board)
 w.box(board,Vector3.ZERO,Vector3(.86,.35,.045),timber)
 var brass:=w.mat(Color("98845c"),load("res://assets/paint.png"),.48,.7)
 for x in [-.27,0,.27]:
  for y in [-.125,.125]: w.sphere(board,Vector3(x,y,.027),.008,steel)
  w.tube(board,Vector3(x,.07,.026),Vector3(x,.07,.10),.009,steel)
  w.tube(board,Vector3(x,.07,.10),Vector3(x,.09,.10),.009,steel)
  if x==0: continue # One missing key leaves an actual empty hook.
  ring(board,Vector3(x,.052,.104),.038,steel,Vector3(PI/2,0,0),.005)
  ring(board,Vector3(x,.012,.11),.023,brass,Vector3(PI/2,0,0),.006)
  w.box(board,Vector3(x,-.06,.11),Vector3(.013,.105,.014),brass)
  for y in [-.075,-.105]: w.box(board,Vector3(x+.014,y,.11),Vector3(.027,.013,.014),brass)

func tick(delta: float, active: bool) -> void:
 hum.stream_paused=not active
 if active and not hum.playing: hum.play()
 if not active: return
 clock+=delta
 for screen in screens: screen.set_shader_parameter("clock",clock)

func snapshot() -> Dictionary:
 return {"groups":clusters.size(),"screens":screens.size(),"clock":clock,"names":clusters.map(func(n):return str(n.name))}

func _lost_property() -> void:
 var shelf:=cluster(self,"LostPropertyCubbies",Vector3(2.2,.016,-11.70))
 for x in [-.84,.84]: w.box(shelf,Vector3(x,.57,0),Vector3(.055,1.14,.48),timber,true)
 for y in [.08,.43,.78,1.14]: w.box(shelf,Vector3(0,y,0),Vector3(1.73,.045,.48),timber,true)
 w.box(shelf,Vector3(0,.59,-.22),Vector3(1.7,1.1,.04),timber)
 for x in [-.28,.28]: w.box(shelf,Vector3(x,.59,0),Vector3(.03,1.08,.46),timber)
 for row in range(3):
  for col in range(3):
   var x: float=-.56+col*.56;var y: float=.106+row*.35
   if (row+col)%2==0:
    for k in range(3): w.box(shelf,Vector3(x,y+.025+k*.044,.02),Vector3(.39,.042,.32),cloth if k%2 else enamel)
   else:
    var item:=w.box(shelf,Vector3(x,y+.075,.02),Vector3(.35,.15,.32),w.materials.teal if row else w.materials.red)
    w.box(item,Vector3(0,.01,.164),Vector3(.12,.045,.008),enamel)
 label(shelf,"found",Vector3(0,1.41,-.22),Vector2(1.45,.36))
 w.box(shelf,Vector3(0,1.41,-.24),Vector3(1.55,.41,.035),timber)
 for x in [-.62,.62]: w.box(shelf,Vector3(x,1.20,-.22),Vector3(.04,.18,.05),timber)
 var stroller:=cluster(self,"AbandonedPushchair",Vector3(4.4,.016,-11.55),-.2)
 var body:=StaticBody3D.new();body.position.y=.54;stroller.add_child(body)
 var collider:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.59,1.08,.66);collider.shape=bounds;body.add_child(collider)
 for side in [-1,1]:
  for z in [-.25,.25]:
   w.tube(stroller,Vector3(side*.29-.025,.12,z),Vector3(side*.29+.025,.12,z),.115,w.materials.dark)
   w.tube(stroller,Vector3(side*.29-.027,.12,z),Vector3(side*.29+.027,.12,z),.045,steel)
  w.tube(stroller,Vector3(side*.25,.14,.25),Vector3(side*.22,.84,-.20),.016,steel)
  w.tube(stroller,Vector3(side*.25,.14,-.25),Vector3(side*.22,.56,.24),.016,steel)
  w.tube(stroller,Vector3(side*.22,.84,-.20),Vector3(side*.22,1.05,-.32),.018,steel)
 w.tube(stroller,Vector3(-.22,1.05,-.32),Vector3(.22,1.05,-.32),.023,w.materials.dark)
 w.box(stroller,Vector3(0,.45,.025),Vector3(.43,.05,.43),cloth)
 var back:=w.box(stroller,Vector3(0,.66,-.17),Vector3(.43,.43,.045),cloth);back.rotation.x=-.16
 for side in [-1,1]: w.tube(stroller,Vector3(side*.19,.68,-.19),Vector3(side*.13,.49,.12),.013,timber)
 w.box(stroller,Vector3(0,.48,.23),Vector3(.32,.045,.15),steel)
