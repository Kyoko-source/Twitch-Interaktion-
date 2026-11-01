class_name ScareBank
extends RefCounted

const ROOT:="res://assets/revamp-v300/"
const FAMILIES:=["rabbit","clown","ossuary","crawler","window","fall","crowd","charge","whisper","crocodile"]
static var previous: Dictionary={}
static var random:=RandomNumberGenerator.new()
static var initialized:=false

static func family(id: String, mode: String="") -> String:
 if "bunny" in id or "mascot" in id: return "rabbit"
 if "clown" in id or "kitchen_double"==id or id=="archive_finale": return "clown"
 if "vent" in id or "ceiling" in id: return "ossuary"
 if "croc" in id: return "crocodile"
 if "window" in id or id=="tube_watcher": return "window"
 if "tube" in id or "crawl" in id or mode=="crawl": return "crawler"
 if "drop" in id or mode=="drop": return "fall"
 if mode in ["queue","throne"] or id=="party_burst": return "crowd"
 if mode in ["rush","ambush","pursuit","crossing"] or id=="door_death": return "charge"
 return "whisper"

static func select(player: AudioStreamPlayer3D, id: String, mode: String="") -> void:
 var kind:=family(id,mode);var variant:=choose(kind,false)
 player.stream=load(ROOT+kind+"-%d.wav"%variant)
 player.pitch_scale=1.0;player.volume_db=-5
 player.set_meta("scare_family",kind);player.set_meta("scare_variant",variant)

static func next_variant(kind: String) -> int:
 return choose(kind,true)

static func choose(kind: String, remember: bool) -> int:
 if not initialized: random.randomize();initialized=true
 var candidates: Array[int]=[1,2,3];candidates.erase(previous.get(kind,0))
 var variant: int=candidates[random.randi_range(0,candidates.size()-1)]
 if remember: previous[kind]=variant
 return variant

static func flat(id: String) -> AudioStream:
 var kind:=family(id)
 return load(ROOT+kind+"-%d.wav"%choose(kind,false))

static func play(player: AudioStreamPlayer3D) -> void:
 var kind: String=player.get_meta("scare_family","")
 var variant: int=player.get_meta("scare_variant",0)
 if not kind.is_empty():
  if previous.get(kind,0)==variant:
   variant=choose(kind,false);player.stream=load(ROOT+kind+"-%d.wav"%variant);player.set_meta("scare_variant",variant)
  previous[kind]=variant
 player.play()

static func play_flat(player: Node) -> void:
 var path: String=player.stream.resource_path
 if path.begins_with(ROOT):
  var key:=path.get_file().trim_suffix(".wav");var kind:=key.get_slice("-",0);var variant:=int(key.get_slice("-",1))
  if previous.get(kind,0)==variant: variant=choose(kind,false);player.stream=load(ROOT+kind+"-%d.wav"%variant)
  previous[kind]=variant
 player.play()

static func lead(parent: Node3D, id: String, mode: String="") -> AudioStreamPlayer3D:
 var player:=AudioStreamPlayer3D.new();player.name="ScareAnticipation"
 player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;player.max_distance=13;player.unit_size=3
 player.volume_db=-16;player.stream=load(ROOT+family(id,mode)+"-lead.wav")
 parent.add_child(player)
 if AudioServer.get_bus_index("Interior")>=0: player.bus="Interior"
 return player
