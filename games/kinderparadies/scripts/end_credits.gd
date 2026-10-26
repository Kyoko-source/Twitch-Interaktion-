class_name EndCredits
extends Control

const AUTHOR:="Kyoko"
const IDEA:="einsmarello"
const TESTERS: Array[String]=["einsmarello","__jerry__","gingerbread","Mozart"]
const KYOKO_NOTE:="Vielen Dank fürs spielen meines Projektes. Du musst wissen, ich bin kein Spieleentwickler oder Software Designer.\n\nDas Spiel After Play war eine Idee von mir als die Anomalie Spiele groß im Hype waren.\n\nZudem Zeitpunkt wusste ich nur noch nichts von der erstellung solcher Spiele.\nMonatelanges lernen/verstehen und umsetzen folgten und mit viel Hilfe guter Freunde, Online Assets Bibliotheken und KI erstellten Inhalten wie Bilder und Musik konnte ich nach Monatelanger entwicklung mein erstes Spiel herausbringen.\n\nEs ist nicht perfekt und auch nicht Fehlerfrei gestaltet aber der erste Meilenstein für mich selber in der Entwicklung meines ersten eigenen Games."
var g: Node3D
var clock:=0.0
var hold:=0.0
var word: Label
var roll: VBoxContainer
var actions: VBoxContainer
var done:=false
var music: AudioStreamPlayer
var black: ColorRect
var afterglow: EndingAfterglow

func build(game: Node3D) -> void:
 g=game;name="EndCredits";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 music=AudioStreamPlayer.new();music.name="CreditsMusicBox";music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;music.stream=load(RoomHorror.MUSIC);(music.stream as AudioStreamMP3).loop=true;music.bus="Master";music.volume_db=-60;add_child(music)
 black=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
 word=g._label("ENDE",128);word.add_theme_font_override("font",g.title_font);word.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;word.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);word.modulate.a=0;add_child(word)
 roll=VBoxContainer.new();roll.position=Vector2(312,1120);roll.size.x=1296;roll.add_theme_constant_override("separation",22);add_child(roll)
 _line("AFTER PLAY",88);_line("Ein Spiel von",21,Color("b4aa90"));_line(AUTHOR,61)
 _gap(65);_line("SPIELIDEE · PROGRAMMIERUNG · GESTALTUNG",21,Color("b4aa90"));_line(AUTHOR,45)
 _gap(65);_line("ZUSÄTZLICHE IDEEN UND KONZEPTBEITRÄGE",21,Color("b4aa90"));_line(IDEA,43)
 _gap(65);_line("TESTSPIELER",21,Color("b4aa90"))
 for tester in TESTERS: _line(tester,37)
 _gap(85);_line("Vielen Dank fürs Spielen.",38)
 _gap(65);_line("GODOT ENGINE",23);_line("Asset-Quellen und Lizenzen: Mitwirkende im Hauptmenü und Dateien im Windows-Paket.",17,Color("8a8c83"))
 _gap(160);_line("Notiz von Kyoko",49,Color("cbbb95"));_gap(28)
 var note: Label=g._label(KYOKO_NOTE,29,Color("e0ddd0"));note.name="KyokoNote";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_constant_override("line_spacing",12);roll.add_child(note)
 _gap(140)
 actions=VBoxContainer.new();actions.position=Vector2(742,465);actions.custom_minimum_size.x=436;actions.add_theme_constant_override("separation",16);actions.hide();add_child(actions)
 actions.add_child(g._button("Neue Nachtschicht",g._new_shift,true));actions.add_child(g._button("Hauptmenü",g._main_menu))
 var hint: Label=g._label("Leertaste halten · Credits überspringen",15,Color("6e736e"));hint.name="SkipHint";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hint.position=Vector2(1400,32);hint.size.x=470;hint.hide();add_child(hint)

func _line(text: String, size: int, color: Color=Color("e8e6da")) -> void:
 var label: Label=g._label(text,size,color);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",g.title_font);roll.add_child(label)

func _gap(height: float) -> void:
 var gap:=Control.new();gap.custom_minimum_size.y=height;roll.add_child(gap)

func tick(delta: float) -> void:
 clock+=delta
 if done: return
 if afterglow:
  afterglow.tick(delta);black.color.a=afterglow.shade_alpha()
  music.volume_db=-9-51*smoothstep(12.,16.,afterglow.clock)
  hold=hold+delta if Input.is_action_pressed("jump") and afterglow.clock>2 else 0.0
  if afterglow.finished or hold>=1.3: _finish_afterglow()
  return
 word.modulate.a=clampf((clock-.22)/.38,0,1)*clampf((4.0-clock)/.6,0,1)
 if clock<4: return
 if not music.playing: music.play()
 music.volume_db=linear_to_db(maxf(.001,clampf((clock-4)/.8,0,1)*db_to_linear(-9)))
 word.hide();roll.position.y=1120-(clock-4)*38
 get_node("SkipHint").show()
 hold=hold+delta if Input.is_action_pressed("jump") and clock>5 else 0.0
 if roll.position.y+roll.size.y< -80 or hold>=1.3: finish_scroll()

func finish_scroll() -> void:
 if done or afterglow: return
 roll.hide();word.hide();get_node("SkipHint").hide();hold=0
 afterglow=EndingAfterglow.new();afterglow.build(g)
 if not music.playing: music.play()

func _finish_afterglow() -> void:
 afterglow.dispose();done=true;black.color.a=1;music.stop()
 word.text="AFTER PLAY";word.modulate.a=1;word.show();word.offset_bottom=-390;actions.show()

func _exit_tree() -> void:
 if afterglow: afterglow.dispose()
 if is_instance_valid(music): music.stop()

func snapshot() -> Dictionary:
 return {"clock":clock,"stage":"complete" if done else "last_look" if afterglow else "credits" if clock>=4 else "title" if clock>=.22 else "blackout","end_word":word.text=="ENDE" and word.is_visible_in_tree() and word.modulate.a>.05,"author":AUTHOR,"ideas":IDEA,"testers":TESTERS,"note":KYOKO_NOTE,"scroll_y":roll.position.y,"done":done,"music":music.playing,"music_track":music.stream.resource_path,"music_gain":music.volume_db,"afterglow":afterglow.snapshot() if afterglow else {}}
