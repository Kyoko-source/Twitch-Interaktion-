extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 var initial: PlayWorld=game.world;var builds: int=game.world_build_count
 verify.call(game.menu_reference_ready,"Initial menu did not retain a pristine reference venue")
 var started:=Time.get_ticks_usec();game._request_shift()
 var start_ms:=float(Time.get_ticks_usec()-started)/1000.
 verify.call(game.phase=="intro" and game.world==initial and game.world_build_count==builds,"Play rebuilds the world already visible behind the menu")
 verify.call(start_ms<150.,"Pristine Play blocks for more than 150 ms: "+str(start_ms))
 game.intro.skip();game.player.active=false
 if game.world.native_art:
  for chair in game.world.props.chairs.get_children():
   var hull: Node=chair.get_node_or_null("SmoothPartyChairHull")
   verify.call(hull!=null and hull.get_child_count()==2,"Party chair lost its fitted seat/back collision")
   var dense:=false
   for shape in chair.find_children("*","CollisionShape3D",true,false):
    if not shape.disabled and shape.shape is ConcavePolygonShape3D:dense=true
   verify.call(not dense,"Party chair still sends the imported triangle mesh to walking physics")
 game._show_ending(1);game.end_credits.tick(5)
 var ending: EndCredits=game.end_credits
 var beat:=game.get_tree().get_frame()
 await ending.wait_prepared()
 verify.call(game.get_tree().get_frame()>beat+10 and not game.world_loading,"Closing venue was built in one blocked frame")
 verify.call(game.world.current=="none" and ending.music.playing,"Preparing the end view rerolls an anomaly or stops the credits music")
 builds=game.world_build_count;started=Time.get_ticks_usec();ending.finish_scroll()
 var skip_ms:=float(Time.get_ticks_usec()-started)/1000.
 verify.call(ending.afterglow!=null and game.world_build_count==builds and skip_ms<50.,"Skip builds a world or blocks instead of showing the prepared closing view")
 ending.tick(PatrolPartyOutro.DURATION+1.);verify.call(ending.done and ending.actions.visible,"Prepared closing view has no completed ending actions")
 game._main_menu();beat=game.get_tree().get_frame()
 await game._request_shift()
 verify.call(game.get_tree().get_frame()>beat+10 and game.phase=="intro" and game.loading_progress==1.,"Starting a later shift blocks or leaves an unfinished loading state")
 verify.call(game.state.streak==0 and game.archive.collected.is_empty(),"Responsive new shift retained old progress")
 game.intro.skip();game.player.active=false
 # A queued preparation belonging to discarded credits must never replace
 # the following shift's room after its first process frame.
 game._show_ending(1);game._new_shift();game.intro.skip();game.player.active=false
 var fresh: PlayWorld=game.world
 for i in range(4):await game.get_tree().process_frame
 verify.call(game.phase=="play" and game.world==fresh and not game.world_loading,"A discarded credit preparation runs during the next shift")
 # Cancel after construction has actually yielded, not just before its deferred start.
 game._show_ending(1)
 await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(game.world_loading,"Credit preparation never entered its yielding build")
 game._new_shift();game.intro.skip();game.player.active=false;fresh=game.world
 for i in range(48):await game.get_tree().process_frame
 verify.call(game.phase=="play" and game.world==fresh and not game.world_loading,"An in-flight credit build replaced a newer shift")
 print("STARTUP TIMINGS MS play=",start_ms," skip=",skip_ms," responsive_frames=",game.get_tree().get_frame()-beat)
 game.intro.skip();game.player.active=false
