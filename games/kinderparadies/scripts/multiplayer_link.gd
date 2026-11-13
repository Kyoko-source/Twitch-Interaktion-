class_name MultiplayerLink
extends Node

# Spectator multiplayer, player 1's side. The game opens a session on the
# website, shows its six-digit code and waits for player 2's thirteen-round
# plan. During the shift it reports the round, room, events and player 1's
# position; once per session it uploads a floor-plan outline of the venue's
# walls, so player 2 sees a map with a glowing dot instead of a video feed.
signal changed
signal plan_ready(plan: Array)

const DEFAULT_SERVER:="https://62.238.49.219/api/afterplay/mp/sessions"
var SERVER:=OS.get_environment("AFTERPLAY_MP_SERVER") if OS.has_environment("AFTERPLAY_MP_SERVER") else DEFAULT_SERVER
const STATE_EVERY:=.35
const POLL_EVERY:=1.5
var g: Node3D
var status:="idle" # idle, connecting, waiting, joined, playing, error
var message:=""
var code:=""
var token:=""
var plan: Array=[]
var events: Array[String]=[]
var poll_http: HTTPRequest
var state_http: HTTPRequest
var map_http: HTTPRequest
var poll_clock:=0.
var state_clock:=0.
var map_sent:=false
var map_world: Node

func build(game: Node3D) -> void:
 g=game;name="MultiplayerLink";process_mode=Node.PROCESS_MODE_ALWAYS
 for key in ["poll","state","map"]:
  var http:=HTTPRequest.new();http.name=key.capitalize()+"Request";http.timeout=20;add_child(http)
  set(key+"_http",http)
 poll_http.request_completed.connect(_polled);state_http.request_completed.connect(func(_a,_b,_c,_d):pass);map_http.request_completed.connect(_map_done)

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
 var body:={"version":ProjectSettings.get_setting("application/config/version","4.3"),"catalog":PatrolState.catalog()}
 http.request(SERVER,PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(body))

func stop() -> void:
 map_sent=false;map_world=null
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
 state_clock-=delta
 if state_clock<=0. and state_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
  state_clock=STATE_EVERY;_send_state()
 if not map_sent and map_http.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:_send_map()

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
 var payload:={"phase":str(g.phase),"round":clampi(g.state.streak+1,1,13),"streak":g.state.streak,"zone":zone(),"current":str(g.state.current),"events":events.duplicate()}
 if is_instance_valid(g.world) and not g.world_loading and g.player and g.phase not in ["loading","menu"]:
  var p: Vector3=g.player.global_position;var ahead: Vector3=-g.player.global_basis.z
  payload.x=snappedf(p.x,.01);payload.z=snappedf(p.z,.01);payload.yaw=snappedf(atan2(ahead.x,ahead.z),.01)
 events.clear()
 state_http.request(SERVER+"/"+code+"/state",_headers(true),HTTPClient.METHOD_POST,JSON.stringify(payload))

func _send_map() -> void:
 if not is_instance_valid(g.world) or g.world_loading or g.phase in ["loading","menu"]:return
 var data:=outline(g.world)
 if data.walls.is_empty():return
 map_world=g.world
 map_http.request(SERVER+"/"+code+"/map",_headers(true),HTTPClient.METHOD_PUT,JSON.stringify(data))

func _map_done(result: int,response: int,_h,_b) -> void:
 map_sent=result==HTTPRequest.RESULT_SUCCESS and response==200
 if not map_sent:push_warning("Multiplayer map upload failed: result %d http %d"%[result,response])

# Floor plan for player 2: the footprint of every architectural wall as a
# quad in the XZ plane (x, z pairs), plus the room labels. Only walls that
# stand on the ground floor count, so ceilings and the climbing frame's upper
# deck do not clutter the outline.
static func outline(world: Node3D) -> Dictionary:
 var walls: Array=[];var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
 var stack: Array[Node]=[world]
 while not stack.is_empty():
  var node: Node=stack.pop_back()
  for child in node.get_children():stack.append(child)
  if not node is MeshInstance3D or not node.get_meta("architecture_wall",false) or not (node as MeshInstance3D).is_visible_in_tree():continue
  var mesh: MeshInstance3D=node;var box: AABB=mesh.get_aabb();var t: Transform3D=mesh.global_transform
  var bottom:=(t*box.position).y;var top:=(t*box.end).y
  if minf(bottom,top)>1.2 or maxf(bottom,top)<.4:continue
  var quad: Array=[]
  for corner in [Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1),Vector3(0,0,1)]:
   var p: Vector3=t*(box.position+box.size*corner)
   quad.append(snappedf(p.x,.01));quad.append(snappedf(p.z,.01))
   lo=lo.min(Vector2(p.x,p.z));hi=hi.max(Vector2(p.x,p.z))
  walls.append(quad)
 var rooms: Array=[]
 for name in world.zones:
  var z: Vector3=world.zones[name];rooms.append({"name":str(name),"x":snappedf(z.x,.01),"z":snappedf(z.z,.01)})
 return {"walls":walls,"rooms":rooms,"bounds":[snappedf(lo.x,.01),snappedf(lo.y,.01),snappedf(hi.x,.01),snappedf(hi.y,.01)] if walls.size() else []}
