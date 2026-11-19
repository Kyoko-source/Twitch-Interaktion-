class_name ZombiesArsenal
extends Node3D

# The guard's guns in the wave mode: two slots, a viewmodel on the camera,
# hitscan with spread and pellets, piercing rifles, rift projectiles, reload,
# aiming, melee and synthesised shots (replaceable by real recordings).
const HIP:=Vector3(.2,-.22,-.42)
const AIM:=Vector3(0,-.12,-.32)
const RAY_MASK:=1|ZombieEnemy.LAYER_BODY|ZombieEnemy.LAYER_HEAD

var mode: Node3D
var camera: Camera3D
var slots: Array=[]
var current:=0
var view: Node3D
var view_left: Node3D
var muzzle: Node3D
var fire_cd:=0.0
var reload_t:=0.0
var reload_total:=0.0
var swap_t:=0.0
var kick:=0.0
var recoil:=0.0
var aiming:=0.0
var burst:=0
var melee_t:=0.0
var bob:=0.0
var rng:=RandomNumberGenerator.new()
var shot: AudioStreamPlayer
var dry: AudioStreamPlayer
var clack: AudioStreamPlayer
var shots:={}
var flash: OmniLight3D
var flash_mesh: MeshInstance3D
var trigger_held:=false
var used: Dictionary={}

func build(owner_mode: Node3D, cam: Camera3D) -> void:
	mode=owner_mode;camera=cam;name="ZombiesArsenal";cam.add_child(self)
	shot=_player(-3.);shot.max_polyphony=10;dry=_player(-8.);clack=_player(-6.);clack.stream=load("res://assets/feedback-v403/switch.ogg")
	dry.stream=sfx("empty") if sfx("empty") else _wav(.05,func(t: float):return (rng.randf()-.5)*exp(-t*120.)*.8)
	for frame in ["pistol","revolver","smg","rifle","shotgun","lmg","sniper","rift"]:
		var variants: Array=[]
		for v in range(3):
			var s:=sfx("shot-%s-%d"%[frame,v])
			if s:variants.append(s)
		shots[frame]=variants if not variants.is_empty() else [_gunshot(frame)]
	flash=OmniLight3D.new();flash.light_color=Color("ffc27a");flash.omni_range=5.;flash.light_energy=0.;flash.shadow_enabled=false;add_child(flash)

func _player(volume: float) -> AudioStreamPlayer:
	var p:=AudioStreamPlayer.new();p.volume_db=volume;p.max_polyphony=6;p.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(p);return p

func _wav(length: float, wave: Callable) -> AudioStreamWAV:
	var rate:=22050;var count:=int(length*rate);var data:=PackedByteArray();data.resize(count*2)
	for i in range(count):data.encode_s16(i*2,int(clampf(float(wave.call(float(i)/rate)),-1.,1.)*30000.))
	var s:=AudioStreamWAV.new();s.format=AudioStreamWAV.FORMAT_16_BITS;s.mix_rate=rate;s.data=data;return s

func _gunshot(frame: String) -> AudioStreamWAV:
	var body: Array={"pistol":[.22,90.,180.],"revolver":[.42,55.,110.],"smg":[.16,120.,210.],"rifle":[.3,70.,150.],"shotgun":[.5,40.,85.],"lmg":[.32,60.,130.],"sniper":[.7,30.,70.],"rift":[.8,20.,55.]}[frame]
	var last:=[0.];var noise:=RandomNumberGenerator.new();noise.seed=hash(frame)
	return _wav(float(body[0]),func(t: float):
		var n:=noise.randf()*2.-1.;last[0]=lerpf(float(last[0]),n,.35)
		var boom:=sin(TAU*float(body[2])*t*(1.-t*1.5))*exp(-t*float(body[1])*.18)
		var zap:=sin(TAU*(900.-t*1400.)*t)*exp(-t*9.)*.6 if frame=="rift" else 0.
		return (float(last[0])*exp(-t*float(body[1]))*1.3+boom*.9+zap)*.9)

const SFX:="res://assets/zombies-v500/sfx/"
static func sfx(key: String) -> AudioStream:
	return load(SFX+key+".ogg") if ResourceLoader.exists(SFX+key+".ogg") else null

func _mech(key: String, pitch: float=1.) -> void:
	var s:=sfx(key)
	clack.stream=s if s else load("res://assets/feedback-v403/switch.ogg");clack.pitch_scale=pitch*rng.randf_range(.96,1.04);clack.play()

# ---------------------------------------------------------------- slots
func max_slots() -> int:
	return 2

func data(index: int=-1) -> Dictionary:
	var i:=current if index<0 else index
	return slots[i] if i<slots.size() else {}

func weapon(index: int=-1) -> Array:
	var d:=data(index)
	return ZombiesConfig.weapon(str(d.id)) if not d.is_empty() else []

func mag_size(id: String, level: int) -> int:
	return int(round(float(ZombiesConfig.weapon(id)[5])*float(ZombiesConfig.UPGRADE_MAG[level])))

func reserve_size(id: String, level: int) -> int:
	var base:=float(ZombiesConfig.weapon(id)[6])*(1.5 if mode.has_perk("seelenvorrat") else 1.)
	return int(round(base*(1.+level*.25)))

func has_weapon(id: String) -> int:
	for i in range(slots.size()):
		if slots[i].id==id:return i
	return -1

func give(id: String, level: int=0) -> void:
	var have:=has_weapon(id)
	var entry:={"id":id,"level":level,"mag":mag_size(id,level),"reserve":reserve_size(id,level),"refills":ZombiesConfig.RIFT_REFILLS}
	if have>=0:slots[have]=entry;equip(have);return
	if slots.size()<max_slots():slots.append(entry);equip(slots.size()-1)
	else:slots[current]=entry;equip(current)
	used[id]=true

func refill(index: int=-1) -> bool:
	var i:=current if index<0 else index
	if i>=slots.size():return false
	var d: Dictionary=slots[i]
	if d.id=="rift_cannon":
		if int(d.refills)<=0:return false
		d.refills=int(d.refills)-1
	d.reserve=reserve_size(d.id,int(d.level));return true

func refill_all() -> void:
	for i in range(slots.size()):
		var d: Dictionary=slots[i];d.reserve=reserve_size(d.id,int(d.level));d.mag=mag_size(d.id,int(d.level))

func equip(index: int) -> void:
	current=clampi(index,0,maxi(slots.size()-1,0));reload_t=0.;swap_t=.35;burst=0
	for node in [view,view_left]:
		if is_instance_valid(node):node.queue_free()
	view=null;view_left=null
	var row:=weapon()
	if row.is_empty():return
	view=_frame(row,int(data().level));add_child(view)
	if str(row[15])=="dual":
		view_left=_frame(row,int(data().level));add_child(view_left);view_left.scale.x=-1.
	muzzle=view.find_child("Muzzle",true,false) as Node3D
	_mech("swap")

func _frame(row: Array, level: int) -> Node3D:
	var node:=(load("res://assets/zombies-v500/weapon-%s.glb"%str(row[2])) as PackedScene).instantiate() as Node3D
	var accent: Color=row[14]
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mesh.mesh.get_surface_count()):
			var m:=mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if not m:continue
			if m.resource_name=="GunAccent" or (level>0 and m.resource_name=="GunMetal"):
				var copy:=m.duplicate() as StandardMaterial3D
				if m.resource_name=="GunAccent":copy.albedo_color=accent
				if level>0:
					var tone: Color={"fire":Color("ff5a1a"),"shock":Color("6af2ff"),"void":Color("b05aff")}[ZombiesConfig.UPGRADE_ELEMENT[level]]
					copy.emission_enabled=true;copy.emission=tone;copy.emission_energy_multiplier=(1.2+level*.8) if m.resource_name=="GunAccent" else .12+level*.06
				mesh.set_surface_override_material(s,copy)
	return node

# ---------------------------------------------------------------- firing
func tick(delta: float, firing: bool, aim_held: bool) -> void:
	fire_cd-=delta;swap_t=maxf(swap_t-delta,0.);melee_t=maxf(melee_t-delta,0.)
	kick=lerpf(kick,0.,clampf(delta*12.,0,1));recoil=lerpf(recoil,0.,clampf(delta*7.,0,1))
	aiming=move_toward(aiming,1. if aim_held and reload_t<=0. else 0.,delta*6.)
	flash.light_energy=maxf(flash.light_energy-delta*60.,0.)
	if reload_t>0.:
		reload_t-=delta
		if reload_t<=0.:_finish_reload()
	var row:=weapon()
	if not row.is_empty():
		var auto:=int(row[4])>=400 and str(row[15])!="burst"
		if firing and (auto or not trigger_held or burst>0):
			_try_fire(row)
		if str(row[15])=="burst" and burst>0 and fire_cd<=0.:_try_fire(row)
	trigger_held=firing
	_pose(delta)

func _try_fire(row: Array) -> void:
	if fire_cd>0. or reload_t>0. or swap_t>0. or melee_t>0.:return
	var d:=data()
	if int(d.mag)<=0:
		if int(d.reserve)>0:reload()
		else:dry.play();fire_cd=.25;mode.announce_ammo_empty()
		return
	if str(row[15])=="burst":
		if burst<=0:burst=3
		burst-=1
	var rpm:=float(row[4])*(1.25 if mode.has_pickup("bloodrush") else 1.)
	fire_cd=60./rpm
	if str(row[15])=="burst" and burst==0:fire_cd+=.22
	if not mode.has_pickup("infinite_ammo"):d.mag=int(d.mag)-1
	_shoot(row,int(d.level))

func _shoot(row: Array, level: int) -> void:
	var frame: String=row[2]
	var variants: Array=shots[frame]
	shot.stream=variants[rng.randi_range(0,variants.size()-1)];shot.pitch_scale=rng.randf_range(.94,1.06)*(.86 if level>0 else 1.);shot.play()
	flash.light_energy=3.5 if frame!="rift" else 6.;flash.light_color=Color("ffc27a") if level==0 else Color("ff6a3a") if level==1 else Color("7af2ff") if level==2 else Color("c07aff")
	if muzzle:flash.global_position=muzzle.global_position
	var steady:=.6 if mode.has_perk("leerer_blick") else 1.
	kick=1.;recoil+=float(row[10])*steady
	mode.player.camera.rotation.x=clampf(mode.player.camera.rotation.x+float(row[10])*.012*steady*(1.-aiming*.4),-1.35,1.35)
	mode.player.rotate_y(rng.randf_range(-1,1)*float(row[10])*.004*steady)
	if str(row[15])=="rift":
		mode.rift_shot(muzzle.global_position if muzzle else camera.global_position,-camera.global_basis.z,float(row[3])*float(ZombiesConfig.UPGRADE_DAMAGE[level]))
		return
	var spread:=deg_to_rad(float(row[8]))*(1.-aiming*.6)*steady*(1.35 if mode.player.velocity.length()>3. else 1.)
	var pellets:=int(row[9])
	var damage:=float(row[3])*float(ZombiesConfig.UPGRADE_DAMAGE[level])
	var pierce:=3 if str(row[15])=="pierce" else 1
	var element:=str(ZombiesConfig.UPGRADE_ELEMENT[level]) if level>0 else str(row[15]) if str(row[15]) in ["fire","shock","void"] else ""
	for p in range(pellets):
		var dir:=-camera.global_basis.z
		var cone:=Basis(camera.global_basis.x,rng.randf_range(-spread,spread))*Basis(camera.global_basis.y,rng.randf_range(-spread,spread))
		_ray(camera.global_position,(cone*dir).normalized(),damage,float(row[11]),pierce,element)

func _ray(from: Vector3, dir: Vector3, damage: float, headshot: float, pierce: int, element: String) -> void:
	var space:=get_world_3d().direct_space_state;var exclude: Array[RID]=[mode.player.get_rid()]
	var end:=from+dir*90.;var start:=from;var hits:=0
	while hits<pierce:
		var q:=PhysicsRayQueryParameters3D.create(start,end,RAY_MASK);q.collide_with_areas=true;q.exclude=exclude
		var hit:=space.intersect_ray(q)
		if hit.is_empty():mode.tracer(muzzle.global_position if muzzle else from,end,element);return
		var collider: Object=hit.collider
		var enemy: Variant=collider.get_meta("enemy") if collider.has_meta("enemy") else null
		if enemy is ZombieEnemy and not (enemy as ZombieEnemy).dead:
			var head:=collider is Area3D
			mode.hit_enemy(enemy,damage,head,headshot,hit.position,element)
			exclude.append((enemy as ZombieEnemy).get_rid());exclude.append((collider as CollisionObject3D).get_rid())
			if (enemy as ZombieEnemy).head_area:exclude.append((enemy as ZombieEnemy).head_area.get_rid())
			hits+=1;start=hit.position
			if hits>=pierce:mode.tracer(muzzle.global_position if muzzle else from,hit.position,element);return
		else:
			mode.impact(hit.position,hit.normal);mode.tracer(muzzle.global_position if muzzle else from,hit.position,element);return

func reload() -> void:
	var d:=data()
	if d.is_empty() or reload_t>0. or int(d.reserve)<=0 or int(d.mag)>=mag_size(d.id,int(d.level)):return
	var row:=weapon();reload_total=float(row[7])*(.5 if mode.has_perk("leichenfinger") else 1.);reload_t=reload_total;burst=0
	_mech("reload-out")

func _finish_reload() -> void:
	var d:=data()
	if d.is_empty():return
	var need:=mag_size(d.id,int(d.level))-int(d.mag);var take:=mini(need,int(d.reserve))
	d.mag=int(d.mag)+take;d.reserve=int(d.reserve)-take;_mech("reload-in")
	get_tree().create_timer(.12).timeout.connect(func():if is_instance_valid(self):_mech("chamber"))

func swap(step: int) -> void:
	if slots.size()<2 or melee_t>0.:return
	equip(posmod(current+step,slots.size()))

func melee() -> void:
	if melee_t>0.:return
	melee_t=.45;reload_t=0.;kick=-1.;_mech("melee-swing")
	var dmg:=ZombiesConfig.MELEE_DAMAGE*(2.5 if mode.has_perk("blutdurst") else 1.)*(10. if mode.has_pickup("bloodrush") else 1.)
	mode.melee(camera.global_position,-camera.global_basis.z,dmg)

func _pose(delta: float) -> void:
	if not is_instance_valid(view):return
	bob+=delta*mode.player.velocity.length()*2.2
	var base:=HIP.lerp(AIM,aiming)
	var sway:=Vector3(sin(bob)*.008,absf(cos(bob))*.01,0)*(1.-aiming*.7)
	var dip:=0.
	if reload_t>0.:dip=sin(clampf(1.-reload_t/maxf(reload_total,.01),0,1)*PI)
	if swap_t>0.:dip=maxf(dip,swap_t/.35)
	var stab:=sin(clampf(1.-melee_t/.45,0,1)*PI)*float(melee_t>0.)
	view.position=base+sway+Vector3(0,-dip*.18,kick*.06-stab*.25)
	view.rotation=Vector3(-dip*.9+kick*.06+stab*.5,0,dip*.4)
	if view_left:view_left.position=Vector3(-base.x,base.y,base.z)+sway+Vector3(0,-dip*.18,kick*.05);view_left.rotation=view.rotation
	camera.fov=lerpf(camera.fov,mode.player.base_fov*(1.-aiming*(.55 if str(weapon()[2])=="sniper" else .22)),clampf(delta*10.,0,1)) if not weapon().is_empty() else camera.fov

func snapshot() -> Array:
	var out: Array=[]
	for d in slots:out.append({"id":d.id,"level":d.level,"mag":d.mag,"reserve":d.reserve})
	return out
