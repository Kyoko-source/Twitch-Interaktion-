class_name ScareBank
extends RefCounted

const ROOT:="res://assets/revamp-v300/"
const VOICE_ROOT:="res://assets/feedback-v403/"
const SOUND_ROOT:="res://assets/quality-v410/audio/"
const VARIANTS:=4
const VOICES:=["horse","granny","door"]
const FAMILIES:=["rabbit","clown","ossuary","crawler","window","fall","crowd","charge","whisper","crocodile"]
const BUS:="AP.Scare"
static var previous: Dictionary={}
static var random:=RandomNumberGenerator.new()
static var initialized:=false
# 5.4.0: the owner's jumpscare stings ride on top of every scream.
const STING_ROOT:="res://assets/jumpscare-v540/sting-%d.ogg"
const STINGS:=6
const BALLOON_BURST:="res://assets/jumpscare-v540/balloon-burst.ogg"
static var sting_player: AudioStreamPlayer
static var last_sting:=0
static var sting_at:=-10.
static var sting_count:=0

static func family(id: String, mode: String="") -> String:
 if id=="door_death":return "door"
 if id in ["horse_contact","ceiling_horse_hunt"]:return "horse"
 if id.begins_with("granny_"):return "granny"
 if "bunny" in id or "mascot" in id: return "rabbit"
 if "clown" in id or "kitchen_double"==id or id=="archive_finale": return "clown"
 if "vent" in id or "ceiling" in id or id=="pit_hands": return "ossuary"
 if "croc" in id: return "crocodile"
 if "window" in id or id=="tube_watcher": return "window"
 if "tube" in id or "crawl" in id or mode=="crawl": return "crawler"
 if "drop" in id or mode=="drop": return "fall"
 if mode in ["queue","throne"] or id=="party_burst": return "crowd"
 if mode in ["rush","ambush","pursuit","crossing"] or id=="door_death": return "charge"
 return "whisper"

static func select(player: AudioStreamPlayer3D, id: String, mode: String="") -> void:
 var kind:=family(id,mode);var variant:=choose(kind,false)
 player.stream=load(track(kind,variant))
 player.pitch_scale=1.0;player.volume_db=0
 player.set_meta("scare_family",kind);player.set_meta("scare_variant",variant)

static func next_variant(kind: String) -> int:
 return choose(kind,true)

static func choose(kind: String, remember: bool) -> int:
 if not initialized: random.randomize();initialized=true
 var candidates: Array[int]=[1,2,3,4];candidates.erase(previous.get(kind,0))
 var variant: int=candidates[random.randi_range(0,candidates.size()-1)]
 if remember: previous[kind]=variant
 return variant

static func flat(id: String) -> AudioStream:
 var kind:=family(id)
 return load(track(kind,choose(kind,false)))

static func track(kind: String,variant: int) -> String:
 return SOUND_ROOT+kind+"-%d.ogg"%variant

static func play(player: AudioStreamPlayer3D) -> void:
 var kind: String=player.get_meta("scare_family","")
 var variant: int=player.get_meta("scare_variant",0)
 if not kind.is_empty():
  if previous.get(kind,0)==variant:
   variant=choose(kind,false);player.stream=load(track(kind,variant));player.set_meta("scare_variant",variant)
  previous[kind]=variant
 player.play();sting()

static func play_flat(player: Node) -> void:
 var path: String=player.stream.resource_path
 if path.begins_with(ROOT) or path.begins_with(VOICE_ROOT) or path.begins_with(SOUND_ROOT):
  var key:=path.get_file().get_basename();var kind:=key.get_slice("-",0);var variant:=int(key.get_slice("-",1))
  if previous.get(kind,0)==variant: variant=choose(kind,false);player.stream=load(track(kind,variant))
  previous[kind]=variant
 player.play();sting()

# One sting per scare, never the same twice in a row; two calls within half a
# second (a scream plus the full-screen hit) share the first one.
static func sting() -> void:
 var now:=Time.get_ticks_msec()/1000.
 if now-sting_at<.5:return
 var tree:=Engine.get_main_loop() as SceneTree
 if not tree or not tree.root:return
 if not is_instance_valid(sting_player):
  sting_player=AudioStreamPlayer.new();sting_player.name="JumpscareSting";sting_player.volume_db=-3.;tree.root.add_child.call_deferred(sting_player)
  loud(sting_player)
 if not initialized: random.randomize();initialized=true
 var pick:=random.randi_range(1,STINGS-1)
 if pick>=last_sting:pick+=1
 if last_sting==0:pick=random.randi_range(1,STINGS)
 last_sting=pick;sting_at=now;sting_count+=1
 sting_player.stream=load(STING_ROOT%pick)
 if sting_player.is_inside_tree():sting_player.play()
 else:sting_player.ready.connect(sting_player.play,CONNECT_ONE_SHOT)

static func lead(parent: Node3D, id: String, mode: String="") -> AudioStreamPlayer3D:
 var player:=AudioStreamPlayer3D.new();player.name="ScareAnticipation"
 player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;player.max_distance=13;player.unit_size=3
 var kind:=family(id,mode)
 player.volume_db=-16;player.stream=load(SOUND_ROOT+kind+"-lead.ogg")
 parent.add_child(player)
 if AudioServer.get_bus_index("Interior")>=0: player.bus="Interior"
 return player

# Jumpscares get their own bus straight into Master: never ducked by the
# ambience slider, pushed hot into a limiter so every hit lands at full level.
static func bus() -> String:
 var index:=AudioServer.get_bus_index(BUS)
 if index<0:
  AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,BUS)
  var limiter:=AudioEffectHardLimiter.new();limiter.ceiling_db=-.3;limiter.pre_gain_db=3.
  AudioServer.add_bus_effect(index,limiter)
 AudioServer.set_bus_send(index,"Master")
 return BUS

static func loud(player: Node) -> void:
 player.bus=bus();player.set_meta("scare_bus",true)
