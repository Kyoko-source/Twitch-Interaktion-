extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._main_menu();await game.get_tree().process_frame
 verify.call(game.menu.find_child("CinematicMenuBackground",true,false) is ColorRect and game.menu_camera.current,"The main menu does not show the actual 3D scene")
 verify.call(game.menu_music.playing and game.menu_music.stream.data==(load("res://assets/menu/abandoned-arcade.mp3") as AudioStreamMP3).data and game.menu_music.stream.loop,"Abandoned Arcade does not play and loop in the menu")
 verify.call(game.menu_music.bus=="Master","Menu music incorrectly depends on room ambience")
 var previous_rect:=Rect2()
 for button in game.menu.find_children("*","Button",true,false):
  var rect: Rect2=button.get_global_rect()
  verify.call(Rect2(0,0,1920,1080).encloses(rect) and not (previous_rect.has_area() and previous_rect.intersects(rect)),"Main-menu control clips or overlaps: "+button.text+" "+str(rect)+" previous "+str(previous_rect))
  previous_rect=rect
 var saved_music: float=game.settings.menu_music
 game.settings.menu_music=0.0;game._apply_settings();verify.call(game.menu_music.volume_db<=-79,"Menu-music setting fails to mute its actual player")
 game.settings.menu_music=saved_music;game._apply_settings()
 game._new_shift();game.intro.skip();await game.get_tree().physics_frame
 verify.call(not game.menu_music.playing,"Menu music continues under gameplay or intro")
 var layout:=SceneAudit.placement(game.world)
 verify.call(layout.doors.is_empty(),"Decorative geometry crosses a real door opening: "+str(layout.doors))
 verify.call(layout.art.is_empty(),"Wall pictures overlap: "+str(layout.art))
 verify.call(layout.furniture.is_empty(),"Freestanding furniture intersects an architectural wall: "+str(layout.furniture))
 game.archive.try_code("0712");game.world.archive.open();game.world.archive.tick(3,true)
 layout=SceneAudit.placement(game.world)
 verify.call(layout.doors.is_empty(),"The open archive doorway is obstructed: "+str(layout.doors))
 var memories: ArchiveMemories=game.memories
 verify.call(memories.shots.size()==11,"Narration is missing memory scenes")
 var last:=-1.0
 for i in range(memories.shots.size()):
  var shot: Dictionary=memories.shots[i]
  verify.call(float(shot.start)>last and ResourceLoader.exists("res://assets/presentation-v250/"+str(shot.image)),"Missing or misordered memory image: "+str(shot))
  verify.call(memories.index_at(float(shot.start)+.1)==i,"Narration cue chooses the wrong image at "+str(shot.start))
  last=float(shot.start)
 game.player.position=Vector3(-11.3,0,-9.9);game.player.camera.look_at(ArchiveFinale.RECORDER)
 var finale: ArchiveFinale=game.world.archive.finale
 finale.interact();await game.get_tree().create_timer(.15).timeout
 verify.call(memories.visible and not game.player.active and not game.hud.visible and game.world.archive.playback_locked(),"Narration does not enter the locked, immersive memory sequence")
 finale.voice.seek(135.0);await game.get_tree().create_timer(.2).timeout
 verify.call(memories.shot_index==5 and memories.current.texture!=null and absf(memories.audio_position-game.archive.recording_position)<.1,"Displayed memory is not synchronized with actual audio playback")
 game._pause();await game.get_tree().process_frame
 var frozen:=memories.snapshot();var position: Vector3=game.player.position
 Input.action_press("forward");await game.get_tree().create_timer(.2).timeout;Input.action_release("forward")
 verify.call(finale.voice.stream_paused and is_equal_approx(memories.audio_position,frozen.position) and is_equal_approx(memories.blend,frozen.blend) and game.player.position.is_equal_approx(position),"Pause fails to freeze narration, memory transition or movement")
 game._resume();verify.call(not game.player.active,"Resuming a memory allows walking away from the cutscene")
 game._pause();game.has_session=false;game._continue();await game.get_tree().create_timer(.2).timeout
 verify.call(game.memories.visible and game.memories.shot_index==5 and game.archive.recording_position>=135 and game.archive.recording_position<140,"Loading a saved narration restarts or loses its visual cue")
 finale=game.world.archive.finale;finale.voice.seek(finale.duration-.07)
 await game.get_tree().create_timer(.25).timeout
 verify.call(game.archive.ending=="armed" and not memories.visible and game.player.active and game.hud.visible,"Finished narration fails to restore the actual archive and controls")
 game._new_shift();game.intro.skip()
