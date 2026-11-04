extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.set_process(false);g.player.active=false
 var w: PlayWorld=g.world;var player: NightGuard=g.player
 for kind in ScareBank.VOICES+ScareBank.FAMILIES:
  var digests: Dictionary={}
  for variant in range(1,ScareBank.VARIANTS+1):
   var file:=ScareBank.track(kind,variant);var digest:=FileAccess.get_sha256(file)
   verify.call(not digest.is_empty() and not digests.has(digest),"Missing or duplicate actual voice take: "+file);digests[digest]=true
 for kind in ["keys","paper","switch","hinge"]:
  var last:=""
  for attempt in range(12):
   player.foley.play(kind);var path: String=player.foley.sound.stream.resource_path
   verify.call(path!=last and player.foley.sound.pitch_scale==1.,"Repeated or pitch-shifted contact sound: "+kind);last=path
 for surface in player.surface_sounds:
  var files: Dictionary={}
  for stream in player.surface_sounds[surface]:files[stream.resource_path]=true
  verify.call(files.size()==8,"Surface has fewer than eight independent footstep takes: "+surface)
 var movement:=w.creature_audio
 movement.tick(.016,true)
 var count:=movement.count
 for frame in range(60):movement.tick(.016,true)
 verify.call(movement.count==count,"Stationary reference creatures generate movement clues")
 var mask: Node3D=w.room_horror.creature.mask;var previous:=mask.position
 mask.position.x+=.4;movement.tick(.016,true)
 verify.call(movement.count==count+1 and movement.records.horse.source.playing,"Moving horse has no mechanical material response")
 verify.call(movement.records.horse.source.global_position.distance_to(mask.global_position)<.001,"Horse sound stays at the source room while its head moves")
 movement.tick(1.,false)
 verify.call(not movement.records.horse.source.playing,"Paused creature movement sound is still audible")
 mask.position=previous;movement.tick(.016,true)
 verify.call(movement.count==count+1,"Resuming a stationary creature emits a deferred movement sound")
 var old_position:=player.position;var old_rotation:=player.rotation
 player.position=Vector3(-9.75,0,4.3);player.rotation=Vector3(0,PI/2.,0);player.camera.rotation=Vector3.ZERO
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 player.torch_body.tick(1.,true,0.,player)
 verify.call(player.torch_body.near_wall>.4 and player.lamp.light_energy<GuardTorch.BASE_ENERGY*.8,"Close wall receives the full bleaching flashlight energy")
 player.position=Vector3(-4,0,12);player.rotation=Vector3.ZERO
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 player.torch_body.tick(1.,true,0.,player)
 verify.call(player.lamp.light_energy>GuardTorch.BASE_ENERGY*.95,"Flashlight remains dim after leaving the close wall")
 player.position=old_position;player.rotation=old_rotation;player.foley.stop()
 for branch in [w.find_child("ReceptionCashDrawer",true,false),w.find_child("ManufacturedReceptionTelephone",true,false)]:
  verify.call(branch!=null and branch.find_children("*","CollisionShape3D",true,false).is_empty(),"Decorative close-up manufacturing detail adds walking collision")
 g.set_process(true)
