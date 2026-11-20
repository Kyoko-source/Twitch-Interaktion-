class_name ZombiesFx
extends Node3D

# After Play 5.2.0: the loud side of the Partynacht. Muzzle flashes, glowing
# tracers, sparks, blood sprays with floor and wall splats, gibs, confetti,
# explosions with fireballs, smoke and scorch marks, jagged chain lightning,
# burning guests, the flamethrower stream, void implosions, floating damage
# numbers and positional one-shot sounds. Textures, sounds and music are made
# by tools/make-after-play-zombies-fx-v520.py.
const FX:="res://assets/zombies-v520/fx/"
const SFX:="res://assets/zombies-v520/sfx/"
const MAX_BLOOD:=140
const MAX_HOLES:=70
const MAX_SCORCH:=24
const MAX_NUMBERS:=36
const ELEMENT_COLOR:={"fire":Color("ff6a1a"),"shock":Color("6af2ff"),"void":Color("b05aff"),"phase":Color("8a5cff"),"rift":Color("44ff8a"),"flame":Color("ff8a2a"),"tesla":Color("7af6ff"),"launcher":Color("ff6ac8")}
const CONFETTI:=[Color("ff3a6a"),Color("ffd23a"),Color("3affb0"),Color("3aa8ff"),Color("c06aff"),Color("ff8a2a")]

var mode: Node3D
var rng:=RandomNumberGenerator.new()
var live: Array=[]
var decals:={"blood":[],"hole":[],"scorch":[]}
var numbers: Array=[]
var materials:={}
var textures:={}
var sounds:={}
var voices: Array=[]
var flame_emitter: CPUParticles3D
var flame_core: CPUParticles3D
var flame_light: OmniLight3D
var flame_audio: AudioStreamPlayer
var flame_on:=0.0
var burning:={}
var shake_out:=0.0

func setup(owner_mode: Node3D) -> void:
	mode=owner_mode;name="ZombiesFx";rng.randomize()
	for i in range(10):
		var p:=AudioStreamPlayer3D.new();p.unit_size=7.;p.max_distance=60.;p.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE;p.panning_strength=1.1;add_child(p);voices.append(p)
	flame_audio=AudioStreamPlayer.new();flame_audio.volume_db=-6.;flame_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(flame_audio)
	var loop:=_sound("flame-loop")
	if loop is AudioStreamOggVorbis:
		var l:=(loop as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis;l.loop=true;flame_audio.stream=l
	flame_emitter=_emitter("flame",Color.WHITE,true,48,.55);flame_emitter.emitting=false
	flame_emitter.color_ramp=_ramp([Color(1,.95,.7,1),Color(1,.55,.12,.9),Color(.9,.15,.02,.6),Color(.15,.05,.03,0)])
	flame_emitter.scale_amount_min=.35;flame_emitter.scale_amount_max=.6;flame_emitter.scale_amount_curve=_curve([0.,.25,1.],[.3,1.,2.2])
	flame_emitter.spread=9.;flame_emitter.initial_velocity_min=9.;flame_emitter.initial_velocity_max=13.;flame_emitter.gravity=Vector3(0,1.6,0);flame_emitter.damping_min=6.;flame_emitter.damping_max=9.
	flame_emitter.angle_min=-180.;flame_emitter.angle_max=180.;flame_emitter.angular_velocity_min=-90.;flame_emitter.angular_velocity_max=90.
	flame_core=_emitter("glow",Color.WHITE,true,30,.25);flame_core.emitting=false
	flame_core.color_ramp=_ramp([Color(.7,.85,1,1),Color(1,.8,.4,.8),Color(1,.4,.1,0)]);flame_core.scale_amount_min=.12;flame_core.scale_amount_max=.2
	flame_core.spread=4.;flame_core.initial_velocity_min=7.;flame_core.initial_velocity_max=9.
	flame_light=OmniLight3D.new();flame_light.light_volumetric_fog_energy=0.;flame_light.light_color=Color("ff7a2a");flame_light.omni_range=7.;flame_light.light_energy=0.;flame_light.shadow_enabled=false;add_child(flame_light)

# ---------------------------------------------------------------- resources
func _tex(key: String) -> Texture2D:
	if not textures.has(key):textures[key]=load(FX+key+".png") if ResourceLoader.exists(FX+key+".png") else null
	return textures[key]

func _sound(key: String) -> AudioStream:
	if not sounds.has(key):sounds[key]=load(SFX+key+".ogg") if ResourceLoader.exists(SFX+key+".ogg") else null
	return sounds[key]

func _mat(tex_key: String, additive: bool, billboard: int=BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var key:="%s|%s|%d"%[tex_key,additive,billboard]
	if materials.has(key):return materials[key]
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX;m.billboard_mode=billboard;m.billboard_keep_scale=true
	m.vertex_color_use_as_albedo=true;m.albedo_texture=_tex(tex_key);m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.no_depth_test=false
	if billboard==BaseMaterial3D.BILLBOARD_PARTICLES:m.particles_anim_h_frames=1;m.particles_anim_v_frames=1
	materials[key]=m;return m

func _ramp(colors: Array) -> Gradient:
	var g:=Gradient.new();var offsets:=PackedFloat32Array();var cols:=PackedColorArray()
	for i in range(colors.size()):offsets.append(float(i)/maxf(colors.size()-1,1));cols.append(colors[i])
	g.offsets=offsets;g.colors=cols;return g

func _curve(xs: Array, ys: Array) -> Curve:
	var c:=Curve.new();c.max_value=4.
	for i in range(xs.size()):c.add_point(Vector2(float(xs[i]),float(ys[i])))
	return c

func _emitter(tex_key: String, color: Color, additive: bool, amount: int, life: float) -> CPUParticles3D:
	var p:=CPUParticles3D.new();p.amount=maxi(amount,1);p.lifetime=life;p.local_coords=false
	var q:=QuadMesh.new();q.size=Vector2.ONE;q.material=_mat(tex_key,additive);p.mesh=q;p.color=color
	p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(p);return p

func _track(node: Node, life: float, extra: Dictionary={}) -> void:
	var entry:={"node":node,"life":life,"total":life};entry.merge(extra);live.append(entry)

# One-shot burst. dir=ZERO means all around.
func burst(at: Vector3, tex_key: String, color: Color, amount: int, speed: float, size_min: float, size_max: float, life: float, gravity: float=-9., dir: Vector3=Vector3.ZERO, spread: float=180., additive: bool=true, fade: Gradient=null, grow: Curve=null) -> CPUParticles3D:
	var p:=_emitter(tex_key,color,additive,amount,life);p.one_shot=true;p.explosiveness=.92;p.randomness=.5
	p.global_position=at;p.direction=dir if dir!=Vector3.ZERO else Vector3.UP;p.spread=spread
	p.initial_velocity_min=speed*.35;p.initial_velocity_max=speed;p.gravity=Vector3(0,gravity,0)
	p.scale_amount_min=size_min;p.scale_amount_max=size_max;p.angle_min=-180.;p.angle_max=180.
	p.color_ramp=fade if fade else _ramp([Color(1,1,1,1),Color(1,1,1,0)])
	if grow:p.scale_amount_curve=grow
	p.emitting=true;_track(p,life+.3);return p

func sound(key: String, at: Vector3, volume: float=0., pitch: float=1., variants: int=1) -> void:
	var name_key:=key if variants<=1 else "%s-%d"%[key,rng.randi_range(0,variants-1)]
	var s:=_sound(name_key)
	if not s:return
	var best: AudioStreamPlayer3D=voices[0]
	for v: AudioStreamPlayer3D in voices:
		if not v.playing:best=v;break
	best.global_position=at;best.stream=s;best.volume_db=volume;best.pitch_scale=pitch*rng.randf_range(.94,1.06);best.play()

func light(at: Vector3, color: Color, energy: float, radius: float, life: float) -> void:
	var l:=OmniLight3D.new();l.light_volumetric_fog_energy=0.;l.light_color=color;l.light_energy=energy;l.omni_range=radius;l.shadow_enabled=false;add_child(l);l.global_position=at
	_track(l,life,{"light":energy})

# ---------------------------------------------------------------- decals
func _decal(kind: String, tex_key: String, at: Vector3, normal: Vector3, size_value: float, tint: Color, limit: int, fade_after: float) -> void:
	var d:=Decal.new();d.texture_albedo=_tex(tex_key);d.modulate=tint;d.size=Vector3(size_value,.5,size_value);d.cull_mask=1;d.upper_fade=.3;d.lower_fade=.3;d.albedo_mix=1.
	add_child(d);d.global_position=at
	var up:=normal.normalized();var side:=up.cross(Vector3.RIGHT if absf(up.x)<.9 else Vector3.FORWARD).normalized()
	d.global_basis=Basis(side,up,side.cross(up)).rotated(up,rng.randf()*TAU)
	var list: Array=decals[kind];list.append({"node":d,"age":0.,"fade":fade_after})
	while list.size()>limit:
		var old: Dictionary=list.pop_front()
		if is_instance_valid(old.node):(old.node as Node).queue_free()

func _surface(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(from,from+dir.normalized()*reach,1);q.exclude=[mode.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func splat(at: Vector3, dir: Vector3, amount: float) -> void:
	var floor_hit:=_surface(at+Vector3.UP*.2,Vector3.DOWN,4.)
	if not floor_hit.is_empty():
		var spot: Vector3=floor_hit.position+Vector3(rng.randf_range(-.4,.4),0,rng.randf_range(-.4,.4))*amount
		_decal("blood","blood-%d"%rng.randi_range(0,5),spot,floor_hit.normal,rng.randf_range(.9,1.6)*clampf(amount,.6,2.2),Color(1,1,1,rng.randf_range(.85,1.)),MAX_BLOOD,60.)
	if dir!=Vector3.ZERO:
		var wall_hit:=_surface(at,dir+Vector3(0,rng.randf_range(-.2,.1),0),3.2)
		if not wall_hit.is_empty():
			_decal("blood","blood-%d"%rng.randi_range(0,5),wall_hit.position,wall_hit.normal,rng.randf_range(.8,1.4)*clampf(amount,.6,1.8),Color.WHITE,MAX_BLOOD,60.)

# ---------------------------------------------------------------- guns
func muzzle(m: Node3D, color: Color, size_value: float, cam: Camera3D) -> void:
	if not is_instance_valid(m):return
	var root:=Node3D.new();m.add_child(root);root.global_basis=cam.global_basis.orthonormalized()
	var star:=MeshInstance3D.new();var sq:=QuadMesh.new();sq.size=Vector2.ONE*.15*size_value;star.mesh=sq
	var sm:=_mat("muzzle-%d"%rng.randi_range(0,2),true,BaseMaterial3D.BILLBOARD_DISABLED).duplicate() as StandardMaterial3D;sm.vertex_color_use_as_albedo=false;sm.albedo_color=color.lightened(.35);star.material_override=sm
	star.rotation.z=rng.randf()*TAU;star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(star)
	for k in range(2):
		var side:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2(.3,.12)*size_value;side.mesh=q
		var m2:=_mat("muzzle-side",true,BaseMaterial3D.BILLBOARD_DISABLED).duplicate() as StandardMaterial3D;m2.vertex_color_use_as_albedo=false;m2.albedo_color=color;side.material_override=m2
		side.rotation=Vector3(k*PI*.5,PI*.5,0);side.position=Vector3(0,0,-.14*size_value);side.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(side)
	_track(root,.05)
	burst(m.global_position,"smoke",Color(.7,.7,.72,.35),3,.8,.08,.16,.7,.4,-cam.global_basis.z,25.,false,_ramp([Color(1,1,1,.4),Color(1,1,1,0)]),_curve([0.,1.],[.5,2.]))
	burst(m.global_position,"glow",color,5,6.,.02,.04,.18,-4.,-cam.global_basis.z,30.)

func casing(at: Vector3, cam: Camera3D) -> void:
	var p:=burst(at,"glow",Color("ffcf5a"),1,2.6,.025,.03,.6,-14.,cam.global_basis.x+cam.global_basis.y*.8,20.)
	p.color_ramp=_ramp([Color("ffd86a"),Color("b8862a")])

func tracer(from: Vector3, to: Vector3, color: Color, width: float=1.) -> void:
	var length:=from.distance_to(to)
	if length<.3:return
	for layer in range(2):
		var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();var w:=(.02 if layer==0 else .006)*width;box.size=Vector3(w,w,length);mesh.mesh=box
		var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color=Color(color.r,color.g,color.b,.55) if layer==0 else Color(1,1,1,.95);mesh.material_override=m;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh);mesh.global_position=(from+to)*.5;mesh.look_at(to,Vector3.UP if absf((to-from).normalized().y)<.98 else Vector3.RIGHT)
		_track(mesh,.07,{"fade":m,"alpha":m.albedo_color.a})

func impact(at: Vector3, normal: Vector3, color: Color=Color("ffd8a0")) -> void:
	burst(at+normal*.03,"glow",color,10,5.,.02,.05,.3,-12.,normal,55.)
	if rng.randf()<.5:burst(at+normal*.05,"smoke",Color(.55,.5,.45,.5),3,1.,.15,.3,.9,.3,normal,40.,false,_ramp([Color(1,1,1,.45),Color(1,1,1,0)]),_curve([0.,1.],[.6,1.8]))
	if rng.randf()<.3:light(at+normal*.1,color,1.6,2.,.06)
	_decal("hole","hole",at,normal,rng.randf_range(.07,.11),Color.WHITE,MAX_HOLES,30.)

# ---------------------------------------------------------------- gore & party
func blood(at: Vector3, dir: Vector3, amount: float, head: bool) -> void:
	var red:=_ramp([Color(.75,0,.04,1),Color(.5,0,.02,1),Color(.3,0,.01,0)])
	burst(at,"glow",Color.WHITE,int(14*amount)+6,4.2*amount+1.5,.04,.1,.75,-11.,dir+Vector3.UP*.4,55.,false,red)
	burst(at,"smoke",Color(.6,0,.03,.6),int(3*amount)+2,1.2,.25,.5,.6,-1.,dir,60.,false,_ramp([Color(.7,0,.05,.55),Color(.4,0,.02,0)]),_curve([0.,1.],[.5,1.6]))
	if head:burst(at,"glow",Color.WHITE,18,6.,.05,.12,.9,-12.,Vector3.UP,70.,false,red)
	if rng.randf()<.55*amount:splat(at,dir,amount)

func gib(at: Vector3, amount: float) -> void:
	var p:=_emitter("glow",Color.WHITE,false,int(10*amount)+4,1.4);p.one_shot=true;p.explosiveness=1.
	var chunk:=BoxMesh.new();chunk.size=Vector3(.07,.05,.06);var m:=StandardMaterial3D.new();m.albedo_color=Color(.4,0,.03);m.roughness=.35;m.vertex_color_use_as_albedo=true;chunk.material=m;p.mesh=chunk
	p.global_position=at;p.direction=Vector3.UP;p.spread=80.;p.initial_velocity_min=3.;p.initial_velocity_max=7.;p.gravity=Vector3(0,-14,0)
	p.scale_amount_min=.6;p.scale_amount_max=1.8;p.angular_velocity_min=-400.;p.angular_velocity_max=400.;p.color_ramp=_ramp([Color(.6,.02,.05),Color(.35,0,.02)])
	p.emitting=true;_track(p,1.7)
	for i in range(int(2*amount)+1):splat(at+Vector3(rng.randf_range(-.8,.8),0,rng.randf_range(-.8,.8)),Vector3.ZERO,amount)
	sound("gore",at,-2.,1.,3)

func confetti(at: Vector3, amount: float) -> void:
	var p:=_emitter("glow",Color.WHITE,false,int(22*amount)+6,2.2);p.one_shot=true;p.explosiveness=.95
	var q:=QuadMesh.new();q.size=Vector2(.05,.03);var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.vertex_color_use_as_albedo=true;m.cull_mode=BaseMaterial3D.CULL_DISABLED;q.material=m;p.mesh=q
	p.global_position=at;p.direction=Vector3.UP;p.spread=70.;p.initial_velocity_min=2.5;p.initial_velocity_max=6.;p.gravity=Vector3(0,-3.2,0);p.damping_min=1.;p.damping_max=2.5
	p.angular_velocity_min=-500.;p.angular_velocity_max=500.;p.particle_flag_rotate_y=true;p.scale_amount_min=.8;p.scale_amount_max=1.5
	var cols:=Gradient.new();var offsets:=PackedFloat32Array();var list:=PackedColorArray()
	for i in range(CONFETTI.size()):offsets.append(float(i)/(CONFETTI.size()-1));list.append(CONFETTI[i])
	cols.offsets=offsets;cols.colors=list;cols.interpolation_mode=Gradient.GRADIENT_INTERPOLATE_CONSTANT;p.color_initial_ramp=cols
	p.emitting=true;_track(p,2.5)

# ---------------------------------------------------------------- big stuff
# Blasts right in front of the eyes must not blind the player.
func _near_fade(at: Vector3, radius: float) -> float:
	var cam:=get_viewport().get_camera_3d()
	if not cam:return 1.
	return clampf((at.distance_to(cam.global_position)-.8)/(radius*2.2),.12,1.)

func explosion(at: Vector3, radius: float, color: Color=Color("ff7a2a")) -> void:
	var size_value:=clampf(radius/4.,.5,2.5);var near:=_near_fade(at,radius)
	var fire:=_ramp([Color(1,1,.85,1),Color(1,.75,.3,1),color,Color(.35,.08,.02,.6),Color(.05,.02,.02,0)])
	burst(at,"flame",Color(1,1,1,near),int(26*size_value*near)+4,5.5*size_value,.8*size_value*near,1.6*size_value*near,.75,1.5,Vector3.UP,180.,true,fire,_curve([0.,.3,1.],[.4,1.,1.6]))
	burst(at,"glow",Color.WHITE,int(40*size_value),14.*size_value,.04,.1,.9,-9.,Vector3.UP,180.,true,_ramp([Color(1,1,.8,1),color,Color(color.r,color.g,color.b,0)]))
	if near>.35:burst(at+Vector3.UP*.3,"smoke",Color(.12,.1,.1,.85*near),int(14*size_value*near)+2,2.2*size_value,1.*size_value*near,1.8*size_value*near,2.8,1.4,Vector3.UP,80.,false,_ramp([Color(.25,.22,.2,0),Color(.18,.16,.15,.8),Color(.1,.1,.1,0)]),_curve([0.,1.],[.5,2.4]))
	var ring:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2.ONE*2.;q.orientation=PlaneMesh.FACE_Y;ring.mesh=q
	var rm:=_mat("ring",true,BaseMaterial3D.BILLBOARD_DISABLED).duplicate() as StandardMaterial3D;rm.vertex_color_use_as_albedo=false;rm.albedo_color=color.lightened(.3);ring.material_override=rm
	add_child(ring);ring.global_position=at+Vector3.UP*.15;_track(ring,.45,{"grow":radius*1.2,"fade":rm,"alpha":1.})
	var orb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;sphere.radial_segments=24;sphere.rings=12;orb.mesh=sphere
	var om:=StandardMaterial3D.new();om.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;om.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;om.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;om.albedo_color=Color(1,.85,.6,.8*near);om.cull_mode=BaseMaterial3D.CULL_DISABLED;orb.material_override=om
	add_child(orb);orb.global_position=at;_track(orb,.2,{"grow":radius*.45,"fade":om,"alpha":.7*near})
	light(at+Vector3.UP,color,9.*size_value,radius*3.,.5)
	var floor_hit:=_surface(at+Vector3.UP*.5,Vector3.DOWN,3.)
	if not floor_hit.is_empty():_decal("scorch","scorch",floor_hit.position,floor_hit.normal,radius*.9,Color.WHITE,MAX_SCORCH,45.)
	sound("explosion",at,2.,1.15-size_value*.12,3)
	var d:=at.distance_to(mode.player_position())
	shake_out=maxf(shake_out,clampf(1.2-d/(radius*4.),0.,.9))

func implosion(at: Vector3, radius: float, color: Color=Color("b05aff")) -> void:
	var p:=burst(at,"glow",color,40,0.,.05,.12,.6,0.,Vector3.UP,180.,true,_ramp([Color(color.r,color.g,color.b,0),color,Color(1,1,1,1)]))
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE;p.emission_sphere_radius=radius;p.radial_accel_min=-radius*9.;p.radial_accel_max=-radius*6.
	var orb:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;orb.mesh=sphere
	var om:=StandardMaterial3D.new();om.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;om.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;om.albedo_color=Color(.04,0,.08,.85);orb.material_override=om
	var near:=_near_fade(at,radius)
	add_child(orb);orb.global_position=at;orb.scale=Vector3.ONE*radius*.4;_track(orb,.45,{"shrink":radius*.4,"fade":om,"alpha":.6*near})
	light(at,color,6.,radius*2.5,.5)
	sound("zap",at,-4.,.55,3)

# Jagged bolt with forks; regenerated a few times while it lives.
func lightning(a: Vector3, b: Vector3, color: Color=Color("7af6ff"), thickness: float=1., life: float=.22) -> void:
	var mesh:=MeshInstance3D.new();var im:=ImmediateMesh.new();mesh.mesh=im;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;m.vertex_color_use_as_albedo=true;m.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=m
	add_child(mesh);mesh.global_position=Vector3.ZERO
	var entry:={"a":a,"b":b,"color":color,"thick":thickness,"mesh":im,"next":0.}
	_draw_bolt(entry)
	_track(mesh,life,{"bolt":entry,"fade":m,"alpha":1.})
	light(b,color,4.,4.,life)
	light(a.lerp(b,.5),color,2.5,5.,life)
	burst(b,"glow",color,10,5.,.03,.06,.3,-6.)

func _bolt_points(a: Vector3, b: Vector3, depth: int) -> PackedVector3Array:
	var pts:=PackedVector3Array([a,b]);var jitter:=a.distance_to(b)*.18
	for level in range(depth):
		var next:=PackedVector3Array()
		for i in range(pts.size()-1):
			next.append(pts[i]);next.append((pts[i]+pts[i+1])*.5+Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))*jitter)
		next.append(pts[pts.size()-1]);pts=next;jitter*=.5
	return pts

func _draw_bolt(entry: Dictionary) -> void:
	var im: ImmediateMesh=entry.mesh;im.clear_surfaces()
	var cam:=get_viewport().get_camera_3d()
	var eye:=cam.global_position if cam else Vector3.ZERO
	var strands: Array=[[_bolt_points(entry.a,entry.b,5),1.]]
	for f in range(2):
		var main: PackedVector3Array=strands[0][0];var from: Vector3=main[rng.randi_range(2,main.size()-3)]
		var to: Vector3=from+(entry.b-entry.a).normalized().rotated(Vector3.UP,rng.randf_range(-1.2,1.2))*rng.randf_range(.6,1.6)+Vector3(0,rng.randf_range(-.6,.3),0)
		strands.append([_bolt_points(from,to,3),.5])
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in strands:
		var pts: PackedVector3Array=strand[0]
		for layer in range(2):
			var width: float=(.09 if layer==0 else .025)*float(entry.thick)*float(strand[1])
			var col: Color=Color(entry.color.r,entry.color.g,entry.color.b,.5) if layer==0 else Color(1,1,1,1)
			for i in range(pts.size()-1):
				var p0:=pts[i];var p1:=pts[i+1];var view:=(eye-(p0+p1)*.5).normalized();var side:=(p1-p0).cross(view).normalized()*width
				for v in [p0-side,p0+side,p1+side,p0-side,p1+side,p1-side]:im.surface_set_color(col);im.surface_add_vertex(v)
	im.surface_end()

func chain_sound(at: Vector3) -> void:
	sound("zap",at,-3.,1.,3)

# ---------------------------------------------------------------- fire
func set_burning(e: Node3D, on: bool) -> void:
	var id:=e.get_instance_id()
	if on and not burning.has(id):
		var p:=CPUParticles3D.new();p.amount=24;p.lifetime=.7;p.local_coords=false
		var q:=QuadMesh.new();q.size=Vector2.ONE;q.material=_mat("flame",true);p.mesh=q
		p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(.25,.7,.25);p.position=Vector3(0,.9,0)
		p.direction=Vector3.UP;p.spread=15.;p.initial_velocity_min=.8;p.initial_velocity_max=2.;p.gravity=Vector3(0,2.,0)
		p.scale_amount_min=.25;p.scale_amount_max=.5;p.scale_amount_curve=_curve([0.,.3,1.],[.4,1.,.2]);p.angle_min=-180.;p.angle_max=180.
		p.color_ramp=_ramp([Color(1,.9,.6,1),Color(1,.5,.1,.9),Color(.6,.1,.02,0)]);p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.add_child(p);p.emitting=true
		var l:=OmniLight3D.new();l.light_volumetric_fog_energy=0.;l.light_color=Color("ff7a2a");l.light_energy=1.8;l.omni_range=3.;l.shadow_enabled=false;l.position=Vector3(0,1.,0);e.add_child(l)
		burning[id]={"p":p,"l":l}
	elif not on and burning.has(id):
		var b: Dictionary=burning[id];burning.erase(id)
		if is_instance_valid(b.p):(b.p as CPUParticles3D).emitting=false;(b.p as Node).get_tree().create_timer(.8).timeout.connect((b.p as Node).queue_free)
		if is_instance_valid(b.l):(b.l as Node).queue_free()

# Called every frame by the arsenal while a flamethrower is held.
func flame(from: Vector3, dir: Vector3, firing: bool) -> void:
	flame_on=.09 if firing else flame_on
	flame_emitter.global_position=from;flame_emitter.direction=dir;flame_core.global_position=from;flame_core.direction=dir
	flame_light.global_position=from+dir*2.

# ---------------------------------------------------------------- numbers
func number(at: Vector3, value: float, color: Color, big: bool) -> void:
	var label:=Label3D.new();label.text="%d"%int(round(value));label.font=load("res://assets/Oswald.ttf");label.font_size=56 if big else 40;label.pixel_size=.0006;label.outline_size=12
	label.modulate=color;label.outline_modulate=Color(0,0,0,.85);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.fixed_size=true;label.render_priority=5
	add_child(label);label.global_position=at+Vector3(rng.randf_range(-.25,.25),rng.randf_range(0,.2),rng.randf_range(-.25,.25))
	numbers.append(label)
	while numbers.size()>MAX_NUMBERS:
		var old: Node=numbers.pop_front()
		if is_instance_valid(old):old.queue_free()
	_track(label,.8,{"rise":1.1,"label":true})

# ---------------------------------------------------------------- update
func tick(delta: float) -> void:
	flame_on=maxf(flame_on-delta,0.)
	var flaming:=flame_on>0.
	flame_emitter.emitting=flaming;flame_core.emitting=flaming
	flame_light.light_energy=lerpf(flame_light.light_energy,(3.5+sin(Time.get_ticks_msec()*.05)*1.2) if flaming else 0.,clampf(delta*20.,0,1))
	if flaming and flame_audio.stream and not flame_audio.playing:flame_audio.play()
	elif not flaming and flame_audio.playing:flame_audio.stop()
	for fx in live.duplicate():
		if not is_instance_valid(fx.node):live.erase(fx);continue
		var node: Node3D=fx.node
		fx.life=float(fx.life)-delta;var k:=clampf(1.-float(fx.life)/float(fx.total),0.,1.)
		if fx.has("light"):(node as OmniLight3D).light_energy=float(fx.light)*(1.-k)*(1.-k)
		if fx.has("grow"):node.scale=Vector3.ONE*lerpf(.15,float(fx.grow),1.-pow(1.-k,3.))
		if fx.has("shrink"):node.scale=Vector3.ONE*lerpf(float(fx.shrink),.01,k*k)
		if fx.has("fade"):var m: StandardMaterial3D=fx.fade;var c:=m.albedo_color;c.a=float(fx.alpha)*(1.-k);m.albedo_color=c
		if fx.has("rise"):node.position.y+=delta*float(fx.rise)*(1.-k);(node as Label3D).modulate.a=1.-k*k;(node as Label3D).outline_modulate.a=(1.-k*k)*.85
		if fx.has("bolt"):
			var b: Dictionary=fx.bolt;b.next=float(b.next)-delta
			if float(b.next)<=0.:b.next=.05;_draw_bolt(b)
		if float(fx.life)<=0.:node.queue_free();live.erase(fx)
	for kind in decals:
		for d in (decals[kind] as Array).duplicate():
			if not is_instance_valid(d.node):(decals[kind] as Array).erase(d);continue
			d.age=float(d.age)+delta
			if float(d.age)>float(d.fade):
				var dn: Decal=d.node;var a:=1.-clampf((float(d.age)-float(d.fade))/6.,0.,1.);dn.modulate.a=a
				if a<=0.:dn.queue_free();(decals[kind] as Array).erase(d)

func clear() -> void:
	for kind in decals:
		for d in decals[kind]:
			if is_instance_valid(d.node):(d.node as Node).queue_free()
		(decals[kind] as Array).clear()
	for fx in live:
		if is_instance_valid(fx.node):(fx.node as Node).queue_free()
	live.clear();burning.clear();flame_on=0.;flame_audio.stop()
