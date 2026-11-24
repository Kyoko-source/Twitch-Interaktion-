class_name NightMenus
extends RefCounted

# Native controls over the real room, never a baked screenshot of the interface.
static func clear(g: Node3D) -> void:
 for child in g.menu.get_children(): g.menu.remove_child(child);child.queue_free()
 g.menu.show();g.hud.hide();g.player.release();g.world.atmosphere.set_active(false)

static func menu_font(weight: int=500, spacing: int=0) -> FontVariation:
 var font:=FontVariation.new();font.base_font=load("res://assets/presentation-v250/BodoniModa.ttf");font.variation_opentype={"wght":weight,"opsz":72};font.spacing_glyph=spacing;return font

static func backdrop(g: Node3D, darken: bool=false) -> void:
 # The visible backdrop is the actual playable 3D room and mascot. Only the
 # navigation edge is shaded; no idealised illustration promises other assets.
 var edge:=ColorRect.new();edge.name="CinematicMenuBackground";edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);edge.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.menu.add_child(edge)
 var shader:=Shader.new();shader.code="shader_type canvas_item;void fragment(){float edge=1.0-smoothstep(.14,.56,UV.x);COLOR=vec4(vec3(.012,.017,.014),edge*.86);}"
 var material:=ShaderMaterial.new();material.shader=shader;edge.material=material
 if darken:
  var shade:=ColorRect.new();shade.color=Color(.025,.033,.028,.94);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.menu.add_child(shade)

static func nav_style(selected: bool, hovered: bool=false, compact: bool=false) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color(.21,.17,.09,.45) if selected or hovered else Color.TRANSPARENT;style.border_width_left=3 if selected or hovered else 0;style.border_color=Color("b6a16d");style.content_margin_left=27;style.content_margin_right=20;style.content_margin_top=0 if compact else 5;style.content_margin_bottom=0 if compact else 5;return style

static func multiplayer(g: Node3D) -> void:
 # Player 2 joins on the website with this code and plans all 13 rounds.
 g.phase="multiplayer";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.position=Vector2(110,150);column.custom_minimum_size=Vector2(900,0);column.add_theme_constant_override("separation",22);g.menu.add_child(column)
 var title: Label=g._label("MULTIPLAYER",64,Color("e8e1c8"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 column.add_child(g._paragraph("Spieler 2 öffnet auf der Webseite unter Spiele → After Play den Reiter „After Play Multiplayer“ und gibt diesen Code ein. Er legt für alle 13 Runden fest, welche Anomalie passiert, und verfolgt dich danach live auf einer Karte.",21))
 var code_label: Label=g._label("······",128,Color("eee5cf"));code_label.name="MultiplayerCode";code_label.add_theme_font_override("font",menu_font(600,18));column.add_child(code_label)
 var status_label: Label=g._label("",24,Color("cbbb95"));status_label.name="MultiplayerStatus";column.add_child(status_label)
 var site: Label=g._label("62.238.49.219  ·  Spiele  ·  After Play  ·  After Play Multiplayer",18,Color("8f8c80"));column.add_child(site)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);column.add_child(row)
 var retry: Button=g._button("Neuen Code holen",func():g.mp.start());retry.custom_minimum_size=Vector2(320,56);row.add_child(retry)
 var back: Button=g._button("Abbrechen",func():g.mp.stop();g._main_menu(),true);back.custom_minimum_size=Vector2(260,56);row.add_child(back)
 var refresh:=func():
  if not is_instance_valid(code_label):return
  code_label.text=(g.mp.code.substr(0,3)+" "+g.mp.code.substr(3)) if g.mp.code.length()==6 else "······"
  status_label.text=AfterPlayLanguage.t(g.mp.message)
  status_label.add_theme_color_override("font_color",Color("d98c7e") if g.mp.status=="error" else Color("cbbb95"))
 for connection in g.mp.changed.get_connections():g.mp.changed.disconnect(connection.callable)
 g.mp.changed.connect(refresh)
 if not g.mp.active():g.mp.start()
 refresh.call();back.grab_focus();g._telemetry()

# Endless mode: start a new run or continue the saved one.
static func endless(g: Node3D) -> void:
 g.phase="endless";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="EndlessMenu";column.position=Vector2(110,140);column.custom_minimum_size=Vector2(900,0);column.add_theme_constant_override("separation",20);g.menu.add_child(column)
 var title: Label=g._label("ENDLOSMODUS",64,Color("e8e1c8"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 column.add_child(g._paragraph("Bis zu 500 Rundgänge mit drei Leben. Am Anfang sind die Anomalien laut und groß, mit jeder Runde werden sie leiser und kleiner, bis nur noch winzige Details verändert sind. Ab Runde 15 hast du für jede Runde fünf Minuten. Eine falsche Tür, das Pferd oder die abgelaufene Zeit kosten ein Leben.",21))
 var record: Label=g._label("Bester Lauf: Runde %d  ·  Erfolge: %d / %d"%[g.achievements.best_round,g.achievements.unlocked.size(),AfterPlayAchievements.LIST.size()],20,Color("cbbb95"));column.add_child(record)
 var info: Dictionary=g.endless_save_info()
 var first: Button
 if not info.is_empty():
  first=g._button("Lauf fortsetzen · Runde %d · %d Leben"%[info.round,info.lives],g._continue_endless,true);first.name="EndlessContinue";first.custom_minimum_size=Vector2(560,56);column.add_child(first)
 var start: Button=g._button("Neuen Lauf starten",g._start_endless,info.is_empty());start.name="EndlessStart";start.custom_minimum_size=Vector2(560,56);column.add_child(start)
 var list: Button=g._button("Erfolge",func():g.achievements.show_menu(func():endless(g)));list.custom_minimum_size=Vector2(560,56);column.add_child(list)
 var back: Button=g._button("Zurück",g._main_menu);back.custom_minimum_size=Vector2(560,56);column.add_child(back)
 (first if first else start).grab_focus();g._telemetry()

static func endless_summary(g: Node3D, won: bool) -> void:
 g.phase="endless_over";clear(g);backdrop(g,true)
 g.player.lamp.hide();g.room_audio.stop()
 var column:=VBoxContainer.new();column.name="EndlessSummary";column.position=Vector2(110,180);column.custom_minimum_size=Vector2(900,0);column.add_theme_constant_override("separation",22);g.menu.add_child(column)
 var title: Label=g._label("500 RUNDEN" if won else "LAUF BEENDET",72,Color("e8e1c8"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 var reached: int=PatrolState.ENDLESS_GOAL if won else g.state.round_number()
 column.add_child(g._paragraph(("Du hast alle 500 Rundgänge überstanden. Happyland hat keine Anomalien mehr für dich." if won else "Du bist bis Runde %d gekommen. %d Runden geschafft, %d Fehler."%[reached,g.state.streak,g.state.errors]),24))
 column.add_child(g._label("Bester Lauf: Runde %d"%g.achievements.best_round,22,Color("cbbb95")))
 var again: Button=g._button("Neuen Lauf starten",g._start_endless,true);again.name="EndlessAgain";again.custom_minimum_size=Vector2(560,56);column.add_child(again)
 var menu_button: Button=g._button("Hauptmenü",g._main_menu);menu_button.custom_minimum_size=Vector2(560,56);column.add_child(menu_button)
 again.grab_focus();g._telemetry()

# Nightwatch Protocol: rules, the nights, start.
static func nightwatch(g: Node3D) -> void:
 g.phase="nightwatch_menu";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="NightwatchMenu";column.position=Vector2(110,120);column.custom_minimum_size=Vector2(980,0);column.add_theme_constant_override("separation",18);g.menu.add_child(column)
 var title: Label=g._label("NIGHTWATCH PROTOCOL",60,Color("e8e1c8"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 column.add_child(g._paragraph("Du sitzt von 00:00 bis 06:00 Uhr im Kontrollraum unter Happyland. Auf den zehn Kameras verändern sich die Räume: Dinge fehlen, schweben, stehen falsch, ein Raum ist ganz anders. Öffne die Kamera im Vollbild und klick mit links auf die Veränderung – dann ist alles wieder normal.",21))
 column.add_child(g._paragraph("Bleiben zu viele Veränderungen offen, oder eine zu lange, startet der kritische Alarm. Wird er nicht gestoppt, ist die Nacht verloren.",19))
 var threats: Label=g._paragraph("Schau immer wieder links zur Tür und rechts in den Lüftungsschacht (Pfeile am Bildrand oder A / D). Steht etwas an der Tür: Rolltor runter (Leertaste, 20 % Strom). Sitzt etwas im Schacht: mit der Taschenlampe hineinleuchten (F, 10 % Strom). Zu langsam – und es erwischt dich. Reicht der Strom nicht, tipp am Generator die Wörter.",19)
 threats.add_theme_color_override("font_color",Color("e8a090"));column.add_child(threats)
 var best: Label=g._label("Geschafft: Nacht %d von %d  ·  Längste Schicht: %02d:%02d"%[g.achievements.nightwatch_night,NightwatchConfig.NIGHTS,int(g.achievements.nightwatch_time)/60,int(g.achievements.nightwatch_time)%60],21,Color("cbbb95"));best.name="NightwatchHighscore";column.add_child(best)
 var next:=mini(g.achievements.nightwatch_night+1,NightwatchConfig.NIGHTS)
 var start: Button=g._button("Nacht %d beginnen"%next,g._start_nightwatch.bind(next),true);start.name="NightwatchStart";start.custom_minimum_size=Vector2(560,56);column.add_child(start)
 # Every night survived (and the next one) can be played again.
 var row:=HBoxContainer.new();row.name="NightwatchNights";row.add_theme_constant_override("separation",10);column.add_child(row)
 for n in range(1,NightwatchConfig.NIGHTS+1):
  var pick: Button=g._button("Nacht %d"%n,g._start_nightwatch.bind(n));pick.name="NightwatchNight%d"%n;pick.custom_minimum_size=Vector2(150,48)
  pick.disabled=n>g.achievements.nightwatch_night+1;row.add_child(pick)
 var back: Button=g._button("Zurück",g._main_menu);back.custom_minimum_size=Vector2(560,56);column.add_child(back)
 start.grab_focus();g._telemetry()

static func nightwatch_summary(g: Node3D, r: Dictionary) -> void:
 g.phase="nightwatch_over";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="NightwatchSummary";column.position=Vector2(110,110);column.custom_minimum_size=Vector2(980,0);column.add_theme_constant_override("separation",14);g.menu.add_child(column)
 var title: Label=g._label(str(r.title),70,Color("e8a08c"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 if r.new_best:
  var best: Label=g._label("NACHT %d FREIGESCHALTET!"%mini(int(r.night)+1,NightwatchConfig.NIGHTS) if int(r.night)<NightwatchConfig.NIGHTS else "ALLE FÜNF NÄCHTE ÜBERSTANDEN!",30,Color("f0d27a"));best.name="NightwatchNewBest";best.add_theme_font_override("font",menu_font(600,2));column.add_child(best)
 var rows:=[["Nacht","%d"%r.night],["Uhrzeit erreicht",str(r.clock)],["Anomalien behoben","%d"%r.fixed],["Fehlklicks","%d"%r.misses],["An der Tür abgewehrt","%d"%r.door],["Aus dem Schacht verscheucht","%d"%r.vent],["Hase zurückgeschickt","%d"%int(r.get("bunny",0))],["Generator-Neustarts","%d erfolgreich · %d fehlgeschlagen"%[r.repairs,r.failed_repairs]],["Strom übrig","%d %%"%ceili(float(r.power))]]
 var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",40);grid.add_theme_constant_override("v_separation",6);column.add_child(grid)
 for row in rows:
  grid.add_child(g._label(row[0],22,Color("bac6c0")))
  grid.add_child(g._label(row[1],22,Color("eee7d6")))
 var next_night:=mini(int(r.night)+1,NightwatchConfig.NIGHTS) if r.won else int(r.night)
 var again: Button=g._button(("Nacht %d beginnen" if r.won and int(r.night)<NightwatchConfig.NIGHTS else "Nacht %d wiederholen")%next_night,g._start_nightwatch.bind(next_night),true);again.name="NightwatchAgain";again.custom_minimum_size=Vector2(560,56);column.add_child(again)
 var menu_button: Button=g._button("Hauptmenü",g._main_menu);menu_button.custom_minimum_size=Vector2(560,56);column.add_child(menu_button)
 again.grab_focus();g._telemetry()

# 5.1.1: the extra modes live one click deeper.
const MODES:=[
 ["endless","Endlosmodus","Bis zu 500 Rundgänge mit drei Leben. Die Anomalien werden immer kleiner."],
 ["nightwatch","Nightwatch Protocol (Beta)","Fünf Nächte im Kontrollraum: Anomalien auf zehn Kameras, eine Tür, ein Schacht und Strom, der bis 06:00 reichen muss."],
 ["zombies","Partynacht","Runde um Runde gegen die Partykinder. Waffen, Perks, Bosse und Chaos."],
 ["multiplayer","Multiplayer","Ein zweiter Spieler plant auf der Webseite deine dreizehn Runden."],
]
static func modes(g: Node3D) -> void:
 g.phase="modes";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="ModesMenu";column.position=Vector2(110,120);column.custom_minimum_size=Vector2(980,0);column.add_theme_constant_override("separation",14);g.menu.add_child(column)
 var title: Label=g._label("WEITERE SPIELMODI",62,Color("e8e1c8"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 var spacer:=Control.new();spacer.custom_minimum_size.y=12;column.add_child(spacer)
 var first: Button
 for row in MODES:
  var id: String=row[0]
  var button: Button=g._button(row[1],func():open_mode(g,id),id=="zombies");button.name="Mode_"+id;button.custom_minimum_size=Vector2(620,56);column.add_child(button)
  var line: Label=g._label(row[2],17,Color("a9a796"));line.add_theme_font_override("font",menu_font());column.add_child(line)
  if id in LOCKED_MODES:lock_mode(g,button,line)
  if first==null:first=button
 var gap:=Control.new();gap.custom_minimum_size.y=16;column.add_child(gap)
 var back: Button=g._button("Zurück",g._main_menu);back.name="ModesBack";back.custom_minimum_size=Vector2(620,56);column.add_child(back)
 first.grab_focus();g._telemetry()

# 5.2.4: modes still being built stay visible but greyed out; hovering says so.
# 5.5.0: Nightwatch Protocol is open as a beta.
const LOCKED_MODES:=[]
static func lock_mode(g: Node3D, button: Button, line: Label) -> void:
 button.disabled=true;button.focus_mode=Control.FOCUS_NONE;button.tooltip_text="In Development";button.mouse_default_cursor_shape=Control.CURSOR_FORBIDDEN
 var grey: StyleBoxFlat=g._style(Color(.06,.06,.06,.55),Color("3a3a36"))
 button.add_theme_stylebox_override("disabled",grey);button.add_theme_color_override("font_disabled_color",Color("6c6b62"))
 line.modulate=Color(1,1,1,.45)
 var text:=line.text
 button.mouse_entered.connect(func():line.text="In Development";line.modulate=Color(1,1,1,.9))
 button.mouse_exited.connect(func():line.text=text;line.modulate=Color(1,1,1,.45))

static func open_mode(g: Node3D, id: String) -> void:
 match id:
  "endless":endless(g)
  "nightwatch":
   if not "nightwatch" in LOCKED_MODES:nightwatch(g)
  "zombies":zombies(g)
  "multiplayer":multiplayer(g)

# Partynacht: the wave survival mode.
static func zombies(g: Node3D) -> void:
 g.phase="zombies_menu";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="ZombiesMenu";column.position=Vector2(110,110);column.custom_minimum_size=Vector2(1000,0);column.add_theme_constant_override("separation",16);g.menu.add_child(column)
 var title: Label=g._label("PARTYNACHT",72,Color("e8a08c"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 column.add_child(g._paragraph("Die Gäste sind zurück, und sie wollen feiern. Überlebe Runde um Runde gegen die Partykinder, ihre Elitegäste und die Geburtstagsbosse. Mit Punkten öffnest du Absperrungen, kaufst Waffen von den Wänden, Munition an den Kisten, Perks an den verdorbenen Automaten, ziehst Waffen aus dem Chaos-Geschenk und veredelst sie in der Fleischmaschine.",20))
 column.add_child(g._paragraph("Linke Maustaste schießen · rechte zielen · R nachladen · V Nahkampf · E kaufen · Mausrad oder 1/2 Waffe wechseln · F Lampe · ESC Pause",18))
 var z: Dictionary=g.achievements.zombies
 var best: Label=g._label("Höchste Runde: %d  ·  Bester Punktestand: %d  ·  Kills gesamt: %d  ·  Kopftreffer: %d  ·  Bosse: %d"%[int(z.best_round),int(z.best_points),int(z.kills),int(z.headshots),int(z.bosses)],19,Color("cbbb95"));best.name="ZombiesRecords";column.add_child(best)
 var start: Button=g._button("Partynacht beginnen",g._start_zombies,true);start.name="ZombiesStart";start.custom_minimum_size=Vector2(560,56);column.add_child(start)
 var back: Button=g._button("Zurück",g._main_menu);back.custom_minimum_size=Vector2(560,56);column.add_child(back)
 start.grab_focus();g._telemetry()

static func zombies_summary(g: Node3D, r: Dictionary) -> void:
 g.phase="zombies_over";clear(g);backdrop(g,true)
 var column:=VBoxContainer.new();column.name="ZombiesSummary";column.position=Vector2(110,100);column.custom_minimum_size=Vector2(1000,0);column.add_theme_constant_override("separation",12);g.menu.add_child(column)
 var title: Label=g._label("DIE FEIER IST VORBEI",66,Color("e8a08c"));title.add_theme_font_override("font",menu_font(500,3));column.add_child(title)
 if r.get("new_best",false):
  var best: Label=g._label("NEUER REKORD!",30,Color("f0d27a"));best.name="ZombiesNewBest";best.add_theme_font_override("font",menu_font(600,2));column.add_child(best)
 var rows:=[["Erreichte Runde","%d"%int(r.round)],["Punkte","%d"%int(r.points)],["Kills","%d"%int(r.kills)],["Kopftreffer","%d"%int(r.headshots)],["Elitegäste","%d"%int(r.elites)],["Bosse besiegt","%d"%int(r.bosses)],["Überlebt","%02d:%02d"%[int(r.seconds)/60,int(r.seconds)%60]],["Pickups","%d"%int(r.pickups)],["Perks","%d"%int(r.perks)],["Höchste Runde bisher","%d"%int(g.achievements.zombies.best_round)]]
 var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",40);grid.add_theme_constant_override("v_separation",5);column.add_child(grid)
 for row in rows:
  grid.add_child(g._label(row[0],22,Color("bac6c0")));grid.add_child(g._label(row[1],22,Color("eee7d6")))
 var again: Button=g._button("Neue Partynacht",g._start_zombies,true);again.name="ZombiesAgain";again.custom_minimum_size=Vector2(560,56);column.add_child(again)
 var menu_button: Button=g._button("Hauptmenü",g._main_menu);menu_button.custom_minimum_size=Vector2(560,56);column.add_child(menu_button)
 again.grab_focus();g._telemetry()

static func home(g: Node3D) -> void:
 clear(g);backdrop(g)
 var heading: Label=g._label("AFTER PLAY",220,Color("e8e1c8"));heading.add_theme_font_override("font",menu_font(500,4));heading.position=Vector2(90,54);heading.scale.x=.44;g.menu.add_child(heading)
 var ink:=Shader.new();ink.code="shader_type canvas_item;void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR;float n=fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453);c.a*=step(.07,n);COLOR=c;}";var print_material:=ShaderMaterial.new();print_material.shader=ink;heading.material=print_material
 var subtitle: Label=g._label("Kinderparadies",28,Color("d9d0b5"));subtitle.add_theme_font_override("font",menu_font(400,7));subtitle.position=Vector2(207,325);g.menu.add_child(subtitle)
 var lead: Label=g._label("Dreizehn Rundgänge. Keine zweite Sicherheit.",20,Color("c9c4b1"));lead.add_theme_font_override("font",menu_font(500,1));lead.position=Vector2(100,420);g.menu.add_child(lead)
 var items: Array=[["Neue Nachtschicht",g._request_shift],["Schicht fortsetzen",g._continue_shift],["Weitere Spielmodi",func():modes(g)],["Einstellungen",func():g._settings("menu")],["Erinnerungsalbum",func():g.album.show_menu()],["Anomalie-Album",func():g.anomaly_album.show_menu(func():home(g))],["Erfolge",func():g.achievements.show_menu(func():home(g))],["Mitwirkende",func():credits(g)],["Zur Webseite" if OS.has_feature("web") else "Spiel beenden",g._quit]]
 # 4.15.0: the ways to play stay large; everything else sits smaller and
 # quieter below a thin rule. Without a save there is no dead
 # "Schicht fortsetzen" line (the other actions keep their numbers).
 var y:=470.
 for i in range(items.size()):
  var primary:=i<3
  if i==1 and not g._can_continue_shift():continue
  if i==3:
   var rule:=ColorRect.new();rule.name="MainMenuRule";rule.color=Color(.71,.63,.43,.6);rule.position=Vector2(127,y+10);rule.size=Vector2(220,1);rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.menu.add_child(rule);y+=26
  var button: Button=g._button(items[i][0],items[i][1]);button.name="MainMenuAction"+str(i)
  button.add_theme_font_override("font",menu_font(500,1));button.add_theme_font_size_override("font_size",29 if primary else 20)
  button.add_theme_stylebox_override("normal",nav_style(false,false,not primary));button.add_theme_stylebox_override("hover",nav_style(true,true,not primary));button.add_theme_stylebox_override("pressed",nav_style(true,true,not primary));button.add_theme_stylebox_override("disabled",nav_style(false,false,not primary));button.add_theme_stylebox_override("focus",nav_style(false,true,not primary))
  var label_ink:=Color("e8e1c8") if primary else Color("b3ae9c")
  for state in ["font_color","font_pressed_color"]: button.add_theme_color_override(state,label_ink)
  for state in ["font_hover_color","font_focus_color"]: button.add_theme_color_override(state,Color("f1ead3"))
  button.add_theme_color_override("font_disabled_color",Color("77786f"))
  button.custom_minimum_size=Vector2(540 if primary else 420,0);g.menu.add_child(button)
  var height:=maxf(52. if primary else 34.,button.get_combined_minimum_size().y)
  button.position=Vector2(100,y);button.size=Vector2(button.custom_minimum_size.x,height)
  y+=height+(2. if primary else 1.)
 # Below the minimum requirements: say so plainly, change nothing.
 var shortfalls:=SystemCheck.issues("--system-check-preview" in OS.get_cmdline_user_args())
 if not shortfalls.is_empty():
  var advice:=Label.new();advice.name="SystemAdvice";advice.text="
".join(shortfalls.map(func(line):return AfterPlayLanguage.t(line)))
  advice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;advice.add_theme_font_override("font",menu_font());advice.add_theme_font_size_override("font_size",15);advice.add_theme_color_override("font_color",Color("d6b98c"))
  advice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);advice.offset_left=-620;advice.offset_right=-35;advice.offset_top=-110;advice.offset_bottom=-80
  advice.grow_horizontal=Control.GROW_DIRECTION_BEGIN;advice.grow_vertical=Control.GROW_DIRECTION_BEGIN;advice.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;advice.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;g.menu.add_child(advice)
 var version: Label=g._label("v5.6.0",15,Color("aaa994"));version.add_theme_font_override("font",menu_font());version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);version.offset_left=-110;version.offset_right=-35;version.offset_top=-65;version.offset_bottom=-35;g.menu.add_child(version)

static func settings(g: Node3D, tab: String="Bild") -> void:
 clear(g);g.settings_tab=tab
 backdrop(g,true)
 var title: Label=g._label("Einstellungen",62);title.add_theme_font_override("font",menu_font());title.position=Vector2(75,55);g.menu.add_child(title)
 var note: Label=g._label("Deine Nachtschicht. Dein Spielgefühl.",17,Color("a3aaa2"));note.position=Vector2(78,140);g.menu.add_child(note)
 var nav:=VBoxContainer.new();nav.position=Vector2(75,218);nav.add_theme_constant_override("separation",14);g.menu.add_child(nav)
 for category in (["Bild","Audio","Mikrofon","Steuerung","Spiel","Sprache"] if MicListener.supported() else ["Bild","Audio","Steuerung","Spiel","Sprache"]):
  var chosen: String=category
  var button: Button=g._button(category,func():settings(g,chosen),category==tab);button.custom_minimum_size.x=250;nav.add_child(button)
 var back: Button=g._button("Zurück",g._return_from_panel);back.custom_minimum_size.x=250;nav.add_child(back)
 var scroll:=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scroll.offset_left=395;scroll.offset_top=205;scroll.offset_right=-90;scroll.offset_bottom=-75;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;g.menu.add_child(scroll)
 var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",16);scroll.add_child(column)
 var heading: Label=g._label(tab,30);heading.add_theme_font_override("font",g.title_font);column.add_child(heading)
 match tab:
  "Sprache":
   column.add_child(g._label("Sprache / Language",24))
   var languages:=OptionButton.new();languages.name="LanguageChoice";languages.set_meta("qa_label","Sprache / Language");languages.custom_minimum_size=Vector2(500,52);languages.add_item("Deutsch");languages.add_item("English");languages.selected=1 if g.settings.language=="en" else 0
   languages.item_selected.connect(func(index: int):changed(g,"language","en" if index==1 else "de");settings(g,"Sprache"));column.add_child(languages)
   toggle(g,column,"Untertitel für Sprache","subtitles")
   toggle(g,column,"Englische Schildübersetzungen","sign_subtitles")
   column.add_child(g._paragraph("Die gesprochenen Aufnahmen erhalten Untertitel in deiner gewählten Sprache. Sie folgen Pause und Fortsetzen.",18))
   column.add_child(g._paragraph("Bei englischer Spielsprache erscheint die Übersetzung unten im Bild, wenn du ein Schild ansiehst.",18))
  "Bild":
   slider(g,column,"Helligkeit","brightness",.7,1.8,.05)
   slider(g,column,"Sichtfeld","fov",65,100,1,"°")
   slider(g,column,"Renderauflösung","render_scale",.65,1,.05)
   option(g,column,"Grafikqualität","quality",["Leistung","Standard","Hoch"],[0,1,2])
   toggle(g,column,"Filmkorn","grain")
   toggle(g,column,"Stroboskop-Effekte","strobe")
   option(g,column,"Bildratenlimit","fps",["Unbegrenzt","30 FPS","60 FPS","120 FPS","144 FPS"],[0,30,60,120,144])
   if not OS.has_feature("web"): toggle(g,column,"V-Sync","vsync")
   column.add_child(g._button("Vollbild umschalten",g._fullscreen))
  "Audio":
   slider(g,column,"Lautstärke","volume",0,1,.05)
   slider(g,column,"Menümusik","menu_music",0,1,.05)
   slider(g,column,"Eigene Atmung und Kleidung","body_audio",0,1,.05)
   slider(g,column,"Raumklang & entfernte Geräusche","ambience",0,1,.05)
   slider(g,column,"Chef-Anruf","voice",0,1,.05)
   column.add_child(g._paragraph("Alle Tonquellen bleiben an die Gesamtlautstärke gebunden. ESC pausiert auch räumliche Geräusche und den Anruf.",16))
  "Mikrofon":
   microphone(g,column)
  "Steuerung":
   slider(g,column,"Mausempfindlichkeit","sensitivity",.0007,.0045,.0001)
   toggle(g,column,"Maus-Y umkehren","invert_y")
   toggle(g,column,"Kamerabewegung","motion")
   slider(g,column,"Körperbewegungen","body_motion",0,1,.05)
   toggle(g,column,"Handanimationen","hand_actions")
   column.add_child(g._paragraph("WASD / Pfeiltasten   Bewegen\nMaus   Umsehen\nUmschalt   Schnell gehen\nLeertaste   Springen / Intro gedrückt überspringen\nC halten   Ducken\nE   Interagieren\nF   Taschenlampe\nG   Aufheben / Loslassen\nLinke Maustaste   Werfen\nMausrad / R   Getragenes drehen (Umschalt + Mausrad kippen)\nTAB   Fundstücke und Zeitungen\nESC   Pause",18))
  "Spiel":
   toggle(g,column,"Fadenkreuz","crosshair")
   column.add_child(g._paragraph("Deine handschriftliche Kontrollliste liegt im TAB-Inventar. Sie ist eine freiwillige Merkhilfe für den aktuellen Rundgang.",18))
   var prank:=CheckButton.new();prank.text="Jumpscares  Off / On";prank.custom_minimum_size.y=60
   prank.toggled.connect(func(_on):g._menu_jump());column.add_child(prank)
   column.add_child(g._paragraph("Der erste Rundgang ist dein Vergleich. 13 richtige Entscheidungen in Folge beenden die Nachtschicht.",18))
 var reset: Button=g._button("Einstellungen zurücksetzen",func():g._reset_settings();settings(g,tab));column.add_child(reset)
 g._telemetry()

# 5.4.0: microphone mode, off by default, with a live level meter so the
# player can set the sensitivity before a night.
static func microphone(g: Node3D, column: VBoxContainer) -> void:
 toggle(g,column,"Mikrofon-Modus","mic")
 column.add_child(g._label("Mikrofon-Gerät",18))
 var devices:=OptionButton.new();devices.name="MicDevice";devices.set_meta("qa_label","Mikrofon-Gerät");devices.custom_minimum_size.y=46
 var names:=MicListener.devices()
 for device in names:devices.add_item(AfterPlayLanguage.t("Windows-Standard") if device=="Default" else device)
 devices.selected=maxi(0,names.find(str(g.settings.get("mic_device","Default"))))
 devices.item_selected.connect(func(i):changed(g,"mic_device",names[i]));column.add_child(devices)
 column.add_child(g._paragraph("Im Mikrofon-Modus hört dich das Gebäude. Hier schläft etwas. Wenn du zu lange zu laut bist – schreien, lautes Lachen, lautes Reden –, weckst du es.",18))
 var important: Label=g._paragraph("Wichtig: Das Wesen ist KEINE Anomalie. Du musst es nicht melden, und es hat nichts mit der roten oder grünen Tür zu tun. Es ist allein die Strafe für Lärm.",18)
 important.add_theme_color_override("font_color",Color("e8574f"));column.add_child(important)
 column.add_child(g._paragraph("1. Mal zu laut: Alle Lampen flackern – eine Warnung.
2. Mal: Es schreit. Es ist wach.
3. Mal: Es kommt. Die Nacht ist verloren.
Drei ruhige Minuten lassen es eine Stufe wieder einschlafen.",18))
 column.add_child(g._paragraph("Unten links siehst du während der Schicht immer deinen Pegel. Bleib aus dem roten Bereich. Mit jeder Runde schläft es leichter: Der rote Bereich wird größer.",18))
 slider(g,column,"Mikrofon-Empfindlichkeit","mic_sensitivity",0,1,.05)
 column.add_child(g._label("Pegel",18))
 var meter:=ProgressBar.new();meter.name="MicLevelMeter";meter.min_value=0;meter.max_value=1;meter.step=.001;meter.show_percentage=false;meter.custom_minimum_size=Vector2(500,26)
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("6fa86a");meter.add_theme_stylebox_override("fill",fill)
 var back:=StyleBoxFlat.new();back.bg_color=Color(.12,.12,.12);back.border_color=Color(.4,.4,.38);back.set_border_width_all(1);meter.add_theme_stylebox_override("background",back)
 var mark:=ColorRect.new();mark.name="MicThreshold";mark.color=Color("e0141b");mark.size=Vector2(3,26);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;meter.add_child(mark)
 var state: Label=g._label("",16,Color("a3aaa2"));state.name="MicState"
 var timer:=Timer.new();timer.wait_time=.05;timer.autostart=true;meter.add_child(timer)
 var refresh:=func():
  var level: float=g.mic.level_db if g.mic else -80.
  var limit: float=g.mic_warden.base_threshold() if g.mic_warden else -25.
  meter.value=clampf((level+60.)/60.,0.,1.);mark.position.x=clampf((limit+60.)/60.,0.,1.)*meter.size.x-1.
  var over:=level>limit
  fill.bg_color=Color("e0141b") if over else Color("6fa86a")
  state.text=AfterPlayLanguage.t("Mikrofon ist aus." if not bool(g.settings.mic) else "Zu laut! So würdest du es wecken." if over else "Leise genug.")
 timer.timeout.connect(refresh);column.add_child(meter);column.add_child(state);refresh.call()
 column.add_child(g._paragraph("Teste hier: Sprich in normaler Lautstärke – der Balken soll unter der roten Linie bleiben. Wenn du schreist, muss er darüber gehen. Kopfhörer empfohlen, sonst hört das Mikrofon den Spielsound.",16))
 column.add_child(g._paragraph("Es wird nur die Lautstärke gemessen. Nichts wird aufgenommen, gespeichert oder gesendet.",16))

static func changed(g: Node3D, key: String, value: Variant) -> void:
 g.settings[key]=value;g._apply_settings();g._write_settings()

static func slider(g: Node3D, parent: VBoxContainer, title: String, key: String, low: float, high: float, step: float, suffix: String="") -> void:
 var label: Label=g._label(title,18);parent.add_child(label)
 var slider:=HSlider.new();slider.set_meta("qa_label",title);slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=float(g.settings[key]);slider.custom_minimum_size=Vector2(500,32)
 var display:=func(v):label.text=AfterPlayLanguage.t(title)+"   "+("%.4f"%v if key=="sensitivity" else str(roundi(v))+suffix if high>2 else "%d %%"%roundi(v*100))
 display.call(slider.value);slider.value_changed.connect(func(v):display.call(v);changed(g,key,v));parent.add_child(slider)

static func toggle(g: Node3D, parent: VBoxContainer, title: String, key: String) -> void:
 var button:=CheckButton.new();button.text=AfterPlayLanguage.t(title);button.button_pressed=bool(g.settings[key]);button.custom_minimum_size.y=48;button.toggled.connect(func(v):changed(g,key,v));parent.add_child(button)

static func option(g: Node3D, parent: VBoxContainer, title: String, key: String, labels: Array, values: Array) -> void:
 parent.add_child(g._label(title,18));var button:=OptionButton.new();button.set_meta("qa_label",title);button.custom_minimum_size.y=46
 for label in labels: button.add_item(AfterPlayLanguage.t(label))
 button.selected=maxi(0,values.find(int(g.settings[key])));button.item_selected.connect(func(i):changed(g,key,values[i]));parent.add_child(button)

static func credits(g: Node3D) -> void:
 g.phase="help";g.return_phase="menu"
 var column: VBoxContainer=g._panel("Mitwirkende","After Play · Kinderparadies")
 column.add_child(g._paragraph("Spielidee, Programmierung und Gestaltung: Kyoko.\nZusätzliche Ideen und Konzeptbeiträge: einsmarello.\nTestspieler: einsmarello, __jerry__, gingerbread, Mozart und 2eazy4me_.\n\nAnatomiebasis des Clownkopfs: Infinite von Lee Perry-Smith, bearbeitet, CC BY 3.0.\n\nUmgebungsaufnahmen: Joseph SARDIN / BigSoundBank, CC0. Kreaturenaufnahmen: Ogrebane und A New Room / OpenGameArt, CC0. Weitere Asset-Lizenzen und Quellen liegen der Windows-Fassung bei.",18))
 var credit:=RichTextLabel.new();credit.bbcode_enabled=true;credit.fit_content=true;credit.custom_minimum_size.x=440;credit.text="[url=https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf/LeePerrySmith]%s[/url] · [url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url]";credit.text=credit.text%AfterPlayLanguage.t("Kopfmodell und Quelle");credit.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(credit)
 column.add_child(g._label("Charakter & Stimme der Rosenyan-Puppe",23))
 var rosenyan:=RichTextLabel.new();rosenyan.name="RosenyanCredit";rosenyan.bbcode_enabled=true;rosenyan.fit_content=true;rosenyan.custom_minimum_size.x=440;rosenyan.add_theme_font_size_override("normal_font_size",18)
 rosenyan.text=AfterPlayLanguage.t("Rosenyan-Puppe: Charakter und Stimme von RosenyanVT. Alle Rechte an Figur und Aufnahme liegen bei RosenyanVT.")+" [url=https://www.twitch.tv/rosenyanvt]twitch.tv/rosenyanvt[/url]"
 rosenyan.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(rosenyan)
 column.add_child(g._label("Charakter & Stimme der einsmarello-Puppe",23))
 var marello:=RichTextLabel.new();marello.name="EinsmarelloCredit";marello.bbcode_enabled=true;marello.fit_content=true;marello.custom_minimum_size.x=440;marello.add_theme_font_size_override("normal_font_size",18)
 marello.text=AfterPlayLanguage.t("einsmarello-Puppe: Charakter und Gesang von einsmarello. Alle Rechte an Figur und Aufnahme liegen bei einsmarello.")+" [url=https://www.twitch.tv/einsmarello]twitch.tv/einsmarello[/url]"
 marello.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(marello)
 column.add_child(g._label("Charakter & Stimme der Hissybusa-Puppe",23))
 var hissy:=RichTextLabel.new();hissy.name="HissybusaCredit";hissy.bbcode_enabled=true;hissy.fit_content=true;hissy.custom_minimum_size.x=440;hissy.add_theme_font_size_override("normal_font_size",18)
 hissy.text=AfterPlayLanguage.t("Hissybusa-Puppe: Charakter und Stimme von Hissybusa. Alle Rechte an Figur und Aufnahme liegen bei Hissybusa.")+" [url=https://www.twitch.tv/hissybusa]twitch.tv/hissybusa[/url]"
 hissy.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(hissy)
 column.add_child(g._label("Charakter der Jule_heartbeat-Puppe",23))
 var jule:=RichTextLabel.new();jule.name="JuleCredit";jule.bbcode_enabled=true;jule.fit_content=true;jule.custom_minimum_size.x=440;jule.add_theme_font_size_override("normal_font_size",18)
 jule.text=AfterPlayLanguage.t("Jule_heartbeat-Puppe: Charakter von Jule_heartbeat. Alle Rechte an der Figur liegen bei Jule_heartbeat. Das Schnurren der Katze ist für das Spiel erzeugt.")+" [url=https://www.twitch.tv/jule_heartbeat]twitch.tv/jule_heartbeat[/url]"
 jule.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(jule)
 column.add_child(g._label("Charakter der theraidenlena-Puppe",23))
 var lena:=RichTextLabel.new();lena.name="TheraidenlenaCredit";lena.bbcode_enabled=true;lena.fit_content=true;lena.custom_minimum_size.x=440;lena.add_theme_font_size_override("normal_font_size",18)
 lena.text=AfterPlayLanguage.t("theraidenlena-Puppe: Charakter von theraidenlena. Alle Rechte an der Figur liegen bei theraidenlena. Die Spieluhr-Melodie ist für das Spiel erzeugt.")+" [url=https://www.twitch.tv/theraidenlena]twitch.tv/theraidenlena[/url]"
 lena.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(lena)
 column.add_child(g._label("Partymusik",23))
 var party_credit:=RichTextLabel.new();party_credit.name="PartyMusicCredit";party_credit.bbcode_enabled=true;party_credit.fit_content=true;party_credit.custom_minimum_size.x=440;party_credit.add_theme_font_size_override("normal_font_size",18)
 party_credit.text=HappylandParty.MUSIC_CREDIT
 for link in ["https://suno.com/terms"]:party_credit.text=party_credit.text.replace(link,"[url="+link+"]"+link+"[/url]")
 party_credit.meta_clicked.connect(func(link):OS.shell_open(str(link)));column.add_child(party_credit)
 column.add_child(g._button("Zurück",g._return_from_panel,true));g._telemetry()
