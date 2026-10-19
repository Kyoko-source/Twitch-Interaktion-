class_name PatrolState
extends RefCounted

const GOAL := 13
const REPLACEMENTS := {"clock_reverse":"reception_peeker","car_moves":"reception_charge","car_float":"reception_queue","hours_wrong":"pit_hands","bunny_watches":"frame_stalker","balls_red":"slide_crawler","ball_moves":"party_portrait","slide_green":"party_guests","slide_missing":"cake_mouth","croc_breathes":"corridor_crossing","chairs_missing":"service_pursuit","chair_stack":"service_ceiling","blood_pool":"fridge_occupant","mural_upside":"pot_arms","mural_mirror":"kitchen_double","mural_red":"screen_visitor","stars_upside":"cinema_last_row","footprints":"vent_strike","extinguisher_float":"tube_chase","bloody_hands":"tube_window_hands"}
const ZONES := ["Empfang", "Bällebad", "Party Raum", "Wartungsgang", "Küche", "Kino"]
const ANOMALIES := [
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
 {"id":"car_giant","name":"Das Spielauto ist riesig geworden.","zone":"Empfang"},
 {"id":"reception_queue","name":"Drei reglose Besucher warten mit verdrehten Köpfen vor dem Empfang.","zone":"Empfang"},
 {"id":"car_missing","name":"Das rote Spielauto am Empfang fehlt.","zone":"Empfang"},
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
var history: Array = []

func start(seed_value: int = 0) -> void:
 rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
 streak=0;best=0;errors=0;rounds=0;seconds=0;current="none";completed=false
 visited.clear();deck.clear();bag.clear();history.clear()

func _shuffle(items: Array[String]) -> void:
 for i in range(items.size()-1,0,-1):
  var j := rng.randi_range(0,i)
  var temp := items[i];items[i]=items[j];items[j]=temp

func _next() -> void:
 visited.clear()
 if deck.is_empty():
  deck.assign(["normal","normal","normal","normal","anomaly","anomaly","anomaly","anomaly","anomaly"])
  _shuffle(deck)
 if deck.pop_back()=="normal":
  current="none"
 else:
  if bag.is_empty():
   for anomaly in ANOMALIES: bag.append(anomaly.id)
   _shuffle(bag)
  current=bag.pop_back()

func inspect(zone: String) -> bool:
 if zone in ZONES and zone not in visited and not completed:
  visited.append(zone)
  return true
 return false

func decide(red: bool) -> Dictionary:
 if completed: return {"accepted":false}
 var anomaly := current!="none"
 var correct := red==anomaly
 var detail := describe(current)
 rounds+=1
 if correct: streak+=1;best=maxi(best,streak)
 else: streak=0;errors+=1
 completed=streak==GOAL
 var result := {"accepted":true,"correct":correct,"anomaly":anomaly,"detail":detail,"streak":streak,"completed":completed}
 history.append({"anomaly":current,"red":red,"correct":correct})
 if not completed: _next()
 return result

static func describe(id: String) -> String:
 for anomaly in ANOMALIES:
  if anomaly.id==id: return anomaly.zone+": "+anomaly.name
 return "Es gab keine Anomalie. Der Rundgang war normal."

func serialize() -> Dictionary:
 return {"version":1,"streak":streak,"best":best,"errors":errors,"rounds":rounds,"seconds":seconds,"current":current,"visited":visited,"deck":deck,"bag":bag,"completed":completed,"history":history,"rng":str(rng.state)}

func restore(data: Dictionary) -> bool:
 var valid_ids: Array[String]=["none"]
 for anomaly in ANOMALIES: valid_ids.append(anomaly.id)
 valid_ids.append_array(REPLACEMENTS.keys())
 if data.get("version")!=1 or data.get("current","") not in valid_ids: return false
 if int(data.get("streak",-1))<0 or int(data.get("streak",99))>GOAL: return false
 if not data.get("visited",[]) is Array or not data.get("deck",[]) is Array or not data.get("bag",[]) is Array: return false
 if not data.get("history",[]) is Array: return false
 for field in ["streak","best","errors","rounds","seconds"]:
  var value=data.get(field,0)
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0: return false
 if int(data.get("best",0))>GOAL or not str(data.get("rng","1")).is_valid_int(): return false
 for id in data.get("bag",[]):
  if id not in valid_ids: return false
 for item in data.get("deck",[]):
  if item not in ["normal","anomaly"]: return false
 for zone in data.get("visited",[]):
  if zone not in ZONES and zone!="Partyraum": return false
 if data.get("visited",[]).size()!=Array(data.get("visited",[])).reduce(func(acc,item):return acc if item in acc else acc+[item],[]).size(): return false
 streak=int(data.streak);best=int(data.get("best",0));errors=int(data.get("errors",0));rounds=int(data.get("rounds",0));seconds=float(data.get("seconds",0));current=REPLACEMENTS.get(data.current,data.current)
 visited.assign(data.get("visited",[]).map(func(zone):return "Party Raum" if zone=="Partyraum" else zone));deck.assign(data.get("deck",[]));bag.assign(data.get("bag",[]).map(func(id):return REPLACEMENTS.get(id,id)));completed=streak==GOAL
 history=data.get("history",[]);rng.state=int(data.get("rng","1"))
 return true
