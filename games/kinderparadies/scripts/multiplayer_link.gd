class_name MultiplayerLink
extends Node

# Spectator multiplayer, player 1's side. The game opens a session on the
# website, shows its six-digit code and waits for player 2's thirteen-round
# plan. During the shift it reports the round, room and events and streams a
# security-camera picture that follows player 1 through the venue.
signal changed
signal plan_ready(plan: Array)

const DEFAULT_SERVER:="https://62.238.49.219/api/afterplay/mp/sessions"
var SERVER:=OS.get_environment("AFTERPLAY_MP_SERVER") if OS.has_environment("AFTERPLAY_MP_SERVER") else DEFAULT_SERVER
const STATE_EVERY:=1.0
const FRAME_EVERY:=.7
const POLL_EVERY:=1.5
var g: Node3D
var status:="idle" # idle, connecting, waiting, joined, playing, error
var message:=""
var code:=""
var token:=""
var plan: Array=[]
var events: Array[String]=[]
var camera_label:=""
var poll_http: HTTPRequest
var state_http: HTTPRequest
var frame_http: HTTPRequest
var poll_clock:=0.
var state_clock:=0.
var frame_clock:=0.
var capturing:=false
var view: SubViewport
var lens: Camera3D
var figure: Node3D
const SPECTATOR_LAYER:=512

func build(game: Node3D) -> void:
 g=game;name="MultiplayerLink";process_mode=Node.PROCESS_MODE_ALWAYS
 for key in ["poll","state","frame"]:
  var http:=HTTPRequest.new();http.name=key.capitalize()+"Request";http.timeout=20;add_child(http)
  set(key+"_http",http)
 poll_http.request_completed.connect(_polled);state_http.request_completed.connect(func(_a,_b,_c,_d):pass);frame_http.request_completed.connect(func(_a,_b,_c,_d):pass)
 view=SubViewport.new();view.name="SpectatorCamera";view.size=Vector2i(640,360);view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(view)
 lens=Camera3D.new();lens.fov=74;lens.near=.1;lens.far=60;lens.cull_mask=1|SPECTATOR_LAYER;view.add_child(lens);lens.current=true

func active() -> bool:
 return status in ["waiting","joined","playing"]

func start() -> void:
 stop()
 status="connecting";message="Verbinde mit der Webseite …";changed.emit()
 var http:=HTTPRequest.new();http.timeout=30;add_child(http)
 http.request_completed.connect(func(result: int,response: int,_h,body: PackedByteArray):
  http.queue_free()
  var data=JSON.parse_string(body.get_string_from_utf8()) if result==HTTPRequest.RESULT_SUCCESS else null
  if response!=200 or not data is Dictionary or not data.has("code"):
   push_warning("Multiplayer session failed: result %d http %d %s"%[result,response,body.get_string_from_utf8().left(300)])
   status="error";message="Keine Verbindung zur Webseite. Prüfe deine Internetverbindung.";changed.emit();return
  code=str(data.code);token=str(data.host_token);status="waiting";message="Warte auf Spieler 2 …";poll_clock=0.;changed.emit())
 var labels: Array=[]
 for feed in ReceptionWatch.FEEDS:labels.append(str(feed.label))
 var body:={"version":ProjectSettings.get_setting("application/config/version","4.3"),"catalog":PatrolState.catalog(),"cameras":labels}
 http.request(SERVER,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(body))

func stop() -> void:
 if is_instance_valid(figure):figure.queue_free()
 status="idle";message="";code="";token="";plan=[];events.clear();changed.emit()

func event(text: String) -> void:
 if status!="playing":return
 events.append(text)
 if events.size()>10:events.pop_front()

func tick(delta: float) -> void:
 if status in ["waiting","joined"]:
  poll_clock-=delta
  if poll_clock<=0. and poll_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
   poll_clock=POLL_EVERY
   poll_http.request(SERVER+"/"+code+"/host",_headers(),HTTPClient.METHOD_GET)
 if status!="playing":return
 state_clock-=delta;frame_clock-=delta
 if state_clock<=0. and state_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
  state_clock=STATE_EVERY;_send_state()
 if frame_clock<=0. and not capturing and frame_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
  frame_clock=FRAME_EVERY;_send_frame()

func _headers(json:=false) -> PackedStringArray:
 var rows:=PackedStringArray(["X-Host-Token: "+token])
 if json:rows.append("Content-Type: application/json")
 return rows

func _polled(result: int,response: int,_h,body: PackedByteArray) -> void:
 if result!=HTTPRequest.RESULT_SUCCESS:return
 if response==404 or response==403:status="error";message="Die Sitzung ist abgelaufen. Starte den Multiplayer neu.";changed.emit();return
 var data=JSON.parse_string(body.get_string_from_utf8())
 if not data is Dictionary:return
 if status=="waiting" and data.get("joined",false):status="joined";message="Spieler 2 ist da und plant die 13 Runden …";changed.emit()
 var received=data.get("plan")
 if received is Array and received.size()==PatrolState.GOAL and status in ["waiting","joined"]:
  plan=received;status="playing";message="Plan erhalten. Die Schicht beginnt.";changed.emit();plan_ready.emit(plan)

func zone() -> String:
 if not is_instance_valid(g.world) or not g.player:return ""
 var best:="";var distance:=INF
 for name in g.world.zones:
  var p: Vector3=g.world.zones[name];var d:=Vector2(g.player.position.x-p.x,g.player.position.z-p.z).length()
  if d<distance:distance=d;best=name
 return best

func _send_state() -> void:
 var payload:={"phase":str(g.phase),"round":clampi(g.state.streak+1,1,13),"streak":g.state.streak,"zone":zone(),"camera":camera_label,"current":str(g.state.current),"events":events.duplicate()}
 events.clear()
 state_http.request(SERVER+"/"+code+"/state",_headers(true),HTTPClient.METHOD_POST,JSON.stringify(payload))

# The security camera with a clear line of sight that is closest to player 1
# pans to follow them; out of every camera's sight, a high corner view above
# and behind the guard takes over, like a portable ceiling camera.
# Player 1 has no body in first person. A uniformed guard with a lit torch,
# drawn only for the spectator camera, shows player 2 where they are.
func _figure() -> void:
 if is_instance_valid(figure) and figure.get_parent()==g.player:return
 figure=Node3D.new();figure.name="SpectatorGuard";g.player.add_child(figure)
 var uniform:=StandardMaterial3D.new();uniform.albedo_color=Color("34465c");uniform.roughness=.8
 var skin:=StandardMaterial3D.new();skin.albedo_color=Color("b08c74")
 var parts: Array=[[CapsuleMesh.new(),Vector3(0,1.15,0),Vector3(.42,.62,.3),uniform],[SphereMesh.new(),Vector3(0,1.66,0),Vector3(.21,.24,.22),skin],
  [CylinderMesh.new(),Vector3(0,1.78,0),Vector3(.24,.07,.24),uniform],[CapsuleMesh.new(),Vector3(-.1,.43,0),Vector3(.16,.86,.16),uniform],[CapsuleMesh.new(),Vector3(.1,.43,0),Vector3(.16,.86,.16),uniform],
  [CapsuleMesh.new(),Vector3(.25,1.2,-.22),Vector3(.11,.55,.11),uniform]]
 for row in parts:
  var mesh:=MeshInstance3D.new();mesh.mesh=row[0];mesh.position=row[1];mesh.scale=row[2]
  if row[0] is CapsuleMesh:(row[0] as CapsuleMesh).radius=.5;(row[0] as CapsuleMesh).height=1.
  elif row[0] is SphereMesh:(row[0] as SphereMesh).radius=.5;(row[0] as SphereMesh).height=1.
  else:(row[0] as CylinderMesh).top_radius=.5;(row[0] as CylinderMesh).bottom_radius=.55;(row[0] as CylinderMesh).height=1.
  mesh.material_override=row[3];mesh.layers=SPECTATOR_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;figure.add_child(mesh)
 figure.get_child(5).rotation.x=-1.2
 var glow:=StandardMaterial3D.new();glow.emission_enabled=true;glow.emission=Color("fff1c8");glow.emission_energy_multiplier=4.;glow.albedo_color=Color.WHITE
 var bulb:=MeshInstance3D.new();var b:=SphereMesh.new();b.radius=.05;b.height=.1;bulb.mesh=b;bulb.material_override=glow;bulb.position=Vector3(.25,1.38,-.5);bulb.layers=SPECTATOR_LAYER;figure.add_child(bulb)
 g.player.camera.cull_mask&=~SPECTATOR_LAYER

func _aim() -> void:
 var target: Vector3=g.player.global_position+Vector3(0,1.0,0)
 var space: PhysicsDirectSpaceState3D=g.world.get_world_3d().direct_space_state
 var best:=-1;var distance:=INF
 for i in range(ReceptionWatch.FEEDS.size()):
  var feed: Dictionary=ReceptionWatch.FEEDS[i];var p: Vector3=feed.p
  var d:=p.distance_to(target)
  if d>7.5 or d>=distance:continue
  var ray:=PhysicsRayQueryParameters3D.create(p,target,1,[g.player.get_rid()])
  if space.intersect_ray(ray).is_empty():best=i;distance=d
 if best>=0:
  lens.global_position=ReceptionWatch.FEEDS[best].p;camera_label=str(ReceptionWatch.FEEDS[best].label)
 else:
  var back: Vector3=g.player.global_basis.z;back.y=0;back=back.normalized() if back.length()>.1 else Vector3.BACK
  # Pull the follow camera in front of any wall behind the guard.
  var want:=target+back*2.1+Vector3(0,1.15,0)
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(target,want,1,[g.player.get_rid()]))
  lens.global_position=(hit.position+(target-hit.position).normalized()*.25) if not hit.is_empty() else want
  camera_label="08 / MOBIL"
 if lens.global_position.distance_to(target)>.05:lens.look_at(target,Vector3.UP)

func _send_frame() -> void:
 if not is_instance_valid(g.world) or g.world_loading or g.phase in ["loading","menu"]:return
 capturing=true
 view.world_3d=g.world.get_world_3d()
 _figure();_aim()
 view.render_target_update_mode=SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 capturing=false
 if status!="playing":return
 var image:=view.get_texture().get_image()
 if not image or image.is_empty():return
 image.resize(512,288,Image.INTERPOLATE_BILINEAR)
 frame_http.request_raw(SERVER+"/"+code+"/frame",PackedStringArray(["X-Host-Token: "+token,"Content-Type: image/jpeg"]),HTTPClient.METHOD_PUT,image.save_jpg_to_buffer(.62))
