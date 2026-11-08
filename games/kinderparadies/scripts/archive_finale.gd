class_name ArchiveFinale
extends Node3D

const RECORDING:="res://assets/finale/marelle.ogg"
const RECORDER:=Vector3(-12.1,.035,-9.55)
var w: PlayWorld
var progress: ArchiveState
var voice: AudioStreamPlayer
var led: StandardMaterial3D
var looked_away:=false
var started:=false
var trigger_count:=0
var duration:=0.0

func build(world: PlayWorld) -> void:
 w=world;name="ArchiveFinale"
 # Seated on the floor with its back against the south archive wall (z=-7.8),
 # knees drawn up and wrists shackled out to either side at shoulder height.
 var remains: Node3D=(load("res://assets/finale/archive-corpse-v431.glb") as PackedScene).instantiate()
 # Faces into the room (-Z) with its back flat to the wall.
 remains.name="ChainedRemains";remains.position=Vector3(-13.05,0.,-8.12);remains.rotation=Vector3(0,PI,0);add_child(remains)
 var rot:=ShaderMaterial.new();rot.shader=load("res://assets/finale/corpse_skin.gdshader");rot.set_shader_parameter("micro",w.atmosphere.micro_normal)
 for mesh in remains.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var material:=mesh.get_active_material(i) as StandardMaterial3D
   if not material:continue
   if material.resource_name=="Mummified leathery remnant":mesh.set_surface_override_material(i,rot)
   elif material.resource_name in ["Corpse scanned complexion","Matted dead hair"]:
    var dim:=material.duplicate() as StandardMaterial3D;dim.albedo_color=Color(.52,.48,.42) if material.resource_name.begins_with("Corpse") else Color(.16,.15,.14);dim.roughness=.8;mesh.set_surface_override_material(i,dim)
   elif "fabric" in material.resource_name:
    # Rotted, filth-soaked cloth: the weave shows, the colour has gone.
    var rag:=material.duplicate() as StandardMaterial3D;rag.albedo_texture=load("res://assets/pbr/dirty_carpet/albedo.jpg");rag.albedo_color=rag.albedo_color*Color(.75,.7,.62);rag.uv1_triplanar=true;rag.uv1_scale=Vector3.ONE*5
    rag.normal_enabled=true;rag.normal_texture=load("res://assets/pbr/dirty_carpet/normal.jpg");rag.normal_scale=.8;rag.roughness=.97
    rag.detail_enabled=true;rag.detail_mask=load("res://assets/presentation-v250/blood-texture.png");rag.detail_albedo=load("res://assets/aged-plaster.png");rag.detail_blend_mode=BaseMaterial3D.BLEND_MODE_MUL
    mesh.set_surface_override_material(i,rag)
   elif material.resource_name=="Ancient human bone":
    var b:=material.duplicate() as StandardMaterial3D;b.albedo_color=Color("62553e");b.albedo_texture=load("res://assets/aged-plaster.png");b.uv1_triplanar=true;b.uv1_scale=Vector3.ONE*6
    b.normal_enabled=true;b.normal_texture=w.atmosphere.micro_normal;b.normal_scale=.3;b.roughness=.9;mesh.set_surface_override_material(i,b)
 # Decades of seepage: a dark stain spreading on the floor.
 var stain:=w.mat(Color(.05,.035,.02,.82),null,.35);stain.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 var pool:=w.sphere(self,Vector3(-13.05,.004,-8.32),1,stain);pool.scale=Vector3(.62,.004,.42);pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 w.box(remains,Vector3(0,.35,0),Vector3(.8,.7,.6),w.materials.dark,true).hide()
 for joint in ["LeftWrist","RightWrist","LeftAnkle","RightAnkle"]:
  var point:=remains.find_child(joint,true,false) as Node3D
  var p: Vector3=point.global_position-global_position
  # Wrist chains run up to rings in the wall; ankle chains to floor rings.
  var outward:=signf(p.x-(-13.05))
  var anchor:=p+(Vector3(outward*.22,.5,.09) if joint.ends_with("Wrist") else Vector3(outward*.2,-.06,.22))
  _restraint(p,anchor,joint)
 _recorder()
 voice=AudioStreamPlayer.new();voice.name="MarelleRecording";voice.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;voice.stream=load(RECORDING);voice.volume_db=-1.5;voice.bus="NightVoice" if AudioServer.get_bus_index("NightVoice")>=0 else "Master";add_child(voice)
 duration=voice.stream.get_length();voice.finished.connect(_finished_recording)

func _restraint(wrist: Vector3, anchor: Vector3, label: String) -> void:
 anchor.y=maxf(.05,anchor.y)
 var root:=Node3D.new();root.name="Chain"+label;add_child(root)
 var iron:=w.mat(Color("786650"),null,.68,.8);iron.normal_enabled=true;iron.normal_texture=w.atmosphere.micro_normal;iron.normal_scale=.4
 w.box(root,anchor-Vector3(0,.018,0),Vector3(.15,.034,.15),iron)
 for x in [-.052,.052]:
  for z in [-.052,.052]: w.sphere(root,anchor+Vector3(x,.01,z),.012,iron)
 for i in range(20):
  var t:=i/19.0;var pos:=wrist.lerp(anchor,t);pos.y=maxf(.047,pos.y-sin(t*PI)*.09)
  var ring:=TorusMesh.new();ring.inner_radius=.019;ring.outer_radius=.029;ring.rings=16;ring.ring_segments=6
  var link:=MeshInstance3D.new();link.mesh=ring;link.material_override=iron;link.position=pos;link.rotation=Vector3(PI/2 if i%2 else 0,0,atan2(anchor.z-wrist.z,anchor.x-wrist.x));root.add_child(link)
 var cuff:=TorusMesh.new();cuff.inner_radius=.023;cuff.outer_radius=.035;cuff.rings=24;cuff.ring_segments=8
 var shackle:=MeshInstance3D.new();shackle.mesh=cuff;shackle.material_override=iron;shackle.position=wrist;shackle.rotation.z=PI/2;root.add_child(shackle)

func _recorder() -> void:
 var root:=Node3D.new();root.name="CassetteRecorder";root.position=RECORDER;root.rotation.y=-.18;add_child(root)
 var shell:=w.mat(Color("514b3b"),load("res://assets/paint.png"),.86,.2)
 var dark:=w.mat(Color("111513"),null,.82);var steel: Material=w.materials.metal
 w.box(root,Vector3(0,.043,0),Vector3(.30,.078,.19),shell)
 w.box(root,Vector3(0,.083,-.022),Vector3(.22,.006,.102),dark)
 for x in [-.052,.052]:
  w.tube(root,Vector3(x,.087,-.024),Vector3(x,.090,-.024),.024,w.materials.paper)
  w.tube(root,Vector3(x,.090,-.024),Vector3(x,.092,-.024),.009,dark)
 w.box(root,Vector3(0,.091,-.024),Vector3(.072,.003,.009),w.materials.rust)
 for i in range(13): w.box(root,Vector3(-.115+i*.019,.083,.066),Vector3(.006,.006,.022),dark)
 for i in range(5): w.box(root,Vector3(-.108+i*.052,.038,.107),Vector3(.039,.033,.030),steel if i!=2 else w.materials.gold)
 for side in [-1,1]:
  for z in [-.071,.069]: w.sphere(root,Vector3(side*.126,.082,z),.005,steel)
 led=w.mat(Color("38100b"),null,.6);led.emission_enabled=true;led.emission=Color("f27442");led.emission_energy_multiplier=0
 w.sphere(root,Vector3(.123,.086,.023),.005,led)
 var body:=StaticBody3D.new();body.collision_layer=4;body.collision_mask=0;body.set_meta("interaction","archive_recording");root.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.34,.14,.25);shape.shape=box;shape.position.y=.055;body.add_child(shape)

func sync(value: ArchiveState) -> void:
 progress=value;started=false;looked_away=false

func interact() -> void:
 if not progress or not progress.unlocked or progress.ending in ["armed","complete"]: return
 if progress.ending=="idle" and not _inside():
  _game()._announce("Geh ganz ins Archiv, um die Aufnahme zu starten.",4)
  return
 if progress.ending=="idle": progress.ending="recording";progress.recording_position=0
 _play();_game()._save()
 _game()._announce("Die Tür verriegelt sich. Hör die Aufnahme zu Ende.",4)

func _inside() -> bool:
 var position: Vector3=_game().player.position
 return w.archive.safe_pose(position) and position.x<LostArchive.ENTRY.x-.3

func _play() -> void:
 if started: return
 # Earlier versions allowed saving a playing tape from outside the archive.
 if not _inside():
  var player: NightGuard=_game().player
  player.position=Vector3(-11.3,0,-9.9);player.velocity=Vector3.ZERO;player.rotation=Vector3.ZERO;player.camera.look_at(RECORDER+Vector3(0,.07,0))
 w.archive.hold_for_recording()
 started=true;voice.stream_paused=false;voice.play(minf(progress.recording_position,maxf(0,duration-.05)))
 _game()._show_recording_memories()

func _finished_recording() -> void:
 if not progress or progress.ending!="recording": return
 progress.ending="armed";progress.recording_position=duration;looked_away=not _facing_exit();w.archive.open();_game()._save()
 _game()._end_recording_memories()

func _game() -> Node3D:
 return w.get_parent()

func _facing_exit() -> bool:
 var camera: Camera3D=_game().player.camera
 var direction: Vector3=LostArchive.ENTRY+Vector3(0,1.5,0)-camera.global_position;direction.y=0
 var forward: Vector3=-camera.global_basis.z;forward.y=0
 return forward.normalized().dot(direction.normalized())>.65

func tick(_delta: float, active: bool) -> void:
 if not progress: return
 voice.stream_paused=not active
 var recording:=progress.ending=="recording"
 var bus:=AudioServer.get_bus_index("NightAmbience")
 if bus>=0:
  var amount: float=_game().settings.ambience*(.18 if active and recording else 1.0)
  AudioServer.set_bus_volume_db(bus,linear_to_db(amount) if amount>0 else -80)
 led.emission_energy_multiplier=.9 if recording and active else .15 if progress.ending in ["armed","complete"] else 0.0
 if not active: return
 if recording:
  if not started: _play()
  if voice.playing: progress.recording_position=clampf(voice.get_playback_position(),0,duration)
 if progress.ending!="armed": return
 var player: NightGuard=_game().player
 var facing:=_facing_exit()
 if not facing: looked_away=true
 # Resolve before the capsule crosses the doorway, including backwards or
 # crouched exits. Old saves already outside the room must resolve too.
 var at_exit:=player.position.x>=LostArchive.ENTRY.x-.65 and absf(player.position.z-LostArchive.ENTRY.z)<1.05
 if (facing and looked_away) or at_exit or not w.archive.safe_pose(player.position):
  progress.ending="complete";trigger_count+=1;_game()._save();_game()._start_archive_scare()

func snapshot() -> Dictionary:
 return {"state":progress.ending if progress else "idle","position":progress.recording_position if progress else 0.0,"duration":duration,"playing":voice.playing,"paused":voice.stream_paused,"started":started,"looked_away":looked_away,"triggers":trigger_count,"track":RECORDING,"skeleton_meshes":get_node("ChainedRemains").find_children("*","MeshInstance3D",true,false).size(),"chains":4}
