class_name ArchiveState
extends RefCounted

const ORDER: Array[String]=["note","opening","missing","coverup","closure","casefile"]
const PAPERS: Array[String]=["opening","missing","coverup","closure"]
static var catalog: Dictionary={}
var collected: Array[String]=[]
var unlocked:=false
var creator_access:=false
var ending:="idle"
var recording_position:=0.0

static func document(id: String) -> Dictionary:
 if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/catalog.json"))
 return catalog.get(id,{})

func clear() -> void:
 collected.clear();unlocked=false;creator_access=false;ending="idle";recording_position=0.0

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
 if value=="0712": creator_access=true;unlocked=true;return true
 if not has_all_papers() or value!="6428": return false
 unlocked=true;return true

func serialize() -> Dictionary:
 return {"version":2,"collected":collected.duplicate(),"unlocked":unlocked,"creator_access":creator_access,"ending":ending,"recording_position":recording_position}

func restore(data: Dictionary) -> bool:
 clear()
 if (data.get("version")!=1 and data.get("version")!=2) or not data.get("collected") is Array or not data.get("unlocked") is bool: return false
 var access=data.get("creator_access",false) if data.version==2 else false
 var finale: String=str(data.get("ending","idle")) if data.version==2 else "idle"
 var position=data.get("recording_position",0.0) if data.version==2 else 0.0
 if not data.get("creator_access",false) is bool or finale not in ["idle","recording","armed","complete"]: return false
 if typeof(position) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(position)) or float(position)<0 or float(position)>3600: return false
 var ids: Array[String]=[]
 for id in data.collected:
  if not id is String or id not in ORDER or id in ids: return false
  ids.append(id)
 collected=ids
 if data.unlocked and not has_all_papers() and not access: clear();return false
 if "casefile" in collected and not data.unlocked: clear();return false
 if (access or finale!="idle") and not data.unlocked: clear();return false
 unlocked=data.unlocked;creator_access=access;ending=finale;recording_position=float(position);return true
