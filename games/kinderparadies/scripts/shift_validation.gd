extends RefCounted

func run(g: Node3D,verify: Callable) -> void:
 g.set_process(false)
 g._new_shift();g.intro.skip();g.player.active=false
 var album: ShiftAlbum=g.album
 var original:=album.entries.duplicate(true);album.entries.clear();album.textures.clear()
 album.discover(1);album.discover(1);album.discover(8)
 var copy:=ShiftAlbum.new();copy.build(g)
 verify.call(copy.entries.size()==1 and copy.entries.has("1"),"Album fails to persist discovered endings independently")
 g._new_shift();g.intro.skip();g.player.active=false
 verify.call(album.entries.has("1"),"New shift deletes collected ending memories")
 album.show_menu()
 verify.call(g.menu.find_children("AlbumEnding*","PanelContainer",true,false).size()==3,"Album does not display three spoiler-free slots")
 var hidden: String=g.menu.get_node("AlbumEnding2").get_child(0).get_child(1).text
 verify.call(hidden=="Unentdecktes Ende","An undiscovered album card reveals its ending")
 g.ending_preview=true;g._show_ending(2)
 verify.call(not album.entries.has("2"),"Creator ending preview unlocks unearned album entries")
 g._main_menu();g._new_shift();g.intro.skip();g.player.active=false
 var ticket: ShiftTicket=g.intro.ticket
 ticket.set_floor(12);ticket.tick(4,true)
 verify.call(not ticket.paper.visible,"Last-patrol receipt appears before twelve correct decisions")
 ticket.set_floor(13);ticket.tick(.4,true);var printed:=ticket.amount;ticket.tick(3,false)
 verify.call(ticket.paper.visible and ticket.amount==printed and printed>0.,"Receipt animation ignores pause")
 ticket.tick(2,true)
 verify.call(ticket.amount==1. and ticket.text.text.contains(ShiftTicket.MESSAGE.split(". ")[0]),"Last-patrol receipt never prints its requested text")
 ticket.set_floor(1)
 verify.call(not ticket.paper.visible and not ticket.revealed,"Death/new shift retains the final-patrol receipt")
 var touch: VenueTouch=g.world.touch
 verify.call(touch.records.size()==2 and touch.brands>=10 and touch.cup in g.world.atmosphere.loose,"Contact reactions, shared identity or cup pause registration are missing")
 touch.bump(0,3.);touch.tick(.1,true);var angle: float=touch.records[0].angle;var bumps: int=touch.bumps
 touch.bump(0,4.);touch.tick(.4,false)
 verify.call(angle!=0. and touch.records[0].angle==angle and touch.bumps==bumps,"Contact reaction repeats without contact or ignores pause")
 for i in range(360):touch.tick(1./60.,true)
 verify.call(absf(touch.records[0].angle)<.003,"Bin lid never returns to its stable reference pose")
 verify.call(g.world.current=="none" and g.world.terrors.spec.is_empty(),"Ordinary reactions alter the reference-round anomaly")
 var torch: GuardTorch=g.player.torch_body
 torch.tick(.02,true,0.)
 verify.call(is_equal_approx(g.player.lamp.light_energy,4.9) and torch.body.get_child_count()>12,"Flashlight makeover or modest brightness increase is absent")
 var shell: MeshInstance3D=torch.body.get_node("AnodisedAluminiumBody")
 var arrays:=shell.mesh.surface_get_arrays(0);var outward:=0.;var sample_count:=0
 for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
  var p: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
  if p.z>-.14 and p.z<.16:
   outward+=Vector3(p.x,p.y,0).normalized().dot(arrays[Mesh.ARRAY_NORMAL][i]);sample_count+=1
 verify.call(sample_count>20 and outward/sample_count>.8,"Torch shell faces inward and exposes its hollow interior")
 torch.look(Vector2(80,35));torch.tick(.05,true,0.,g.player)
 verify.call(torch.sway.length()>0.,"Flashlight has no damped mouse response")
 torch.land(-7.)
 for i in range(6):torch.tick(1./60.,true,0.,g.player)
 verify.call(torch.landing<-.002,"Flashlight lacks landing inertia")
 for i in range(180):torch.tick(1./60.,true,0.,g.player)
 verify.call(absf(torch.landing)<.001,"Flashlight landing spring does not settle")
 var wall:=StaticBody3D.new();g.add_child(wall);var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,1,.03);shape.shape=box;wall.add_child(shape);wall.global_transform=g.player.camera.global_transform;wall.global_position-=g.player.camera.global_basis.z*.43
 await g.get_tree().physics_frame;await g.get_tree().physics_frame
 for i in range(30):torch.tick(1./60.,true,0.,g.player)
 verify.call(torch.near_wall>.5 and torch.position.z>GuardTorch.REST.z+.1,"Torch intersects a close wall instead of retracting")
 wall.queue_free();torch.reset_motion()
 verify.call(torch.position==GuardTorch.REST and torch.landing==0.,"New shift retains flashlight inertia")
 var warning:=AfterPlayStartWarning.new();g.add_child(warning);warning.build(g)
 await g.get_tree().process_frame
 verify.call(warning.strobe.has_focus() and warning.continue_button.text=="Verstanden · Weiter","Redesigned warning loses explicit acknowledgement or initial safe focus")
 verify.call(warning.root.find_child("WarningTitle",true,false)!=null and warning.root.find_child("WarningJoke",true,false)!=null,"Redesigned warning drops its health information or joke")
 warning.queue_free()
 var dummy:=Node3D.new();g.add_child(dummy);var visitor: Node3D=(load("res://assets/revamp-v300/visitor-ragged.glb") as PackedScene).instantiate();dummy.add_child(visitor)
 ScareSculpt.visitor(visitor,g.world,"pursuit")
 verify.call(visitor.find_child("DetailedScareAnatomy",true,false)!=null and visitor.find_child("ShreddedLayeredCostume",true,false)!=null,"Granny still uses the old simplified face or dress")
 g.door_failure.start_patrol(g.world,g.player.camera)
 verify.call(g.door_failure.attacker.scene_file_path.contains("visitors-v421") and g.door_failure.attacker.find_child("Head",true,false)!=null,"Wrong-door attacker does not use the rebuilt v421 visitor")
 g.door_failure.tick(1.4)
 verify.call(not g.door_failure.running,"Upgraded wrong-door attacker breaks its bounded scare timeline")
 dummy.queue_free();album.entries=original;album.textures.clear();album.save();g.ending_preview=false
 g._main_menu();g.set_process(true)
