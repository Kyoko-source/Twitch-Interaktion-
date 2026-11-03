class_name HappylandParty
extends Node3D

const TRACK=preload("res://assets/party-v385/track_cues.gd")
const COLORS: Array[Color]=[Color("ff2862"),Color("396aff"),Color("21edaa"),Color("f2bb25"),Color("bd3cff"),Color("22d9f2")]
var w: PlayWorld
var audio: AudioStreamPlayer3D
var enabled:=false
var clock:=0.0
var intensity:=0.0
var drop:=false
var lamps: Array[SpotLight3D]=[]
var fills: Array[OmniLight3D]=[]
var heads: Array[Node3D]=[]
var lenses: Array[StandardMaterial3D]=[]
var ball: Node3D
var dots: MultiMeshInstance3D
var dot_material: ShaderMaterial
var status: Label3D
var led: StandardMaterial3D
var saved_practical:=0.0

func build(world: PlayWorld) -> void:
 w=world;name="HappylandPartyLighting"
 var steel: Material=w.materials.metal;var black: Material=w.materials.dark
 # Suspended perimeter rails stay above the glazed crawl route and door heads.
 for x in [7.38,19.1]:
  w.tube(self,Vector3(x,6.87,-11.4),Vector3(x,6.87,1.05),.055,steel)
  for z in [-10.6,-5.3,.3]:w.tube(self,Vector3(x,6.87,z),Vector3(x,7.31,z),.018,steel)
 for z in [-11.4,1.05]:w.tube(self,Vector3(7.38,6.87,z),Vector3(19.1,6.87,z),.055,steel)
 var positions: Array[Vector3]=[Vector3(7.38,6.63,-9.5),Vector3(7.38,6.63,-2),Vector3(19.1,6.63,-9.5),Vector3(19.1,6.63,-2),Vector3(12.8,6.63,-11.4),Vector3(15.8,6.63,1.05)]
 for i in range(positions.size()):
  var fixture:=Node3D.new();fixture.name="PartySpot%d"%i;fixture.position=positions[i];add_child(fixture)
  w.box(fixture,Vector3(0,.12,0),Vector3(.27,.07,.25),steel)
  w.tube(fixture,Vector3(0,.12,0),Vector3(0,.24,0),.025,steel)
  for side in [-1,1]:w.box(fixture,Vector3(side*.135,-.025,0),Vector3(.035,.3,.12),steel)
  var head:=Node3D.new();fixture.add_child(head);heads.append(head)
  var housing:=w.tube(head,Vector3(0,.02,0),Vector3(0,-.26,0),.13,black);housing.set_meta("nonblocking_atmosphere",true)
  var lens:=w.mat(COLORS[i],null,.27,.25);lens.emission_enabled=true;lens.emission=COLORS[i];lens.emission_energy_multiplier=.03;lenses.append(lens)
  w.tube(head,Vector3(0,-.265,0),Vector3(0,-.276,0),.112,lens)
  var light:=SpotLight3D.new();light.name="MusicDrivenWash";light.position=positions[i]-Vector3.UP*.26;light.spot_range=11;light.spot_angle=30;light.spot_angle_attenuation=1.25;light.light_color=COLORS[i];light.light_energy=0;light.shadow_enabled=false;light.light_volumetric_fog_energy=.35;add_child(light);lamps.append(light)
 for p in [Vector3(10.0,3.0,-6.5),Vector3(17.5,3.0,-2.5)]:
  var fill:=OmniLight3D.new();fill.position=p;fill.omni_range=7;fill.light_energy=0;fill.shadow_enabled=false;fill.light_volumetric_fog_energy=.08;add_child(fill);fills.append(fill)
 var extras: Array[Vector3]=[]
 for x in [7.38,19.1]:
  for z in [-7.,-4.5,.3]:extras.append(Vector3(x,6.63,z))
 for z in [-11.4,1.05]:
  for x in [9.8,17.4]:extras.append(Vector3(x,6.63,z))
 for i in range(extras.size()):
  var p:=extras[i];w.tube(self,p+Vector3.UP*.02,p+Vector3.UP*.24,.026,steel)
  w.tube(self,p,p-Vector3.UP*.23,.11,black)
  w.tube(self,p-Vector3.UP*.235,p-Vector3.UP*.247,.096,lenses[i%lenses.size()])
 ball=Node3D.new();ball.name="MirroredDiscoBall";ball.position=Vector3(13.65,5.95,-5.5);add_child(ball)
 w.tube(self,ball.position,Vector3(13.65,7.30,-5.5),.013,steel)
 var mirror:=w.mat(Color("bdc8c4"),null,.17,1)
 w.sphere(ball,Vector3.ZERO,.355,mirror)
 var facets:=MultiMeshInstance3D.new();facets.name="IndividualMirrorTiles";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var tile:=QuadMesh.new();tile.size=Vector2(.047,.045);mm.mesh=tile;mm.instance_count=20*44
 for row in range(20):
  for col in range(44):
   var a: float=(row+.5)*PI/20;var b: float=col*TAU/44;var n:=Vector3(sin(a)*cos(b),cos(a),sin(a)*sin(b))
   var basis:=Basis.looking_at(-n,Vector3.RIGHT if absf(n.y)>.95 else Vector3.UP)
   mm.set_instance_transform(row*44+col,Transform3D(basis,n*.361))
 facets.multimesh=mm;facets.material_override=mirror;ball.add_child(facets)
 dots=MultiMeshInstance3D.new();dots.name="DiscoBallFloorReflections";var reflections:=MultiMesh.new();reflections.transform_format=MultiMesh.TRANSFORM_3D;var quad:=QuadMesh.new();quad.size=Vector2.ONE;reflections.mesh=quad;reflections.instance_count=72;dots.multimesh=reflections;add_child(dots)
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,blend_add,depth_draw_never,cull_disabled;uniform float power=0.0;void fragment(){float a=1.0-smoothstep(.08,.5,length(UV-.5));ALBEDO=vec3(.8,.88,.72)*power;ALPHA=a*power;}"
 dot_material=ShaderMaterial.new();dot_material.shader=shader;dots.material_override=dot_material;dots.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 audio=AudioStreamPlayer3D.new();audio.name="PartySong";audio.stream=load("res://assets/party-v385/party-web.ogg" if OS.has_feature("web") else "res://assets/party-v385/party.mp3").duplicate();audio.stream.loop=true;audio.position=Vector3(13.4,3.4,-4.5);audio.unit_size=5;audio.max_distance=33;audio.volume_db=-7;audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(audio)
 _control();evaluate(0,true);set_enabled(false)

func _control() -> void:
 var panel:=Node3D.new();panel.name="MaintenancePartyControl";panel.position=Vector3(-10.39,1.44,-3.48);panel.rotation.y=-PI/2;add_child(panel)
 w.box(panel,Vector3.ZERO,Vector3(.58,.62,.10),w.materials.metal)
 for x in [-.24,.24]:
  for y in [-.26,.26]:w.sphere(panel,Vector3(x,y,.058),.014,w.materials.rust)
 w.text(panel,"PARTY MODUS",Vector3(0,.18,.062),.072,Color("d4cfad"))
 status=w.text(panel,"AUS",Vector3(0,-.20,.062),.052,Color("bdba9c"))
 led=w.mat(Color("3f7e51"),null,.3);led.emission_enabled=true;led.emission=Color("4fff91");led.emission_energy_multiplier=.05
 var button:=w.sphere(panel,Vector3(0,-.01,.08),.086,led);button.scale.z=.3
 var body:=StaticBody3D.new();body.set_meta("interaction","party_control");body.position=Vector3(0,0,.10);panel.add_child(body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.58,.62,.09);shape.shape=bounds;body.add_child(shape)

func set_enabled(value: bool) -> void:
 if value and not enabled:saved_practical=w.party_light.light_energy
 if enabled and not value:w.party_light.light_energy=saved_practical
 enabled=value;status.text="AN" if value else "AUS";led.emission_energy_multiplier=2.0 if value else .05
 if enabled:w.party_light.light_energy=.16
 if value:audio.play(0)
 else:audio.stop()
 if not value:
  for i in range(lamps.size()):lamps[i].light_energy=0;lenses[i].emission_energy_multiplier=.03
  for fill in fills:fill.light_energy=0
  dot_material.set_shader_parameter("power",0.)

func evaluate(seconds: float,strobe: bool) -> void:
 clock=fposmod(seconds,TRACK.DURATION)
 var sample:=clampi(int(clock*4),0,TRACK.ENERGY.size()-1);var energy: float=TRACK.ENERGY[sample]
 var beat_index:=0
 for i in range(TRACK.BEATS.size()):
  if TRACK.BEATS[i]>clock:break
  beat_index=i
 var age: float=maxf(0,clock-float(TRACK.BEATS[beat_index]));var pulse:=exp(-age*13.)
 drop=false
 for moment in TRACK.DROPS:
  if clock>=moment and clock<moment+24:drop=true
 intensity=(.35+energy*.65)*(.65+pulse*.65)*(1.8 if drop else 1.)
 # Short, music-synchronised bursts, capped at 6 flashes/s and independently
 # switchable. Motion and colour continue when strobe is disabled.
 var flash:=strobe and drop and energy>.68 and fposmod(clock*6,1)<.20 and beat_index%8<3
 for i in range(lamps.size()):
  var color:=COLORS[(i+floori(float(beat_index)/(1 if drop else 4)))%COLORS.size()]
  lamps[i].light_color=Color("f4fff8") if flash and i%2==0 else color
  lamps[i].light_energy=(28.0 if flash else (10.0 if drop else 4.0)*intensity)
  lamps[i].spot_angle=35 if drop else 27
  var target:=Vector3(13.4+sin(clock*(1.1 if drop else .23)+i*1.9)*3.7,.15,-5.2+cos(clock*(.8 if drop else .19)+i)*4.3)
  heads[i].quaternion=Quaternion(Vector3.DOWN,(target-heads[i].global_position).normalized())
  lamps[i].global_position=heads[i].global_position-heads[i].global_basis.y*.27
  lamps[i].look_at(target)
  lenses[i].emission=color;lenses[i].emission_energy_multiplier=1.0+intensity*2
 for i in range(fills.size()):
  fills[i].light_color=COLORS[(beat_index+i*3)%COLORS.size()];fills[i].light_energy=intensity*(2.2 if drop else .5)
 ball.rotation.y=clock*(.36 if drop else .11)
 dot_material.set_shader_parameter("power",.32+intensity*.42)
 for i in range(dots.multimesh.instance_count):
  var a: float=i*2.39996+clock*.12;var radius:=1.3+fmod(i*.71,4.5)
  var p:=Vector3(clampf(13.5+cos(a)*radius,7.2,19.3),.035,clampf(-5.3+sin(a)*radius,-11.5,1.0))
  var basis:=Basis(Vector3.RIGHT,-PI/2).scaled(Vector3.ONE*(.055+fmod(i*.03,.10)))
  dots.multimesh.set_instance_transform(i,Transform3D(basis,p))

func tick(delta: float,active: bool,visible_scene: bool,strobe: bool) -> void:
 if not enabled:return
 audio.stream_paused=not active
 for light in lamps:light.visible=visible_scene
 for light in fills:light.visible=visible_scene
 dots.visible=visible_scene
 if active:evaluate(audio.get_playback_position(),strobe)

func snapshot() -> Dictionary:
 return {"enabled":enabled,"playing":audio.playing,"paused":audio.stream_paused,"clock":clock,"drop":drop,"intensity":intensity,"lights":lamps.size(),"drops":TRACK.DROPS}
