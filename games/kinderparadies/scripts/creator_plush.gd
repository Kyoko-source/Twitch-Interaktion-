class_name CreatorPlush
extends RefCounted
# Creator plushies in the play corner (4.5.0 Rosenyan, 4.6.0 einsmarello). Character and voice
# belong to the creators and are credited in the menu, the end credits and the licence notes.
# Picking one up plays her voice line and shows the guard's comment for her.

const PLUSHES:={
 "rosenyan":{"node":"RosenyanPlush","title":"Rosenyan-Puppe","model":"res://assets/rosenyan-v450/rosenyan-plush.glb",
  "voice":"res://assets/rosenyan-v450/i-am-defeated.ogg","spot":Vector3(-4.2,.225,7.6),"yaw":PI*.72,"comment":"rosenyan"},
 "einsmarello":{"node":"EinsmarelloPlush","title":"einsmarello-Puppe","model":"res://assets/einsmarello-v460/einsmarello-plush.glb",
  "voice":"res://assets/einsmarello-v460/barbie-girl.ogg","spot":Vector3(-4.75,.225,8.25),"yaw":PI*.62,"comment":"einsmarello"},
}
const TITLES:=["Rosenyan-Puppe","einsmarello-Puppe"]
const HALF_HEIGHT:=.22

static func place_all(atmosphere: Node3D) -> void:
 for id in PLUSHES:place(atmosphere,id)

static func place(atmosphere: Node3D,id: String) -> NightProp:
 var cfg: Dictionary=PLUSHES[id]
 var body:=NightProp.new();body.name=cfg.node;body.title=cfg.title;body.mass=.45
 body.position=cfg.spot;body.rotation.y=cfg.yaw
 var physics:=PhysicsMaterial.new();physics.friction=.85;physics.bounce=.04;body.physics_material_override=physics
 var shape:=BoxShape3D.new();shape.size=Vector3(.34,HALF_HEIGHT*2,.3)
 var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
 var model: Node3D=(load(cfg.model) as PackedScene).instantiate();model.name="PlushModel"
 # The glTF faces +Z and stands on its seat; the body origin is the collider centre.
 model.position=Vector3(0,-HALF_HEIGHT,.02);body.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
 var voice:=AudioStreamPlayer3D.new();voice.name="Voice";voice.stream=load(cfg.voice)
 voice.volume_db=-1.0;voice.unit_size=3.0;voice.max_distance=16.0;body.add_child(voice)
 body.picked.connect(func():_on_picked(body,voice,str(cfg.comment)))
 atmosphere.add_child(body);atmosphere.loose.append(body);body.suspend(true)
 return body

static func _on_picked(body: NightProp,voice: AudioStreamPlayer3D,comment: String) -> void:
 voice.pitch_scale=randf_range(.98,1.03);voice.play()
 var node: Node=body.get_parent()
 while node and not ("dialogue" in node):node=node.get_parent()
 if node and node.dialogue:node.dialogue.request_again(comment)
