class_name GuardTorch
extends Node3D

const BASE_ENERGY:=4.9
const REST:=Vector3(.23,-.245,-.39)
var lamp: SpotLight3D
var clock:=0.0
var wait:=26.0
var burst:=-1.0
var strength:=1.0
var count:=0
var rng:=RandomNumberGenerator.new()
var emitter: StandardMaterial3D
var spill: OmniLight3D
var body: Node3D
var lens: MeshInstance3D
var near_wall:=0.0
var sway:=Vector2.ZERO
var sway_target:=Vector2.ZERO
var landing:=0.0
var landing_speed:=0.0
var walk_phase:=0.0

func surface(color: Color,metal: float,rough: float) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=rough
 m.normal_enabled=true;m.normal_texture=load("res://assets/detail-v310/clown-normal.jpg");m.normal_scale=.025;m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*34
 return m

func lathe(parent: Node3D,title: String,profile: Array[Vector2],material: Material,grooves: float=0.) -> MeshInstance3D:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(profile.size()-1):
  for side in range(64):
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
    var ring: Vector2=profile[row+corner.y];var angle: float=(side+corner.x)*TAU/64.
    var r:=ring.y*(1.+grooves*pow(absf(sin(angle*16.)),6.))
    st.set_uv(Vector2(float(side+corner.x)/64.,ring.x*9.));st.add_vertex(Vector3(cos(angle)*r,sin(angle)*r,ring.x))
 st.generate_normals();st.generate_tangents();st.index()
 var mesh:=MeshInstance3D.new();mesh.name=title;mesh.mesh=st.commit();mesh.material_override=material;parent.add_child(mesh);return mesh

func box(parent: Node3D,title: String,p: Vector3,s: Vector3,m: Material) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.name=title;var shape:=BoxMesh.new();shape.size=s;mesh.mesh=shape;mesh.position=p;mesh.material_override=m;parent.add_child(mesh);return mesh

func build(light: SpotLight3D) -> void:
 lamp=light;rng.randomize();wait=rng.randf_range(20,42)
 position=REST;rotation=Vector3(-.035,-.09,-.08)
 spill=OmniLight3D.new();spill.name="TorchNearSpill";spill.light_color=light.light_color;spill.omni_range=2.8;spill.omni_attenuation=2.;spill.position=Vector3(0,.12,.10);spill.light_cull_mask=1;add_child(spill)
 lamp.light_cull_mask=1;spill.light_volumetric_fog_energy=0.;spill.light_specular=0.
 body=Node3D.new();body.name="MachinedNightwatchTorch";add_child(body)
 var metal:=surface(Color("424c48"),.83,.36);var edge:=surface(Color("929b90"),.9,.31)
 var rubber:=surface(Color("1d2520"),.03,.93);var brass:=surface(Color("ac9970"),.65,.44)
 lathe(body,"AnodisedAluminiumBody",[Vector2(.17,0),Vector2(.17,.027),Vector2(.155,.031),Vector2(-.13,.031),Vector2(-.16,.045),Vector2(-.215,.063),Vector2(-.252,.064),Vector2(-.258,.059)],metal)
 lathe(body,"MachinedGrip",[Vector2(.12,.032),Vector2(.117,.035),Vector2(-.104,.035),Vector2(-.11,.032)],rubber,.065)
 for z in [-.12,-.137,-.153,-.171,-.188]:
  lathe(body,"HeatSinkRing",[Vector2(z+.002,.041),Vector2(z,.052 if z>-.16 else .060),Vector2(z-.006,.052 if z>-.16 else .060),Vector2(z-.008,.043)],metal)
 lathe(body,"WornBezel",[Vector2(-.246,.064),Vector2(-.258,.066),Vector2(-.269,.064),Vector2(-.27,.057),Vector2(-.255,.055)],edge,.012)
 var reflector:=surface(Color("c1c6bd"),.96,.19)
 lathe(body,"PolishedReflector",[Vector2(-.265,.056),Vector2(-.257,.052),Vector2(-.242,.046),Vector2(-.228,.032),Vector2(-.22,.014)],reflector)
 var led:=surface(Color("d7d0a8"),.1,.36);led.emission_enabled=true;led.emission=Color("fff0ca");led.emission_energy_multiplier=.6;emitter=led
 var diode:=MeshInstance3D.new();diode.name="Emitter";var disc:=CylinderMesh.new();disc.top_radius=.009;disc.bottom_radius=.009;disc.height=.002;disc.radial_segments=32;diode.mesh=disc;diode.rotation.x=PI/2;diode.position.z=-.222;diode.material_override=led;body.add_child(diode)
 var glass:=surface(Color(.67,.79,.73,.12),.0,.13);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.clearcoat_enabled=true;glass.clearcoat=.8
 lens=MeshInstance3D.new();lens.name="RecessedProtectiveGlass";var pane:=CylinderMesh.new();pane.top_radius=.056;pane.bottom_radius=.056;pane.height=.0008;pane.radial_segments=64;lens.mesh=pane;lens.material_override=glass;lens.position.z=-.265;lens.rotation.x=PI/2;body.add_child(lens)
 for z in [.13,.145]:lathe(body,"TailcapGrip",[Vector2(z,.031),Vector2(z-.003,.036),Vector2(z-.009,.036),Vector2(z-.011,.032)],edge)
 box(body,"SwitchGuard",Vector3(0,.035,-.096),Vector3(.025,.009,.038),metal)
 box(body,"RubberThumbSwitch",Vector3(0,.042,-.096),Vector3(.018,.005,.026),rubber)
 for side in [-1,1]:
  var screw:=MeshInstance3D.new();screw.name="BezelFastener";var ball:=SphereMesh.new();ball.radius=.0025;ball.height=.005;ball.radial_segments=12;ball.rings=6;screw.mesh=ball;screw.position=Vector3(side*.061,0,-.25);screw.material_override=brass;body.add_child(screw)
 box(body,"PocketClip",Vector3(-.033,.012,.057),Vector3(.005,.012,.14),edge)
 var hand: Node3D=(load("res://assets/revamp-v300/anatomical-grip-v300.glb") as PackedScene).instantiate();hand.name="GuardGrip";hand.position=Vector3(.046,-.025,.04);hand.quaternion=Quaternion(Vector3.UP,-PI/2)*Quaternion(Vector3.BACK,PI);add_child(hand);CharacterFinish.hand(hand)
 var cuff: Node3D=(load("res://assets/props/clown-sleeve.glb") as PackedScene).instantiate();cuff.name="WornGuardCuff";cuff.position=Vector3(0,.16,0);cuff.scale=Vector3(.45,.21,.45);hand.add_child(cuff)
 var fabric:=surface(Color("293d34"),0.,.97);fabric.albedo_texture=load("res://assets/pbr/fabric_pattern_07/albedo.jpg");fabric.uv1_scale=Vector3.ONE*8
 for mesh in cuff.find_children("*","MeshInstance3D",true,false):mesh.material_override=fabric
 for mesh in find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=2

func look(relative: Vector2) -> void:
 sway_target=(sway_target+relative*.00045).clamp(Vector2(-.055,-.045),Vector2(.055,.045))

func land(speed: float) -> void:
 landing_speed=-clampf(absf(speed)*.024,.035,.23)

func trigger() -> void:
 if burst>=0:return
 burst=0;count+=1

func tick(delta: float,on: bool,fright: float,guard=null) -> void:
 if on:
  clock+=delta;wait-=delta
  if wait<=0:trigger();wait=rng.randf_range(24,48)
  if burst>=0:
   burst+=delta;strength=.12 if (burst<.065 or (burst>.14 and burst<.2) or (burst>.31 and burst<.35)) else .72 if burst<.45 else 1.
   if burst>.58:burst=-1;strength=1
 else:strength=1
 lamp.light_energy=BASE_ENERGY*strength;lamp.spot_angle=26+fright*30
 spill.visible=on;spill.light_energy=.145*strength
 if emitter:emitter.emission_energy_multiplier=.65*strength if on else 0.
 if not guard:return
 var from: Vector3=guard.camera.global_position
 var query:=PhysicsRayQueryParameters3D.create(from,from-guard.camera.global_basis.z*.95,1);query.exclude=[guard.get_rid()]
 var hit: Dictionary=guard.get_world_3d().direct_space_state.intersect_ray(query)
 var target:=clampf((.82-from.distance_to(hit.position))/.6,0.,1.) if hit else 0.
 near_wall=lerpf(near_wall,target,1.-exp(-delta*13.))
 var moving: float=Vector2(guard.velocity.x,guard.velocity.z).length()
 walk_phase+=delta*(10.5 if moving>3. else 6.5)
 var motion_enabled: bool=guard.motion
 sway_target=sway_target.lerp(Vector2.ZERO,1.-exp(-delta*8.));sway=sway.lerp(sway_target,1.-exp(-delta*14.))
 var remaining:=minf(delta,.1)
 while remaining>0:
  var dt:=minf(remaining,.008);landing_speed+=(-landing*150.-landing_speed*18.)*dt;landing+=landing_speed*dt;remaining-=dt
 var bob:=Vector3(sin(walk_phase)*.007,cos(walk_phase*2.)*.006,cos(walk_phase)*.004)*clampf(moving/2.8,0.,1.6) if motion_enabled else Vector3.ZERO
 position=REST+bob+Vector3(-sway.x,sway.y+landing if motion_enabled else 0.,near_wall*.24)
 rotation=Vector3(-.035+near_wall*.32+(sway.y*2. if motion_enabled else 0.),-.09+(sway.x*2. if motion_enabled else 0.),-.08+(sin(walk_phase)*.018*minf(moving/3.,1.5) if motion_enabled else 0.))

func reset_motion() -> void:
 sway=Vector2.ZERO;sway_target=Vector2.ZERO;landing=0.;landing_speed=0.;near_wall=0.;position=REST;rotation=Vector3(-.035,-.09,-.08)
