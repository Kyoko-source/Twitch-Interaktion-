class_name NightMenus
extends RefCounted

# Native controls over the real room, never a baked screenshot of the interface.
static func clear(g: Node3D) -> void:
 for child in g.menu.get_children(): g.menu.remove_child(child);child.queue_free()
 g.menu.show();g.hud.hide();g.player.release();g.world.atmosphere.set_active(false)

static func home(g: Node3D) -> void:
 clear(g)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader:=Shader.new();shader.code="shader_type canvas_item;void fragment(){float a=mix(.98,.06,smoothstep(.18,.68,UV.x));COLOR=vec4(.012,.018,.016,a);}"
 var material:=ShaderMaterial.new();material.shader=shader;shade.material=material;g.menu.add_child(shade)
 for row in range(2):
  var heading: Label=g._label("AFTER" if row==0 else "PLAY",120);heading.add_theme_font_override("font",g.title_font);heading.position=Vector2(80,68+row*118);g.menu.add_child(heading)
 var subtitle: Label=g._label("Kinderparadies",36);subtitle.add_theme_font_override("font",g.title_font);subtitle.position=Vector2(88,328);g.menu.add_child(subtitle)
 var lead: Label=g._label("Dreizehn Rundgänge. Keine zweite Sicherheit.",18,Color("c2c3b7"));lead.position=Vector2(88,400);g.menu.add_child(lead)
 var actions:=VBoxContainer.new();actions.position=Vector2(88,466);actions.add_theme_constant_override("separation",10);g.menu.add_child(actions)
 var start: Button=g._button("Neue Nachtschicht",g._new_shift,true);start.custom_minimum_size=Vector2(406,62);start.add_theme_font_override("font",g.title_font);start.add_theme_font_size_override("font_size",27);actions.add_child(start)
 var resume: Button=g._button("Schicht fortsetzen",g._continue);resume.disabled=not g._can_continue();resume.custom_minimum_size=Vector2(406,62);resume.add_theme_font_override("font",g.title_font);resume.add_theme_font_size_override("font_size",27);actions.add_child(resume)
 var gap:=Control.new();gap.custom_minimum_size.y=12;actions.add_child(gap)
 for item in [["Einstellungen",func():g._settings("menu")],["Dienstanweisung",func():g._help("menu")],["Mitwirkende",func():credits(g)],["Zur Webseite" if OS.has_feature("web") else "Spiel beenden",g._quit]]:
  var button: Button=g._button(item[0],item[1]);button.custom_minimum_size=Vector2(406,48);button.add_theme_font_override("font",g.title_font);button.add_theme_font_size_override("font_size",27)
  var plain:=StyleBoxEmpty.new();plain.content_margin_left=8;plain.content_margin_top=6;plain.content_margin_bottom=6;button.add_theme_stylebox_override("normal",plain);actions.add_child(button)
 var hint: Label=g._label("WASD · Maus · E",15,Color("a3aaa2"));hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);hint.offset_left=88;hint.offset_right=420;hint.offset_top=-70;hint.offset_bottom=-40;g.menu.add_child(hint)
 var version: Label=g._label("v2.1.0",15,Color("a3aaa2"));version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);version.offset_left=-110;version.offset_right=-35;version.offset_top=-70;version.offset_bottom=-35;g.menu.add_child(version)

static func settings(g: Node3D, tab: String="Bild") -> void:
 clear(g);g.settings_tab=tab
 var shade:=ColorRect.new();shade.color=Color(.018,.028,.025,.96);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);g.menu.add_child(shade)
 var title: Label=g._label("Einstellungen",62);title.add_theme_font_override("font",g.title_font);title.position=Vector2(75,55);g.menu.add_child(title)
 var note: Label=g._label("Deine Nachtschicht. Dein Spielgefühl.",17,Color("a3aaa2"));note.position=Vector2(78,140);g.menu.add_child(note)
 var nav:=VBoxContainer.new();nav.position=Vector2(75,218);nav.add_theme_constant_override("separation",14);g.menu.add_child(nav)
 for category in ["Bild","Audio","Steuerung","Spiel"]:
  var chosen: String=category
  var button: Button=g._button(category,func():settings(g,chosen),category==tab);button.custom_minimum_size.x=250;nav.add_child(button)
 var back: Button=g._button("Zurück",g._return_from_panel);back.custom_minimum_size.x=250;nav.add_child(back)
 var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=395;scroll.offset_top=205;scroll.offset_right=-90;scroll.offset_bottom=-75;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;g.menu.add_child(scroll)
 var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",16);scroll.add_child(column)
 var heading: Label=g._label(tab,30);heading.add_theme_font_override("font",g.title_font);column.add_child(heading)
 match tab:
  "Bild":
   slider(g,column,"Helligkeit","brightness",.7,1.8,.05)
   slider(g,column,"Sichtfeld","fov",65,100,1,"°")
   slider(g,column,"Renderauflösung","render_scale",.65,1,.05)
   option(g,column,"Grafikqualität","quality",["Leistung","Standard","Hoch"],[0,1,2])
   toggle(g,column,"Filmkorn","grain")
   option(g,column,"Bildratenlimit","fps",["Unbegrenzt","30 FPS","60 FPS","120 FPS","144 FPS"],[0,30,60,120,144])
   if not OS.has_feature("web"): toggle(g,column,"V-Sync","vsync")
   column.add_child(g._button("Vollbild umschalten",g._fullscreen))
  "Audio":
   slider(g,column,"Lautstärke","volume",0,1,.05)
   slider(g,column,"Raumklang & entfernte Geräusche","ambience",0,1,.05)
   slider(g,column,"Chef-Anruf","voice",0,1,.05)
   column.add_child(g._paragraph("Alle Tonquellen bleiben an die Gesamtlautstärke gebunden. ESC pausiert auch räumliche Geräusche und den Anruf.",16))
  "Steuerung":
   slider(g,column,"Mausempfindlichkeit","sensitivity",.0007,.0045,.0001)
   toggle(g,column,"Maus-Y umkehren","invert_y")
   toggle(g,column,"Kamerabewegung","motion")
   column.add_child(g._paragraph("WASD / Pfeiltasten   Bewegen\nMaus   Umsehen\nUmschalt   Schnell gehen\nLeertaste   Springen / Intro gedrückt überspringen\nC halten   Ducken\nE   Interagieren\nF   Taschenlampe\nG   Aufheben / Loslassen\nLinke Maustaste   Werfen\nTAB   Fundstücke und Zeitungen\nESC   Pause",18))
  "Spiel":
   toggle(g,column,"Fadenkreuz","crosshair")
   toggle(g,column,"Bereichsliste anzeigen","area_list")
   var prank:=CheckButton.new();prank.text="Jumpscares  Off / On";prank.custom_minimum_size.y=60
   prank.toggled.connect(func(_on):g._menu_jump());column.add_child(prank)
   column.add_child(g._paragraph("Der erste Rundgang ist dein Vergleich. 13 richtige Entscheidungen in Folge beenden die Nachtschicht.",18))
 var reset: Button=g._button("Einstellungen zurücksetzen",func():g._reset_settings();settings(g,tab));column.add_child(reset)
 g._telemetry()

static func changed(g: Node3D, key: String, value: Variant) -> void:
 g.settings[key]=value;g._apply_settings();g._write_settings()

static func slider(g: Node3D, parent: VBoxContainer, title: String, key: String, low: float, high: float, step: float, suffix: String="") -> void:
 var label: Label=g._label(title,18);parent.add_child(label)
 var slider:=HSlider.new();slider.set_meta("qa_label",title);slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=float(g.settings[key]);slider.custom_minimum_size=Vector2(500,32)
 var display:=func(v):label.text=title+"   "+("%.4f"%v if key=="sensitivity" else str(roundi(v))+suffix if high>2 else "%d %%"%roundi(v*100))
 display.call(slider.value);slider.value_changed.connect(func(v):display.call(v);changed(g,key,v));parent.add_child(slider)

static func toggle(g: Node3D, parent: VBoxContainer, title: String, key: String) -> void:
 var button:=CheckButton.new();button.text=title;button.button_pressed=bool(g.settings[key]);button.custom_minimum_size.y=48;button.toggled.connect(func(v):changed(g,key,v));parent.add_child(button)

static func option(g: Node3D, parent: VBoxContainer, title: String, key: String, labels: Array, values: Array) -> void:
 parent.add_child(g._label(title,18));var button:=OptionButton.new();button.set_meta("qa_label",title);button.custom_minimum_size.y=46
 for label in labels: button.add_item(label)
 button.selected=maxi(0,values.find(int(g.settings[key])));button.item_selected.connect(func(i):changed(g,key,values[i]));parent.add_child(button)

static func credits(g: Node3D) -> void:
 g.phase="help";g.return_phase="menu"
 var column: VBoxContainer=g._panel("Mitwirkende","After Play · Kinderparadies")
 column.add_child(g._paragraph("Spielwelt, Modelle, Animationen und Spielgestaltung: Aviary / After Play.\n\nAnatomiebasis des Clownkopfs: Infinite von Lee Perry-Smith, bearbeitet, CC BY 3.0.\n\nUmgebungsaufnahmen: Joseph SARDIN / BigSoundBank, CC0. Weitere Asset-Lizenzen und Quellen liegen der Windows-Fassung bei.",18))
 var credit:=RichTextLabel.new();credit.bbcode_enabled=true;credit.fit_content=true;credit.custom_minimum_size.x=440;credit.text="[url=https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf/LeePerrySmith]Kopfmodell und Quelle[/url] · [url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url]";credit.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(credit)
 column.add_child(g._button("Zurück",g._return_from_panel,true));g._telemetry()
