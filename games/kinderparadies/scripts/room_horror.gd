class_name RoomHorror
extends Node3D

const MUSIC:="res://assets/party/musicbox.mp3"
const CREATURE:="res://assets/creatures/vent-ossuary-v21.glb"
const SHAFT:=Rect2(-2.05,-20.8,1.5,1.7)
var w: PlayWorld
var music: AudioStreamPlayer3D
var dancer: Node3D
var creature: Node3D
var clock:=0.0
var bulbs: Array[Dictionary]=[]
var panels:=0

static func outside_shaft(rect: Rect2) -> Array[Rect2]:
 # Subtract the same physical opening from roof slabs, acoustic tiles and rails.
 var cut:=rect.intersection(SHAFT)
 if not cut.has_area(): return [rect]
 var pieces: Array[Rect2]=[]
 for part in [Rect2(rect.position,Vector2(cut.position.x-rect.position.x,rect.size.y)),Rect2(Vector2(cut.end.x,rect.position.y),Vector2(rect.end.x-cut.end.x,rect.size.y)),Rect2(Vector2(cut.position.x,rect.position.y),Vector2(cut.size.x,cut.position.y-rect.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,rect.end.y-cut.end.y))]:
  if part.has_area(): pieces.append(part)
 return pieces

func _ceiling_piece(rect: Rect2, y: float, thickness: float, material: Material, panel: bool=false) -> void:
 for part in outside_shaft(rect):
  var mesh:=w.box(self,Vector3(part.get_center().x,y,part.get_center().y),Vector3(part.size.x,thickness,part.size.y),material)
  if panel: mesh.set_meta("ceiling_panel",true);panels+=1

func build(world: PlayWorld) -> void:
 w=world;name="RoomHorror"
 _ceilings();_bulbs();_music_box();_vent_creature()

func _ceilings() -> void:
 var plaster:=w.mat(Color("aaa990"),load("res://assets/aged-plaster.png"),.99)
 var acoustic:=w.mat(Color("6c7065"),load("res://assets/paint.png"),.99)
 for spec in [{"x":-17.24,"width":7.74,"material":plaster},{"x":-6.30,"width":9.94,"material":acoustic},{"x":-9.28,"width":2.76,"material":plaster}]:
  var count:=ceili(float(spec.width)/1.2);var width: float=spec.width/count
  for col in range(count):
   for row in range(8):
    _ceiling_piece(Rect2(spec.x+col*width+.0125,-22.4+row*1.125+.0125,width-.025,1.1),3.535,.045,spec.material,true)
  for col in range(count+1): _ceiling_piece(Rect2(spec.x+col*width-.0125,-22.4,.025,9),3.51,.035,w.materials.metal)
  for row in range(9): _ceiling_piece(Rect2(spec.x,-22.4+row*1.125-.0125,spec.width,.025),3.51,.035,w.materials.metal)

func _bulbs() -> void:
 # Visible opal bulbs, sockets, protective cages and supports meet the ceiling.
 for pos in [Vector3(-14.5,3.12,-15.4),Vector3(-11.2,3.12,-21),Vector3(-7.9,3.12,-15.6),Vector3(-3.8,3.12,-15.6),Vector3(.4,3.12,-20.7)]:
  w.box(self,Vector3(pos.x,3.49,pos.z),Vector3(.15,.055,.15),w.materials.dark)
  w.tube(self,Vector3(pos.x,3.47,pos.z),pos+Vector3(0,.13,0),.022,w.materials.dark)
  w.tube(self,pos+Vector3(0,.13,0),pos+Vector3(0,.035,0),.045,w.materials.metal)
  var glow:=w.mat(Color("ddd0a0"),null,.4);glow.emission_enabled=true;glow.emission=Color("f0d69b");glow.emission_energy_multiplier=1.1
  var bulb:=w.sphere(self,pos,.065,glow);bulb.scale.y=1.25
  for side in [-1,1]:
   w.tube(self,pos+Vector3(side*.09,.11,0),pos+Vector3(side*.09,-.11,0),.007,w.materials.metal)
   w.tube(self,pos+Vector3(0,.11,side*.09),pos+Vector3(0,-.11,side*.09),.007,w.materials.metal)
  var light:=w.lamp(pos+Vector3(0,-.08,0),Color("d0c18b"),.55,4.5);light.shadow_enabled=true
  bulbs.append({"light":light,"emission":glow,"energy":.55})

 # Both the actual kitchen tube and its bounce light share a faulty contact.
 for fixture in w.practicals:
  if fixture.get_meta("kitchen_flicker",false): bulbs.append({"light":fixture,"emission":(fixture.get_meta("diffuser") if fixture.has_meta("diffuser") else null),"energy":fixture.get_meta("base_energy"),"kitchen":true})

func _music_box() -> void:
 # An open, brass-trimmed wooden automaton rests on the existing sideboard.
 var root:=Node3D.new();root.name="PartyMusicBox";root.position=Vector3(19.12,.89,-2.42);root.rotation.y=-PI/2;add_child(root)
 var wood:=w.mat(Color("4b3025"),load("res://assets/wood.png"),.72)
 var brass:=w.mat(Color("948054"),null,.46,.7)
 var velvet:=w.mat(Color("4e1924"),load("res://assets/paint.png"),.95)
 w.box(root,Vector3(0,.075,0),Vector3(.44,.15,.34),wood)
 for y in [.014,.135]: w.box(root,Vector3(0,y,0),Vector3(.46,.018,.36),brass)
 w.box(root,Vector3(0,.154,0),Vector3(.39,.015,.29),velvet)
 for x in [-.17,.17]:
  for z in [-.12,.12]: w.sphere(root,Vector3(x,-.009,z),.025,brass)
 var lid:=Node3D.new();lid.position=Vector3(0,.16,-.155);lid.rotation.x=-.23;root.add_child(lid)
 w.box(lid,Vector3(0,.19,0),Vector3(.44,.38,.035),wood)
 w.box(lid,Vector3(0,.19,.021),Vector3(.37,.31,.012),brass)
 w.box(lid,Vector3(0,.19,.029),Vector3(.33,.27,.008),w.mat(Color("3d5350"),null,.22,.7))
 for z in [-.07,.05]: w.tube(root,Vector3(.23,.08,z),Vector3(.28,.08,z),.012,brass)
 w.tube(root,Vector3(.28,.08,-.07),Vector3(.28,.08,.05),.009,brass)
 dancer=Node3D.new();dancer.position=Vector3(0,.17,0);root.add_child(dancer)
 var porcelain:=w.mat(Color("b6ad96"),null,.55)
 w.tube(dancer,Vector3.ZERO,Vector3(0,.035,0),.06,brass)
 var dress:=w.sphere(dancer,Vector3(0,.105,0),.065,velvet);dress.scale=Vector3(1,1.15,1)
 w.tube(dancer,Vector3(0,.13,0),Vector3(0,.23,0),.023,porcelain)
 var face:=w.sphere(dancer,Vector3(0,.262,0),.039,porcelain);face.scale=Vector3(.85,1.15,.85)
 for side in [-1,1]:
  w.tube(dancer,Vector3(side*.022,.20,0),Vector3(side*.082,.225,0),.009,porcelain)
  w.tube(dancer,Vector3(side*.082,.225,0),Vector3(side*.05,.275,0),.008,porcelain)
  w.sphere(dancer,Vector3(side*.013,.269,.031),.005,w.materials.dark)
  var ear:=w.sphere(dancer,Vector3(side*.022,.32,0),.018,porcelain);ear.scale=Vector3(.6,2.8,.55)
 w.tube(dancer,Vector3(-.014,.248,.032),Vector3(.014,.248,.032),.003,w.materials.rust)
 music=AudioStreamPlayer3D.new();music.name="MusicBoxAudio";music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var stream: AudioStreamMP3=load(MUSIC);stream.loop=true;music.stream=stream;music.position=root.position+Vector3(0,.25,0);music.volume_db=-9;music.unit_size=1.25;music.max_distance=10;music.attenuation_filter_cutoff_hz=4200;add_child(music)
 if w.native_art: music.bus="Interior"

func _vent_creature() -> void:
 # An actual roof opening leads into a deep, unlit duct. The neck starts inside.
 var pos:=Vector3(-1.3,3.40,-20.15)
 var soot:=w.mat(Color("060706"),null,1)
 var darkness:=w.mat(Color.BLACK,null,1);darkness.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 var cap:=w.box(self,Vector3(pos.x,4.65,pos.z+.2),Vector3(1.5,.06,1.7),darkness);cap.name="ShaftDarkEnd"
 for x in [-.77,.77]: w.box(self,Vector3(pos.x+x,4.04,pos.z+.2),Vector3(.04,1.22,1.74),soot)
 for z in [-.67,1.07]: w.box(self,Vector3(pos.x,4.04,pos.z+z),Vector3(1.5,1.22,.04),soot)
 for x in [-.78,.78]: w.box(self,Vector3(pos.x+x,3.46,pos.z+.2),Vector3(.1,.12,1.85),w.materials.metal)
 for z in [-.72,1.12]: w.box(self,Vector3(pos.x,3.46,pos.z+z),Vector3(1.64,.12,.1),w.materials.metal)
 for x in [-.7,.7]:
  for z in [-.64,1.04]: w.sphere(self,Vector3(pos.x+x,3.387,pos.z+z),.025,w.materials.rust)
 var grate:=Node3D.new();grate.position=Vector3(pos.x+.8,3.4,pos.z+.2);grate.rotation.z=.5;add_child(grate)
 w.box(grate,Vector3(.1,-.08,0),Vector3(.23,.05,1.5),w.materials.metal)
 for z in [-.73,.73]: w.box(grate,Vector3(.2,-.37,z),Vector3(.045,.64,.045),w.materials.metal)
 for k in range(10): w.box(grate,Vector3(.2,-.1-k*.06,0),Vector3(.035,.025,1.4),w.materials.metal)
 creature=(load(CREATURE) as PackedScene).instantiate();creature.name="CinemaVentDweller";creature.position=pos;creature.rotation.y=-.55;add_child(creature)
 for mesh in creature.find_children("*","MeshInstance3D",true,false):
  for s in range(mesh.mesh.get_surface_count()):
   var material: Material=mesh.get_active_material(s)
   if material is StandardMaterial3D:
    material=material.duplicate();mesh.set_surface_override_material(s,material)
    material.albedo_texture=load("res://assets/aged-plaster.png");material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*3.2
    material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.48
    material.roughness=.94;material.metallic_specular=.10
   if material is StandardMaterial3D and material.resource_name=="Mottled cadaver skin":
    material.albedo_texture=load("res://assets/creatures/dweller-skin.png");material.uv1_triplanar=true;material.uv1_scale=Vector3.ONE*2.2
    material.normal_enabled=true;material.normal_texture=w.atmosphere.micro_normal;material.normal_scale=.22

func tick(delta: float, active: bool) -> void:
 if music.stream_paused==active: music.stream_paused=not active
 if active and not music.playing: music.play()
 if not active: return
 clock+=delta;dancer.rotation.y=clock*.7
 # Isolated short contact failures, not a constant full-screen strobe.
 for i in range(bulbs.size()):
  var phase:=fmod(clock+i*3.17,12.7+i*1.9);var amount:=1.0
  if phase>11.7 and phase<12.18: amount=.15 if sin(phase*92+i)>-.1 else .68
  if bulbs[i].get("kitchen",false):
   var kitchen_phase:=fmod(clock,8.3)
   amount=(.06 if sin(kitchen_phase*109)>.05 else .52) if kitchen_phase>6.6 and kitchen_phase<7.12 else 1.0
  bulbs[i].light.light_energy=bulbs[i].energy*amount
  if bulbs[i].emission: bulbs[i].emission.emission_energy_multiplier=(.45 if bulbs[i].get("kitchen",false) else 1.1)*amount
 # The industrial pendant spots follow their visible lamp's contact failures.
 for i in range(5):
  var phase:=fmod(clock+i*2.31,19.0+i*2.0);var amount:=1.0
  if phase>18.25 and phase<18.63: amount=.28 if sin(phase*85)>0 else .76
  w.practicals[i].light_energy=.65*amount
  if w.native_art and i<w.native_art.spots.size(): w.native_art.spots[i].light_energy=3.0*amount
 # Subtle breathing stays rooted inside the shaft.
 creature.scale=Vector3(1,1+sin(clock*.65)*.006,1)

func snapshot() -> Dictionary:
 var powers: Array[float]=[]
 for item in bulbs: powers.append(item.light.light_energy)
 return {"clock":clock,"panels":panels,"music":music.playing,"paused":music.stream_paused,"track":music.stream.resource_path,"creature":is_instance_valid(creature),"creature_geometry":creature_geometry(),"shaft_depth":1.25,"bulbs":powers}

func creature_geometry() -> Dictionary:
 var bounds:=AABB();var first:=true;var surfaces:=0
 for mesh in creature.find_children("*","MeshInstance3D",true,false):
  var local: AABB=(creature.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
  bounds=local if first else bounds.merge(local);first=false;surfaces+=mesh.mesh.get_surface_count()
 return {"width":bounds.size.x,"rear":bounds.position.z,"top":bounds.end.y,"bottom":bounds.position.y,"surfaces":surfaces}
