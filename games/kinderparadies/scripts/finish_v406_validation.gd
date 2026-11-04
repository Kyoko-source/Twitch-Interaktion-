extends RefCounted

func surfaces(cabin: Node3D) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for mesh in cabin.find_children("*","MeshInstance3D",true,false):
  var transform: Transform3D=cabin.global_transform.affine_inverse()*mesh.global_transform
  result.append({"p":transform.origin,"bounds":transform*mesh.get_aabb(),"vertices":mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()})
 result.sort_custom(func(a,b):return str(a.p.snapped(Vector3.ONE*.001))<str(b.p.snapped(Vector3.ONE*.001)))
 return result

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g._build_world("none");g.set_process(false);g.player.active=false
 var w: PlayWorld=g.world;var p: NightGuard=g.player;var passages: PatrolPassage=w.passages
 var original: Node3D=g.intro.get_node("RestoredOriginalLiftCabin")
 var expected:=surfaces(original)
 for lane in range(2):
  var copy: PassageLift=passages.lanes[lane].lift
  # Compare the real room geometry in cabin coordinates, after subtracting the
  # intentional world-space rotation and translation. Not just a shared flag.
  for i in range(2):copy.doors[i].position.x=g.intro.doors[i].position.x
  var actual:=surfaces(copy.cabin)
  verify.call(actual.size()==expected.size(),"Return lift has a different set of visible components")
  if actual.size()==expected.size():
   for i in range(actual.size()):
    verify.call(actual[i].bounds.position.distance_to(expected[i].bounds.position)<.002 and actual[i].bounds.size.distance_to(expected[i].bounds.size)<.002 and actual[i].vertices==expected[i].vertices,"Return cabin component does not match entrance geometry: "+str(i))
  verify.call(copy.cabin.find_child("InsetLiftControlPanel",true,false)!=null and copy.cabin.find_child("PeriodLiftDirectory",true,false)!=null and copy.ticket!=null,"Return copy omits the control panel, directory or printer")
  for i in range(2):copy.doors[i].position.x=(-1 if i==0 else 1)*1.89
  passages.set_floor(7);g.intro.set_floor(7)
  verify.call(copy.floor_displays.all(func(display):return display.text=="07"),"Return cabin floor number differs from the entrance")
  for row in passages.lanes:row.open=false
  passages.chosen=-1;passages.closing=false;passages.fired=false
  passages.open(bool(lane));passages.tick(1.,true,p,bool(lane),false)
  var points: Array[Vector3]=[Vector3(PatrolPassage.CENTERS[lane],.03,-10.6)]
  for point in passages.lanes[lane].path:
   points.append(passages.lanes[lane].root.to_global(Vector3(point.x,.03,point.y)))
  points.append(copy.cabin.to_global(Vector3(0,.03,.55)))
  p.position=points[0];p.velocity=Vector3.ZERO
  for point in points.slice(1):
   for frame in range(210):
    var toward: Vector3=point-p.position;toward.y=0
    if toward.length()<.08:break
    await g.get_tree().physics_frame;p.velocity=toward.normalized()*2.6+Vector3.DOWN*.4;p.move_and_slide()
   verify.call(Vector2(p.position.x-point.x,p.position.z-point.z).length()<.12 and p.position.y>-.06,"Walking catches a corridor joint or misses the return lift: "+str(lane)+" "+str(point)+" actual "+str(p.position))
  passages.tick(.01,true,p,bool(lane),false)
  verify.call(passages.closing and g.phase=="lift","Entering the correct cloned lift does not board it")
  await g.get_tree().create_timer(.38).timeout
  verify.call(p.position.distance_to(passages.boarding_position())<.02,"Boarding does not centre the player on the original cabin pose")
  var local: Vector3=copy.cabin.to_local(p.position)
  verify.call(local.distance_to(Vector3(0,0,.55))<.02,"Viewpoint jumps relative to the entrance cabin")
  g.phase="play";g.player.active=false;passages.closing=false;passages.chosen=-1;passages.fired=false;p.position=Vector3(0,0,5.)
 # Wrong-door attack still happens in the corridor, before any boarding.
 passages.open(true);p.position=Vector3(PatrolPassage.CENTERS[1],0,PatrolPassage.ENTRY_Z-2.5)
 passages.tick(.1,true,p,false,false)
 verify.call(g.phase=="failure" and passages.fired,"Wrong corridor no longer triggers its attack")
 g.door_failure.running=false;g.door_failure.hide();g.phase="play";p.active=false
 var plant:=w.atmosphere.get_node("NeglectedAspidistra")
 verify.call(plant.find_children("*","CollisionShape3D",true,false).size()==1,"Plant leaf detail adds snagging collision")
 var leaves:=plant.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return mesh.get_active_material(0) is ShaderMaterial)
 verify.call(leaves.size()==1 and leaves[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>3000,"Plant still uses stretched fabric spheres")
 var colors: PackedColorArray=leaves[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 verify.call(not colors.is_empty() and colors[0].g<.6,"Leaf mesh loses its botanical colour pigment")
 var cart:=w.details.find_child("ForgottenPopcornTrolley",true,false)
 if not cart:cart=w.annex.find_child("ForgottenPopcornTrolley",true,false)
 var batches:=cart.find_children("IrregularPoppedCorn_*","MultiMeshInstance3D",true,false)
 verify.call(batches.size()==3 and batches.all(func(mesh):return mesh.multimesh.instance_count==160),"Popcorn machine still has a few round balls instead of a filled irregular pile")
 for mesh in batches:
  verify.call(mesh.multimesh.mesh.get_aabb().size.x<.04 and mesh.multimesh.mesh.get_aabb().size.y<.035,"Popped kernels are oversized")
 for fly in w.annex.get_node("PotFlies").get_children():verify.call(fly.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and fly.material_override.shader.code.contains("depth_draw_never"),"Tiny moving flies retain opaque screen-space occluders or shadow casters")
 var energy: Array[float]=[]
 var kitchen: Array=[]
 for bulb in w.room_horror.bulbs:
  if bulb.light.global_position.x< -9.35 and bulb.light.global_position.z< -24:kitchen.append(bulb)
 for frame in range(1800):
  w.room_horror.tick(1./60.,true)
  if frame==0:
   for bulb in kitchen:energy.append(bulb.light.light_energy)
  elif frame%30==0:
   verify.call(kitchen.size()>=4 and kitchen.all(func(bulb):return is_equal_approx(bulb.light.light_energy,bulb.energy)),"Kitchen reference lighting changes or flashes over time")
 g._new_shift();g.intro.skip();g.set_process(true)
