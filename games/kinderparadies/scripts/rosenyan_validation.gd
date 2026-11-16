extends RefCounted
# Creator plushies (4.5.0 Rosenyan, 4.6.0 einsmarello): present, carryable, voiced and credited.

const COMMENTS:={"rosenyan":["uhh RosenyanVT. Mehr Cozyness geht nicht"],"einsmarello":["Oh, einsmarello. Mit Rotkohl. Peak Gesang, ehrlich."]}
const VOICE_SECONDS:={"rosenyan":[.8,1.6],"einsmarello":[3.4,4.4]}

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game._build_world("none");game._resume()
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 game.settings.subtitles=true
 for id in CreatorPlush.PLUSHES:
  var cfg: Dictionary=CreatorPlush.PLUSHES[id]
  var plush: NightProp=game.world.atmosphere.find_child(cfg.node,true,false)
  verify.call(plush!=null and plush.title==cfg.title and plush in game.world.atmosphere.loose,id+" plush is missing from the play corner")
  if not plush:continue
  var triangles:=0
  for mesh: MeshInstance3D in plush.find_children("*","MeshInstance3D",true,false):
   for s in range(mesh.mesh.get_surface_count()):triangles+=mesh.mesh.surface_get_array_index_len(s)/3
  verify.call(triangles>20000,id+" plush model did not load")
  var voice: AudioStreamPlayer3D=plush.get_node("Voice")
  var length: float=voice.stream.get_length() if voice.stream else 0.
  verify.call(length>VOICE_SECONDS[id][0] and length<VOICE_SECONDS[id][1],id+" voice line missing or not the short cut")
  verify.call(plush.impact.stream.resource_path.ends_with("impact-cloth.wav"),id+" plush does not sound like cloth")
  verify.call(game.dialogue.catalog[cfg.comment].de==COMMENTS[id],id+" subtitle text changed")
  game.dialogue.reset()
  game.player.position=plush.global_position+Vector3(.9,-.2,.5);game.player.velocity=Vector3.ZERO
  game.player.look_at(Vector3(plush.global_position.x,game.player.global_position.y,plush.global_position.z),Vector3.UP)
  game.player.camera.look_at(plush.global_position,Vector3.UP)
  await game.get_tree().physics_frame
  verify.call(game.player.prop_target()==plush,id+" plush cannot be targeted for pickup")
  game.player.grab_prop()
  verify.call(game.player.carried==plush and voice.playing,"Picking up the "+id+" plush does not play her voice")
  verify.call(cfg.comment in game.dialogue.pending or game.dialogue.current==cfg.comment,"Picking up the "+id+" plush does not show her subtitle")
  game.player.drop_prop();voice.stop()
  # Second pickup in the same shift: voice again, subtitle again (never queued twice).
  game.dialogue.pending.clear();game.dialogue.current=""
  game.player.camera.look_at(plush.global_position,Vector3.UP);await game.get_tree().physics_frame
  game.player.grab_prop();game.player.drop_prop();game.player.grab_prop()
  verify.call(voice.playing and game.dialogue.pending.count(cfg.comment)<=1,"Repeated pickups of "+id+" break the voice or flood the subtitles")
  game.player.drop_prop();voice.stop()
  game._build_world("none");game._resume();await game.get_tree().physics_frame
 var credits: String=FileAccess.get_file_as_string("res://scripts/night_menus.gd")+FileAccess.get_file_as_string("res://scripts/end_credits.gd")
 verify.call("RosenyanVT" in credits and "twitch.tv/rosenyanvt" in credits,"RosenyanVT is not credited in menu and end credits")
 verify.call("EINSMARELLO-PUPPE" in credits and "einsmarello-Puppe: Charakter" in credits and "twitch.tv/einsmarello" in credits,"einsmarello is not credited for her plush")
 game._build_world("none");game._resume()
