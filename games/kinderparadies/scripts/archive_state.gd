class_name ArchiveState
extends RefCounted

const ORDER: Array[String]=["note","opening","missing","coverup","closure","casefile"]
const PAPERS: Array[String]=["opening","missing","coverup","closure"]
static var catalog: Dictionary={}
var collected: Array[String]=[]
var unlocked:=false

static func document(id: String) -> Dictionary:
 if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/catalog.json"))
 return catalog.get(id,{})

func clear() -> void:
 collected.clear();unlocked=false

func has_all_papers() -> bool:
 for id in PAPERS:
  if id not in collected: return false
 return true

func take(id: String, stage: int) -> bool:
 if id not in ORDER or id in collected: return false
 if id in PAPERS and int(document(id).stage)!=stage: return false
 if id=="casefile" and not unlocked: return false
 collected.append(id);return true

func try_code(value: String) -> bool:
 if not has_all_papers() or value!="6428": return false
 unlocked=true;return true

func serialize() -> Dictionary:
 return {"version":1,"collected":collected.duplicate(),"unlocked":unlocked}

func restore(data: Dictionary) -> bool:
 clear()
 if data.get("version")!=1 or not data.get("collected") is Array or not data.get("unlocked") is bool: return false
 var ids: Array[String]=[]
 for id in data.collected:
  if not id is String or id not in ORDER or id in ids: return false
  ids.append(id)
 collected=ids
 if data.unlocked and not has_all_papers(): clear();return false
 if "casefile" in collected and not data.unlocked: clear();return false
 unlocked=data.unlocked;return true
