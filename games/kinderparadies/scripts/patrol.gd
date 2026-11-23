class_name PatrolState
extends RefCounted

const GOAL := 13
const REPLACEMENTS := {"clock_reverse":"reception_peeker","car_moves":"reception_charge","car_float":"reception_queue","hours_wrong":"pit_hands","bunny_watches":"frame_stalker","balls_red":"slide_crawler","ball_moves":"party_portrait","slide_green":"party_guests","slide_missing":"cake_mouth","croc_breathes":"corridor_crossing","chairs_missing":"service_pursuit","chair_stack":"service_ceiling","blood_pool":"fridge_occupant","mural_upside":"pot_arms","mural_mirror":"kitchen_double","mural_red":"screen_visitor","stars_upside":"cinema_last_row","footprints":"vent_strike","extinguisher_float":"tube_chase","bloody_hands":"tube_window_hands"}
const ZONES := ["Empfang", "Bällebad", "Party Raum", "Wartungsgang", "Küche", "Kino"]
const ANOMALIES := [
 {"id":"horse_clown_hunt","name":"Der Pferdekopf verfolgt dich an einem wachsenden Hals. Die rote Tür öffnet erst, wenn der Küchenclown ihn vertrieben hat.","zone":"Kino"},
 {"id":"power_blackout","name":"Stromausfall: Licht, Partymodus und Maschinen fallen aus. Die rote Tür öffnet erst, wenn der Hauptschalter im Wartungsraum wieder umgelegt ist.","zone":"Wartungsgang"},
 {"id":"dust_footprints","name":"Kleine Kinderfußspuren führen vom Bällebad durch den Staub bis an die Wand und hören dort auf.","zone":"Bällebad"},
 {"id":"cold_breath","name":"In der Küche ist es eiskalt: Der eigene Atem wird sichtbar, Raureif liegt auf den Wänden.","zone":"Küche"},
 {"id":"wc_stall_watcher","name":"In der offenen WC-Kabine wartet eine verdrehte Gestalt und schnellt nach vorn.","zone":"Kinder-WC"},
 {"id":"wc_ceiling_guest","name":"Über dem Abfluss hängt ein Besucher kopfüber und fährt von der niedrigen WC-Decke herab.","zone":"Kinder-WC"},
 {"id":"snackbar_visitor","name":"Vor der geschlossenen Snackbar bricht eine Gestalt aus dem Dunkeln hervor.","zone":"Party Raum"},
 {"id":"throne_guest","name":"Auf dem Geburtstagsthron sitzt ein verdrehter Gast und schnellt dir entgegen.","zone":"Party Raum"},
 {"id":"costume_wakes","name":"Ein leer aufgehängtes Kostüm hebt den Kopf und schlägt nach vorn.","zone":"Party Raum"},
 {"id":"false_exit","name":"Die Garderobe am alten Haupteingang erscheint unversehrt und hell. Nach einem Lichtausfall ist sie verfallen; das Schild hat sich verändert.","zone":"Empfang"},
 {"id":"reception_counter_burst","name":"Hinter dem Empfang schnellt ein Besucher hervor und stürmt auf dich zu.","zone":"Empfang"},
 {"id":"reception_overhead","name":"Über dem Empfangsgang fällt eine kopfüber hängende Gestalt herab.","zone":"Empfang"},
 {"id":"pit_runner","name":"Am Rand des Bällebads rast eine entstellte Gestalt auf dich zu.","zone":"Bällebad"},
 {"id":"frame_drop","name":"Im Klettergerüst sackt ein kopfüber hängender Körper plötzlich nach unten.","zone":"Bällebad"},
 {"id":"party_mascot_guest","name":"Neben dem großen Stoffhasen taucht ein Gast auf und schießt auf dich zu.","zone":"Party Raum"},
 {"id":"party_under_table","name":"Eine verdrehte Gestalt kriecht am Geburtstagstisch hervor.","zone":"Party Raum"},
 {"id":"maintenance_blackout","name":"Im Wartungsgang tritt ein Besucher plötzlich aus dem Dunkeln und greift nach dir.","zone":"Wartungsgang"},
 {"id":"server_rush","name":"Zwischen den Wartungsregalen schießt ein Besucher durch den Serverraum auf dich zu.","zone":"Wartungsgang"},
 {"id":"kitchen_cupboard_face","name":"Aus dem offenen Küchenschrank fährt dir ein verzerrter Kopf entgegen.","zone":"Küche"},
 {"id":"kitchen_floor_crawler","name":"Vor der Küchenarbeitsplatte kriecht eine Gestalt auf allen Vieren auf dich zu.","zone":"Küche"},
 {"id":"cinema_aisle_rush","name":"Eine Gestalt rennt im Mittelgang des Kinos direkt auf dich zu.","zone":"Kino"},
 {"id":"cinema_seat_ambush","name":"Zwischen den Kinositzen erhebt sich plötzlich ein Besucher und stürzt nach vorn.","zone":"Kino"},
 {"id":"tube_burst","name":"Im Krabbeltunnel fährt eine kriechende Gestalt auf dich zu. Nur von innen sichtbar.","zone":"Krabbelröhre"},
 {"id":"clown_lunge","name":"Der Küchenclown hört auf zu rühren, fährt auf dich zu und beobachtet dich danach.","zone":"Küche"},
 {"id":"tube_watcher","name":"Eine Gestalt schaut durch das Dachfenster in die Krabbelröhre.","zone":"Bällebad"},
 {"id":"chair_ceiling","name":"Die Stühle hängen an der Decke.","zone":"Party Raum"},
 {"id":"service_pursuit","name":"Aus dem dunklen Wartungsende folgt dir eine langarmige Gestalt.","zone":"Wartungsgang"},
 {"id":"service_ceiling","name":"Ein verdrehter Besucher hängt kopfüber im Wartungsgang und fährt auf dich herab.","zone":"Wartungsgang"},
 {"id":"balls_float","name":"Bälle schweben über dem Bällebad.","zone":"Bällebad"},
 {"id":"slide_crawler","name":"Eine verrenkte Gestalt kriecht vom Auslauf der Rutsche auf dich zu.","zone":"Bällebad"},
 {"id":"ball_giant","name":"Ein riesiger Ball steckt im Bällebad.","zone":"Bällebad"},
 {"id":"party_portrait","name":"Unter dem großen Clownfresko steht ein Besucher, der dich durch den Party Raum verfolgt.","zone":"Party Raum"},
 {"id":"balls_missing","name":"Das Bällebad ist leer.","zone":"Bällebad"},
 {"id":"pot_arms","name":"Lange knöcherne Arme greifen aus dem Schimmeltopf.","zone":"Küche"},
 {"id":"kitchen_double","name":"Neben dem Küchenclown erscheint ein zweiter Besucher und verfolgt dich durch die Küche.","zone":"Küche"},
 {"id":"screen_visitor","name":"Eine Gestalt steht vor der Kinoleinwand und läuft auf dich zu.","zone":"Kino"},
 {"id":"mural_missing","name":"Das große Wandbild ist verschwunden.","zone":"Wartungsgang"},
 {"id":"reception_peeker","name":"Eine ausgemergelte Gestalt beugt sich hinter dem Empfang hervor und zuckt auf dich zu.","zone":"Empfang"},
 {"id":"clock_fast","name":"Die Uhr dreht sich viel zu schnell.","zone":"Empfang"},
 {"id":"reception_charge","name":"Ein langarmiger Besucher verfolgt dich kurz durch den leeren Empfangsgang.","zone":"Empfang"},
 {"id":"car_giant","name":"Das Spielauto neben dem Klettergerüst ist riesig geworden.","zone":"Bällebad"},
 {"id":"reception_queue","name":"Drei reglose Besucher warten mit verdrehten Köpfen vor dem Empfang.","zone":"Empfang"},
 {"id":"car_missing","name":"Das rote Spielauto neben dem Klettergerüst fehlt.","zone":"Bällebad"},
 {"id":"cinema_last_row","name":"Hinter der letzten Kinoreihe steht ein Besucher auf und folgt dir durch den Gang.","zone":"Kino"},
 {"id":"vent_strike","name":"Der Pferdeschädel stößt bei Annäherung aus dem Schacht nach unten.","zone":"Kino"},
 {"id":"lights_red","name":"Alle Deckenlampen leuchten rot.","zone":"Empfang"},
 {"id":"party_dark","name":"Die Beleuchtung im Party Raum ist ausgefallen.","zone":"Party Raum"},
 {"id":"balloons_many","name":"Ein ganzer Schwarm Ballons füllt den Party Raum.","zone":"Party Raum"},
 {"id":"balloons_floor","name":"Die Ballons hängen nach unten und liegen am Boden.","zone":"Party Raum"},
 {"id":"party_guests","name":"Drei stumme Gestalten stehen um den Geburtstagstisch.","zone":"Party Raum"},
 {"id":"cake_mouth","name":"Zwischen den Kerzen taucht ein ausgezehrtes Gesicht auf und schnappt nach dir.","zone":"Party Raum"},
 {"id":"net_missing","name":"Die Sicherheitsnetze an der Kletteranlage fehlen.","zone":"Bällebad"},
 {"id":"star_giant","name":"Ein übergroßer Stern hängt im Wartungsgang.","zone":"Wartungsgang"},
 {"id":"tube_chase","name":"Eine kriechende Gestalt verfolgt dich kurz im Krabbeltunnel. Nur von innen sichtbar.","zone":"Krabbelröhre"},
 {"id":"pit_hands","name":"Knöcherne Arme schnellen aus dem Bällebad und bleiben zwischen den Bällen stehen.","zone":"Bällebad"},
 {"id":"blood_trail","name":"Eine frische Blutspur zieht sich durch den Hauptgang.","zone":"Empfang"},
 {"id":"tube_window_hands","name":"Lange Finger schlagen von außen gegen ein Röhrenfenster. Nur von innen sichtbar.","zone":"Krabbelröhre"},
 {"id":"fridge_occupant","name":"Eine hagere Gestalt lauert vor dem Kühlschrank und beugt sich plötzlich vor.","zone":"Küche"},
 {"id":"mural_bleeds","name":"Aus dem Wandbild laufen breite Blutspuren.","zone":"Wartungsgang"},
 {"id":"bunny_ceiling","name":"Der Stoffhase hängt kopfüber vor der Decke statt auf seiner Bank zu sitzen.","zone":"Empfang"},
 {"id":"heavy_mist","name":"Der normale graugrüne Nebel ist blutrot geworden.","zone":"Bällebad"},
 {"id":"bunny_lunge","name":"Der Stoffhase springt dich bei Annäherung an und bleibt danach vor seiner Bank liegen.","zone":"Empfang"},
 {"id":"frame_stalker","name":"Eine kriechende Gestalt bewegt sich hinter den Netzen im Klettergerüst.","zone":"Bällebad"},
 {"id":"corridor_crossing","name":"Eine Gestalt schießt quer durch den Wartungsgang und bleibt verrenkt stehen.","zone":"Wartungsgang"},
 {"id":"croc_snap","name":"Das Krokodil bäumt sich mit einem Knall auf und bleibt danach aufgerichtet.","zone":"Bällebad"},
 {"id":"balloons_follow","name":"Die drei Geburtstagsballons folgen dir durch den Raum.","zone":"Party Raum"},
 {"id":"party_burst","name":"Die Ballons blähen sich bei Annäherung mit einem Knall auf.","zone":"Party Raum"},
 {"id":"horse_rocks","name":"Das verlassene Schaukelpferd schaukelt von alleine.","zone":"Empfang"}
]

var rng := RandomNumberGenerator.new()
var streak := 0
var best := 0
var errors := 0
var rounds := 0
var seconds := 0.0
var current := "none"
var visited: Array[String] = []
var deck: Array[String] = []
var bag: Array[String] = []
var completed := false
var horse_override:=false
var history: Array = []
# Multiplayer: player 2's thirteen planned rounds (an anomaly id or "none").
# Survives start() so a death replays the same planned shift.
var plan: Array[String] = []
# Endless mode (4.14.0): up to 500 rounds, three lives, a five minute timer
# from round 15. streak counts the rounds cleared, so streak+1 is the round.
const ENDLESS_GOAL:=500
const LIVES:=3
const TIMER_FROM:=15
const ROUND_SECONDS:=300.0
# Obvious changes and loud encounters first, quiet ones later. Every other
# catalogue anomaly is tier 2. From round 31 procedural detail anomalies
# (current=="detail") join and shrink with every round.
const TIER_1:=["lights_red","heavy_mist","balls_missing","balls_float","ball_giant","chair_ceiling","balloons_many","party_dark","blood_trail","mural_bleeds","bunny_ceiling","car_giant","star_giant","reception_queue","party_guests","power_blackout","reception_counter_burst","reception_overhead","pit_runner","cinema_aisle_rush","horse_clown_hunt","snackbar_visitor","throne_guest"]
const TIER_3:=["dust_footprints","false_exit","clock_fast","car_missing","net_missing","horse_rocks","tube_watcher","tube_window_hands","tube_chase","tube_burst","frame_stalker","cinema_last_row","balloons_follow","mural_missing","cold_breath"]
var endless:=false
var lives:=LIVES
var round_time:=0.0
var detail:={}
var tier_bags:={"1":[],"2":[],"3":[]}
# Counters for achievements: rounds without losing a life, detail anomalies
# found in a row, rounds survived on the last life.
var flawless:=0
var detail_row:=0
var last_life_rounds:=0
var over:=false

static func catalog() -> Array:
 var rows: Array=[]
 for anomaly in ANOMALIES:rows.append({"id":anomaly.id,"name":anomaly.name,"zone":anomaly.zone})
 return rows

func start(seed_value: int = 0) -> void:
 rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
 _reset()

# A death in the thirteen-round shift (5.2.7): progress starts over, but the
# anomaly bag and its random stream carry on, so the anomalies of the failed
# attempt do not come back until every other one has been seen.
func retry() -> void:
 var kept:=bag.duplicate()
 # The round drawn right after the fatal door was never shown; it goes back.
 if not endless and current not in ["none","detail"] and current not in kept and current not in _seen():kept.append(current)
 _reset()
 if not endless:bag.assign(kept)

func _reset() -> void:
 streak=0;best=0;errors=0;rounds=0;seconds=0;current="none";completed=false;horse_override=false
 visited.clear();deck.clear();bag.clear();history.clear()
 lives=LIVES;round_time=0;detail={};flawless=0;detail_row=0;last_life_rounds=0;over=false
 for key in tier_bags:tier_bags[key]=[]
 if endless:plan.clear();return
 if plan.size()==GOAL: current=plan[0]

func _shuffle(items: Array[String]) -> void:
 for i in range(items.size()-1,0,-1):
  var j := rng.randi_range(0,i)
  var temp := items[i];items[i]=items[j];items[j]=temp

func goal() -> int:
 return ENDLESS_GOAL if endless else GOAL

func round_number() -> int:
 return mini(streak+1,goal())

func timed() -> bool:
 return endless and round_number()>=TIMER_FROM

func time_left() -> float:
 return maxf(0,ROUND_SECONDS-round_time)

static func tier_of(id: String) -> int:
 return 1 if id in TIER_1 else 3 if id in TIER_3 else 2

# Share of each tier per round: [tier 1, tier 2, tier 3, detail].
static func tier_weights(round_value: int) -> Array:
 if round_value<=5:return [1.,0.,0.,0.]
 if round_value<=15:return [.6,.4,0.,0.]
 if round_value<=30:return [.25,.45,.3,0.]
 if round_value<=60:return [.1,.25,.3,.35]
 if round_value<=150:return [.05,.15,.2,.6]
 return [.03,.1,.12,.75]

# Detail size: 1.0 at round 31 down to 0.08 at round 500.
static func detail_strength(round_value: int) -> float:
 return lerpf(1.,.08,pow(clampf((round_value-31)/469.,0.,1.),.6))

func _next_endless() -> void:
 horse_override=false;visited.clear();detail={};round_time=0
 if completed or over:current="none";return
 # Slightly more anomalies than normal rounds, never three normal in a row.
 var recent:=history.slice(-2).filter(func(h):return h.get("anomaly","")=="none" and h.get("correct",false)).size()
 if rng.randf()<.42 and recent<2:current="none";return
 var weights:Array=tier_weights(round_number())
 var pick:=rng.randf();var tier:=0
 while tier<3 and pick>float(weights[tier]):pick-=float(weights[tier]);tier+=1
 if tier==3:
  current="detail";detail={"seed":rng.randi(),"strength":detail_strength(round_number())};return
 var key:=str(tier+1)
 if tier_bags[key].is_empty():
  var ids: Array[String]=[]
  for anomaly in ANOMALIES:
   if tier_of(anomaly.id)==tier+1:ids.append(anomaly.id)
  _shuffle(ids);tier_bags[key]=Array(ids)
 current=str(tier_bags[key].pop_back())

# The first endless round.
func begin_endless(seed_value: int=0) -> void:
 endless=true;start(seed_value);_next_endless()

func _next() -> void:
 if endless:_next_endless();return
 horse_override=false
 visited.clear()
 if plan.size()==GOAL:
  current=plan[clampi(streak,0,GOAL-1)]
  return
 if deck.is_empty():
  # Every round after the first is drawn at random, including the four
  # newspaper rounds (their papers still appear; they are no longer safe).
  # Twelve slots, seven anomalies: seven versus six over all thirteen rounds.
  # Restored decks keep their order so updates never reroll a saved shift.
  deck.assign(["normal","normal","normal","normal","normal","anomaly","anomaly","anomaly","anomaly","anomaly","anomaly","anomaly"])
  _shuffle(deck)
 if deck.pop_back()=="normal":
  current="none"
 else:
  current=_draw_unseen()

# Ids already drawn in this attempt of the shift (since the last wrong door).
func _seen() -> Array:
 var ids:=[]
 for entry in history:
  if not entry.get("correct",true):ids.clear();continue
  var id:=str(entry.get("anomaly","none"))
  if id!="none" and id not in ids:ids.append(id)
 return ids

# Every anomaly at most once per shift (5.2.7). A refilled bag leaves out what
# this attempt has already shown.
func _draw_unseen() -> String:
 var seen:=_seen()
 while not bag.is_empty():
  var id:String=bag.pop_back()
  if id not in seen:return id
 for anomaly in ANOMALIES:
  if anomaly.id not in seen:bag.append(anomaly.id)
 # Only possible with every anomaly shown in one attempt: allow repeats.
 if bag.is_empty():
  for anomaly in ANOMALIES:bag.append(anomaly.id)
 _shuffle(bag)
 return bag.pop_back()

func inspect(zone: String) -> bool:
 if zone in ZONES and zone not in visited and not completed:
  visited.append(zone)
  return true
 return false

# A wrong door, an expired timer or the horse cost one life; the round is
# drawn again. At zero lives the run is over.
func miss(reason: String="door") -> Dictionary:
 if not endless or completed or over:return {"accepted":false}
 var was_detail:=current=="detail"
 var anomaly:=current!="none"
 var detail_text:=describe_current()
 lives-=1;errors+=1;rounds+=1;flawless=0;last_life_rounds=0
 if was_detail:detail_row=0
 over=lives<=0
 _remember({"anomaly":current,"reason":reason,"correct":false})
 _next()
 return {"accepted":true,"correct":false,"anomaly":anomaly,"detail":detail_text,"streak":streak,"lives":lives,"over":over,"completed":false,"reason":reason}

func _remember(entry: Dictionary) -> void:
 history.append(entry)
 if endless and history.size()>40:history=history.slice(-40)

func _decide_endless(red: bool) -> Dictionary:
 var anomaly:=current!="none"
 if red!=anomaly:return miss("door")
 var was_detail:=current=="detail"
 var finished_round:=round_number();var used:=round_time
 var detail_text:=describe_current()
 rounds+=1;streak+=1;best=maxi(best,streak);flawless+=1
 if was_detail:detail_row+=1
 if lives==1:last_life_rounds+=1
 completed=streak>=ENDLESS_GOAL
 _remember({"anomaly":current,"red":red,"correct":true})
 var result:={"accepted":true,"correct":true,"anomaly":anomaly,"id":current,"detail":detail_text,"streak":streak,"lives":lives,"over":false,"completed":completed,"round":finished_round,"seconds":used,"timed":finished_round>=TIMER_FROM,"was_detail":was_detail}
 _next()
 return result

func describe_current() -> String:
 if current=="detail":return str(detail.get("text","Ein kleines Detail hatte sich verändert."))
 return describe(current)

func decide(red: bool) -> Dictionary:
 if completed or over: return {"accepted":false}
 if endless:return _decide_endless(red)
 var anomaly := current!="none"
 var correct := red==anomaly
 var detail := describe(current)
 rounds+=1
 if correct: streak+=1;best=maxi(best,streak)
 else: streak=0;errors+=1
 completed=streak==GOAL
 var result := {"accepted":true,"correct":correct,"anomaly":anomaly,"id":current,"detail":detail,"streak":streak,"completed":completed}
 history.append({"anomaly":current,"red":red,"correct":correct})
 if completed: current="none";horse_override=false
 else: _next()
 return result

static func describe(id: String) -> String:
 for anomaly in ANOMALIES:
  if anomaly.id==id: return anomaly.zone+": "+anomaly.name
 return "Es gab keine Anomalie. Der Rundgang war normal."

func serialize() -> Dictionary:
 return {"endless":endless,"lives":lives,"round_time":round_time,"detail":detail,"tier_bags":tier_bags,"flawless":flawless,"detail_row":detail_row,"last_life_rounds":last_life_rounds,"over":over,"version":1,"horse_override":horse_override,"streak":streak,"best":best,"errors":errors,"rounds":rounds,"seconds":seconds,"current":current,"visited":visited,"deck":deck,"bag":bag,"completed":completed,"history":history,"rng":str(rng.state),"plan":plan}

func restore(data: Dictionary) -> bool:
 var valid_ids: Array[String]=["none"]
 for anomaly in ANOMALIES: valid_ids.append(anomaly.id)
 valid_ids.append_array(REPLACEMENTS.keys())
 valid_ids.append("detail")
 var endless_save:=bool(data.get("endless",false))
 var limit:=ENDLESS_GOAL if endless_save else GOAL
 if data.get("current","")=="detail" and not endless_save:return false
 if data.get("version")!=1 or data.get("current","") not in valid_ids: return false
 if int(data.get("streak",-1))<0 or int(data.get("streak",9999))>limit: return false
 if not data.get("visited",[]) is Array or not data.get("deck",[]) is Array or not data.get("bag",[]) is Array: return false
 if not data.get("history",[]) is Array: return false
 if not data.get("horse_override",false) is bool:return false
 for field in ["streak","best","errors","rounds","seconds"]:
  var value=data.get(field,0)
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0: return false
 if int(data.get("best",0))>limit or not str(data.get("rng","1")).is_valid_int(): return false
 for id in data.get("bag",[]):
  if id not in valid_ids: return false
 if endless_save and not _restore_endless(data,valid_ids):return false
 for item in data.get("deck",[]):
  if item not in ["normal","anomaly"]: return false
 for zone in data.get("visited",[]):
  if zone not in ZONES and zone!="Partyraum": return false
 if data.get("visited",[]).size()!=Array(data.get("visited",[])).reduce(func(acc,item):return acc if item in acc else acc+[item],[]).size(): return false
 streak=int(data.streak);best=int(data.get("best",0));errors=int(data.get("errors",0));rounds=int(data.get("rounds",0));seconds=float(data.get("seconds",0));current=REPLACEMENTS.get(data.current,data.current)
 visited.assign(data.get("visited",[]).map(func(zone):return "Party Raum" if zone=="Partyraum" else zone));deck.assign(data.get("deck",[]));bag.assign(data.get("bag",[]).map(func(id):return REPLACEMENTS.get(id,id)).reduce(func(acc,id):return acc if id in acc else acc+[id],[]));completed=streak==limit
 history=data.get("history",[]);rng.state=int(data.get("rng","1"))
 endless=endless_save
 if endless:
  lives=int(data.lives);round_time=float(data.get("round_time",0));detail=data.get("detail",{});over=bool(data.get("over",false))
  flawless=int(data.get("flawless",0));detail_row=int(data.get("detail_row",0));last_life_rounds=int(data.get("last_life_rounds",0))
  for key in tier_bags:tier_bags[key]=Array(data.tier_bags.get(key,[]))
 else:lives=LIVES;round_time=0;detail={};over=false;flawless=0;detail_row=0;last_life_rounds=0
 plan.clear()
 var saved_plan=data.get("plan",[])
 if saved_plan is Array and saved_plan.size()==GOAL and saved_plan.all(func(id):return id in valid_ids):plan.assign(saved_plan)
 horse_override=data.get("horse_override",false)==true and current=="horse_clown_hunt"
 if completed: current="none";horse_override=false
 return true

func _restore_endless(data: Dictionary, valid_ids: Array[String]) -> bool:
 for field in ["lives","round_time","flawless","detail_row","last_life_rounds"]:
  var value=data.get(field,-1)
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0:return false
 if int(data.lives)>LIVES or (int(data.lives)==0 and not bool(data.get("over",false))):return false
 if not data.get("detail",{}) is Dictionary or not data.get("tier_bags",{}) is Dictionary:return false
 for key in tier_bags:
  var stored=data.tier_bags.get(key,[])
  if not stored is Array:return false
  for id in stored:
   if id not in valid_ids:return false
 return true
