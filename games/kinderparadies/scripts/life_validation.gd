extends RefCounted

func press(game: Node3D) -> void:
 var event:=InputEventAction.new();event.action="interact";event.pressed=true;game._unhandled_input(event)

func run(game: Node3D, verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 var life: HappylandLife=game.world.life
 var audit:=SceneAudit.placement(game.world)
 verify.call(audit.doors.is_empty() and audit.art.is_empty() and audit.furniture.is_empty(),"Life expansion overlaps a doorway, painting or wall: "+JSON.stringify(audit))
 verify.call(life.bathroom!=null and life.booth!=null and life.snack!=null and life.puddles==3,"The six environmental additions are incomplete")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(18.5,1.2,7.8),Vector3(21.4,1.2,7.8),1);ray.exclude=[game.player.get_rid()]
 verify.call(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"The WC entrance has an invisible wall or overlay")
 game.player.position=Vector3(18.4,.03,7.8);game.player.rotation=Vector3(0,-PI/2,0);game.player.active=true;game.player.velocity=Vector3.ZERO
 Input.action_press("forward")
 for frame in range(120):
  await game.get_tree().physics_frame
  if game.player.position.x>21.3: break
 Input.action_release("forward")
 var collisions: Array[String]=[]
 for i in range(game.player.get_slide_collision_count()):
  var hit: Node3D=game.player.get_slide_collision(i).get_collider();var mesh:=hit.get_parent() as MeshInstance3D
  collisions.append(str(hit.get_path())+" "+str(hit.global_position)+" "+str(mesh.global_transform*mesh.get_aabb() if mesh else AABB()))
 verify.call(game.player.position.x>21.2 and absf(game.player.position.z-7.8)<.08,"Guard cannot walk through the actual WC entrance: "+str(game.player.position)+" "+str(collisions))
 game.player.velocity=Vector3.ZERO;life.apply_room_audio(game.player)
 verify.call(game.player.step_player.bus=="WashroomSteps" and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("WashroomSteps"))==1,"Bathroom footsteps have no distinct room acoustics")
 game._pause();var saved: Vector3=game.player.position;game.has_session=false;game._continue();game.player.active=false
 verify.call(game.player.position.distance_to(saved)<.08,"Continue discards a valid position in the new washroom")
 life=game.world.life
 game.player.active=true;game.player.rotation=Vector3(0,-PI/2,0);Input.action_press("back")
 for frame in range(120):
  await game.get_tree().physics_frame
  if game.player.position.x<18.6: break
 Input.action_release("back")
 verify.call(game.player.position.x<18.7,"The new washroom traps the returning guard")
 game.player.active=false;game.player.velocity=Vector3.ZERO
 game.player.position=Vector3(25.7,.03,6.7);game.player.rotation=Vector3(0,PI,0);game.player.camera.look_at(Vector3(25.7,1.3,8.01))
 await game.get_tree().physics_frame
 verify.call(game._target()=="life:locked_wc","Locked cubicle cannot be inspected")
 press(game);verify.call(game.phase=="play","Locked cubicle interrupts the round")
 game.player.active=true;Input.action_press("forward")
 for frame in range(60): await game.get_tree().physics_frame
 Input.action_release("forward")
 verify.call(game.player.position.z<7.73,"The guard walks through the locked cubicle")
 game.player.active=false;game.player.velocity=Vector3.ZERO
 game.player.position=Vector3(12.69,0,14.95);game.player.camera.look_at(HappylandLife.PHOTO)
 await game.get_tree().physics_frame
 verify.call(game._target()=="life:photo","The strip behind the booth curtain cannot be examined with E")
 press(game);verify.call(game.phase=="help" and game.menu.find_child("BoothPhotoReader",true,false)!=null,"E does not open the actual corrected photo strip")
 game._return_from_panel();game.player.active=false
 var state_before:=JSON.stringify(game.state.serialize())
 life.tick(6.5,true)
 verify.call(life.drip_count>0 and life.compressor_count>0 and life.photo_hum.playing,"Ordinary water and compressor events never occur")
 verify.call(JSON.stringify(game.state.serialize())==state_before and game.state.current=="none","Ordinary booth, water or compressor changes the anomaly decision")
 game._pause();await game.get_tree().process_frame
 var at:=life.clock
 await game.get_tree().create_timer(.15).timeout
 verify.call(life.clock==at and life.photo_hum.stream_paused and life.motor.stream_paused,"Environmental motion or audio advances during pause")
 game._resume();game.player.active=false
 await game.get_tree().create_timer(.12).timeout
 verify.call(life.clock>at and not life.photo_hum.stream_paused,"Ordinary room sounds fail to resume")
 var master:=AudioServer.get_bus_volume_db(0)
 game._show_archive_ending();game.end_credits.tick(5);game.end_credits.finish_scroll();game.end_credits.tick(3)
 var last: EndingAfterglow=game.end_credits.afterglow
 verify.call(game.end_credits.snapshot().stage=="last_look" and not game.end_credits.actions.visible and game.end_credits.music.playing,"Closing shot is missing or reveals buttons over the image")
 verify.call(last.camera.current and game.world.current=="none" and game.end_credits.black.color.a<.01,"Closing shot is not the empty reference venue")
 verify.call(game.world.life.clock==0 and not game.world.life.photo_hum.playing,"Ambient machinery leaks into the music-box-only closing shot")
 last.tick(8)
 var faded:=0
 for item in last.lights:
  if item.node.light_energy<item.energy*.5: faded+=1
 verify.call(faded>5 and game.world.environment.environment.ambient_light_energy<last.ambient*.4,"The closing room lights do not actually fade")
 verify.call(not last.emissions.is_empty() and last.emissions.all(func(item):return item.material.emission_energy_multiplier<=item.energy*.1),"The glowing lamp surfaces remain lit after their lights fade")
 game.end_credits.tick(20)
 verify.call(game.end_credits.done and game.end_credits.actions.visible and not game.end_credits.music.playing and game.end_credits.black.color.a==1,"Closing shot does not finish cleanly on black")
 verify.call(is_equal_approx(AudioServer.get_bus_volume_db(0),master),"Closing shot changes the player's master volume")
 game._main_menu();await game.get_tree().process_frame;await game.get_tree().process_frame
 verify.call(game.menu_camera.current,"Closing-shot disposal overrides the menu camera")
 game._new_shift();game.intro.skip();game.player.active=false
