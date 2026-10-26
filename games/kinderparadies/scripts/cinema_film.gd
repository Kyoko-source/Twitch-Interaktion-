class_name CinemaFilm
extends Node3D

const MOVIE:="res://assets/cinema-film/happyland-advert.ogv"
const SOUND:="res://assets/cinema-film/happyland-advert.ogg"
var w: PlayWorld
var owned:=false
var playing:=false
var reel: Node3D
var spools: Array[Node3D]=[]
var screen: MeshInstance3D
var original: Material
var picture: StandardMaterial3D
var video: VideoStreamPlayer
var audio: AudioStreamPlayer3D
var viewport: SubViewport
var gain:=.8

func build(world: PlayWorld) -> void:
 w=world;name="OptionalHappylandFilm";position=ServiceAnnex.OFFSET
 var desk:=w.polish.find_child("ProjectionWorktable",true,false)
 # The worktable is parented to the annex rather than the polish node.
 if not desk: desk=w.annex.find_child("ProjectionWorktable",true,false)
 assert(desk!=null,"Cinema projection table missing")
 reel=Node3D.new();reel.name="CollectibleHappylandReel";reel.position=Vector3(-.28,.868,-.02);desk.add_child(reel)
 _reel(reel,.125,false)
 var label:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.20,.055);label.mesh=quad;label.position=Vector3(0,.044,0);label.rotation.x=-PI/2
 label.material_override=w.mat(Color("d3c7a2"),DressingPrint.texture(self,"film"),.88);reel.add_child(label)
 var body:=StaticBody3D.new();body.set_meta("interaction","film_reel");reel.add_child(body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.31,.13,.31);shape.shape=bounds;shape.position.y=.035;body.add_child(shape)
 # A wall-mounted remote reaches the ceiling projector without requiring jumps.
 var panel:=w.box(self,Vector3(-6.245,1.27,-15.83),Vector3(.10,.31,.27),w.materials.metal,true)
 (panel.get_child(0) as StaticBody3D).set_meta("interaction","cinema_projector")
 for y in [1.18,1.34]:
  w.tube(self,Vector3(-6.18,y,-15.83),Vector3(-6.16,y,-15.83),.043,w.materials.gold if y>1.3 else w.materials.red)
 w.artwork(self,Vector3(-6.245,1.68,-15.83),Vector2(.64,.19),DressingPrint.texture(self,"film"),PI/2)
 for x in [-5.59,-5.20]:
  var spool:=Node3D.new();spool.name="ProjectorFilmSpool";spool.position=Vector3(x,3.26,-17.7);add_child(spool);_reel(spool,.16,true);spool.hide();spools.append(spool)
 screen=w.annex.screen_surface;original=screen.material_override
 viewport=SubViewport.new();viewport.name="FilmProjectionViewport";viewport.size=Vector2i(1008,400);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
 var black:=ColorRect.new();black.size=Vector2(1008,400);black.color=Color.BLACK;viewport.add_child(black)
 video=VideoStreamPlayer.new();video.name="HappylandArchiveVideo";video.expand=true;video.position=Vector2(237,0);video.size=Vector2(534,400);video.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(video)
 video.finished.connect(stop)
 picture=w.mat(Color.WHITE);picture.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;picture.albedo_texture=viewport.get_texture();picture.albedo_texture_force_srgb=true
 audio=AudioStreamPlayer3D.new();audio.name="HappylandFilmSpeaker";audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;audio.position=Vector3(2.9,1.6,-17.7);audio.max_distance=14;audio.unit_size=2.8;audio.volume_db=-9;audio.bus="Interior" if w.native_art else "Master";add_child(audio)
 set_volume(.8)

func _reel(parent: Node3D, radius: float, vertical: bool) -> void:
 var disc:=Node3D.new();parent.add_child(disc)
 if vertical: disc.rotation.x=PI/2
 w.tube(disc,Vector3(0,0,0),Vector3(0,.028,0),radius*.78,w.materials.dark)
 for y in [0.0,.035]:
  var mesh:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=radius*.85;torus.outer_radius=radius;torus.rings=32;torus.ring_segments=8;mesh.mesh=torus;mesh.material_override=w.materials.metal;mesh.position.y=y;disc.add_child(mesh)
  for i in range(5):
   var a:=TAU*i/5;w.tube(disc,Vector3(0,y,0),Vector3(cos(a)*radius*.91,y,sin(a)*radius*.91),.009,w.materials.metal)
 w.tube(disc,Vector3(0,-.008,0),Vector3(0,.043,0),.025,w.materials.rust)

func sync(found: bool) -> void:
 owned=found;reel.visible=not owned
 # Hidden collectibles cannot intercept a ray cast meant for the table behind.
 for body in reel.find_children("*","StaticBody3D",true,false): body.collision_layer=0 if owned else 1
 if not owned: stop()

func start() -> bool:
 if not owned or not ResourceLoader.exists(MOVIE) or not ResourceLoader.exists(SOUND): return false
 if not video.stream: video.stream=load(MOVIE)
 if not audio.stream: audio.stream=load(SOUND)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 screen.material_override=picture;video.paused=false;video.play();audio.stream_paused=false;audio.play();playing=true
 for spool in spools: spool.show()
 return true

func stop() -> void:
 playing=false
 if video: video.stop();video.paused=false
 if audio: audio.stop();audio.stream_paused=false
 if screen: screen.material_override=original
 if viewport: viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for spool in spools: spool.hide()

func set_volume(value: float) -> void:
 gain=clampf(value,0,1)
 if audio: audio.volume_db=-9+linear_to_db(maxf(.0001,gain))

func tick(delta: float, active: bool) -> void:
 if not playing: return
 video.paused=not active;audio.stream_paused=not active
 if active:
  for i in range(spools.size()): spools[i].rotation.z+=delta*(2.9 if i==0 else 2.3)

func snapshot() -> Dictionary:
 return {"owned":owned,"playing":playing,"paused":video.paused,"position":video.stream_position,"audio_position":audio.get_playback_position(),"audio_paused":audio.stream_paused,"screen":screen.material_override==picture,"spools":spools.map(func(n):return n.visible),"gain":gain}
