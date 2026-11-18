class_name SharedShaders
extends RefCounted

# 4.8.1 load time: the world is rebuilt every round. A fresh Shader object for
# the same code made the renderer parse it and build its pipelines again on
# each round change. Identical code now always returns the same Shader.
static var cache:={}

static func of(code: String) -> Shader:
 var key:=code.hash()
 var found: Shader=cache.get(key)
 if found and found.code==code: return found
 var shader:=Shader.new();shader.code=code;cache[key]=shader
 return shader
