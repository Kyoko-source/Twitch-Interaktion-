class_name ZombieEnemy
extends CharacterBody3D

# One member of the horde. Moves on the zombie grid, animates its own rig with
# twitching, wrong motion and attacks; the mode applies damage and rewards.
const LAYER_BODY:=1<<3
const LAYER_HEAD:=1<<4

var mode: Node3D
var kind:=""
var spec: Dictionary={}
var role:="runner"
var boss:=false
var elite:=false
var hp:=100.0
var max_hp:=100.0
var speed:=2.0
var dmg:=25.0
var size_scale:=1.0
var model: Node3D
var parts:={}
var rest:={}
var head_area: Area3D
var shape: CollisionShape3D
var path:=PackedVector3Array()
var path_i:=0
var repath:=0.0
var attack_cd:=0.0
var attack_t:=-1.0
var special_cd:=0.0
var rise:=0.0
var dead:=false
var walk:=0.0
var twitch_t:=0.0
var head_goal:=Vector3.ZERO
var slow:=1.0
var burn:=0.0
var stun:=0.0
var buffed:=0.0
var stuck:=0.0
var boss_phase:=0
var clone:=false
var rng:=RandomNumberGenerator.new()
var glow: OmniLight3D
# Skinned party children (5.1.0) play their own baked actions.
var anim: AnimationPlayer
var anim_lock:=0.0
var current_anim:=""

func setup(owner_mode: Node3D, id: String, data: Dictionary, round_number: int, is_boss: bool, seed_value: int) -> void:
	mode=owner_mode;kind=id;spec=data;boss=is_boss;rng.seed=seed_value
	role="boss" if boss else str(data.get("role","runner"));elite=boss or bool(data.get("elite",false))
	size_scale=float(data.get("scale",1.))
	max_hp=ZombiesConfig.health(round_number)*float(data.get("hp",1.))
	if boss:max_hp=maxf(max_hp,900.)*1.
	hp=max_hp
	speed=ZombiesConfig.speed(round_number)*float(data.get("speed",1.))*rng.randf_range(.9,1.12)
	if boss:speed=2.4*float(data.get("speed",1.))
	dmg=ZombiesConfig.damage(round_number)*float(data.get("dmg",1.))
	if boss:dmg*=1.8
	collision_layer=LAYER_BODY;collision_mask=1|LAYER_BODY
	var radius:=.3 if not boss else .32*size_scale
	var capsule:=CapsuleShape3D.new();capsule.radius=minf(radius,1.1);capsule.height=maxf(1.6*minf(size_scale,1.4),capsule.radius*2.+.1)
	if role=="crawler":capsule.height=.7
	shape=CollisionShape3D.new();shape.shape=capsule;shape.position.y=capsule.height*.5;add_child(shape)
	model=(load(str(data.model)) as PackedScene).instantiate() as Node3D
	add_child(model);model.scale=Vector3.ONE*size_scale
	if str(data.model).contains("visitors-v421"):CharacterFinish.dynamic_only(model)
	for key in ["ArmL","ArmR","LegL","LegR","HeadRig","Torso"]:
		var node:=model.find_child(key,true,false) as Node3D
		if node:parts[key]=node;rest[key]=node.rotation
	anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim:
		for loop_name in ["Idle","Walk","Run","Crawl"]:
			if anim.has_animation(loop_name):anim.get_animation(loop_name).loop_mode=Animation.LOOP_LINEAR
		anim.playback_default_blend_time=.18;_play("Crawl" if role=="crawler" else "Idle")
		anim.seek(rng.randf()*.8,true)
	elif role=="crawler":model.rotation.x=1.15;model.position.y=.22
	var head_height:=(1.62 if role!="crawler" else .42)*minf(size_scale,1.)
	if boss or role=="tank":head_height=capsule.height*.85
	head_area=Area3D.new();head_area.collision_layer=LAYER_HEAD;head_area.collision_mask=0;head_area.monitoring=false;head_area.set_meta("enemy",self)
	var head_shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.17*maxf(size_scale*.6,1.) if not boss else .35*size_scale*.5;head_shape.shape=sphere
	head_area.add_child(head_shape)
	var skeleton:=model.find_child("*",true,false) as Skeleton3D if false else _skeleton()
	if skeleton and skeleton.find_bone("head")>=0:
		# The head hitbox rides the head bone through every lean, twitch and fall.
		var follow:=BoneAttachment3D.new();follow.bone_name="head";skeleton.add_child(follow)
		follow.add_child(head_area);head_area.position=Vector3(0,.16,-.02);sphere.radius=.15
	else:
		add_child(head_area);head_area.position=Vector3(0,head_height,.08 if role!="crawler" else .45)
	set_meta("enemy",self)
	if elite:
		glow=OmniLight3D.new();glow.omni_range=2.4*maxf(size_scale*.6,1.);glow.light_energy=1.2 if not boss else 3.
		glow.light_color={"spitter":Color("8aff4a"),"screamer":Color("ff4aa0"),"teleporter":Color("8a6aff"),"tank":Color("ffb6d9"),"alien":Color("44ff8a"),"jumper":Color("ffa040"),"boss":Color("ff2a2a")}.get(role,Color("ff4040"))
		glow.position=Vector3(0,head_height,.3);glow.shadow_enabled=false;add_child(glow)
	if role=="alien":_alien_skin()
	rise=.9;model.position.y=-1.8*minf(size_scale,1.5)
	special_cd=rng.randf_range(1.5,4.)

func _skeleton() -> Skeleton3D:
	var found:=model.find_children("*","Skeleton3D",true,false)
	return found[0] as Skeleton3D if not found.is_empty() else null

func _alien_skin() -> void:
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode blend_add,unshaded,depth_draw_never,cull_back;
void fragment(){float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);ALBEDO=vec3(.2,1.,.5)*rim*(1.2+.6*sin(TIME*6.0+VERTEX.y*8.0));ALPHA=1.0;}"""
	var m:=ShaderMaterial.new();m.shader=shader
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):mesh.material_overlay=m

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(mode):return
	var scale_t: float=mode.enemy_time_scale()*slow
	if rise>0.:
		rise-=delta;model.position.y=lerpf(-1.8*minf(size_scale,1.5),.22 if role=="crawler" and not anim else 0.,clampf(1.-rise/.9,0,1));return
	if burn>0.:
		burn-=delta;mode.damage_enemy(self,max_hp*.07*delta+12.*delta,false,"fire",false)
		if dead:return
	attack_cd-=delta*scale_t;special_cd-=delta*scale_t;buffed=maxf(buffed-delta,0.);slow=move_toward(slow,1.,delta*.5)
	var target: Vector3=mode.player_position()
	var to:=target-global_position;to.y=0;var dist:=to.length()
	var dir:=Vector3.ZERO
	if stun>0.:stun-=delta
	elif mode.player_hidden():
		repath-=delta
		if repath<=0.:repath=2.;path=mode.nav.path(global_position,global_position+Vector3(rng.randf_range(-6,6),0,rng.randf_range(-6,6)));path_i=1
		dir=_follow()
	else:
		var direct: bool=dist<7. and mode.line_clear(global_position+Vector3.UP,target+Vector3.UP*.8)
		if direct:dir=to.normalized()
		else:
			repath-=delta
			if repath<=0. or path_i>=path.size():
				repath=rng.randf_range(.45,.8);path=mode.nav.path(global_position,target);path_i=1
			dir=_follow()
	var move_speed:=speed*scale_t*(1.45 if buffed>0. else 1.)
	match role:
		"spitter":
			if dist<5.:dir=-to.normalized()
			elif dist<9. and mode.line_clear(global_position+Vector3.UP*1.4,target+Vector3.UP*1.2):dir=Vector3.ZERO
			if special_cd<=0. and dist<14. and mode.line_clear(global_position+Vector3.UP*1.4,target+Vector3.UP*1.2):
				special_cd=rng.randf_range(2.6,3.6);mode.spit(self,global_position+Vector3(0,1.45*size_scale,0)+to.normalized()*.4,target+Vector3.UP*1.2)
		"screamer":
			if special_cd<=0. and dist<16.:special_cd=rng.randf_range(6.,9.);mode.scream(self)
		"teleporter":
			if special_cd<=0. and dist>6.:special_cd=rng.randf_range(5.,8.);mode.teleport_near(self)
		"jumper":
			if special_cd<=0. and dist>3. and dist<7.5 and is_on_floor():
				special_cd=rng.randf_range(3.5,5.);velocity=to.normalized()*9.5+Vector3.UP*5.8;mode.enemy_sound(self,"leap")
		"boss":
			_boss_tick(dist,to)
	if is_on_floor() or role=="boss":
		var want:=dir*move_speed
		velocity.x=move_toward(velocity.x,want.x,delta*14.);velocity.z=move_toward(velocity.z,want.z,delta*14.)
	velocity.y-=20.*mode.gravity_scale()*delta
	if is_on_floor() and velocity.y<0.:velocity.y=-.1
	var before:=global_position
	move_and_slide()
	if dir.length()>.1 and before.distance_to(global_position)<move_speed*delta*.25:
		stuck+=delta
		if stuck>1.2:stuck=0.;repath=0.;velocity+=Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2))
	else:stuck=0.
	if global_position.y<-6.:mode.recover_enemy(self)
	var face:=to if dist<7. or dir.length()<.1 else dir
	if face.length()>.05:rotation.y=lerp_angle(rotation.y,atan2(face.x,face.z),clampf(delta*9.,0,1))
	# Melee: wind up, then strike if still close.
	var reach:=1.35 if not boss else 1.1+size_scale*.6
	if attack_t<0. and attack_cd<=0. and dist<reach:
		attack_t=.42;attack_cd=1.35 if not boss else 1.7
		if anim and role!="crawler":
			var swing:="Attack2" if anim.has_animation("Attack2") and rng.randf()<.5 else "Attack"
			_play(swing,1.25,.68)
	if attack_t>=0.:
		attack_t-=delta*scale_t
		if attack_t<0. and dist<reach+.35:mode.hurt_player(dmg,self)
	_animate(delta,Vector2(velocity.x,velocity.z).length())

func _follow() -> Vector3:
	while path_i<path.size() and Vector2(path[path_i].x-global_position.x,path[path_i].z-global_position.z).length()<.45:path_i+=1
	if path_i>=path.size():return Vector3.ZERO
	var d:=path[path_i]-global_position;d.y=0
	return d.normalized()

func _boss_tick(dist: float, to: Vector3) -> void:
	var ratio:=hp/max_hp
	var phase_now:=0 if ratio>.66 else 1 if ratio>.33 else 2
	if phase_now>boss_phase:
		boss_phase=phase_now;speed*=1.25;mode.boss_phase(self,boss_phase)
	if special_cd>0.:return
	var attacks: Array=spec.get("attacks",["charge"])
	var attack: String=attacks[rng.randi_range(0,mini(attacks.size()-1,boss_phase+1))]
	special_cd=rng.randf_range(4.5,7.)-boss_phase*1.2
	match attack:
		"charge":
			if dist>4.:velocity=to.normalized()*speed*3.2;stun=-0.;mode.boss_attack(self,"charge")
		"summon":mode.boss_attack(self,"summon")
		"shockwave","stomp":mode.boss_attack(self,"shockwave")
		"spit":mode.spit(self,global_position+Vector3(0,1.4*size_scale*.6,0),mode.player_position()+Vector3.UP*1.2,true)
		"teleport":mode.teleport_near(self)

func _play(id: String, rate: float=1., lock: float=0.) -> void:
	if not anim or not anim.has_animation(id):return
	if current_anim!=id or lock>0.:anim.play(id,.15 if lock>0. else -1.);current_anim=id
	anim.speed_scale=rate;anim_lock=maxf(anim_lock,lock)

func _animate_skinned(delta: float, moving: float) -> void:
	anim_lock-=delta
	if anim_lock>0.:return
	if role=="crawler":_play("Crawl",clampf(moving/1.,.6,1.8));return
	if moving<.35:_play("Idle",1.)
	elif moving<2.6:_play("Walk",clampf(moving/1.35,.7,1.9))
	else:_play("Run",clampf(moving/3.6,.8,1.7))

func _animate(delta: float, moving: float) -> void:
	if anim:_animate_skinned(delta,moving);return
	walk+=delta*(2.5+moving*2.4)
	var amp:=clampf(moving/2.5,.2,1.)
	twitch_t-=delta
	if twitch_t<=0.:
		twitch_t=rng.randf_range(.12,.55)
		head_goal=Vector3(rng.randf_range(-.35,.45),rng.randf_range(-.6,.6),rng.randf_range(-.7,.7))
	var striking:=attack_t>=0.
	if parts.has("LegL"):
		(parts.LegL as Node3D).rotation.x=rest.LegL.x+sin(walk)*.75*amp
		(parts.LegR as Node3D).rotation.x=rest.LegR.x-sin(walk)*.75*amp
	if parts.has("ArmL"):
		var reach:=-1.25 if role!="crawler" else -.4
		var swing:=-.35+(.34-attack_t)*4. if striking else 0.
		(parts.ArmL as Node3D).rotation.x=rest.ArmL.x+reach+sin(walk*.5+1.)*.18+swing
		(parts.ArmR as Node3D).rotation.x=rest.ArmR.x+reach+sin(walk*.5)*.18+swing*.8
		(parts.ArmL as Node3D).rotation.z=rest.ArmL.z+sin(walk*1.7)*.12
		(parts.ArmR as Node3D).rotation.z=rest.ArmR.z-sin(walk*1.3)*.12
	if parts.has("HeadRig"):
		var h: Node3D=parts.HeadRig
		h.rotation=h.rotation.lerp(rest.HeadRig+head_goal,clampf(delta*(18. if rng.randf()<.3 else 6.),0,1))
	var lean:=.25 if role=="sprinter" else .12
	if role!="crawler":model.rotation.x=lean*amp+sin(walk*2.)*.03
	model.rotation.z=sin(walk*.5)*.09+(sin(Time.get_ticks_msec()*.031)*.05 if rng.randf()<.08 else 0.)
	if not parts.has("LegL"):
		model.position.y=absf(sin(walk))*.08*size_scale;model.rotation.z=sin(walk)*.12

func hit_flash() -> void:
	if glow:glow.light_energy*=1.6
	if anim and anim_lock<=0. and role!="crawler" and rng.randf()<.45:_play("Hit",1.3,.24)

func die(explosive: bool) -> void:
	if dead:return
	dead=true;collision_layer=0;collision_mask=1;head_area.collision_layer=0;velocity=Vector3.ZERO
	if glow:glow.queue_free();glow=null
	var tween:=create_tween()
	if anim and not explosive:
		_play("Death",rng.randf_range(.9,1.15),9.)
		tween.tween_interval(2.6);tween.tween_property(model,"position:y",-1.4,1.4);tween.tween_callback(queue_free)
		return
	if explosive:
		tween.tween_property(model,"scale",Vector3.ONE*size_scale*.05,.25)
	else:
		var fall:=-1.35 if rng.randf()<.6 else 1.25
		tween.set_parallel(true)
		tween.tween_property(model,"rotation:x",fall,.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(model,"position:y",.15,.55)
		tween.set_parallel(false)
		tween.tween_interval(1.6)
		tween.tween_property(model,"position:y",-1.4,1.4)
	tween.tween_callback(queue_free)
