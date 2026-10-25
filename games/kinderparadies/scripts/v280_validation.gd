class_name PassageChecks
extends RefCounted

static func travel(game: Node3D, red: bool) -> void:
 game._decide(red)
 game.player.position=Vector3(PatrolPassage.CENTERS[1 if red else 0],0,PatrolPassage.ENTRY_Z-9.2)
 game.world.passages.tick(.01,true,game.player,game.state.current!="none",game.state.completed)
 for frame in range(900):
  if game.phase=="play" and game.world.passages.chosen<0: break
  await game.get_tree().physics_frame

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 verify.call(game.world.backstage.find_child("CostumeRepairWorkshop",true,false)!=null,"Costume room has no repair workshop")
 for red in [false,true]:
  if red: game.state.current="balls_float";game._build_world("balls_float");game._resume()
  var index:=1 if red else 0
  var x: float=PatrolPassage.CENTERS[index]
  game.player.position=Vector3(x,0,PatrolPassage.ENTRY_Z+1.7);game.player.rotation.y=0;game.player.camera.rotation.x=0;game.player.active=true
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  verify.call(game._target()==("red" if red else "green"),"Decision door is not reachable with E")
  Input.action_press("forward")
  for frame in range(70): await game.get_tree().physics_frame
  Input.action_release("forward")
  verify.call(game.player.position.z>PatrolPassage.ENTRY_Z+.1,"Shut decision door has no collider")
  var old_streak: int=game.state.streak
  game._decide(red)
  for frame in range(55): await game.get_tree().physics_frame
  verify.call(game.state.streak==old_streak and game.phase=="play","Opening a door commits the decision before walking")
  Input.action_press("forward")
  for frame in range(85): await game.get_tree().physics_frame
  Input.action_release("forward");game.player.active=false
  verify.call(game.player.position.z<PatrolPassage.ENTRY_Z-2.3 and game.player.position.y>-.05,"Corridor threshold blocks real walking")
  game._pause();var p: Vector3=game.player.position;var before: String=JSON.stringify(game.world.passages.snapshot())
  await game.get_tree().create_timer(.2).timeout
  verify.call(before==JSON.stringify(game.world.passages.snapshot()),"Passage advances during pause")
  game.has_session=false;game._continue();game.player.active=false
  verify.call(game.player.position.distance_to(p)<.1 and game.world.passages.chosen==index,"Saving in a corridor loses position or committed choice")
  game._decide(not red)
  verify.call(not game.world.passages.lanes[1-index].open,"Committed corridor lets the other door be selected")
  game.player.active=true;game.player.rotation.y=0;Input.action_press("forward")
  for frame in range(220):
   await game.get_tree().physics_frame
   if game.phase=="lift": break
  Input.action_release("forward")
  verify.call(game.phase=="lift" and not game.player.active,"Walking into the lift does not close it automatically")
  for frame in range(240):
   await game.get_tree().physics_frame
   if game.phase=="play": break
  game.player.active=false
  verify.call(game.state.streak==old_streak+1 and game.phase=="play","The lift counts the same round more than once or never arrives")
  verify.call(game.player.position.distance_to(Vector3(-8,0,19.35))<.15 and absf(game.intro.doors[0].position.x)>1.8,"Return is not in the original open entrance lift")
 # Wrong choice: retain the survived count, clear all story progress and wake without the phone call.
 game.state.current="none";game.archive.collected.append("opening")
 game._decide(true);game.player.position=Vector3(PatrolPassage.CENTERS[1],0,PatrolPassage.ENTRY_Z-2.8)
 game.world.passages.tick(.01,true,game.player,false,false)
 verify.call(game.phase=="failure" and game.door_failure.patrol_mode and game.survived==2,"Wrong corridor did not start one screaming 3D attack with the correct count")
 verify.call(game.archive.collected.is_empty() and game.state.streak==0,"Death does not clear the shift and its papers")
 var shown:=false
 for frame in range(600):
  await game.get_tree().physics_frame
  if game.death_label.visible: shown=game.death_label.text=="2 Runden überlebt"
  if game.phase=="play": break
 verify.call(shown,"Death never displays the survived-round count")
 verify.call(game.phase=="play" and game.state.streak==0 and not game.intro_pending and game.intro.stage=="done","Death does not wake directly into round 1")
 verify.call(game.player.position.distance_to(Vector3(-8,0,19.35))<.15,"Death wakes outside the original elevator")
 game.player.active=false
 game.state.current="balls_float";game._build_world("balls_float");game._resume()
 game._decide(false);game.player.position=Vector3(PatrolPassage.CENTERS[0],0,PatrolPassage.ENTRY_Z-2.8)
 game.world.passages.tick(.01,true,game.player,true,false)
 verify.call(game.phase=="failure" and game.state.streak==0,"Green corridor with an anomaly does not trigger death")
 for frame in range(600):
  await game.get_tree().physics_frame
  if game.phase=="play": break
 verify.call(game.phase=="play" and game.state.streak==0 and game.player.position.distance_to(Vector3(-8,0,19.35))<.15,"Wrong green corridor fails to restart in the entrance lift")
 game.player.active=false
 var count: int=game.door_failure.shown;game._pause();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.door_failure.shown==count and game.phase=="play","Loading after death repeats the attack or intro")
 for invalid in [null,[],{"chosen":99,"open":[true,false]},{"chosen":0,"open":["bad",false]}]: game.world.passages.restore(invalid)
 verify.call(game.world.passages.chosen==-1,"Malformed corridor save mutated selection")

 # The service rooms are beyond the corridors, connected by their own walkable hall.
 game._resume();game.player.position=Vector3(-7.9,0,-11);game.player.rotation.y=0;game.player.camera.rotation.x=0;game.player.velocity=Vector3.ZERO
 Input.action_press("forward")
 for frame in range(480): await game.get_tree().physics_frame
 Input.action_release("forward");game.player.active=false
 verify.call(game.player.position.z< -29 and game.player.position.y>-.05,"Extended service approach cannot be walked into")
 verify.call(game.world.annex.safe_pose(game.player.position),"Extended service approach cannot be saved")
 for id in ["missing","coverup"]:
  game.world.archive.sync(game.archive,int(ArchiveState.document(id).stage))
  var item: Node3D=game.world.archive.items[id]
  verify.call(item.global_position.distance_to(LostArchive.PAPERS[id]+ServiceAnnex.OFFSET)<.01,"Newspaper did not follow its service room")
 verify.call(game.world.room_horror.creature.global_position.z< -30,"Cinema creature did not follow the cinema ceiling")
