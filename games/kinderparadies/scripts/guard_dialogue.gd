class_name GuardDialogue
extends Node3D

var game: Node3D
var catalog: Dictionary={}
var seen: Dictionary={}
var pending: Array[String]=[]
var current:=""
var segment:=0
var mode:="typing"
var clock:=0.
var next_letter:=0.
var next_sound:=0.
var cooldown:=0.
var idle_time:=0.
var tube_time:=0.
var idle_anchor:=Vector3.ZERO
var memory_dwell:=0.
var cook_dwell:=0.
var language:="de"
var world_id:=0
var arrival_armed:=true
var ui: CanvasLayer
var text: DialogueText
var letters:=DialogueLetters.new()
var typing: AudioStreamPlayer

func build(g: Node3D) -> void:
 game=g;name="NightguardComments"
 catalog=JSON.parse_string(FileAccess.get_file_as_string("res://locales/guard_dialogue.json"))
 ui=CanvasLayer.new();ui.layer=19;add_child(ui)
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
 text=DialogueText.new();text.name="TypewrittenGuardComment";text.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(text)
 text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);text.offset_top=-232;text.offset_bottom=-232
 add_child(letters);letters.build(g.player)
 typing=AudioStreamPlayer.new();typing.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;typing.volume_db=-35;add_child(typing)
 var click:=AudioStreamWAV.new();click.format=AudioStreamWAV.FORMAT_16_BITS;click.mix_rate=16000
 var data:=PackedByteArray();data.resize(640)
 var noise:=RandomNumberGenerator.new();noise.seed=406
 for i in range(320):
  var t:=i/16000.;var sample: float=(sin(t*TAU*1170.)*.25+noise.randf_range(-.65,.65))*exp(-t*310.)
  data.encode_s16(i*2,int(sample*14000.))
 click.data=data;typing.stream=click;ui.hide()

func reset() -> void:
 seen.clear();pending.clear();current="";segment=0;mode="typing";clock=0.;cooldown=0.;idle_time=0.;memory_dwell=0.;cook_dwell=0.;arrival_armed=true
 tube_time=0.;idle_anchor=game.player.position;letters.clear();text.layout("",[]);typing.stop();ui.hide()

func request(id: String) -> bool:
 if not catalog.has(id) or seen.has(id):return false
 seen[id]=true
 if bool(game.settings.subtitles):pending.append(id)
 game._save()
 return true

func focuses(point: Vector3,distance: float) -> bool:
 var camera: Camera3D=game.player.camera;var toward:=point-camera.global_position
 if toward.length()>distance or toward.length()<.1 or -camera.global_basis.z.dot(toward.normalized())<.91:return false
 var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,point-toward.normalized()*.08,1,[game.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func situations(delta: float) -> void:
 var w: PlayWorld=game.world
 var in_tube:=w.tubes.contains(game.player.position)
 if in_tube and game.player.crouching:request("crawl")
 tube_time=tube_time+delta if in_tube else 0.
 if tube_time>=30.:request("tube_hiding")
 var hunt: HorseHunt=w.horse_hunt
 if hunt.enabled and hunt.catch_count>0 and hunt.phase in ["recoiling","rejoining","following","clown","retreating","resolved"]:request("horse_survived")

func observe(delta: float) -> void:
 var g:=game;var w: PlayWorld=g.world;var p: Vector3=g.player.position
 if arrival_armed and g.state.streak==0 and p.z<17.05:
  arrival_armed=false;request("arrival")
 if g.state.streak==6:request("round7")
 if g.state.streak==12:request("round13")
 if not seen.has("memories"):
  memory_dwell=memory_dwell+delta if focuses(w.watch.board.to_global(Vector3(0,0,.15)),5.) else 0.
  if memory_dwell>.65:request("memories")
 if not seen.has("cook"):
  var kitchen:=w.acoustics.area(p)=="kitchen"
  cook_dwell=cook_dwell+delta if kitchen and focuses(w.annex.clown.head.global_position,6.) else 0.
  if cook_dwell>.45:request("cook")
 if w.encounters.id=="bunny_lunge" and w.encounters.triggered:request("bunny")
 if w.soundscape.voice.playing and w.soundscape.last_voice=="children-laugh.ogg" and (w.tubes.contains(p) or w.climbing.sky.contains(p)):request("children")
 if w.tubes.contains(p) or p.distance_to(idle_anchor)>.35:idle_anchor=p;idle_time=0.
 else:idle_time+=delta
 if idle_time>=60.:request("idle")

func speech_busy() -> bool:
 var g:=game
 return g.archive.ending=="recording" or g.world.film.playing or (g.world.soundscape.voice.playing and g.world.tubes.contains(g.player.position)) or g.world.horse_hunt.phase in ["catch","fatal"] or g.player.fright>.08

func _layout() -> void:
 language=AfterPlayLanguage.code
 var lines: Array=catalog[current].get(language,catalog[current].de)
 text.layout(str(lines[clampi(segment,0,lines.size()-1)]),catalog[current].get("emphasis",[]))

func tick(delta: float) -> void:
 var g:=game
 if not is_instance_valid(g.world) or g.world_loading:ui.hide();letters.hide();typing.stop();return
 var instance: int=g.world.get_instance_id()
 if instance!=world_id:letters.clear();world_id=instance;idle_anchor=g.player.position;idle_time=0.;tube_time=0.;memory_dwell=0.;cook_dwell=0.
 # Detect gameplay events independently of subtitle display priority. A scream
 # may postpone the text, but does not stop the thirty-second hiding clock.
 if g.phase=="play":situations(delta)
 var active: bool=g.phase=="play" and bool(g.settings.subtitles) and not speech_busy()
 ui.visible=active and not current.is_empty()
 letters.tick(delta,active)
 if not active:typing.stop();return
 if AudioServer.get_bus_index("NightAmbience")>=0:typing.bus="NightAmbience"
 observe(delta)
 cooldown=maxf(0.,cooldown-delta)
 if current.is_empty():
  if pending.is_empty() or cooldown>0:return
  current=pending.pop_front();segment=0;mode="typing";clock=0.;next_letter=0.;next_sound=0.;_layout();ui.show()
 if language!=AfterPlayLanguage.code:
  var progress:=float(text.typed)/maxi(1,text.glyphs.size());_layout();text.typed=int(progress*text.glyphs.size())
 var step:=minf(delta,.15);clock+=step;next_sound-=step
 if mode=="typing":
  next_letter-=step
  var budget:=4
  while next_letter<=0 and text.typed<text.glyphs.size() and budget>0:
   var character: String=text.glyphs[text.typed].char;text.typed+=1;budget-=1
   next_letter+=.034+(.16 if character in [".","!","?","…"] else .07 if character in [",",":"] else 0.)
   if not character.strip_edges().is_empty() and next_sound<=0:typing.play();next_sound=.075
  if text.typed>=text.glyphs.size():mode="hold";clock=0.;typing.stop()
 elif mode=="hold":
  if clock>maxf(2.,text.glyphs.size()*.028):mode="fall";clock=0.
 else:
  var target:=mini(text.glyphs.size(),int(clock/.026))
  while text.dropped<target:
   var glyph: Dictionary=text.glyphs[text.dropped]
   letters.release(glyph.char,text.global_position+glyph.position,glyph.color);text.dropped+=1
  if text.dropped>=text.glyphs.size():
   segment+=1
   var lines: Array=catalog[current].get(language,catalog[current].de)
   if segment>=lines.size():current="";cooldown=1.2;ui.hide()
   else:mode="typing";clock=0.;next_letter=0.;_layout()
 text.queue_redraw()

func serialize() -> Dictionary:
 return {"seen":seen.keys(),"pending":pending,"current":current,"segment":segment,"mode":mode,"clock":clock,"typed":text.typed,"dropped":text.dropped,"arrival":arrival_armed}

func restore(value: Variant) -> void:
 reset()
 if not value is Dictionary:return
 for id in value.get("seen",[]):
  if id is String and catalog.has(id):seen[id]=true
 for id in value.get("pending",[]):
  if id is String and catalog.has(id) and id not in pending:pending.append(id);seen[id]=true
 var id: String=str(value.get("current",""))
 arrival_armed=bool(value.get("arrival",game.state.streak==0))
 if not catalog.has(id):return
 current=id;seen[id]=true;pending.erase(id);segment=clampi(int(value.get("segment",0)),0,catalog[id].de.size()-1)
 _layout();mode=str(value.get("mode","typing"))
 if mode not in ["typing","hold","fall"]:mode="typing"
 clock=clampf(float(value.get("clock",0)),0,20.)
 text.typed=clampi(int(value.get("typed",0)),0,text.glyphs.size());text.dropped=clampi(int(value.get("dropped",0)),0,text.typed)

func snapshot() -> Dictionary:
 return {"current":current,"segment":segment,"mode":mode,"text":text.text,"typed":text.typed,"dropped":text.dropped,"seen":seen.keys(),"pending":pending.duplicate(),"visible":ui.visible,"letters":letters.snapshot(),"idle":idle_time,"tube_time":tube_time,"typing":typing.playing}
