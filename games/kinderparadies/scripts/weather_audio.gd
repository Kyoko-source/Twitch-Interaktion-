class_name HappylandWeather
extends Node

const ROOT:="res://assets/weather-v352/"
const BUS:="AP.Weather"
const LEVELS:={"hall":-17.,"party":-21.,"kitchen":-23.,"cinema":-25.,"corridor":-22.,"service":-23.,"washroom":-22.,"backstage":-24.,"archive":-27.,"tube":-25.,"entrance":-14.,"outside":-12.,"elevator":-29.}
var rain: AudioStreamPlayer
var thunder: AudioStreamPlayer
var filter: AudioEffectLowPassFilter
var rng:=RandomNumberGenerator.new()
var next_roll:=0.
var clock:=0.
var count:=0
var last_variant:=-1
var area:="hall"
var running:=false
# 4.11.0: lightning first, then thunder after a delay that grows with distance.
var storm: Node
var pending:=-1.
var pending_near:=false
const CLOSE:="res://assets/weather-v4110/close-thunder-%d.ogg"

func build() -> void:
 name="QuietRainAndDistantThunder";rng.randomize();next_roll=rng.randf_range(8.,16.)
 var index:=AudioServer.get_bus_index(BUS)
 if index<0:AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,BUS)
 AudioServer.set_bus_send(index,"NightAmbience")
 filter=AudioEffectLowPassFilter.new();filter.cutoff_hz=850.
 AudioServer.add_bus_effect(index,filter)
 rain=AudioStreamPlayer.new();rain.name="SoftRoofRain";rain.bus=BUS;rain.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var stream: AudioStreamOggVorbis=load(ROOT+"soft-roof-rain.ogg").duplicate();stream.loop=true;rain.stream=stream;rain.volume_db=-60;add_child(rain)
 thunder=AudioStreamPlayer.new();thunder.name="DistantRollingThunder";thunder.bus=BUS;thunder.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;thunder.volume_db=-26;add_child(thunder)

func cue_thunder() -> void:
 var distance:=rng.randf()
 pending_near=distance<.35;pending=.2+distance*3.6
 if is_instance_valid(storm):storm.flash(1.-distance)
 next_roll=rng.randf_range(22.,48.)

func _sound_thunder() -> void:
 var variant:=rng.randi_range(0,2)
 if variant==last_variant:variant=(variant+1+rng.randi_range(0,1))%3
 last_variant=variant
 thunder.stream=load(CLOSE%(variant+1) if pending_near else ROOT+"distant-thunder-%d.ogg"%(variant+1));thunder.play();count+=1

func tick(delta: float,active: bool,room: String,allow_thunder: bool=true) -> void:
 running=active
 if not active:
  rain.stream_paused=true;thunder.stream_paused=true;return
 area=room
 rain.stream_paused=false;thunder.stream_paused=false
 if not rain.playing:rain.play()
 clock+=delta
 var weight:=minf(1.,delta*2.)
 var level: float=LEVELS.get(room,-24.)
 rain.volume_db=lerpf(rain.volume_db,level,weight)
 # The recording already has a soft average level. A second -20 dB
 # attenuation buried it beneath the room beds, particularly on small speakers.
 thunder.volume_db=lerpf(thunder.volume_db,level*.35-(-4. if pending_near else 2.),weight)
 filter.cutoff_hz=lerpf(filter.cutoff_hz,(2600. if pending_near else 1600.) if room in ["entrance","outside"] else 500. if room in ["archive","tube","elevator"] else (1700. if pending_near else 850.),weight)
 if not allow_thunder:thunder.stop();return
 if pending>=0:
  pending-=delta
  if pending<0:_sound_thunder()
 next_roll-=delta
 if next_roll<=0 and not thunder.playing and pending<0:cue_thunder()

func snapshot() -> Dictionary:
 return {"clock":clock,"running":running,"area":area,"next_roll":next_roll,"count":count,"variant":last_variant,"rain_playing":rain.playing,"thunder_playing":thunder.playing,"paused":rain.stream_paused,"rain_db":rain.volume_db,"thunder_db":thunder.volume_db,"cutoff":filter.cutoff_hz,"bus":rain.bus}

func _exit_tree() -> void:
 if is_instance_valid(rain):rain.stop()
 if is_instance_valid(thunder):thunder.stop()
 var index:=AudioServer.get_bus_index(BUS)
 if index>=0:AudioServer.remove_bus(index)
