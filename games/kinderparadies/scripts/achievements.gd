class_name AfterPlayAchievements
extends Node

# In-game achievements (4.14.0), stored locally next to the album. Never
# cleared by a death, a new shift or a new endless run.
const LIST:=[
 {"id":"round_10","title":"Erste Schritte","text":"Erreiche im Endlosmodus Runde 10."},
 {"id":"round_15","title":"Die Uhr tickt","text":"Erreiche Runde 15. Ab hier läuft der Timer."},
 {"id":"round_25","title":"Nachtschwärmer","text":"Erreiche im Endlosmodus Runde 25."},
 {"id":"round_50","title":"Halbes Hundert","text":"Erreiche im Endlosmodus Runde 50."},
 {"id":"round_100","title":"Dreistellig","text":"Erreiche im Endlosmodus Runde 100."},
 {"id":"round_200","title":"Dauerdienst","text":"Erreiche im Endlosmodus Runde 200."},
 {"id":"round_250","title":"Halbzeit","text":"Erreiche im Endlosmodus Runde 250."},
 {"id":"round_350","title":"Unermüdlich","text":"Erreiche im Endlosmodus Runde 350."},
 {"id":"round_500","title":"Happyland gehört dir","text":"Schaffe alle 500 Runden des Endlosmodus."},
 {"id":"flawless","title":"Makellos","text":"Schaffe 50 Runden am Stück, ohne ein Leben zu verlieren."},
 {"id":"eagle_eye","title":"Adlerauge","text":"Erkenne 25 Detail-Anomalien hintereinander."},
 {"id":"clutch","title":"Gegen die Uhr","text":"Beende eine Runde mit Timer, wenn weniger als 10 Sekunden übrig sind."},
 {"id":"blitz","title":"Blitzrunde","text":"Beende eine Runde mit Timer in unter 60 Sekunden."},
 {"id":"last_life","title":"Am seidenen Faden","text":"Überlebe 25 Runden mit dem letzten Leben.","secret":true},
 {"id":"ending_1","title":"Feierabend mit Freunden","text":"Schaffe alle 13 Rundgänge der Nachtschicht."},
 {"id":"ending_2","title":"Die Wahrheit hinter der Tür","text":"Finde heraus, was im Archiv liegt.","secret":true},
 {"id":"ending_3","title":"Ich bin dann mal weg","text":"Verlasse Happyland auf eigene Faust.","secret":true},
 {"id":"ending_4","title":"Alle wieder da","text":"Bringe alle Kinder zurück nach Happyland.","secret":true},
 {"id":"plushes","title":"Puppensammler","text":"Finde alle fünf Puppen in einer Schicht.","secret":true},
 {"id":"nightwatch_first","title":"Wieder an seinem Platz","text":"Behebe im Nightwatch Protocol deine erste Anomalie."},
 {"id":"nightwatch_10","title":"Wachsames Auge","text":"Behebe 10 Anomalien in einer Nacht."},
 {"id":"nightwatch_25","title":"Fünf Nächte","text":"Überstehe im Nightwatch Protocol alle fünf Nächte."},
 {"id":"nightwatch_generator","title":"Notstrom","text":"Starte den Generator in einer Nacht fünfmal neu."},
 {"id":"nightwatch_10min","title":"06:00","text":"Überstehe eine Nacht im Nightwatch Protocol."},
 {"id":"nightwatch_5000","title":"Aus dem Dunkeln","text":"Überstehe eine Nacht, in der dir der Strom ausgegangen ist.","secret":true},
 {"id":"party_10","title":"Partygast","text":"Überlebe in der Partynacht bis Runde 10."},
 {"id":"party_25","title":"Die Feier hört nie auf","text":"Überlebe in der Partynacht bis Runde 25."},
 {"id":"party_boss","title":"Geburtstag abgesagt","text":"Besiege in der Partynacht einen Boss."},
 {"id":"party_perks","title":"Vier Gläser","text":"Trinke in einem Lauf vier Perks."},
 {"id":"album_10","title":"Schnappschuss","text":"Sammle 10 Polaroids im Anomalie-Album."},
 {"id":"album_34","title":"Halbes Album","text":"Sammle 34 Polaroids im Anomalie-Album."},
 {"id":"album_all","title":"Lückenlos","text":"Sammle alle Polaroids im Anomalie-Album.","secret":true},
]
const ROUNDS:=[10,15,25,50,100,200,250,350,500]

var g: Node3D
var path:=""
var unlocked:={}
var best_round:=0
# Nightwatch Protocol: the last night survived (0-5) and the longest shift.
var nightwatch_night:=0
var nightwatch_time:=0.0
# Partynacht (wave mode) records.
var zombies:={"best_round":0,"best_points":0,"kills":0,"headshots":0,"bosses":0,"longest":0.,"pickups":0,"perks":0,"weapons":[]}
var toast: PanelContainer
var toast_title: Label
var toast_text: Label
var toast_head: Label
var queue: Array=[]
var showing:=false

func build(game: Node3D) -> void:
 g=game;name="Achievements"
 var author: bool=g.AUTHOR_TOOLS and ("--self-test" in OS.get_cmdline_user_args() or "--render-qa" in OS.get_cmdline_user_args())
 path="user://qa-%d-after-play-achievements.json"%OS.get_process_id() if author else "user://qa-after-play-achievements.json" if OS.has_feature("qa") else "user://after-play-achievements.json"
 var text: String=g._persistent_text(path)
 var data=JSON.parse_string(text) if not text.is_empty() else null
 if data is Dictionary:
  var stored=data.get("unlocked",{})
  if stored is Dictionary:
   for row in LIST:
    if stored.has(row.id):unlocked[row.id]=float(stored[row.id])
  best_round=clampi(int(data.get("best_round",0)),0,PatrolState.ENDLESS_GOAL)
  nightwatch_night=clampi(int(data.get("nightwatch_night",0)),0,NightwatchConfig.NIGHTS);nightwatch_time=maxf(float(data.get("nightwatch_time",0.)),0.)
  var stored_z=data.get("zombies",{})
  if stored_z is Dictionary:
   for key in zombies:
    if stored_z.has(key):zombies[key]=stored_z[key] if key=="weapons" and stored_z[key] is Array else maxf(float(stored_z[key]),0.) if key=="longest" else maxi(int(stored_z[key]),0)
 var layer:=CanvasLayer.new();layer.layer=40;add_child(layer)
 toast=PanelContainer.new();toast.name="AchievementToast";toast.mouse_filter=Control.MOUSE_FILTER_IGNORE
 toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);toast.position=Vector2(-460,40);toast.custom_minimum_size=Vector2(420,0)
 var style:=StyleBoxFlat.new();style.bg_color=Color(.03,.04,.035,.93);style.border_color=Color("b6a16d");style.border_width_left=4;style.set_content_margin_all(16);style.content_margin_left=22;toast.add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",4);toast.add_child(column)
 toast_head=g._label("ERFOLG FREIGESCHALTET",14,Color("b6a16d"));column.add_child(toast_head)
 toast_title=g._label("",26,Color("eee7d6"));toast_title.add_theme_font_override("font",g.title_font);column.add_child(toast_title)
 toast_text=g._label("",16,Color("bac6c0"));toast_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_text.custom_minimum_size.x=380;column.add_child(toast_text)
 layer.add_child(toast);toast.hide()

static func row(id: String) -> Dictionary:
 for item in LIST:
  if item.id==id:return item
 return {}

# Any other toast (5.2.8: new album polaroids), queued with the achievements.
func notify(head: String,title: String,text: String) -> void:
 queue.append({"head":head,"title":title,"text":text});_show_next()

func has(id: String) -> bool:
 return unlocked.has(id)

func unlock(id: String) -> bool:
 if unlocked.has(id) or row(id).is_empty():return false
 unlocked[id]=Time.get_unix_time_from_system();save()
 queue.append(id);_show_next()
 return true

func record_round(round_value: int) -> void:
 if round_value>best_round:best_round=round_value;save()
 for target in ROUNDS:
  if round_value>=target:unlock("round_%d"%target)

# Returns true when a night is survived for the first time.
func record_nightwatch(night_value: int, survived: bool, seconds: float) -> bool:
 var better:=survived and night_value>nightwatch_night
 if better:nightwatch_night=night_value
 nightwatch_time=maxf(nightwatch_time,seconds)
 save();return better

# Adds a Partynacht run; true when it is a new best round or score.
func record_zombies(r: Dictionary) -> bool:
 var better:=int(r.round)>int(zombies.best_round) or (int(r.round)==int(zombies.best_round) and int(r.points)>int(zombies.best_points))
 zombies.best_round=maxi(int(zombies.best_round),int(r.round));zombies.best_points=maxi(int(zombies.best_points),int(r.points))
 for key in ["kills","headshots","bosses","pickups","perks"]:zombies[key]=int(zombies[key])+int(r.get(key,0))
 zombies.longest=maxf(float(zombies.longest),float(r.seconds))
 var seen: Array=zombies.weapons
 for id in r.get("weapons",[]):
  if not id in seen:seen.append(id)
 if int(r.round)>=10:unlock("party_10")
 if int(r.round)>=25:unlock("party_25")
 if int(r.bosses)>=1:unlock("party_boss")
 if int(r.perks)>=4:unlock("party_perks")
 save();return better

func save() -> void:
 g._write_persistent_text(path,JSON.stringify({"unlocked":unlocked,"best_round":best_round,"nightwatch_night":nightwatch_night,"nightwatch_time":nightwatch_time,"zombies":zombies}))

func _show_next() -> void:
 if showing or queue.is_empty() or not is_instance_valid(toast):return
 showing=true
 var next=queue.pop_front()
 var item: Dictionary=next if next is Dictionary else row(next)
 toast_head.text=str(item.get("head","ERFOLG FREIGESCHALTET"))
 toast_title.text=AfterPlayLanguage.t(item.title);toast_text.text=AfterPlayLanguage.t(item.text)
 toast.show();toast.position.x=-460
 var tween:=create_tween()
 tween.tween_property(toast,"position:x",40.,.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 tween.tween_interval(3.6)
 tween.tween_property(toast,"position:x",-460.,.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 tween.tween_callback(func():toast.hide();showing=false;_show_next())

func show_menu(back: Callable) -> void:
 g.phase="achievements";NightMenus.clear(g);NightMenus.backdrop(g,true)
 var title: Label=g._label("ERFOLGE",64,Color("e8e1c8"));title.add_theme_font_override("font",NightMenus.menu_font(500,3));title.position=Vector2(100,70);g.menu.add_child(title)
 var summary: Label=g._label("%d / %d freigeschaltet  ·  Bester Endloslauf: Runde %d  ·  Nightwatch: Nacht %d / 5"%[unlocked.size(),LIST.size(),best_round,nightwatch_night],20,Color("cbbb95"));summary.position=Vector2(104,170);g.menu.add_child(summary)
 var scroll:=ScrollContainer.new();scroll.position=Vector2(100,225);scroll.size=Vector2(1720,620);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;g.menu.add_child(scroll)
 var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",14);scroll.add_child(grid)
 for item in LIST:
  var done:=unlocked.has(item.id);var hidden:=bool(item.get("secret",false)) and not done
  var card:=PanelContainer.new();card.name="Achievement_"+str(item.id);card.custom_minimum_size=Vector2(550,104)
  var paper:=StyleBoxFlat.new();paper.bg_color=Color("c8bea2") if done else Color("1b231f");paper.border_color=Color("b6a16d") if done else Color("3a4038");paper.border_width_left=4;paper.set_content_margin_all(14);paper.content_margin_left=20;card.add_theme_stylebox_override("panel",paper)
  var col:=VBoxContainer.new();col.add_theme_constant_override("separation",4);card.add_child(col)
  var name_label: Label=g._label("???" if hidden else str(item.title),24,Color("2c3127") if done else Color("d9d3bf"));name_label.add_theme_font_override("font",g.title_font);col.add_child(name_label)
  var text_label: Label=g._label("Geheimer Erfolg" if hidden else str(item.text),16,Color("4c5044") if done else Color("8f968b"));text_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text_label.custom_minimum_size.x=500;col.add_child(text_label)
  grid.add_child(card)
 var back_button: Button=g._button("Zurück",back,true);back_button.position=Vector2(100,900);back_button.size=Vector2(320,60);g.menu.add_child(back_button);back_button.grab_focus();g._telemetry()
