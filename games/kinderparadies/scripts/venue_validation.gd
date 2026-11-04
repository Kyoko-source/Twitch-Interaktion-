extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world
 verify.call(w.venue.count>=330,"Cinema and main hall detail pass is incomplete")
 for path in ["CinemaShowHistory/ServicedProjectionApparatus","ArcadeLounge/ArcadeTokenExchange","HallBuildingHistory"]:
  verify.call(w.venue.has_node(path),"Missing functional venue dressing: "+path)
 var bounds:=AABB();var first:=true
 for mesh in w.playground.croc_visual.find_children("*","MeshInstance3D",true,false):
  var b: AABB=mesh.global_transform*mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
 # The larger v3.8.5 animal has a longer snout than the retired v3 model.
 verify.call(bounds.position.z>9.1 and bounds.end.z<15.2,"Crocodile intrudes on the climbing tower or photo-booth approach: "+str(bounds))
 var tube_bounds:=AABB();first=true
 for mesh in w.tubes.find_children("*","MeshInstance3D",true,false):
  var b: AABB=mesh.global_transform*mesh.get_aabb();tube_bounds=b if first else tube_bounds.merge(b);first=false
 for name in ["Arcade_arcade","Arcade_orbit","ArcadePrizeCabinet"]:
  var cabinet:=w.details.find_child(name,true,false)
  for mesh in cabinet.find_children("*","MeshInstance3D",true,false):
   verify.call(not tube_bounds.intersects(mesh.global_transform*mesh.get_aabb()),"A cabinet intersects the crawl-tube envelope: "+name)
 var holders:=w.find_children("RecessedCupHolder*","Node3D",true,false)
 verify.call(holders.size()==48,"Cinema cup holders are not attached to all 24 seats")
 var skin_count:=0;var eye_count:=0
 for mesh in w.annex.clown.head.find_children("*","MeshInstance3D",true,false):
  if "Inset_eyeball" in str(mesh.name) or "Inset eyeball" in str(mesh.name):eye_count+=1
 for mesh in w.annex.clown.root.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var mat: Material=mesh.get_active_material(i)
   if mat is ShaderMaterial and mat.shader.resource_path.ends_with("clown_skin.gdshader"):
    skin_count+=1;verify.call(mat.get_shader_parameter("skin")!=null and mat.get_shader_parameter("pores")!=null,"Clown facial detail textures are missing")
 verify.call(skin_count==1 and eye_count==2,"Clown has no scanned textured face or physical eyes")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Venue detail pass obstructs architecture: "+JSON.stringify(layout))
 verify.call(w.venue.clear_pose(Vector3(13,0,14.7)) and not w.venue.clear_pose(Vector3(11.2,0,16.38)),"Photo-booth access or new token machine collision is invalid")
 w.archive.leaf.rotation.y=-1.8;w.backstage.exit_leaf.rotation.y=PI/2
 w.passages.restore({"chosen":-1,"open":[true,true]})
 verify.call(SceneAudit.placement(w).doors.is_empty(),"Venue details obstruct a door after opening it")
 verify.call(game.state.current=="none","Ordinary cinema dressing introduced an anomaly")
