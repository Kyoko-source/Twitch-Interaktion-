extends RefCounted

func walk(game: Node3D,to: Vector3,frames: int=500) -> bool:
 var guard: NightGuard=game.player;guard.active=true
 Input.action_press("forward")
 for i in range(frames):
  var d:=to-guard.position;guard.rotation.y=atan2(-d.x,-d.z)
  if Vector2(d.x,d.z).length()<.10 and absf(d.y)<.12:break
  await game.get_tree().physics_frame
 Input.action_release("forward")
 for i in range(12):await game.get_tree().physics_frame
 var reached:=guard.position.distance_to(to)<.23
 print("CLIMB WALK ",to," -> ",guard.position," ",reached)
 return reached

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var guard: NightGuard=game.player;var sky: SkyTube=w.climbing.sky
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(sky.length>18 and sky.window_count>=6,"The party loop is not a substantial glazed route")
 verify.call(w.climbing.carved.size()==4,"Lookout has no physically attached carved names")
 verify.call(w.climbing.repaired_post_count==21,"Repair bands were attached to rails or suspended in empty space")
 for s in [-.045,sky.length+.045]:
  verify.call(sky.tangent(s).length()>.99 and (sky.surface(s,0,SkyTube.OUTER)-sky.route(s)).length()>.92,"Tube seam residue collapses across an entrance")
 verify.call(w.climbing.lookout.find_children("CarvedName*","Label3D",true,false).is_empty(),"Carvings are still floating text labels")
 var doors:=SceneAudit.placement(w)
 verify.call(doors.doors.is_empty() and doors.art.is_empty() and doors.furniture.is_empty(),"Climbing expansion overlaps scenery: "+JSON.stringify(doors))
 # Start on the ground and reach the old bridge using normal movement.
 guard.position=Vector3(6.4,0,7.5);guard.velocity=Vector3.ZERO
 for target in [Vector3(11.1,2.15,7.5),Vector3(12,2.15,7.5),Vector3(12,2.15,3.6),Vector3(10.8,2.15,3.6),Vector3(4.03,2.977,3.6),Vector3(4.03,2.977,-1.0),Vector3(2.05,2.977,-.10),Vector3(2.05,4.15,-3.7),Vector3(2.4,4.15,-4.5),Vector3(3.45,4.15,-4.5)]:
  verify.call(await walk(game,target),"Ground-to-lookout route is blocked at "+str(target))
 verify.call(FootSurfaces.at(guard)=="wood","Lookout does not use wood contact sounds")
 Input.action_press("crouch")
 await game.get_tree().physics_frame
 # Crawl the entire continuous tube in both directions, including both real
 # wall penetrations and all three bends. No teleport between checkpoints.
 for forward in [true,false]:
  var samples:=ceili(sky.length/.40)
  for i in range(samples+1):
   var s:=sky.length*i/samples
   if not forward:s=sky.length-s
   var target:=sky.route(s);target.y=SkyTube.FLOOR
   if not await walk(game,target,110):
    verify.call(false,"Tube blocks "+("forward" if forward else "reverse")+" at s="+str(s)+" position="+str(guard.position));break
  if forward:
   verify.call(await walk(game,Vector3(16.05,4.15,3.65)),"Tube exit has a raised threshold")
   Input.action_release("crouch")
   for i in range(25):await game.get_tree().physics_frame
   verify.call(not guard.crouching,"Cannot stand on the eastern upper landing")
   verify.call(await walk(game,Vector3(16.2,4.15,3.7)),"Eastern upper landing is disconnected")
   verify.call(await walk(game,Vector3(16.2,2.15,8.15)),"Upper ramp cannot be descended without jumping")
   verify.call(await walk(game,Vector3(16.2,4.15,3.7)),"Upper ramp cannot be ascended without jumping")
   Input.action_press("crouch")
  else:verify.call(await walk(game,Vector3(3.25,4.15,-4.5)),"Lookout return mouth has a raised threshold")
 Input.action_release("crouch")
 for i in range(25):await game.get_tree().physics_frame
 verify.call(not guard.crouching,"Cannot stand after returning to the lookout")
 for target in [Vector3(2.05,4.15,-3.7),Vector3(2.05,2.977,-.10),Vector3(2.3975,2.977,.72)]:
  verify.call(await walk(game,target),"Lookout return obstructs the existing slide approach")
 guard.rotation.y=PI;Input.action_press("forward")
 for i in range(150):await game.get_tree().physics_frame
 Input.action_release("forward")
 verify.call(guard.position.z>6.8 and guard.position.y<1.4,"Reported slide lip still catches the player: "+str(guard.position))
 # Windows must show the room and physically contain the same capsule.
 var sample:=sky.route(7.8);sample.y=SkyTube.FLOOR
 guard.position=sample;guard.velocity=Vector3.ZERO;guard.set_crouch(true)
 verify.call(w.tubes.contains(sample) and w.acoustics.area(sample)=="tube","Upper route is missing crawl audio/pose detection")
 w.soundscape.voice.stop();var voices_before:=w.soundscape.voice_count;w.soundscape.cue_voice(guard)
 verify.call(w.soundscape.voice_count==voices_before+1 and absf(w.soundscape.voice.position.y-SkyTube.HEIGHT-.15)<.02,"Children's voices remain in the lower tunnel when inside the upper route")
 verify.call(not w.tubes.contains(sample-Vector3.UP*SkyTube.FLOOR),"Party floor is incorrectly classified as a tube")
 w.tubes.set_anomaly("tube_watcher");w.tubes.tick(0,true,guard)
 verify.call(not w.tubes.watcher.visible,"Lower-tunnel watcher appears outside its roof window")
 var s: float=sky.nearest(sample).s;var side:=Vector3.UP.cross(sky.tangent(s))
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sky.route(s),sky.route(s)+side*1.3,1,[guard.get_rid()]))
 verify.call(not hit.is_empty() and sky.is_ancestor_of(hit.collider),"A transparent bay has no physical barrier")
 game._save();game.has_session=false;game._continue()
 for i in range(12):await game.get_tree().physics_frame
 verify.call(game.player.crouching and game.world.climbing.sky.contains(game.player.position),"Upper-tube save is not restored crouched in the same route")
 # A pre-expansion upper-deck save under the cabin remains escapable.
 game.player.position=Vector3(2.05,2.977,-4.5);game._save();game.has_session=false;game._continue()
 for i in range(8):await game.get_tree().physics_frame
 verify.call(game.player.crouching and game.player.position.distance_to(Vector3(2.05,2.977,-4.5))<.1,"An older upper-deck save is trapped inside the new lookout floor")
 Input.action_press("crouch")
 verify.call(await walk(game,Vector3(2.05,2.977,-2.7)),"An older save cannot crawl out below the new cabin")
 # Preserve the original lower tunnel and its interior-only watcher.
 game.player.position=Vector3(-5.5,0,10.7);game.player.velocity=Vector3.ZERO
 verify.call(await walk(game,Vector3(-5.5,.31,12.5)),"Original crawl-tube mouth was broken by the expansion")
 var lower_open:=true
 for i in range(1000):
  var n:=CrawlTubes.nearest(game.player.position);var to:=CrawlTubes.route(minf(CrawlTubes.LENGTH,n.s+.45));to.y=.31
  if n.s>CrawlTubes.LENGTH-.3:to+=Vector3(0,0,-1.2)
  var d: Vector3=to-game.player.position;game.player.rotation.y=atan2(-d.x,-d.z);Input.action_press("forward")
  await game.get_tree().physics_frame
  if game.player.position.x>3.4 and game.player.position.z<11.3:break
  if i==999:lower_open=false
 Input.action_release("forward")
 verify.call(lower_open,"Original lower tube no longer traverses both bends")
 game.world.tubes.set_anomaly("tube_watcher");game.player.position=CrawlTubes.route(7.4)-Vector3.UP*.72;game.world.tubes.tick(0,true,game.player)
 verify.call(game.world.tubes.watcher.visible,"Original watcher is missing from its interior roof window")
 game.player.position=Vector3(0,0,10);game.world.tubes.tick(0,true,game.player)
 verify.call(not game.world.tubes.watcher.visible,"Original watcher is visible from outside the lower tube")
 Input.action_release("crouch");game.player.active=false
