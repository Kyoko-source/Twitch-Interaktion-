extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var guard: NightGuard=game.player
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var frame: AgedArchway=w.arrival_design.find_child("AgedTimberAnnexPortal",true,false)
 verify.call(frame!=null and frame.solids.size()==3,"Annex portal is missing its three fitted timber liners")
 for mesh in frame.solids:
  verify.call(mesh.material_override is ShaderMaterial and mesh.get_child_count()==1,"Timber reveal has no aged finish or simple fitted collision")
 var snack:=w.life.snack
 verify.call(snack.global_position.distance_to(HappylandLife.SNACK_POS)<.001 and snack.global_position.z<1.,"Snackbar is still in the main hall")
 verify.call(snack.get_children().filter(func(node):return node.get_meta("slush_dispenser",false)).size()==2,"Snackbar relocation lost a dispenser")
 verify.call(w.life.clear_pose(Vector3(16.95,0,16.24)) and not w.life.clear_pose(snack.global_position),"Snackbar collision or old saved-position bounds were not moved")
 var fresco:=w.find_child("TheFourEmptyChairs",true,false) as Node3D
 verify.call(fresco.position.y-1.9>2.0,"Snackbar machines obscure the bottom of the wall painting")
 var menu: MeshInstance3D=snack.get_node("PartySnackbarMenu")
 verify.call(menu.global_basis.z.dot(Vector3.RIGHT)>.99 and absf(menu.global_position.x-6.98)<.01,"Menu is not fitted on the adjacent party wall")
 var old_notice:=false
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.get_meta("mounted_art",false) and mesh.global_position.distance_to(Vector3(-9.975,2.0,-7.55))<.1:old_notice=true
 verify.call(not old_notice,"Marked technical-service notice remains on the main-room wall")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Scenery blocks a doorway, wall art or furniture: "+JSON.stringify(layout))
 var route=load("res://scripts/reception_validation.gd").new()
 verify.call(await route.walk(game,Vector3(-7.9,0,-10),Vector3(-7.9,0,-15.2),180),"New timber frame blocks entering the annex")
 verify.call(await route.walk(game,Vector3(-7.9,0,-15.2),Vector3(-7.9,0,-10),180),"New timber frame traps the returning player")
 verify.call(await route.walk(game,Vector3(5.5,0,-8.7),Vector3(8.1,0,-8.7)),"Snackbar relocation blocks the party-room entrance")
 verify.call(await route.walk(game,Vector3(8.1,0,-6.2),Vector3(8.1,0,-.7),180),"Snackbar blocks the passage beside the birthday tables")
 await route.walk(game,Vector3(11,0,-1.2),Vector3(11,0,.7),80)
 verify.call(guard.position.z< -.12,"Snackbar collision did not follow the visible counter")
 for id in ["snackbar_visitor","party_portrait"]:
  game._build_world(id);guard.active=false
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var terror: NightTerrors=game.world.terrors;var shape:=terror.actor.get_child(1) as CollisionShape3D
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=1;query.exclude=[guard.get_rid(),terror.actor.get_rid()]
  verify.call(game.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"Moved party encounter spawns in furniture: "+id)
  guard.position=terror.origin+Vector3(0,0,-1.8);guard.camera.look_at(terror.focus_point());terror.tick(1,true,guard)
  verify.call(terror.triggered,"Moved party encounter has no working sightline: "+id)
