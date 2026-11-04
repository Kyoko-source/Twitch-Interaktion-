class_name CreatureFoley
extends Node3D

var w: PlayWorld
var records: Dictionary={}
var count:=0

func build(world: PlayWorld) -> void:
 w=world;name="MaterialCreatureMovement"
 for id in ["horse","rabbit","clown","visitor"]:
  var source:=AudioStreamPlayer3D.new();source.name=id.capitalize()+"MaterialMovement";source.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
  source.unit_size=2.;source.max_distance=10.;source.volume_db=-28. if id=="clown" else -22.;add_child(source)
  w.acoustics.add_source(source)
  records[id]={"source":source,"last":Vector3.ZERO,"anchored":false,"distance":0.,"cooldown":0.,"variant":0}

func target(id: String) -> Node3D:
 if id=="horse":return w.room_horror.creature.mask
 if id=="rabbit":return w.atmosphere.horrors.bunny
 if id=="clown":return w.annex.clown.hand
 return w.terrors.actor

func tick(delta: float,active: bool) -> void:
 for id in records:
  var r: Dictionary=records[id];var node:=target(id)
  if not active:r.source.stop();r.anchored=false;continue
  r.cooldown=maxf(0.,r.cooldown-delta)
  if not is_instance_valid(node) or not node.is_visible_in_tree():r.anchored=false;continue
  var p:=node.global_position
  if r.anchored:
   var moved: float=p.distance_to(r.last)
   if moved<2.:r.distance+=moved
  r.last=p;r.anchored=true;r.source.global_position=p
  var threshold:=.13 if id=="clown" else .35 if id=="horse" else .45
  if r.distance>=threshold and r.cooldown<=0:
   var variants: Array=[1,2,3,4];variants.erase(r.variant);r.variant=variants.pick_random()
   r.source.stream=QualityAssets.audio("joint" if id=="horse" else "fabric",r.variant);r.source.play()
   r.distance=0.;r.cooldown=1.3 if id=="clown" else .65;count+=1

func snapshot() -> Dictionary:
 return {"count":count,"sources":records.size(),"playing":records.values().filter(func(r):return r.source.playing).size()}
