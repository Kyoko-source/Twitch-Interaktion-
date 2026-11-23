class_name AnomalyAlbum
extends RefCounted

# 5.2.8: every anomaly the player has correctly reported (red door) becomes a
# polaroid. Kept across shifts, deaths and modes like the memory album; a new
# shift never clears it. Photos are real in-game renders shipped with the game
# (assets/album-v528, made by --render-qa --album-photos-qa).
const PHOTOS:="res://assets/album-v528/"
const MILESTONES:={10:"album_10",34:"album_34",68:"album_all"}
var g: Node3D
var path:=""
var found: Dictionary={}
var textures: Dictionary={}
var font: Font

func build(game: Node3D) -> void:
 g=game
 var author: bool=g.AUTHOR_TOOLS and ("--self-test" in OS.get_cmdline_user_args() or "--render-qa" in OS.get_cmdline_user_args())
 path="user://qa-%d-after-play-anomalies.json"%OS.get_process_id() if author else "user://qa-after-play-anomalies.json" if OS.has_feature("qa") else "user://after-play-anomalies.json"
 var text: String=g._persistent_text(path)
 var data=JSON.parse_string(text) if not text.is_empty() else null
 if data is Dictionary and data.get("found") is Dictionary:
  for id in data.found:
   var entry=data.found[id]
   var key: String=PatrolState.REPLACEMENTS.get(id,id)
   if valid(key) and entry is Dictionary:found[key]={"date":str(entry.get("date","")),"times":maxi(int(entry.get("times",1)),1)}
 font=load("res://assets/backstage-v270/Caveat.ttf")

static func valid(id: String) -> bool:
 return PatrolState.ANOMALIES.any(func(a):return a.id==id)

static func total() -> int:
 return PatrolState.ANOMALIES.size()

func count() -> int:
 return found.size()

# Called after a correct red door. Returns true for a new polaroid.
func record(id: String) -> bool:
 if not valid(id):return false
 if found.has(id):
  found[id].times=int(found[id].times)+1;save();return false
 found[id]={"date":Time.get_date_string_from_system(),"times":1};save()
 g.achievements.notify("NEUES POLAROID",_title(id),"Anomalie-Album: %d / %d"%[count(),total()])
 for amount in MILESTONES:
  if count()>=amount:g.achievements.unlock(MILESTONES[amount])
 return true

func save() -> void:
 g._write_persistent_text(path,JSON.stringify({"version":1,"found":found}))

static func entry(id: String) -> Dictionary:
 for a in PatrolState.ANOMALIES:
  if a.id==id:return a
 return {}

# Short caption: the first clause of the catalogue sentence.
static func _title(id: String) -> String:
 var text: String=entry(id).get("name","")
 var cut:=text.find(". ")
 if cut>0:text=text.substr(0,cut)
 if text.length()>58:
  var space:=text.rfind(" ",55)
  text=text.substr(0,space if space>20 else 55)+" …"
 return text.trim_suffix(".")

func photo(id: String) -> Texture2D:
 if textures.has(id):return textures[id]
 var file:=PHOTOS+id+".jpg"
 var result: Texture2D=load(file) if ResourceLoader.exists(file) else null
 textures[id]=result;return result

func _polaroid(id: String,index: int,on_open: Callable) -> Control:
 var known:=found.has(id)
 var card:=Button.new();card.name="Polaroid_"+id;card.custom_minimum_size=Vector2(252,282);card.focus_mode=Control.FOCUS_ALL
 var frame:=StyleBoxFlat.new();frame.bg_color=Color("ece6d6") if known else Color("1d221f");frame.set_corner_radius_all(2)
 frame.shadow_color=Color(0,0,0,.55);frame.shadow_size=10;frame.shadow_offset=Vector2(3,6)
 frame.content_margin_left=14;frame.content_margin_right=14;frame.content_margin_top=14;frame.content_margin_bottom=10
 var hover:=frame.duplicate() as StyleBoxFlat;hover.border_color=Color("d6b25e");hover.set_border_width_all(3)
 card.add_theme_stylebox_override("normal",frame);card.add_theme_stylebox_override("pressed",frame);card.add_theme_stylebox_override("disabled",frame)
 card.add_theme_stylebox_override("hover",hover);card.add_theme_stylebox_override("focus",hover)
 var col:=VBoxContainer.new();col.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_theme_constant_override("separation",6)
 col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);col.offset_left=14;col.offset_right=-14;col.offset_top=14;col.offset_bottom=-10;card.add_child(col)
 var image:=TextureRect.new();image.custom_minimum_size=Vector2(224,196);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if known:
  image.texture=photo(id)
  col.add_child(image)
 else:
  var dark:=Panel.new();dark.custom_minimum_size=Vector2(224,196);dark.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var black:=StyleBoxFlat.new();black.bg_color=Color("0b0d0c");dark.add_theme_stylebox_override("panel",black);col.add_child(dark)
  var mark: Label=g._label("?",92,Color("3a423c"));mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mark.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;dark.add_child(mark)
 var caption: Label=g._label(_title(id) if known else str(entry(id).get("zone","")),19 if known else 22,Color("2b2a26") if known else Color("6f776f"))
 caption.add_theme_font_override("font",font);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.custom_minimum_size=Vector2(224,0);caption.max_lines_visible=2;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(caption)
 # A loose, hand-pinned look: every card sits a little crooked.
 card.pivot_offset=card.custom_minimum_size*.5;card.rotation=deg_to_rad(float((index*37)%9)-4.)*.55
 if known:card.pressed.connect(func():on_open.call(id))
 return card

func show_menu(back: Callable) -> void:
 g.phase="help";g.return_phase="menu";NightMenus.clear(g);NightMenus.backdrop(g,true)
 var heading: Label=g._label("Anomalie-Album",58,Color("e8e1c8"));heading.add_theme_font_override("font",NightMenus.menu_font());heading.position=Vector2(100,70);g.menu.add_child(heading)
 var share:=float(count())/float(total())
 var progress: Label=g._label("%d / %d Anomalien gefunden"%[count(),total()],24,Color("d6b25e"));progress.position=Vector2(104,158);g.menu.add_child(progress)
 var bar:=ProgressBar.new();bar.name="AlbumProgress";bar.position=Vector2(104,196);bar.size=Vector2(560,10);bar.show_percentage=false;bar.max_value=1.;bar.value=share
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("d6b25e");var empty:=StyleBoxFlat.new();empty.bg_color=Color("2a302b")
 bar.add_theme_stylebox_override("fill",fill);bar.add_theme_stylebox_override("background",empty);g.menu.add_child(bar)
 var hint: Label=g._label("Jede Anomalie, die du mit der roten Tür meldest, landet hier als Foto. Klicke ein Polaroid an.",18,Color("8f968b"));hint.position=Vector2(700,186);g.menu.add_child(hint)
 var scroll:=ScrollContainer.new();scroll.name="AlbumScroll";scroll.position=Vector2(90,232);scroll.size=Vector2(1740,650);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;g.menu.add_child(scroll)
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",18);margin.add_theme_constant_override("margin_top",16);margin.add_theme_constant_override("margin_bottom",24);scroll.add_child(margin)
 var grid:=GridContainer.new();grid.name="AlbumGrid";grid.columns=6;grid.add_theme_constant_override("h_separation",28);grid.add_theme_constant_override("v_separation",30);margin.add_child(grid)
 var reopen:=func():show_menu(back)
 # Found polaroids first (in the order of the catalogue), then the blanks.
 var ids: Array=PatrolState.ANOMALIES.map(func(a):return a.id)
 var ordered: Array=ids.filter(func(id):return found.has(id))+ids.filter(func(id):return not found.has(id))
 for i in range(ordered.size()):grid.add_child(_polaroid(ordered[i],i,func(id):_detail(id,reopen)))
 var back_button: Button=g._button("Zurück",back,true);back_button.position=Vector2(100,920);back_button.size=Vector2(320,60);g.menu.add_child(back_button);back_button.grab_focus();g._telemetry()

func _detail(id: String,back: Callable) -> void:
 NightMenus.clear(g);NightMenus.backdrop(g,true)
 var a: Dictionary=entry(id);var info: Dictionary=found.get(id,{})
 var frame:=PanelContainer.new();frame.position=Vector2(150,110);frame.rotation=deg_to_rad(-2.)
 var paper:=StyleBoxFlat.new();paper.bg_color=Color("ece6d6");paper.shadow_color=Color(0,0,0,.6);paper.shadow_size=18;paper.shadow_offset=Vector2(6,10)
 paper.content_margin_left=26;paper.content_margin_right=26;paper.content_margin_top=26;paper.content_margin_bottom=20;frame.add_theme_stylebox_override("panel",paper);g.menu.add_child(frame)
 var col:=VBoxContainer.new();col.add_theme_constant_override("separation",10);frame.add_child(col)
 var image:=TextureRect.new();image.custom_minimum_size=Vector2(760,570);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.texture=photo(id);col.add_child(image)
 var caption: Label=g._label(_title(id),34,Color("2b2a26"));caption.add_theme_font_override("font",font);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.custom_minimum_size.x=760;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(caption)
 var zone: Label=g._label(str(a.get("zone","")).to_upper(),20,Color("d6b25e"));zone.position=Vector2(1040,150);g.menu.add_child(zone)
 var text: Label=g._label(str(a.get("name","")),28,Color("e8e1c8"));text.position=Vector2(1040,190);text.size=Vector2(720,0);text.custom_minimum_size.x=720;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;g.menu.add_child(text)
 var times: int=int(info.get("times",1))
 var meta: Label=g._label("Zuerst gemeldet am %s  ·  %d× erkannt"%[_date(str(info.get("date",""))),times],20,Color("8f968b"));meta.position=Vector2(1040,430);g.menu.add_child(meta)
 var back_button: Button=g._button("Zurück zum Album",back,true);back_button.position=Vector2(1040,880);back_button.size=Vector2(380,60);g.menu.add_child(back_button);back_button.grab_focus()

static func _date(iso: String) -> String:
 var parts:=iso.split("-")
 return "%s.%s.%s"%[parts[2],parts[1],parts[0]] if parts.size()==3 else iso

func snapshot() -> Dictionary:
 return {"found":count(),"total":total(),"ids":found.keys()}
