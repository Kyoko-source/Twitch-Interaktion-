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
	verify.call(ZombiesConfig.WEAPONS.size()==33 and ZombiesConfig.PERKS.size()==12 and ZombiesConfig.PICKUPS.size()>=16,"Partynacht content incomplete: weapons/perks/pickups")
	verify.call(ZombiesConfig.ENEMIES.size()>=10 and ZombiesConfig.BOSSES.size()>=4 and ZombiesConfig.EVENTS.size()>=12,"Partynacht enemies, bosses or events missing")
	verify.call(ZombiesConfig.health(30)>ZombiesConfig.health(5)*5. and ZombiesConfig.enemies_in_round(20)>ZombiesConfig.enemies_in_round(1)*4 and ZombiesConfig.spawn_gap(25)<ZombiesConfig.spawn_gap(1),"Rounds do not escalate")
	var missing: Array=[]
	for row in ZombiesConfig.WEAPONS:
		if not str(row[2]) in ZombiesConfig.SPECIAL_FRAMES and not ResourceLoader.exists("res://assets/zombies-v500/weapon-%s.glb"%str(row[2])):missing.append(row[0])
	for id in ZombiesConfig.ENEMIES:
		if not ResourceLoader.exists(str(ZombiesConfig.ENEMIES[id].model)):missing.append(id)
	for b in ZombiesConfig.BOSSES:
		if not ResourceLoader.exists(str(b.model)):missing.append(b.id)
	verify.call(missing.is_empty(),"Partynacht models missing: "+str(missing))
	# 5.2.6: the round-10 croc was excluded from every export and crashed the game;
	# every enemy and boss model must survive each preset's exclude filter.
	var cut: Array=[]
	var presets:=ConfigFile.new();presets.load("res://export_presets.cfg")
	for section in presets.get_sections():
		if not presets.has_section_key(section,"exclude_filter"):continue
		var web:=str(presets.get_value(section,"platform","")).to_lower().contains("web")
		var patterns:=str(presets.get_value(section,"exclude_filter","")).split(",",false)
		for data in ZombiesConfig.ENEMIES.values()+ZombiesConfig.BOSSES:
			var path:=ZombiesConfig.model_path(data,web).trim_prefix("res://")
			for pattern in patterns:
				if path.matchn(pattern.strip_edges()):cut.append(str(presets.get_value(section,"name",section))+":"+path)
	verify.call(cut.is_empty(),"Partynacht models excluded from an export: "+str(cut))
	# 5.2.3: every pickup has its own recorded line, none falls back to the drone.
	var voices:=["start"]
	for row in ZombiesConfig.PICKUPS:voices.append("pickup_"+str(row[0]))
	var unvoiced:=voices.filter(func(k):return not ResourceLoader.exists(ZombiesAnnouncer.FOLDER+k+".ogg"))
	verify.call(unvoiced.is_empty() and ZombiesAnnouncer.stream_for("pickup_nuke") is AudioStreamOggVorbis and ZombiesAnnouncer.stream_for("pickup_gravity") is AudioStreamOggVorbis,"Recorded announcer lines are missing: "+str(unvoiced))

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
	verify.call(ZombiesMode.voice_paths().size()>=4,"Zombie voices are missing")
	var spoke: bool=z.enemy_sound(dummy,"leap")
	verify.call(spoke and dummy.voice.stream is AudioStreamOggVorbis,"Zombies do not moan or growl")
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
	# 5.2.1: shots pass through the climbing frame's nets but not through walls.
	var net_bodies: Array=[]
	for net_name in ["WestEntryNet","EastFrontNet"]:
		var net_node: Node=game.world.find_child(net_name,true,false)
		if net_node:net_bodies.append_array(net_node.find_children("*","CollisionObject3D",true,false))
	verify.call(not net_bodies.is_empty() and net_bodies.all(func(b):return z.is_net(b)),"Climbing nets are not found as see-through for shots")
	var through: bool=false
	if not net_bodies.is_empty():
		var nb: CollisionObject3D=net_bodies[0];var nb_at:=nb.global_position+Vector3.UP*1.5
		var ray_from:=nb_at+Vector3(2.5,0,0);var ray_to:=nb_at-Vector3(2.5,0,0)
		var plain:=PhysicsRayQueryParameters3D.create(ray_from,ray_to,1)
		var blocked:=game.get_world_3d().direct_space_state.intersect_ray(plain)
		through=blocked.is_empty() or not z.is_net(blocked.collider) or z.shoot_ray(ray_from,ray_to,1,[] as Array[RID],false).is_empty() or not z.is_net(z.shoot_ray(ray_from,ray_to,1,[] as Array[RID],false).collider)
	verify.call(through,"A shot does not pass a climbing net")
	verify.call(not z.is_net(game.player),"The guard counts as a net")
	# 5.2.0: effects, music, signs, health bars and the three party weapons.
	verify.call(ResourceLoader.exists(ZombiesFx.FX+"blood-0.png") and ResourceLoader.exists(ZombiesFx.SFX+"explosion-0.ogg") and z.music_calm.stream is AudioStreamOggVorbis and z.music_dread.stream is AudioStreamOggVorbis,"Partynacht effects or music are missing")
	verify.call(z.music_calm.playing and z.music_dread.playing,"Partynacht music does not play")
	verify.call(z.neon.size()>=z.doors.size()+z.stations.size() and not z.lamps.is_empty(),"Barriers and stations have no neon signs or lamps")
	verify.call(dummy.hp_bar!=null and dummy.hp_show>0.,"A hit guest shows no health bar")
	# 5.2.2: an elite's glow flashes on hits but never runs away (it used to multiply on every hit).
	var shiny:=z._spawn_enemy();shiny.rise=0.;shiny.glow=OmniLight3D.new();shiny.add_child(shiny.glow);shiny.glow_base=1.2;shiny.glow.light_energy=1.2
	for i in range(200):shiny.hit_flash()
	verify.call(shiny.glow.light_energy<=shiny.glow_base*2.5,"Elite glow grows without limit on hits")
	shiny.queue_free();z.enemies.erase(shiny)
	var fx_before:=z.fx.live.size()
	z.fx.explosion(dummy.global_position+Vector3.UP,3.);z.fx.lightning(dummy.global_position+Vector3.UP*3.,dummy.global_position);z.fx.confetti(dummy.global_position,1.)
	verify.call(z.fx.live.size()>=fx_before+8 and not z.fx.decals.scorch.is_empty(),"Explosions, lightning or confetti spawn no effects")
	var aim:=(dummy.global_position+Vector3.UP-cam.global_position).normalized()
	var torch:=z._spawn_enemy();torch.rise=0.;torch.stun=99.;torch.model.position.y=0.
	var torch_at:=cam.global_position+aim*3.;torch_at.y=dummy.global_position.y;torch.global_position=torch_at
	await game.get_tree().physics_frame;await game.get_tree().physics_frame
	# Tough test guests: the flame cone also reaches the dummy behind the torch.
	for tough: ZombieEnemy in [torch,dummy]:tough.max_hp=6000.;tough.hp=6000.
	var torch_hp:=torch.hp
	z.flame_hit(cam.global_position,(torch.global_position+Vector3.UP-cam.global_position).normalized(),40.,"")
	verify.call(torch.hp<torch_hp and torch.burn>0. and z.fx.burning.has(torch.get_instance_id()),"The flamethrower does not set a guest on fire: torch at %s cam %s clear %s hp %.0f/%.0f dead %s"%[str(torch.global_position),str(cam.global_position),str(z.clear_to(cam.global_position,torch,1.)),torch.hp,torch_hp,str(torch.dead)])
	var tesla_hp:=dummy.hp+torch.hp
	z.tesla_shot(cam.global_position,cam.global_position,aim,100.,"")
	verify.call(dummy.hp+torch.hp<tesla_hp,"The tesla coil does not strike the guest in the aim: dummy %s clear %s dead %s"%[str(dummy.global_position),str(z.clear_to(cam.global_position,dummy,1.2)),str(dummy.dead)])
	await shot(game,"tesla")
	z.hud.wave(7,"Die Musik wird lauter.");await frames(game,20);await shot(game,"wave")
	z.cake_shot(cam.global_position+aim*.5,aim,99999.,0)
	var flight:=0
	while not z.projectiles.is_empty() and flight<120:await game.get_tree().physics_frame;flight+=1
	verify.call(z.projectiles.is_empty() and (not is_instance_valid(dummy) or dummy.dead or not is_instance_valid(torch) or torch.dead),"The cake launcher does not explode on guests")
	for id in ["kuchenbrenner","gewitterkind","tortenwerfer"]:
		var holder:=ZombiesArsenal.frame_model(str(ZombiesConfig.weapon(id)[2]))
		verify.call(holder.find_child("Muzzle",true,false)!=null,"Party weapon %s has no muzzle"%id);holder.free()
	z.arsenal.give("ar47",3)
	verify.call(ZombiesConfig.elements(3,"")=="fire+shock+void" and not z.arsenal.glow_mats.is_empty(),"Upgraded guns do not stack elements or glow")
	z.arsenal.slots.remove_at(z.arsenal.current);z.arsenal.equip(0)
	if is_instance_valid(torch) and not torch.dead:z.damage_enemy(torch,99999.,false,"",false)
	if is_instance_valid(dummy) and not dummy.dead:z.damage_enemy(dummy,99999.,false,"",false)
	z.arsenal.give("kuchenbrenner",2);z.arsenal.flame_t=.5;z.fx.flame(z.arsenal.muzzle.global_position,-cam.global_basis.z,true)
	for i in range(12):z.fx.flame(z.arsenal.muzzle.global_position,-cam.global_basis.z,true);await game.get_tree().process_frame
	await shot(game,"effects")
	var marked:=z._spawn_enemy();marked.rise=0.;marked.stun=99.;marked.model.position.y=0.;marked.global_position=torch_at+aim*2.;z.damage_enemy(marked,marked.max_hp*.45,false,"",false)
	await frames(game,10);await shot(game,"hpbar")
	verify.call(marked.hp_show>0. and marked.hp_fill<.95,"The health bar does not follow the damage")
	z.damage_enemy(marked,99999.,false,"",false)
	z.arsenal.slots.remove_at(z.arsenal.current);z.arsenal.equip(0)
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
	# 5.2.4: every perk has its own jingle of 2.5 to 4.5 s, and buying one plays it.
	var no_jingle: Array=[]
	for row in ZombiesConfig.PERKS:
		var tune:=z.perk_jingle(str(row[0]))
		if tune==null or tune.get_length()<2.5 or tune.get_length()>4.5:no_jingle.append(row[0])
	verify.call(no_jingle.is_empty(),"Perk jingles missing or wrong length: "+str(no_jingle))
	verify.call(z.jingle.stream!=null and z.jingle.stream.resource_path.begins_with(ZombiesMode.JINGLES),"Buying a perk plays no jingle")
	# 5.2.5 lag fix: effects share cached materials (a fresh material per muzzle
	# flash stalled ~25 ms on the render thread), and only the nearest lamps cast shadows.
	var cached_before:=ZombiesFx.cache.size()
	for i in range(40):z.fx.muzzle(z.arsenal.muzzle,Color("ffc27a"),1.,game.player.camera);z.tracer(game.player.global_position,game.player.global_position+Vector3.FORWARD*4.,"")
	verify.call(ZombiesFx.cache.size()-cached_before<=6,"Muzzle flashes and tracers still build new materials: +%d"%(ZombiesFx.cache.size()-cached_before))
	var flash_a:=z.fx.cached("muzzle-side|"+Color("ffc27a").to_html(),func():return null)
	verify.call(flash_a is StandardMaterial3D,"Muzzle flash material is not cached")
	z.shadow_clock=0.;z._tick_shadows(0.)
	var lit:=z.shadow_lights.filter(func(l):return is_instance_valid(l) and (l as Light3D).shadow_enabled).size()
	verify.call(not z.shadow_lights.is_empty() and lit<=ZombiesMode.SHADOW_LAMPS,"Partynacht keeps %d shadow lamps on (limit %d)"%[lit,ZombiesMode.SHADOW_LAMPS])
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
	var dimmed: Array=z.shadow_lights.duplicate()
	z.round_number=12;z.hurt_player(9999.,null)
	var waited:=0.
	while game.phase!="zombies_over" and waited<8.:await game.get_tree().process_frame;waited+=game.get_process_delta_time()
	verify.call(game.phase=="zombies_over" and game.menu.find_child("ZombiesSummary",true,false)!=null,"No result screen after dying")
	verify.call(int(game.achievements.zombies.best_round)>=maxi(best_before,12) and int(game.achievements.zombies.kills)>=1,"Partynacht records are not saved")
	await shot(game,"summary")
	verify.call(dimmed.all(func(l):return not is_instance_valid(l) or (l as Light3D).shadow_enabled),"Leaving the Partynacht does not give the lamps their shadows back")
	verify.call(game.zombies==null and is_equal_approx(game.player.speed_scale,1.) and is_equal_approx(game.player.gravity_scale,1.),"Partynacht does not clean up")
	verify.call(game.world.find_children("ZombiesWorld","",true,false).filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"Partynacht objects stay in the world")
	game._main_menu()
	DirAccess.remove_absolute(game.achievements.path)
