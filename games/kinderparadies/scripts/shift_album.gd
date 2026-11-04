class_name ShiftAlbum
extends RefCounted

# Separate from the current shift: death and New Shift must never clear this.
var g: Node3D
var path: String
var entries: Dictionary={}
var textures: Dictionary={}
var capturing:=false

func build(game: Node3D) -> void:
 g=game
 path="user://qa-after-play-album.json" if g.AUTHOR_TOOLS and ("--self-test" in OS.get_cmdline_user_args() or "--render-qa" in OS.get_cmdline_user_args()) or OS.has_feature("qa") else "user://after-play-album.json"
 var text: String=g._persistent_text(path)
 var data=JSON.parse_string(text) if not text.is_empty() else null
 if data is Dictionary:
  for key in ["1","2","3"]:
   if data.get(key) is Dictionary and bool(data[key].get("found",false)):entries[key]=data[key]

func discover(number: int) -> void:
 var key:=str(number)
 if number<1 or number>3 or entries.has(key):return
 entries[key]={"found":true,"image":""};save()

func save() -> void:
 g._write_persistent_text(path,JSON.stringify(entries))

func capture(number: int,camera: Camera3D) -> void:
 var key:=str(number)
 if capturing or not entries.has(key) or not str(entries[key].get("image","")).is_empty() or not is_instance_valid(camera):return
 # Render the actual closing scene without HUD/end titles into a small, one-shot
 # camera. No concept images, and no hidden ending images ship with the game.
 capturing=true
 var view:=SubViewport.new();view.name="EndingAlbumExposure";view.size=Vector2i(640,360);view.world_3d=camera.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_DISABLED;g.add_child(view)
 var lens:=Camera3D.new();view.add_child(lens);lens.global_transform=camera.global_transform;lens.fov=camera.fov;lens.near=camera.near;lens.far=camera.far;lens.environment=camera.environment;lens.current=true
 view.render_target_update_mode=SubViewport.UPDATE_ONCE
 # Frame signals are unavailable in the headless renderer used for validation.
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  if is_instance_valid(view):
   var image:=view.get_texture().get_image()
   if image and not image.is_empty():
    entries[key].image=Marshalls.raw_to_base64(image.save_jpg_to_buffer(.82));textures.erase(key);save()
 if is_instance_valid(view):view.queue_free()
 capturing=false

func photo(key: String) -> Texture2D:
 if textures.has(key):return textures[key]
 if not entries.has(key):return null
 var bytes:=Marshalls.base64_to_raw(str(entries[key].get("image","")))
 if bytes.is_empty() or bytes.size()>400000:return null
 var image:=Image.new()
 if image.load_jpg_from_buffer(bytes)!=OK:return null
 var result:=ImageTexture.create_from_image(image);textures[key]=result;return result

func show_menu() -> void:
 g.phase="help";g.return_phase="menu";NightMenus.clear(g);NightMenus.backdrop(g,true)
 var heading: Label=g._label("Erinnerungen an die Nachtschicht",58,Color("e8e1c8"));heading.add_theme_font_override("font",NightMenus.menu_font());heading.position=Vector2(100,83);g.menu.add_child(heading)
 var hint: Label=g._label("Drei mögliche Ausgänge. Deine entdeckten Enden bleiben hier erhalten.",23,Color("aba992"));hint.position=Vector2(103,172);g.menu.add_child(hint)
 var names:=["Feierabend mit Freunden","Die Wahrheit hinter der Tür","Ich bin dann mal weg"]
 for i in range(3):
  var key:=str(i+1);var found:=entries.has(key)
  var panel:=PanelContainer.new();panel.name="AlbumEnding"+key;panel.position=Vector2(100+i*578,285);panel.size=Vector2(548,490);g.menu.add_child(panel)
  var paper:=StyleBoxFlat.new();paper.bg_color=Color("c8bea2") if found else Color("202824");paper.set_content_margin_all(20);paper.set_corner_radius_all(2);paper.shadow_color=Color(0,0,0,.45);paper.shadow_size=10;panel.add_theme_stylebox_override("panel",paper)
  var col:=VBoxContainer.new();col.add_theme_constant_override("separation",22);panel.add_child(col)
  var image:=TextureRect.new();image.custom_minimum_size=Vector2(508,286);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.texture=photo(key) if found else null
  if image.texture:col.add_child(image)
  else:
   var blank:=PanelContainer.new();blank.custom_minimum_size=image.custom_minimum_size;col.add_child(blank);image.free()
   var dark:=StyleBoxFlat.new();dark.bg_color=Color("131b18");blank.add_theme_stylebox_override("panel",dark)
   var lock: Label=g._label("Aufnahme folgt beim nächsten Abspann" if found else "Noch keine Erinnerung",21,Color("999c8b"));lock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;lock.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;blank.add_child(lock)
  var title: Label=g._label(names[i] if found else "Unentdecktes Ende",29,Color("353a30") if found else Color("8c9386"));title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(title)
  col.add_child(g._label("ENDE %d/3"%(i+1) if found else "—",18,Color("62644f") if found else Color("737d72")))
 var back: Button=g._button("Zurück",g._return_from_panel,true);back.position=Vector2(100,874);back.size=Vector2(320,60);g.menu.add_child(back);g._telemetry()

func snapshot() -> Dictionary:
 return {"found":entries.keys(),"photos":entries.keys().filter(func(key):return not str(entries[key].get("image","")).is_empty())}
