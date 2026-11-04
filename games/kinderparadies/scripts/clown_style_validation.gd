extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g._new_shift();g.intro.skip();g.player.active=false;g.set_process(false)
 var clown: Dictionary=g.world.annex.clown
 var head: Node3D=clown.head
 var hair:=head.find_child("MattedBlondHair",true,false) as MeshInstance3D
 var cap:=head.get_node_or_null("PatchedCostumeCap") as Node3D
 verify.call(hair!=null and cap!=null,"New clown grooming or cap is missing")
 if not hair or not cap:return
 verify.call(hair.mesh.get_surface_count()==1 and hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>70000,"Desktop grooming has not gained its denser fibres")
 verify.call(hair.material_override is ShaderMaterial and hair.material_override.shader.resource_path.ends_with("blond_hair.gdshader"),"New hair lost its blond fibre material")
 verify.call(hair.find_children("*","CollisionShape3D",true,false).is_empty() and cap.find_children("*","CollisionShape3D",true,false).is_empty(),"Costume accessories add movement collision")
 var patches:=0
 var bounds:=AABB();var first:=true
 for mesh in cap.find_children("*","MeshInstance3D",true,false):
  var local: AABB=(head.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
  bounds=local if first else bounds.merge(local);first=false
  verify.call(mesh.get_meta("nonblocking_atmosphere",false) and mesh.gi_mode==GeometryInstance3D.GI_MODE_DYNAMIC,"Cap detail blocks a doorway audit or remains baked to its original pose")
  if str(mesh.name).begins_with("FauxLeatherPanel"):
   patches+=1
   verify.call(mesh.material_override is ShaderMaterial and mesh.material_override.shader.resource_path.ends_with("patched-cap.gdshader"),"A costume patch lacks its surface finish")
 verify.call(patches==6,"Cap is missing one of its six fitted panels")
 verify.call(bounds.position.y>.10 and bounds.end.y<.40 and bounds.size.x<.45,"Cap covers the face or exceeds its fitted silhouette: "+str(bounds))
 verify.call(cap.find_child("IndividualWaxedStitches",true,false)!=null and cap.find_child("RolledHemAndSeamWelts",true,false)!=null,"Cap has only painted seams instead of modelled thread and hem")
 var rest: Transform3D=head.global_transform.affine_inverse()*cap.global_transform
 head.rotation=Vector3(.15,.45,-.10)
 verify.call((head.global_transform.affine_inverse()*cap.global_transform).is_equal_approx(rest),"Cap separates from the head when the clown turns")
 head.rotation=Vector3.ZERO
 var web: Node3D=(load("res://assets/clown-v404/clown-hair-web.glb") as PackedScene).instantiate();g.add_child(web)
 var fibre: MeshInstance3D=web.find_child("MattedBlondHair",true,false)
 verify.call(fibre!=null and fibre.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==30000,"Web grooming lost its compact version of the same style")
 web.queue_free()
 g._build_world("clown_lunge");g.player.active=false
 g.player.position=Vector3(-12.4,0,-31.25);g.player.camera.look_at(g.world.annex.clown.head.global_position)
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 g.world.encounters.tick(1.1,true,g.player)
 verify.call(g.world.encounters.triggered,"New accessories obstruct the actual kitchen clown trigger")
 verify.call(g.world.annex.clown.head.has_node("PatchedCostumeCap"),"Lunging clown loses the cap")
 var failure:=DoorFailure.new();g.player.camera.add_child(failure);failure.start_archive(g.world,g.player.camera)
 verify.call(failure.figure.head.has_node("PatchedCostumeCap"),"Archive ending still uses the previous clown style")
 failure.queue_free();g.set_process(true)
