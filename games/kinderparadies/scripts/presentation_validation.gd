extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 verify.call(ProjectSettings.get_setting("display/window/size/viewport_width")==1920 and ProjectSettings.get_setting("display/window/size/viewport_height")==1080,"The logical screen is not 1920 x 1080")
 verify.call(ProjectSettings.get_setting("display/window/size/window_width_override")==1600 and ProjectSettings.get_setting("display/window/size/window_height_override")==900 and ProjectSettings.get_setting("display/window/stretch/aspect")=="keep","Window proportions stretch instead of preserving 16:9")
 game._new_shift();game.intro.skip()
 var fresco:=game.world.find_child("TheFourEmptyChairs",true,false) as Node3D
 verify.call(fresco.global_position.distance_to(Vector3(13.3,2.85,1.485))<.01 and fresco.global_basis.z.dot(Vector3.FORWARD)>.99,"Party fresco is not mounted on the free wall to the right")
 var visitor: Vector3=NightTerrors.SCENARIOS.party_portrait.p
 verify.call(absf(visitor.x-fresco.global_position.x)<.1 and visitor.z<fresco.global_position.z and visitor.z>0,"Portrait visitor was left behind on the old wall")
 if game.world.native_art:
  var cabinet: Node3D=game.world.native_art.power_box
  var bounds:=AABB();var first:=true
  for mesh in cabinet.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
  var doorway:=AABB(Vector3(-10.55,0,-6.2),Vector3(.7,2.5,1.65))
  verify.call(not first and not bounds.intersects(doorway) and bounds.end.x< -15.4 and bounds.position.x> -16.5,"Native power cabinet obstructs the server-room passage or penetrates its rear wall")
 game._main_menu();await game.get_tree().process_frame;await game.get_tree().process_frame
 var screen:=Rect2(Vector2.ZERO,Vector2(1920,1080))
 for button in game.menu.find_children("*","Button",true,false):
  if button.is_visible_in_tree(): verify.call(screen.encloses(button.get_global_rect()),"Main-menu control is clipped at 16:9: "+button.text)
 var gain:=AudioServer.get_bus_volume_db(0)
 game._show_archive_ending();game.end_credits.tick(1)
 verify.call(not game.end_credits.music.playing and game.end_credits.snapshot().end_word,"Credits music starts before the ENDE card")
 game.end_credits.tick(4);await game.get_tree().process_frame;await game.get_tree().process_frame
 var song: AudioStreamPlayer=game.end_credits.music
 verify.call(song.playing and song.stream.resource_path==RoomHorror.MUSIC and (song.stream as AudioStreamMP3).loop,"Credits do not play the actual supplied music-box recording")
 verify.call(is_equal_approx(gain,AudioServer.get_bus_volume_db(0)),"Credits override the player's master volume")
 verify.call(absf(game.end_credits.roll.position.x+game.end_credits.roll.size.x*.5-960)<1,"Credits are not centred in the 16:9 frame")
 game.end_credits.finish_scroll();await game.get_tree().create_timer(.5).timeout
 verify.call(not song.playing,"Skipping the credits leaves music playing")
 game._show_archive_ending();game.end_credits.tick(5);await game.get_tree().process_frame
 song=game.end_credits.music;game._main_menu()
 verify.call(not song.playing,"Leaving the credits leaks music into the menu")
 game._new_shift();game.intro.skip()
