extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 var creator:=ArchiveState.new()
 verify.call(not creator.try_code("6428") and not creator.try_code("0711"),"Normal or incorrect creator code bypasses the newspapers")
 verify.call(creator.try_code("0712") and creator.unlocked and creator.creator_access and creator.collected.is_empty(),"0712 does not unlock without any newspapers")
 var restored:=ArchiveState.new()
 verify.call(restored.restore(JSON.parse_string(JSON.stringify(creator.serialize()))) and restored.creator_access and restored.unlocked and restored.collected.is_empty(),"Creator access is lost when restoring a save")
 var corrupt:=creator.serialize();corrupt.creator_access="true"
 verify.call(not restored.restore(corrupt),"Malformed creator-access value is accepted")
 corrupt=creator.serialize();corrupt.recording_position=-1
 verify.call(not restored.restore(corrupt),"Negative narration position is accepted")
 var legacy:={"version":1,"collected":["note","opening","missing","coverup","closure"],"unlocked":true}
 verify.call(restored.restore(legacy) and restored.unlocked and not restored.creator_access and restored.ending=="idle","Existing genuine archive progress no longer restores")
 game._new_shift();game.intro.skip();game._open_archive_lock();game.archive_input="0712";game._submit_archive_code()
 verify.call(game.phase=="play" and game.archive.unlocked and game.archive.collected.is_empty(),"Actual lock UI rejects the creator code")
 game.world.archive.tick(2,true)
 game.player.position=Vector3(-11.3,0,-9.9);game.player.rotation=Vector3.ZERO;game.player.camera.look_at(ArchiveFinale.RECORDER+Vector3(0,.07,0))
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(game._target()=="archive_recording","The visible recorder cannot be targeted with E")
 var finale: ArchiveFinale=game.world.archive.finale
 verify.call(finale.duration>279 and finale.duration<281 and finale.snapshot().skeleton_meshes>=2 and finale.snapshot().chains==4,"Narration length, skeletal remains or restraints are missing")
 game.player.camera.look_at(LostArchive.ENTRY+Vector3(0,1.5,0));finale.tick(.1,true)
 verify.call(game.phase=="play" and game.archive.ending=="idle","Looking at the door before listening triggers the ending")
 game.player.position=Vector3(-9.8,0,-9.9);finale.interact()
 verify.call(game.archive.ending=="idle" and not game.world.archive.playback_locked(),"Starting the recorder from the hallway locks the listener outside")
 game.player.position=Vector3(-11.3,0,-9.9);finale.interact();await game.get_tree().create_timer(.15).timeout
 verify.call(game.archive.ending=="recording" and finale.started,"Recorder does not start its actual media stream")
 verify.call(game.world.archive.playback_locked() and is_zero_approx(game.world.archive.leaf.rotation.y),"The actual archive door stays open while the recording plays")
 game.world.archive.open();game._open_archive_lock()
 verify.call(game.phase=="play" and is_zero_approx(game.world.archive.target_angle),"Interacting with the lock bypasses the recording barrier")
 for crouched in [false,true]:
  game.player.set_crouch(crouched);game.player.position=Vector3(-11.0,0,-9.9);game.player.velocity=Vector3.ZERO;game.player.rotation.y=-PI/2;game.player.camera.rotation=Vector3.ZERO;Input.action_press("forward")
  for frame in range(45): await game.get_tree().physics_frame
  Input.action_release("forward")
  verify.call(game.player.position.x< -10.45,"The guard can leave during the recording, crouching="+str(crouched))
 game.player.set_crouch(false);game.player.position=Vector3(-11.3,0,-9.9);game.player.velocity=Vector3.ZERO
 game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame
 var position: float=game.archive.recording_position
 await game.get_tree().create_timer(.15).timeout
 verify.call(finale.voice.stream_paused and is_equal_approx(game.archive.recording_position,position),"Narration advances while the game is paused")
 game._resume();finale.voice.seek(117.0);await game.get_tree().create_timer(.16).timeout;game._pause();game.has_session=false;game._continue()
 verify.call(game.archive.ending=="recording" and game.archive.recording_position>116 and game.archive.recording_position<120,"Narration save loses its playback position: "+JSON.stringify(game.archive.serialize()))
 finale=game.world.archive.finale;await game.get_tree().create_timer(.15).timeout
 verify.call(finale.started and finale.voice.get_playback_position()>116,"Continue restarts the recording instead of resuming: "+JSON.stringify(finale.snapshot()))
 verify.call(game.world.archive.playback_locked() and is_zero_approx(game.world.archive.leaf.rotation.y),"Loading a playing recording unlocks its door")
 game.player.position=Vector3(-8.7,0,-9.9);game._pause();game.has_session=false;game._continue()
 await game.get_tree().create_timer(.15).timeout;finale=game.world.archive.finale
 verify.call(game.world.archive.safe_pose(game.player.position) and game.player.position.x<LostArchive.ENTRY.x-.3 and finale.started,"An older outside-recording save strands its listener outside the locked room")
 game.player.position=Vector3(-11.3,0,-9.9);game.player.camera.look_at(LostArchive.ENTRY+Vector3(0,1.5,0))
 finale.voice.seek(finale.duration-.08)
 await game.get_tree().create_timer(.3).timeout
 verify.call(game.archive.ending=="armed" and game.phase=="play" and finale.trigger_count==0,"Media end does not arm the reveal or scares before the player turns")
 verify.call(not game.world.archive.playback_locked() and game.world.archive.target_angle< -1.7,"Finishing the recording fails to release the archive door")
 game.world.archive.tick(2,true);await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(-11.3,.9,-9.9),Vector3(-9.5,.9,-9.9),1);ray.exclude=[game.player.get_rid()]
 verify.call(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"The released archive door leaves an invisible exit barrier")
 game._pause();finale.tick(.2,false);verify.call(game.phase=="pause" and finale.trigger_count==0,"Ending reveal triggers in the pause menu")
 game._resume();game.player.camera.look_at(Vector3(-14,1.3,-9.9));finale.tick(.1,true)
 verify.call(finale.looked_away and game.phase=="play","The finale cannot register the turn away from the door")
 game.player.camera.look_at(LostArchive.ENTRY+Vector3(0,1.5,0));finale.tick(.1,true)
 verify.call(game.phase=="archive_scare" and game.archive.ending=="complete" and finale.trigger_count==1 and game.door_failure.archive_mode,"Turning back fails to launch the chef scare exactly once")
 game.door_failure.tick(.2)
 verify.call(game.door_failure.audio.stream.resource_path.ends_with("cook-scream.wav") and game.door_failure.running,"Chef reveal has no dedicated vocal scream")
 game.door_failure.tick(1.0);await game.get_tree().process_frame
 verify.call(game.phase=="ending" and is_instance_valid(game.end_credits),"Chef scare fails to enter the black ending")
 game.end_credits.tick(1)
 verify.call(game.end_credits.snapshot().end_word and game.end_credits.word.text=="ENDE","The ending omits the centred ENDE title")
 game.end_credits.tick(4)
 verify.call(game.end_credits.snapshot().stage=="credits" and EndCredits.AUTHOR=="Kyoko" and EndCredits.IDEA=="einsmarello" and EndCredits.TESTERS==["einsmarello","__jerry__","gingerbread","Mozart"],"Rolling credits omit or misspell a requested contributor")
 game.end_credits.finish_scroll();verify.call(game.end_credits.done and game.end_credits.actions.visible,"Credits leave no way to return to the menu or start again")
 game._main_menu();game.has_session=false;game._continue()
 verify.call(game.phase=="ending" and game.world.archive.finale.trigger_count==0,"Continuing a completed finale replays the scare")
 game._new_shift();game.intro.skip()
 verify.call(not game.archive.unlocked and not game.archive.creator_access and game.archive.ending=="idle" and game.archive.recording_position==0,"New shift retains creator access or the prior ending")
