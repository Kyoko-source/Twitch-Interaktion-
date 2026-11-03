extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false
 var w: PlayWorld=g.world;var guard: NightGuard=g.player;var party: HappylandParty=w.party
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 var placement:=SceneAudit.placement(w)
 verify.call(placement.doors.is_empty() and placement.furniture.is_empty(),"Stereo blocks a doorway or intersects furnishings: "+JSON.stringify(placement))
 verify.call(party.stereo.has_node("LeftSpeaker") and party.stereo.has_node("RightSpeaker"),"Stereo has no pair of physical speakers")
 var menu: MeshInstance3D=w.life.snack.get_node("PartySnackbarMenu")
 var sign_bounds: AABB=menu.global_transform*menu.get_aabb()
 var stereo_bounds: AABB=party.stereo.global_transform*party.stereo.get_meta("furniture_volume")
 verify.call(not Rect2(Vector2(sign_bounds.position.z,sign_bounds.position.y),Vector2(sign_bounds.size.z,sign_bounds.size.y)).intersects(Rect2(Vector2(stereo_bounds.position.z,stereo_bounds.position.y),Vector2(stereo_bounds.size.z,stereo_bounds.size.y))),"Stereo obscures the snackbar menu")
 verify.call(party.audio.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED and party.audio.max_distance==0 and party.audio.panning_strength<.2,"Party song still fades with distance or disappears into one ear")
 verify.call(not party.clear_pose(Vector3(7.4,0,-2.8)) and not party.clear_pose(Vector3(13.7,0,-3.8)) and party.clear_pose(Vector3(13.7,.67,-3.8)),"Old saves can embed the guard in the new stereo or repaired table")
 party.set_enabled(true)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 var record: Dictionary=w.acoustics.records.filter(func(item):return item.source==party.audio)[0]
 for x in [7.95,10.2,13.4,16.5,18.75]:
  for z in [-10.8,-7.,-3.8,.5]:
   var point:=Vector3(x,1.65,z)
   var result:=w.acoustics.solve(party.audio,point,[guard.get_rid()])
   verify.call(result.gain==0 and result.cutoff==18000 and not result.blocked,"Music falls away or is muffled within the party room at "+str(point))
 for point in [Vector3(4,1.65,-8),Vector3(-7.9,1.65,-18),Vector3(17.3,1.65,-15)]:
  var result:=w.acoustics.solve(party.audio,point,[guard.get_rid()])
  verify.call(result.gain< -9 and result.cutoff<5000,"Room-filling music leaks into other rooms without damping at "+str(point))
 guard.position=Vector3(18.5,0,-10.5)
 for i in range(75):w.acoustics.tick(1./60,true,guard)
 verify.call(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(record.bus)))<.1,"Actual music bus remains quiet in the far corner")
 party.evaluate(51,false);verify.call(party.drop and party.vu.any(func(m):return m.emission_energy_multiplier>1),"Drop sync or amplifier meter stopped working")
 g._pause();party.tick(.1,false,true,false);await g.get_tree().physics_frame;verify.call(party.audio.stream_paused,"Stereo ignores pause")
 g._resume();party.tick(.1,true,true,false);verify.call(not party.audio.stream_paused,"Stereo does not resume")
 # Walk into the repaired tabletop from every side. No jump or teleport is
 # used after each approach starts. Then land on the actual top surface.
 var centre:=Vector3(13.7,0,-3.8)
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  guard.position=centre+direction*2;guard.velocity=Vector3.ZERO;guard.rotation.y=atan2(direction.x,direction.z);guard.active=true
  Input.action_press("forward")
  for i in range(45):await g.get_tree().physics_frame
  Input.action_release("forward");guard.active=false
  var gap:=Vector2(guard.position.x-centre.x,guard.position.z-centre.z).length()
  verify.call(gap>1.3 and gap<1.7,"Walking still passes through the round table: "+str(guard.position))
 guard.position=centre+Vector3.UP*1.3;guard.velocity=Vector3.ZERO;guard.active=true
 for i in range(60):await g.get_tree().physics_frame
 guard.active=false
 verify.call(guard.is_on_floor() and absf(guard.position.y-.66)<.035,"Player cannot land on the round tabletop")
 party.set_enabled(false);verify.call(not party.audio.playing and party.vu.all(func(m):return m.emission_energy_multiplier<.1),"Stereo still plays or shows active meters after switching off")
 g._new_shift();g.intro.skip();g.player.active=false
