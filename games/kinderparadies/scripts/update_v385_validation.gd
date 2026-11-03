extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false
 var w: PlayWorld=g.world;var guard: NightGuard=g.player
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 var helper=load("res://scripts/climbing_validation.gd").new()
 # Repeated real walking over the photographed opening, never jump or warp
 # between its ramp and landing. Test off-centre approaches too.
 for z in [7.20,7.50,7.80]:
  guard.position=Vector3(6.25,.03,z);guard.velocity=Vector3.ZERO
  verify.call(await helper.walk(g,Vector3(11.25,2.15,z),220),"Lower ramp still catches walking up at z="+str(z))
  verify.call(await helper.walk(g,Vector3(6.25,.03,z),220),"Lower ramp still catches walking down at z="+str(z))
 guard.active=false
 # The rendered parking lot itself must support a capsule, including the
 # right-hand space outside the former narrow ending trigger.
 var entrance: Node3D=w.backstage.exit_root
 for local in [Vector3(-3.0,0,-6.4),Vector3(-5,0,-9),Vector3(3,0,-9)]:
  var p:=entrance.to_global(local)
  var hit:=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP*2,1,[guard.get_rid()]))
  verify.call(not hit.is_empty() and hit.normal.y>.9,"Parking ground is missing at "+str(p))
 # Trigger the real ending from a diagonal approach that formerly bypassed it.
 g.archive.parking_key_found=true;g._sync_parking_key();w.backstage.interact_exit(guard)
 for i in range(65):await g.get_tree().physics_frame
 guard.position=entrance.to_global(Vector3(-.65,.02,-5.85));guard.velocity=Vector3.ZERO;guard.active=true;guard.rotation.y=entrance.rotation.y
 Input.action_press("forward");Input.action_press("left")
 for i in range(70):
  await g.get_tree().physics_frame
  if g.phase=="ending":break
 Input.action_release("forward");Input.action_release("left")
 verify.call(g.phase=="ending" and g.secret_ending and guard.position.y>-.4,"Right-hand parking escape misses ending or falls out of world")
 if is_instance_valid(g.end_credits):await g.end_credits.wait_prepared()
 g._new_shift();g.intro.skip();guard.active=false;w=g.world
 verify.call(not g.archive.parking_key_found and not w.backstage.exit_key_owned and w.details.parking_key.visible,"A genuinely new shift retains a parking key")
 var bounds:=AABB();var first:=true
 for mesh in w.playground.croc_visual.find_children("*","MeshInstance3D",true,false):
  var box: AABB=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
 verify.call(bounds.size.x>10.0 and bounds.size.z>4.6,"Crocodile did not become substantially larger")
 verify.call(bounds.end.x<19.7 and bounds.position.x>6.5 and bounds.position.z>9.0 and bounds.end.z<15.7,"Crocodile intersects a wall, play structure or arcade aisle: "+str(bounds))
 verify.call(w.playground.croc_jaw!=null,"Croc snap lost its articulated jaw")
 var old:=w.playground.croc_jaw.rotation;w.playground.set_croc_jaw(.1);verify.call(w.playground.croc_jaw.rotation!=old,"New crocodile jaw cannot animate");w.playground.set_croc_jaw(0)
 var party: HappylandParty=w.party
 verify.call(not party.enabled and not party.audio.playing,"Party starts unprompted as a false anomaly")
 var button: Node3D=party.get_node("MaintenancePartyControl")
 guard.position=button.global_position+button.global_basis.z*1.1;guard.position.y=0;guard.camera.look_at(button.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 verify.call(g._target()=="party_control","Maintenance party switch is obstructed")
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;g._unhandled_input(event)
 verify.call(party.enabled and party.audio.playing and party.lamps.size()==6,"E does not start the real song and party rig")
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 party.evaluate(12,false);var calm:=party.intensity
 party.evaluate(HappylandParty.TRACK.BEATS.filter(func(t):return t>HappylandParty.TRACK.DROPS[0]+1)[0],false)
 verify.call(party.drop and party.intensity>calm*1.3 and party.lamps.any(func(light):return light.light_energy>2),"First analysed drop has no intensified lighting")
 verify.call(party.lamps.all(func(light):return light.light_color!=Color("f4fff8")),"Disabled strobe still produces white flashes")
 party.evaluate(HappylandParty.TRACK.DROPS[1]+1,false);verify.call(party.drop,"Second analysed drop is not recognised")
 g.phase="pause";party.tick(.1,false,true,true);await g.get_tree().physics_frame
 verify.call(party.audio.stream_paused,"Party music keeps advancing during pause")
 g.phase="play";party.tick(.1,true,true,false);verify.call(not party.audio.stream_paused,"Party music does not resume")
 AfterPlayLanguage.choose("en");verify.call(AfterPlayLanguage.t("E · Parkplatzschlüssel mitnehmen")=="E · Take parking key","Parking key is missing its English interaction");AfterPlayLanguage.choose("de")
 g.archive.parking_key_found=true;g._sync_parking_key();g._save();g.has_session=false;g._continue();g.player.active=false
 verify.call(g.world.party.enabled and g.world.party.audio.playing and g.archive.parking_key_found and not g.world.details.parking_key.visible,"Continue loses the active party or the collected key")
 party=g.world.party
 party.set_enabled(false);verify.call(not party.audio.playing and party.lamps.all(func(light):return light.light_energy==0) and party.fills.all(func(light):return light.light_energy==0),"Turning party off leaves music or lamps on")
 g._build_world("croc_snap");g._resume();guard.active=false
 guard.position=Vector3(6.8,0,11.8);guard.rotation.y=-PI/2;guard.camera.rotation=Vector3.ZERO
 await g.get_tree().physics_frame
 g.world.encounters.elapsed=1.1;g.world.encounters.tick(.01,true,guard)
 verify.call(g.world.encounters.triggered,"The larger crocodile occludes its own approach trigger")
 g.world.encounters.tick(.22,true,guard);var jaw: Vector3=g.world.playground.croc_jaw.rotation
 verify.call(jaw.x>.3,"The larger crocodile does not snap its upper jaw")
 g.world.encounters.tick(.4,false,guard);verify.call(g.world.playground.croc_jaw.rotation==jaw,"The crocodile jaw moves while paused")
 g._new_shift();g.intro.skip();g.player.active=false
