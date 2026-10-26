class_name NurseryAtmosphere
extends Node3D

var w: PlayWorld
var loose: Array[NightProp]=[]
var horrors := {}
var mist: ShaderMaterial
var cloth: ShaderMaterial
var dust: MultiMeshInstance3D
var elapsed := 0.0
var simulation := false
var drips: AudioStreamPlayer3D
var micro_normal: NoiseTexture2D

func build(world: PlayWorld) -> void:
 w=world
 _materials();_weathering();_softplay_details();_reception_details()
 _party_details();_plush_corner();_physical_toys();_mist_and_dust();_horror_variants()
 drips=AudioStreamPlayer3D.new();var stream: AudioStreamWAV=load("res://assets/drips.wav").duplicate()
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate)
 drips.stream=stream;drips.position=Vector3(-8.5,2,-8);drips.volume_db=-17;drips.unit_size=3;drips.max_distance=17;add_child(drips)

func _materials() -> void:
 var noise:=FastNoiseLite.new();noise.seed=711;noise.frequency=.13;noise.fractal_octaves=3
 micro_normal=NoiseTexture2D.new();micro_normal.width=256;micro_normal.height=256;micro_normal.noise=noise;micro_normal.seamless=true;micro_normal.as_normal_map=true;micro_normal.bump_strength=1.8
 for id in ["blue","red","gold","teal","cream","wood","wall"]:
  var material: StandardMaterial3D=w.materials[id]
  material.normal_enabled=true;material.normal_texture=micro_normal;material.normal_scale=.45 if id=="wall" else .28
 w.materials.wall.albedo_texture=load("res://assets/aged-plaster.png");w.materials.wall.albedo_color=Color("bdc1a9")
 w.materials.wall.uv1_scale=Vector3.ONE*.34
 w.materials.fabric=w.mat(Color("857564"),load("res://assets/floor.png"),.98)
 w.materials.fabric.normal_enabled=true;w.materials.fabric.normal_texture=micro_normal;w.materials.fabric.normal_scale=1.15
 w.materials.stitch=w.mat(Color("39342b"),null,.98)
 w.materials.rust=w.mat(Color("705244"),load("res://assets/wood.png"),.8,.45)
 w.materials.paper=w.mat(Color("c0b699"),load("res://assets/aged-plaster.png"),.94)
 w.materials.blood=w.mat(Color("430b0c"),null,.19)

func decal(parent: Node3D, cell: int, pos: Vector3, size: Vector2, rotation_value: Vector3=Vector3.ZERO, tint: Color=Color.WHITE) -> MeshInstance3D:
 # AtlasTexture regions aren't honored by StandardMaterial3D. Remap real mesh UVs.
 var material:=w.mat(tint,load("res://assets/horror-decals.png"),.86);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 if cell!=2: material.albedo_color*=Color(.55,.32,.30,1)
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size
 var arrays:=quad.surface_get_arrays(0);var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var offset:=Vector2(cell%2,floori(cell/2.0))*.5
 for i in range(uvs.size()): uvs[i]=offset+Vector2(.004,.004)+uvs[i]*.492
 arrays[Mesh.ARRAY_TEX_UV]=uvs;var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.mesh=geometry;mesh.material_override=material
 mesh.position=pos;mesh.rotation=rotation_value;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);return mesh

func _weathering() -> void:
 for side in [-1,1]:
  for i in range(7):
   if side<0 and i in [0,1,2,6]: continue # Archive and delivery openings cannot carry wall decals.
   if side>0 and absf(-10+i*3.15-7.8)<1.95: continue # WC opening.
   decal(self,2,Vector3(-10.025 if side<0 else 19.625,1.35,-10+i*3.15),Vector2(2.1,2.7),Vector3(0,-side*PI/2,0),Color(.7,.74,.64,.6))
 # Weathering belongs to the solid piers, never across the service/decision
 # openings. These overlays remain visible even though they have no collider.
 for patch in [Vector2(-5.78,.82),Vector2(.2,2.1),Vector2(3.7,2.1)]:
  decal(self,2,Vector3(patch.x,1.6,-12.035),Vector2(patch.y,3.2),Vector3.ZERO,Color(.65,.7,.65,.5))
 # A fixed, dried mark belongs to the reference round. New wet marks are anomalies.
 decal(self,0,Vector3(-9.97,1.08,-8.25),Vector2(.9,.55),Vector3(0,PI/2,-.35),Color(.32,.24,.23,.7))
 for i in range(18):
  var x:=-8.7+fmod(i*3.73,18.1);var z:=-10.2+fmod(i*5.47,20)
  decal(self,2,Vector3(x,.027,z),Vector2(1.3+(i%3)*.5,.85),Vector3(-PI/2,i*.73,0),Color(.37,.39,.32,.28))
 # Wet irregular pools catch practical lights; no expensive screen-space reflection.
 var wet:=w.mat(Color(.12,.18,.17,.36),load("res://assets/floor.png"),.08,.28)
 wet.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 for i in range(7):
  var pool:=w.sphere(self,Vector3(-5.2+sin(i*2.2)*2.1,.026,-9+i*2.8),.8,wet);pool.scale=Vector3(1.4,.006,.65);pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # Rust collars, cable trays, hanging chains and damaged strips of ceiling fabric.
 for z in [-9,-5,-1,3,7]:
  w.tube(self,Vector3(-7.01,6.72,z),Vector3(-7.01,6.72,z+.11),.244,w.materials.rust)
  for x in [-7.3,-6.7]: w.box(self,Vector3(x,6.72,z+.05),Vector3(.08,.08,.08),w.materials.metal)
 # Creased discarded paper and cups are scattered on the actual floor.
 for i in range(12):
  var sheet:=w.box(self,Vector3(-8+fmod(i*2.7,13),.017,-9+fmod(i*3.9,18)),Vector3(.24,.008,.32),w.materials.paper);sheet.rotation.y=i*.7
  var fold:=w.box(sheet,Vector3(.075,.025,0),Vector3(.09,.008,.31),w.materials.paper);fold.rotation.z=-.45

func _softplay_details() -> void:
 var details:=Node3D.new();w.props.structure.add_child(details);details.position.x=.6
 # Fittings stay on the posts; play obstacles remain inside the net envelope.
 for z in [-5.5,-2.4,.7,3.8]:
  for x in [-.9,2,4.9]:
   for y in [.38,2.25,4.42]:
    w.tube(details,Vector3(x,y-.055,z),Vector3(x,y+.055,z),.151,w.materials.rust)
    for a in range(4):
     var angle:=a*PI/2
     w.sphere(details,Vector3(x+cos(angle)*.154,y,z+sin(angle)*.154),.018,w.materials.metal)
 # Suspended padded obstacles inside the climbing frame, with leather straps.
 for i in range(5):
  var x:=.15+i*.45;var z:=-2.0 if i%2 else -.3
  w.tube(details,Vector3(x,2.15,z),Vector3(x,1.82,z),.013,w.materials.stitch)
  var roller:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=.18;capsule.height=1.25;capsule.radial_segments=16;capsule.rings=8;roller.mesh=capsule;roller.material_override=[w.materials.red,w.materials.gold,w.materials.teal][i%3];roller.position=Vector3(x,1.18,z);roller.rotation.z=(i-2)*.045;details.add_child(roller);roller.set_meta("play_obstacle",true)
  var roller_shape:=CapsuleShape3D.new();roller_shape.radius=.18;roller_shape.height=1.25;PlayGeometry.solid_obstacle(roller,roller_shape)
  w.tube(details,Vector3(x,1.73,z),Vector3(x,1.76,z),.186,w.materials.stitch)
 # Padded wall panels have seams, straps and individual sagging surfaces.
 for i in range(5):
  if absf(3+i*1.35-7.8)<1.55: continue
  var pad:=w.box(self,Vector3(19.59,.65,3+i*1.35),Vector3(.1,1.2,1.24),[w.materials.blue,w.materials.gold,w.materials.red][i%3])
  w.tube(pad,Vector3(-.061,-.47,-.5),Vector3(-.061,.47,-.5),.009,w.materials.stitch)
  w.tube(pad,Vector3(-.061,-.47,.5),Vector3(-.061,.47,.5),.009,w.materials.stitch)

func _reception_details() -> void:
 var counter: Node3D=w.props.counter
 # Desk-sized phone and lamp; all objects use metre dimensions.
 w.tube(counter,Vector3(-.1,1,.99),Vector3(-.1,1.04,.99),.1,w.materials.dark)
 w.tube(counter,Vector3(-.1,1.04,.99),Vector3(-.1,1.39,.99),.015,w.materials.metal)
 w.tube(counter,Vector3(-.1,1.39,.99),Vector3(.1,1.5,.99),.015,w.materials.metal)
 var shade:=w.sphere(counter,Vector3(.12,1.47,.99),.1,w.materials.dark);shade.scale=Vector3(1,.55,1)
 w.lamp(Vector3(-8.73,1.39,6.79),Color("ffd696"),.5,3.2)
 var phone:=w.box(counter,Vector3(-.05,1.05,-1),Vector3(.24,.1,.28),w.materials.dark);phone.rotation.x=-.16
 w.tube(phone,Vector3(-.09,.08,-.08),Vector3(.09,.08,-.08),.032,w.materials.dark)
 for i in range(18): w.sphere(counter,Vector3(-.23+sin(i*.8)*.016,1.01,-1.13+i*.012),.008,w.materials.dark)
 # A broken corkboard with drawings, pushpins and curled corners.
 w.box(self,Vector3(-10.0,2.25,5.5),Vector3(.04,1.35,1.9),w.materials.wood)
 for i in range(5):
  var z:=4.82+(i%3)*.52;var y:=2.1+floori(i/3.0)*.55
  var page:=w.box(self,Vector3(-9.96,y,z),Vector3(.012,.5,.4),w.materials.paper);page.rotation.x=(i-2)*.08
  w.sphere(self,Vector3(-9.94,y+.21,z),.022,w.materials.red)
  for line in range(4): w.tube(self,Vector3(-9.94,y-.15+line*.09,z-.12),Vector3(-9.94,y-.1+line*.09,z+.13),.006,[w.materials.red,w.materials.blue,w.materials.gold][line%3])
 # Large original mural inset in reception, plus bent cable runs.
 var mural:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.8,.6);mural.mesh=quad;mural.material_override=w.mat(Color("929477"),load("res://assets/mural.png"),.95);mural.position=Vector3(-8.426,.49,5.8);mural.rotation.y=PI/2;add_child(mural)
 for y in [.34,.38]:
  for span in [Vector2(-7,-6.42),Vector2(-4.38,3)]: w.tube(self,Vector3(-9.97,y,span.x),Vector3(-9.97,y,span.y),.014,w.materials.dark)
 # An abandoned rocking horse gives the long wall a recognizable, organic prop.
 var horse:=Node3D.new();horse.position=Vector3(-8.95,0,-1.8);horse.rotation.y=-.7;add_child(horse);horrors.horse=horse
 var torso:=w.sphere(horse,Vector3(0,.65,0),.32,w.materials.wood);torso.scale=Vector3(.65,.8,1.4)
 var neck:=w.sphere(horse,Vector3(0,.95,-.3),.21,w.materials.wood);neck.scale=Vector3(.75,1.6,.8);neck.rotation.x=-.35
 var head:=w.sphere(horse,Vector3(0,1.2,-.43),.22,w.materials.wood);head.scale=Vector3(.75,.9,1.25)
 for side in [-1,1]:
  var ear:=w.sphere(horse,Vector3(side*.1,1.41,-.34),.08,w.materials.wood);ear.scale=Vector3(.5,1.7,.7)
  w.sphere(horse,Vector3(side*.157,1.25,-.45),.022,w.materials.dark)
  for z in [-.27,.27]: w.tube(horse,Vector3(side*.15,.63,z),Vector3(side*.24,.2,z),.065,w.materials.wood)
  for i in range(15):
   var t:=i/15.0;var nt:=(i+1)/15.0
   w.tube(horse,Vector3(side*.25,.08+pow(t-.5,2)*.7,-.75+t*1.5),Vector3(side*.25,.08+pow(nt-.5,2)*.7,-.75+nt*1.5),.045,w.materials.rust)
 w.tube(horse,Vector3(-.3,1.02,-.33),Vector3(.3,1.02,-.33),.027,w.materials.dark)
 for i in range(8): w.tube(horse,Vector3(0,1.36-i*.06,-.28+i*.018),Vector3(0,1.34-i*.06,-.16+i*.018),.025,w.materials.stitch)
 var cushion:=w.sphere(horse,Vector3(0,.88,.08),.2,w.materials.red);cushion.scale=Vector3(.8,.17,1.2)
 w.box(self,Vector3(-8.95,.55,-1.8),Vector3(.85,1.1,1.5),w.materials.dark,true).hide()

func _party_details() -> void:
 var ceramic:=w.mat(Color("c2bba4"),load("res://assets/paint.png"),.36)
 # Round layered cake replaces the rectangular placeholder.
 for i in range(3): w.tube(w.props.party_table,Vector3(8.5,.85+i*.07,-7),Vector3(8.5,.92+i*.07,-7),.32-i*.008,w.materials.cream if i%2==0 else w.materials.red)
 var legacy:=Node3D.new();legacy.name="LegacyPartyTableware";w.props.party_table.add_child(legacy)
 for i in range(6):
  var z:=-8.1+(i%3)*1.1;var x:=7.9 if i<3 else 9.1
  w.tube(legacy,Vector3(x,.85,z),Vector3(x,.865,z),.19,ceramic)
  w.tube(legacy,Vector3(x+.12,.86,z+.22),Vector3(x+.12,1.02,z+.22),.058,ceramic)
  w.tube(legacy,Vector3(x+.12,1.02,z+.22),Vector3(x+.12,1.025,z+.22),.048,w.materials.dark)
  w.box(legacy,Vector3(x-.17,.88,z),Vector3(.025,.018,.22),w.materials.metal)
 for i in range(4):
  var strip:=w.box(legacy,Vector3(8.1+i*.38,.873,-7.2),Vector3(.18,.007,.2),w.materials.paper);strip.rotation.y=i*.6

func plush(parent: Node3D, pos: Vector3, scale_value: float=1.0) -> Node3D:
 var bunny:=Node3D.new();bunny.position=pos;bunny.scale=Vector3.ONE*scale_value;parent.add_child(bunny)
 var fabric: Material=w.materials.fabric
 var belly:=w.sphere(bunny,Vector3(0,.22,0),.29,fabric);belly.scale=Vector3(1,1.15,.8)
 var head:=w.sphere(bunny,Vector3(0,.62,.025),.235,fabric);head.scale=Vector3(1,.95,.88)
 for side in [-1,1]:
  var ear:=w.sphere(bunny,Vector3(side*.15,.94,-.015),.13,fabric);ear.scale=Vector3(.55,2.2,.42);ear.rotation.z=-side*.25
  var inner:=w.sphere(bunny,Vector3(side*.15,.94,.04),.095,w.materials.red);inner.scale=Vector3(.4,2.1,.2);inner.rotation.z=-side*.25
  var paw:=w.sphere(bunny,Vector3(side*.24,.25,.06),.13,fabric);paw.scale=Vector3(.7,1.4,.85);paw.rotation.z=side*.3
  var foot:=w.sphere(bunny,Vector3(side*.17,.015,.2),.14,fabric);foot.scale=Vector3(1,.65,1.5)
  w.sphere(bunny,Vector3(side*.078,.65,.207),.028,w.materials.dark)
  w.tube(bunny,Vector3(side*.07,.64,.232),Vector3(side*.087,.662,.232),.004,w.materials.cream)
 var muzzle:=w.sphere(bunny,Vector3(0,.55,.19),.08,w.materials.cream);muzzle.scale=Vector3(1.25,.7,.5)
 w.sphere(bunny,Vector3(0,.59,.235),.025,w.materials.stitch)
 for i in range(7): w.tube(bunny,Vector3(-.027,.1+i*.046,.229),Vector3(.027,.12+i*.046,.229),.004,w.materials.stitch)
 return bunny

func _plush_corner() -> void:
 var bench:=Node3D.new();bench.position=Vector3(-3.1,0,5.3);bench.rotation.y=PI/2;add_child(bench)
 horrors.bench=bench
 for i in range(4): w.box(bench,Vector3(0,.52,-.24+i*.16),Vector3(3,.07,.13),w.materials.wood,true)
 for side in [-1,1]:
  w.tube(bench,Vector3(side*1.2,.05,-.22),Vector3(side*1.2,.55,-.22),.045,w.materials.rust)
  w.tube(bench,Vector3(side*1.2,.05,.25),Vector3(side*1.2,1.1,.25),.045,w.materials.rust)
 for y in [.8,1.05]: w.box(bench,Vector3(0,y,.26),Vector3(3,.12,.065),w.materials.wood)
 var bunny:=plush(self,Vector3(-3.35,.62,4.85),1.08);bunny.rotation.y=-PI/2;horrors.bunny=bunny
 # Dried plant with curled individual leaves.
 w.tube(self,Vector3(-9.3,.05,15.3),Vector3(-9.3,.5,15.3),.27,w.materials.rust)
 for i in range(13):
  var a:=i*2.4;var start:=Vector3(-9.3,.45,15.3);var end:=start+Vector3(sin(a)*.48,.5+(i%4)*.12,cos(a)*.48)
  w.tube(self,start,end,.008,w.materials.wood)
  var leaf:=w.sphere(self,end,.12,w.materials.fabric);leaf.scale=Vector3(.35,1.7,.12);leaf.rotation.z=sin(a)*.8

func prop(pos: Vector3, size: Vector3, material: Material, title: String, mass: float, round_shape: bool=false) -> NightProp:
 var body:=NightProp.new();body.position=pos;body.title=title;body.mass=mass
 var physics_material:=PhysicsMaterial.new();physics_material.friction=.65;physics_material.bounce=.45 if round_shape else .12;body.physics_material_override=physics_material
 var collider:=CollisionShape3D.new()
 if round_shape:
  var shape:=SphereShape3D.new();shape.radius=size.x*.5;collider.shape=shape
  w.sphere(body,Vector3.ZERO,size.x*.5,material)
 else:
  var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;w.box(body,Vector3.ZERO,size,material)
 body.add_child(collider);add_child(body);loose.append(body);body.suspend(true);return body

func _physical_toys() -> void:
 for i in range(18):
  # Loose physics balls stay outside the decorative packed pit instead of
  # falling through its non-physical spheres and flickering inside them.
  var x:=-2.2+(i%6)*1.15;var z:=9.25+floori(i/6.0)*.55
  prop(Vector3(x,.16,z),Vector3.ONE*.29,[w.materials.red,w.materials.blue,w.materials.gold,w.materials.teal][i%4],"Spielball",.16,true)
 for i in range(8):
  var block:=prop(Vector3(-3.9+(i%3)*.37,.18+floori(i/3.0)*.32,8.1),Vector3.ONE*.3,w.materials.wood,"Holzbaustein",.45)
  w.text(block,["A","B","C","★"][i%4],Vector3(0,0,.166),.18,[Color("85392f"),Color("355d66")][i%2])
 # Hollow-looking bucket built as a cup with a separate floor, stable cylinder collider.
 var bucket:=NightProp.new();bucket.position=Vector3(3.7,.26,8.7);bucket.title="Eimer";bucket.mass=.8;add_child(bucket);loose.append(bucket)
 var shape:=CylinderShape3D.new();shape.radius=.24;shape.height=.45;var collider:=CollisionShape3D.new();collider.shape=shape;bucket.add_child(collider)
 var inside:=w.mat(Color("685347"),load("res://assets/aged-plaster.png"),.98);inside.uv1_triplanar=true;inside.uv1_scale=Vector3.ONE*3
 SurfaceDetails.vessel(bucket,Vector3(0,-.215,0),.43,.24,.18,.018,w.materials.red,inside,"BucketCup")
 for i in range(24):
  var a:=i*PI/24;var b:=(i+1)*PI/24
  w.tube(bucket,Vector3(cos(a)*.23,.12+sin(a)*.3,0),Vector3(cos(b)*.23,.12+sin(b)*.3,0),.009,w.materials.metal)
 bucket.suspend(true)
 var toy:=prop(Vector3(-4.8,.33,7.2),Vector3(.4,.62,.35),w.materials.fabric,"Stoffhase",.65)
 toy.get_child(0).queue_free();plush(toy,Vector3(0,-.29,0),.6)

func _mist_and_dust() -> void:
 var shader:=Shader.new();shader.code="""
shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform float strength=0.52;
uniform vec3 fog_tint=vec3(0.34,0.41,0.38);
uniform float clock=0.0;
varying vec3 local_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);}
void vertex(){local_pos=VERTEX;VERTEX.y+=sin(VERTEX.x*2.0+clock*0.24)*0.035;}
void fragment(){vec2 p=local_pos.xz*3.0+vec2(clock*0.035,-clock*0.018);float n=noise(p)*0.65+noise(p*2.3)*0.35;float rim=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);ALBEDO=fog_tint;ALPHA=smoothstep(0.2,0.8,n)*rim*strength;}
"""
 mist=ShaderMaterial.new();mist.shader=shader
 # Soft ellipsoid clouds have no hard horizontal plane intersections on walls.
 for pos in [Vector3(-5.4,.22,-7),Vector3(-5,.25,-1),Vector3(-4.7,.18,5),Vector3(2,.26,7.5),Vector3(8.5,.25,-7)]:
  var cloud:=w.sphere(self,pos,1,mist);cloud.scale=Vector3(3.9,.35,2.7);cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cloud.set_meta("nonblocking_atmosphere",true)
 var dust_shader:=Shader.new();dust_shader.code="shader_type spatial;render_mode unshaded,blend_add,depth_draw_never,cull_disabled,shadows_disabled;uniform float clock=0.0;void vertex(){VERTEX.x+=sin(clock*0.24+INSTANCE_CUSTOM.x*20.0)*0.14;VERTEX.y+=sin(clock*0.3+INSTANCE_CUSTOM.y*14.0)*0.16;}void fragment(){float d=length(UV-0.5);ALBEDO=vec3(0.25,0.3,0.27);ALPHA=(1.0-smoothstep(0.15,0.5,d))*0.17;}"
 var dust_material:=ShaderMaterial.new();dust_material.shader=dust_shader
 dust=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;var quad:=QuadMesh.new();quad.size=Vector2(.014,.014);mm.mesh=quad;mm.instance_count=100
 var rng:=RandomNumberGenerator.new();rng.seed=713
 for i in range(100):
  mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-9,9),rng.randf_range(.5,4.8),rng.randf_range(-11,10))))
  mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0,1))
 dust.multimesh=mm;dust.material_override=dust_material;dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(dust)

func _horror_variants() -> void:
 for id in ["blood_trail","mural_bleeds"]:
  var node:=Node3D.new();node.name=id;add_child(node);horrors[id]=node;node.visible=false
 for i in range(8):
  decal(horrors.blood_trail,3 if i%3==1 else 0,Vector3(-5.8+sin(i*.8)*.35,.039,2-i*1.4),Vector2(.75+sin(i*2.1)*.2,1.1+(i%3)*.2),Vector3(-PI/2,i*.65,0))
 for i in range(4): decal(horrors.mural_bleeds,0,Vector3(-9.91,1.3,-4+i*.7),Vector2(.8,2.3),Vector3(0,PI/2,0))

func anomaly(id: String) -> void:
 if horrors.has(id) and horrors[id] is Node3D: horrors[id].show()
 if id=="bunny_ceiling": horrors.bunny.position=Vector3(-4.3,3.7,-8.5);horrors.bunny.rotation.z=PI
 w.environment.environment.fog_density=.08
 if id=="heavy_mist":
  mist.set_shader_parameter("fog_tint",Vector3(.55,.045,.06))
  w.environment.environment.fog_light_color=Color("9c2834")

func set_active(active: bool) -> void:
 if simulation==active: return
 simulation=active
 for body in loose: body.suspend(not active)
 if active:
  if not drips.playing: drips.play()
  drips.stream_paused=false
 else: drips.stream_paused=true

func tick(delta: float, active: bool) -> void:
 set_active(active)
 if not active: return
 elapsed+=delta;mist.set_shader_parameter("clock",elapsed);dust.material_override.set_shader_parameter("clock",elapsed)

func quality(value: int) -> void:
 dust.visible=value>0
