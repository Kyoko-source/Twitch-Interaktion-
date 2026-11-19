extends RefCounted

# --zombies-only: Partynacht (5.0.0). With --capture-dir=DIR it also saves
# screenshots of the round HUD, stations, the gift box and a boss.
var dir:=""

func shot(game: Node3D, title: String) -> void:
	if dir=="":return
	for i in range(6):await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(dir.path_join("zombies-%s.png"%title))

func frames(game: Node3D, count: int) -> void:
	for i in range(count):await game.get_tree().process_frame

func look_at_point(game: Node3D, at: Vector3, from: Vector3) -> void:
	game.player.global_position=from;var to:=at-from
	game.player.rotation=Vector3(0,atan2(-to.x,-to.z),0);game.player.camera.rotation=Vector3(clampf(-atan2(-(at.y-(from.y+1.65)),Vector2(to.x,to.z).length()),-1.2,1.2),0,0)

func run(game: Node3D, verify: Callable) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):dir=arg.trim_prefix("--capture-dir=")
	verify.call(ZombiesConfig.WEAPONS.size()==30 and ZombiesConfig.PERKS.size()==12 and ZombiesConfig.PICKUPS.size()>=16,"Partynacht content incomplete: weapons/perks/pickups")
	verify.call(ZombiesConfig.ENEMIES.size()>=10 and ZombiesConfig.BOSSES.size()>=4 and ZombiesConfig.EVENTS.size()>=12,"Partynacht enemies, bosses or events missing")
	verify.call(ZombiesConfig.health(30)>ZombiesConfig.health(5)*5. and ZombiesConfig.enemies_in_round(20)>ZombiesConfig.enemies_in_round(1)*4 and ZombiesConfig.spawn_gap(25)<ZombiesConfig.spawn_gap(1),"Rounds do not escalate")
	var missing: Array=[]
	for row in ZombiesConfig.WEAPONS:
		if not ResourceLoader.exists("res://assets/zombies-v500/weapon-%s.glb"%str(row[2])):missing.append(row[0])
	for id in ZombiesConfig.ENEMIES:
		if not ResourceLoader.exists(str(ZombiesConfig.ENEMIES[id].model)):missing.append(id)
	for b in ZombiesConfig.BOSSES:
		if not ResourceLoader.exists(str(b.model)):missing.append(b.id)
	verify.call(missing.is_empty(),"Partynacht models missing: "+str(missing))
	var voices:=["pickup_double_points","pickup_speed","pickup_insta_kill","pickup_nuke","pickup_infinite_ammo","pickup_damage","start"]
	verify.call(voices.all(func(k):return ResourceLoader.exists(ZombiesAnnouncer.FOLDER+k+".ogg")) and ZombiesAnnouncer.stream_for("pickup_nuke") is AudioStreamOggVorbis,"Recorded announcer lines are missing")

	game._main_menu();await game.get_tree().process_frame
	var more:=game.menu.find_child("MainMenuAction2",true,false) as Button
	verify.call(more!=null and more.text.contains("Weitere Spielmodi"),"Main menu has no Weitere Spielmodi")
	more.pressed.emit();await game.get_tree().process_frame
	var entry:=game.menu.find_child("Mode_zombies",true,false) as Button
	verify.call(game.phase=="modes" and entry!=null and entry.text.contains("Partynacht"),"Modes menu has no Partynacht")
	NightMenus.zombies(game)
	verify.call(game.menu.find_child("ZombiesStart",true,false)!=null and game.menu.find_child("ZombiesRecords",true,false)!=null,"Partynacht menu misses start or records")
	await shot(game,"menu")
	game._start_zombies()
	while game.phase=="loading":await game.get_tree().process_frame
	await frames(game,4)
	var z: ZombiesMode=game.zombies
	verify.call(game.phase=="zombies" and z!=null and z.running and game.player.active,"Partynacht does not start")
	verify.call(z.arsenal.slots.size()==1 and z.arsenal.data().id==ZombiesConfig.START_WEAPON and z.points==ZombiesConfig.START_POINTS,"Start weapon or points wrong")
	verify.call(z.zones_open.keys()==[ZombiesConfig.START_ZONE],"More than the start zone is open")
	# Sealed zones: from the start only the reception is walkable.
	var reach:=z.nav.reachable(ZombiesConfig.SPAWN_POINT);var leak:=0
	for c in reach:
		var zone:=ZombiesConfig.zone_at(z.nav.point(c))
		if zone!="" and zone!=ZombiesConfig.START_ZONE:leak+=1
	verify.call(reach.size()>100 and leak==0,"Closed barriers leak into %d cells"%leak)
	var off: Array=[]
	for s in z.stations:
		var c:=z.nav.nearest(s.at)
		if c.x==999999 or z.nav.point(c).distance_to(s.at)>1.6 or ZombiesConfig.zone_at(s.at)=="":off.append(str(s.kind)+":"+str(s.id))
	verify.call(off.is_empty(),"Stations off the walkable floor: "+str(off))
	# Round one starts and the horde rises.
	z.break_clock=.01
	var clock:=0.
	while z.enemies.size()<3 and clock<12.:await game.get_tree().process_frame;clock+=game.get_process_delta_time()
	verify.call(z.round_number==1 and z.enemies.size()>=1,"Round one spawns no enemies: "+str(z.snapshot())+" clock %.1f"%clock)
	await frames(game,60)
	if dir!="":
		var e0: ZombieEnemy=z.enemies[0];look_at_point(game,e0.global_position+Vector3.UP*1.2,e0.global_position+(game.player.global_position-e0.global_position).normalized()*3.)
		await shot(game,"round")
	# Shooting: body and headshot damage, points and a kill.
	var target: ZombieEnemy=z.enemies[0];target.rise=0.;target.stun=99.;target.max_hp=5000.;target.hp=5000.
	var before_hp:=target.hp;var before_points:=z.points
	z.hit_enemy(target,40.,false,2.,target.global_position+Vector3.UP,"")
	var body_damage:=before_hp-target.hp
	verify.call(body_damage>39. and z.points>before_points,"A body hit does no damage or gives no points")
	var hp2:=target.hp;z.hit_enemy(target,40.,true,2.,target.global_position+Vector3.UP*1.6,"")
	verify.call(hp2-target.hp>body_damage*1.5,"Headshots do not hit harder")
	var kills:=int(z.stats.kills);z.damage_enemy(target,99999.,true,"",true)
	verify.call(target.dead and int(z.stats.kills)==kills+1 and int(z.stats.headshots)>=1,"A kill is not counted")
	# The real hitscan path reaches an enemy in front of the camera.
	var dummy:=z._spawn_enemy();dummy.rise=0.;dummy.stun=99.;dummy.model.position.y=0.;dummy.global_position=Vector3(-6.4,0,9.4)
	await game.get_tree().physics_frame;await game.get_tree().physics_frame
	look_at_point(game,dummy.global_position+Vector3.UP*1.,ZombiesConfig.SPAWN_POINT)
	var shot_hp:=dummy.hp
	var cam: Camera3D=game.player.camera
	var probe:=PhysicsRayQueryParameters3D.create(cam.global_position,cam.global_position-cam.global_basis.z*20.,ZombiesArsenal.RAY_MASK);probe.collide_with_areas=true;probe.exclude=[game.player.get_rid()]
	var seen:=game.get_world_3d().direct_space_state.intersect_ray(probe)
	var seen_text:="nothing" if seen.is_empty() else "%s/%s at %s"%[(seen.collider as Node).get_parent().name,(seen.collider as Node).name,str(seen.position)]
	var points_before_shot:=z.points
	z.arsenal._ray(cam.global_position,-cam.global_basis.z,55.,2.,1,"")
	verify.call(dummy.hp<shot_hp or (not seen.is_empty() and seen.collider.has_meta("enemy") and z.points>points_before_shot),"The pistol ray does not hit an enemy in front of the guard: ray sees "+seen_text+" dummy at "+str(dummy.global_position)+" eye "+str(cam.global_position)+" fwd "+str(-cam.global_basis.z))
	z.damage_enemy(dummy,99999.,false,"",false)
	# Buying: wall gun, ammo, perks, limit, door.
	z.points=60000
	var wall_index:=-1;var ammo_index:=-1;var perk_index:=-1;var box_index:=-1;var up_index:=-1
	for i in range(z.stations.size()):
		var s: Dictionary=z.stations[i]
		if s.kind=="wall" and s.id=="k12":wall_index=i
		if s.kind=="ammo" and ammo_index<0:ammo_index=i
		if s.kind=="perk" and s.id=="eiserne_rippen":perk_index=i
		if s.kind=="box":box_index=i
		if s.kind=="upgrade":up_index=i
	z.focus={"type":"station","index":wall_index};z.interact()
	verify.call(z.arsenal.has_weapon("k12")>=0 and z.arsenal.slots.size()==2 and z.points==60000-1200,"Buying a wall gun fails")
	z.arsenal.data().reserve=0;z.focus={"type":"station","index":ammo_index};z.interact()
	verify.call(int(z.arsenal.data().reserve)==z.arsenal.reserve_size("k12",0),"The ammo crate does not refill")
	z.focus={"type":"station","index":perk_index};z.interact()
	verify.call(z.has_perk("eiserne_rippen") and is_equal_approx(z.max_health,160.),"Perk does not apply")
	for id in ["blutdurst","todesatem","hoellenlauf","leichenfinger","achter_sinn"]:if z.perks.size()<z.perk_limit:z.buy_perk(id)
	var count:=z.perks.size();z.focus={}
	for i in range(z.stations.size()):
		if z.stations[i].kind=="perk" and not z.has_perk(z.stations[i].id):z.focus={"type":"station","index":i};break
	z.interact()
	verify.call(z.perks.size()==count and count==ZombiesConfig.PERK_LIMIT,"Perk limit not enforced")
	z.focus={"type":"door","index":0};z.interact()
	for i in range(4):await game.get_tree().physics_frame
	verify.call(z.doors[0].open and z.zones_open.has("halle"),"Door does not open its zone")
	var reach2:=z.nav.reachable(ZombiesConfig.SPAWN_POINT);var into_hall:=0
	for c in reach2:
		if ZombiesConfig.zone_at(z.nav.point(c))=="halle":into_hall+=1
	verify.call(into_hall>100,"The opened barrier is still blocking the way")
	# Chaos gift box.
	z.focus={"type":"station","index":box_index};z.interact()
	verify.call(not z.box_state.is_empty(),"The gift box does not open")
	if dir!="":
		var at: Vector3=z.box_node.global_position;look_at_point(game,at+Vector3.UP*.8,at+Vector3(0,0,2.6).rotated(Vector3.UP,z.box_node.rotation.y))
		await frames(game,40);await shot(game,"box")
	z.box_state.troll=false;z.box_state.clock=3.25;z._tick_stations(.05)
	verify.call(z.box_state.get("ready",false),"The gift box never offers a weapon")
	var offered: String=z.box_state.weapon
	z.focus={"type":"station","index":box_index};z.interact()
	verify.call(z.arsenal.has_weapon(offered)>=0,"Taking the box weapon fails")
	# Flesh machine upgrade.
	z.focus={"type":"station","index":up_index};var upgraded: String=z.arsenal.data().id;z.interact()
	verify.call(not z.upgrade_state.is_empty() and z.arsenal.has_weapon(upgraded)<0,"The flesh machine does not take the weapon")
	z.upgrade_state.clock=4.1;z._tick_stations(.05);z.focus={"type":"station","index":up_index};z.interact()
	verify.call(z.arsenal.has_weapon(upgraded)>=0 and int(z.arsenal.data(z.arsenal.has_weapon(upgraded)).level)==1,"Upgraded weapon not returned at level 1")
	# Every pickup.
	var failing: Array=[]
	for row in ZombiesConfig.PICKUPS:
		var id: String=row[0]
		z.arsenal.data().reserve=0
		z._collect(id)
		if float(row[3])>0. and not z.has_pickup(id):failing.append(id)
		if id=="max_ammo" and int(z.arsenal.data().reserve)==0:failing.append(id)
	verify.call(failing.is_empty(),"Pickups do not apply: "+str(failing))
	var pts:=z.points;z.active={"double_points":5.};z._add_points(100,true)
	verify.call(z.points==pts+200,"Double points do not double")
	z.active={}
	# Boss: spawns, has a bar, rewards a perk slot.
	z.round_number=10;z._spawn_boss(0)
	verify.call(z.bosses.size()==1 and z.bosses[0].hp>ZombiesConfig.health(10)*10.,"Boss does not spawn strong")
	if dir!="":
		var b: ZombieEnemy=z.bosses[0];b.rise=0.;b.model.position.y=0.;b.stun=99.
		look_at_point(game,b.global_position+Vector3.UP*2.,b.global_position+Vector3(4,0,4));await frames(game,30);await shot(game,"boss")
	var limit:=z.perk_limit;z.damage_enemy(z.bosses[0],1e9,false,"",true)
	verify.call(int(z.stats.bosses)==1 and z.perk_limit==limit+1,"Boss kill does not reward")
	# Events and reality escalation.
	var event_fail: Array=[]
	for id in ZombiesConfig.EVENTS:
		z._start_event(id);z._tick_world(.1);z._end_event()
		if z.event!="":event_fail.append(id)
	verify.call(event_fail.is_empty(),"Events do not end: "+str(event_fail))
	z.round_number=30
	for i in range(300):z._tick_world(.1)
	verify.call(z.reality()>.5 and not z.debris.is_empty() and not z.rifts.is_empty(),"Reality does not break from round 15")
	# Damage, regeneration and the end of the party.
	z.active={};z.perks.erase("grabesschritt");z.health=z.max_health
	z.hurt_player(50.,null)
	verify.call(z.health<z.max_health,"Enemies do no damage")
	z.hud.hit(true,true);z.hud.tick(.3,z._hud_data())
	verify.call(is_equal_approx(z.hud.health_bar.value,z.health) and z.hud.health_text.text.contains("LEBEN") and z.hud.hitmarker.modulate.a<.01,"Life bar missing or the hit marker stays on screen: bar %.1f health %.1f text %s marker %.2f"%[z.hud.health_bar.value,z.health,z.hud.health_text.text,z.hud.hitmarker.modulate.a])
	var swings: AnimationPlayer=(z.enemies[0] as ZombieEnemy).anim if not z.enemies.is_empty() else null
	verify.call(swings==null or (swings.has_animation("Attack") and swings.has_animation("Attack2")),"Party children have no swing animations")
	z.regen_wait=0.;var low:=z.health;z._tick_player(1.)
	verify.call(z.health>low,"Health does not regenerate")
	var best_before: int=int(game.achievements.zombies.best_round)
	z.round_number=12;z.hurt_player(9999.,null)
	var waited:=0.
	while game.phase!="zombies_over" and waited<8.:await game.get_tree().process_frame;waited+=game.get_process_delta_time()
	verify.call(game.phase=="zombies_over" and game.menu.find_child("ZombiesSummary",true,false)!=null,"No result screen after dying")
	verify.call(int(game.achievements.zombies.best_round)>=maxi(best_before,12) and int(game.achievements.zombies.kills)>=1,"Partynacht records are not saved")
	await shot(game,"summary")
	verify.call(game.zombies==null and is_equal_approx(game.player.speed_scale,1.) and is_equal_approx(game.player.gravity_scale,1.),"Partynacht does not clean up")
	verify.call(game.world.find_children("ZombiesWorld","",true,false).filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"Partynacht objects stay in the world")
	game._main_menu()
	DirAccess.remove_absolute(game.achievements.path)
