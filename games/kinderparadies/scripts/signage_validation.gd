extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world
 verify.call(w.watch.board.position==ReceptionWatch.WALL and w.watch.board.global_position.z< -12.2,"Birthday memories were not moved into the annex corridor")
 verify.call(w.arrival_design.has_node("RememberedHappylandCorridor/HungKitchenCinemaWayfinder"),"Kitchen/cinema wayfinding is not suspended from the corridor ceiling")
 var gifts:=w.find_children("*","Node3D",true,false).filter(func(node):return node.has_meta("wrapped_present"))
 verify.call(gifts.size()==11,"A gift area retained its old block-and-strut wrapping")
 for gift in gifts:
  verify.call(gift.has_node("CrispWrappedCarton") and gift.find_children("OverlappingPaperFold*","MeshInstance3D",true,false).size()==2,"Present has no fitted paper folds")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"New signs, memories or presents intersect architecture: "+JSON.stringify(layout))
 var count:=0
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("sign_design"):
   count+=1
   var print_material:=mesh.material_override as StandardMaterial3D
   verify.call(not print_material.uv1_triplanar and print_material.uv1_scale==Vector3.ONE and print_material.uv1_offset==Vector3.ZERO and not print_material.texture_repeat,"Printed metal sign is tiled by a later material pass: "+str(mesh.get_path()))
 verify.call(count>=30,"The signage pass missed legacy brown signs")
 for id in VenueSignage.INDEX.IDS:
  verify.call(VenueSignage.texture(id).get_width()==512 and VenueSignage.texture(id).get_height()==256,"Sign atlas cropping fails for "+id)
 for round_number in range(1,14):
  game.state.streak=round_number-1;game._refresh_hud()
  verify.call(game.intro.floor_number==round_number and game.world.passages.floor_number==round_number,"Lift floor is not synchronized with round "+str(round_number))
  verify.call(game.intro.floor_displays.all(func(indicator):return indicator.text==ElevatorIntro.floor_text(round_number)+"  ▲"),"Entrance cabin still displays a fixed floor")
  verify.call(game.world.passages.floor_displays.all(func(indicator):return indicator.text==ElevatorIntro.floor_text(round_number)+" / AUFZUG"),"A decision corridor still displays a fixed floor")
 game.player.position=Vector3(-7.85,.02,-18.75);game.player.camera.look_at(ReceptionWatch.WALL)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(game._target()=="memory_wall","The relocated photo board cannot be inspected from the corridor")
 # Its complete backboard must clear other notices, not only the staff print.
 var board_bounds:=AABB(Vector3(-6.76,.88,-21.05),Vector3(.25,2.25,4.6))
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.has_meta("mounted_art") and not w.watch.board.is_ancestor_of(mesh):
   verify.call(not board_bounds.intersects(mesh.global_transform*mesh.get_aabb()),"Another mounted notice overlaps the photo board: "+str(mesh.get_path()))
 game._new_shift();game.intro.skip();game.player.active=false
 verify.call(game.intro.floor_number==1 and game.world.passages.floor_number==1,"A fresh shift retains the previous floor")
