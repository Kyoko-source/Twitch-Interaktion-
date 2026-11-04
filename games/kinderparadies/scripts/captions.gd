class_name AfterPlayCaptions
extends CanvasLayer

var panel: PanelContainer
var label: Label
var speech: Dictionary={}
var signs: Dictionary={}
var source:=""
var content:=""
var sign_id:=""
var clock:=0.0
var scan_clock:=0.0
var cached_sign:=""

func build() -> void:
 name="SpeechAndSignSubtitles";layer=20
 speech=JSON.parse_string(FileAccess.get_file_as_string("res://locales/subtitles.json"))
 signs=JSON.parse_string(FileAccess.get_file_as_string("res://locales/signs_en.json"))
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);panel.offset_left=-660;panel.offset_right=660;panel.offset_top=-205;panel.offset_bottom=-125;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(0,0,0,.84);style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=12;style.content_margin_bottom=12;style.set_corner_radius_all(5);panel.add_theme_stylebox_override("panel",style)
 label=Label.new();label.name="CaptionText";label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",27);label.add_theme_color_override("font_color",Color("f1ebdc"));panel.add_child(label);clear()

func clear() -> void:
 source="";content="";sign_id="";panel.hide()

func line_at(track: String,seconds: float) -> String:
 for row: Dictionary in speech.get(track,[]):
  if seconds>=float(row.start) and seconds<float(row.end):return str(row.get(AfterPlayLanguage.code,row.de))
 return ""

func show_line(value: String,kind: String) -> void:
 content=value;source=kind;label.text=value;panel.visible=not value.is_empty()
 # Keep the call status and the hold-to-skip control below the spoken lines.
 panel.offset_top=-325 if kind=="intro" else -205;panel.offset_bottom=-245 if kind=="intro" else -125

func tick(delta: float,g: Node3D) -> void:
 if not is_instance_valid(g.world) or g.world_loading:clear();return
 if bool(g.settings.subtitles):
  if g.phase=="intro" and g.intro.stage=="call" and not g.intro.paused:
   show_line(line_at("intro",g.intro.voice.get_playback_position()) if g.intro.recording else AfterPlayLanguage.t(ElevatorIntro.LINES[mini(5,int(g.intro.stage_clock/maxf(1,g.intro.call_length)*6))]),"intro");return
  if g.phase=="play" and g.archive.ending=="recording":
   show_line(line_at("archive",g.archive.recording_position),"archive");return
  if g.phase=="play" and g.world.film.playing and g.world.film.audio.global_position.distance_to(g.player.camera.global_position)<14:
   show_line(line_at("film",g.world.film.audio.get_playback_position()),"film");return
  if g.phase=="play" and g.world.soundscape.voice.playing and g.world.tubes.inside:
   show_line("[Children laughing]" if g.world.soundscape.last_voice=="children-laugh.ogg" else "[Children crying]" if AfterPlayLanguage.english() else "[Kinder weinen]","ambient")
   if not AfterPlayLanguage.english() and g.world.soundscape.last_voice=="children-laugh.ogg":show_line("[Kinder lachen]","ambient")
   return
 if g.dialogue and g.dialogue.ui.visible:clear();return
 if g.phase!="play" or not bool(g.settings.sign_subtitles) or not AfterPlayLanguage.english():
  cached_sign="";scan_clock=0;clear();return
 scan_clock-=delta
 if scan_clock<=0:
  scan_clock=.1;cached_sign=read_sign(g)
 if cached_sign.is_empty():clear()
 else:show_line(cached_sign,"sign")

func read_sign(g: Node3D,cursor: Vector2=Vector2(-1,-1)) -> String:
 var camera: Camera3D=g.player.camera;var viewport:=camera.get_viewport()
 if cursor.x<0:cursor=viewport.get_visible_rect().size*.5 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else viewport.get_mouse_position()
 var origin:=camera.project_ray_origin(cursor);var direction:=camera.project_ray_normal(cursor);var best:=4.8;var found: Node3D
 for node: Node3D in get_tree().get_nodes_in_group("caption_signs"):
  if not node.is_visible_in_tree() or not (g.world.is_ancestor_of(node) or g.intro.is_ancestor_of(node)):continue
  var local:=node.to_local(origin);var ray:=node.global_basis.inverse()*direction
  if local.z<=0 or ray.z>=-.0001:continue
  var distance: float=-local.z/ray.z
  if distance<.08 or distance>best:continue
  var p:=local+ray*distance;var rect: Vector2=node.get_meta("sign_rect",Vector2.ONE)
  if absf(p.x)>rect.x*.5 or absf(p.y)>rect.y*.5:continue
  var id: String=node.get_meta("sign_design","");var words: String=node.get_meta("sign_text","")
  if not signs.has(id) and AfterPlayLanguage.english_text(words)==words:continue
  var excludes: Array[RID]=[g.player.get_rid()];var blocked:=false
  for i in range(5):
   var hit:=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*(distance-.035),1,excludes))
   if hit.is_empty():break
   var body: Node=hit.collider;var parent_name:=str(body.get_parent().name)
   if parent_name in ["ScratchedTransparentBays","PolycarbonateWindows"]:excludes.append(body.get_rid());continue
   blocked=true;break
  if blocked:continue
  best=distance;found=node
 if not found:sign_id="";return ""
 sign_id=str(found.get_meta("sign_design","text"))
 return str(signs.get(sign_id,AfterPlayLanguage.english_text(str(found.get_meta("sign_text","")))))

func snapshot() -> Dictionary:
 return {"visible":panel.visible,"source":source,"text":content,"sign":sign_id}
