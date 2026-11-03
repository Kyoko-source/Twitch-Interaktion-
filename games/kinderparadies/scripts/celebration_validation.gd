extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false
 g.state.decide(false);g.state.current="balls_float";g._build_world("balls_float");g._resume();g.player.active=false
 var previous_round: int=g.state.streak
 g.phase="code";g.archive_input=PatrolPartyOutro.TEST_CODE;g._submit_archive_code()
 verify.call(g.phase=="ending" and g.end_credits.ending_number==1 and g.archive_input.is_empty(),"Preview code does not open ending 1")
 verify.call(g.state.streak==previous_round and not g.state.completed and not g.archive.unlocked,"Preview code changes patrol progress or unlocks the archive")
 var credits: EndCredits=g.end_credits
 credits.tick(5)
 verify.call(credits.music.playing and credits.afterglow==null,"Celebration begins before the credits")
 await credits.wait_prepared()
 verify.call(credits.prepared_afterglow is PatrolPartyOutro and not g.world.party.enabled,"Ending 1 does not prepare a silent party scene")
 Input.action_press("jump");credits.finish_scroll()
 var party: PatrolPartyOutro=credits.afterglow
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(party.started and g.world.party.enabled and g.world.party.audio.playing,"Party song does not start after the credits")
 verify.call(not credits.music.playing and not g.menu_music.playing and not g.world.room_horror.music.playing,"Credits, menu or music-box audio overlaps the party")
 verify.call(g.world.party.audio.bus==&"Master" and g.world.party.audio.panning_strength==0,"Inactive player location muffles the cinematic music")
 verify.call(party.actors.size()==5 and party.minis.size()==5 and not party.bunny.is_empty() and not party.horse.is_empty(),"Celebration cast is incomplete")
 verify.call(g.world.props.party_table.is_visible_in_tree() and g.world.props.chairs.is_visible_in_tree() and g.world.backstage.throne.is_visible_in_tree(),"The original party furniture is hidden during the celebration")
 verify.call(_all_triangles_referenced(party),"Merging costume details drops unindexed sleeve or finger triangles")
 verify.call(is_instance_valid(party.cola) and party.cola.is_inside_tree(),"Rabbit has no attached cola bottle")
 var before:=party.camera.position;var arm_before: Vector3=party.actors[0].left.rotation
 credits.tick(4)
 verify.call(not credits.done,"Holding the credit-skip key also skips the new scene")
 verify.call(party.camera.position.distance_to(before)>.2 and party.actors[0].left.rotation.distance_to(arm_before)>.05,"Camera or articulated dancer remains static")
 verify.call(party.horse.skeleton.get_bone_pose_position(17).distance_to(party.horse.skeleton.get_bone_pose_position(0))>1.5,"Skinned horse neck collapses because bone poses omit their rest positions")
 verify.call(credits.word.visible and credits.word.text=="Ende 1/3","Numbered title is absent from the centre of the party scene")
 verify.call(not credits.music.playing and not g.world.room_horror.music.playing,"Credits music restarts during the celebration")
 var camera_clear:=true
 var furniture_clear:=true
 var tops: Array[AABB]=[AABB(Vector3(9.15,.72,-8.55),Vector3(2.1,.12,3.1)),AABB(Vector3(13.3,.56,-8.225),Vector3(3.4,.12,1.25))]
 for sample in range(96):
  party.clock=sample*.5;party._pose(0.)
  for actor in party.actors+[party.bunny]:
   for mesh in CelebrationCast.meshes(actor.root):
    if mesh.is_visible_in_tree() and (mesh.global_transform*mesh.get_aabb()).grow(.025).has_point(party.camera.global_position):camera_clear=false
    if mesh.is_visible_in_tree():
     for top in tops:
      if (mesh.global_transform*mesh.get_aabb()).intersects(top):furniture_clear=false
 verify.call(camera_clear,"Dolly intersects a dancer between camera keys")
 verify.call(furniture_clear,"A dancer intersects an original party tabletop during the camera ride")
 party.clock=4.
 Input.action_release("jump");credits.tick(.05)
 var original_env: Environment=party.original_environment
 party.clock=PatrolPartyOutro.DURATION-.1;credits.tick(.2)
 await g.get_tree().process_frame
 verify.call(credits.done and credits.actions.visible and not g.world.party.audio.playing,"Completed party leaves no menu or keeps playing music")
 verify.call(g.world.environment.environment==original_env and not is_instance_valid(party.root),"Celebration dressing leaks into the normal venue")
 g._main_menu();g._continue();g.player.active=false
 verify.call(g.phase=="play" and g.state.streak==previous_round and g.world.current==g.state.current,"Continue resumes the preview venue instead of the saved patrol")
 g._new_shift();g.intro.skip();g.player.active=false
 verify.call(g.state.streak==0 and g.world.current=="none" and not g.world.party.enabled,"New shift retains the celebration")
 for number in [2,3]:
  g._show_ending(number);var other: EndCredits=g.end_credits;other.tick(other.title_length()+1.)
  await other.wait_prepared();other.finish_scroll()
  verify.call(other.afterglow is EndingAfterglow and other.music.playing and not g.world.party.enabled,"Celebration incorrectly replaces ending "+str(number))
  other.tick(17);g._main_menu()
 g._new_shift();g.intro.skip();g.player.active=false

func _all_triangles_referenced(party: PatrolPartyOutro) -> bool:
 for actor in party.actors+[party.horse]:
  for mesh in CelebrationCast.meshes(actor.root):
   for surface in range(mesh.mesh.get_surface_count()):
    var arrays: Array=mesh.mesh.surface_get_arrays(surface)
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():continue
    var all_bounds:=AABB(vertices[0],Vector3.ZERO);var drawn_bounds:=AABB(vertices[indices[0]],Vector3.ZERO)
    for vertex in vertices:all_bounds=all_bounds.expand(vertex)
    for index in indices:drawn_bounds=drawn_bounds.expand(vertices[index])
    if all_bounds.position.distance_to(drawn_bounds.position)>.002 or all_bounds.size.distance_to(drawn_bounds.size)>.002:return false
 return true
