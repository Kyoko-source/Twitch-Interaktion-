class_name HappylandAcoustics
extends Node3D

const ROOT:="res://assets/atmosphere-v320/"
const PORTALS:=[
 ["hall","party",Vector3(6.8,1.45,-8.7)],
 ["hall","corridor",Vector3(-7.9,1.45,-12.2)],
 ["corridor","kitchen",Vector3(-9.4,1.45,-29.65)],
 ["corridor","cinema",Vector3(-6.4,1.45,-29.65)],
 ["hall","service",Vector3(-10.2,1.45,-5.4)],
 ["hall","washroom",Vector3(19.8,1.45,7.8)],
 ["party","backstage",Vector3(17.3,1.55,-12.2)],
 ["hall","archive",Vector3(-10.2,1.45,-9.9)],
 ["hall","entrance",Vector3(-10.2,1.45,9.4)],
 ["entrance","outside",Vector3(-15.8,1.45,9.4)]
]
const ROOMS:={
 "hall":Vector3(.78,.14,.70),"party":Vector3(.62,.12,.76),
 "kitchen":Vector3(.46,.18,.48),"cinema":Vector3(.66,.055,.93),
 "corridor":Vector3(.57,.19,.61),"service":Vector3(.40,.11,.66),
 "washroom":Vector3(.49,.23,.46),"backstage":Vector3(.43,.08,.87),
 "archive":Vector3(.39,.10,.80),"tube":Vector3(.19,.17,.32),
 "outside":Vector3(.20,.015,.90),"entrance":Vector3(.36,.13,.65)
}
var w: PlayWorld
var records: Array[Dictionary]=[]
var added_loops: Array[AudioStreamPlayer3D]=[]
var room_reverb: AudioEffectReverb
var step_reverb: AudioEffectReverb
var step_filter: AudioEffectLowPassFilter
var tube_delay: AudioEffectDelay
var room:="hall"
var clock:=0.0
var refresh:=0.0
var casts:=0
var running:=false
var loop_offsets: Dictionary={}

func bus(id: String,send: String) -> int:
 var index:=AudioServer.get_bus_index(id)
 if index<0:
  AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,id)
 AudioServer.set_bus_send(index,send)
 return index

func replace_effects(index: int,effects: Array) -> void:
 while AudioServer.get_bus_effect_count(index)>0:AudioServer.remove_bus_effect(index,0)
 for effect in effects:AudioServer.add_bus_effect(index,effect)

func loop_on(source: AudioStreamPlayer3D,file: String,db: float,reach: float=10.) -> void:
 source.stop();var stream: AudioStreamOggVorbis=load(ROOT+file+".ogg").duplicate();stream.loop=true;source.stream=stream;source.set_meta("machinery_file",ROOT+file+".ogg")
 source.volume_db=db;source.unit_size=1.8;source.max_distance=reach;source.attenuation_filter_cutoff_hz=18000;source.attenuation_filter_db=0

func machine(id: String,file: String,point: Vector3,db: float,reach: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.name=id;source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 source.position=point;add_child(source);loop_on(source,file,db,reach);added_loops.append(source);return source

func build(world: PlayWorld) -> void:
 w=world;name="HappylandRoomAcoustics"
 bus("NightAmbience","Master")
 room_reverb=AudioEffectReverb.new();room_reverb.dry=1.;room_reverb.predelay_msec=24;room_reverb.predelay_feedback=.12
 replace_effects(bus("AP.Room","NightAmbience"),[room_reverb])
 step_reverb=AudioEffectReverb.new();step_reverb.dry=1.;step_reverb.predelay_msec=18;step_reverb.predelay_feedback=.08
 step_filter=AudioEffectLowPassFilter.new();step_filter.cutoff_hz=18000
 tube_delay=AudioEffectDelay.new();tube_delay.tap1_delay_ms=57;tube_delay.tap1_level_db=-20;tube_delay.tap2_active=false;tube_delay.feedback_active=false
 replace_effects(bus("AP.GuardSteps","Master"),[step_filter,step_reverb,tube_delay])
 # Each cabinet has its own motor/CRT bed, located in its real housing.
 loop_on(w.details.hum,"arcade-1",-17,9);w.details.hum.position=Vector3(6,1.1,16.35)
 machine("OrbitCabinetElectronics","arcade-2",Vector3(7.5,1.1,16.35),-19,8)
 machine("PrizeCabinetMotor","arcade-3",Vector3(9.5,.75,16.35),-21,7)
 machine("ServiceTransformer","electrical-cabinet",Vector3(-15.85,1.4,-6.6),-24,7)
 machine("PlasticTubeAir","tube-resonance",CrawlTubes.route(7.4),-29,4.5)
 for source in w.soundscape.beds:
  if source.stream.resource_path.ends_with("fridge.wav"):loop_on(source,"fridge-compressor",-19,10)
  elif source.stream is AudioStreamOggVorbis and source!=w.soundscape.beds[0]:loop_on(source,"vent-air",-26 if source.position.x>0 else -29,11)
 # Rain is outside the new closed window, never a broadband layer in the room.
 w.soundscape.beds[0].position=Vector3(-10.8,2.4,1.7);w.soundscape.beds[0].volume_db=-18;w.soundscape.beds[0].max_distance=9
 for source in w.annex.sources:
  if source.stream.resource_path.ends_with("projector.wav"):loop_on(source,"projector-mechanism",-17,13)
 var sources: Array[AudioStreamPlayer3D]=[]
 sources.append_array(w.soundscape.beds);sources.append_array(w.soundscape.events);sources.append_array(w.annex.sources)
 sources.append_array([w.soundscape.voice,w.soundscape.ghost,w.details.hum,w.life.photo_hum,w.life.motor,w.life.drip,w.life.room_tone,w.atmosphere.drips,w.playground.fan,w.room_horror.music,w.film.audio])
 sources.append_array(added_loops)
 sources.append_array(w.mechanics.sources)
 sources.append(w.party.audio)
 for source in w.soundscape.events:source.volume_db=minf(source.volume_db,-15.)
 w.soundscape.ghost.volume_db=-9.
 var server:=w.server_room.get_node("ServerVentilation") as AudioStreamPlayer3D
 sources.append(server)
 for source in sources:add_source(source)

func add_source(source: AudioStreamPlayer3D) -> void:
 var id:="AP.Source.%02d"%records.size();var filter:=AudioEffectLowPassFilter.new();filter.cutoff_hz=18000
 replace_effects(bus(id,"AP.Room"),[filter]);source.bus=id
 records.append({"source":source,"bus":id,"filter":filter,"gain":0.,"target_gain":0.,"cutoff":18000.,"target_cutoff":18000.,"blocked":false,"route":false})

func route() -> void:
 # Settings and scene rebuilds must not overwrite source-specific filters.
 bus("NightAmbience","Master")
 for record in records:record.source.bus=record.bus

func area(point: Vector3) -> String:
 if w.tubes.contains(point):return "tube"
 if point.x>19.5 and point.z>5 and point.z<11:return "washroom"
 if point.z< -24.1:
  if point.x< -9.35:return "kitchen"
  if point.x> -6.45:return "cinema"
  return "corridor"
 if point.z< -12.25:
  if point.x>7:return "backstage"
  return "corridor"
 if point.x< -10.15:
  if point.z>8.18 and point.z<10.62 and point.x> -15.85:return "entrance"
  if point.z< -7:return "archive"
  if point.z< -1:return "service"
  return "outside"
 if point.x>6.7 and point.z<1.65:return "party"
 return "hall"

func structural(collider: Node) -> bool:
 var node: Node=collider
 while node!=null and node!=w:
  var title:=str(node.name).to_lower()
  if node.get_meta("architecture_wall",false) or node.get_meta("acoustic_barrier",false) or "doorleaf" in title or title=="decisiondoor":return true
  if node==w.archive.leaf:return true
  node=node.get_parent()
 return false

func blocked(a: Vector3,b: Vector3,exclude: Array[RID]) -> bool:
 if a.distance_squared_to(b)<.01:return false
 var ignored: Array[RID]=exclude.duplicate()
 for unused in range(7):
  var query:=PhysicsRayQueryParameters3D.create(a,b,1);query.exclude=ignored;query.hit_from_inside=false
  var hit:=w.get_world_3d().direct_space_state.intersect_ray(query);casts+=1
  if hit.is_empty():return false
  if structural(hit.collider):return true
  ignored.append(hit.rid)
 return false

func portal_path(origin: String,destination: String) -> Array[Vector3]:
 var queue: Array[Dictionary]=[{"room":origin,"path":[]}];var seen:={origin:true}
 while not queue.is_empty():
  var item: Dictionary=queue.pop_front()
  for edge in PORTALS:
   var next: String=edge[1] if edge[0]==item.room else edge[0] if edge[1]==item.room else ""
   if next=="" or seen.has(next):continue
   var path: Array[Vector3]=[];path.assign(item.path);path.append(edge[2])
   if next==destination:return path
   seen[next]=true;queue.append({"room":next,"path":path})
 return []

func solve(source: AudioStreamPlayer3D,listener: Vector3,exclude: Array[RID]) -> Dictionary:
 var point:=source.global_position;var origin:=area(point);var destination:=area(listener)
 if source.get_meta("room_filling_music",false):
  # The stereo fills its room instead of becoming a quiet point source in a
  # corner. A single playback preserves stereo and keeps every beat in sync.
  if destination=="party":return {"gain":0.,"cutoff":18000.,"blocked":false,"route":false}
  if point.distance_to(listener)>36:return {"gain":-60.,"cutoff":1150.,"blocked":true,"route":false}
  var path:=portal_path("party",destination)
  var doorway: Vector3=path[-1] if not path.is_empty() else point
  var obstruction:=blocked(point,listener,exclude)
  var gain:=(-16. if obstruction else -9.)-20.*log(1.+listener.distance_to(doorway)/3.)/log(10.)
  return {"gain":gain,"cutoff":1400. if obstruction else 4800.,"blocked":obstruction,"route":not path.is_empty()}
 if point.distance_to(listener)>source.max_distance+4:return {"gain":-60.,"cutoff":18000.,"blocked":false,"route":false}
 var obstruction:=blocked(point,listener,exclude)
 if origin=="tube" or destination=="tube":
  if origin!=destination:return {"gain":-10.,"cutoff":1650.,"blocked":true,"route":false}
 if not obstruction:return {"gain":0.,"cutoff":18000.,"blocked":false,"route":false}
 var path:=portal_path(origin,destination)
 if not path.is_empty():
  var previous:=point;var length:=0.;var clear:=true
  for portal in path:
   if blocked(previous,portal,exclude):clear=false;break
   length+=previous.distance_to(portal);previous=portal
  if clear and not blocked(previous,listener,exclude):
   length+=previous.distance_to(listener)
   var excess:=maxf(0.,20*log((length+1)/(point.distance_to(listener)+1))/log(10.))
   return {"gain":-3.-minf(excess,12.),"cutoff":4200.,"blocked":true,"route":true}
 return {"gain":-17. if origin=="outside" else -13.,"cutoff":800. if origin=="outside" else 1150.,"blocked":true,"route":false}

func tune(reverb: AudioEffectReverb,profile: Vector3,weight: float) -> void:
 reverb.room_size=lerpf(reverb.room_size,profile.x,weight)
 reverb.wet=lerpf(reverb.wet,profile.y,weight);reverb.damping=lerpf(reverb.damping,profile.z,weight)

func tick(delta: float,active: bool,guard: NightGuard) -> void:
 running=active
 for source in added_loops:
  if not active:
   if source.playing:loop_offsets[source.get_instance_id()]=source.get_playback_position()
   source.stop() # Also cancels deferred 3D starts before their playback exists.
  else:
   source.stream_paused=false
   if not source.playing:source.play(float(loop_offsets.get(source.get_instance_id(),0.)))
 if not active:return
 clock+=delta;refresh-=delta
 room=area(guard.global_position)
 var profile: Vector3=ROOMS[room]
 tune(room_reverb,profile,minf(1.,delta*3));tune(step_reverb,profile,minf(1.,delta*3))
 # Retain the existing washroom bus and its own bright tiled-room signature.
 guard.step_player.bus="WashroomSteps" if room=="washroom" else "AP.GuardSteps"
 step_filter.cutoff_hz=lerpf(step_filter.cutoff_hz,5400. if room=="tube" else 18000.,minf(1.,delta*5))
 AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("AP.GuardSteps"),2,room=="tube")
 if refresh<=0:
  refresh=.16;casts=0
  var exclude: Array[RID]=[guard.get_rid()]
  if is_instance_valid(guard.carried):exclude.append(guard.carried.get_rid())
  for record in records:
   var result:=solve(record.source,guard.camera.global_position,exclude)
   record.target_gain=result.gain;record.target_cutoff=result.cutoff;record.blocked=result.blocked;record.route=result.route
 for record in records:
  record.gain=lerpf(record.gain,record.target_gain,minf(1.,delta*7))
  record.cutoff=lerpf(record.cutoff,record.target_cutoff,minf(1.,delta*5))
  AudioServer.set_bus_volume_db(AudioServer.get_bus_index(record.bus),record.gain)
  record.filter.cutoff_hz=record.cutoff

func snapshot() -> Dictionary:
 var sources: Array[Dictionary]=[]
 for record in records:
  var source: AudioStreamPlayer3D=record.source
  sources.append({"id":str(source.name),"file":source.get_meta("machinery_file",source.stream.resource_path if source.stream else ""),"gain":record.gain,"cutoff":record.cutoff,"blocked":record.blocked,"portal":record.route,"paused":source.stream_paused,"playing":source.playing,"bus":source.bus})
 return {"room":room,"clock":clock,"running":running,"source_count":records.size(),"sources":sources,"rays":casts,"step_wet":step_reverb.wet,"step_cutoff":step_filter.cutoff_hz}
