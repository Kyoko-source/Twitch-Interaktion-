class_name QualityAssets
extends RefCounted

const ROOT:="res://assets/quality-v410/"

static func model(id: String,fallback: String) -> String:
 return fallback if OS.has_feature("web") else ROOT+"desktop/"+id+".glb"

static func audio(kind: String,variant: int) -> AudioStream:
 return load(ROOT+"audio/"+kind+"-%d.ogg"%variant)
