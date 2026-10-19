class_name EndCredits
extends Control

const AUTHOR:="Kyoko"
const IDEA:="einsmarello"
const TESTERS: Array[String]=["einsmarello","__jerry__","gingerbread","Mozart"]
var g: Node3D
var clock:=0.0
var hold:=0.0
var word: Label
var roll: VBoxContainer
var actions: VBoxContainer
var done:=false

func build(game: Node3D) -> void:
 g=game;name="EndCredits";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var black:=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
 word=g._label("ENDE",128);word.add_theme_font_override("font",g.title_font);word.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;word.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);word.modulate.a=0;add_child(word)
 roll=VBoxContainer.new();roll.position=Vector2(120,1100);roll.size.x=1296;roll.add_theme_constant_override("separation",22);add_child(roll)
 _line("AFTER PLAY",88);_line("Ein Spiel von",21,Color("b4aa90"));_line(AUTHOR,61)
 _gap(65);_line("SPIELIDEE · PROGRAMMIERUNG · GESTALTUNG",21,Color("b4aa90"));_line(AUTHOR,45)
 _gap(65);_line("ZUSÄTZLICHE IDEEN UND KONZEPTBEITRÄGE",21,Color("b4aa90"));_line(IDEA,43)
 _gap(65);_line("TESTSPIELER",21,Color("b4aa90"))
 for tester in TESTERS: _line(tester,37)
 _gap(85);_line("Vielen Dank fürs Spielen.",38)
 _gap(65);_line("GODOT ENGINE",23);_line("Asset-Quellen und Lizenzen: Mitwirkende im Hauptmenü und Dateien im Windows-Paket.",17,Color("8a8c83"))
 actions=VBoxContainer.new();actions.position=Vector2(550,425);actions.custom_minimum_size.x=436;actions.add_theme_constant_override("separation",16);actions.hide();add_child(actions)
 actions.add_child(g._button("Neue Nachtschicht",g._new_shift,true));actions.add_child(g._button("Hauptmenü",g._main_menu))
 var hint: Label=g._label("Leertaste halten · Credits überspringen",15,Color("6e736e"));hint.name="SkipHint";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.position=Vector2(400,970);hint.size.x=736;hint.hide();add_child(hint)

func _line(text: String, size: int, color: Color=Color("e8e6da")) -> void:
 var label: Label=g._label(text,size,color);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",g.title_font);roll.add_child(label)

func _gap(height: float) -> void:
 var gap:=Control.new();gap.custom_minimum_size.y=height;roll.add_child(gap)

func tick(delta: float) -> void:
 clock+=delta
 if done: return
 word.modulate.a=clampf((clock-.22)/.38,0,1)*clampf((4.0-clock)/.6,0,1)
 if clock<4: return
 word.hide();roll.position.y=1060-(clock-4)*52
 get_node("SkipHint").show()
 hold=hold+delta if Input.is_action_pressed("jump") and clock>5 else 0.0
 if roll.position.y+roll.size.y< -80 or hold>=1.3: finish_scroll()

func finish_scroll() -> void:
 done=true;roll.hide();word.text="AFTER PLAY";word.modulate.a=1;word.show();word.offset_bottom=-390;actions.show();get_node("SkipHint").hide()

func snapshot() -> Dictionary:
 return {"clock":clock,"stage":"complete" if done else "credits" if clock>=4 else "title" if clock>=.22 else "blackout","end_word":word.text=="ENDE" and word.is_visible_in_tree() and word.modulate.a>.05,"author":AUTHOR,"ideas":IDEA,"testers":TESTERS,"scroll_y":roll.position.y,"done":done}
