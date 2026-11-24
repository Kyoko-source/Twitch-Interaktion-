class_name NightwatchConfig
extends RefCounted

# Nightwatch Protocol: every tunable number of the camera mode lives here, so
# balancing never needs a search through the game logic.
# 5.6.0: nights 1-5 from 00:00 to 06:00. Anomalies change the rooms on the
# cameras and are fixed with a click; something waits at the door and in the
# vent, and the power runs down all night.

# One in-game hour in real seconds; a night is HOURS of them.
const HOUR:=80.0
const HOURS:=6
const NIGHTS:=5
# Per night:
#  drain:    power used per second, in percent, all night long
#  crawler / clown: how often the figures come, 0 (never) to 20 (relentless)
#  interval: seconds between new anomalies at 00:00 (randomised by +-JITTER);
#            it shrinks towards LATE_SPAWN of that by 06:00
#  active:   how many anomalies may be open at the same time
#  detect:   seconds one anomaly may stay unfound before the alarm starts
#  words / time: the generator restart
const NIGHT:=[
 {"drain":.12,"crawler":4,"clown":0,"interval":34.,"active":4,"detect":120.,"words":1,"time":20.},
 {"drain":.13,"crawler":6,"clown":5,"interval":30.,"active":4,"detect":105.,"words":2,"time":17.},
 {"drain":.14,"crawler":9,"clown":9,"interval":27.,"active":5,"detect":95.,"words":2,"time":14.},
 {"drain":.15,"crawler":12,"clown":13,"interval":24.,"active":5,"detect":85.,"words":3,"time":13.},
 {"drain":.16,"crawler":15,"clown":16,"interval":21.,"active":6,"detect":75.,"words":4,"time":12.},
]
const JITTER:=.25
const FIRST_ANOMALY:=18.0
const LATE_SPAWN:=.5
# The status line on every camera, by the number of unfound anomalies.
const STATUS:=["","WARNING – UNUSUAL ACTIVITY DETECTED","ALERT – ANOMALY LEVELS RISING","CRITICAL – ANOMALY THRESHOLD EXCEEDED"]
const STATUS_COLOURS:=[Color("d8f0d8"),Color("ffd24a"),Color("ff9a3a"),Color("ff3b2e")]
# From CRITICAL_COUNT open anomalies (or one left longer than "detect") the
# critical alarm runs: blinking, faster and faster. After CRITICAL_TIME the
# night is lost; the last CRITICAL_FLICKER seconds the lights flicker.
const CRITICAL_COUNT:=3
const CRITICAL_TIME:=25.0
const CRITICAL_FLICKER:=7.0
static func spawn_interval(night_index: int, seconds: float) -> float:
 return float(night(night_index).interval)*lerpf(1.,LATE_SPAWN,clampf(seconds/night_length(),0.,1.))
# What the night tells you at the start.
const BRIEFING:=[
 "Nacht 1. Halte bis 06:00 Uhr durch. Finde die Veränderungen auf den Kameras und klick sie im Vollbild an. Schau ab und zu links zur Tür – steht dort etwas, Tor runter (Leertaste).",
 "Nacht 2. Ab heute kommt auch etwas durch den Lüftungsschacht rechts. Sitzt es in der Öffnung, leuchte mit der Taschenlampe hinein (F).",
 "Nacht 3. Sie kommen öfter. Das Tor kostet 20 %, die Lampe 10 % – reicht der Strom nicht, tipp am Generator.",
 "Nacht 4. Mehr Anomalien gleichzeitig. Vergiss Tür und Schacht nicht.",
 "Nacht 5. Die letzte Nacht. Keiner von ihnen will dich bis 06:00 Uhr gehen lassen.",
]
static func night(index: int) -> Dictionary:
 return NIGHT[clampi(index,1,NIGHT.size())-1]
static func night_length() -> float:
 return HOUR*HOURS
static func ratio(level: int) -> float:
 return clampf(level/20.,0.,1.)

# Power, in percent. Closing the shutter and switching the torch on cost a
# fixed share at once.
const POWER_START:=100.0
const SHUTTER_COST:=20.0
const TORCH_COST:=10.0
# How long the torch burns once switched on, and how long it has to shine on
# the clown before it crawls away.
const TORCH_TIME:=3.0
const TORCH_REPEL:=.7
const TORCH_ENERGY:=7.0
# The shutter rolls up by itself this long after nothing is at the door.
const SHUTTER_HOLD:=6.0
# Screens and alarm by power level.
const FLICKER_LIGHT:=50.0
const ALARM:=20.0
const CRITICAL:=10.0
# At 0 % everything goes dark and the shutter rolls up; something comes for
# you after this many seconds unless the generator runs again first.
const BLACKOUT_MIN:=8.0
const BLACKOUT_MAX:=16.0
# A click into the picture that finds nothing locks clicking for a moment.
const MISS_LOCK:=1.5
# How far around a changed thing a click still counts (feed pixels).
const HIT_MARGIN:=34.0

# The figures at the door (NightwatchStalker) and in the vent (NightwatchVent)
# do not walk the cameras: they are simply there when you look. First visit,
# rest between visits and the time you have once one is there, by level.
static func first_visit(level: int) -> float:
 return lerpf(70.,25.,ratio(level))
static func rest(level: int, rng: RandomNumberGenerator) -> float:
 return lerpf(75.,18.,ratio(level))*rng.randf_range(.7,1.3)
static func grace(level: int) -> float:
 return lerpf(9.,4.,ratio(level))
static func door_wait(rng: RandomNumberGenerator) -> float:
 return rng.randf_range(5.,8.)

# Infrared lamp next to every camera, so dark rooms stay readable on screen.
const IR_ENERGY:=3.0
const IR_RANGE:=24.0
const IR_ANGLE:=62.0
# Night-vision look of the feeds: exposure, ambient light and fog.
const FEED_EXPOSURE:=1.6
const FEED_AMBIENT:=.8
const FEED_FOG:=.5
# Cameras: id, label, position, look-at point.
const CAMERAS:=[
 {"id":"empfang","label":"CAM 01 · EMPFANG","p":Vector3(-6.8,2.7,5.0),"at":Vector3(-8.7,1.2,9.0),"fov":74.},
 {"id":"halle","label":"CAM 02 · HALLE","p":Vector3(-9.6,3.8,-9.6),"at":Vector3(3.0,.8,-7.6),"fov":74.},
 {"id":"baellebad","label":"CAM 03 · BÄLLEBAD","p":Vector3(19.0,3.7,12.8),"at":Vector3(15.3,1.0,10.9),"fov":76.},
 {"id":"spielhalle","label":"CAM 04 · SPIELHALLE","p":Vector3(4.0,3.4,11.0),"at":Vector3(11.0,1.1,16.2),"fov":76.},
 {"id":"party_tisch","label":"CAM 05 · PARTY RAUM · TISCH","p":Vector3(7.9,3.5,-3.4),"at":Vector3(10.75,.8,-5.95),"fov":74.},
 {"id":"party_bar","label":"CAM 06 · PARTY RAUM · SNACKBAR","p":Vector3(17.5,3.6,-10.2),"at":Vector3(15.5,1.0,-1.2),"fov":74.},
 {"id":"kostuem","label":"CAM 07 · KOSTÜMFUNDUS","p":Vector3(18.6,2.9,-13.0),"at":Vector3(13.8,1.0,-16.8),"fov":76.},
 {"id":"wartung","label":"CAM 08 · WARTUNG","p":Vector3(-11.9,2.05,-3.1),"at":Vector3(-14.7,1.15,-5.25),"fov":76.},
 {"id":"kueche","label":"CAM 09 · KÜCHE","p":Vector3(-16.5,3.2,-29.7),"at":Vector3(-13.25,1.05,-27.75),"fov":76.},
 {"id":"kino","label":"CAM 10 · KINO","p":Vector3(-5.9,3.05,-25.85),"at":Vector3(.7,1.0,-30.0),"fov":76.},
]

static func camera_index(id: String) -> int:
 for i in range(CAMERAS.size()):
  if CAMERAS[i].id==id:return i
 return -1

# Generator words: short ones first, long ones in the later nights.
const WORDS_EASY:=["BALL","LAMPE","STROM","KABEL","TUER","RUTSCHE","KERZE","TORTE","PUPPE","HASE","LIFT","PFERD","KINO","NETZ","UHR","STERN"]
const WORDS_MEDIUM:=["SCHALTER","BATTERIE","KONFETTI","LUFTBALLON","SPANNUNG","KLETTERNETZ","GEBURTSTAG","SICHERUNG","MONITOR","KAMERA","NACHTWACHE","GENERATOR"]
const WORDS_HARD:=["STROMKREISLAUF","NOTSTROMAGGREGAT","UEBERWACHUNGSRAUM","KINDERPARADIES","SPANNUNGSREGLER","BAELLEBADBECKEN","SICHERUNGSKASTEN","KONTROLLMONITOR"]
static func words_for(night_index: int, rng: RandomNumberGenerator) -> Array:
 var count: int=int(night(night_index).words)
 var pool: Array=WORDS_EASY if night_index<=1 else WORDS_EASY+WORDS_MEDIUM if night_index<=3 else WORDS_MEDIUM+WORDS_HARD
 var out: Array=[]
 while out.size()<count:
  var word: String=pool[rng.randi_range(0,pool.size()-1)]
  if not word in out or out.size()>=pool.size():out.append(word)
 return out

# Kinds of change. None of them is a figure: the rooms themselves change.
const KINDS:={
 "missing":"Gegenstand fehlt",
 "floating":"Schwebender Gegenstand",
 "moved":"Gegenstand verschoben",
 "extra":"Zusätzlicher Gegenstand",
 "motion":"Gegenstand bewegt sich",
 "light":"Fremdes Licht",
 "balls":"Schwebende Bälle",
 "room":"Raum verändert",
}
const KIND_ORDER:=["missing","floating","moved","extra","motion","light","balls","room"]
# Kinds placed on a floor spot or a whole area instead of one object.
const SPOT_KINDS:=["light","balls","room"]

# Rooms the anomalies happen in. Each area names the camera that shows it, the
# objects that can change (node spec, German label, allowed kinds) and floor
# spots for light changes; "special" lists kinds only this area has.
#   node spec: "prop:<key>"       entry in PlayWorld.props
#              "prop:<key>/*"     one child of that prop group
#              "name:<NodeName>"  first node of that name in the world
const OBJ:=["missing","floating","moved","extra","motion"]
const FIXED:=["missing","motion"]
const ROOMS:=[
 {"id":"empfang","name":"Empfang","areas":[
  {"id":"theke","name":"Empfangstheke","camera":"empfang","spots":[Vector3(-6.6,0,8.6)],"objects":[
   ["name:ReceptionPC","der Computer",["missing","floating","moved","motion"]],
   ["name:EmptyVintageGumballDispenser","der Kaugummiautomat",OBJ],
   ["name:ReceptionOfficeChair","der Bürostuhl",OBJ]]},
  {"id":"wand","name":"Wand mit Pinnwand","camera":"empfang","spots":[Vector3(-8.9,0,5.6)],"objects":[
   ["prop:clock","die Wanduhr",FIXED],
   ["prop:reception_noticeboard","die Pinnwand",FIXED],
   ["prop:reception_bin","der Mülleimer",OBJ]]},
  {"id":"wartebank","name":"Wartebank","camera":"empfang","spots":[Vector3(-8.2,0,13.2)],"objects":[
   ["name:ReceptionBenchBelongings","die Sachen auf der Bank",OBJ],
   ["name:NeglectedAspidistra","die Topfpflanze",OBJ]]}]},
 {"id":"halle","name":"Halle","areas":[
  {"id":"auto","name":"Spielauto","camera":"halle","spots":[Vector3(2.6,0,-6.0)],"objects":[
   ["prop:car","das rote Spielauto",OBJ]]},
  {"id":"ausgaenge","name":"Ausgangstüren","camera":"halle","spots":[Vector3(0.0,0,-10.2)],"objects":[
   ["name:StockedShelf","das Regal",["missing","floating","moved","motion"]],
   ["name:LostPropertyCubbies","die Fundsachen-Fächer",["missing","floating","moved","motion"]]]},
  {"id":"spielwand","name":"Spielwand","camera":"halle","spots":[Vector3(-3.4,0,-4.0)],"objects":[
   ["name:ForgottenActivityBoard","die Spielwand",["missing","floating","motion"]]]}]},
 {"id":"baellebad","name":"Bällebad","areas":[
  {"id":"krokodil","name":"Krokodil","camera":"baellebad","spots":[Vector3(14.6,0,11.6)],"special":["balls"],"objects":[
   ["prop:inflatable","das aufblasbare Krokodil",["missing","floating","moved","motion"]],
   ["name:ConnectedInflationBlower","das Gebläse",OBJ]]},
  {"id":"lampe","name":"Inspektionslampe","camera":"baellebad","spots":[Vector3(17.0,0,10.4)],"objects":[
   ["name:BracedInspectionLamp","die Baulampe",OBJ]]}]},
 {"id":"spielhalle","name":"Spielhalle","areas":[
  {"id":"automaten","name":"Spielautomaten","camera":"spielhalle","spots":[Vector3(7.0,0,14.2)],"objects":[
   ["name:Arcade_arcade","der linke Automat",["missing","floating","moved","motion"]],
   ["name:Arcade_orbit","der Orbit-Automat",["missing","floating","moved","motion"]]]},
  {"id":"preise","name":"Preisschrank","camera":"spielhalle","spots":[Vector3(10.2,0,14.4)],"objects":[
   ["name:ArcadePrizeCabinet","der Preisschrank",["missing","floating","moved","motion"]],
   ["name:ArcadeTokenExchange","der Münzwechsler",OBJ]]}]},
 {"id":"party","name":"Party Raum","areas":[
  {"id":"tisch","name":"Geburtstagstisch","camera":"party_tisch","spots":[Vector3(9.0,0,-5.4)],"objects":[
   ["prop:party_table","der Geburtstagstisch",["missing","floating","moved"]],
   ["prop:chairs/*","ein Stuhl",OBJ],
   ["prop:balloons/*","ein Ballon",["missing","moved","extra","motion"]]]},
  {"id":"basteltisch","name":"Basteltisch","camera":"party_tisch","spots":[Vector3(12.2,0,-5.4)],"objects":[
   ["name:RoundActivityTable","der runde Basteltisch",["missing","floating","moved"]],
   ["name:KidStool","der Kinderhocker",OBJ]]},
  {"id":"musik","name":"Musikecke","camera":"party_bar","spots":[Vector3(17.4,0,-4.6)],"objects":[
   ["name:PartyMusicBox","die Musikbox",OBJ],
   ["name:PartyServiceTrolley","der Servierwagen",OBJ]]},
  {"id":"snackbar","name":"Snackbar","camera":"party_bar","spots":[Vector3(13.0,0,-1.2)],"objects":[
   ["name:CrustedSlushMachineCherry","die Slush-Maschine",OBJ],
   ["name:NapkinDispenser","der Serviettenspender",OBJ]]}]},
 {"id":"kostuem","name":"Kostümfundus","areas":[
  {"id":"stange","name":"Kostümstange","camera":"kostuem","spots":[Vector3(14.4,0,-16.6)],"objects":[
   ["name:OpenCostumeTrunk","die Kostümtruhe",OBJ]]},
  {"id":"naehecke","name":"Nähecke","camera":"kostuem","spots":[Vector3(13.4,0,-14.0)],"objects":[
   ["name:SewingMachine","die Nähmaschine",OBJ]]}]},
 {"id":"wartung","name":"Wartung","areas":[
  {"id":"werkbank","name":"Werkbank","camera":"wartung","spots":[Vector3(-14.6,0,-5.0)],"objects":[
   ["name:GroundedRepairBench","die Werkbank",["missing","floating","moved","motion"]],
   ["name:MountedToolBoard","die Werkzeugwand",FIXED]]},
  {"id":"putzwagen","name":"Putzwagen","camera":"wartung","spots":[Vector3(-12.4,0,-5.4)],"objects":[
   ["name:JanitorServiceCart","der Putzwagen",OBJ],
   ["name:LabelledSpareParts","die Ersatzteile",OBJ]]},
  {"id":"stromkasten","name":"Stromkasten","camera":"wartung","spots":[Vector3(-15.2,0,-3.4)],"objects":[
   ["name:WallMountedPowerBox","der Stromkasten",FIXED]]}]},
 {"id":"kueche","name":"Küche","areas":[
  {"id":"herd","name":"Herd","camera":"kueche","spots":[Vector3(-14.0,0,-29.6)],"objects":[
   ["name:CookingPot","der Kochtopf",OBJ]]},
  {"id":"spuele","name":"Spüle","camera":"kueche","spots":[Vector3(-15.4,0,-28.0)],"objects":[
   ["name:KitchenDryingRack","das Abtropfgestell",OBJ]]},
  {"id":"vorrat","name":"Vorratsregal","camera":"kueche","spots":[Vector3(-12.0,0,-27.2)],"objects":[
   ["name:KitchenProduceCrate","die Gemüsekiste",OBJ],
   ["name:StackedPrepBowl","die Schüsseln",OBJ],
   ["name:KitchenDryStorage","das Vorratsregal",["missing","moved","motion"]]]}]},
 {"id":"kino","name":"Kino","areas":[
  {"id":"sitze","name":"Sitzreihen","camera":"kino","spots":[Vector3(-2.2,0,-28.8)],"objects":[
   ["name:CinemaSeat_-28_-166","ein Kinosessel",OBJ],
   ["name:CinemaSeat_-13_-155","ein Kinosessel",OBJ]]},
  {"id":"popcorn","name":"Popcornwagen","camera":"kino","spots":[Vector3(1.0,0,-27.4)],"objects":[
   ["name:ForgottenPopcornTrolley","der Popcornwagen",OBJ]]}]},
]

static func area(room_id: String, area_id: String) -> Dictionary:
 for item in room(room_id).get("areas",[]):
  if item.id==area_id:return item
 return {}

static func room(id: String) -> Dictionary:
 for item in ROOMS:
  if item.id==id:return item
 return {}
