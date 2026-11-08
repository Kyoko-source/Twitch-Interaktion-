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
 game.player.hands.tick(2.,true)
 verify.call(not b.exit_open,"Parking door opens without the collectible key")
 var key: Node3D=w.details.parking_key
 guard.position=key.global_position+key.global_basis.z*1.25;guard.position.y=0;guard.camera.look_at(key.global_position)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(game._target()=="parking_key","Key cannot be picked up from the centre hook")
 game._unhandled_input(event)
 game.player.hands.tick(2.,true)
 verify.call(game.archive.parking_key_found and not key.visible and b.exit_key_owned,"Picking up key does not unlock door or remove key visual")
 var copy:=ArchiveState.new();verify.call(copy.restore(game.archive.serialize()) and copy.parking_key_found,"Collected parking key is lost on save/reload")
 guard.position=Vector3(-14.4,0,9.4);guard.camera.look_at(Vector3(-15.8,1.3,9.4));await game.get_tree().physics_frame
 game._unhandled_input(event)
 game.player.hands.tick(2.,true)
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
 credits.tick(7.);credits.tick(.05)
 verify.call(credits.snapshot().stage=="drive" and is_instance_valid(credits.drive) and credits.drive.running and not credits.escape_audio.playing and not credits.music.playing,"Secret ending skips the drive home after the title")
 var drive: SecretDrive=credits.drive
 verify.call(drive.camera.current and (not is_instance_valid(game.world) or not game.world.visible) and drive.engine.playing,"Drive home does not take over the view and engine sound")
 var seen:={}
 while is_instance_valid(credits.drive) and not credits.drive_done:
  credits.tick(.05)
  if not is_instance_valid(credits.drive) or credits.drive_done:break
  var d: Dictionary=credits.drive.snapshot()
  if d.clock>SecretDrive.SHOUT_AT+1. and d.clock<SecretDrive.SHOUT_FALL and not seen.has("shout"):
   seen.shout=d.line==AfterPlayLanguage.t(SecretDrive.LINE) and d.typed==credits.drive.shout.glyphs.size() and credits.drive.shout.visible and credits.drive.shout.shake>3. and credits.drive.voice.playing
  if d.clock>SecretDrive.SHOUT_FALL+1.5 and not seen.has("fallen"):seen.fallen=d.dropped==credits.drive.shout.glyphs.size() and not credits.drive.shout.visible
  if d.clock<SecretDrive.REVEAL_AT-.2 and d.kids_visible:seen.early=true
  if d.clock>SecretDrive.LOOK_AT+SecretDrive.LOOK_TIME and not seen.has("mirror"):seen.mirror=d.looking_up>.99
  if d.clock>SecretDrive.REVEAL_AT+.1 and d.clock<SecretDrive.LUNGE_AT and not seen.has("kids"):seen.kids=d.kids_visible
  if d.clock>SecretDrive.LUNGE_AT+SecretDrive.LUNGE_TIME and d.clock<SecretDrive.CUT_AT and not seen.has("lunge"):
   var girl_face:=credits.drive.girl_head.global_position.distance_to(credits.drive.camera.global_position)
   seen.lunge=d.lunged and d.shriek and girl_face<.45
  if d.cut and not seen.has("cut"):seen.cut=not d.shriek and credits.drive.shade.color.a>=.99
 verify.call(seen.get("shout",false),"Red screamed line is missing, incomplete, still or silent")
 verify.call(seen.get("fallen",false),"Screamed letters do not fall out of the subtitle")
 verify.call(not seen.has("early"),"Back-seat children are visible before the mirror reveal")
 verify.call(seen.get("mirror",false) and seen.get("kids",false),"Driver never looks up to the mirror or the children never appear")
 verify.call(seen.get("lunge",false),"Child does not lunge shrieking into the driver's face")
 verify.call(seen.get("cut",false),"Jumpscare does not hard-cut to black and silence")
 credits.tick(.05);credits.tick(.05)
 verify.call(credits.snapshot().stage=="credits" and credits.music.playing and game.get_viewport().get_camera_3d()!=drive.camera,"Credits do not follow the drive home")
 await credits.wait_prepared()
 game._main_menu();game.has_session=false;game._continue()
 verify.call(game.phase=="ending" and game.end_credits.ending_number==3,"Continue loses a completed secret ending")
 game._new_shift();game.intro.skip();verify.call(not game.secret_ending and game.phase=="play" and game.state.streak==0,"New shift retains the secret ending")
 # Secret exit is additional; both numbered story endings keep their titles.
 for number in [1,2]:
  game._show_ending(number);verify.call(game.end_credits.end_title()=="ENDE %d/3"%number,"Secret ending renumbers a story ending")
 game._new_shift();game.intro.skip()
