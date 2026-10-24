class_name GuardEquipment
extends Node3D

var badge: ViewportTexture
var jingle: AudioStreamPlayer
var keyring: Node3D
var step_count:=0
var jingle_count:=0

func build(guard: NightGuard) -> void:
 name="PersonalEquipment"
 badge=EnvironmentPrint.texture(self,"badge")
 var tape:=StandardMaterial3D.new();tape.albedo_color=Color("acaa86");tape.albedo_texture=load("res://assets/aged-plaster.png");tape.roughness=.98;tape.uv1_triplanar=true;tape.uv1_scale=Vector3.ONE*55
 var wrap:=MeshInstance3D.new();wrap.name="TorchRepairTape";var cylinder:=CylinderMesh.new();cylinder.top_radius=.034;cylinder.bottom_radius=.034;cylinder.height=.028;cylinder.radial_segments=32;wrap.mesh=cylinder;wrap.material_override=tape;wrap.rotation.x=PI/2;wrap.position=Vector3(0,0,.064);guard.torch_body.add_child(wrap)
 var label:=MeshInstance3D.new();label.name="TorchInventoryMark";var quad:=QuadMesh.new();quad.size=Vector2(.038,.026);label.mesh=quad;label.rotation.x=-PI/2;label.position=Vector3(0,.0348,.064);guard.torch_body.add_child(label)
 var ink:=StandardMaterial3D.new();ink.albedo_texture=EnvironmentPrint.texture(self,"torch_tag");ink.roughness=.98;label.material_override=ink
 # Metal keys hang from the torch's existing wrist loop, all geometry in metres.
 keyring=Node3D.new();keyring.name="GuardKeyring";keyring.position=Vector3(-.035,-.04,.14);guard.torch_body.add_child(keyring)
 var steel:=StandardMaterial3D.new();steel.albedo_color=Color("747c73");steel.metallic=.8;steel.roughness=.49
 var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.012;torus.outer_radius=.015;torus.rings=24;torus.ring_segments=8;ring.mesh=torus;ring.material_override=steel;ring.rotation.x=PI/2;keyring.add_child(ring)
 for i in range(3):
  var key:=Node3D.new();key.rotation=Vector3(.12*i,-.30+i*.33,-.24+i*.23);keyring.add_child(key)
  var bow:=MeshInstance3D.new();var head:=TorusMesh.new();head.inner_radius=.005;head.outer_radius=.010;head.rings=16;head.ring_segments=6;bow.mesh=head;bow.material_override=steel;bow.rotation.x=PI/2;bow.position.y=-.017;key.add_child(bow)
  _box(key,Vector3(0,-.040,0),Vector3(.005,.037,.003),steel)
  for n in range(3): _box(key,Vector3(.004,-.047+n*.006,0),Vector3(.008,.003,.004),steel)
 for mesh in guard.torch_body.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 jingle=AudioStreamPlayer.new();jingle.name="PersonalKeys";jingle.stream=load("res://assets/backstage-v270/keys.wav");jingle.volume_db=-30;jingle.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(jingle)

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
 var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=size;mesh.mesh=cube;mesh.material_override=material;mesh.position=pos;parent.add_child(mesh)

func step(running: bool, landing: bool) -> void:
 step_count+=1
 if landing or (running and step_count%4==0):
  jingle.pitch_scale=1.0+(step_count%3)*.035;jingle.volume_db=-27 if landing else -31;jingle.play();jingle_count+=1

func tick(guard: NightGuard, delta: float) -> void:
 var moving:=Vector2(guard.velocity.x,guard.velocity.z).length()>.5
 var sway:=sin(guard.walk_clock*.6)*.15 if moving and guard.motion else 0.0
 keyring.rotation.z=lerpf(keyring.rotation.z,sway,minf(1,delta*8))

func stop() -> void:
 if jingle: jingle.stop()
