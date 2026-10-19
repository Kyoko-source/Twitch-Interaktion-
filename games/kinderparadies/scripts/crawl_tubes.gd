class_name CrawlTubes
extends Node3D

const RADIUS:=.9
const INNER:=.82
const CENTER_Y:=1.03
const LENGTH:=15.454867
const WINDOWS:=[{"s":3.4,"angle":0.0},{"s":7.4,"angle":PI/2},{"s":11.8,"angle":PI}]
var w: PlayWorld
var watcher: Node3D
var face: Node3D
var inside:=false
var watcher_enabled:=false

static func route(s: float) -> Vector3:
 s=clampf(s,0,LENGTH)
 if s<2.1: return Vector3(-5.5,CENTER_Y,11.9+s)
 s-=2.1
 if s<PI*.9:
  var a:=PI-s/1.8;return Vector3(-3.7+cos(a)*1.8,CENTER_Y,14+sin(a)*1.8)
 s-=PI*.9
 if s<5.6: return Vector3(-3.7+s,CENTER_Y,15.8)
 s-=5.6
 if s<PI*.9:
  var a:=PI/2-s/1.8;return Vector3(1.9+cos(a)*1.8,CENTER_Y,14+sin(a)*1.8)
 s-=PI*.9
 return Vector3(3.7,CENTER_Y,14-s)

static func tangent(s: float) -> Vector3:
 return (route(s+.01)-route(s-.01)).normalized()

static func surface(s: float, angle: float, radius: float) -> Vector3:
 return route(s)+Vector3.UP.cross(tangent(s))*cos(angle)*radius+Vector3.UP*sin(angle)*radius

static func nearest(pos: Vector3) -> Dictionary:
 var best:=INF;var distance:=0.0
 for i in range(100):
  var s:=LENGTH*i/99.0;var p:=route(s)
  var d:=Vector2(pos.x-p.x,pos.z-p.z).length()
  if d<best: best=d;distance=s
 return {"distance":best,"s":distance}

func contains(pos: Vector3) -> bool:
 var n:=nearest(pos)
 return n.distance<.73 and pos.y<1.2 and n.s>.12 and n.s<LENGTH-.12

func near_entry(pos: Vector3) -> bool:
 for s in [0.0,LENGTH]:
  var p:=route(s);p.y=pos.y
  if p.distance_to(pos)<1.65: return true
 return false

func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
 var vertices: Array[Vector3]=[a,b,c]
 if (b-a).cross(c-a).dot(normal)>0: vertices.reverse()
 for p in vertices: tool.set_normal(normal);tool.set_uv(Vector2(p.x,p.z));tool.add_vertex(p)

func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
 triangle(tool,a,b,c,normal);triangle(tool,c,b,d,normal)

func build(world: PlayWorld) -> void:
 w=world;name="CrawlTubes"
 var colors: Array[Color]=[Color("377e83"),Color("b6963e"),Color("9a4a44"),Color("36587b")]
 var materials: Array[StandardMaterial3D]=[];var tools: Array[SurfaceTool]=[]
 for color in colors:
  var mat:=w.mat(color,load("res://assets/vinyl.png"),.38)
  mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.8;mat.normal_enabled=true;mat.normal_texture=w.atmosphere.micro_normal;mat.normal_scale=.13;materials.append(mat)
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tools.append(tool)
 var glass_tool:=SurfaceTool.new();glass_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var floor_tool:=SurfaceTool.new();floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var distances: Array[float]=[]
 for i in range(101): distances.append(LENGTH*i/100)
 for window in WINDOWS:
  distances.append(window.s-.65);distances.append(window.s+.65)
 distances.sort()
 for i in range(distances.size()-1):
  var s:=distances[i];var next:=distances[i+1];var mid: float=(s+next)*.5
  var tool:=tools[int(mid/1.2)%4]
  for j in range(48):
   var a: float=j*TAU/48;var b: float=(j+1)*TAU/48;var window_open:=false
   for window in WINDOWS:
    if absf(mid-window.s)<.65 and absf(wrapf((a+b)*.5-window.angle,-PI,PI))<PI/6: window_open=true
   for radius in [INNER,RADIUS]:
    var normal: Vector3=(surface(mid,(a+b)*.5,1)-route(mid))*(-1 if radius==INNER else 1)
    var target:=glass_tool if window_open else tool
    if window_open and radius==INNER: continue
    quad(target,surface(s,a,radius),surface(next,a,radius),surface(s,b,radius),surface(next,b,radius),normal)
  # Flat continuous walkway shares the same sampled curve and leaves no lips.
  var left:=route(s)-Vector3.UP.cross(tangent(s))*.36;left.y=.31
  var right:=route(s)+Vector3.UP.cross(tangent(s))*.36;right.y=.31
  var next_left:=route(next)-Vector3.UP.cross(tangent(next))*.36;next_left.y=.31
  var next_right:=route(next)+Vector3.UP.cross(tangent(next))*.36;next_right.y=.31
  quad(floor_tool,left,right,next_left,next_right,Vector3.UP)
 for i in range(4):
  tools[i].generate_normals()
  var mesh:=MeshInstance3D.new();mesh.name="TubeShell"+str(i);mesh.mesh=tools[i].commit();mesh.material_override=materials[i];add_child(mesh);mesh.create_trimesh_collision()
 var walkway:=MeshInstance3D.new();walkway.name="ContinuousWalkway";walkway.mesh=floor_tool.commit();walkway.material_override=w.materials.dark;add_child(walkway);walkway.create_trimesh_collision()
 glass_tool.generate_normals()
 var glazing:=w.mat(Color(.38,.65,.65,.1),null,.52);glazing.metallic_specular=.12;glazing.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glazing.cull_mode=BaseMaterial3D.CULL_DISABLED
 var glass:=MeshInstance3D.new();glass.name="PolycarbonateWindows";glass.mesh=glass_tool.commit();glass.material_override=glazing;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(glass);glass.create_trimesh_collision()
 for collider in glass.find_children("*","CollisionShape3D",true,false):
  (collider.shape as ConcavePolygonShape3D).backface_collision=true
 var seams: Array[Transform3D]=[];var bolts: Array[Transform3D]=[]
 for s in [0.0,1.2,2.4,4.8,6,8.4,9.6,10.8,13.2,14.4,LENGTH]:
  for j in range(32):
   PlayGeometry.strand(seams,surface(s,j*TAU/32,RADIUS+.025),surface(s,(j+1)*TAU/32,RADIUS+.025))
   if j%4==0: bolts.append(Transform3D(Basis.IDENTITY,surface(s,j*TAU/32,RADIUS+.055)))
 var link:=CylinderMesh.new();link.height=1;link.top_radius=.026;link.bottom_radius=.026;link.radial_segments=8
 instances(seams,link,w.materials.gold)
 var bolt:=SphereMesh.new();bolt.radius=.022;bolt.height=.044;bolt.radial_segments=8;bolt.rings=4;instances(bolts,bolt,w.materials.metal)
 for window in WINDOWS:
  for sign_value in [-1,1]:
   for j in range(12):
    var a: float=window.angle-PI/6+j*PI/36;var b: float=a+PI/36
    w.tube(self,surface(window.s+sign_value*.65,a,RADIUS+.016),surface(window.s+sign_value*.65,b,RADIUS+.016),.035,w.materials.cream)
   for i in range(8):
    var s: float=window.s-.65+i*1.3/8
    w.tube(self,surface(s,window.angle+sign_value*PI/6,RADIUS+.016),surface(s+1.3/8,window.angle+sign_value*PI/6,RADIUS+.016),.035,w.materials.cream)
  for side in [-1,1]:
   for edge in [-1,1]: w.sphere(self,surface(window.s+side*.6,window.angle+edge*.48,RADIUS+.055),.025,w.materials.metal)
 # Open mouths and broad, low approach ramps; no invisible entrance caps.
 for s in [0.0,LENGTH]:
  var direction:=tangent(s)*(1 if s==0 else -1);var node:=Node3D.new();node.position=route(s)-direction*.45;node.position.y=.15;node.rotation.y=atan2(direction.x,direction.z);add_child(node)
  var ramp:=Node3D.new();ramp.rotation.x=-atan2(.3,.9);node.add_child(ramp);w.box(ramp,Vector3.ZERO,Vector3(.8,.06,.95),w.materials.blue,true)
  for side in [-1,1]: w.box(self,route(s)+Vector3(side*.83,-.71,0),Vector3(.15,.55,.42),w.materials.dark,true)
 # Dim inspection lamps reveal the curves without filling the tunnel with fog.
 for s in [1.0,5.6,9.6,14.4]:
  var light:=OmniLight3D.new();light.position=route(s)+Vector3(0,.52,0);light.light_color=Color("d6af6a");light.light_energy=.2;light.omni_range=2.7;light.light_volumetric_fog_energy=0;add_child(light)
 _watcher();watcher.hide()

func instances(transforms: Array[Transform3D], mesh: Mesh, material: Material) -> void:
 var instance:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
 for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
 instance.multimesh=mm;instance.material_override=material;add_child(instance)

func _watcher() -> void:
 watcher=Node3D.new();watcher.name="WindowWatcher";watcher.position=route(7.4)+Vector3(0,1.2,0);watcher.rotation.x=PI/2;add_child(watcher)
 var coat:=w.mat(Color("151b1b"),load("res://assets/floor.png"),.98)
 var skin:=w.mat(Color("969584"),load("res://assets/aged-plaster.png"),.9);skin.normal_enabled=true;skin.normal_texture=w.atmosphere.micro_normal;skin.normal_scale=.1
 var dark:=w.mat(Color("171515"),null,.92)
 var torso:=w.sphere(watcher,Vector3(0,-.72,-.04),.5,coat);torso.scale=Vector3(.86,1.6,.55)
 face=Node3D.new();face.position=Vector3(0,.1,0);watcher.add_child(face)
 var head:=w.sphere(face,Vector3(0,0,-.025),.3,coat);head.scale=Vector3(.74,1.18,.65)
 var portrait:=SurfaceTool.new();portrait.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(40):
  for col in range(32):
   var corners: Array[Vector2i]=[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
   for corner in corners:
    var u: float=(col+corner.x)/32.0;var v: float=(row+corner.y)/40.0
    var x: float=(u-.5)*.55;var y: float=(.5-v)*.8
    var z: float=.02+.205*sqrt(maxf(.015,1-pow(x/.24,2)-pow(y/.39,2)))+.045*exp(-pow(x/.045,2)-pow((y+.09)/.08,2))
    portrait.set_uv(Vector2(u,v));portrait.add_vertex(Vector3(x,y,z))
 portrait.generate_normals()
 var mask:=MeshInstance3D.new();mask.mesh=portrait.commit()
 mask.material_override=HorrorFigures.complexion(load("res://assets/ambience/window-watcher-face.png"),true);face.add_child(mask)
 coat.albedo_color=Color("211418")
 skin.albedo_color=Color("6b3030")
 for side in [-1,1]:
  w.tube(watcher,Vector3(side*.34,-.4,0),Vector3(side*.58,-.08,.23),.075,coat)
  w.tube(watcher,Vector3(side*.58,-.08,.23),Vector3(side*.52,.22,.32),.058,coat)
  var palm:=w.sphere(watcher,Vector3(side*.52,.22,.34),.1,skin);palm.scale=Vector3(.75,1.4,.35)
  for finger in range(4): w.tube(watcher,Vector3(side*(.47+finger*.035),.25,.35),Vector3(side*(.47+finger*.037),.45+sin(finger)*.035,.36),.016,skin)

func set_anomaly(id: String) -> void:
 watcher_enabled=id=="tube_watcher";watcher.hide()

func tick(delta: float, active: bool, player: NightGuard) -> void:
 inside=contains(player.position)
 watcher.visible=watcher_enabled and inside
 if active and watcher.visible:
  var offset:=player.position-route(7.4)
  face.rotation.y=lerpf(face.rotation.y,clampf(offset.x*.15,-.18,.18),delta*2)
