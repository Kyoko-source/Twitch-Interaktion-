class_name ArchiveUI
extends RefCounted

static func background(g: Node3D, title: String, subtitle: String) -> void:
 NightMenus.clear(g);g.room_audio.stream_paused=true
 var shade:=ColorRect.new();shade.color=Color(.018,.025,.022,.97);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);g.menu.add_child(shade)
 var heading: Label=g._label(title,52);heading.add_theme_font_override("font",g.title_font);heading.position=Vector2(65,35);g.menu.add_child(heading)
 var sub: Label=g._label(subtitle,17,Color("b2b6a5"));sub.position=Vector2(68,111);g.menu.add_child(sub)

static func inventory(g: Node3D, selected: String="") -> void:
 background(g,"Fundstücke","TAB / ESC schließen · Während du liest, steht die Nachtschicht still.")
 var list_scroll:=ScrollContainer.new();list_scroll.position=Vector2(65,180);list_scroll.size=Vector2(370,675);list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;g.menu.add_child(list_scroll)
 var list:=VBoxContainer.new();list.custom_minimum_size.x=345;list.add_theme_constant_override("separation",12);list_scroll.add_child(list)
 var checklist: Button=g._button("Meine Kontrollliste",func():g.archive_selected="checklist";inventory(g,"checklist"),selected=="checklist");checklist.custom_minimum_size=Vector2(345,56);checklist.add_theme_font_size_override("font_size",17);list.add_child(checklist)
 var found:=0
 for id in ArchiveState.PAPERS:
  if id in g.archive.collected: found+=1
 list.add_child(g._label("ZEITUNGEN   %d / 4"%found,20,Color("c6b68d")))
 for id in ArchiveState.ORDER:
  if id in ["casefile","patrol_hint"] and id not in g.archive.collected: continue
  var chosen: String=id;var owned: bool=id in g.archive.collected
  var title: String=ArchiveState.document(id).title if owned else "Zettel · nicht gefunden" if id=="note" else "Zeitung %d · nicht gefunden"%(ArchiveState.PAPERS.find(id)+1)
  var button: Button=g._button(title,func():g.archive_selected=chosen;inventory(g,chosen),selected==id);button.custom_minimum_size=Vector2(345,56);button.disabled=not owned;button.add_theme_font_size_override("font_size",17);list.add_child(button)
 var gap:=Control.new();gap.custom_minimum_size.y=20;list.add_child(gap)
 var equipment: Button=g._button("Meine Ausrüstung",func():g._equipment_card());equipment.custom_minimum_size.x=345;list.add_child(equipment)
 var help: Button=g._button("Dienstanweisung",func():g._help("inventory"));help.custom_minimum_size.x=345;list.add_child(help)
 var back: Button=g._button("Zurück zum Zahlenschloss" if g.inventory_back=="code" else "Zurück ins Spiel",g._archive_back);back.custom_minimum_size.x=345;list.add_child(back)
 var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=455;panel.offset_top=170;panel.offset_right=-65;panel.offset_bottom=-45
 var paper:=StyleBoxTexture.new();paper.texture=load("res://assets/story/paper.png");paper.set_content_margin_all(40);panel.add_theme_stylebox_override("panel",paper);g.menu.add_child(panel)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var article:=VBoxContainer.new();article.add_theme_constant_override("separation",22);article.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(article)
 var current:=selected
 if current!="checklist" and current not in g.archive.collected: current=g.archive.collected[0] if not g.archive.collected.is_empty() else "checklist"
 if current=="checklist":
  g.archive_selected="checklist"
  var notebook:=PatrolNotebook.new();notebook.name="PatrolNotebook";notebook.visited.assign(g.state.visited);notebook.round_number=mini(13,g.state.streak+1);notebook.finished=g.state.completed;notebook.custom_minimum_size=Vector2(900,760);notebook.size_flags_horizontal=Control.SIZE_EXPAND_FILL;article.add_child(notebook)
 else:
  g.archive_selected=current
  var doc:=ArchiveState.document(current)
  if current in ArchiveState.PAPERS:
   var scan:=TextureRect.new();scan.name="NewspaperScan";scan.texture=load("res://assets/story/"+current+".png");scan.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;scan.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;scan.custom_minimum_size.y=1180;scan.size_flags_horizontal=Control.SIZE_EXPAND_FILL;article.add_child(scan)
   article.add_child(g._label("LESEFASSUNG",15,Color("6e5a39")))
  if current=="note":
   var handwritten:=TextureRect.new();handwritten.name="HandwrittenNote";handwritten.texture=load("res://assets/story/note.png");handwritten.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;handwritten.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;handwritten.custom_minimum_size.y=1100;handwritten.size_flags_horizontal=Control.SIZE_EXPAND_FILL;article.add_child(handwritten)
  else:
   var section: Label=g._label(doc.section,15,Color("6e5a39"));article.add_child(section)
   var headline: Label=g._label(doc.headline,39,Color("29271f"));headline.add_theme_font_override("font",g.title_font);headline.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;article.add_child(headline)
   var rule:=HSeparator.new();article.add_child(rule)
   var body:=RichTextLabel.new();body.text=doc.body;body.fit_content=true;body.scroll_active=false;body.add_theme_color_override("default_color",Color("312e24"));body.add_theme_font_size_override("normal_font_size",23);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;article.add_child(body)
   var footer: Label=g._paragraph(doc.footer,17);footer.custom_minimum_size.x=0;footer.add_theme_color_override("font_color",Color("716044"));article.add_child(footer)
 g._telemetry()

static func keypad(g: Node3D, message: String="") -> void:
 background(g,"Zahlenschloss","Vier Stellen. Keine Namen. Nur die Spuren, die zurückgeblieben sind.")
 var column:=VBoxContainer.new();column.position=Vector2(65,185);column.custom_minimum_size.x=420;column.add_theme_constant_override("separation",14);g.menu.add_child(column)
 var input:=LineEdit.new();input.name="ArchiveCodeInput";input.placeholder_text="– – – –";input.max_length=4;input.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER;input.custom_minimum_size=Vector2(420,68);input.add_theme_font_size_override("font_size",34);input.alignment=HORIZONTAL_ALIGNMENT_CENTER;input.text=g.archive_input;column.add_child(input)
 input.text_changed.connect(func(text):
  var digits:=""
  for c in text:
   if c in "0123456789": digits+=c
  if digits!=text: input.text=digits;input.caret_column=digits.length()
  g.archive_input=digits)
 input.text_submitted.connect(func(_text):g._submit_archive_code())
 var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);column.add_child(grid)
 for key in ["1","2","3","4","5","6","7","8","9","Löschen","0","Prüfen"]:
  var chosen: String=key
  var button: Button=g._button(key,func():
   if chosen=="Prüfen": g._submit_archive_code();return
   if chosen=="Löschen": input.text=input.text.left(maxi(0,input.text.length()-1))
   elif input.text.length()<4: input.text+=chosen
   g.archive_input=input.text)
  button.custom_minimum_size=Vector2(132,58);button.alignment=HORIZONTAL_ALIGNMENT_CENTER;grid.add_child(button)
 var result: Label=g._paragraph(message,18);result.custom_minimum_size.x=420;result.add_theme_color_override("font_color",Color("d3ad82"));column.add_child(result)
 column.add_child(g._button("Fundstücke ansehen",func():g._inventory("code")))
 column.add_child(g._button("Zurück ins Spiel",g._resume))
 var text: Label=g._paragraph("Der Zettel an der Tür spricht vom Anfang, von den Verlorenen, von ihren Rufen und von der Zeit des Wartens.\n\nLies deine gesammelten Zeitungen. Jede hinterlässt einen Teil der Geschichte.",24);text.position=Vector2(620,220);text.custom_minimum_size.x=660;text.size.x=660;g.menu.add_child(text)
 input.grab_focus();g._telemetry()
