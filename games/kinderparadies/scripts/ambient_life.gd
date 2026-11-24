class_name AmbientLife
extends Node3D

# 5.2.7: the venue breathes. Real CC0 field recordings (assets/ambient-v527,
# tools/prepare-after-play-ambient-life-v527.py) in two layers:
#  - room tones: neon and tube hum, wind at the old main
#    door, rain on the window, the boiler, the snack machine, dripping sinks
#    and the dead cinema speaker, each looping at its real source;
#  - life: every few seconds one sound within earshot, from the building
#    (creaks, radiators, plastic frames), animals (rats, mice, a pigeon), toys
#    (squeaks, wind-up cars, the music box, balls in the pit), the washroom and
#    the street outside (cars in the rain, dogs, a siren, an owl).
# Its own random stream; it never touches the patrol RNG, and it plays the same
# way in normal and anomaly rounds, so no sound gives a round away.
const ROOT:="res://assets/ambient-v527/"
# 5.6.1: the reception clock ticks on its own (PlayWorld, ClockTick), in step
# with its second hand.
const BEDS:=[
 {"file":"neon-buzz","pos":Vector3(-8.5,2.9,7.0),"db":-19.0,"reach":8.0,"power":true},
 {"file":"fluorescent-hum","pos":Vector3(0,4.4,3),"db":-23.0,"reach":10.0,"power":true},
 {"file":"fluorescent-hum","pos":Vector3(12,4.4,10),"db":-24.0,"reach":10.0,"power":true},
 {"file":"fluorescent-hum","pos":Vector3(-7.9,3,-18),"db":-23.0,"reach":8.0,"power":true},
 {"file":"fluorescent-hum","pos":Vector3(-13.6,3.1,-30.7),"db":-24.0,"reach":7.0,"power":true},
 {"file":"entrance-wind","pos":Vector3(-15.6,1.4,9.4),"db":-14.0,"reach":11.0},
 {"file":"window-rain","pos":Vector3(-10.4,2.2,1.7),"db":-18.0,"reach":8.0},
 {"file":"boiler","pos":Vector3(-13.5,1,-4.2),"db":-18.0,"reach":9.0,"power":true},
 {"file":"vending-hum","pos":Vector3(12.6,1,-1.4),"db":-20.0,"reach":7.0,"power":true},
 {"file":"sink-drip","pos":Vector3(-16.63,1,-28.65),"db":-19.0,"reach":6.0},
 {"file":"sink-drip","pos":Vector3(23.1,1,5.7),"db":-21.0,"reach":6.0},
 {"file":"cinema-static","pos":Vector3(3.48,1.9,-29.6),"db":-24.0,"reach":10.0,"power":true}
]
const CEILINGS:=[Vector3(0,5,0),Vector3(8,5,8),Vector3(-4,5,10),Vector3(14,4,-6),Vector3(-7.9,3,-20),Vector3(-13,3,-33),Vector3(0,3,-33),Vector3(-13,2.5,-4),Vector3(17,3,-14)]
const WALLS:=[Vector3(-9.6,4,-2),Vector3(10,4.5,-11.5),Vector3(-16,2.8,-34),Vector3(18,3,12),Vector3(-6,.2,-22),Vector3(-12,.2,-6),Vector3(26,2.8,9)]
const OUTSIDE:=[Vector3(-11.6,2,1.7),Vector3(-17,1.5,9.4)]
# Each pool: files, points, weight, cooldown per file (s), volume, reach.
const POOLS:={
 "creaks":{"files":["room-creak-a","room-creak-b","wood-creak","floor-creak-1","floor-creak-2","floor-creak-3"],"points":CEILINGS,"weight":3.0,"cooldown":8.0,"db":-9.0,"reach":18.0},
 "metal":{"files":["metal-creak-1","metal-creak-2","radiator-knock-1","radiator-knock-2"],"points":[Vector3(-7.9,3,-16),Vector3(-13,2,-5),Vector3(-13.25,2.6,-31.25),Vector3(25,2.5,7)],"weight":2.0,"cooldown":14.0,"db":-11.0,"reach":16.0},
 "plastic":{"files":["plastic-creak-1","plastic-creak-2"],"points":[Vector3(2,3.5,2),Vector3(3.7,2,10.9)],"weight":1.4,"cooldown":18.0,"db":-11.0,"reach":16.0},
 "rats":{"files":["rat-gnaw-1","rat-gnaw-2","rats","mouse-squeak-1","mouse-squeak-2"],"points":WALLS,"weight":1.5,"cooldown":30.0,"db":-12.0,"reach":14.0},
 "pigeon":{"files":["pigeon"],"points":[Vector3(5,5.8,5),Vector3(-2,5.8,-4)],"weight":.35,"cooldown":150.0,"db":-9.0,"reach":22.0},
 "toys":{"files":["squeak-toy-1","squeak-toy-2","toy-car","windup-car","windup-toy","xylophone-1","xylophone-2","ball-bounce-1","ball-bounce-2"],"points":[Vector3(-2,.3,12),Vector3(10.5,.3,-5.4),Vector3(1.2,.3,9),Vector3(15,.3,-8),Vector3(-5,.3,4)],"weight":1.3,"cooldown":45.0,"db":-12.0,"reach":17.0},
 "rare_toys":{"files":["music-box","talking-toy"],"points":[Vector3(-2,.6,12),Vector3(14,.8,-10)],"weight":.35,"cooldown":180.0,"db":-13.0,"reach":15.0},
 "pit":{"files":["ball-pit-1","ball-pit-2"],"points":[Vector3(3.6,.4,7.1),Vector3(5,.4,6)],"weight":1.0,"cooldown":20.0,"db":-11.0,"reach":14.0},
 "balloons":{"files":["balloon-rub-1","balloon-rub-2"],"points":[Vector3(8.2,2.6,-9.7)],"weight":.7,"cooldown":30.0,"db":-13.0,"reach":10.0},
 "arcade":{"files":["coin-slot"],"points":[Vector3(7.5,1,16.35)],"weight":.45,"cooldown":100.0,"db":-11.0,"reach":14.0},
 "washroom":{"files":["cistern","hand-dryer"],"points":[Vector3(25.7,.8,9),Vector3(21.5,1.4,10.3)],"weight":.6,"cooldown":200.0,"db":-10.0,"reach":16.0},
 "outside":{"files":["car-pass-1","car-pass-2","dogs-1","dogs-2","owl","siren","door-rattle-1","door-rattle-2"],"points":OUTSIDE,"weight":1.5,"cooldown":70.0,"db":-7.0,"reach":42.0}
}
const VOICES:=6

var w: PlayWorld
var rng:=RandomNumberGenerator.new()
var beds: Array[AudioStreamPlayer3D]=[]
var voices: Array[AudioStreamPlayer3D]=[]
var voice_index:=0
var timer:=3.0
var played:={}
var last_file:=""
var count:=0
var clock:=0.0

func build(world: PlayWorld) -> void:
 w=world;name="AmbientLife";rng.randomize()
 for spec in BEDS:
  var source:=_player("Bed_"+str(spec.file),spec.pos,spec.db,spec.reach)
  var stream: AudioStreamOggVorbis=(load(ROOT+spec.file+".ogg") as AudioStreamOggVorbis).duplicate();stream.loop=true;source.stream=stream
  # The blackout silences everything that runs on mains power.
  if spec.get("power",false):source.set_meta("machinery_file",ROOT+spec.file+".ogg")
  beds.append(source)
 for i in range(VOICES):voices.append(_player("LifeVoice%d"%i,Vector3.ZERO,-12,16))

func _player(id: String,pos: Vector3,db: float,reach: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.name=id;source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 source.position=pos;source.volume_db=db;source.unit_size=2.;source.max_distance=reach;source.attenuation_filter_cutoff_hz=4500
 source.bus="NightAmbience";add_child(source);return source

func sources() -> Array[AudioStreamPlayer3D]:
 var all: Array[AudioStreamPlayer3D]=[];all.append_array(beds);all.append_array(voices);return all

func tick(delta: float,active: bool,player: Node3D) -> void:
 for source in beds+voices:
  if source.stream_paused==active:source.stream_paused=not active
 if not active:return
 for source in beds:
  if not source.playing:source.play(rng.randf_range(0,source.stream.get_length()*.9))
 clock+=delta;timer-=delta
 if timer<=0:
  cue(player.global_position)
  timer=rng.randf_range(2.5,6.5)

# One life sound within earshot of the listener. Returns the file played.
func cue(listener: Vector3) -> String:
 var options: Array=[];var total:=0.
 for key in POOLS:
  var pool: Dictionary=POOLS[key]
  var points: Array=pool.points.filter(func(p):return p.distance_to(listener)<pool.reach)
  var files: Array=pool.files.filter(func(f):return f!=last_file and clock-float(played.get(f,-1000.))>=pool.cooldown)
  if points.is_empty() or files.is_empty():continue
  options.append([pool,points,files]);total+=pool.weight
 if options.is_empty():return ""
 var pick:=rng.randf()*total;var chosen: Array=options[-1]
 for option in options:
  pick-=option[0].weight
  if pick<=0:chosen=option;break
 var pool: Dictionary=chosen[0];var file: String=chosen[2][rng.randi_range(0,chosen[2].size()-1)]
 var point: Vector3=chosen[1][rng.randi_range(0,chosen[1].size()-1)]
 var voice:=voices[voice_index];voice_index=(voice_index+1)%voices.size()
 voice.stream=load(ROOT+file+".ogg");voice.position=point+Vector3(rng.randf_range(-.6,.6),0,rng.randf_range(-.6,.6))
 voice.volume_db=pool.db+rng.randf_range(-2.5,1.);voice.max_distance=pool.reach;voice.pitch_scale=rng.randf_range(.93,1.05)
 voice.play();played[file]=clock;last_file=file;count+=1
 # 5.3.0: a car crossing the lot sweeps its lights through the window.
 if file.begins_with("car-pass") and w.mood:w.mood.headlights(point)
 return file

func stop_all() -> void:
 for source in beds+voices:source.stop()

func snapshot() -> Dictionary:
 return {"beds":beds.size(),"beds_playing":beds.filter(func(s):return s.playing).size(),"voices":voices.size(),"count":count,"last":last_file,"timer":timer}
