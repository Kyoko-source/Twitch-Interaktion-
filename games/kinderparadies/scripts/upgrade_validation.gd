extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var sound:=w.acoustics;var guard: NightGuard=game.player
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(w.graphics.surfaces>400 and w.graphics.details>600,"Whole-scene surface and architectural pass did not build")
 verify.call(w.graphics.exterior.count>100 and w.graphics.exterior.rain.multimesh.instance_count>=240,"Exterior parking scene or rain is missing")
 verify.call(w.graphics.exterior.get_node("ClosedWindowBarrier").get_child_count()==1,"Window has no fitted closed collider")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(-9,2.2,1.7),Vector3(-11,2.2,1.7),1);ray.exclude=[guard.get_rid()]
 var hit:=w.get_world_3d().direct_space_state.intersect_ray(ray)
 verify.call(not hit.is_empty() and str(hit.collider.name)=="ClosedWindowBarrier","West window is still covered by a wall or can be walked through")
 verify.call(not w.graphics.clear_pose(Vector3(17,0,16.6)) and w.graphics.clear_pose(Vector3(-9,0,1.7)),"Relocated shelves obstruct the window or accept embedded old saves")
 var curved:=w.details.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("curved_crt",false))
 verify.call(curved.size()==2,"Arcade CRTs did not receive convex glass surfaces")
 for screen in curved:
  verify.call(screen.mesh.get_aabb().size.z>.015 and screen.has_node("ConvexCRTGlass"),"Arcade screen is still a flat illustration")
 var checked:=0
 for mesh in w.mesh_cache.values():
  var arrays: Array=mesh.surface_get_arrays(0)
  var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
  var valid: bool=tangents.size()==arrays[Mesh.ARRAY_VERTEX].size()*4
  for value in tangents:
   if not is_finite(value):valid=false;break
  verify.call(valid,"Procedural rounded mesh has no usable normal-map tangent basis")
  checked+=1
  if checked==16:break
 verify.call(sound.records.size()>30,"Machinery sources are not individually routed")
 var unique: Dictionary={}
 for record in sound.records:
  verify.call(not unique.has(record.bus) and record.source.bus==record.bus,"An ambient source lost its individual acoustic filter")
  unique[record.bus]=true
 verify.call(sound.area(Vector3(-12,1,-31))=="kitchen" and sound.area(Vector3(-1,1,-31))=="cinema","Annex acoustic zones use unshifted room coordinates")
 var exclude: Array[RID]=[guard.get_rid()]
 var projector: AudioStreamPlayer3D=w.annex.sources[1]
 var direct:=sound.solve(projector,Vector3(-4.4,1.65,-29.65),exclude)
 var wall:=sound.solve(projector,Vector3(-12,1.65,-32),exclude)
 verify.call(direct.cutoff>15000 and direct.gain> -1,"Projector is muffled in its own unobstructed room")
 verify.call(wall.cutoff<5000 and wall.gain< -2 and wall.route,"Projector has no real wall/doorway path into the kitchen: "+str(wall))
 var rain:=sound.solve(w.soundscape.beds[0],Vector3(-8,1.65,1.7),exclude)
 verify.call(rain.blocked and rain.cutoff<1000 and rain.gain< -14,"Exterior rain bypasses the closed glazing")
 # Test the actual moving delivery leaf, not a mocked occlusion boolean.
 var speaker:=w.life.photo_hum;var old:=speaker.global_position
 speaker.global_position=Vector3(-11.9,1.4,9.4)
 w.backstage.exit_open=false;w.backstage.exit_leaf.rotation.y=0
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var shut:=sound.solve(speaker,Vector3(-9,1.65,9.4),exclude)
 w.backstage.exit_open=true;w.backstage.exit_leaf.rotation.y=PI*.49
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var opened:=sound.solve(speaker,Vector3(-9,1.65,9.4),exclude)
 verify.call(shut.blocked and shut.cutoff<2000 and opened.cutoff>15000 and opened.gain>shut.gain+8,"Opening the real door does not release the sound: "+str([shut,opened]))
 speaker.global_position=old
 guard.position=CrawlTubes.route(7.4);guard.position.y=.25
 sound.tick(.2,true,guard)
 verify.call(sound.room=="tube" and guard.step_player.bus=="AP.GuardSteps" and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("AP.GuardSteps"),2),"Crawl footsteps do not receive the short plastic-tube resonance")
 guard.position=Vector3(-1,0,-31)
 for i in range(8):sound.tick(.1,true,guard)
 verify.call(sound.room=="cinema" and sound.step_reverb.wet<.07 and sound.step_filter.cutoff_hz>15000,"Cinema footsteps retain the tube echo or ignore upholstery absorption")
 var before:=sound.clock;var visual_before:=w.graphics.clock
 sound.tick(.5,false,guard);w.graphics.tick(.5,false)
 verify.call(sound.clock==before and w.graphics.clock==visual_before,"Pause advances the new sound or rain/vent animations")
 for source in sound.added_loops:verify.call(not source.playing or source.stream_paused,"A new machine continues through pause")
 var volume: float=game.settings.ambience;game.settings.ambience=0.;game._apply_settings()
 verify.call(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("NightAmbience"))< -70,"New filters bypass the ambience volume slider")
 for record in sound.records:verify.call(record.source.bus==record.bus,"Settings overwrite source-specific routing")
 game.settings.ambience=volume;game._apply_settings()
 verify.call(w.current=="none" and game.state.current=="none","Ordinary rain or machinery became an anomaly")
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Graphics update obstructs a room or door: "+JSON.stringify(layout))
 var buses:=AudioServer.bus_count
 game._new_shift();game.intro.skip();await game.get_tree().process_frame
 verify.call(AudioServer.bus_count==buses,"Acoustic buses accumulate on every round rebuild")
