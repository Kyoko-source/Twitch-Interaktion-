extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.set_process(false);g.player.active=false
 g._build_world("none")
 var w: PlayWorld=g.world;var m: MechanicalProps=w.mechanics
 for id in ["bell","gum","ticket"]:
  var target: String="mechanical:"+id
  var record: Dictionary=m.records[id]
  verify.call(record.sound.stream.get_length()>.2 and record.sound.stream.get_length()<1.5,"Mechanism sound is absent or unnecessarily long: "+id)
  verify.call(record.sound.bus.begins_with("AP.Source."),"Mechanism bypasses room acoustics: "+id)
  var bodies: Array=record.root.find_children("*","StaticBody3D",true,false)
  verify.call(bodies.size()==1 and bodies[0].collision_layer==8 and bodies[0].collision_mask==0,"Mechanical detail blocks walking: "+id)
  var point: Vector3=record.contact.global_position
  # Test real ray targeting from the clear customer side of each existing desk.
  g.player.position=Vector3(point.x,0,8.77) if id!="ticket" else Vector3(-5.3,0,point.z)
  g.player.camera.look_at(point)
  await g.get_tree().physics_frame;await g.get_tree().physics_frame
  verify.call(g._target()==target,"Cannot reach mechanical interaction through E: "+id+" (hit "+g._target()+")")
  var before: int=record.count
  var event:=InputEventAction.new();event.action="interact";event.pressed=true;g._unhandled_input(event)
  verify.call(g.player.hands.kind==target and record.count==before,"Mechanism fires before hand contact: "+id)
  g.player.hands.tick(g.player.hands.duration*.29,true)
  verify.call(record.count==before+1,"Hand contact fails to move mechanism: "+id)
  m.tick(.15,true)
  verify.call(record.pivot.transform!=record.rest,"No visible mechanism movement: "+id)
  var time: float=record.time;var pose: Transform3D=record.pivot.transform
  m.tick(4.,false)
  verify.call(record.time==time and record.pivot.transform.is_equal_approx(pose) and not record.sound.playing,"Paused mechanism or audio keeps running: "+id)
  verify.call(not m.interact(target) and record.count==before+1,"Repeated interaction overlaps a mechanism: "+id)
  g.player.hands.tick(2.,true);m.tick(.25,true)
  verify.call(record.played and record.sound.playing and not record.sound.stream_paused,"Contact sound is absent: "+id)
  m.tick(2.,true)
  verify.call(record.pivot.transform.is_equal_approx(record.rest) and not m.busy(target),"Mechanism fails to return: "+id)
  AfterPlayLanguage.choose("en");verify.call(AfterPlayLanguage.t(m.prompt(target))!=m.prompt(target),"Mechanism prompt lacks English translation: "+id)
  AfterPlayLanguage.choose("de");verify.call(AfterPlayLanguage.t(m.prompt(target))==m.prompt(target),"Mechanism prompt ignores German: "+id)
 # The reported reception bug: inspect the real fingertip and generated sleeve
 # from both reachable customer positions, then operate it from farther away.
 var hands: GuardActions=g.player.hands
 var bell_point: Vector3=m.records.bell.contact.global_position
 for side in [-.10,.10]:
  g.player.position=Vector3(bell_point.x+side,0,8.56);g.player.camera.look_at(bell_point)
  verify.call(hands.begin("mechanical:bell",bell_point),"Close bell gesture cannot begin")
  hands.clock=hands.duration*.40;hands.pose()
  verify.call(hands.visible and hands.close_contact,"Reachable bell hides the hand")
  var finger:=hands.skeleton.get_bone_global_pose(hands.skeleton.find_bone("index3"))*Vector3(0,.02125,0)
  verify.call(hands.skeleton.to_global(finger).distance_to(bell_point)<.012,"Finger misses the reachable bell")
  var bounds:=hands.sleeve.custom_aabb
  verify.call(bounds.end.z<-.06 and bounds.size.length()<.85,"Sleeve crosses the camera or stretches across the screen")
  var mesh_id:=hands.sleeve.mesh.get_instance_id();hands.pose()
  verify.call(hands.sleeve.mesh.get_instance_id()==mesh_id,"Each hand pose allocates a new sleeve mesh")
  hands.cancel()
 g.player.position=Vector3(bell_point.x,0,9.1);g.player.camera.look_at(bell_point)
 hands.begin("mechanical:bell",bell_point);hands.clock=hands.duration*.40;hands.pose()
 verify.call(not hands.visible and not hands.sleeve.visible,"Distant bell grows a stretched arm")
 hands.cancel()
 # The animation-disabled option still works immediately, without a second path.
 g.player.hands.enabled=false
 g.player.position=Vector3(m.records.bell.contact.global_position.x,0,8.77);g.player.camera.look_at(m.records.bell.contact.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 var count: int=m.records.bell.count;var event:=InputEventAction.new();event.action="interact";event.pressed=true;g._unhandled_input(event)
 verify.call(m.records.bell.count==count+1 and g.player.hands.kind.is_empty(),"Disabled hand animation prevents ordinary interaction")
 g.player.hands.enabled=true
 var annex: ServiceAnnex=w.annex
 for i in range(1081):
  annex.tick(1./60.,true)
  if i%20!=0:continue
  verify.call(annex.grip_error()<.00001,"Spoon slips out of the curled fingers")
  var bowl: Vector3=annex.clown.bowl.position
  var radial:=Vector2(bowl.x,bowl.z-ServiceAnnex.POT_Z).length()
  verify.call(radial>=.194 and radial<=.270 and bowl.y>=1.261 and bowl.y<=1.338,"Spoon crosses through pot wall or misses food")
  var wrist: Vector3=annex.clown.hand.transform*HorrorFigures.WRIST
  var endpoint: Vector3=annex.clown.forearm.transform*Vector3(0,.5,0)
  verify.call(endpoint.distance_to(wrist)<.00001,"Cooking sleeve detaches from wrist")
 verify.call(annex.pot_taps==1,"Pot contact sound is unsynchronized or repeated every frame")
 annex.clock=(TAU*2.+PI)/1.15;annex._stir_pose()
 verify.call(absf(Vector2(annex.clown.bowl.position.x,annex.clown.bowl.position.z-ServiceAnnex.POT_Z).length()+.052-.321)<.001,"Audible contact does not meet the inner pot rim")
 var taps:=annex.pot_taps;var pose: Transform3D=annex.clown.hand.transform;var clock:=annex.clock
 annex.tick(5.,false)
 verify.call(annex.clock==clock and annex.clown.hand.transform.is_equal_approx(pose) and not annex.pot_audio.playing,"Cooking ignores pause")
 annex.scare=true;annex.tick(5.,true)
 verify.call(annex.clown.hand.transform.is_equal_approx(pose) and annex.pot_taps==taps and not annex.pot_audio.playing,"Clown continues cooking or tapping during a lunge")
 annex.scare=false;annex.settled=true;annex.tick(5.,true)
 verify.call(not annex.pot_audio.playing and annex.clown.hand.transform==pose,"Settled clown keeps cooking")
 g.set_process(true)
