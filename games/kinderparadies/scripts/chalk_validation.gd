extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._resume();game.player.active=false
 var w: PlayWorld=game.world;var board: ChalkBoard=w.chalk
 board.select_tool(0);board.begin_stroke(Vector2(80,100));board.extend_stroke(Vector2(180,100));board.finish_stroke()
 verify.call(board.paper.get_pixel(130,100).a>.3,"Chalk does not form a continuous handwritten stroke")
 verify.call(board.paper.get_pixel(130,110).a==0,"Chalk escapes the brush footprint")
 var saved:=board.serialize()
 verify.call(not saved.is_empty() and board.restore(saved) and board.paper.get_pixel(130,100).a>.3,"PNG save loses the slate writing")
 var a:=board.paper.get_pixel(130,100).a
 board.select_tool(4);board.begin_stroke(Vector2(130,100));board.finish_stroke()
 verify.call(board.paper.get_pixel(130,100).a==0,"Eraser does not remove chalk")
 board.undo();verify.call(is_equal_approx(board.paper.get_pixel(130,100).a,a),"Undo does not restore erased notes")
 board.clear();verify.call(board.paper.get_pixel(130,100).a==0,"Wipe-clean leaves notes behind")
 board.undo();verify.call(board.paper.get_pixel(130,100).a>.3,"Clear cannot be undone")
 board.begin_stroke(Vector2(200,100));board.extend_stroke(Vector2(-5,100));board.extend_stroke(Vector2(500,100))
 verify.call(not board.drawing and board.paper.get_pixel(350,100).a==0,"Leaving the slate connects an unintended stroke across it")
 verify.call(not board.restore("broken image") and board.paper.get_pixel(130,100).a>.3,"Invalid image destroys an existing note")
 board.finish_stroke();game._save()
 var stored: Dictionary=JSON.parse_string(game._persistent_text(game.SAVE))
 verify.call(stored.get("chalk","")==board.serialize(),"Patrol save omits chalk drawing")
 game._build_world("none");board=game.world.chalk
 verify.call(board.paper.get_pixel(130,100).a>.3,"A new round discards the slate notes")
 game.has_session=false;game._continue();board=game.world.chalk;game.player.active=false
 verify.call(board.paper.get_pixel(130,100).a>.3,"Continue does not restore the saved chalkboard")
 # Use the same physics ray as E-interaction and check the wall occludes it.
 game.player.position=board.to_global(Vector3(0,-1.65,1.7));game.player.rotation.y=-PI/2;game.player.camera.rotation=Vector3.ZERO
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(game._target()=="chalk_board","Slate cannot be reached with the normal interaction ray")
 board.select_tool(0);board.open(game);await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(game.phase=="chalk" and not game.player.active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Drawing fails to release mouse-look or pause movement")
 var canvas:=board.canvas
 verify.call(canvas.size.x>=960 and canvas.size.y>=480,"Drawing surface has no usable area")
 verify.call(canvas.get_parent().get_node("ChalkSlateBackground").size==canvas.size,"Slate background extends past its frame and controls")
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=canvas.get_global_rect().position+Vector2(450,240);down.global_position=down.position;game.get_viewport().push_input(down,true)
 await game.get_tree().process_frame
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=down.position;up.global_position=up.position;game.get_viewport().push_input(up,true)
 await game.get_tree().process_frame
 var pixel:=Vector2(450,240)*Vector2(ChalkBoard.RESOLUTION)/canvas.size
 verify.call(board.paper.get_pixel(floori(pixel.x),floori(pixel.y)).a>0,"Real GUI mouse input does not write on the canvas")
 var esc:=InputEventAction.new();esc.action="pause";esc.pressed=true;game._input(esc)
 verify.call(game.phase=="play" and not board.drawing and not board.sound.playing,"ESC fails to close the chalkboard cleanly")
 game.player.active=false
 AfterPlayLanguage.choose("en");board.open(game);await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(str(game.menu.find_child("ChalkTool0",true,false).text)=="White chalk","Chalk controls are untranslated")
 game._close_chalk();game.player.active=false;AfterPlayLanguage.choose("de")
 # The photograph must have clearance from ALL front/back acoustic panels.
 var photo:=game.world.venue.find_child("CinemaBirthdayPhotograph",true,false) as MeshInstance3D
 var art_bounds:=photo.get_aabb()
 var rect:=Rect2(Vector2(art_bounds.position.x,art_bounds.position.y),Vector2(art_bounds.size.x,art_bounds.size.y)).grow(.065)
 var clear:=true
 for panel in game.world.find_children("*","MeshInstance3D",true,false):
  if not panel.get_meta("cinema_absorber",false):continue
  var bounds: AABB=(photo.global_transform.affine_inverse()*panel.global_transform)*panel.get_aabb()
  if absf(bounds.get_center().z)<.13 and rect.intersects(Rect2(Vector2(bounds.position.x,bounds.position.y),Vector2(bounds.size.x,bounds.size.y))):clear=false
 verify.call(clear,"Cinema absorbers still overlap the framed photograph")
 var layout:=SceneAudit.placement(game.world)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Slate or cinema fix obstructs the venue: "+JSON.stringify(layout))
 game._new_shift();verify.call(game.world.chalk.serialize().is_empty(),"A genuinely new shift does not reset the chalkboard")
