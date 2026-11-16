class_name RosenyanPlush
extends RefCounted
# Rosenyan plush (4.5.0): a soft doll sitting among the play-corner toys. Character and voice
# belong to RosenyanVT (twitch.tv/rosenyanvt) and are credited in the menu, the credits and the
# licence notes. Picking her up plays her "I am defeated" and shows the guard's comment.

const TITLE:="Rosenyan-Puppe"
const MODEL:="res://assets/rosenyan-v450/rosenyan-plush.glb"
const VOICE:="res://assets/rosenyan-v450/i-am-defeated.ogg"
const SPOT:=Vector3(-4.2,.225,7.6)
const HALF_HEIGHT:=.22

static func place(atmosphere: Node3D) -> NightProp:
 var body:=NightProp.new();body.name="RosenyanPlush";body.title=TITLE;body.mass=.45
 body.position=SPOT;body.rotation.y=PI*.72
 var physics:=PhysicsMaterial.new();physics.friction=.85;physics.bounce=.04;body.physics_material_override=physics
 var shape:=BoxShape3D.new();shape.size=Vector3(.34,HALF_HEIGHT*2,.3)
 var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
 var model: Node3D=(load(MODEL) as PackedScene).instantiate();model.name="RosenyanModel"
 # The glTF faces +Z and stands on its seat; the body origin is the collider centre.
 model.position=Vector3(0,-HALF_HEIGHT,.02);body.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
 var voice:=AudioStreamPlayer3D.new();voice.name="Voice";voice.stream=load(VOICE)
 voice.volume_db=-1.0;voice.unit_size=3.0;voice.max_distance=16.0;body.add_child(voice)
 body.picked.connect(func():_on_picked(body,voice))
 atmosphere.add_child(body);atmosphere.loose.append(body);body.suspend(true)
 return body

static func _on_picked(body: NightProp,voice: AudioStreamPlayer3D) -> void:
 voice.pitch_scale=randf_range(.98,1.03);voice.play()
 var node: Node=body.get_parent()
 while node and not ("dialogue" in node):node=node.get_parent()
 if node and node.dialogue:node.dialogue.request_again("rosenyan")
