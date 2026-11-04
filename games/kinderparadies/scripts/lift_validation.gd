extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.set_process(false);g.player.active=false
 var intro: ElevatorIntro=g.intro
 var cabin:=intro.get_node("RestoredOriginalLiftCabin")
 verify.call(cabin.position==Vector3(-8.,0,18.8) and intro.doors.size()==2,"Lift makeover moves the original cabin or drops a sliding leaf")
 var collision_count:=0
 for shape in cabin.find_children("*","CollisionShape3D",true,false):
  if not shape.disabled:
   collision_count+=1
   verify.call(shape.shape is BoxShape3D,"Cabin detail sends a dense mesh to walking physics")
 verify.call(collision_count==5,"Cabin dressing adds blocking collision to the original five-slab envelope")
 verify.call(cabin.find_child("InsetLiftControlPanel",true,false)!=null and cabin.find_child("PeriodLiftDirectory",true,false)!=null,"Lift has no coherent control panel or period directory")
 verify.call(cabin.find_children("*","MeshInstance3D",true,false).size()<40,"Cabin detail was not batched into a small number of draw calls")
 for floor in [1,3,8,13]:
  intro.set_floor(floor)
  verify.call(intro.floor_displays.size()==2 and intro.floor_displays.all(func(indicator):return indicator.text.begins_with("%02d"%floor)),"New lift displays disagree with the actual patrol floor")
 intro.ticket.tick(2.,true)
 verify.call(intro.ticket.revealed and intro.ticket.paper.visible,"Rebuilt cabin loses the final-patrol printer")
 intro.set_floor(1)
 verify.call(not intro.ticket.paper.visible,"Resetting the lift retains the final-patrol receipt")
 var handset:=intro.phone.get_node("MachinedHandset")
 var hand:=intro.phone.get_node("FittedPhoneHand")
 verify.call(handset.find_children("*","MeshInstance3D",true,false).size()<12 and hand.find_children("*","MeshInstance3D",true,false).size()<9,"New handset or hand retains hundreds of individual detail draw calls")
 var skin_ok:=false
 for mesh in hand.find_children("*","MeshInstance3D",true,false):
  var material:=mesh.get_active_material(0) as StandardMaterial3D
  if "skin" in material.resource_name.to_lower():skin_ok=material.vertex_color_use_as_albedo and material.normal_enabled
 verify.call(skin_ok,"Close-up hand loses its skin pigment or pore finish")
 var glass: MeshInstance3D=intro.display.get_node("OLEDGlassSurface")
 var arrays:=glass.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 verify.call(glass.mesh.get_aabb().size.distance_to(Vector3(.068,.144,0))<.0001 and arrays[Mesh.ARRAY_NORMAL][0].z>.99,"Rounded OLED face is incorrectly sized or faces away from the player")
 # The bezel is .0758 wide: the live display must fit inside it, including corners.
 verify.call(Array(vertices).all(func(p):return absf(p.x)<=.03401 and absf(p.y)<=.07201),"Live display spills over the handset bezel")
 intro.tick(1.5)
 verify.call(intro.stage=="ringing" and intro.phone.visible and intro.display.state_label.text=="Eingehender Anruf","New handset does not show the incoming call")
 intro.accept();intro.tick(2.)
 verify.call(intro.stage=="call" and intro.display.timer_label.text=="00:02" and intro.display.artwork.connected,"Display does not follow the accepted call")
 var clock:=intro.clock;intro.paused=true;intro.tick(3.)
 verify.call(intro.clock==clock and intro.voice.stream_paused,"Intro pause advances the call or leaves speech playing")
 intro.paused=false;intro.tick(.01)
 verify.call(not intro.voice.stream_paused,"Continuing the call leaves speech paused")
 intro.tick(intro.call_length+1.)
 verify.call(intro.stage=="arrival","Completed call never starts door arrival")
 intro.tick(2.5);g.player.active=false
 verify.call(g.phase=="play" and not intro.phone.visible and intro.doors.all(func(door):return absf(door.position.x)>1.8),"New cabin cannot finish the intro and open both leaves")
 AfterPlayLanguage.choose("en")
 g.player.camera.look_at(Vector3(-8.,1.89,20.31))
 var words: String=g.captions.read_sign(g,g.get_viewport().get_visible_rect().size*.5)
 verify.call(words.contains("ground floor"),"Lift directory is excluded from English sign subtitles")
 AfterPlayLanguage.choose("de")
 intro.start_return();intro.tick(1.2);g.player.active=false
 verify.call(intro.stage=="done" and not intro.phone.visible,"Returning to the new cabin repeats the phone call")
 # Real physics traverse checks cover the threshold and adjoining floor without a jump.
 g.player.position=Vector3(-8.,.03,18.1);g.player.velocity=Vector3(0,0,-2.8)
 for i in range(90):
  await g.get_tree().physics_frame
  g.player.velocity=Vector3(0,-.1,-2.8);g.player.move_and_slide()
 verify.call(g.player.position.z<16.6 and g.player.position.y>-.08,"Lift threshold catches walking or drops the player through the floor")
 intro.start();intro.tick(1.5);intro.skip();g.player.active=false
 verify.call(intro.stage=="done" and not intro.phone.visible and not intro.ring.playing,"Skip leaves the rebuilt phone visible or ringing")
 g.set_process(true);g._main_menu()
