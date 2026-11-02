extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var art: ChildDrawings=game.world.child_art
 verify.call(art.pieces.size()==15,"Child-height drawing placement is incomplete")
 var rooms: Dictionary={};var paper_count:=0;var wall_count:=0;var poses: Array[Transform3D]=[]
 for piece in art.pieces:
  var size:=piece.get_aabb().size
  var mount:=piece.get_parent() as Node3D
  verify.call(mount.global_position.y>=.5 and mount.global_position.y+size.y/2<1.05,"Children's artwork is placed at adult height")
  rooms[piece.get_meta("room")]=true;poses.append(mount.global_transform)
  if piece.get_meta("paper"):
   paper_count+=1
   verify.call(mount.find_children("YellowedTape*","MeshInstance3D",true,false).size()==2,"A paper drawing has no attached tape")
  else:wall_count+=1
  verify.call(piece.find_children("*","CollisionShape3D",true,false).is_empty(),"A decorative wall drawing has an unnecessary collider")
 verify.call(rooms.size()==3 and paper_count==9 and wall_count==6,"Paper and direct crayon drawings are not distributed across the venue")
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var attached:=true;var issue:=""
 for piece in art.pieces:
  var mount:=piece.get_parent() as Node3D;var normal:=mount.global_basis.z.normalized()
  var query:=PhysicsRayQueryParameters3D.create(mount.global_position+normal*.04,mount.global_position-normal*.20)
  var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty() or not hit.collider.get_parent().get_meta("architecture_wall",false):attached=false;issue=str(mount.name)
 verify.call(attached,"Child artwork floats without a wall behind it: "+issue)
 var exposed:=true
 var meshes: Array=game.world.find_children("*","MeshInstance3D",true,false)
 for piece in art.pieces:
  var centre:=piece.to_global(piece.get_aabb().get_center())+piece.global_basis.z*.001
  for mesh: MeshInstance3D in meshes:
   if mesh==piece or not mesh.is_visible_in_tree():continue
   if mesh.get_aabb().grow(.001).has_point(mesh.to_local(centre)):exposed=false;issue=str(piece.get_parent().name)+" inside "+str(mesh.get_path())
 verify.call(exposed,"A drawing is buried in a wall finish or curtain: "+issue)
 var layout:=SceneAudit.placement(game.world)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Child drawings overlap an existing sign, artwork or doorway: "+JSON.stringify(layout))
 game.world.tick(30,true)
 var static_art:=true
 for i in range(art.pieces.size()):
  if art.pieces[i].get_parent().global_transform!=poses[i]:static_art=false
 verify.call(static_art and game.world.current=="none","Children's drawings introduce movement or anomalies in a reference round")
