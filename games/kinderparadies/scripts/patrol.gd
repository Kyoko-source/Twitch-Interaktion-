class_name PatrolState
extends RefCounted

const GOAL := 13
const ZONES := ["Empfang", "Bällebad", "Partyraum", "Wartungsgang"]
const ANOMALIES := [
 {"id":"chair_ceiling","name":"Die Stühle hängen an der Decke.","zone":"Partyraum"},
 {"id":"chairs_missing","name":"Alle Stühle im Partyraum sind verschwunden.","zone":"Partyraum"},
 {"id":"chair_stack","name":"Die Stühle stehen übereinander.","zone":"Partyraum"},
 {"id":"balls_float","name":"Bälle schweben über dem Bällebad.","zone":"Bällebad"},
 {"id":"balls_red","name":"Alle Bälle im Bällebad sind rot.","zone":"Bällebad"},
 {"id":"ball_giant","name":"Ein riesiger Ball steckt im Bällebad.","zone":"Bällebad"},
 {"id":"ball_moves","name":"Ein Ball rollt von selbst durch den Gang.","zone":"Bällebad"},
 {"id":"balls_missing","name":"Das Bällebad ist leer.","zone":"Bällebad"},
 {"id":"mural_upside","name":"Das Wandbild im Wartungsgang steht auf dem Kopf.","zone":"Wartungsgang"},
 {"id":"mural_mirror","name":"Das Wandbild ist gespiegelt: Der Mond steht rechts.","zone":"Wartungsgang"},
 {"id":"mural_red","name":"Das Wandbild leuchtet blutrot.","zone":"Wartungsgang"},
 {"id":"mural_missing","name":"Das große Wandbild ist verschwunden.","zone":"Wartungsgang"},
 {"id":"clock_reverse","name":"Die Uhr am Empfang läuft rückwärts.","zone":"Empfang"},
 {"id":"clock_fast","name":"Die Uhr dreht sich viel zu schnell.","zone":"Empfang"},
 {"id":"car_moves","name":"Das Spielauto fährt von selbst.","zone":"Empfang"},
 {"id":"car_giant","name":"Das Spielauto ist riesig geworden.","zone":"Empfang"},
 {"id":"car_float","name":"Das Spielauto schwebt über dem Boden.","zone":"Empfang"},
 {"id":"car_missing","name":"Das rote Spielauto am Empfang fehlt.","zone":"Empfang"},
 {"id":"stars_upside","name":"Die Wandsterne stehen auf dem Kopf.","zone":"Wartungsgang"},
 {"id":"footprints","name":"Dunkle Fußspuren führen in den Wartungsgang.","zone":"Wartungsgang"},
 {"id":"lights_red","name":"Alle Deckenlampen leuchten rot.","zone":"Empfang"},
 {"id":"party_dark","name":"Die Beleuchtung im Partyraum ist ausgefallen.","zone":"Partyraum"},
 {"id":"balloons_many","name":"Ein ganzer Schwarm Ballons füllt den Partyraum.","zone":"Partyraum"},
 {"id":"balloons_floor","name":"Die Ballons hängen nach unten und liegen am Boden.","zone":"Partyraum"},
 {"id":"slide_green","name":"Die rote Rutsche ist plötzlich grün.","zone":"Bällebad"},
 {"id":"slide_missing","name":"Die große rote Rutsche fehlt.","zone":"Bällebad"},
 {"id":"net_missing","name":"Die Sicherheitsnetze an der Kletteranlage fehlen.","zone":"Bällebad"},
 {"id":"star_giant","name":"Ein übergroßer Stern hängt im Wartungsgang.","zone":"Wartungsgang"},
 {"id":"extinguisher_float","name":"Der Feuerlöscher schwebt an der Wand.","zone":"Wartungsgang"},
 {"id":"hours_wrong","name":"Die Öffnungszeiten am Empfang lauten 03:33–03:33.","zone":"Empfang"},
 {"id":"blood_trail","name":"Eine frische Blutspur zieht sich durch den Hauptgang.","zone":"Empfang"},
 {"id":"bloody_hands","name":"Blutige Handabdrücke bedecken die Wand im Wartungsgang.","zone":"Wartungsgang"},
 {"id":"blood_pool","name":"Eine große Blutlache liegt unter dem Geburtstagstisch.","zone":"Partyraum"},
 {"id":"mural_bleeds","name":"Aus dem Wandbild laufen breite Blutspuren.","zone":"Wartungsgang"},
 {"id":"bunny_ceiling","name":"Der Stoffhase hängt kopfüber vor der Decke statt auf seiner Bank zu sitzen.","zone":"Empfang"},
 {"id":"heavy_mist","name":"Der Nebel ist ungewöhnlich dicht und füllt den ganzen Raum.","zone":"Bällebad"}
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
 if completed or visited.size()!=ZONES.size(): return {"accepted":false}
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
  if zone not in ZONES: return false
 if data.get("visited",[]).size()!=Array(data.get("visited",[])).reduce(func(acc,item):return acc if item in acc else acc+[item],[]).size(): return false
 streak=int(data.streak);best=int(data.get("best",0));errors=int(data.get("errors",0));rounds=int(data.get("rounds",0));seconds=float(data.get("seconds",0));current=data.current
 visited.assign(data.get("visited",[]));deck.assign(data.get("deck",[]));bag.assign(data.get("bag",[]));completed=streak==GOAL
 history=data.get("history",[]);rng.state=int(data.get("rng","1"))
 return true
