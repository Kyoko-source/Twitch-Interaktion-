extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var guard: NightGuard=game.player
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(w.arrival_design.parts>220,"Corridor/entrance construction detail pass did not build")
 verify.call(w.arrival_design.wall_materials>=5,"Architectural plaster was not reworked across rooms")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Accidental design intersection: "+JSON.stringify(layout))
 # Regression must actually detect the photographed shelf/dispenser overlap.
 var shelves: Array=w.props.RoomDressing.get_children().filter(func(n):return n.get_meta("stocked_shelf",false))
 var shelf: Node3D=shelves[0];var old:=shelf.global_transform
 shelf.global_position=w.life.snack.global_position
 verify.call(not SceneAudit.placement(w).furniture.is_empty(),"Furniture overlap audit silently ignores the snackbar regression")
 shelf.global_transform=old
 verify.call(w.details.find_child("ReceptionCoatRail",true,false)==null and w.backstage.exit_root.find_child("ReceptionCoatRail",true,false)!=null,"Existing cloakroom was not relocated into the entrance")
 var remote: Node3D=w.film.get_node("FlushProjectorLabel")
 for panel in w.revamp.get_node("CinemaWallRestoration").get_children():
  if panel is MeshInstance3D and panel.get_meta("new_acoustic_panel",false):
   verify.call(not (panel.global_transform*panel.get_aabb()).intersects(AABB(remote.global_position-Vector3(.1,.14,.37),Vector3(.2,.28,.74))),"Cinema remote label still passes through an absorber")
 var indoor_rain:=false
 for index in range(w.graphics.exterior.rain.multimesh.instance_count):
  var drop:=w.graphics.exterior.rain.multimesh.get_instance_transform(index).origin
  indoor_rain=indoor_rain or (drop.x< -6.15 and drop.z> -7.0)
 verify.call(not indoor_rain,"Exterior rain falls inside the entrance or through its awning")
 verify.call(w.arrival_design.clear_pose(Vector3(-13.2,0,9.4)) and not w.arrival_design.clear_pose(w.backstage.exit_root.to_global(Vector3(-.94,0,-3.0))),"Continue can embed a pre-update saved guard in the new cloakroom bench")
 var b:=w.backstage
 guard.position=Vector3(-8.8,0,9.4);guard.rotation.y=PI/2;guard.velocity=Vector3.ZERO;guard.active=true;Input.action_press("forward")
 for frame in range(100):await game.get_tree().physics_frame
 Input.action_release("forward");guard.active=false
 verify.call(guard.position.x< -12.5 and game.phase=="play","Main entrance traversal failed at "+str(guard.position))
 guard.position=Vector3(-14.4,0,9.4);guard.velocity=Vector3.ZERO;guard.active=true;Input.action_press("forward")
 for frame in range(45):await game.get_tree().physics_frame
 Input.action_release("forward");guard.active=false
 verify.call(guard.position.x> -15.6 and not game.secret_ending,"Closed glass door can be walked through or triggers the ending early")
 guard.position=Vector3(-14.4,0,9.4);guard.camera.look_at(Vector3(-15.8,1.3,9.4));await game.get_tree().physics_frame
 verify.call(game._target()=="delivery_exit","Glass door cannot be opened with E")
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)
 for frame in range(75):await game.get_tree().physics_frame
 verify.call(b.exit_open and b.exit_leaf.rotation.y>1.45 and game.phase=="play","Opening the glass door fails or ends the game before stepping outside")
 guard.active=true;guard.rotation.y=PI/2;Input.action_press("forward")
 for frame in range(100):
  await game.get_tree().physics_frame
  if game.phase=="ending":break
 Input.action_release("forward")
 verify.call(game.phase=="ending" and game.secret_ending and not guard.active,"Walking onto the actual parking lot does not end the shift")
 if game.phase!="ending":return
 var credits: EndCredits=game.end_credits
 verify.call(credits.ending_number==3 and credits.end_title()=="Geheimes Ende" and credits.secret_line.text==EndCredits.SECRET_LINE,"Secret ending title or exact requested line is missing")
 credits.tick(.9);await game.get_tree().process_frame
 verify.call(credits.black.color.a>=.99 and credits.escape_audio.playing and credits.word.modulate.a==0,"Car must start under black before the title appears")
 credits.tick(2.2);verify.call(credits.word.modulate.a>.9 and credits.secret_line.modulate.a>.9,"Secret ending text never becomes visible")
 credits.tick(7.);verify.call(credits.snapshot().stage=="credits" and credits.music.playing and not credits.escape_audio.playing,"Secret ending omits credits or overlaps engine and credit music")
 await credits.wait_prepared()
 game._main_menu();game.has_session=false;game._continue()
 verify.call(game.phase=="ending" and game.end_credits.ending_number==3,"Continue loses a completed secret ending")
 game._new_shift();game.intro.skip();verify.call(not game.secret_ending and game.phase=="play" and game.state.streak==0,"New shift retains the secret ending")
 # Secret exit is additional; both numbered story endings keep their titles.
 for number in [1,2]:
  game._show_ending(number);verify.call(game.end_credits.end_title()=="ENDE %d/2"%number,"Secret ending renumbers a story ending")
 game._new_shift();game.intro.skip()
