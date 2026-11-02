extends RefCounted

func advance(game: Node3D,seconds: float) -> void:
 for i in range(ceili(seconds*60)):
  game.world.horse_hunt.tick(1.0/60.0,true,game.player)
  if i%60==0:await game.get_tree().physics_frame

func walk(game: Node3D,to: Vector3,maximum: int=700) -> bool:
 var player: NightGuard=game.player;player.velocity=Vector3.ZERO;player.active=true
 player.rotation.y=atan2(-(to.x-player.position.x),-(to.z-player.position.z));Input.action_press("forward")
 for i in range(maximum):
  await game.get_tree().physics_frame
  game.world.horse_hunt.tick(1.0/60.0,true,player)
  if Vector2(player.position.x,player.position.z).distance_to(Vector2(to.x,to.z))<.17:break
 Input.action_release("forward");player.active=false;player.velocity=Vector3.ZERO
 return Vector2(player.position.x,player.position.z).distance_to(Vector2(to.x,to.z))<.25

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false;game.set_process(false)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var horse: CeilingHorse=game.world.room_horror.creature;var rest:=horse.mask.transform;var jaw:=horse.jaw.transform
 for i in range(600):horse.tick(.1,true)
 verify.call(horse.mask.transform==rest and horse.jaw.transform==jaw and horse.clock==0,"Reference horse still moves in a normal round")
 verify.call(not game.world.passages.red_locked and not game.world.passages.horse_note.visible,"Normal red door displays the horse puzzle")
 # Existing creator access remains independent from the new eight-digit code.
 game._open_archive_lock();game.archive_input="0712";game._submit_archive_code()
 verify.call(game.archive.unlocked and game.archive.creator_access,"0712 archive access was broken by the longer keypad")
 game.state.streak=2;game.state.current="none";game.archive.collected.assign(["note"]);game.player.position=Vector3(-8.7,0,-9.9)
 var before: Dictionary=game.state.serialize().duplicate(true);var before_pose: Transform3D=game.player.transform
 game._open_archive_lock();var input:=game.menu.find_child("ArchiveCodeInput",true,false) as LineEdit
 verify.call(input!=null and input.max_length==8,"Keypad cannot accept the creator hunt code")
 game.archive_input=HorseHunt.TEST_CODE;game._submit_archive_code();game.player.active=false
 var hunt: HorseHunt=game.world.horse_hunt
 verify.call(game.state.current==HorseHunt.ID and game.state.horse_override and hunt.enabled,"Eight-digit code does not replace the current round with the hunt")
 verify.call(game.state.streak==2 and game.state.rounds==before.rounds and game.state.deck==before.deck and game.state.bag==before.bag and str(game.state.rng.state)==before.rng,"Creator trigger resets progress or consumes the anomaly deck")
 verify.call(game.archive.unlocked and game.archive.collected==["note"] and game.player.transform==before_pose,"Creator trigger loses archive progress or moves the player")
 game._decide(true);verify.call(not game.world.passages.lanes[1].open and game.world.passages.lanes[1].body.collision_layer==1 and game.notice.text==HorseHunt.CLUE,"Locked red door opens or does not explain the clown clue")
 verify.call(game.world.passages.horse_note.visible,"Horse clue is missing from the red door")
 var hair:=game.world.annex.clown.head.find_child("MattedBlondHair",true,false) as Node3D
 verify.call(hair is MeshInstance3D and game.world.annex.clown.head.is_ancestor_of(hair) and hair.find_children("*","CollisionShape3D",true,false).is_empty(),"Blond clown hair is missing, detached, or collidable")
 # Save and reload a forced hunt on an otherwise protected newspaper round.
 game._save();game.has_session=false;game._continue();game.player.active=false;hunt=game.world.horse_hunt;horse=game.world.room_horror.creature
 verify.call(game.state.current==HorseHunt.ID and game.state.streak==2 and hunt.red_locked(),"Reload suppresses the forced hunt on newspaper round three")
 game.world.archive.tick(3,true)
 game.player.position=Vector3(-7.9,0,-25.5);game.player.velocity=Vector3.ZERO
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 await advance(game,9.3)
 verify.call(hunt.navigation.ready and hunt.navigation.cells.size()>1000,"Batched horse navigation did not finish")
 # Real mask vertices, not just its centre, must clear the kitchen lintel.
 var kept_head:=hunt.head;var kept_rotation:=hunt.head_rotation;var clear:=true;var issue:=""
 for i in range(61):
  hunt.head=Vector3(lerpf(-8.0,-11.0,i/60.0),2.03,-29.65);hunt.head_rotation=Vector3(-1.02,PI/2,0)
  hunt.head_rotation.x=hunt._fit_head();horse.mask.global_position=hunt.head;horse.mask.rotation=hunt.head_rotation
  for mesh in horse.mask.find_children("*","MeshInstance3D",true,false):
   for surface in range(mesh.mesh.get_surface_count()):
    var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:
     var p: Vector3=mesh.to_global(vertex)
     if absf(p.x+9.4)<.12 and (p.y>2.54 or p.z< -30.6 or p.z> -28.7):clear=false;issue=str(p)
 hunt.head=kept_head;hunt.head_rotation=kept_rotation;hunt._draw()
 verify.call(clear,"Following horse clips the kitchen lintel: "+issue)
 verify.call(hunt.phase=="following" and hunt.head.x< -7,"Anomalous horse never emerges into the corridor")
 for sample in [Vector3(-6.2,0,8.5),Vector3(8.0,0,-8.7),Vector3(-11.7,0,-5.4),Vector3(-11.5,0,-29.65),Vector3(-5.15,0,-29.65),Vector3(17.3,.2,-14),Vector3(21.1,0,7.8),Vector3(-11.2,0,-9.9)]:
  verify.call(not hunt.navigation.path(Vector3(-7.9,0,-29.65),sample).is_empty(),"Horse cannot navigate to an accessible room: "+str(sample))
 await advance(game,3)
 var frozen:=hunt.serialize().duplicate(true)
 hunt.tick(2,false,game.player)
 verify.call(hunt.serialize().trace==frozen.trace and hunt.clock==frozen.clock and hunt.head==HorseHunt.read_vector(frozen.head),"Pause advances the hunt or its recorded path")
 var routes: Array[Vector3]=[Vector3(-7.9,0,-10.7),Vector3(5.7,0,-10.7),Vector3(5.7,0,-8.7),Vector3(8.1,0,-8.7),Vector3(8.1,0,-10.05),Vector3(9.6,0,-10.05)]
 for p in routes:verify.call(await walk(game,p),"Player route used to lure the horse is blocked: "+str(game.player.position)+" target "+str(p))
 for i in range(1200):
  hunt.tick(1.0/60.0,true,game.player)
  if hunt.head.x>6.8 and hunt.phase=="following":break
  if i%60==0:await game.get_tree().physics_frame
 verify.call(hunt.head.x>6.8 and hunt.phase=="following" and hunt.trace.size()>80 and horse.sections.size()>5,"Horse stopped at the cinema doorway instead of following into the party room")
 var saved_head:=hunt.head;var saved_points:=hunt.trace.size();game._save();game.has_session=false;game._continue();game.player.active=false;hunt=game.world.horse_hunt;horse=game.world.room_horror.creature
 verify.call(hunt.phase=="following" and hunt.head.distance_to(saved_head)<.001 and hunt.trace.size()==saved_points and game.world.passages.red_locked,"Mid-chase reload resets the horse or unlocks red")
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 # The same actual standing route leads back to the kitchen, past its wall.
 for p in [Vector3(8.1,0,-10.05),Vector3(8.1,0,-8.7),Vector3(5.7,0,-8.7),Vector3(5.7,0,-10.7),Vector3(-7.9,0,-10.7),Vector3(-7.9,0,-29.65),Vector3(-12.3,0,-29.65)]:
  verify.call(await walk(game,p),"Kitchen lure route is blocked: "+str(game.player.position)+" target "+str(p))
 for i in range(1200):
  hunt.tick(1.0/60.0,true,game.player)
  if hunt.phase=="clown":break
  if i%60==0:await game.get_tree().physics_frame
 verify.call(hunt.phase=="clown" and hunt.screamed and hunt.scream.playing,"Kitchen clown does not repel the horse with a scream")
 verify.call(hunt.red_locked(),"Red opens before the clown and retreat are complete")
 await advance(game,.55)
 verify.call(game.world.annex.scare and game.world.annex.clown.root.global_position.distance_to(hunt.clown_start)>1,"The kitchen clown remains stationary during its leap")
 var paused_clock:=hunt.clown_clock;var paused_pose: Transform3D=game.world.annex.clown.root.transform
 hunt.tick(1,false,game.player)
 verify.call(hunt.clown_clock==paused_clock and game.world.annex.clown.root.transform==paused_pose and hunt.scream.stream_paused,"Pause does not freeze the clown or scream")
 await advance(game,.5)
 verify.call(hunt.phase=="retreating" and hunt.red_locked(),"Horse retreat does not begin with the red door still locked")
 var retreat_pose:=hunt.head;var retreat_data: Variant=JSON.parse_string(JSON.stringify(hunt.serialize()))
 hunt.restore(retreat_data)
 verify.call(hunt.phase=="retreating" and hunt.head.distance_to(retreat_pose)<.001 and hunt.retreat_index==retreat_data.retreat_index,"Saved retreat loses its reverse path")
 var old_index:=hunt.retreat_index;await advance(game,.6)
 verify.call(hunt.retreat_index<old_index and hunt.red_locked(),"Retreat does not consume the recorded history backwards")
 var bad:=hunt.serialize().duplicate(true);bad.trace=[["invalid"]];var good:=hunt.head;hunt.restore(bad)
 verify.call(hunt.head==good,"Malformed encounter save mutates the live hunt")
 await advance(game,80)
 verify.call(hunt.phase=="resolved" and not hunt.red_locked() and not game.world.passages.horse_note.visible,"Red never unlocks after the entire horse has returned")
 verify.call(horse.mask.position.distance_to(CeilingHorse.ROUTE[0])<.001 and horse.sections.slice(1).all(func(section):return not section.neck.visible),"Horse does not return completely into its static home pose")
 verify.call(not game.world.annex.scare and game.world.annex.clown.root.transform==hunt.clown_transform,"Clown is left floating after repelling the horse")
 game._decide(true);verify.call(game.world.passages.lanes[1].open,"Resolved hunt still blocks choosing the red door")
 game.world.passages.chosen=1;game.player.position=Vector3(PatrolPassage.CENTERS[1],0,PatrolPassage.ENTRY_Z-3)
 game._save();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.world.horse_hunt.phase=="resolved" and not game.world.passages.red_locked and game.world.passages.chosen==1 and game.world.passages.lanes[1].open,"Reload relocks a resolved hunt or strands the player in its red passage")
 print("HUNT RESULT ",JSON.stringify(game.world.horse_hunt.snapshot()))
 game.set_process(true)
