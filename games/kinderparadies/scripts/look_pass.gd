class_name LookPass
extends Node3D

# 4.11.0 lighting pass, the last word on the venue's light after every other
# module has built. Less flat grey haze, deeper shadows and contact darkness,
# light that hangs in the air as visible cones and pools, bloom on bright
# fixtures and softer filtered shadow edges. Forward+ only; Web keeps its look.
var w: PlayWorld
var advanced:=false
var cones: Array[Dictionary]=[]
var base: Dictionary={}

func build(world: PlayWorld) -> void:
 w=world;name="CinematicLightingPass"
 advanced=not OS.has_feature("web") and RenderingServer.get_current_rendering_method()=="forward_plus"
 if not advanced:return
 var env:=w.environment.environment
 env.ambient_light_energy=.088;env.ambient_light_color=Color("6a7d88")
 env.volumetric_fog_ambient_inject=.055;env.volumetric_fog_density=.036
 env.volumetric_fog_albedo=Color("cfd6d2");env.volumetric_fog_anisotropy=.62;env.volumetric_fog_detail_spread=1.4
 env.glow_enabled=true;env.glow_intensity=.62;env.glow_strength=1.05;env.glow_bloom=.035;env.glow_hdr_threshold=.95
 env.glow_blend_mode=Environment.GLOW_BLEND_MODE_SCREEN
 env.ssao_enabled=true;env.ssao_intensity=1.9;env.ssao_power=1.35;env.ssao_radius=.6;env.ssao_light_affect=.12
 env.ssil_intensity=.85
 env.adjustment_enabled=true;env.adjustment_contrast=1.1;env.adjustment_saturation=.98
 env.ssr_max_steps=128;env.ssr_fade_in=.08;env.ssr_fade_out=1.6;env.ssr_depth_tolerance=.18
 # Wetter floors: the lamps and the torch now gleam in the hall and the annex.
 for mesh: MeshInstance3D in w.find_children("*","MeshInstance3D",true,false):
  var floor_shader:=mesh.material_override as ShaderMaterial
  if floor_shader and floor_shader.shader and floor_shader.shader.resource_path.ends_with("floor.gdshader"):
   var damp=floor_shader.get_shader_parameter("dampness")
   if damp!=null and float(damp)>.1:floor_shader.set_shader_parameter("dampness",minf(1.,float(damp)*1.45))
 base={"ambient":env.ambient_light_energy,"inject":env.volumetric_fog_ambient_inject,"density":env.volumetric_fog_density}
 _pendants()
 _decals()
 # Fixtures throw their light into the air: cones from spots, soft pools from
 # lamps. The guard's torch has its own beam; party lights keep their show.
 for light: Light3D in w.find_children("*","Light3D",true,false):
  if w.party.is_ancestor_of(light) or light.light_energy<.25:continue
  var amount:=1.9 if light is SpotLight3D else .75
  cones.append({"light":light,"amount":amount,"before":light.light_volumetric_fog_energy})
  light.light_volumetric_fog_energy=maxf(light.light_volumetric_fog_energy,amount)

# Industrial pendants over the dark half of the hall: a cone of warm or cold
# light each, hanging in the haze. The red-light anomaly tints them like the
# practicals (world.set_anomaly); the power cut switches off every Light3D.
const PENDANTS:=[[Vector3(2.,5.6,-2.5),"ffcf8f"],[Vector3(1.,5.6,6.6),"ffd9a0"],[Vector3(8.5,5.6,3.),"a9c6c9"],[Vector3(15.,5.6,13.),"ffcf8f"],[Vector3(-3.,5.4,-9.6),"c9d6cf"],[Vector3(15.5,5.6,4.5),"ffd9a0"]]
var pendants: Array[SpotLight3D]=[]
func _pendants() -> void:
 var shade_mat:=w.mat(Color("2c3331"),null,.45,.7)
 var bulb:=w.mat(Color("fff1d6"));bulb.emission_enabled=true;bulb.emission=Color("ffe7bf");bulb.emission_energy_multiplier=6.
 for spec in PENDANTS:
  var p: Vector3=spec[0]
  var root:=Node3D.new();root.name="IndustrialPendant";root.position=p;add_child(root)
  w.tube(root,Vector3(0,.25,0),Vector3(0,1.6,0),.008,w.materials.dark)
  var shade:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=.09;cone.bottom_radius=.34;cone.height=.26;cone.radial_segments=28;shade.mesh=cone;shade.material_override=shade_mat;root.add_child(shade)
  w.sphere(root,Vector3(0,-.08,0),.07,bulb)
  var light:=SpotLight3D.new();light.name="PendantCone";light.position=Vector3(0,-.12,0);light.rotation.x=-PI/2
  light.light_color=Color(spec[1]);light.light_energy=4.2;light.spot_range=10.;light.spot_angle=34;light.spot_angle_attenuation=1.6
  light.shadow_enabled=true;light.light_size=.05;light.light_volumetric_fog_energy=2.2;root.add_child(light)
  pendants.append(light)

# Stains drawn here, projected as decals: dark grime along the wall base,
# brown water marks and mould higher up, scuffed blots on the floors.
static var stain_maps: Dictionary={}
static func stain(kind: String) -> ImageTexture:
 if stain_maps.has(kind):return stain_maps[kind]
 var size:=128 if kind=="base" else 192
 var image:=Image.create(size,size,false,Image.FORMAT_RGBA8)
 var noise:=FastNoiseLite.new();noise.seed=hash(kind)%9973;noise.frequency=.035;noise.fractal_octaves=5
 for y in range(size):
  for x in range(size):
   var u:=x/(size-1.);var v:=y/(size-1.);var n:=noise.get_noise_2d(x,y)*.5+.5
   var a:=0.;var c:=Color("2a2218")
   match kind:
    "base":
     # Dark at the bottom edge, ragged upwards, fading at the sides.
     a=clampf((v-.25+n*.45)*1.6,0,1)*smoothstep(0.,.18,u)*smoothstep(1.,.82,u);c=Color("1f1a14")
    "water":
     var r:=Vector2(u-.5,v-.5).length()*2.;var edge:=exp(-pow((r-.82+n*.18)/.07,2.))
     a=clampf((1.-smoothstep(.55,.95,r+n*.25))*.45+edge*.75,0,1);c=Color("5b4426")
    "mould":
     var r:=Vector2(u-.5,v-.5).length()*2.;a=clampf((1.-r)*1.3*smoothstep(.45,.75,n),0,1);c=Color("1d2418")
    _:
     var r:=Vector2(u-.5,v-.5).length()*2.;a=clampf((1.-smoothstep(.3,1.,r+n*.3))*.85,0,1);c=Color("1c1814")
   image.set_pixel(x,y,Color(c.r,c.g,c.b,a))
 image.generate_mipmaps()
 stain_maps[kind]=ImageTexture.create_from_image(image);return stain_maps[kind]

func _decal(kind: String,p: Vector3,normal: Vector3,size_value: Vector2,strength: float) -> void:
 var decal:=Decal.new();decal.name="Stain_"+kind;decal.texture_albedo=stain(kind);decal.albedo_mix=strength
 decal.size=Vector3(size_value.x,.7,size_value.y);decal.cull_mask=1;decal.upper_fade=.4;decal.lower_fade=.4
 var y:=normal.normalized();var x:=(Vector3.UP if absf(y.y)<.9 else Vector3.FORWARD).cross(y).normalized();var z:=x.cross(y)
 decal.basis=Basis(x,y,z);decal.position=p;add_child(decal)

func _decals() -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=4110
 for room in SecretPlushEnding.ROOMS:
  var x0: float=room[1];var x1: float=room[2];var z0: float=room[3];var z1: float=room[4]
  # Grime along every wall base, in overlapping strips.
  for side in [[Vector3(x0,0,0),Vector3.RIGHT,true],[Vector3(x1,0,0),Vector3.LEFT,true],[Vector3(0,0,z0),Vector3.BACK,false],[Vector3(0,0,z1),Vector3.FORWARD,false]]:
   var length:=(z1-z0) if side[2] else (x1-x0)
   var steps:=int(length/2.6)
   for i in range(steps):
    var t:=lerpf(.08,.92,(i+.5)/maxf(1,steps))
    var at: Vector3=side[0]+(Vector3(0,.42,lerpf(z0,z1,t)) if side[2] else Vector3(lerpf(x0,x1,t),.42,0))
    _decal("base",at,side[1],Vector2(rng.randf_range(2.4,3.4),.95),rng.randf_range(.55,.8))
   # A few water marks and mould higher on the walls.
   for i in range(maxi(1,int(length/7.))):
    var t:=rng.randf_range(.1,.9)
    var at: Vector3=side[0]+(Vector3(0,rng.randf_range(1.4,2.4),lerpf(z0,z1,t)) if side[2] else Vector3(lerpf(x0,x1,t),rng.randf_range(1.4,2.4),0))
    var kind:="water" if rng.randf()<.6 else "mould"
    _decal(kind,at,side[1],Vector2.ONE*rng.randf_range(.7,1.6),rng.randf_range(.5,.8))
  # Scuffed blots on the floor.
  for i in range(maxi(2,int((x1-x0)*(z1-z0)/28.))):
   _decal("floor",Vector3(rng.randf_range(x0+.6,x1-.6),.05,rng.randf_range(z0+.6,z1-.6)),Vector3.UP,Vector2.ONE*rng.randf_range(.8,2.2),rng.randf_range(.35,.65))

func quality(value: int) -> void:
 if not advanced:return
 # Soft shadow filtering only where it is affordable; cones are lighter on Medium.
 RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if value==2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
 for cone in cones:
  if is_instance_valid(cone.light):cone.light.light_volumetric_fog_energy=cone.amount*(1. if value==2 else .6) if value>0 else cone.before
 for light in pendants:light.shadow_enabled=value==2

func snapshot() -> Dictionary:
 return {"advanced":advanced,"cones":cones.size(),"base":base,"pendants":pendants.size(),"decals":get_children().filter(func(n):return n is Decal).size()}
