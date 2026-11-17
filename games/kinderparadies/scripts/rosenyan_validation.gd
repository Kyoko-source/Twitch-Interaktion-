extends RefCounted
# Creator plushies (4.5.0 Rosenyan, 4.6.0 einsmarello, 4.7.0 Hissybusa and Jule_heartbeat): present, carryable, voiced,
# credited and, since 4.7.0, resting on a real surface at their own spot in the venue.

const COMMENTS:={"rosenyan":["uhh RosenyanVT. Mehr Cozyness geht nicht"],"einsmarello":["Oh, einsmarello. Mit Rotkohl. Peak Gesang, ehrlich."],"hissybusa":["Hissybusa. Brüllt einen Dino an und verliert trotzdem. Chaos auf zwei Plüschbeinen."],"jule":["Jule_heartbeat mit schlafender Katze. Pssst, die beiden haben schon Feierabend."]}
const VOICE_SECONDS:={"rosenyan":[.8,1.6],"einsmarello":[3.4,4.4],"hissybusa":[5.0,6.0],"jule":[2.5,3.5]}
const AREAS:={"rosenyan":"party","einsmarello":"lookout","hissybusa":"bench","jule":"cinema"}

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
  # Rests on a real surface: something solid right under the seat, nothing inside the body.
  var space: PhysicsDirectSpaceState3D=plush.get_world_3d().direct_space_state
  var down:=PhysicsRayQueryParameters3D.create(plush.global_position,plush.global_position-Vector3(0,.6,0),1);down.exclude=[plush.get_rid()]
  var floor_hit:=space.intersect_ray(down)
  var gap: float=plush.global_position.y-CreatorPlush.HALF_HEIGHT-floor_hit.position.y if floor_hit else 9.
  verify.call(gap> -.02 and gap<.04,id+" plush floats or sinks (gap "+str(snappedf(gap,.001))+")")
  var body_query:=PhysicsShapeQueryParameters3D.new();body_query.shape=(plush.get_child(0) as CollisionShape3D).shape
  body_query.transform=plush.global_transform.translated(Vector3(0,.03,0));body_query.collision_mask=1;body_query.exclude=[plush.get_rid()];body_query.margin=.001
  var inside: Array[String]=[]
  for hit in space.intersect_shape(body_query,6):inside.append(str(hit.collider.name))
  verify.call(inside.is_empty(),id+" plush intersects "+str(inside))
  var p: Vector3=plush.global_position
  var where:="party" if p.x>8.5 and p.z< -4 and p.y>.8 else "lookout" if p.y>4. and p.z< -3.4 else "cinema" if p.z< -24.1 and p.x> -6.45 and p.y<1. else "bench" if p.x> -3.4 and p.x< -2.8 and p.y>.7 and p.y<.9 else "?"
  verify.call(where==AREAS[id],id+" plush is not at its spot ("+where+")")
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
  verify.call(voice.volume_db<=-8.,id+" voice is still too loud")
  # Turning while carried: wheel step spins 15 degrees, R spins 45 degrees, Shift tilts; held pose stays.
  var before: Vector3=plush.global_basis.z
  game.player.turn_carried(1.0)
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var spun:=rad_to_deg(Vector2(before.x,before.z).angle_to(Vector2(plush.global_basis.z.x,plush.global_basis.z.z)))
  verify.call(absf(absf(spun)-15.)<2.,id+" plush does not turn by a wheel step (turned "+str(spun)+")")
  game.player.turn_carried(3.0)
  await game.get_tree().physics_frame
  spun=rad_to_deg(Vector2(before.x,before.z).angle_to(Vector2(plush.global_basis.z.x,plush.global_basis.z.z)))
  verify.call(absf(absf(spun)-60.)<3.,id+" plush does not turn by R (turned "+str(spun)+")")
  var up_before: Vector3=plush.global_basis.y
  game.player.turn_carried(2.0,true)
  await game.get_tree().physics_frame
  verify.call(up_before.angle_to(plush.global_basis.y)>deg_to_rad(20.),id+" plush does not tilt with Shift + wheel")
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
 verify.call("HISSYBUSA-PUPPE" in credits and "Hissybusa-Puppe: Charakter" in credits and "twitch.tv/hissybusa" in credits,"Hissybusa is not credited for his plush")
 verify.call("JULE_HEARTBEAT-PUPPE" in credits and "Jule_heartbeat-Puppe: Charakter" in credits and "twitch.tv/jule_heartbeat" in credits,"Jule_heartbeat is not credited for her plush")
 game._build_world("none");game._resume()
