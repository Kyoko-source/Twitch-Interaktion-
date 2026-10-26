extends RefCounted

func press(game: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 game.state.streak=4;game.state.current="none";game._build_world("none");game._resume();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var paper: Node3D=game.world.archive.items.missing
 # The player stands in the clear aisle in front of the seat, not on its hull.
 game.player.position=Vector3(1.20,.03,-31.90);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(paper.global_position)
 await game.get_tree().physics_frame
 var query:=PhysicsRayQueryParameters3D.create(game.player.camera.global_position,paper.global_position,1);query.exclude=[game.player.get_rid()]
 var old_hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
 verify.call(not old_hit.is_empty() and old_hit.collider.get_meta("movement_hull",false),"Newspaper regression no longer exercises the coarse seat hull")
 verify.call(game._target()=="paper:missing","Standing in the cinema aisle cannot target the newspaper on the cushion")
 game.player.position=Vector3(-.80,.03,-31.90);game.player.camera.look_at(paper.global_position)
 await game.get_tree().physics_frame
 verify.call(game.world.find_children("SeatInteractionSurface*","StaticBody3D",true,false).size()==24,"Accurate interaction surfaces are missing from some cinema seats")
 verify.call(game._target()!="paper:missing","Newspaper can be collected through the solid backrest")
 game.player.position=Vector3(1.15,.03,-31.90);game.player.set_crouch(true);game.player.camera.position.y=.8;game.player.camera.look_at(paper.global_position)
 await game.get_tree().physics_frame
 verify.call(game._target()=="paper:missing","Crouching in front of the cinema seat cannot reach the newspaper")
 game.player.set_crouch(false);game.player.camera.position.y=1.65;game.player.camera.look_at(paper.global_position)
 press(game);await game.get_tree().process_frame
 verify.call("missing" in game.archive.collected and not game.world.archive.items.has("missing"),"E does not collect and hide the actual cinema newspaper")
 game._pause();game.has_session=false;game._continue();game.player.active=false
 verify.call("missing" in game.archive.collected and not game.world.archive.items.has("missing") and game.state.streak==4,"Continue loses the cinema newspaper or respawns it")
 for final_anomaly in ["none","balls_float"]:
  game._new_shift();game.intro.skip();game.player.active=false
  game.archive.collected.append("opening")
  for i in range(12): game.state.decide(game.state.current!="none")
  game.state.current=final_anomaly;game._build_world(final_anomaly);game._resume();game.player.active=false
  var scares: int=game.door_failure.shown
  await PassageChecks.travel(game,final_anomaly!="none")
  verify.call(game.phase=="ending" and game.state.completed and game.state.streak==13,"Thirteenth correct elevator choice restarts instead of ending: "+final_anomaly)
  verify.call(not game.player.active and not game.arrival_pending and not game.wake_pending and game.door_failure.shown==scares,"Normal ending restarts the elevator or triggers death")
  var credits: EndCredits=game.end_credits;credits.tick(1)
  verify.call(credits.word.text=="ENDE 1/2" and credits.snapshot().end_word,"Normal ending omits its numbered end card")
  credits.tick(4)
  verify.call(credits.music.playing and credits.snapshot().stage=="credits" and credits.snapshot().second_end_hint==EndCredits.SECOND_END_HINT,"Normal ending omits music, credits or the requested clue")
  var lines:=credits.roll.find_children("*","Label",true,false)
  verify.call(lines.any(func(line):return line.text==EndCredits.SECOND_END_HINT),"Second-ending clue is absent from the actual credit roll")
  credits.finish_scroll();credits.tick(17)
  verify.call(credits.done and credits.actions.visible and credits.actions.get_node("SecondEndingHint").visible,"Skipping credits hides the second-ending clue or leaves no exit")
  await game.get_tree().create_timer(.15).timeout
  verify.call(game.phase=="ending" and game.state.streak==13,"End 1 starts another shift without a player choice")
  game._main_menu();game._continue()
  verify.call(game.phase=="ending" and game.end_credits.ending_number==1,"Warm continue loses ending 1")
  game._main_menu();game.has_session=false;game._continue()
  verify.call(game.phase=="ending" and game.end_credits.ending_number==1 and game.state.streak==13 and "opening" in game.archive.collected,"Saved completion restarts or loses the finished shift")
 # A completed archive takes precedence even if thirteen rounds are also saved.
 game.archive.creator_access=true;game.archive.unlocked=true;game.archive.ending="complete";game._show_archive_ending();game.end_credits.tick(1)
 verify.call(game.end_credits.word.text=="ENDE 2/2" and game.end_credits.snapshot().second_end_hint=="","Archive ending has the wrong number or the end-1-only clue")
 game.end_credits.tick(4)
 verify.call(game.end_credits.music.playing and game.end_credits.snapshot().stage=="credits","Ending 2 loses the music-box credit roll")
 game._main_menu();game.has_session=false;game._continue()
 verify.call(game.phase=="ending" and game.end_credits.ending_number==2 and game.world.archive.finale.trigger_count==0,"Continue replays the archive scare or prefers ending 1 over ending 2")
 # Older versions allowed starting the archive after thirteen rounds. Preserve
 # an already listened-to recording rather than replacing its armed reveal.
 game.archive.ending="armed";game._save();game._main_menu();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.phase=="play" and game.archive.ending=="armed" and game.state.completed,"Migrating an older thirteen-round save discards its ongoing archive finale")
 game._new_shift();game.intro.skip();game.player.active=false
 verify.call(game.state.streak==0 and not game.state.completed and game.archive.ending=="idle" and game.archive.collected.is_empty(),"Explicitly starting a new shift retains completed progress")
