extends RefCounted

func run(game: Node3D,verify: Callable) -> void:
 game._new_shift();game.intro.skip();game.player.active=false
 var w: PlayWorld=game.world;var guard: NightGuard=game.player;var craft:=w.craft
 await game.get_tree().physics_frame;await game.get_tree().physics_frame
 verify.call(craft.floors.size()==3 and craft.handle_styles==5 and craft.worn_surfaces>=2,"Material/repair design pass is missing")
 verify.call(craft.has_node("CinemaFacadeAndProscenium/CinemaTicketInspection"),"Cinema ticket desk is missing")
 for key in craft.floors:
  var m: ShaderMaterial=craft.floors[key].material_override
  verify.call(m.shader.resource_path==VenueCraft.ROOT+"floor-finish.gdshader" and m.get_shader_parameter("normal_map")!=null,"A floor finish is flat/unconfigured: "+key)
 var layout:=SceneAudit.placement(w)
 verify.call(layout.doors.is_empty() and layout.art.is_empty() and layout.furniture.is_empty(),"Craft pass intersects architecture or a passage: "+JSON.stringify(layout))
 verify.call(not craft.clear_pose(Vector3(-6.08,0,-32.8)) and craft.clear_pose(Vector3(-5.3,0,-32.8)),"Ticket desk save hull blocks the aisle or accepts an embedded guard")
 # The rear-row visitor uses the same aisle; furnishings must clear its actual
 # capsule too, not only the standing player's chosen walking line.
 var visitor:=CapsuleShape3D.new();visitor.radius=.22;visitor.height=1.75
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=visitor;query.collision_mask=1;query.margin=.001;query.exclude=[guard.get_rid()]
 query.transform=Transform3D(Basis(),NightTerrors.SCENARIOS.cinema_last_row.p+ServiceAnnex.OFFSET+Vector3(0,.91,0))
 verify.call(game.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(),"Cinema counter blocks the rear-row visitor's actual spawn capsule")
 var programme:=w.find_child("RecessedCinemaProgramme",true,false) as MeshInstance3D
 verify.call(programme!=null and (programme.material_override as StandardMaterial3D).emission_enabled,"Existing cinema programme was duplicated or not recessed/illuminated")
 var forbidden:=Rect2(-6.8,-30.4,1.0,1.50)
 var clear_litter:=true
 for zone in craft.litter_zones:
  if zone.intersects(forbidden) or zone.grow(.3).has_point(Vector2(1.2,-31.9)):clear_litter=false
 verify.call(clear_litter and craft.litter_zones.size()==5,"Cinema litter occupies the entrance or the newspaper pickup")
 for mesh in w.find_children("*","MeshInstance3D",true,false):
  if mesh.get_meta("cinema_litter",false):verify.call(not mesh.visible,"Legacy randomly distributed cinema litter is still visible")
 for sample in [{"p":Vector3(-2.15,.012,-3.7),"sound":"rubber"},{"p":Vector3(-5.3,.008,-29.65),"sound":"carpet"},{"p":Vector3(-11.8,.008,-29.65),"sound":"concrete"}]:
  guard.position=sample.p;guard.velocity=Vector3.ZERO;await game.get_tree().physics_frame
  verify.call(FootSurfaces.at(guard)==sample.sound,"Visible floor finish and actual footstep disagree: "+str(sample))
 # Standing, without jumping: both thresholds and both jamb-side routes.
 for x in [-9.4,-6.4]:
  for offset in [-.36,.36]:
   for direction in [-1,1]:
    guard.position=Vector3(x+direction*1.1,0,-29.65+offset);guard.velocity=Vector3.ZERO;guard.rotation.y=PI/2 if direction==1 else -PI/2;guard.active=true;Input.action_press("forward")
    for frame in range(62):await game.get_tree().physics_frame
    Input.action_release("forward");guard.active=false
    verify.call(guard.position.x<x-.9 if direction==1 else guard.position.x>x+.9,"Threshold/jamb traps the guard at "+str(guard.position))
    verify.call(absf(guard.position.y)<.06,"A decorative floor/threshold changes physical floor height")
 # The accessible seat aisle beside the new ticket counter must still work.
 guard.position=Vector3(-5.3,0,-30.8);guard.rotation.y=0;guard.active=true;Input.action_press("forward")
 for frame in range(65):await game.get_tree().physics_frame
 Input.action_release("forward");guard.active=false
 verify.call(guard.position.z< -33.3,"The ticket counter blocks the rear cinema aisle")
 var normals:=craft.lights.map(func(record):return record.light.light_color)
 verify.call(normals[0].r>normals[0].b and craft.lights[0].light.spot_angle<40,"Party table has no focused warm light island")
 w.set_anomaly("party_dark")
 verify.call(craft.lights[0].light.light_energy==0,"New birthday light defeats the party-dark anomaly")
 game._build_world("lights_red");game._resume();game.player.active=false
 for record in game.world.craft.lights:verify.call(record.light.light_color.r>record.light.light_color.g*2,"New light ignores the red-light anomaly")
 game._new_shift();game.intro.skip();game.player.active=false
