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

func emitter(file: String, pos: Vector3, db: float, range_value: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;source.stream=load(ASSETS+file);source.position=pos;source.volume_db=db;source.unit_size=2;source.max_distance=range_value;source.attenuation_filter_cutoff_hz=3300;add_child(source);return source

func build(world: PlayWorld) -> void:
 w=world;rng.randomize()
 # No global broadband rain bed. Water is a quiet source by the far wall.
 beds.append(emitter("rain-muted.ogg",Vector3(-9,5,-10),-18,10))
 beds.append(emitter("ventilation.ogg",Vector3(16,5,-5),-15,12))
 beds.append(emitter("ventilation.ogg",Vector3(-8,5,2),-19,9))
 for source in beds: (source.stream as AudioStreamOggVorbis).loop=true
 events.append(emitter("door-creak.ogg",Vector3(6.8,1.8,-5.6),-8,13))
 events.append(emitter("pipe-knock.wav",Vector3(-7,5,-4),-16,12))
 events.append(emitter("relay-tick.wav",Vector3(1,5.8,0),-21,10))
 voice=emitter("children-laugh.ogg",CrawlTubes.route(7.4),-1,5)
 voice.attenuation_filter_cutoff_hz=2700
 if not OS.has_feature("web"):
  if AudioServer.get_bus_index("CrawlSpace")<0:
   AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,"CrawlSpace");AudioServer.set_bus_send(bus,"Interior")
   var reverb:=AudioEffectReverb.new();reverb.room_size=.4;reverb.damping=.7;reverb.wet=.24;reverb.dry=.9;AudioServer.add_bus_effect(bus,reverb)
  voice.bus="CrawlSpace"
  for source in events+beds: source.bus="Interior"

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
 for source in events+beds+[voice]:
  if source.stream_paused==active: source.stream_paused=not active
 if not active: return
 for source in beds:
  if not source.playing: source.play(rng.randf_range(0,source.stream.get_length()*.5))
 clock+=delta;event_timer-=delta
 if event_timer<=0:
  # Different positions and long irregular gaps, independent of anomaly RNG.
  var source:=events[rng.randi_range(0,events.size()-1)];source.pitch_scale=rng.randf_range(.88,1.08);source.play();event_timer=rng.randf_range(11,23)
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
 for source in events+beds+[voice]: source.stop()

func snapshot() -> Dictionary:
 return {"clock":clock,"in_tube":in_tube,"voice_count":voice_count,"last_voice":last_voice,"voice_playing":voice.playing,"voice_paused":voice.stream_paused,"voice_timer":voice_timer,"bed_count":beds.size(),"event_count":events.size()}
