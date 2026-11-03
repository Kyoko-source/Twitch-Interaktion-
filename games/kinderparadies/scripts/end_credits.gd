class_name EndCredits
extends Control

const AUTHOR:="Kyoko"
const MUSIC:="res://assets/music-v371/fern-and-feather.mp3"
const IDEA:="einsmarello"
const TESTERS: Array[String]=["einsmarello","__jerry__","gingerbread","Mozart"]
const SECOND_END_HINT:="schau dich für Ende 2 nochmal genauer um in Runde 3,5,8 und 11"
const SECRET_LINE:="Was eine dumme Horror Scheiße, ich bin Weg und Kündige"
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
var afterglow
var ending_number:=2
var secret_line: Label
var escape_audio: AudioStreamPlayer
var car_started:=false
var prepared_afterglow
var preparation_started:=false
var skip_pending:=false
var party_skip_released:=false
var hold_started_at:=-1
var party_started_at:=-1

func build(game: Node3D, number: int=2) -> void:
 g=game;ending_number=clampi(number,1,3);name="EndCredits";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 music=AudioStreamPlayer.new();music.name="CreditsFernAndFeather";music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;music.stream=load(MUSIC);(music.stream as AudioStreamMP3).loop=true;music.bus="Master";music.volume_db=-60;add_child(music)
 black=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
 word=g._label(end_title(),128);word.add_theme_font_override("font",g.title_font);word.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;word.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);word.modulate.a=0;add_child(word)
 if ending_number==3:
  black.color.a=0;word.offset_bottom=-180
  secret_line=g._label(SECRET_LINE,37,Color("d5cbbb"));secret_line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;secret_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;secret_line.position=Vector2(260,570);secret_line.size=Vector2(1400,150);secret_line.modulate.a=0;add_child(secret_line)
  escape_audio=AudioStreamPlayer.new();escape_audio.name="CarLeavingHappyland";escape_audio.stream=load("res://assets/arrival-v330/car-departure.ogg");escape_audio.bus="Master";escape_audio.volume_db=-5;escape_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(escape_audio)
 roll=VBoxContainer.new();roll.position=Vector2(312,1120);roll.size.x=1296;roll.add_theme_constant_override("separation",22);add_child(roll)
 _line("AFTER PLAY",88);_line("Ein Spiel von",21,Color("b4aa90"));_line(AUTHOR,61)
 if ending_number==1:
  _gap(65);_line("Eine weitere Geschichte wartet.",36,Color("cbbb95"));_line(SECOND_END_HINT,30,Color("e0ddd0"))
 _gap(65);_line("SPIELIDEE · PROGRAMMIERUNG · GESTALTUNG",21,Color("b4aa90"));_line(AUTHOR,45)
 _gap(65);_line("ZUSÄTZLICHE IDEEN UND KONZEPTBEITRÄGE",21,Color("b4aa90"));_line(IDEA,43)
 _gap(65);_line("TESTSPIELER",21,Color("b4aa90"))
 for tester in TESTERS: _line(tester,37)
 _gap(85);_line("Vielen Dank fürs Spielen.",38)
 _gap(65);_line("GODOT ENGINE",23);_line("Asset-Quellen und Lizenzen: Mitwirkende im Hauptmenü und Dateien im Windows-Paket.",17,Color("8a8c83"))
 _gap(65);_line("Partymusik",23,Color("b4aa90"));_line(HappylandParty.MUSIC_CREDIT,21)
 _gap(160);_line("Notiz von Kyoko",49,Color("cbbb95"));_gap(28)
 var note: Label=g._label(KYOKO_NOTE,29,Color("e0ddd0"));note.name="KyokoNote";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_constant_override("line_spacing",12);roll.add_child(note)
 _gap(140)
 actions=VBoxContainer.new();actions.position=Vector2(742,465);actions.custom_minimum_size.x=436;actions.add_theme_constant_override("separation",16);actions.hide();add_child(actions)
 actions.add_child(g._button("Neue Nachtschicht",g._request_shift,true));actions.add_child(g._button("Hauptmenü",g._main_menu))
 if ending_number==1:
  var clue: Label=g._label(SECOND_END_HINT,24,Color("cbbb95"));clue.name="SecondEndingHint";clue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;clue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;clue.custom_minimum_size.x=436;actions.add_child(clue)
 var hint: Label=g._label("Leertaste halten · Credits überspringen",15,Color("6e736e"));hint.name="SkipHint";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hint.position=Vector2(1400,32);hint.size.x=470;hint.hide();add_child(hint)
 call_deferred("prepare_last_look")

func prepare_last_look() -> void:
 if preparation_started or done or not is_inside_tree() or g.end_credits!=self or g.phase!="ending":return
 preparation_started=true
 # Yield construction while the end card/credits stay animated and music plays.
 await g._build_world_responsive("none",Callable(),false)
 if not is_inside_tree() or g.end_credits!=self or g.phase!="ending":return
 # Start the normal credit roll and its music before warming the additional
 # cast. Cold WebGL material compilation must not hold the opening end card.
 while ending_number==1 and clock<title_length()+1.:
  await get_tree().process_frame
  if not is_inside_tree() or g.end_credits!=self or g.phase!="ending":return
 var closing=PatrolPartyOutro.new() if ending_number==1 else EndingAfterglow.new()
 await closing.build(g)
 if not is_inside_tree() or g.end_credits!=self or g.phase!="ending":closing.dispose();return
 # Warm only the final camera view, rather than drawing the entire cold venue
 # from the inactive player's camera beneath the opaque end card.
 g.world.show()
 prepared_afterglow=closing
 if skip_pending:_start_last_look()

func _start_last_look() -> void:
 afterglow=prepared_afterglow;prepared_afterglow=null;skip_pending=false
 if afterglow is PatrolPartyOutro:
  party_started_at=Time.get_ticks_msec()
  music.stop();afterglow.start()
  word.text=AfterPlayLanguage.t("Ende 1/3");word.add_theme_font_size_override("font_size",90);word.offset_bottom=0;word.show()
  word.add_theme_color_override("font_color",Color("71486d"));word.add_theme_color_override("font_outline_color",Color("fff5e8"));word.add_theme_constant_override("outline_size",5)
  party_skip_released=not Input.is_action_pressed("jump")
  get_node("SkipHint").text=AfterPlayLanguage.t("Leertaste halten · Feier überspringen");get_node("SkipHint").show()

func wait_prepared() -> void:
 while not prepared_afterglow and not afterglow and not done:
  await get_tree().process_frame

func end_title() -> String:
 return AfterPlayLanguage.t("Geheimes Ende" if ending_number==3 else "ENDE %d/3"%ending_number)

func title_length() -> float:
 return 10. if ending_number==3 else 4.

func _line(text: String, size: int, color: Color=Color("e8e6da")) -> void:
 var label: Label=g._label(text,size,color);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",g.title_font);roll.add_child(label)

func _gap(height: float) -> void:
 var gap:=Control.new();gap.custom_minimum_size.y=height;roll.add_child(gap)

func tick(delta: float) -> void:
 clock+=delta
 if done: return
 if skip_pending:return
 if ending_number==3 and not afterglow:
  black.color.a=smoothstep(0.,.8,clock)
  if clock>=.85 and not car_started:car_started=true;escape_audio.play()
 if afterglow:
  afterglow.tick(delta);black.color.a=afterglow.shade_alpha()
  if afterglow is PatrolPartyOutro:
   if music.playing:music.stop()
   word.modulate.a=(1.-black.color.a)*.94
   if not Input.is_action_pressed("jump"):party_skip_released=true
  else:music.volume_db=-9-51*smoothstep(12.,16.,afterglow.clock)
  var ready_to_skip: bool=afterglow.clock>2 or (afterglow is PatrolPartyOutro and Time.get_ticks_msec()-party_started_at>2000)
  _update_hold(delta,ready_to_skip and (not afterglow is PatrolPartyOutro or party_skip_released))
  if afterglow.finished or hold>=1.3: _finish_afterglow()
  return
 word.modulate.a=clampf((clock-(2.7 if ending_number==3 else .22))/.38,0,1)*clampf((title_length()-clock)/.6,0,1)
 if secret_line:secret_line.modulate.a=word.modulate.a
 if clock<title_length(): return
 if escape_audio:escape_audio.stop()
 if not (afterglow is PatrolPartyOutro) and not music.playing: music.play()
 music.volume_db=linear_to_db(maxf(.001,clampf((clock-title_length())/.8,0,1)*db_to_linear(-9)))
 word.hide();roll.position.y=1120-(clock-title_length())*38
 if secret_line:secret_line.hide()
 get_node("SkipHint").show()
 _update_hold(delta,clock>title_length()+1)
 if roll.position.y+roll.size.y< -80 or hold>=1.3: finish_scroll()

func finish_scroll() -> void:
 if done or afterglow: return
 roll.hide();word.hide();get_node("SkipHint").hide();hold=0;hold_started_at=-1
 if prepared_afterglow:_start_last_look()
 else:skip_pending=true
 if not (afterglow is PatrolPartyOutro) and not music.playing: music.play()

func _update_hold(delta: float,allowed: bool) -> void:
 if not allowed or not Input.is_action_pressed("jump"):
  hold=0.;hold_started_at=-1;return
 if hold_started_at<0:hold_started_at=Time.get_ticks_msec()
 # A slow shader compilation or software-rendered frame must not turn a
 # 1.3-second key hold into a long wait measured in simulation frames.
 hold=maxf(hold+delta,float(Time.get_ticks_msec()-hold_started_at)/1000.)

func _finish_afterglow() -> void:
 # The opaque end card needs no 3D view. Restoring the inactive player camera
 # otherwise renders a cold venue behind it and stalls WebGL before buttons
 # become responsive, even though the celebration has already finished.
 g.world.hide()
 afterglow.dispose();done=true;black.color.a=1;music.stop()
 get_node("SkipHint").hide()
 word.text=end_title();word.add_theme_font_size_override("font_size",128);word.modulate.a=1;word.show();word.offset_bottom=-390;actions.show()
 word.remove_theme_color_override("font_color");word.remove_theme_color_override("font_outline_color");word.remove_theme_constant_override("outline_size")
 if secret_line:
  word.offset_bottom=-610;secret_line.position.y=325;secret_line.modulate.a=1;secret_line.show()

func _exit_tree() -> void:
 if afterglow: afterglow.dispose()
 if prepared_afterglow:prepared_afterglow.dispose()
 if is_instance_valid(music): music.stop()
 if is_instance_valid(escape_audio):escape_audio.stop()

func snapshot() -> Dictionary:
 return {"prepared":prepared_afterglow!=null or afterglow!=null or done,"clock":clock,"stage":"complete" if done else "last_look" if afterglow else "credits" if clock>=title_length() else "title" if clock>=(2.7 if ending_number==3 else .22) else "blackout","end_word":word.text==end_title() and word.is_visible_in_tree() and word.modulate.a>.05,"ending":ending_number,"secret_line":SECRET_LINE if ending_number==3 else "","car":is_instance_valid(escape_audio) and escape_audio.playing,"title":end_title(),"second_end_hint":SECOND_END_HINT if ending_number==1 else "","author":AUTHOR,"ideas":IDEA,"testers":TESTERS,"note":KYOKO_NOTE,"scroll_y":roll.position.y,"done":done,"music":music.playing,"music_track":music.stream.resource_path,"music_gain":music.volume_db,"skip_hold":hold,"skip_released":party_skip_released,"skip_pressed":Input.is_action_pressed("jump"),"afterglow":afterglow.snapshot() if afterglow else {}}
