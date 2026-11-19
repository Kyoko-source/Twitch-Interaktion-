class_name ZombiesAnnouncer
extends RefCounted

# Voice lines and stingers of the wave mode. Drop a recording into
# res://assets/zombies-v500/audio/ named after the key (ogg, wav or mp3) and
# it replaces the synthesised placeholder, no code change needed.
# Keys: start, round, round_end, boss, boss_phase, boss_down, perk, door,
# box, box_result, box_troll, upgrade, upgrade_start, reality, game_over,
# ammo_empty, pickup_<id>, event_<id>.
const FOLDER:="res://assets/zombies-v500/audio/"
const LOUD:=["start","round","boss","boss_down","reality","game_over"]
static var cache:={}
static var recorded:={}
# One voice at a time: a new spoken line cuts the previous one.
static var voice: AudioStreamPlayer

static func stream_for(key: String) -> AudioStream:
	if key=="":return null
	if cache.has(key):return cache[key]
	var found: AudioStream=null
	for ext in ["ogg","wav","mp3"]:
		if ResourceLoader.exists(FOLDER+key+"."+ext):found=load(FOLDER+key+"."+ext);recorded[key]=true;break
	if found==null and key.begins_with("pickup_") and ResourceLoader.exists(FOLDER+"pickup.ogg"):found=load(FOLDER+"pickup.ogg")
	if found==null:found=_placeholder(key)
	cache[key]=found;return found

static func play(owner: Node, key: String) -> void:
	var stream:=stream_for(key)
	if stream==null or not is_instance_valid(owner):return
	var spoken: bool=recorded.has(key)
	if spoken and is_instance_valid(voice):voice.stop();voice.queue_free()
	var player:=AudioStreamPlayer.new();player.stream=stream;player.volume_db=-1. if spoken else -4. if key in LOUD else -10.;player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	owner.add_child(player);player.play();player.finished.connect(player.queue_free)
	if spoken:voice=player

# A low detuned drone with a sting on top, pitched per key.
static func _placeholder(key: String) -> AudioStreamWAV:
	var base:=55.+float(hash(key)%40);var length:=1.6 if key in LOUD else .7
	var rate:=22050;var count:=int(length*rate);var data:=PackedByteArray();data.resize(count*2)
	for i in range(count):
		var t:=float(i)/rate;var env:=minf(t*8.,1.)*exp(-t*(1.6 if key in LOUD else 4.))
		var s:=sin(TAU*base*t)*.5+sin(TAU*base*1.01*t+sin(t*3.))*.35+sin(TAU*base*4.02*t)*.12*exp(-t*6.)
		if key.begins_with("pickup_") or key=="perk":s+=sin(TAU*(660.+t*400.)*t)*.3*exp(-t*5.)
		data.encode_s16(i*2,int(clampf(s*env,-1.,1.)*26000.))
	var w:=AudioStreamWAV.new();w.format=AudioStreamWAV.FORMAT_16_BITS;w.mix_rate=rate;w.data=data;return w
