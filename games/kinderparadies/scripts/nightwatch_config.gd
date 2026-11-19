class_name NightwatchConfig
extends RefCounted

# Nightwatch Protocol (4.15.0): every tunable number of the camera mode lives
# here, so balancing never needs a search through the game logic.

# Difficulty rises one stage every STAGE_SECONDS of survived time.
const STAGE_SECONDS:=75.0
const MAX_STAGE:=12
# Per stage (index 0 = stage 1; the last row repeats beyond it).
#  interval: seconds between new anomalies (randomised by +-JITTER)
#  active:   how many anomalies may be open at the same time
#  detect:   seconds to report an anomaly before the shift ends
#  drain:    power used per second, in percent
const STAGES:=[
 {"interval":34.,"active":1,"detect":110.,"drain":.40},
 {"interval":31.,"active":1,"detect":100.,"drain":.44},
 {"interval":28.,"active":2,"detect":95.,"drain":.48},
 {"interval":26.,"active":2,"detect":90.,"drain":.52},
 {"interval":24.,"active":2,"detect":85.,"drain":.56},
 {"interval":22.,"active":3,"detect":80.,"drain":.60},
 {"interval":20.,"active":3,"detect":75.,"drain":.64},
 {"interval":18.,"active":3,"detect":70.,"drain":.68},
 {"interval":16.,"active":4,"detect":66.,"drain":.72},
 {"interval":15.,"active":4,"detect":62.,"drain":.76},
 {"interval":14.,"active":4,"detect":58.,"drain":.80},
 {"interval":13.,"active":5,"detect":55.,"drain":.84},
]
const JITTER:=.25
const FIRST_ANOMALY:=18.0
# Generator repairs: words to type and the time for all of them, by stage.
const QTE:=[
 {"words":1,"time":20.},
 {"words":2,"time":18.},
 {"words":2,"time":15.},
 {"words":3,"time":14.},
 {"words":4,"time":12.},
 {"words":5,"time":10.},
 {"words":5,"time":10.},
 {"words":6,"time":11.},
 {"words":6,"time":10.},
 {"words":7,"time":11.},
 {"words":7,"time":10.5},
 {"words":8,"time":11.},
]
const MAX_WRONG:=3
const POWER_START:=100.0
# Screens and alarm by power level (percent).
const FLICKER_LIGHT:=50.0
const ALARM:=20.0
const CRITICAL:=10.0
# Points.
const POINTS_REPORT:=100
const POINTS_COMBO:=25
const POINTS_COMBO_MAX:=10
const POINTS_GENERATOR:=40
const POINTS_PER_SECOND:=1.0

# Words for the generator: short ones first, long ones from stage 5.
const WORDS_EASY:=["BALL","LAMPE","STROM","KABEL","TUER","RUTSCHE","KERZE","TORTE","PUPPE","HASE","LIFT","PFERD","KINO","NETZ","UHR","STERN"]
const WORDS_MEDIUM:=["SCHALTER","BATTERIE","KONFETTI","LUFTBALLON","SPANNUNG","KLETTERNETZ","GEBURTSTAG","SICHERUNG","MONITOR","KAMERA","NACHTWACHE","GENERATOR"]
const WORDS_HARD:=["STROMKREISLAUF","NOTSTROMAGGREGAT","UEBERWACHUNGSRAUM","KINDERPARADIES","SPANNUNGSREGLER","BAELLEBADBECKEN","SICHERUNGSKASTEN","KONTROLLMONITOR"]

# Report categories. Only kinds the mode can actually produce are listed.
const KINDS:={
 "missing":"Gegenstand fehlt",
 "floating":"Schwebender Gegenstand",
 "moved":"Gegenstand verschoben",
 "extra":"Zusätzlicher Gegenstand",
 "visitor":"Besucher im Raum",
 "motion":"Ungewöhnliche Bewegung",
 "apparition":"Erscheinung oder Kreatur",
 "light":"Veränderung der Beleuchtung",
}
const KIND_ORDER:=["missing","floating","moved","extra","visitor","motion","apparition","light"]
# Kinds that need a spot on the floor instead of an object.
const SPOT_KINDS:=["visitor","apparition","light"]

# Infrared lamp next to every camera, so dark rooms stay readable on screen.
const IR_ENERGY:=1.6
const IR_RANGE:=16.0
const IR_ANGLE:=48.0
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

# Rooms for the report book. Each area names the camera that shows it, the
# objects that can change (node spec, German label, allowed kinds) and floor
# spots for visitors, apparitions and light changes.
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
  {"id":"krokodil","name":"Krokodil","camera":"baellebad","spots":[Vector3(14.6,0,11.6)],"objects":[
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

static func stage_of(seconds: float) -> int:
 return clampi(1+floori(seconds/STAGE_SECONDS),1,MAX_STAGE)

static func stage(index: int) -> Dictionary:
 return STAGES[clampi(index,1,STAGES.size())-1]

static func qte(index: int) -> Dictionary:
 return QTE[clampi(index,1,QTE.size())-1]

static func words_for(index: int, rng: RandomNumberGenerator) -> Array:
 var count: int=int(qte(index).words)
 var pool: Array=WORDS_EASY if index<=2 else WORDS_EASY+WORDS_MEDIUM if index<=4 else WORDS_MEDIUM+WORDS_HARD if index>=8 else WORDS_MEDIUM+WORDS_HARD.slice(0,3)
 var out: Array=[]
 while out.size()<count:
  var word: String=pool[rng.randi_range(0,pool.size()-1)]
  if not word in out or out.size()>=pool.size():out.append(word)
 return out

static func camera_index(id: String) -> int:
 for i in range(CAMERAS.size()):
  if CAMERAS[i].id==id:return i
 return -1

static func room(id: String) -> Dictionary:
 for item in ROOMS:
  if item.id==id:return item
 return {}

static func area(room_id: String, area_id: String) -> Dictionary:
 for item in room(room_id).get("areas",[]):
  if item.id==area_id:return item
 return {}
