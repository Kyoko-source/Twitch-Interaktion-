class_name ZombiesMode
extends Node3D

# After Play: Partynacht (5.0.0). Round-based survival in Happyland: buy
# barriers, wall guns, perks, ammo, the chaos gift box and the flesh machine;
# survive party zombies, elites, bosses, events and a world that comes apart.
signal ended

const STATION_LAYER:=1<<20
var g: Node3D
var w: PlayWorld
var player: NightGuard
var nav:=ZombiesNav.new()
var arsenal: ZombiesArsenal
var hud: ZombiesHud
var rng:=RandomNumberGenerator.new()
var root3d: Node3D

# Run state.
var running:=false
var over:=false
var round_number:=0
var points:=0
var earned:=0
var health:=100.0
var max_health:=100.0
var regen_wait:=0.0
var to_spawn:=0
var spawn_clock:=0.0
var break_clock:=0.0
var in_break:=true
var enemies: Array=[]
var bosses: Array=[]
var zones_open:={}
var doors: Array=[]
var stations: Array=[]
var perks: Array=[]
var perk_limit:=ZombiesConfig.PERK_LIMIT
var active:={}
var pickups: Array=[]
var pickups_this_round:=0
var projectiles: Array=[]
var effects: Array=[]
var event:=""
var chain:=0
var chain_clock:=0.0
var kill_times: Array=[]
var seconds:=0.0
var stats:={}
var box_spot:=0
var box_uses:=0
var box_state:={}
var box_node: Node3D
var upgrade_state:={}
var lights: Array=[]
var alarm_lights: Array=[]
var env: Environment
var env_base:={}
var debris: Array=[]
var rifts: Array=[]
var spawn_cells:={}
var sense_clock:=0.0
var aim_held:=false
var fire_held:=false
var prompt_text:=""
var focus: Dictionary={}
var slowed:=0.0
var shake:=0.0

# ---------------------------------------------------------------- build
func build(game: Node3D) -> void:
	g=game;w=g.world;player=g.player;name="ZombiesMode";rng.randomize()
	root3d=Node3D.new();root3d.name="ZombiesWorld";w.add_child(root3d)
	for door in ZombiesConfig.DOORS:_door(door)
	for row in ZombiesConfig.STATIONS:_station(row)
	box_spot=0;_place_box()
	arsenal=ZombiesArsenal.new();arsenal.build(self,player.camera)
	hud=ZombiesHud.new();add_child(hud);hud.build(g)
	for light: Light3D in w.find_children("*","Light3D",true,false):lights.append([light,light.light_energy,light.light_color])
	for zone in ZombiesConfig.ZONES:
		var r: Array=ZombiesConfig.ZONES[zone].rects[0]
		var alarm:=OmniLight3D.new();alarm.light_color=Color("ff1a12");alarm.omni_range=11.;alarm.light_energy=0.;alarm.shadow_enabled=false;root3d.add_child(alarm)
		alarm.global_position=Vector3((r[0]+r[1])*.5,3.,(r[2]+r[3])*.5);alarm_lights.append(alarm)
	env=get_world_3d().environment
	if env:env_base={"fog":env.fog_light_color,"density":env.fog_density,"ambient":env.ambient_light_color}

func _build_nav() -> void:
	nav.build(get_world_3d().direct_space_state,[player.get_rid()])
	spawn_cells.clear()
	for id in nav.heights:
		var z:=ZombiesConfig.zone_at(nav.point(id))
		if z!="":
			if not spawn_cells.has(z):spawn_cells[z]=[]
			spawn_cells[z].append(id)

func _sign(parent: Node3D, text: String, at: Vector3, color: Color, size_px: int=48) -> Label3D:
	var label:=Label3D.new();label.text=text;label.font=load("res://assets/Oswald.ttf");label.font_size=size_px;label.pixel_size=.004;label.outline_size=10
	label.modulate=color;label.outline_modulate=Color(0,0,0,.9);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false;label.position=at;parent.add_child(label);return label

func _door(spec: Dictionary) -> void:
	var node:=Node3D.new();node.name="Barrier_"+str(spec.id);root3d.add_child(node)
	var a: Vector3=spec.from;var b: Vector3=spec.to;var length:=a.distance_to(b);var count:=maxi(1,ceili(length/2.));var step:=length/count
	var dir:=(b-a).normalized();var yaw:=atan2(dir.x,dir.z)+PI/2
	var panels: Array=[]
	for i in range(count):
		var p:=(load("res://assets/zombies-v500/fence-panel.glb") as PackedScene).instantiate() as Node3D
		node.add_child(p);p.global_position=a+dir*(step*(i+.5));p.rotation.y=yaw;p.scale=Vector3(step/2.,1.,1.)
		var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.,2.4,.16);shape.shape=box;shape.position.y=1.2;body.add_child(shape);p.add_child(body)
		body.collision_layer=1|STATION_LAYER;body.set_meta("zombie_station",doors.size())
		panels.append(p)
	var mid:=(a+b)*.5
	var label:=_sign(node,"%s\n%d"%[str(spec.name).to_upper(),int(spec.cost)],node.to_local(mid)+Vector3(0,2.45,0),Color("ffd23a"),40)
	doors.append({"spec":spec,"node":node,"panels":panels,"open":false,"label":label,"mid":mid})

func _yaw_to_zone(p: Vector3) -> float:
	var z:=ZombiesConfig.zone_at(p);var r: Array=ZombiesConfig.ZONES[z].rects[0] if z!="" else [p.x-1,p.x+1,p.z-1,p.z+1]
	var c:=Vector3((r[0]+r[1])*.5,0,(r[2]+r[3])*.5)-p
	return atan2(c.x,c.z)

func _station(row: Array) -> void:
	var kind: String=row[0];var id: String=row[1];var at: Vector3=row[2]
	var node:=Node3D.new();node.name="Station_%s_%s"%[kind,id];root3d.add_child(node);node.global_position=at;node.rotation.y=_yaw_to_zone(at)
	var size_value:=Vector3(1,1.2,1)
	var light:=OmniLight3D.new();light.omni_range=3.2;light.light_energy=1.4;light.shadow_enabled=false;light.position=Vector3(0,1.6,.8);node.add_child(light)
	match kind:
		"perk":
			var row_p:=ZombiesConfig.perk(id)
			var m:=(load("res://assets/zombies-v500/perk-machine.glb") as PackedScene).instantiate() as Node3D;node.add_child(m)
			_tint(m,"PerkGlow",row_p[3]);light.light_color=row_p[3];size_value=Vector3(.95,2.1,.75)
			_sign(node,"%s\n%d"%[str(row_p[1]).to_upper(),int(row_p[2])],Vector3(0,2.55,0),row_p[3],44)
		"ammo":
			var m2:=(load("res://assets/zombies-v500/ammo-crate.glb") as PackedScene).instantiate() as Node3D;node.add_child(m2)
			light.light_color=Color("ffb43a");light.position=Vector3(0,1.,.6);size_value=Vector3(.95,.6,.6)
			_sign(node,"MUNITION",Vector3(0,1.05,0),Color("ffcf6a"),36)
		"wall":
			var row_w:=ZombiesConfig.weapon(id)
			var board:=w.box(node,Vector3(0,1.25,0),Vector3(1.15,.62,.06),w.mat(Color("2a2118"),load("res://assets/wood.png"),.8))
			board.name="WallBoard"
			w.box(node,Vector3(0,.6,-.05),Vector3(.08,1.2,.08),w.mat(Color("2a2118"),load("res://assets/wood.png"),.8))
			var gun:=(load("res://assets/zombies-v500/weapon-%s.glb"%str(row_w[2])) as PackedScene).instantiate() as Node3D;node.add_child(gun)
			gun.position=Vector3(.12 if str(row_w[2]) in ["pistol","revolver"] else .35,1.25,.06);gun.rotation=Vector3(0,PI/2,0);gun.scale=Vector3.ONE*(1.6 if str(row_w[2]) in ["pistol","revolver"] else 1.15)
			_tint(gun,"GunAccent",row_w[14]);light.light_color=Color("9fe0ff");light.light_energy=.9;size_value=Vector3(1.2,1.6,.3)
			_sign(node,"%s\n%d"%[str(row_w[1]),int(row_w[12])],Vector3(0,1.85,0),Color("e8f4ff"),34)
		"upgrade":
			var m3:=(load("res://assets/zombies-v500/flesh-machine.glb") as PackedScene).instantiate() as Node3D;node.add_child(m3)
			light.light_color=Color("ff2a1a");light.light_energy=2.;size_value=Vector3(1.3,1.8,1.1)
			_sign(node,"FLEISCHMASCHINE",Vector3(0,2.1,0),Color("ff5a4a"),40)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size_value;shape.shape=box;shape.position.y=size_value.y*.5;body.add_child(shape);node.add_child(body)
	body.collision_layer=1|STATION_LAYER
	stations.append({"kind":kind,"id":id,"node":node,"light":light,"at":at})

func _tint(node: Node3D, material_name: String, color: Color) -> void:
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		for s in range(mesh.mesh.get_surface_count()):
			var m:=mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if m and m.resource_name==material_name:
				var copy:=m.duplicate() as StandardMaterial3D;copy.albedo_color=color
				if copy.emission_enabled:copy.emission=color
				mesh.set_surface_override_material(s,copy)

func _place_box() -> void:
	if is_instance_valid(box_node):
		for i in range(stations.size()):
			if stations[i].kind=="box":stations.remove_at(i);break
		box_node.queue_free()
	var at: Vector3=ZombiesConfig.BOX_SPOTS[box_spot]
	box_node=Node3D.new();box_node.name="ChaosBox";root3d.add_child(box_node);box_node.global_position=at;box_node.rotation.y=_yaw_to_zone(at)
	var m:=(load("res://assets/zombies-v500/chaos-box.glb") as PackedScene).instantiate() as Node3D;box_node.add_child(m)
	var light:=OmniLight3D.new();light.light_color=Color("9a4aff");light.omni_range=4.;light.light_energy=2.;light.position=Vector3(0,1.5,0);box_node.add_child(light)
	var beam:=MeshInstance3D.new();var cyl:=CylinderMesh.new();cyl.top_radius=.25;cyl.bottom_radius=.4;cyl.height=12.;beam.mesh=cyl;beam.position.y=6.
	var bm:=StandardMaterial3D.new();bm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;bm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;bm.albedo_color=Color(.6,.3,1.,.12);bm.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;beam.material_override=bm;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;box_node.add_child(beam)
	_sign(box_node,"CHAOS-GESCHENK\n%d"%ZombiesConfig.BOX_PRICE,Vector3(0,1.6,0),Color("d2a6ff"),40)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.5,.9,.9);shape.shape=box;shape.position.y=.45;body.add_child(shape);box_node.add_child(body)
	body.collision_layer=1|STATION_LAYER
	stations.append({"kind":"box","id":"","node":box_node,"light":light,"at":at})
	box_state={}

# ---------------------------------------------------------------- run
func start() -> void:
	running=false;over=false;round_number=0;points=ZombiesConfig.START_POINTS;earned=0;max_health=ZombiesConfig.PLAYER_HEALTH;health=max_health
	zones_open={ZombiesConfig.START_ZONE:true};perks=[];perk_limit=ZombiesConfig.PERK_LIMIT;active={};seconds=0.;event=""
	stats={"kills":0,"headshots":0,"bosses":0,"pickups":0,"perks":0,"elites":0,"points":0,"doors":0,"box":0,"upgrades":0}
	await get_tree().physics_frame
	_build_nav()
	player.global_position=ZombiesConfig.SPAWN_POINT;player.rotation=Vector3(0,PI*.5,0);player.camera.rotation=Vector3.ZERO
	player.speed_scale=1.;player.gravity_scale=1.
	arsenal.give(ZombiesConfig.START_WEAPON)
	hud.set_perks(perks)
	in_break=true;break_clock=4.
	_announce("PARTYNACHT","Die Gäste sind schon da. Überlebe, so lange du kannst.","start",Color("ff3a3a"),5.)
	player.capture()
	running=true

func _next_round() -> void:
	round_number+=1;in_break=false;to_spawn=ZombiesConfig.enemies_in_round(round_number);spawn_clock=1.;pickups_this_round=0
	_end_event()
	if round_number>=ZombiesConfig.EVENT_FROM and rng.randf()<ZombiesConfig.EVENT_CHANCE+(.12 if round_number>=ZombiesConfig.NIGHTMARE_FROM else 0.):
		var pool:=ZombiesConfig.EVENTS.keys()
		if round_number<ZombiesConfig.FIRST_BOSS:pool.erase("double_boss")
		_start_event(pool[rng.randi_range(0,pool.size()-1)])
	var boss_round:=round_number>=ZombiesConfig.FIRST_BOSS and (round_number-ZombiesConfig.FIRST_BOSS)%ZombiesConfig.BOSS_EVERY==0
	if boss_round or event=="double_boss":
		var count:=2 if event=="double_boss" or round_number>=ZombiesConfig.HELL_FROM else 1
		for i in range(count):_spawn_boss(int(round_number/float(ZombiesConfig.BOSS_EVERY))+i)
	else:
		_announce("RUNDE %d"%round_number,_round_line(),"round",Color("ff3a3a"),3.5)
	for alarm in alarm_lights:(alarm as OmniLight3D).light_energy=3.5
	if round_number==ZombiesConfig.REALITY_FROM:_announce("DIE REALITÄT REISST","Ab jetzt ist nichts mehr, wie es war.","reality",Color("8aff6a"),5.)

func _round_line() -> String:
	if round_number==ZombiesConfig.FIRST_ELITES:return "Die ersten besonderen Gäste kommen."
	if round_number>=ZombiesConfig.HELL_FROM:return "Hölle und Himmel feiern zusammen."
	if round_number>=ZombiesConfig.NIGHTMARE_FROM:return "Albtraumphase."
	return ["Sie lachen schon.","Noch mehr Gäste.","Die Musik wird lauter.","Keiner geht nach Hause.","Hörst du die Kerzen?"][round_number%5]

# Called every frame by the game while the mode runs.
func tick(delta: float) -> void:
	if not running:return
	seconds+=delta
	var dt:=delta
	fire_held=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	aim_held=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	arsenal.tick(dt,fire_held,aim_held)
	# The shift torch hand would hold nothing here; the gun takes its place.
	if player.torch_body.visible:player.torch_body.hide()
	_tick_rounds(dt)
	_tick_player(dt)
	_tick_pickups(dt)
	_tick_projectiles(dt)
	_tick_effects(dt)
	_tick_world(dt)
	_tick_stations(dt)
	_tick_focus()
	hud.tick(dt,_hud_data())

func _tick_rounds(delta: float) -> void:
	enemies=enemies.filter(func(e):return is_instance_valid(e) and not e.dead)
	bosses=bosses.filter(func(e):return is_instance_valid(e) and not e.dead)
	if in_break:
		break_clock-=delta
		if break_clock<=0.:_next_round()
		return
	spawn_clock-=delta
	var cap:=ZombiesConfig.MAX_ALIVE+(8 if event=="clones" else 0)
	if to_spawn>0 and spawn_clock<=0. and enemies.size()<cap:
		spawn_clock=ZombiesConfig.spawn_gap(round_number)*rng.randf_range(.7,1.2)
		_spawn_enemy();to_spawn-=1
		if event=="clones" and to_spawn>0:_spawn_enemy(true)
	if to_spawn<=0 and enemies.is_empty():
		in_break=true;break_clock=ZombiesConfig.ROUND_BREAK
		_add_points(ZombiesConfig.POINTS_ROUND+round_number*10,false)
		_announce("RUNDE %d ÜBERSTANDEN"%round_number,"Atme. Kauf ein. Sie kommen wieder.","round_end",Color("f2e6b4"),3.5)
		for alarm in alarm_lights:(alarm as OmniLight3D).light_energy=0.

func _spawn_cell() -> Vector3:
	var p:=player.global_position;var best:=Vector3.INF
	for attempt in range(30):
		var zone_list:=zones_open.keys();var zone: String=zone_list[rng.randi_range(0,zone_list.size()-1)]
		if not spawn_cells.has(zone):continue
		var cells: Array=spawn_cells[zone];var c: Vector2i=cells[rng.randi_range(0,cells.size()-1)]
		if not nav.walkable(c):continue
		var at:=nav.point(c);var d:=at.distance_to(p)
		if d>9. and d<34.:return at
		if d>6. and best==Vector3.INF:best=at
	if not rifts.is_empty() and rng.randf()<.4:return (rifts[rng.randi_range(0,rifts.size()-1)] as Node3D).global_position
	return best if best!=Vector3.INF else p+Vector3(10,0,0)

func _pick_kind() -> String:
	var elite_pool:=ZombiesConfig.elites_for(round_number)
	if event=="alien":elite_pool.append("alien");elite_pool.append("alien")
	if event in ["laughter"]:elite_pool+=["screamer","screamer"]
	if event=="poison":elite_pool+=["spitter","spitter"]
	var chance:=ZombiesConfig.elite_chance(round_number)*(1.6 if round_number>=ZombiesConfig.MULTI_ELITES else 1.)
	if not elite_pool.is_empty() and rng.randf()<chance:return elite_pool[rng.randi_range(0,elite_pool.size()-1)]
	var r:=rng.randf()
	if round_number>3 and r<.16:return "sprinter"
	if round_number>6 and r<.27:return "crawler"
	return "party" if rng.randf()<.55 else "party_b"

func _spawn_enemy(clone: bool=false) -> ZombieEnemy:
	var kind:=_pick_kind();var data: Dictionary=ZombiesConfig.ENEMIES[kind]
	var e:=ZombieEnemy.new();root3d.add_child(e);e.global_position=_spawn_cell()
	e.setup(self,kind,data,round_number,false,rng.randi())
	if event=="blood_moon":e.speed*=1.3
	if event=="poison":e.max_hp*=1.2;e.hp=e.max_hp
	if clone:e.clone=true;e.max_hp*=.5;e.hp=e.max_hp;_shadow(e)
	enemies.append(e);_rise_fx(e.global_position)
	return e

func _shadow(e: ZombieEnemy) -> void:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(.05,.0,.08,.85);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.emission_enabled=true;m.emission=Color(.3,0,.5)
	for mesh: MeshInstance3D in e.model.find_children("*","MeshInstance3D",true,false):mesh.material_override=m

func _spawn_boss(index: int) -> void:
	var data: Dictionary=ZombiesConfig.BOSSES[posmod(index,ZombiesConfig.BOSSES.size())]
	var e:=ZombieEnemy.new();root3d.add_child(e);e.global_position=_spawn_cell()
	e.setup(self,str(data.id),data,round_number,true,rng.randi())
	e.max_hp=ZombiesConfig.health(round_number)*float(data.hp);e.hp=e.max_hp
	enemies.append(e);bosses.append(e);to_spawn=maxi(to_spawn/2,4)
	_rise_fx(e.global_position);shake=1.
	_announce(str(data.name),"Ein besonderer Gast hat Geburtstag.","boss",Color("ff1a1a"),5.)

# ---------------------------------------------------------------- damage
func damage_multiplier() -> float:
	return (2. if has_pickup("damage") else 1.)*(1.25 if event=="blood_moon" else 1.)

func hit_enemy(e: ZombieEnemy, amount: float, head: bool, headshot: float, at: Vector3, element: String) -> void:
	if e.dead:return
	var value:=amount*damage_multiplier()
	if head:value*=headshot*(1.6 if has_perk("zerreisser") else 1.)
	if has_pickup("crit") and rng.randf()<.25:value*=3.;_spark(at,Color("ff5af2"),.4)
	if has_pickup("insta_kill"):value=maxf(value,e.max_hp*(.06 if e.boss else 10.))
	_add_points(ZombiesConfig.POINTS_HIT,true)
	_blood(at,.6 if not head else 1.)
	match element:
		"fire":e.burn=3.
		"shock":_chain(e,value*.35,2)
		"void":_blast(at,2.2,value*.4,Color("b05aff"),e)
		"phase":e.slow=.55
	if has_perk("flackergeist") and rng.randf()<.15:_chain(e,value*.5,2)
	if has_pickup("chain") and rng.randf()<.35:_chain(e,value*.6,3)
	hud.hit(false,head)
	damage_enemy(e,value,head,element,true)

func damage_enemy(e: ZombieEnemy, amount: float, head: bool, element: String, credit: bool) -> void:
	if e.dead:return
	e.hp-=amount;e.hit_flash()
	if e.hp<=0.:_kill(e,head,element,credit)

func _kill(e: ZombieEnemy, head: bool, element: String, credit: bool) -> void:
	var at:=e.global_position+Vector3.UP
	e.die(element in ["void","rift","nuke"] or has_pickup("fire_kills"))
	stats.kills=int(stats.kills)+1
	if head:stats.headshots=int(stats.headshots)+1
	kill_times.append(seconds)
	if credit:
		var reward:=ZombiesConfig.POINTS_HEADSHOT_KILL if head else ZombiesConfig.POINTS_MELEE_KILL if element=="melee" else ZombiesConfig.POINTS_KILL
		if e.elite and not e.boss:reward+=ZombiesConfig.POINTS_ELITE;stats.elites=int(stats.elites)+1
		chain=chain+1 if chain_clock>0. else 1;chain_clock=ZombiesConfig.CHAIN_WINDOW
		if chain>=5:reward+=chain*10
		_add_points(reward,true)
		hud.hit(true,head)
	if e.boss:
		stats.bosses=int(stats.bosses)+1;_add_points(ZombiesConfig.POINTS_BOSS,true)
		_announce("GAST VERABSCHIEDET","Die Feier geht weiter.","boss_down",Color("ffd23a"),4.)
		for i in range(2):_drop_pickup(e.global_position+Vector3(rng.randf_range(-1.5,1.5),0,rng.randf_range(-1.5,1.5)),true)
		perk_limit=mini(perk_limit+1,ZombiesConfig.PERKS.size())
	elif rng.randf()<ZombiesConfig.PICKUP_CHANCE*(2. if event=="birthday" else 1.) and pickups_this_round<ZombiesConfig.PICKUPS_PER_ROUND+(2 if event=="birthday" else 0):
		_drop_pickup(e.global_position,false)
	if has_pickup("fire_kills"):_blast(at,3.,120.+round_number*20.,Color("ff6a1a"),e)
	_blood(at,1.6)

func _chain(source: ZombieEnemy, amount: float, jumps: int) -> void:
	var from:=source.global_position+Vector3.UP*1.2;var done:=[source]
	for j in range(jumps):
		var best: ZombieEnemy=null;var best_d:=7.
		for e: ZombieEnemy in enemies:
			if e in done or e.dead:continue
			var d:=e.global_position.distance_to(from)
			if d<best_d:best_d=d;best=e
		if not best:return
		var to:=best.global_position+Vector3.UP*1.2;_bolt(from,to);done.append(best)
		damage_enemy(best,amount,false,"shock",true);from=to

func _blast(at: Vector3, radius: float, amount: float, color: Color, skip: ZombieEnemy=null) -> void:
	_flash(at,color,radius)
	for e: ZombieEnemy in enemies.duplicate():
		if e==skip or e.dead:continue
		var d:=e.global_position.distance_to(at)
		if d<radius:damage_enemy(e,amount*(1.-d/radius*.6),false,"blast",true)

func melee(from: Vector3, dir: Vector3, amount: float) -> void:
	var best: ZombieEnemy=null;var best_d:=1.9
	for e: ZombieEnemy in enemies:
		if e.dead:continue
		var to:=e.global_position+Vector3.UP-from;var d:=to.length()
		if d<best_d and to.normalized().dot(dir)>.4:best_d=d;best=e
	if best:
		_blood(best.global_position+Vector3.UP*1.2,1.2);hud.hit(false,false);_add_points(ZombiesConfig.POINTS_HIT,true)
		best.velocity+=dir*4.;damage_enemy(best,amount*damage_multiplier(),false,"melee",true)

func hurt_player(amount: float, source: Node3D) -> void:
	if over or not running:return
	if has_pickup("shield"):_spark(player.global_position+Vector3.UP,Color("ffb6d9"),.6);return
	if has_perk("grabesschritt") and rng.randf()<.28:return
	var value:=amount
	if has_perk("pluesch_segen") and _recent_kills(6.)>=5:value*=.5
	health-=value;regen_wait=ZombiesConfig.REGEN_DELAY*(.5 if has_perk("todesatem") else 1.);shake=maxf(shake,.45)
	if source:player.velocity+=(player.global_position-source.global_position).normalized()*3.
	if health<=0.:_game_over()

func _recent_kills(window: float) -> int:
	kill_times=kill_times.filter(func(t):return seconds-float(t)<10.)
	return kill_times.filter(func(t):return seconds-float(t)<window).size()

func _tick_player(delta: float) -> void:
	chain_clock-=delta
	regen_wait-=delta
	if regen_wait<=0. and health<max_health:health=minf(health+ZombiesConfig.REGEN_RATE*(2. if has_perk("todesatem") else 1.)*delta,max_health)
	slowed=maxf(slowed-delta,0.)
	player.speed_scale=(1.3 if has_perk("hoellenlauf") else 1.)*(1.3 if has_pickup("bloodrush") else 1.)*(.6 if slowed>0. else 1.)
	player.gravity_scale=.35 if event=="gravity" else 1.
	if shake>0.:
		shake=maxf(shake-delta*2.,0.);player.camera.rotation.z=sin(seconds*60.)*shake*.02
	elif player.camera.rotation.z!=0.:player.camera.rotation.z=lerpf(player.camera.rotation.z,0.,.2)
	if player.global_position.y<-4.:player.global_position=ZombiesConfig.SPAWN_POINT

# ---------------------------------------------------------------- enemy hooks
func player_position() -> Vector3:
	return player.global_position

func player_hidden() -> bool:
	return has_pickup("invisible")

func enemy_time_scale() -> float:
	return (.4 if has_pickup("time") else 1.)*(.55 if has_pickup("slowdown") else 1.)*(.7 if event=="time" else 1.)

func gravity_scale() -> float:
	return .35 if event=="gravity" or has_pickup("gravity") else 1.

func line_clear(a: Vector3, b: Vector3) -> bool:
	var q:=PhysicsRayQueryParameters3D.create(a,b,1);q.exclude=[player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func recover_enemy(e: ZombieEnemy) -> void:
	e.global_position=_spawn_cell();e.velocity=Vector3.ZERO

func spit(_e: ZombieEnemy, from: Vector3, to: Vector3, heavy: bool=false) -> void:
	var dir:=(to-from).normalized();var orb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.12 if not heavy else .25;sphere.height=sphere.radius*2.;orb.mesh=sphere
	var m:=StandardMaterial3D.new();m.albedo_color=Color("8aff4a");m.emission_enabled=true;m.emission=Color("6aff2a");m.emission_energy_multiplier=3.;orb.material_override=m
	root3d.add_child(orb);orb.global_position=from
	var light:=OmniLight3D.new();light.light_color=Color("8aff4a");light.omni_range=2.;orb.add_child(light)
	projectiles.append({"node":orb,"vel":dir*(12. if not heavy else 9.),"dmg":ZombiesConfig.damage(round_number)*(.6 if not heavy else 1.4),"life":3.,"hostile":true})

func scream(e: ZombieEnemy) -> void:
	_flash(e.global_position+Vector3.UP*1.5,Color("ff4aa0"),6.)
	for other: ZombieEnemy in enemies:
		if other.global_position.distance_to(e.global_position)<9.:other.buffed=3.5
	if e.global_position.distance_to(player.global_position)<12.:shake=maxf(shake,.35)

func teleport_near(e: ZombieEnemy) -> void:
	var p:=player.global_position;var back:=player.global_basis.z
	for attempt in range(10):
		var at:=p+back*rng.randf_range(3.,5.)+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2))
		var c:=nav.nearest(at)
		if c.x!=999999 and nav.point(c).distance_to(at)<1.:
			_flash(e.global_position+Vector3.UP,Color("8a6aff"),2.5);e.global_position=nav.point(c);_flash(e.global_position+Vector3.UP,Color("8a6aff"),2.5);return

func enemy_sound(_e: ZombieEnemy, _kind: String) -> void:
	pass

func boss_phase(e: ZombieEnemy, phase: int) -> void:
	_announce("ER WIRD WÜTEND" if phase==1 else "LETZTE KERZE","%s verändert sich."%str(e.spec.get("name","Der Gast")),"boss_phase",Color("ff2a2a"),3.)
	for i in range(2+phase*2):_spawn_enemy()

func boss_attack(e: ZombieEnemy, kind: String) -> void:
	match kind:
		"summon":
			for i in range(3+e.boss_phase*2):
				var minion:=_spawn_enemy();minion.global_position=e.global_position+Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3))
		"shockwave":
			_ring(e.global_position,7.,Color("ff2a2a"))
			if e.global_position.distance_to(player.global_position)<7. and player.is_on_floor():hurt_player(e.dmg*.8,e)
			shake=maxf(shake,.6)
		"charge":shake=maxf(shake,.3)

# ---------------------------------------------------------------- shots & fx
func tracer(from: Vector3, to: Vector3, element: String) -> void:
	var length:=from.distance_to(to)
	if length<.3:return
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.012,.012,length);mesh.mesh=box
	var color: Color=Color("ffe0a0") if element=="" else {"fire":Color("ff6a1a"),"shock":Color("6af2ff"),"void":Color("b05aff"),"phase":Color("8a5cff")}.get(element,Color("ffe0a0"))
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mesh.material_override=m;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root3d.add_child(mesh);mesh.global_position=(from+to)*.5;mesh.look_at(to,Vector3.UP if absf((to-from).normalized().y)<.98 else Vector3.RIGHT)
	effects.append({"node":mesh,"life":.06,"fade":m})

func impact(at: Vector3, normal: Vector3) -> void:
	_spark(at+normal*.02,Color("ffd8a0"),.15)

func _particles(at: Vector3, color: Color, amount: int, speed_value: float, size_value: float, life: float) -> void:
	var p:=CPUParticles3D.new();p.one_shot=true;p.emitting=true;p.amount=amount;p.lifetime=life;p.explosiveness=.95
	p.direction=Vector3.UP;p.spread=180.;p.initial_velocity_min=speed_value*.4;p.initial_velocity_max=speed_value;p.gravity=Vector3(0,-9.,0)
	var q:=QuadMesh.new();q.size=Vector2.ONE*size_value;p.mesh=q
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;q.material=m
	root3d.add_child(p);p.global_position=at;effects.append({"node":p,"life":life+.2})

func _blood(at: Vector3, amount: float) -> void:
	_particles(at,Color(.45,0,.02),int(10*amount)+4,3.5*amount,.06,.6)
	if round_number>=ZombiesConfig.REALITY_FROM and rng.randf()<.3:_particles(at,Color("44ff8a"),6,2.5,.05,.5)

func _spark(at: Vector3, color: Color, size_value: float) -> void:
	_particles(at,color,6,2.,.03,.25)
	var light:=OmniLight3D.new();light.light_color=color;light.omni_range=1.5+size_value*3.;light.light_energy=2.;root3d.add_child(light);light.global_position=at;effects.append({"node":light,"life":.08,"light":2.})

func _flash(at: Vector3, color: Color, radius: float) -> void:
	var light:=OmniLight3D.new();light.light_color=color;light.omni_range=radius*2.;light.light_energy=6.;root3d.add_child(light);light.global_position=at;effects.append({"node":light,"life":.35,"light":6.})
	var orb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;orb.mesh=sphere
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color(color.r,color.g,color.b,.5);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;m.cull_mode=BaseMaterial3D.CULL_DISABLED;orb.material_override=m
	root3d.add_child(orb);orb.global_position=at;orb.scale=Vector3.ONE*.2;effects.append({"node":orb,"life":.35,"grow":radius,"fade":m})
	_particles(at,color,24,7.,.08,.7)

func _ring(at: Vector3, radius: float, color: Color) -> void:
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.9;torus.outer_radius=1.;ring.mesh=torus
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;ring.material_override=m
	root3d.add_child(ring);ring.global_position=at+Vector3.UP*.1;ring.scale=Vector3(.3,.3,.3);effects.append({"node":ring,"life":.5,"grow":radius,"fade":m,"flat":true})

func _bolt(a: Vector3, b: Vector3) -> void:
	var points:=[a]
	for i in range(1,6):points.append(a.lerp(b,i/6.)+Vector3(rng.randf_range(-.25,.25),rng.randf_range(-.25,.25),rng.randf_range(-.25,.25)))
	points.append(b)
	for i in range(points.size()-1):tracer(points[i],points[i+1],"shock")

func _rise_fx(at: Vector3) -> void:
	_particles(at+Vector3.UP*.1,Color(.25,.2,.18),14,2.5,.12,.9)
	var light:=OmniLight3D.new();light.light_color=Color("ff2a1a") if round_number<ZombiesConfig.REALITY_FROM else Color("44ff8a");light.omni_range=3.;light.light_energy=2.5;root3d.add_child(light);light.global_position=at+Vector3.UP*.4;effects.append({"node":light,"life":.9,"light":2.5})

func rift_shot(from: Vector3, dir: Vector3, amount: float) -> void:
	var orb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.18;sphere.height=.36;orb.mesh=sphere
	var m:=StandardMaterial3D.new();m.albedo_color=Color("44ff8a");m.emission_enabled=true;m.emission=Color("44ff8a");m.emission_energy_multiplier=6.;orb.material_override=m
	root3d.add_child(orb);orb.global_position=from
	var light:=OmniLight3D.new();light.light_color=Color("44ff8a");light.omni_range=4.;light.light_energy=3.;orb.add_child(light)
	projectiles.append({"node":orb,"vel":dir*34.,"dmg":amount,"life":2.5,"hostile":false})

func _tick_projectiles(delta: float) -> void:
	var space:=get_world_3d().direct_space_state
	for p in projectiles.duplicate():
		var node: Node3D=p.node
		if not is_instance_valid(node):projectiles.erase(p);continue
		p.life=float(p.life)-delta
		var from:=node.global_position;var to:=from+(p.vel as Vector3)*delta
		if p.hostile:
			(p.vel as Vector3).y-=2.*delta
			if to.distance_to(player.global_position+Vector3.UP*1.1)<.7:
				hurt_player(float(p.dmg),null);slowed=2.;_particles(to,Color("8aff4a"),12,3.,.06,.5);node.queue_free();projectiles.erase(p);continue
		var q:=PhysicsRayQueryParameters3D.create(from,to,1|(0 if p.hostile else ZombieEnemy.LAYER_BODY|ZombieEnemy.LAYER_HEAD));q.collide_with_areas=not p.hostile;q.exclude=[player.get_rid()]
		var hit:=space.intersect_ray(q)
		if not hit.is_empty() or float(p.life)<=0.:
			var at: Vector3=hit.position if not hit.is_empty() else to
			if p.hostile:_particles(at,Color("8aff4a"),10,2.,.06,.5)
			else:_blast(at,4.5,float(p.dmg),Color("44ff8a"));_chain_from(at,float(p.dmg)*.4);shake=maxf(shake,.25)
			node.queue_free();projectiles.erase(p);continue
		node.global_position=to

func _chain_from(at: Vector3, amount: float) -> void:
	var near:=enemies.filter(func(e):return not e.dead and e.global_position.distance_to(at)<9.)
	for i in range(mini(3,near.size())):
		_bolt(at,(near[i] as ZombieEnemy).global_position+Vector3.UP);damage_enemy(near[i],amount,false,"rift",true)

func _tick_effects(delta: float) -> void:
	for fx in effects.duplicate():
		var node: Node3D=fx.node
		if not is_instance_valid(node):effects.erase(fx);continue
		var total: float=fx.get("total",fx.life);fx.total=total
		fx.life=float(fx.life)-delta;var k:=clampf(1.-float(fx.life)/total,0.,1.)
		if fx.has("light"):(node as OmniLight3D).light_energy=float(fx.light)*(1.-k)
		if fx.has("grow"):
			var s:=lerpf(.2,float(fx.grow),k)
			node.scale=Vector3(s,.3 if fx.get("flat",false) else s,s)
		if fx.has("fade"):var c:=(fx.fade as StandardMaterial3D).albedo_color;c.a=(1.-k)*.6;(fx.fade as StandardMaterial3D).albedo_color=c
		if float(fx.life)<=0.:node.queue_free();effects.erase(fx)

# ---------------------------------------------------------------- pickups
func has_pickup(id: String) -> bool:
	return float(active.get(id,0.))>0.

func has_perk(id: String) -> bool:
	return id in perks

func _drop_pickup(at: Vector3, force: bool) -> void:
	if not force:pickups_this_round+=1
	var row: Array=ZombiesConfig.PICKUPS[rng.randi_range(0,ZombiesConfig.PICKUPS.size()-1)]
	var node:=Node3D.new();node.name="Pickup_"+str(row[0]);root3d.add_child(node);node.global_position=Vector3(at.x,.0,at.z)
	var color: Color=row[2]
	var glyph:=Label3D.new();glyph.text=str(row[4]);glyph.font_size=150;glyph.pixel_size=.004;glyph.modulate=color;glyph.outline_size=14;glyph.outline_modulate=Color(0,0,0,.8);glyph.billboard=BaseMaterial3D.BILLBOARD_ENABLED;glyph.position.y=1.;glyph.no_depth_test=true;node.add_child(glyph)
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.42;torus.outer_radius=.5;ring.mesh=torus;ring.position.y=1.
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color;m.emission_enabled=true;m.emission=color;ring.material_override=m;node.add_child(ring)
	var light:=OmniLight3D.new();light.light_color=color;light.omni_range=4.;light.light_energy=3.;light.position.y=1.;node.add_child(light)
	_particles(at+Vector3.UP,color,20,4.,.06,.8)
	pickups.append({"id":row[0],"node":node,"life":ZombiesConfig.PICKUP_LIFETIME,"ring":ring,"glyph":glyph})

func _tick_pickups(delta: float) -> void:
	for id in active.keys():
		active[id]=float(active[id])-delta
		if float(active[id])<=0.:active.erase(id)
	for p in pickups.duplicate():
		var node: Node3D=p.node
		if not is_instance_valid(node):pickups.erase(p);continue
		p.life=float(p.life)-delta
		(p.ring as Node3D).rotation.y+=delta*3.;(p.ring as Node3D).rotation.x=sin(seconds*2.)*.5;(p.glyph as Node3D).position.y=1.+sin(seconds*3.)*.12
		node.visible=float(p.life)>5. or fmod(seconds,.3)<.18
		if float(p.life)<=0.:node.queue_free();pickups.erase(p);continue
		if Vector2(node.global_position.x-player.global_position.x,node.global_position.z-player.global_position.z).length()<1.3:
			_collect(str(p.id));node.queue_free();pickups.erase(p)
	if has_pickup("gravity"):
		for e: ZombieEnemy in enemies:
			if not e.boss:e.velocity.y=maxf(e.velocity.y,1.6);damage_enemy(e,e.max_hp*.18*delta,false,"gravity",true)
	if has_perk("achter_sinn"):
		sense_clock-=delta
		if sense_clock<=0.:sense_clock=10.;_reveal()

func _collect(id: String) -> void:
	var row:=ZombiesConfig.pickup(id);stats.pickups=int(stats.pickups)+1
	_announce(str(row[1]).to_upper(),"","pickup_"+id,row[2],2.5)
	_flash(player.global_position+Vector3.UP,row[2],3.)
	if float(row[3])>0.:active[id]=float(row[3])
	match id:
		"max_ammo":arsenal.refill_all()
		"nuke":
			for e: ZombieEnemy in enemies.duplicate():
				if not e.boss:damage_enemy(e,e.hp+1.,false,"nuke",false)
			_add_points(400,false);shake=1.
		"alien":health=max_health;_add_points(500,false)

func _reveal() -> void:
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,depth_test_disabled,blend_add,cull_back;void fragment(){float r=pow(1.0-abs(dot(NORMAL,VIEW)),1.5);ALBEDO=vec3(.7,.3,1.)*r;}"
	var m:=ShaderMaterial.new();m.shader=shader
	for e: ZombieEnemy in enemies:
		for mesh: MeshInstance3D in e.model.find_children("*","MeshInstance3D",true,false):
			if mesh.material_overlay==null:mesh.material_overlay=m
	get_tree().create_timer(3.).timeout.connect(func():
		for e in enemies:
			if is_instance_valid(e):
				for mesh: MeshInstance3D in e.model.find_children("*","MeshInstance3D",true,false):
					if mesh.material_overlay==m:mesh.material_overlay=null)

# ---------------------------------------------------------------- buying
func _add_points(value: int, double_ok: bool) -> void:
	var v:=value*(2 if double_ok and (has_pickup("double_points") or event=="blood_moon") else 1)
	points+=v;earned+=v;stats.points=earned;hud.popup(v)

func spend(cost: int) -> bool:
	if points<cost:_announce("","Nicht genug Punkte (%d)"%cost,"",Color.WHITE,1.5);return false
	points-=cost;return true

func _tick_focus() -> void:
	focus={};prompt_text=""
	var eye:=player.camera.global_position;var forward:=-player.camera.global_basis.z
	var best_d:=2.4
	for i in range(doors.size()):
		var d: Dictionary=doors[i]
		if d.open:continue
		var a: Vector3=d.spec.from;var b: Vector3=d.spec.to
		var closest:=Geometry3D.get_closest_point_to_segment(player.global_position,a,b)
		var dist:=Vector2(closest.x-player.global_position.x,closest.z-player.global_position.z).length()
		if dist<1.8 and dist<best_d:best_d=dist;focus={"type":"door","index":i}
	for i in range(stations.size()):
		var s: Dictionary=stations[i];var at: Vector3=(s.node as Node3D).global_position
		var to:=at+Vector3.UP-eye;var dist:=Vector2(to.x,to.z).length()
		if dist<2.3 and dist<best_d+.3 and to.normalized().dot(forward)>.25:best_d=dist;focus={"type":"station","index":i}
	if focus.is_empty():return
	if focus.type=="door":
		var spec: Dictionary=doors[focus.index].spec;prompt_text="E · Absperrung öffnen: %s  [%d]"%[spec.name,spec.cost];return
	var st: Dictionary=stations[focus.index]
	match str(st.kind):
		"perk":
			var row:=ZombiesConfig.perk(st.id)
			prompt_text="%s – bereits getrunken"%row[1] if has_perk(st.id) else "E · %s kaufen  [%d]  ·  %s"%[row[1],row[2],row[4]]
			if not has_perk(st.id) and perks.size()>=perk_limit:prompt_text="Perk-Limit erreicht (%d). Besiege einen Boss für einen weiteren Platz."%perk_limit
		"ammo":
			var d:=arsenal.data()
			if not d.is_empty():
				var row_w:=ZombiesConfig.weapon(d.id);prompt_text="E · Munition für %s  [%d]"%[row_w[1],_ammo_price(d.id)]
				if d.id=="rift_cannon":prompt_text+="  ·  noch %d Nachfüllungen"%int(d.refills)
		"wall":
			var row_w2:=ZombiesConfig.weapon(st.id)
			prompt_text="E · Munition %s  [%d]"%[row_w2[1],int(row_w2[12])/2] if arsenal.has_weapon(st.id)>=0 else "E · %s kaufen  [%d]"%[row_w2[1],row_w2[12]]
		"box":
			if box_state.is_empty():prompt_text="E · Chaos-Geschenk öffnen  [%d]"%ZombiesConfig.BOX_PRICE
			elif box_state.get("ready",false):prompt_text="E · %s nehmen"%ZombiesConfig.weapon(box_state.weapon)[1]
			else:prompt_text="Das Geschenk entscheidet …"
		"upgrade":
			var d2:=arsenal.data()
			if not upgrade_state.is_empty():prompt_text="E · Waffe aus der Maschine nehmen" if upgrade_state.get("ready",false) else "Die Maschine arbeitet …"
			elif not d2.is_empty() and int(d2.level)<3:prompt_text="E · %s veredeln (Stufe %d)  [%d]"%[ZombiesConfig.weapon(d2.id)[1],int(d2.level)+1,ZombiesConfig.UPGRADE_PRICE[int(d2.level)]]
			else:prompt_text="Diese Waffe kann nicht weiter veredelt werden."

func _ammo_price(id: String) -> int:
	return int(ZombiesConfig.AMMO_PRICE[str(ZombiesConfig.weapon(id)[13])])

func interact() -> void:
	if focus.is_empty():return
	if focus.type=="door":open_door(focus.index);return
	var st: Dictionary=stations[focus.index]
	match str(st.kind):
		"perk":
			if has_perk(st.id) or perks.size()>=perk_limit:return
			var row:=ZombiesConfig.perk(st.id)
			if spend(int(row[2])):buy_perk(st.id)
		"ammo":
			var d:=arsenal.data()
			if d.is_empty():return
			if int(d.reserve)>=arsenal.reserve_size(d.id,int(d.level)):return
			if d.id=="rift_cannon" and int(d.refills)<=0:_announce("","Die Rift Cannon lässt sich nicht mehr nachfüllen.","",Color.WHITE,2.);return
			if spend(_ammo_price(d.id)):arsenal.refill();_spark((st.node as Node3D).global_position+Vector3.UP*.6,Color("ffb43a"),.6)
		"wall":
			var row_w:=ZombiesConfig.weapon(st.id)
			if arsenal.has_weapon(st.id)>=0:
				if spend(int(row_w[12])/2):arsenal.refill(arsenal.has_weapon(st.id))
			elif spend(int(row_w[12])):arsenal.give(st.id)
		"box":_use_box()
		"upgrade":_use_upgrade()

func open_door(index: int) -> void:
	var d: Dictionary=doors[index]
	if d.open or not spend(int(d.spec.cost)):return
	d.open=true;stats.doors=int(stats.doors)+1
	for z in d.spec.zones:zones_open[z]=true
	for p: Node3D in d.panels:
		for body: CollisionObject3D in p.find_children("*","CollisionObject3D",true,false):body.collision_layer=0
		var tween:=p.create_tween();tween.tween_property(p,"rotation:x",-1.5,.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT);tween.tween_interval(.8);tween.tween_property(p,"position:y",-2.5,1.);tween.tween_callback(p.queue_free)
	(d.label as Node3D).queue_free()
	_particles(d.mid+Vector3.UP,Color(.4,.38,.34),30,4.,.15,1.)
	await get_tree().physics_frame
	nav.rebuild_line(d.spec.from,d.spec.to)
	_announce("","%s geöffnet"%d.spec.name,"door",Color.WHITE,2.)

func buy_perk(id: String) -> void:
	perks.append(id);stats.perks=int(stats.perks)+1
	if id=="eiserne_rippen":max_health=160.;health=max_health
	if id=="seelenvorrat":arsenal.refill_all()
	hud.set_perks(perks)
	var row:=ZombiesConfig.perk(id);_announce(str(row[1]).to_upper(),str(row[4]),"perk",row[3],3.)

func _box_weapon() -> String:
	var pool: Array=[];var total:=0.
	for row in ZombiesConfig.WEAPONS:
		if row[0]==ZombiesConfig.START_WEAPON or arsenal.has_weapon(row[0])>=0:continue
		var weight:=float(ZombiesConfig.RARITY_WEIGHT[row[13]]);pool.append([row[0],weight]);total+=weight
	var roll:=rng.randf()*total
	for entry in pool:
		roll-=float(entry[1])
		if roll<=0.:return entry[0]
	return pool.back()[0]

func _use_box() -> void:
	if box_state.get("ready",false):
		arsenal.give(box_state.weapon);_close_box();return
	if not box_state.is_empty() or not spend(ZombiesConfig.BOX_PRICE):return
	stats.box=int(stats.box)+1;box_uses+=1
	var troll:=box_uses>=ZombiesConfig.BOX_USES_BEFORE_MOVE or rng.randf()<ZombiesConfig.BOX_TROLL_CHANCE
	box_state={"clock":0.,"weapon":_box_weapon(),"troll":troll,"ready":false,"show":null}
	var lid:=box_node.find_child("Lid",true,false) as Node3D
	if lid:lid.create_tween().tween_property(lid,"rotation:x",-1.6,.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce("","Das Chaos-Geschenk öffnet sich …","box",Color("d2a6ff"),2.)

func _close_box() -> void:
	if box_state.get("show")!=null and is_instance_valid(box_state.show):(box_state.show as Node).queue_free()
	var lid:=box_node.find_child("Lid",true,false) as Node3D
	if lid:lid.create_tween().tween_property(lid,"rotation:x",0.,.4)
	box_state={}

func _tick_stations(delta: float) -> void:
	if not box_state.is_empty():
		box_state.clock=float(box_state.clock)+delta
		var t: float=box_state.clock
		if t<3.2:
			var frame_id: String=ZombiesConfig.WEAPONS[int(t*10.)%ZombiesConfig.WEAPONS.size()][0] if t<3. else box_state.weapon
			if box_state.get("frame","")!=frame_id:
				if box_state.get("show")!=null and is_instance_valid(box_state.show):(box_state.show as Node).queue_free()
				var row:=ZombiesConfig.weapon(frame_id)
				var show:=(load("res://assets/zombies-v500/weapon-%s.glb"%str(row[2])) as PackedScene).instantiate() as Node3D
				box_node.add_child(show);show.position=Vector3(0,.8+t*.25,0);show.rotation.y=PI/2;show.scale=Vector3.ONE*1.6;_tint(show,"GunAccent",row[14])
				box_state.show=show;box_state.frame=frame_id
			if box_state.get("show")!=null:(box_state.show as Node3D).position.y=.8+t*.25
		elif not box_state.ready:
			if box_state.troll:
				_announce("DAS GESCHENK HAT KEINE LUST MEHR","Es zieht weiter. Die Punkte bekommst du zurück.","box_troll",Color("d2a6ff"),3.5)
				points+=ZombiesConfig.BOX_PRICE;_close_box();box_uses=0
				box_spot=(box_spot+1+rng.randi_range(0,ZombiesConfig.BOX_SPOTS.size()-2))%ZombiesConfig.BOX_SPOTS.size();_flash(box_node.global_position+Vector3.UP,Color("9a4aff"),3.);_place_box();return
			box_state.ready=true;box_state.clock=3.2
			var row2:=ZombiesConfig.weapon(box_state.weapon)
			_announce(str(row2[1]).to_upper(),str(row2[13]).to_upper(),"box_result",ZombiesConfig.RARITY_COLOR[row2[13]],2.5)
		elif t>11.:_close_box()
	if not upgrade_state.is_empty():
		upgrade_state.clock=float(upgrade_state.clock)+delta
		var machine: Node3D=upgrade_state.node
		machine.rotation.z=sin(seconds*40.)*.01*float(not upgrade_state.ready)
		if not upgrade_state.ready and float(upgrade_state.clock)>4.:
			upgrade_state.ready=true;_flash(machine.global_position+Vector3(0,1.2,.6),Color("ff2a1a"),2.)
		if upgrade_state.ready and float(upgrade_state.clock)>16.:upgrade_state={}
	for s in stations:
		if s.light:(s.light as OmniLight3D).light_energy=lerpf((s.light as OmniLight3D).light_energy,1.4+sin(seconds*3.+float(s.at.x))*.4,.1)

func _use_upgrade() -> void:
	var st: Dictionary=stations[focus.index]
	if not upgrade_state.is_empty():
		if upgrade_state.ready:
			arsenal.give(upgrade_state.weapon,int(upgrade_state.level));upgrade_state={}
			var row:=ZombiesConfig.weapon(arsenal.data().id)
			_announce(str(ZombiesConfig.UPGRADE_NAMES[int(arsenal.data().level)]).to_upper(),str(row[1]),"upgrade",Color("ff4a3a"),3.)
		return
	var d:=arsenal.data()
	if d.is_empty() or int(d.level)>=3 or not spend(int(ZombiesConfig.UPGRADE_PRICE[int(d.level)])):return
	stats.upgrades=int(stats.upgrades)+1
	upgrade_state={"weapon":d.id,"level":int(d.level)+1,"clock":0.,"ready":false,"node":st.node}
	arsenal.slots.remove_at(arsenal.current)
	if arsenal.slots.is_empty():arsenal.give(ZombiesConfig.START_WEAPON)
	else:arsenal.equip(0)
	_announce("","Die Fleischmaschine frisst deine Waffe …","upgrade_start",Color("ff4a3a"),2.5)

# ---------------------------------------------------------------- events & world
func _start_event(id: String) -> void:
	event=id;var spec: Dictionary=ZombiesConfig.EVENTS[id]
	_announce(str(spec.name),str(spec.text),"event_"+id,Color("ff4aff"),5.)
	match id:
		"dark":
			for row in lights:(row[0] as Light3D).light_energy=float(row[1])*.12
			player.lamp_on=true;player.lamp.visible=true
		"rift","alien":
			for i in range(3):_add_rift()

func _end_event() -> void:
	if event=="dark" or event=="flicker":
		for row in lights:if is_instance_valid(row[0]):(row[0] as Light3D).light_energy=float(row[1])
	event=""

func _add_rift() -> void:
	var at:=_spawn_cell()+Vector3.UP*1.4
	var rift:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.7;torus.outer_radius=.95;rift.mesh=torus
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color("44ff8a");m.emission_enabled=true;m.emission=Color("44ff8a");m.emission_energy_multiplier=4.;rift.material_override=m
	root3d.add_child(rift);rift.global_position=at;rift.rotation.x=PI/2
	var core:=MeshInstance3D.new();var disc:=SphereMesh.new();disc.radius=.7;disc.height=.1;core.mesh=disc
	var cm:=StandardMaterial3D.new();cm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;cm.albedo_color=Color(.05,0,.1,.9);cm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;core.material_override=cm;rift.add_child(core)
	var light:=OmniLight3D.new();light.light_color=Color("44ff8a");light.omni_range=6.;light.light_energy=2.5;rift.add_child(light)
	rifts.append(rift)
	if rifts.size()>6:(rifts.pop_front() as Node).queue_free()

func _add_debris() -> void:
	var models:=["res://assets/arcade-v4120/prize-bunny.glb","res://assets/models/cardboard_box_01/cardboard_box_01.gltf","res://assets/zombies-v500/weapon-pistol.glb"]
	var node:=(load(models[rng.randi_range(0,models.size()-1)]) as PackedScene).instantiate() as Node3D
	root3d.add_child(node);node.global_position=_spawn_cell()+Vector3(0,rng.randf_range(1.5,3.2),0);node.scale=Vector3.ONE*rng.randf_range(.6,1.4)
	debris.append({"node":node,"spin":Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)),"base":node.global_position.y})
	if debris.size()>18:(debris.pop_front().node as Node).queue_free()

func reality() -> float:
	if round_number<ZombiesConfig.REALITY_FROM:return 0.
	return clampf((round_number-ZombiesConfig.REALITY_FROM+1)/25.,0.,1.)

func _tick_world(delta: float) -> void:
	var real:=reality()
	for alarm in alarm_lights:
		var a: OmniLight3D=alarm
		if round_number>=ZombiesConfig.NIGHTMARE_FROM:a.light_energy=2.+sin(seconds*4.)*1.6
		else:a.light_energy=maxf(a.light_energy-delta*.6,0.)*(.6+.4*float(fmod(seconds,.5)<.25))
	if event=="flicker":
		var on:=fmod(seconds*7.3,1.)<.55
		for row in lights:if is_instance_valid(row[0]):(row[0] as Light3D).light_energy=float(row[1])*(1. if on else .05)
	if real>0. and debris.size()<int(real*18.) and rng.randf()<delta:_add_debris()
	if real>.2 and rifts.size()<int(real*5.) and rng.randf()<delta*.2:_add_rift()
	for d in debris:
		var n: Node3D=d.node
		if is_instance_valid(n):n.rotation+=(d.spin as Vector3)*delta;n.global_position.y=float(d.base)+sin(seconds+n.global_position.x)*.3
	for r in rifts:
		if is_instance_valid(r):(r as Node3D).rotate_object_local(Vector3.FORWARD,delta*2.);(r as Node3D).scale=Vector3.ONE*(1.+sin(seconds*5.)*.08)
	if env:
		var tint:=Color("ff1a12") if event=="blood_moon" else Color("5aff3a") if event=="poison" else Color(env_base.fog).lerp(Color("6a1aff"),real*.5)
		env.fog_light_color=Color(env.fog_light_color).lerp(tint,clampf(delta,0,1))
		env.fog_density=lerpf(env.fog_density,float(env_base.density)*(2.4 if event in ["poison","blood_moon"] else 1.+real*.8),clampf(delta,0,1))

func _announce(big: String, small: String, key: String, color: Color, length: float) -> void:
	hud.announce(big,small,color,length)
	ZombiesAnnouncer.play(self,key)

func announce_ammo_empty() -> void:
	_announce("","Leer. Munitionskiste suchen!","ammo_empty",Color.WHITE,1.5)

func _hud_data() -> Dictionary:
	var d:=arsenal.data();var row:=arsenal.weapon()
	var ammo:="" if d.is_empty() else ("∞" if has_pickup("infinite_ammo") else "%d"%int(d.mag))+"  /  %d"%int(d.reserve)
	var weapon_name:="" if row.is_empty() else str(row[1])+("  ·  "+str(ZombiesConfig.UPGRADE_NAMES[int(d.level)]) if int(d.level)>0 else "")
	var lines: Array=[]
	for id in active:lines.append("%s  %ds"%[ZombiesConfig.pickup(id)[1],ceili(float(active[id]))])
	if event!="":lines.push_front("◆ "+str(ZombiesConfig.EVENTS[event].name))
	var boss_name:="";var boss_hp:=0.
	if not bosses.is_empty():var b: ZombieEnemy=bosses[0];boss_name=str(b.spec.get("name",""));boss_hp=b.hp/b.max_hp
	return {"round":round_number,"points":points,"ammo":ammo,"weapon":weapon_name,"weapon_color":ZombiesConfig.RARITY_COLOR.get(row[13] if not row.is_empty() else "common",Color.WHITE),
		"pickups":"\n".join(lines),"prompt":prompt_text,"hurt":1.-health/max_health,"shield":has_pickup("shield"),"glitch":reality()*.6+(.4 if event=="rift" else 0.),
		"boss_name":boss_name,"boss_hp":boss_hp,"aiming":arsenal.aiming>.5}

# ---------------------------------------------------------------- input & end
func handle(event_in: InputEvent) -> bool:
	if not running:return false
	if event_in is InputEventMouseButton and event_in.pressed:
		var mb:=event_in as InputEventMouseButton
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:player.capture();return true
		if mb.button_index==MOUSE_BUTTON_WHEEL_UP:arsenal.swap(-1);return true
		if mb.button_index==MOUSE_BUTTON_WHEEL_DOWN:arsenal.swap(1);return true
	if event_in is InputEventKey and event_in.pressed and not event_in.echo:
		var key:=(event_in as InputEventKey).physical_keycode
		if event_in.is_action("interact"):interact();return true
		if key==KEY_R:arsenal.reload();return true
		if key==KEY_V:arsenal.melee();return true
		if key==KEY_F:player.toggle_lamp();return true
		if key==KEY_1:arsenal.equip(0);return true
		if key==KEY_2 and arsenal.slots.size()>1:arsenal.equip(1);return true
	return false

func _game_over() -> void:
	if over:return
	over=true;running=false;health=0.
	_announce("DU BIST GEFALLEN","Runde %d"%round_number,"game_over",Color("ff1a1a"),4.)
	var results:=summary()
	if g.achievements:results.new_best=g.achievements.record_zombies(results)
	player.active=false
	var tween:=create_tween();tween.tween_property(player.camera,"rotation:z",.9,1.2);tween.parallel().tween_property(player.camera,"position:y",.35,1.2)
	await get_tree().create_timer(2.4).timeout
	ended.emit()
	if is_instance_valid(g) and g.phase=="zombies":g._zombies_results(results)

func summary() -> Dictionary:
	return {"round":round_number,"points":earned,"kills":stats.get("kills",0),"headshots":stats.get("headshots",0),"bosses":stats.get("bosses",0),"seconds":seconds,
		"pickups":stats.get("pickups",0),"perks":stats.get("perks",0),"weapons":arsenal.used.keys() if arsenal else [],"elites":stats.get("elites",0),"new_best":false}

func stop() -> void:
	running=false;over=true
	for row in lights:if is_instance_valid(row[0]):(row[0] as Light3D).light_energy=float(row[1])
	if env and not env_base.is_empty():env.fog_light_color=env_base.fog;env.fog_density=env_base.density;env.ambient_light_color=env_base.ambient
	player.speed_scale=1.;player.gravity_scale=1.;player.camera.rotation.z=0.;player.camera.position.y=1.65;player.camera.fov=player.base_fov
	if is_instance_valid(arsenal):arsenal.queue_free()
	if is_instance_valid(root3d):root3d.queue_free()
	if is_instance_valid(hud):hud.queue_free()

func snapshot() -> Dictionary:
	return {"running":running,"round":round_number,"points":points,"health":health,"alive":enemies.size(),"to_spawn":to_spawn,"zones":zones_open.keys(),"perks":perks,"weapons":arsenal.snapshot() if arsenal else [],"event":event,"active":active.keys()}
