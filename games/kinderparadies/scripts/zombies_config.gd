class_name ZombiesConfig
extends RefCounted

# After Play: Partynacht (5.0.0), the round-based wave survival mode.
# Every number, list and place of the mode lives here.

# ---------------------------------------------------------------- rounds
const FIRST_ELITES:=5
const FIRST_BOSS:=10
const BOSS_EVERY:=5
const REALITY_FROM:=15
const MULTI_ELITES:=20
const NIGHTMARE_FROM:=25
const HELL_FROM:=30
const MAX_ALIVE:=26
const ROUND_BREAK:=9.0
static func enemies_in_round(r: int) -> int:
	return int(6+r*3.2+pow(maxf(r-8,0),1.35))
static func health(r: int) -> float:
	return 120.*pow(1.105,mini(r,45)-1)+maxf(r-45,0)*900.
static func speed(r: int) -> float:
	return minf(1.9+r*.16,4.6)
static func spawn_gap(r: int) -> float:
	return maxf(2.2-r*.07,.35)
static func elite_chance(r: int) -> float:
	return 0. if r<FIRST_ELITES else minf(.05+(r-FIRST_ELITES)*.012,.32)
static func damage(r: int) -> float:
	return 26.+minf(r,40)*1.1

# ---------------------------------------------------------------- points
const POINTS_HIT:=10
const POINTS_KILL:=60
const POINTS_HEADSHOT_KILL:=110
const POINTS_MELEE_KILL:=130
const POINTS_ELITE:=300
const POINTS_BOSS:=2500
const POINTS_ROUND:=90
const CHAIN_WINDOW:=2.6
const START_POINTS:=500

# ---------------------------------------------------------------- player
const PLAYER_HEALTH:=100.0
const REGEN_DELAY:=4.0
const REGEN_RATE:=28.0
const MELEE_DAMAGE:=150.0
const PERK_LIMIT:=4

# ---------------------------------------------------------------- enemies
# id: model, scale, health factor, speed factor, damage factor, points, role
const ENEMIES:={
	"party":{"name":"Partykind","model":"res://assets/zombies-v500/party-zombie.glb","scale":.86,"hp":1.,"speed":1.,"dmg":1.,"role":"runner"},
	"party_b":{"name":"Partykind","model":"res://assets/zombies-v500/party-zombie-b.glb","scale":.84,"hp":1.,"speed":1.05,"dmg":1.,"role":"runner"},
	"sprinter":{"name":"Luftschlangen-Sprinter","model":"res://assets/zombies-v500/party-zombie-b.glb","scale":.8,"hp":.6,"speed":1.75,"dmg":.8,"role":"sprinter"},
	"crawler":{"name":"Krabbelkind","model":"res://assets/zombies-v500/party-zombie.glb","scale":.86,"hp":.75,"speed":.85,"dmg":.9,"role":"crawler"},
	"jumper":{"name":"Hüpfburg-Springer","model":"res://assets/zombies-v500/party-zombie.glb","scale":.9,"hp":1.1,"speed":1.15,"dmg":1.2,"role":"jumper","elite":true},
	"spitter":{"name":"Konfetti-Spucker","model":"res://assets/visitors-v421/visitor-split.glb","scale":.95,"hp":1.3,"speed":.8,"dmg":.7,"role":"spitter","elite":true},
	"screamer":{"name":"Kreischerin","model":"res://assets/visitors-v421/visitor-hooded.glb","scale":1.,"hp":1.6,"speed":.9,"dmg":.8,"role":"screamer","elite":true},
	"phase":{"name":"Flackerkind","model":"res://assets/visitors-v421/visitor-ragged.glb","scale":.95,"hp":1.8,"speed":1.2,"dmg":1.3,"role":"teleporter","elite":true},
	"tank":{"name":"Plüsch-Koloss","model":"res://assets/hero/stitched-rabbit.glb","scale":1.9,"hp":6.,"speed":.6,"dmg":2.,"role":"tank","elite":true},
	"alien":{"name":"Riss-Mutant","model":"res://assets/zombies-v500/party-zombie-b.glb","scale":1.05,"hp":2.4,"speed":1.3,"dmg":1.4,"role":"alien","elite":true},
}
const ELITES_BY_ROUND:=[[5,["jumper","spitter"]],[8,["screamer"]],[12,["phase","tank"]],[15,["alien"]]]
# Bosses rotate; each has phases at 66 % and 33 % health.
const BOSSES:=[
	{"id":"marell","name":"MARELL, DER KOCH DER LETZTEN TORTE","model":"res://assets/clown-v420/clown-desktop.glb","scale":2.3,"hp":42.,"speed":.75,"attacks":["charge","summon","shockwave"]},
	{"id":"titan","name":"DER PLÜSCH-TITAN","model":"res://assets/einsmarello-v460/einsmarello-plush.glb","scale":3.4,"hp":60.,"speed":.55,"attacks":["shockwave","summon","stomp"]},
	{"id":"croc","name":"DAS MUTIERTE KROKODIL","model":"res://assets/creatures/night-crocodile-v4.glb","scale":1.3,"hp":50.,"speed":.9,"attacks":["charge","spit","shockwave"]},
	{"id":"hunter","name":"DER GEBURTSTAGSJÄGER","model":"res://assets/celebration-v3813/celebration-rabbit.glb","scale":2.4,"hp":46.,"speed":1.05,"attacks":["teleport","charge","summon"]},
]

# ---------------------------------------------------------------- weapons
# id, name, frame, damage, rpm, magazine, reserve, reload s, spread deg,
# pellets, recoil, headshot x, price (0 = box only), rarity, accent, special
const WEAPONS:=[
	["p9","P-9 Knochenbeißer","pistol",42,330,8,64,1.3,1.6,1,.6,2.,0,"common",Color("8a8f96"),""],
	["doppelzahn","Doppelzahn .45","pistol",85,240,7,49,1.4,1.8,1,1.1,2.2,600,"common",Color("6a4a2a"),""],
	["grablicht","Grablicht Auto-Pistol","pistol",36,780,18,108,1.5,2.6,1,.5,1.8,900,"uncommon",Color("4fd18a"),""],
	["marell","Marell's Smile","pistol",58,520,24,144,2.0,2.2,1,.6,2.4,0,"rare",Color("d8433f"),"dual"],
	["totenglocke","Totenglocke Magnum","revolver",210,150,6,36,2.2,1.2,1,1.8,2.6,0,"uncommon",Color("c9a25a"),""],
	["schaedelrichter","Schädelrichter Revolver","revolver",320,120,6,42,2.4,1.,1,2.2,3.,0,"rare",Color("e2dccf"),""],
	["k12","K-12 Ripper","smg",48,820,30,180,1.9,3.,1,.55,1.8,1200,"common",Color("b5462e"),""],
	["neon_wasp","Neon Wasp","smg",44,960,32,192,1.8,3.4,1,.5,1.7,0,"uncommon",Color("f2e24a"),""],
	["vx9","VX-9 Splitter","smg",62,720,30,210,2.0,2.8,1,.6,1.9,0,"uncommon",Color("5d8fd6"),""],
	["kindergrab","Kindergrab SMG","smg",72,880,36,216,2.1,3.,1,.6,1.9,0,"rare",Color("ff8cc8"),""],
	["phase_runner","Phase Runner SMG","smg",80,1000,40,240,1.7,2.6,1,.5,2.,0,"epic",Color("8a5cff"),"phase"],
	["ar47","AR-47 Ruin","rifle",95,600,30,210,2.4,2.,1,.85,2.,1400,"common",Color("7b5b32"),""],
	["m13","M13 Phantom","rifle",88,720,30,240,2.2,1.6,1,.7,2.1,0,"uncommon",Color("9aa3ad"),""],
	["xr88","XR-88 Flood","rifle",110,680,36,252,2.5,1.8,1,.8,2.1,0,"rare",Color("3fb6d1"),""],
	["void_carbine","Void Carbine","rifle",130,620,30,240,2.3,1.4,1,.75,2.3,0,"epic",Color("3a2a6a"),"void"],
	["afterburn","Afterburn Rifle","rifle",120,600,30,210,2.4,1.7,1,.8,2.,0,"rare",Color("ff6a1a"),"fire"],
	["red_static","Red Static MK1","rifle",140,560,28,224,2.4,1.5,1,.8,2.2,0,"epic",Color("ff2a2a"),"shock"],
	["pumpgrave","Pumpgrave 12","shotgun",58,75,6,48,2.8,7.,8,1.9,1.5,1500,"common",Color("6e3f22"),""],
	["double_funeral","Double Funeral","shotgun",70,200,2,40,2.2,8.,10,2.4,1.5,0,"uncommon",Color("2a2a2a"),""],
	["meatstorm","Meatstorm Auto-Shotgun","shotgun",52,300,12,96,3.0,7.5,8,1.6,1.4,0,"rare",Color("b02838"),""],
	["specter_breach","Specter Breach","shotgun",88,150,8,64,2.6,5.5,9,1.7,1.6,0,"epic",Color("a6e9ff"),"shock"],
	["titan_maw","Titan Maw","lmg",120,560,80,320,4.6,3.,1,.9,1.9,2500,"uncommon",Color("4a5a3a"),""],
	["bunkerjaw","Bunkerjaw LMG","lmg",105,700,100,400,5.0,3.4,1,.85,1.8,0,"rare",Color("707a52"),""],
	["oblivion","MG-X Oblivion","lmg",150,640,90,360,4.8,2.8,1,.9,2.,0,"epic",Color("1c1c24"),"void"],
	["rotting_sun","Rotting Sun LMG","lmg",135,600,75,300,4.4,3.,1,.9,2.,0,"epic",Color("d6a020"),"fire"],
	["ashline","Ashline DMR","rifle",260,260,15,120,2.6,.8,1,1.2,2.8,1800,"uncommon",Color("5a5048"),""],
	["static_fang","Static Fang Burst Rifle","rifle",150,900,24,192,2.3,1.,1,.7,2.6,0,"rare",Color("61f2ff"),"burst"],
	["night_needle","Night Needle","sniper",650,55,5,40,3.2,.25,1,2.6,4.,2200,"uncommon",Color("2b3a55"),"pierce"],
	["widowmaker","Widowmaker Zero","sniper",1100,48,6,42,3.4,.2,1,3.,5.,0,"epic",Color("d0d0d8"),"pierce"],
	["rift_cannon","Rift Cannon","rift",900,90,8,40,3.6,.5,1,2.4,1.,0,"legendary",Color("44ff8a"),"rift"],
]
const RARITY_WEIGHT:={"common":10.,"uncommon":7.,"rare":4.,"epic":1.6,"legendary":.45}
const RARITY_COLOR:={"common":Color("cfd2d6"),"uncommon":Color("7ce08a"),"rare":Color("5ab3ff"),"epic":Color("c27bff"),"legendary":Color("ffb340")}
const START_WEAPON:="p9"
const AMMO_PRICE:={"common":250,"uncommon":400,"rare":650,"epic":1000,"legendary":2500}
const RIFT_REFILLS:=2
const BOX_PRICE:=950
const BOX_USES_BEFORE_MOVE:=6
const BOX_TROLL_CHANCE:=.06
const UPGRADE_PRICE:=[5000,9000,15000]
const UPGRADE_DAMAGE:=[1.,1.9,2.9,4.2]
const UPGRADE_MAG:=[1.,1.5,1.75,2.]
const UPGRADE_NAMES:=["","Albtraum-veredelt","Fleischgeschmiedet","Realitätszerreißer"]
const UPGRADE_ELEMENT:=["","fire","shock","void"]

# ---------------------------------------------------------------- perks
# id, name, price, colour, short description
const PERKS:=[
	["blutdurst","Blutdurst",2000,Color("c0182a"),"Doppelter Nahkampfschaden"],
	["todesatem","Todesatem",1500,Color("6fd6c2"),"Leben regeneriert doppelt so schnell"],
	["hoellenlauf","Höllenlauf",2000,Color("ff7a1a"),"Schneller laufen und rennen"],
	["eiserne_rippen","Eiserne Rippen",2500,Color("b9b9c4"),"Leben auf 160"],
	["leichenfinger","Leichenfinger",3000,Color("9be04a"),"Doppelt so schnell nachladen"],
	["leerer_blick","Leerer Blick",1500,Color("e8e8f0"),"Weniger Rückstoß und Streuung"],
	["achter_sinn","Achter Sinn",2000,Color("a45cff"),"Gegner leuchten kurz durch Wände"],
	["grabesschritt","Grabesschritt",2000,Color("3a4a5a"),"Treffer werden oft verfehlt"],
	["seelenvorrat","Seelenvorrat",2500,Color("4a8cff"),"Mehr Munition in Reserve"],
	["zerreisser","Zerreißer",3000,Color("ff3a6a"),"Kopftreffer verursachen mehr Schaden"],
	["flackergeist","Flackergeist",3500,Color("6af2ff"),"Treffer springen elektrisch über"],
	["pluesch_segen","Plüschsegen",2500,Color("ffb6d9"),"Nach Killserien weniger Schaden"],
]

# ---------------------------------------------------------------- pickups
# id, name, colour, seconds (0 = instant), glyph
const PICKUPS:=[
	["double_points","Doppelte Punkte",Color("ffd23a"),30.,"×2"],
	["max_ammo","Maximalmunition",Color("ffffff"),0.,"▮▮"],
	["insta_kill","Sofortkill",Color("ff2a2a"),30.,"☠"],
	["slowdown","Kriechzeit",Color("6ab6ff"),20.,"≈"],
	["nuke","Geburtstagsbombe",Color("ff8a2a"),0.,"✸"],
	["damage","Doppelter Schaden",Color("ff3a6a"),25.,"▲"],
	["shield","Plüschschild",Color("ffb6d9"),18.,"◈"],
	["invisible","Vergessen",Color("a0a0b0"),12.,"◌"],
	["infinite_ammo","Endlose Munition",Color("c27bff"),20.,"∞"],
	["crit","Kritische Nacht",Color("ff5af2"),25.,"✦"],
	["fire_kills","Feuerkinder",Color("ff6a1a"),25.,"♨"],
	["chain","Kettenblitz",Color("6af2ff"),25.,"ϟ"],
	["gravity","Schwerelos",Color("7affd0"),12.,"⇡"],
	["alien","Alien-Segen",Color("44ff8a"),0.,"✧"],
	["time","Zeitlupe",Color("9ad0ff"),12.,"⌛"],
	["bloodrush","Blutrausch",Color("b0102a"),15.,"✚"],
	["speed","Doppeltes Tempo",Color("4affc8"),20.,"»"],
]
const PICKUP_CHANCE:=.035
const PICKUPS_PER_ROUND:=4
const PICKUP_LIFETIME:=26.0

# ---------------------------------------------------------------- events
const EVENT_FROM:=6
const EVENT_CHANCE:=.22
const EVENTS:={
	"blood_moon":{"name":"BLUTMOND","text":"Der Mond blutet. Sie sind schneller, die Punkte doppelt."},
	"alien":{"name":"ALIEN-INVASION","text":"Etwas kommt durch die Risse."},
	"gravity":{"name":"SCHWERKRAFTAUSFALL","text":"Die Welt vergisst, wo unten ist."},
	"dark":{"name":"DUNKELHEIT","text":"Das Licht stirbt. Nur deine Lampe bleibt."},
	"flicker":{"name":"FLACKERPHASE","text":"Die Röhren sterben im Takt deines Herzens."},
	"poison":{"name":"GIFTNEBEL","text":"Grüner Nebel kriecht aus den Lüftungen."},
	"time":{"name":"ZEITSTILLSTAND","text":"Die Zeit hängt fest. Für alle außer dich."},
	"clones":{"name":"KLONWELLE","text":"Sie kommen doppelt. Halb so stark."},
	"double_boss":{"name":"DOPPELTER GEBURTSTAG","text":"Zwei Gäste haben Geburtstag."},
	"birthday":{"name":"VERSEUCHTE GEBURTSTAGSRUNDE","text":"Alles Gute zum Todestag."},
	"laughter":{"name":"KINDERGELÄCHTER","text":"Hörst du sie lachen?"},
	"rift":{"name":"DIMENSIONSRISS","text":"Die Realität reißt auf."},
}

# ---------------------------------------------------------------- map
# Zones of the park; rects are [x0, x1, z0, z1].
const START_ZONE:="empfang"
const SPAWN_POINT:=Vector3(-6.4,0,12.2)
const ZONES:={
	"empfang":{"name":"Empfang","rects":[[-10.2,-3.6,4.2,19.6],[-16.0,-10.2,8.2,10.6]]},
	"halle":{"name":"Halle","rects":[[-10.2,6.9,-12.3,4.2]]},
	"baellebad":{"name":"Bällebad","rects":[[-3.6,19.8,4.2,17.2]]},
	"party":{"name":"Party Raum","rects":[[6.9,19.8,-12.0,4.2],[11.4,19.8,-18.7,-12.0]]},
	"wartung":{"name":"Wartung","rects":[[-16.5,-10.2,-12.5,-1.8]]},
	"annex":{"name":"Küche & Kino","rects":[[-17.5,4.3,-35.5,-12.3]]},
	"wc":{"name":"Kinder-WC","rects":[[19.8,27.2,4.5,10.5]]},
}
# Bought barriers: two zones each, fence lines from a to b.
const DOORS:=[
	{"id":"d_halle","name":"Halle","cost":750,"zones":["empfang","halle"],"from":Vector3(-10.2,0,4.2),"to":Vector3(-3.6,0,4.2)},
	{"id":"d_ball","name":"Bällebad","cost":1000,"zones":["empfang","baellebad"],"from":Vector3(-3.6,0,4.2),"to":Vector3(-3.6,0,17.2)},
	{"id":"d_hb","name":"Klettergerüst","cost":750,"zones":["halle","baellebad"],"from":Vector3(-3.6,0,4.2),"to":Vector3(6.9,0,4.2)},
	{"id":"d_party_h","name":"Party Raum","cost":1250,"zones":["halle","party"],"from":Vector3(6.9,0,-12.3),"to":Vector3(6.9,0,4.2)},
	{"id":"d_party_b","name":"Party Raum","cost":1250,"zones":["baellebad","party"],"from":Vector3(6.9,0,4.2),"to":Vector3(19.8,0,4.2)},
	{"id":"d_wartung","name":"Wartung","cost":1000,"zones":["halle","wartung"],"from":Vector3(-10.2,0,-12.3),"to":Vector3(-10.2,0,-1.8)},
	{"id":"d_annex","name":"Küche & Kino","cost":1500,"zones":["halle","annex"],"from":Vector3(-9.6,0,-12.3),"to":Vector3(-6.0,0,-12.3)},
	{"id":"d_wc","name":"Kinder-WC","cost":750,"zones":["baellebad","wc"],"from":Vector3(19.8,0,4.5),"to":Vector3(19.8,0,10.5)},
]
# Stations: kind, id (weapon/perk), position on the floor.
const STATIONS:=[
	["ammo","",Vector3(-8.0,0,16.4)],
	["wall","doppelzahn",Vector3(-9.3,0,11.2)],
	["wall","k12",Vector3(-4.4,0,9.2)],
	["perk","eiserne_rippen",Vector3(-5.0,0,14.6)],
	["ammo","",Vector3(.6,0,-10.8)],
	["wall","ar47",Vector3(-8.7,0,.6)],
	["wall","pumpgrave",Vector3(2.8,0,-9.6)],
	["perk","leichenfinger",Vector3(-8.7,0,-3.6)],
	["perk","hoellenlauf",Vector3(5.6,0,-10.9)],
	["ammo","",Vector3(8.2,0,6.2)],
	["wall","grablicht",Vector3(11.5,0,6.6)],
	["perk","todesatem",Vector3(17.6,0,15.4)],
	["perk","zerreisser",Vector3(18.4,0,6.4)],
	["ammo","",Vector3(16.0,0,-10.6)],
	["wall","ashline",Vector3(9.0,0,-1.2)],
	["perk","blutdurst",Vector3(8.3,0,-11.1)],
	["perk","achter_sinn",Vector3(18.5,0,-1.2)],
	["upgrade","",Vector3(15.0,0,-15.6)],
	["ammo","",Vector3(-11.4,0,-4.2)],
	["perk","flackergeist",Vector3(-11.1,0,-10.6)],
	["perk","grabesschritt",Vector3(-13.6,0,-3.4)],
	["ammo","",Vector3(-12.6,0,-33.6)],
	["perk","seelenvorrat",Vector3(-15.6,0,-26.6)],
	["perk","pluesch_segen",Vector3(-10.6,0,-33.6)],
	["perk","leerer_blick",Vector3(2.8,0,-34.0)],
	["wall","titan_maw",Vector3(-4.8,0,-34.3)],
	["wall","night_needle",Vector3(-8.4,0,-16.4)],
	["ammo","",Vector3(25.6,0,6.0)],
]
const BOX_SPOTS:=[Vector3(-6.6,0,-10.6),Vector3(16.8,0,9.4),Vector3(17.6,0,-14.8),Vector3(.2,0,-25.6),Vector3(25.4,0,9.4)]

static func weapon(id: String) -> Array:
	for row in WEAPONS:
		if row[0]==id:return row
	return []

static func perk(id: String) -> Array:
	for row in PERKS:
		if row[0]==id:return row
	return []

static func pickup(id: String) -> Array:
	for row in PICKUPS:
		if row[0]==id:return row
	return []

static func zone_at(p: Vector3) -> String:
	for id in ZONES:
		for r in ZONES[id].rects:
			if p.x>=r[0] and p.x<=r[1] and p.z>=r[2] and p.z<=r[3]:return id
	return ""

static func elites_for(r: int) -> Array:
	var out: Array=[]
	for row in ELITES_BY_ROUND:
		if r>=int(row[0]):out+=row[1]
	return out
