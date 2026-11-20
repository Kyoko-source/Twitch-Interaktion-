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
# 5.2.0: effects, glowing parts and the special weapons.
var fx: ZombiesFx
var glow_mats: Array=[]
var flame_t:=0.0
const MUZZLE_SIZE:={"pistol":.8,"revolver":1.1,"smg":.9,"rifle":1.1,"shotgun":1.6,"lmg":1.3,"sniper":1.7,"rift":1.5,"tesla":.9,"launcher":1.7}
const TIER:={"common":0,"uncommon":1,"rare":2,"epic":3,"legendary":4}
const CAMO:="""shader_type spatial;
uniform vec3 base:source_color=vec3(.15);
uniform vec3 tone:source_color=vec3(1.,.4,.1);
uniform float level=1.0;
varying vec3 lp;
void vertex(){lp=VERTEX;}
float h(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
void fragment(){
 float band=smoothstep(.72,1.,sin(lp.z*70.+lp.y*40.-TIME*5.));
 vec3 cell=floor(lp*38.);float spark=step(.86,h(cell))*(.5+.5*sin(TIME*4.+h(cell)*20.));
 float vein=smoothstep(.93,1.,sin(lp.x*90.+sin(lp.z*30.+TIME)*3.));
 ALBEDO=base*.7;METALLIC=.9;ROUGHNESS=.28;
 EMISSION=tone*(band*.8+spark*.9+vein*.5*level)*(.18+level*.12);}"""

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
	for special in [["tesla","zap-0"],["launcher","launcher"]]:
		var path:=ZombiesFx.SFX+str(special[1])+".ogg"
		shots[special[0]]=[load(path)] if ResourceLoader.exists(path) else [_gunshot("rift")]
	shots["flamer"]=[]
	fx=mode.fx
	flash=OmniLight3D.new();flash.light_volumetric_fog_energy=0.;flash.light_color=Color("ffc27a");flash.omni_range=5.;flash.light_energy=0.;flash.shadow_enabled=false;add_child(flash)

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
	view=null;view_left=null;glow_mats=[]
	var row:=weapon()
	if row.is_empty():return
	view=_frame(row,int(data().level));add_child(view)
	if str(row[15])=="dual":
		view_left=_frame(row,int(data().level));add_child(view_left);view_left.scale.x=-1.
	muzzle=view.find_child("Muzzle",true,false) as Node3D
	_mech("swap")

static func _std(id: String, color: Color, metal: float, rough: float, glow: float=0.) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.resource_name=id;m.albedo_color=color;m.metallic=metal;m.roughness=rough
	if glow>0.:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	return m

static func _part(root: Node3D, mesh: PrimitiveMesh, mat: Material, at: Vector3, rot: Vector3=Vector3.ZERO) -> MeshInstance3D:
	mesh.material=mat;var mi:=MeshInstance3D.new();mi.mesh=mesh;mi.position=at;mi.rotation=rot;root.add_child(mi);return mi

static func _cyl(r_top: float, r_bottom: float, h: float) -> CylinderMesh:
	var c:=CylinderMesh.new();c.top_radius=r_top;c.bottom_radius=r_bottom;c.height=h;c.radial_segments=20;return c

static func _box(size_value: Vector3) -> BoxMesh:
	var b:=BoxMesh.new();b.size=size_value;return b

static func _torus(inner: float, outer: float) -> TorusMesh:
	var t:=TorusMesh.new();t.inner_radius=inner;t.outer_radius=outer;t.rings=24;t.ring_segments=10;return t

# Model of a frame: the modelled guns or the three party weapons built here.
static func frame_model(frame: String) -> Node3D:
	if not frame in ZombiesConfig.SPECIAL_FRAMES:
		return (load("res://assets/zombies-v500/weapon-%s.glb"%frame) as PackedScene).instantiate() as Node3D
	var root:=Node3D.new();root.name="Weapon_"+frame
	var metal:=_std("GunMetal",Color(.16,.17,.2),.85,.32);var poly:=_std("GunPolymer",Color(.07,.07,.08),0.,.75);var accent:=_std("GunAccent",Color.WHITE,.3,.35,1.6)
	var along:=Vector3(PI*.5,0,0)
	var muzzle_at:=Vector3.ZERO
	match frame:
		"flamer":
			_part(root,_box(Vector3(.07,.09,.42)),metal,Vector3(0,.02,-.2))
			_part(root,_cyl(.065,.065,.34),accent,Vector3(0,-.075,-.06),along)
			for z in [-.2,-.06,.08]:_part(root,_cyl(.069,.069,.02),metal,Vector3(0,-.075,z),along)
			_part(root,_box(Vector3(.04,.12,.05)),poly,Vector3(0,-.07,.1),Vector3(.3,0,0))
			_part(root,_cyl(.02,.032,.2),metal,Vector3(0,.03,-.5),along)
			_part(root,_torus(.024,.034),accent,Vector3(0,.03,-.58),along)
			_part(root,_cyl(.006,.006,.22),accent,Vector3(.045,.03,-.3),along)
			var pilot:=SphereMesh.new();pilot.radius=.012;pilot.height=.024
			var flame_mat:=StandardMaterial3D.new();flame_mat.resource_name="PilotFlame";flame_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flame_mat.albedo_color=Color(.5,.7,1.)
			_part(root,pilot,flame_mat,Vector3(0,.0,-.61))
			muzzle_at=Vector3(0,.03,-.63)
		"tesla":
			_part(root,_box(Vector3(.07,.1,.34)),metal,Vector3(0,.02,-.1))
			_part(root,_box(Vector3(.04,.12,.05)),poly,Vector3(0,-.07,.1),Vector3(.3,0,0))
			_part(root,_cyl(.018,.018,.32),poly,Vector3(0,.03,-.4),along)
			for i in range(4):_part(root,_torus(.03,.046-i*.003),accent,Vector3(0,.03,-.3-i*.055),along)
			var orb:=SphereMesh.new();orb.radius=.036;orb.height=.072;_part(root,orb,accent,Vector3(0,.03,-.57))
			for x in [-.032,.032]:_part(root,_box(Vector3(.008,.008,.12)),metal,Vector3(x,.03,-.6),Vector3(0,-x*4.,0))
			var cell:=CapsuleMesh.new();cell.radius=.02;cell.height=.12;_part(root,cell,accent,Vector3(.05,0,-.05),along)
			muzzle_at=Vector3(0,.03,-.6)
		"launcher":
			_part(root,_cyl(.066,.066,.6),metal,Vector3(0,.045,-.26),along)
			_part(root,_cyl(.072,.06,.06),poly,Vector3(0,.045,-.57),along)
			for z in [-.06,-.44]:_part(root,_torus(.064,.076),accent,Vector3(0,.045,z),along)
			_part(root,_cyl(.1,.1,.14),poly,Vector3(0,-.01,-.02),along)
			_part(root,_cyl(.102,.102,.03),accent,Vector3(0,-.01,-.1),along)
			_part(root,_box(Vector3(.04,.12,.05)),poly,Vector3(0,-.09,.1),Vector3(.3,0,0))
			_part(root,_box(Vector3(.012,.05,.04)),accent,Vector3(0,.13,-.45))
			muzzle_at=Vector3(0,.045,-.6)
	var muzzle_node:=Node3D.new();muzzle_node.name="Muzzle";muzzle_node.position=muzzle_at;root.add_child(muzzle_node)
	return root

func _frame(row: Array, level: int) -> Node3D:
	var node:=frame_model(str(row[2]))
	var accent: Color=row[14]
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mesh.mesh.get_surface_count()):
			var m:=mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if not m:continue
			if level>0 and m.resource_name=="GunMetal":
				var camo:=ShaderMaterial.new();var shader:=Shader.new();shader.code=CAMO;camo.shader=shader
				camo.set_shader_parameter("base",m.albedo_color);camo.set_shader_parameter("tone",_tone(ZombiesConfig.elements(level,str(row[15]))));camo.set_shader_parameter("level",float(level))
				mesh.set_surface_override_material(s,camo);continue
			if m.resource_name=="GunAccent" or (level>0 and m.resource_name=="GunMetal"):
				var copy:=m.duplicate() as StandardMaterial3D
				if m.resource_name=="GunAccent":copy.albedo_color=accent;copy.emission=accent
				if level>0:
					var tone: Color={"fire":Color("ff5a1a"),"shock":Color("6af2ff"),"void":Color("b05aff")}[ZombiesConfig.UPGRADE_ELEMENT[level]]
					copy.emission_enabled=true;copy.emission=tone;copy.emission_energy_multiplier=(1.2+level*.8) if m.resource_name=="GunAccent" else .12+level*.06
				mesh.set_surface_override_material(s,copy)
				if m.resource_name=="GunAccent" and level>0:copy.albedo_color=copy.emission.darkened(.55);copy.emission_energy_multiplier=.9
	_dress(node,row,level)
	for vi: VisualInstance3D in node.find_children("*","VisualInstance3D",true,false):vi.layers=2
	return node

func _tone(elements: String) -> Color:
	if elements=="":return Color("ffc27a")
	var list:=elements.split("+",false)
	return ZombiesFx.ELEMENT_COLOR.get(list[list.size()-1],Color("ffc27a"))

# Glowing coils, energy cells, holo sights and fins: more with rarity and level.
func _dress(node: Node3D, row: Array, level: int) -> void:
	var mz:=node.find_child("Muzzle",true,false) as Node3D
	if not mz:return
	var t:=Transform3D.IDENTITY;var walk: Node=mz
	while walk and walk!=node:t=(walk as Node3D).transform*t;walk=walk.get_parent()
	var at:=t.origin;var tier: int=TIER.get(str(row[13]),0)
	var color: Color=row[14] if level==0 else _tone(ZombiesConfig.elements(level,str(row[15])))
	var glow:=StandardMaterial3D.new();glow.albedo_color=color.darkened(.4);glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=2.5;glow.metallic=.4;glow.roughness=.3
	glow_mats.append(glow)
	var along:=Vector3(PI*.5,0,0)
	var coils:=mini(tier+level,4)
	var radius:=.024 if str(row[2]) in ["pistol","revolver","smg"] else .032
	for i in range(coils):_part(node,_torus(radius,radius+.007),glow,Vector3(0,at.y,at.z+.06+i*.04),along)
	if tier>=2 or level>=2:
		var cell:=CapsuleMesh.new();cell.radius=.013;cell.height=.09;_part(node,cell,glow,Vector3(.034,at.y-.035,at.z*.45),along)
		_part(node,_box(Vector3(.02,.012,.07)),_std("GunMetal",Color(.2,.2,.22),.8,.3),Vector3(.026,at.y-.035,at.z*.45))
	if tier>=3 or level>=3:
		var holo:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2(.06,.06);holo.mesh=q
		var hm:=StandardMaterial3D.new();hm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;hm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;hm.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;hm.albedo_texture=load(ZombiesFx.FX+"ring.png");hm.albedo_color=color;hm.cull_mode=BaseMaterial3D.CULL_DISABLED
		holo.material_override=hm;holo.position=Vector3(0,at.y+.075,at.z*.3);node.add_child(holo)
		_part(node,_box(Vector3(.008,.04,.008)),glow,Vector3(0,at.y+.045,at.z*.3))
	if tier>=4 or level>=3:
		for side in [-1.,1.]:_part(node,_box(Vector3(.004,.05,.14)),glow,Vector3(.03*side,at.y+.025,at.z*.6),Vector3(0,0,.5*side))
	if level>0 and fx:
		var p:=CPUParticles3D.new();p.amount=10;p.lifetime=.7;p.local_coords=false
		var pq:=QuadMesh.new();pq.size=Vector2.ONE*.025;pq.material=fx._mat("glow",true);p.mesh=pq;p.color=color
		p.direction=Vector3.UP;p.spread=60.;p.initial_velocity_min=.05;p.initial_velocity_max=.25;p.gravity=Vector3(0,.6 if level!=3 else -.2,0)
		p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=.05;p.position=Vector3(0,at.y,at.z*.6);node.add_child(p);p.emitting=true

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
	flame_t=maxf(flame_t-delta,0.)
	if fx and muzzle and not row.is_empty() and str(row[15])=="flame":fx.flame(muzzle.global_position,-camera.global_basis.z,flame_t>0.)
	var pulse:=1.1+sin(Time.get_ticks_msec()*.006)*.5+kick*1.5
	for m: StandardMaterial3D in glow_mats:m.emission_energy_multiplier=pulse
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
	var frame: String=row[2];var special:=str(row[15])
	var elements:=ZombiesConfig.elements(level,special)
	var tone: Color=_tone(elements) if elements!="" or not ZombiesFx.ELEMENT_COLOR.has(special) else ZombiesFx.ELEMENT_COLOR[special]
	var variants: Array=shots.get(frame,[])
	if not variants.is_empty():
		shot.stream=variants[rng.randi_range(0,variants.size()-1)];shot.pitch_scale=rng.randf_range(.94,1.06)*(.86 if level>0 else 1.);shot.play()
	flash.light_energy=(3.5 if frame!="rift" else 6.)*(.5 if special=="flame" else 1.);flash.light_color=tone
	if muzzle:
		flash.global_position=muzzle.global_position
		if fx and special!="flame":fx.muzzle(muzzle,tone,float(MUZZLE_SIZE.get(frame,1.))*(1.25 if level>0 else 1.),camera)
		if view_left and fx and special!="flame":
			var left_muzzle:=view_left.find_child("Muzzle",true,false) as Node3D
			if left_muzzle:fx.muzzle(left_muzzle,tone,float(MUZZLE_SIZE.get(frame,1.)),camera)
		if fx and frame in ["pistol","smg","rifle","lmg","sniper","shotgun"]:fx.casing(muzzle.global_position+camera.global_basis.z*.28+camera.global_basis.x*.03,camera)
	var steady:=.6 if mode.has_perk("leerer_blick") else 1.
	kick=1.;recoil+=float(row[10])*steady
	mode.player.camera.rotation.x=clampf(mode.player.camera.rotation.x+float(row[10])*.012*steady*(1.-aiming*.4),-1.35,1.35)
	mode.player.rotate_y(rng.randf_range(-1,1)*float(row[10])*.004*steady)
	var from_muzzle:=muzzle.global_position if muzzle else camera.global_position
	var hit_damage:=float(row[3])*float(ZombiesConfig.UPGRADE_DAMAGE[level])
	match special:
		"rift":mode.rift_shot(from_muzzle,-camera.global_basis.z,hit_damage);return
		"flame":flame_t=.12;mode.flame_hit(camera.global_position,-camera.global_basis.z,hit_damage,elements);return
		"tesla":mode.tesla_shot(from_muzzle,camera.global_position,-camera.global_basis.z,hit_damage,elements);return
		"launcher":mode.cake_shot(from_muzzle,(-camera.global_basis.z+camera.global_basis.y*.08).normalized(),hit_damage,level);return
	var spread:=deg_to_rad(float(row[8]))*(1.-aiming*.6)*steady*(1.35 if mode.player.velocity.length()>3. else 1.)
	var pellets:=int(row[9])
	var damage:=float(row[3])*float(ZombiesConfig.UPGRADE_DAMAGE[level])
	var pierce:=3 if str(row[15])=="pierce" else 1
	var element:=elements
	for p in range(pellets):
		var dir:=-camera.global_basis.z
		var cone:=Basis(camera.global_basis.x,rng.randf_range(-spread,spread))*Basis(camera.global_basis.y,rng.randf_range(-spread,spread))
		_ray(camera.global_position,(cone*dir).normalized(),damage,float(row[11]),pierce,element)

func _ray(from: Vector3, dir: Vector3, damage: float, headshot: float, pierce: int, element: String) -> void:
	var space:=get_world_3d().direct_space_state;var exclude: Array[RID]=[mode.player.get_rid()]
	var end:=from+dir*90.;var start:=from;var hits:=0;var passes:=0
	while hits<pierce and passes<12:
		passes+=1
		var q:=PhysicsRayQueryParameters3D.create(start,end,RAY_MASK);q.collide_with_areas=true;q.exclude=exclude
		var hit:=space.intersect_ray(q)
		if hit.is_empty():mode.tracer(muzzle.global_position if muzzle else from,end,element);return
		var collider: Object=hit.collider
		# Bullets fly through the climbing frame's nets.
		if mode.is_net(collider):exclude.append((collider as CollisionObject3D).get_rid());start=hit.position;continue
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
