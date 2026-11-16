extends RefCounted
# Rosenyan plush (4.5.0): present, carryable, voiced and credited.

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume()
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var plush: NightProp=game.world.atmosphere.find_child("RosenyanPlush",true,false)
 verify.call(plush!=null and plush.title==RosenyanPlush.TITLE and plush in game.world.atmosphere.loose,"Rosenyan plush is missing from the play corner")
 if not plush:return
 var meshes: Array=plush.find_children("*","MeshInstance3D",true,false)
 var triangles:=0
 for mesh: MeshInstance3D in meshes:
  for s in range(mesh.mesh.get_surface_count()):triangles+=mesh.mesh.surface_get_array_index_len(s)/3
 verify.call(triangles>20000,"Rosenyan plush model did not load")
 var voice: AudioStreamPlayer3D=plush.get_node("Voice")
 verify.call(voice.stream!=null and voice.stream.get_length()>.8 and voice.stream.get_length()<1.6,"Rosenyan voice line missing or not the short cut")
 verify.call(plush.impact.stream.resource_path.ends_with("impact-cloth.wav"),"Rosenyan plush does not sound like cloth")
 # Look at her and pick her up with the normal grab action.
 game.settings.subtitles=true;game.dialogue.reset()
 game.player.position=plush.global_position+Vector3(1.1,-.2,0);game.player.velocity=Vector3.ZERO
 game.player.look_at(plush.global_position*Vector3(1,0,1)+Vector3(0,game.player.global_position.y,0),Vector3.UP)
 game.player.camera.look_at(plush.global_position,Vector3.UP)
 await game.get_tree().physics_frame
 verify.call(game.player.prop_target()==plush,"Rosenyan plush cannot be targeted for pickup")
 game.player.grab_prop()
 verify.call(game.player.carried==plush and voice.playing,"Picking up the plush does not play \"I am defeated\"")
 verify.call("rosenyan" in game.dialogue.pending or game.dialogue.current=="rosenyan","Picking up the plush does not show the RosenyanVT subtitle")
 var lines: Array=game.dialogue.catalog["rosenyan"].de
 verify.call(lines==["uhh RosenyanVT. Mehr Cozyness geht nicht"],"RosenyanVT subtitle text changed")
 game.player.drop_prop();voice.stop()
 # Second pickup in the same shift: voice again, subtitle again (but never queued twice).
 game.dialogue.pending.clear();game.dialogue.current=""
 game.player.camera.look_at(plush.global_position,Vector3.UP);await game.get_tree().physics_frame
 game.player.grab_prop();game.player.drop_prop();game.player.grab_prop()
 verify.call(voice.playing and game.dialogue.pending.count("rosenyan")<=1,"Repeated pickups break the voice or flood the subtitles")
 game.player.drop_prop()
 var credits: String=FileAccess.get_file_as_string("res://scripts/night_menus.gd")+FileAccess.get_file_as_string("res://scripts/end_credits.gd")
 verify.call("RosenyanVT" in credits and "twitch.tv/rosenyanvt" in credits,"RosenyanVT is not credited in menu and end credits")
 game._build_world("none");game._resume()
