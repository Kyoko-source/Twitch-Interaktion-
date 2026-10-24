extends RefCounted

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(game.hud.find_children("*","Label",true,false).size()==4 and game.round_label.visible,"Minimal HUD still contains the permanent checklist or key legend")
 game._inventory();await game.get_tree().process_frame;await game.get_tree().process_frame
 var notebook:=game.menu.find_child("PatrolNotebook",true,false) as PatrolNotebook
 verify.call(is_instance_valid(notebook) and notebook.visited.is_empty() and notebook.round_number==1,"A fresh inventory does not show the handwritten patrol sheet")
 verify.call(not game.player.active and notebook.handwriting.has_char("ü".unicode_at(0)),"Notebook does not pause or lacks German handwriting glyphs")
 game.state.inspect("Küche");game._inventory();await game.get_tree().process_frame;await game.get_tree().process_frame
 notebook=game.menu.find_child("PatrolNotebook",true,false) as PatrolNotebook
 verify.call(notebook.visited==["Küche"],"Notebook does not reflect the current round's visited areas")
 game._resume();game.state.visited.clear();game.player.active=false
 var b: BackstageExpansion=game.world.backstage
 verify.call(b.costumes.size()==7 and b.throne.find_children("*","MeshInstance3D",true,false).size()>=4,"Authored throne and seven hanging costumes are missing")
 var placement:=SceneAudit.placement(game.world)
 verify.call(placement.doors.is_empty() and placement.art.is_empty() and placement.furniture.is_empty(),"Expansion placement issue: "+str(placement))
 # Traverse the actual ramp and aperture with a full standing capsule, in both
 # directions and near both jambs. No teleport or jump over threshold failures.
 for offset in [-.28,0,.28]:
  for direction in [1,-1]:
   game.player.position=Vector3(17.3+offset,0 if direction==1 else .2,-8.2 if direction==1 else -14.0);game.player.velocity=Vector3.ZERO;game.player.rotation.y=0 if direction==1 else PI;game.player.set_crouch(false);game.player.active=true
   Input.action_press("forward")
   for frame in range(132): await game.get_tree().physics_frame
   Input.action_release("forward");game.player.active=false
   verify.call(game.player.position.z< -13.0 if direction==1 else game.player.position.z> -9.0,"Backstage threshold traps the player: "+str(game.player.position))
   verify.call(game.player.position.y>=-.03,"Backstage floor has an unsupported gap")
 game.player.position=Vector3(17.3,.2,-14.5);await game.get_tree().physics_frame
 verify.call(FootSurfaces.at(game.player)=="wood","Backstage floor does not play its wood footsteps")
 game._save();game.has_session=false;game._continue();game.player.active=false
 verify.call(game.player.position.distance_to(Vector3(17.3,.2,-14.5))<.1,"Save/resume rejects the new backstage room")
 b=game.world.backstage
 # A shut leaf must block the actual standing capsule, not only look closed.
 game.player.position=Vector3(-8.8,0,9.4);game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI/2;game.player.active=true
 Input.action_press("forward")
 for frame in range(50): await game.get_tree().physics_frame
 Input.action_release("forward");game.player.active=false
 verify.call(game.player.position.x> -10.0,"Closed delivery door has no physical collision")
 game.player.position=Vector3(-8.8,0,9.4);game.player.camera.look_at(Vector3(-10.2,1.3,9.4));await game.get_tree().physics_frame
 verify.call(game._target()=="delivery_exit","Delivery door is not reachable with the normal E ray")
 b.interact_exit(game.player)
 for frame in range(80): await game.get_tree().physics_frame
 verify.call(b.exit_open and b.exit_leaf.rotation.y>1.45,"Delivery door does not swing open")
 placement=SceneAudit.placement(game.world)
 verify.call(placement.doors.is_empty(),"Decoration blocks the open delivery passage: "+str(placement.doors))
 for direction in [1,-1]:
  game.player.position=Vector3(-8.8 if direction==1 else -13.6,0,9.4);game.player.velocity=Vector3.ZERO;game.player.rotation.y=PI/2 if direction==1 else -PI/2;game.player.active=true
  Input.action_press("forward")
  for frame in range(92): await game.get_tree().physics_frame
  Input.action_release("forward");game.player.active=false
  verify.call(game.player.position.x< -12.2 if direction==1 else game.player.position.x> -10,"Player cannot walk both ways through the delivery door: "+str(game.player.position))
 game.player.position=Vector3(-10.4,0,9.4);b.interact_exit(game.player)
 verify.call(b.exit_open,"Delivery door closes through someone standing in the threshold")
 verify.call(not b.clean.visible and not b.exit_started,"Normal round contains the impossible clean corridor")
 for id in BackstageExpansion.DOCS:
  var document: MeshInstance3D=game.world.server_room.find_child("Document_"+id,true,false)
  game.player.position=document.global_position+Vector3(0,-document.global_position.y,1.65);game.player.camera.look_at(document.global_position)
  await game.get_tree().physics_frame
  verify.call(game._target()=="story:"+id,"Maintenance story document cannot be read with E: "+id)
  game._environment_note(id);await game.get_tree().process_frame
  var text:=""
  for label in game.menu.find_children("*","Label",true,false): text+=label.text
  verify.call(BackstageExpansion.DOCS[id].text in text and not game.player.active,"Maintenance document does not pause/read clearly")
  game._return_from_panel();game.player.active=false
 game._equipment_card();await game.get_tree().process_frame
 verify.call(game.menu.find_child("GuardDutyBadge",true,false)!=null,"Personal badge is missing from inventory equipment")
 game._resume();game.player.active=false
 var gear: GuardEquipment=game.player.equipment
 gear.step(true,true);await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(gear.jingle_count>0 and gear.jingle.stream.get_length()>.08,"Personal equipment has no recorded key sound")
 game._pause();verify.call(not gear.jingle.playing,"Keyring continues to ring after pausing")
 game._build_world("false_exit");game._resume();game.player.active=false;b=game.world.backstage
 game.player.position=Vector3(-8.8,0,9.4);b.interact_exit(game.player);b.tick(1.5,true,game.player)
 verify.call(b.clean.visible and not b.ruined.visible and b.exit_started,"False exit never presents the clean room")
 var elapsed:=b.exit_clock;var angle:=b.exit_leaf.rotation.y;b.tick(2,false,game.player)
 verify.call(b.exit_clock==elapsed and b.exit_leaf.rotation.y==angle,"False exit animation ignores pause")
 b.tick(2.5,true,game.player)
 verify.call(b.exit_finished and not b.clean.visible and b.ruined.visible,"False exit does not change after the blackout")
 # Once inside, the effect must leave the way back open.
 game._build_world("false_exit");game._resume();game.player.active=false;b=game.world.backstage
 game.player.position=Vector3(-8.8,0,9.4);b.interact_exit(game.player);b.tick(1.5,true,game.player)
 game.player.position=Vector3(-12.5,0,9.4);b.tick(3,true,game.player)
 verify.call(b.exit_open and b.exit_finished,"Impossible corridor locks the player inside")
 # Use the real save/continue path on a non-protected round. The safe room
 # pose, changed sign and open route must survive, without replaying the sting.
 game.state.streak=1;game.state.rounds=1;game.state.current="false_exit"
 game._save();game.has_session=false;game._continue();game.player.active=false;b=game.world.backstage
 verify.call(b.exit_finished and b.exit_open and b.ruined.visible and not b.clean.visible,"Reload resets the discovered false exit")
 verify.call(game.player.position.distance_to(Vector3(-12.5,0,9.4))<.1,"Reload rejects a player inside the delivery corridor")
 verify.call(not b.door_audio.playing,"Restoring the corridor replays its door sound")
 game._save(true)
 var next: Dictionary=JSON.parse_string(game._persistent_text(game.SAVE))
 verify.call(next.backstage.is_empty(),"A next-round save carries the previous encounter")
 game._build_world("costume_wakes");game._resume();game.player.active=false;b=game.world.backstage
 game.player.position=Vector3(16.15,.2,-15.1);game.player.camera.look_at(b.masks[3].global_position)
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 b.tick(1,true,game.player)
 verify.call(b.triggered and b.masks[3].rotation.x<-.1,"Hanging costume has no accessible visual trigger")
 var attack:=b.attack;game._pause();await game.get_tree().process_frame;await game.get_tree().process_frame;b.tick(1,false,game.player)
 verify.call(b.attack==attack and (not b.scare_audio.playing or b.scare_audio.stream_paused),"Hanging costume moves or plays its sting while paused")
 game.state.current="costume_wakes";game._save();game.has_session=false;game._continue();game.player.active=false;b=game.world.backstage
 verify.call(b.triggered and b.masks[3].rotation.x<-.1 and not b.scare_audio.playing,"Reload resets the costume or replays its scare sound")
 var saved:=b.serialize();b.restore({"id":"false_exit","costume_triggered":false})
 verify.call(b.serialize()==saved,"Encounter data from another anomaly is accepted")
 b.restore({"id":"costume_wakes","costume_triggered":false,"costume_attack":"invalid"})
 verify.call(b.serialize()==saved,"Malformed encounter save mutates live state")
 var legacy: Dictionary=JSON.parse_string(game._persistent_text(game.SAVE));legacy.erase("backstage");legacy.layout_version=8
 game._write_persistent_text(game.SAVE,JSON.stringify(legacy));game.has_session=false;game._continue();game.player.active=false
 verify.call(game.phase=="play" and game.state.current=="costume_wakes","Version 2.6 saves without expansion data no longer load")
 game._build_world("throne_guest");game._resume();game.player.active=false
 game.player.position=Vector3(13.4,.2,-8.6);game.player.camera.look_at(game.world.terrors.focus_point())
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 game.world.terrors.tick(1,true,game.player)
 verify.call(game.world.terrors.triggered,"Seated throne visitor cannot be discovered")
 var state:=PatrolState.new();state.start(270)
 for round_number in range(1,14):
  if round_number in [1,3,5,8,11]: verify.call(state.current=="none","Expansion broke protected newspaper round "+str(round_number))
  state.decide(state.current!="none")
 game._new_shift();game.intro.skip()
