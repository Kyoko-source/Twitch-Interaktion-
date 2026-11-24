extends RefCounted

# After Play 5.2.1 trailer director (author tool, not in player builds).
# Run with Godot's movie maker:
#   godot --path . --write-movie trailer.avi --fixed-fps 30 --resolution 1920x1080 -- --trailer
# Every shot prints "TRAILER MARK <name> <frame>"; tools/make-after-play-trailer-v521.py
# cuts the recording at these frames.
var game: Node3D
var cam: Camera3D
var z: ZombiesMode
var frame:=0
var rng:=RandomNumberGenerator.new()
# --trailer-preview: no recording, two stills per shot to check framing.
var preview:=false
var shots_dir:=""

func _tick() -> void:
	await game.get_tree().process_frame
	frame=Engine.get_frames_drawn()
	if z:
		z.health=z.max_health;z.hud.prompt.visible=false
	var vp:=game.get_viewport()
	Input.warp_mouse(vp.get_visible_rect().size*.5)

func wait(seconds: float) -> void:
	for i in range(int(round(seconds*30.))):await _tick()

func mark(id: String) -> void:
	frame=Engine.get_frames_drawn()
	print("TRAILER MARK %s %d"%[id,frame])
	if preview:
		for at in [.6,2.2]:
			game.get_tree().create_timer(at).timeout.connect(func():game.get_viewport().get_texture().get_image().save_png(shots_dir.path_join("%s-%.1f.png"%[id,at])))

func _free_cam() -> void:
	cam=Camera3D.new();cam.near=.05;cam.far=140.;cam.fov=58.;game.world.add_child(cam);cam.make_current()
	var torch:=SpotLight3D.new();torch.light_color=Color("d8c9a4");torch.light_energy=2.4;torch.spot_range=22.;torch.spot_angle=40.;torch.spot_angle_attenuation=1.4;torch.shadow_enabled=true;cam.add_child(torch)

func dolly(id: String, a: Vector3, b: Vector3, look_a: Vector3, look_b: Vector3, seconds: float, fov: float=58.) -> void:
	cam.fov=fov;cam.global_position=a;cam.look_at(look_a,Vector3.UP)
	await wait(.5)
	mark(id)
	var n:=int(seconds*30.)
	for i in range(n):
		var k:=smoothstep(0.,1.,float(i)/n)
		cam.global_position=a.lerp(b,k);cam.look_at(look_a.lerp(look_b,k),Vector3.UP)
		await _tick()

# ---------------------------------------------------------------- shooter helpers
func aim_at(at: Vector3, rate: float=10.) -> void:
	var p: NightGuard=game.player;var from:=p.camera.global_position;var to:=at-from
	var yaw:=atan2(-to.x,-to.z);var pitch:=clampf(atan2(to.y,Vector2(to.x,to.z).length()),-1.1,1.1)
	var k:=1.-exp(-rate/30.)
	p.rotation.y=lerp_angle(p.rotation.y,yaw,k);p.camera.rotation.x=lerpf(p.camera.rotation.x,pitch,k)

func guests(n: int, center: Vector3, spread: float, rise: bool=false) -> Array:
	var out: Array=[]
	for i in range(n):
		var e:=z._spawn_enemy()
		var at:=center+Vector3(rng.randf_range(-spread,spread),0,rng.randf_range(-spread,spread))
		var cell:=z.nav.nearest(at)
		e.global_position=z.nav.point(cell) if cell.x!=999999 else at
		if rise:z._rise_fx(e.global_position)
		else:e.rise=0.;e.model.position.y=0.
		out.append(e)
	return out

func clear_guests() -> void:
	for e in z.enemies:
		if is_instance_valid(e):(e as Node).queue_free()
	z.enemies.clear();z.bosses.clear()

func target_of(list: Array) -> ZombieEnemy:
	var best: ZombieEnemy=null;var best_d:=999.
	for e in list:
		if not is_instance_valid(e) or (e as ZombieEnemy).dead:continue
		var d:=(e as ZombieEnemy).global_position.distance_to(game.player.global_position)
		if d<best_d:best_d=d;best=e
	return best

func shoot(seconds: float, list: Array, head: bool=true, sweep: float=0.) -> void:
	var n:=int(seconds*30.)
	for i in range(n):
		var d:=z.arsenal.data()
		if not d.is_empty():d.mag=z.arsenal.mag_size(d.id,int(d.level));z.arsenal.reload_t=0.
		z.health=z.max_health
		var t:=target_of(list)
		if t:
			var h:=(1.45 if head else 1.0)*minf(t.size_scale,1.4)
			if t.role=="crawler":h=.45
			var spot: Vector3=t.global_position+Vector3.UP*h+game.player.global_basis.x*sin(i*.12)*sweep
			aim_at(spot,9.)
		z.arsenal._try_fire(z.arsenal.weapon())
		await _tick()

# Props right in front of the lens hide the action; take them out of the shot.
func clear_lens(eye: Vector3) -> void:
	for vi: VisualInstance3D in game.world.find_children("*","VisualInstance3D",true,false):
		if not vi.visible or vi is Light3D or vi is Decal or vi is ReflectionProbe or vi is CPUParticles3D:continue
		if str(vi.get_path()).contains("ZombiesWorld"):continue
		var box:=vi.global_transform*vi.get_aabb()
		if box.size.length()>4.5:continue
		if box.get_center().distance_to(eye)<2.4 and box.end.y>.5:vi.visible=false

func stand(at: Vector3, look: Vector3) -> void:
	var p: NightGuard=game.player
	clear_lens(at+Vector3.UP*1.65)
	p.global_position=at;p.velocity=Vector3.ZERO
	var to:=look-(at+Vector3.UP*1.65)
	p.rotation=Vector3(0,atan2(-to.x,-to.z),0);p.camera.rotation=Vector3(atan2(to.y,Vector2(to.x,to.z).length()),0,0)

# ---------------------------------------------------------------- run
func run(owner: Node3D) -> void:
	game=owner;rng.seed=521
	preview="--trailer-preview" in OS.get_cmdline_user_args()
	shots_dir=OS.get_environment("TEMP").path_join("after-play-trailer-preview")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):shots_dir=arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	game.settings.quality=2;game.settings.grain=true;game.settings.volume=.85;game.settings.crosshair=true
	game.settings.subtitles=false;game.settings.sign_subtitles=false;game.settings.voice=0.;game._apply_settings()
	await wait(1.)
	if not "--party-only" in OS.get_cmdline_user_args():
		await act_original()
		await act_nightwatch()
	await act_party()
	mark("end")
	await wait(1.)
	game.get_tree().quit()

func act_original() -> void:
	game._build_world("none");game._resume()
	game.hud.hide();game.player.active=false;game.player.lamp.hide();game.prompt.text="";game.player.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_free_cam()
	await wait(2.)
	await dolly("a1",Vector3(-6.6,1.7,3.6),Vector3(-7.4,1.55,6.6),Vector3(-8.4,1.2,9.6),Vector3(-8.9,1.1,10.2),5.)
	await dolly("a2",Vector3(17.2,2.5,-9.6),Vector3(16.7,2.3,-7.9),Vector3(15.5,1.0,-1.2),Vector3(15.2,1.0,-.8),4.5,66.)
	await dolly("a3",Vector3(4.4,2.3,11.4),Vector3(6.0,2.0,12.4),Vector3(11.0,1.1,16.2),Vector3(11.4,1.0,16.4),4.5,64.)
	await dolly("a4",Vector3(8.2,1.7,-3.2),Vector3(9.4,1.5,-4.3),Vector3(10.75,.8,-5.95),Vector3(10.9,.8,-6.1),4.)
	await dolly("a5",Vector3(-5.4,1.9,-25.8),Vector3(-3.4,1.6,-27.3),Vector3(.7,1.0,-30.),Vector3(.9,1.1,-30.2),4.)

func act_nightwatch() -> void:
	await game._start_nightwatch()
	var nw: Nightwatch=game.nightwatch
	await wait(2.)
	mark("b1");await wait(4.)
	var change:=nw.force("kino","sitze","floating")
	nw.open_fullscreen(9);await wait(.4)
	mark("b2");await wait(3.)
	if not change.is_empty():nw.fix(change)
	await wait(.6)
	nw.close_fullscreen();nw.look("right");await wait(1.4)
	nw.start_qte();await wait(.3)
	mark("b3")
	for i in range(18):
		if nw.qte.is_empty():break
		var words: Array=nw.qte.words;var word: String=words[int(nw.qte.index)]
		nw.type_key(word[int(nw.qte.typed)]);await wait(.17)
	await wait(1.)
	nw.stop()

func act_party() -> void:
	await game._start_zombies()
	z=game.zombies;game.player.show()
	for m in [z.music_calm,z.music_dread]:(m as AudioStreamPlayer).stop();(m as AudioStreamPlayer).stream=null
	z.points=80000;z.in_break=true;z.break_clock=99999.;z.to_spawn=0
	for i in range(z.doors.size()):z.open_door(i)
	await wait(3.)
	z.points=4250;z.fx.clear()
	var tubes:=game.world.find_child("CrawlTubes",true,false) as Node3D
	if tubes:tubes.hide()
	var hall:=Vector3(-7.7,0,13.4);var down:=Vector3(-7.2,1.2,3.)
	# Round one: the banner, the gong, the guests climbing out of the floor.
	stand(hall,down);await wait(.5)
	z.round_number=1
	var first:=guests(5,Vector3(-6.9,0,8.5),1.6,true)
	z.hud.wave(1,"Die Gäste sind schon da.");z._sting("round-start",0.);z._storm(9);ZombiesAnnouncer.play(z,"start")
	mark("c1");await wait(3.6)
	# Pistol headshots.
	mark("c2");await shoot(3.2,first,true)
	clear_guests();await wait(.2)
	# Cake launcher.
	z.arsenal.give("tortenwerfer");stand(hall,down)
	var cakes:=guests(7,Vector3(-6.8,0,7.5),1.4)
	for e in cakes:(e as ZombieEnemy).stun=1.5
	await wait(.6)
	mark("c3")
	for shot in range(3):
		var t:=target_of(cakes)
		if t:
			for i in range(8):aim_at(t.global_position+Vector3.UP*.4,14.);await _tick()
		z.arsenal.fire_cd=0.;z.arsenal._try_fire(z.arsenal.weapon());await wait(.75)
	clear_guests();await wait(.2)
	# Flamethrower.
	z.arsenal.give("kuchenbrenner",1);stand(hall+Vector3(0,0,-.8),down)
	var torches:=guests(7,Vector3(-6.8,0,10.5),1.5)
	await wait(.5)
	mark("c4");await shoot(3.3,torches,false,1.6)
	clear_guests();await wait(.2)
	# Tesla coil.
	z.arsenal.give("gewitterkind",2);stand(hall,down)
	var storm:=guests(9,Vector3(-6.8,0,8.5),2.)
	await wait(.5)
	mark("c5");await shoot(3.3,storm,true)
	clear_guests();await wait(.2)
	# Boss.
	z.round_number=10;z.arsenal.give("oblivion",3);stand(hall,down)
	z._spawn_boss(0)
	var boss: ZombieEnemy=z.bosses[0];boss.global_position=Vector3(-7.,0,5.5);boss.rise=.6;boss.max_hp*=10.;boss.hp=boss.max_hp
	await wait(.4)
	mark("c6")
	for i in range(30):aim_at(boss.global_position+Vector3.UP*3.2,6.);await _tick()
	await shoot(2.6,[boss],false)
	clear_guests();z.hud.boss_box.hide();await wait(.2)
	# Round 25: the reality tears, then a nuke.
	z.hud.title_time=0.;z.hud.title.text="";z.hud.subtitle.text=""
	z.round_number=25;z.arsenal.give("rotting_sun",3);stand(hall,down)
	var horde:=guests(16,Vector3(-6.8,0,8.),2.4,true)
	z.hud.wave(25,"Albtraumphase.",Color("c040ff"));z._sting("round-start",0.);z._storm(14)
	mark("c7");await shoot(2.2,horde,true)
	z._collect("nuke");await wait(1.6)
	clear_guests()
	# Finale: confetti, lightning and the neon chaos box.
	_free_cam_party()
	var box: Vector3=z.box_node.global_position
	cam.global_position=box+Vector3(3.2,1.6,3.2);cam.look_at(box+Vector3.UP*1.1,Vector3.UP);cam.fov=55.
	await wait(.3)
	mark("c8")
	for i in range(int(3.8*30)):
		var ang:=.78+i*.006
		cam.global_position=box+Vector3(cos(ang)*3.6,1.5+i*.004,sin(ang)*3.6);cam.look_at(box+Vector3.UP*1.1,Vector3.UP)
		if i%9==0:z.fx.confetti(box+Vector3(rng.randf_range(-1.5,1.5),2.2,rng.randf_range(-1.5,1.5)),2.)
		if i%14==0:z.fx.lightning(box+Vector3(rng.randf_range(-3,3),4.,rng.randf_range(-3,3)),box+Vector3.UP*.8,ZombiesFx.CONFETTI[rng.randi_range(0,5)],1.8,.3)
		if i==40:z.fx.explosion(box+Vector3(1.6,.3,-1.4),2.4,Color("ff6ac8"))
		await _tick()

func _free_cam_party() -> void:
	cam=Camera3D.new();cam.near=.05;cam.far=140.;game.world.add_child(cam);cam.make_current()
	z.hud.hide();z.arsenal.hide();game.player.hide()
