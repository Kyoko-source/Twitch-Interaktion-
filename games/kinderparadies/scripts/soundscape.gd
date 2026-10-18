class_name NightSoundscape
extends Node3D

const ASSETS:="res://assets/ambience/"
var w: PlayWorld
var events: Array[AudioStreamPlayer3D]=[]
var beds: Array[AudioStreamPlayer3D]=[]
var voice: AudioStreamPlayer3D
var rng:=RandomNumberGenerator.new()
var clock:=0.0
var event_timer:=8.0
var voice_timer:=1.6
var voice_index:=0
var voice_count:=0
var last_voice:=""
var in_tube:=false
const NEW_ASSETS:="res://assets/ambience-v180/"
const MORE_ASSETS:="res://assets/ambience-v193/"
var ghost: AudioStreamPlayer3D
var ghost_timer:=7.0
var ghost_clock:=0.0
var ghost_duration:=0.0
var ghost_count:=0
var ghost_from:=Vector3.ZERO
var ghost_to:=Vector3.ZERO
var ghost_track:=""

func emitter(file: String, pos: Vector3, db: float, range_value: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;source.stream=load(file if file.begins_with("res://") else ASSETS+file);source.position=pos;source.volume_db=db;source.unit_size=2;source.max_distance=range_value;source.attenuation_filter_cutoff_hz=3300;add_child(source);return source

func build(world: PlayWorld) -> void:
 w=world;rng.randomize()
 # No global broadband rain bed. Water is a quiet source by the far wall.
 beds.append(emitter("rain-muted.ogg",Vector3(-9,5,-10),-18,10))
 beds.append(emitter("ventilation.ogg",Vector3(16,5,-5),-15,12))
 beds.append(emitter("ventilation.ogg",Vector3(-8,5,2),-19,9))
 for source in beds: (source.stream as AudioStreamOggVorbis).loop=true
 for spec in [{"file":"fridge.wav","pos":Vector3(-11,1,-21.7),"db":-7.0,"range":7.0},{"file":"fly.wav","pos":Vector3(-13.25,1.5,-19.25),"db":-5.0,"range":3.6}]:
  var source:=emitter(NEW_ASSETS+spec.file,spec.pos,spec.db,spec.range);var stream: AudioStreamWAV=source.stream;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);beds.append(source)
 events.append(emitter("door-creak.ogg",Vector3(6.8,1.8,-8.7),-8,13))
 events.append(emitter("pipe-knock.wav",Vector3(-7,5,-4),-16,12))
 events.append(emitter("relay-tick.wav",Vector3(1,5.8,0),-21,10))
 events.append(emitter(NEW_ASSETS+"cutlery.wav",Vector3(-16.6,1.2,-18.4),-4,8))
 events.append(emitter(NEW_ASSETS+"chain.wav",Vector3(13.4,4.8,6.5),-6,14))
 events.append(emitter(NEW_ASSETS+"floor-creak.wav",Vector3(-3,1.0,-19.2),-4,9))
 events.append(emitter(NEW_ASSETS+"breathing.wav",Vector3(-7.9,1.8,-21.5),-6,8))
 for spec in [{"file":"metal-door.wav","pos":Vector3(-7.9,1.6,-14),"db":-3.0},{"file":"dish-rattle.wav","pos":Vector3(-15.6,1.2,-18.4),"db":-2.0},{"file":"duct-stress.wav","pos":Vector3(-1.3,3.3,-20.2),"db":-1.0},{"file":"motor-stop.wav","pos":Vector3(17.2,3,8.4),"db":-1.0}]:
  events.append(emitter(MORE_ASSETS+spec.file,spec.pos,spec.db,14))
 var leak:=emitter(MORE_ASSETS+"leak.wav",Vector3(-8,2.7,-9),-5,9);var dripping: AudioStreamWAV=leak.stream;dripping.loop_mode=AudioStreamWAV.LOOP_FORWARD;dripping.loop_end=int(dripping.get_length()*dripping.mix_rate);beds.append(leak)
 ghost=emitter(MORE_ASSETS+"ghost-walk.wav",Vector3(-5.4,.15,7),-2,16);ghost.unit_size=3;ghost.attenuation_filter_cutoff_hz=3000
 voice=emitter("children-laugh.ogg",CrawlTubes.route(7.4),-1,5)
 voice.attenuation_filter_cutoff_hz=2700
 if not OS.has_feature("web"):
  if AudioServer.get_bus_index("CrawlSpace")<0:
   AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"CrawlSpace");AudioServer.set_bus_send(bus,"Interior")
   var reverb:=AudioEffectReverb.new();reverb.room_size=.4;reverb.damping=.7;reverb.wet=.24;reverb.dry=.9;AudioServer.add_bus_effect(bus,reverb)
  voice.bus="CrawlSpace"
  for source in events+beds+[ghost]: source.bus="Interior"

func cue_steps(player: NightGuard) -> void:
 # Sound-only paths stay in real aisles. They do not instantiate a person and
 # never consume the anomaly generator's randomness or change the correct door.
 var paths: Array[Vector3]=[Vector3(-5.5,.15,3),Vector3(-5.5,.15,10),Vector3(5.8,.15,-10),Vector3(5.8,.15,-5.8),Vector3(-7.9,.15,-14),Vector3(-7.9,.15,-21.5),Vector3(13,.15,-10.4),Vector3(17,.15,-10.4)]
 var nearest:=0;var distance:=1000.0
 for i in range(0,paths.size(),2):
  var d:=((paths[i]+paths[i+1])*.5).distance_to(player.position)
  if d<distance: distance=d;nearest=i
 ghost_from=paths[nearest];ghost_to=paths[nearest+1]
 if rng.randf()<.5: var swap:=ghost_from;ghost_from=ghost_to;ghost_to=swap
 ghost_track="ghost-run.wav" if ghost_count%2 else "ghost-walk.wav";ghost.stream=load(MORE_ASSETS+ghost_track);ghost.pitch_scale=rng.randf_range(.95,1.04)
 ghost_clock=0;ghost_duration=ghost.stream.get_length()/ghost.pitch_scale;ghost.position=ghost_from;ghost.play();ghost_count+=1
 ghost_timer=ghost_duration+rng.randf_range(16,30)

func cue_voice(player: NightGuard) -> void:
 if voice.playing and not voice.stream_paused: return
 last_voice="children-laugh.ogg" if voice_index%2==0 else "children-cry.ogg"
 voice.stream=load(ASSETS+last_voice);voice.pitch_scale=rng.randf_range(.96,1.02)
 var current:=CrawlTubes.nearest(player.position)
 var offset:=2.2 if voice_index%2==0 else -2.6
 voice.position=CrawlTubes.route(clampf(current.s+offset,.8,CrawlTubes.LENGTH-.8))+Vector3(0,.15,0)
 voice.volume_db=-1;voice.play();voice_index+=1;voice_count+=1
 voice_timer=voice.stream.get_length()+rng.randf_range(4,7)

func tick(delta: float, active: bool, player: NightGuard) -> void:
 for source in events+beds+[voice,ghost]:
  if source.stream_paused==active: source.stream_paused=not active
 if not active: return
 for source in beds:
  if not source.playing: source.play(rng.randf_range(0,source.stream.get_length()*.5))
 clock+=delta;event_timer-=delta
 ghost_timer-=delta
 if ghost_timer<=0 and not ghost.playing: cue_steps(player)
 if ghost.playing:
  ghost_clock+=delta;ghost.position=ghost_from.lerp(ghost_to,clampf(ghost_clock/maxf(.1,ghost_duration),0,1))
 if event_timer<=0:
  # Different positions and long irregular gaps, independent of anomaly RNG.
  var near:=events.filter(func(source): return source.position.distance_to(player.position)<source.max_distance)
  if not near.is_empty():
   var source: AudioStreamPlayer3D=near[rng.randi_range(0,near.size()-1)];source.pitch_scale=rng.randf_range(.94,1.04);source.play()
  event_timer=rng.randf_range(5,11)
 var entered:=w.tubes.contains(player.position)
 if entered and not in_tube: voice_timer=minf(voice_timer,1.6)
 in_tube=entered
 if in_tube:
  voice_timer-=delta
  voice.volume_db=lerpf(voice.volume_db,-1,delta*3)
  if voice_timer<=0: cue_voice(player)
 else:
  # Closed plastic walls muffle voices when the listener leaves the tube.
  voice.volume_db=lerpf(voice.volume_db,-25,delta*2)

func stop_all() -> void:
 for source in events+beds+[voice,ghost]: source.stop()

func snapshot() -> Dictionary:
 return {"clock":clock,"in_tube":in_tube,"voice_count":voice_count,"last_voice":last_voice,"voice_playing":voice.playing,"voice_paused":voice.stream_paused,"voice_timer":voice_timer,"bed_count":beds.size(),"event_count":events.size(),"ghost_count":ghost_count,"ghost_playing":ghost.playing,"ghost_paused":ghost.stream_paused,"ghost_track":ghost_track,"ghost_clock":ghost_clock,"ghost_position":[ghost.position.x,ghost.position.y,ghost.position.z]}
