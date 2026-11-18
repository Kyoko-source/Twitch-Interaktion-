class_name Thunderstorm
extends Node3D

# 4.11.0 thunderstorm over Happyland. Lightning flares through the parking
# window and the glass entrance door: two or three hard blue-white stutters
# that throw the frames' shadows across the floor and light shafts into the
# haze. The weather schedules each strike and sends its thunder after a delay
# that grows with the distance. Outdoor light: a power cut never switches it off.
const PATTERN:=[[0.,1.],[.05,.12],[.11,.8],[.19,.05],[.29,.55],[.36,.0],[.52,.25],[.6,0.]]
var w: PlayWorld
var flares: Array[SpotLight3D]=[]
var clock:=-1.
var strength:=0.
var flashes:=0
# Window glass whose rain lights up with each flash.
var panes: Array[ShaderMaterial]=[]

func build(world: PlayWorld) -> void:
 w=world;name="ThunderstormOverHappyland"
 var exterior: HappylandExterior=w.graphics.exterior if w.graphics else null
 if exterior and exterior.window_light:
  _flare("LightningThroughParkingWindow",exterior.window_light.global_transform)
 for mesh: MeshInstance3D in w.find_children("*","MeshInstance3D",true,false):
  var glass:=mesh.material_override as ShaderMaterial
  if glass and glass.shader and glass.shader.resource_path.ends_with("glazing.gdshader") and glass not in panes:panes.append(glass)
 if w.backstage and w.backstage.exit_root:
  var root: Node3D=w.backstage.exit_root
  var at:=root.to_global(Vector3(0,2.7,-7.6));var aim:=root.to_global(Vector3(.2,.2,-1.))
  _flare("LightningThroughEntranceGlass",Transform3D(Basis.IDENTITY,at).looking_at(aim,Vector3.UP))

func _flare(title: String,transform_value: Transform3D) -> void:
 var light:=SpotLight3D.new();light.name=title;light.light_color=Color("cdd9ff");light.light_energy=0
 light.spot_range=22;light.spot_angle=62;light.spot_angle_attenuation=.7;light.shadow_enabled=true;light.light_size=.02
 light.light_volumetric_fog_energy=3.5;light.set_meta("outdoor",true);add_child(light);light.global_transform=transform_value
 flares.append(light)

# amount: 1 = right overhead, small values = far away.
func flash(amount: float) -> void:
 clock=0.;strength=clampf(amount,0,1);flashes+=1

func _process(delta: float) -> void:
 if clock<0:return
 clock+=minf(delta,.05)
 var level:=0.
 for i in range(PATTERN.size()-1):
  var a: Array=PATTERN[i];var b: Array=PATTERN[i+1]
  if clock>=a[0] and clock<b[0]:level=a[1];break
 if clock>=PATTERN[-1][0]:clock=-1.;level=0.
 for light in flares:light.light_energy=level*lerpf(6.,34.,strength)
 for glass in panes:glass.set_shader_parameter("flash",level*lerpf(.3,1.,strength))

func snapshot() -> Dictionary:
 return {"flares":flares.size(),"panes":panes.size(),"flashes":flashes,"flashing":clock>=0}
