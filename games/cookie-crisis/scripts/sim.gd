class_name CookieSim
extends RefCounted
## Santa's Cookie Crisis – the economy. A 1:1 port of frontend/src/cookie/sim.js (same numbers, same
## save format, so the website keeps validating saves and granting the finale title).
##
## Everything is counted in whole cookies: one cookie = 25 g of dough, the mountain outside holds
## 25 t = 1,000,000 cookies. Dough moves through buffers and is never created or lost:
##   dough + carry + ball + sheet + tray + queue + belt + exit + falling + baked == 1,000,000
## A Schokotaler is credited in exactly the moment a cookie lands in the chute.

const GRAMS_PER_COOKIE := 25
const GOAL := 1000000
const OVEN_SLOTS := 14.0
const FALL_TIME := 0.42
const CLICK_RATE := 2.5
const TRIP_TIME := 9.0
const STEP := 1.0 / 60.0
const BIG := 1 << 60

const PHASES := [
	{"n": 1, "name": "Kleine Weihnachtsbäckerei", "unlock": 0},
	{"n": 2, "name": "Mechanische Werkstatt", "unlock": 1200},
	{"n": 3, "name": "Automatische Weihnachtsbäckerei", "unlock": 12000},
	{"n": 4, "name": "Industrielle Keksproduktion", "unlock": 90000},
	{"n": 5, "name": "Magische Weihnachts-Megafabrik", "unlock": 330000},
]

const UPGRADES := [
	{"id": "eimer", "phase": 1, "stage": "portion", "kind": "tool", "name": "Holzeimer", "text": "Statt mit den Händen trägst du 24 Kekse Teig auf einmal.", "base": 12, "growth": 1.0, "max": 1},
	{"id": "schubkarre", "phase": 1, "stage": "portion", "kind": "tool", "name": "Schubkarre", "text": "Eine ganze Ladung: 96 Kekse Teig pro Fahrt vom Teigberg.", "base": 140, "growth": 1.0, "max": 1},
	{"id": "nudelholz", "phase": 1, "stage": "roll", "kind": "tool", "name": "Größeres Nudelholz", "text": "Weniger Rollbewegungen pro Teigplatte.", "base": 14, "growth": 4.0, "max": 2},
	{"id": "teigrolle", "phase": 1, "stage": "portion", "kind": "tool", "name": "Breitere Teigrolle", "text": "Größere Teigplatten – mehr Kekse pro Portion.", "base": 22, "growth": 3.0, "max": 3},
	{"id": "form", "phase": 1, "stage": "cut", "kind": "tool", "name": "Mehrfach-Ausstechform", "text": "Sticht mehrere Sterne auf einmal aus.", "base": 12, "growth": 3.4, "max": 3},
	{"id": "blech", "phase": 1, "stage": "load", "kind": "tool", "name": "Größeres Backblech", "text": "Mehr Kekse pro Fahrt zum Ofen.", "base": 10, "growth": 3.0, "max": 3},
	{"id": "bandtempo", "phase": 1, "stage": "oven", "kind": "tool", "name": "Schnelleres Förderband", "text": "Das Ofenband läuft zügiger.", "base": 18, "growth": 2.1, "max": 5},
	{"id": "eingang", "phase": 1, "stage": "oven", "kind": "tool", "name": "Größerer Ofeneingang", "text": "Mehr Kekse nebeneinander auf dem Band.", "base": 90, "growth": 3.5, "max": 2},
	{"id": "schacht", "phase": 1, "stage": "chute", "kind": "tool", "name": "Breiterer Sammelschacht", "text": "Der Schacht schluckt mehr Kekse pro Sekunde.", "base": 25, "growth": 2.4, "max": 4},
	{"id": "portionierer", "phase": 2, "stage": "portion", "kind": "machine", "name": "Teigpumpe mit Portionierer", "text": "Eine Pumpe saugt Teig vom Teigberg durchs Rohr ins Haus – du musst nicht mehr schleppen.", "base": 160, "growth": 2.1, "max": 5},
	{"id": "walze", "phase": 2, "stage": "roll", "kind": "machine", "name": "Mechanische Teigwalze", "text": "Eine Kurbeldrehung walzt zwei Teigplatten auf einmal.", "base": 220, "growth": 1.0, "max": 1},
	{"id": "stanzpresse", "phase": 2, "stage": "cut", "kind": "machine", "name": "Mehrfach-Stanzpresse", "text": "Ein Hebelzug stanzt eine ganze Platte aus.", "base": 280, "growth": 3.2, "max": 2},
	{"id": "motor", "phase": 2, "stage": "oven", "kind": "machine", "name": "Elektrischer Förderbandmotor", "text": "Ein Motor treibt das Ofenband deutlich schneller an.", "base": 320, "growth": 2.4, "max": 3},
	{"id": "blechschieber", "phase": 2, "stage": "load", "kind": "machine", "name": "Automatischer Blechschieber", "text": "Schiebt volle Bleche selbst auf das Ofenband.", "base": 260, "growth": 1.0, "max": 1},
	{"id": "transport", "phase": 2, "stage": "load", "kind": "machine", "name": "Mechanischer Kekstransport", "text": "Ein Zubringerband bringt Kekse laufend zum Ofen.", "base": 420, "growth": 2.2, "max": 4},
	{"id": "zufuhr", "phase": 3, "stage": "portion", "kind": "machine", "name": "Automatische Teigzufuhr", "text": "Ein Rohr versorgt den Portionierer pausenlos mit Teig.", "base": 2600, "growth": 2.8, "max": 3},
	{"id": "steuerung", "phase": 3, "stage": "roll", "kind": "machine", "name": "Zentrale Maschinensteuerung", "text": "Walze und Presse laufen jetzt automatisch.", "base": 3200, "growth": 2.5, "max": 4},
	{"id": "ausstechwalze", "phase": 3, "stage": "cut", "kind": "machine", "name": "Rotierende Ausstechwalze", "text": "Eine Walze mit Sternformen sticht im Durchlauf aus.", "base": 5500, "growth": 2.8, "max": 3},
	{"id": "platzierung", "phase": 3, "stage": "load", "kind": "machine", "name": "Automatische Keksplatzierung", "text": "Greifarme setzen die Kekse exakt aufs Band.", "base": 4600, "growth": 2.8, "max": 3},
	{"id": "syncband", "phase": 3, "stage": "oven", "kind": "machine", "name": "Synchronisierte Förderbänder", "text": "Alle Bänder laufen im Takt – schneller und ruckfrei.", "base": 4000, "growth": 2.5, "max": 3},
	{"id": "durchlauf", "phase": 3, "stage": "oven", "kind": "machine", "name": "Breiterer Durchlaufofen", "text": "Der Ofen wird breiter: zwei Kekse mehr pro Reihe.", "base": 8000, "growth": 3.0, "max": 2},
	{"id": "mehrspur", "phase": 3, "stage": "oven", "kind": "machine", "name": "Mehrspurige Ofenförderbänder", "text": "Eine weitere Spur läuft durch den Ofen.", "base": 9500, "growth": 2.9, "max": 3},
	{"id": "sammelstation", "phase": 3, "stage": "chute", "kind": "machine", "name": "Automatische Sammelstation", "text": "Rüttler und Rinnen verteilen die Kekse im Schacht.", "base": 5000, "growth": 2.8, "max": 3},
	{"id": "extruder", "phase": 4, "stage": "portion", "kind": "machine", "name": "Hochgeschwindigkeits-Teigextruder", "text": "Presst Teig als endloses Band – portionieren und walzen in einem.", "base": 30000, "growth": 2.2, "max": 3},
	{"id": "industrie", "phase": 4, "stage": "cut", "kind": "machine", "name": "Industrielle Ausstechmaschinen", "text": "Breite Stanzbrücken im Dauerbetrieb.", "base": 32000, "growth": 2.2, "max": 3},
	{"id": "verteiler", "phase": 4, "stage": "load", "kind": "machine", "name": "Automatische Verteilersysteme", "text": "Weichen verteilen die Kekse auf alle Spuren.", "base": 30000, "growth": 2.2, "max": 3},
	{"id": "hochleistung", "phase": 4, "stage": "roll", "kind": "machine", "name": "Hochleistungsmotoren", "text": "Kräftigere Motoren für Walzen und Bänder.", "base": 26000, "growth": 2.2, "max": 3},
	{"id": "etagen", "phase": 4, "stage": "oven", "kind": "machine", "name": "Mehrstöckige Förderbandöfen", "text": "Ein weiteres Ofenstockwerk mit eigenen Bändern.", "base": 55000, "growth": 2.0, "max": 2},
	{"id": "magnet", "phase": 4, "stage": "oven", "kind": "machine", "name": "Magnetische Transportsysteme", "text": "Magnetbänder gleiten ohne Reibung.", "base": 40000, "growth": 2.2, "max": 2},
	{"id": "sensoren", "phase": 4, "stage": "chute", "kind": "machine", "name": "Präzisionssensoren", "text": "Sensoren takten Schacht und Maschinen fein ab.", "base": 28000, "growth": 2.2, "max": 3},
	{"id": "vollauto", "phase": 4, "stage": "all", "kind": "machine", "name": "Vollautomatische Produktionsstraßen", "text": "Alle Stationen greifen nahtlos ineinander: alles ×1,3.", "base": 100000, "growth": 1.0, "max": 1},
	{"id": "beschleuniger", "phase": 5, "stage": "portion", "kind": "magic", "name": "Magischer Teigbeschleuniger", "text": "Funkelnder Teig fließt doppelt so schnell.", "base": 55000, "growth": 2.0, "max": 2},
	{"id": "ultra", "phase": 5, "stage": "cut", "kind": "magic", "name": "Ultrahochgeschwindigkeits-Ausstechsysteme", "text": "Die Formen bewegen sich schneller als das Auge.", "base": 55000, "growth": 2.0, "max": 2},
	{"id": "portale", "phase": 5, "stage": "load", "kind": "magic", "name": "Magische Keksportale", "text": "Kekse verschwinden hier und erscheinen direkt auf dem Band.", "base": 60000, "growth": 2.0, "max": 2},
	{"id": "turboofen", "phase": 5, "stage": "oven", "kind": "magic", "name": "Riesiger Weihnachts-Turboofen", "text": "Ein gewaltiger Ofen mit deutlich breiteren Bändern.", "base": 70000, "growth": 2.0, "max": 2},
	{"id": "schwebend", "phase": 5, "stage": "oven", "kind": "magic", "name": "Schwebende Förderbänder", "text": "Zusätzliche Bänder schweben durch die Halle.", "base": 65000, "growth": 2.0, "max": 2},
	{"id": "rentier", "phase": 5, "stage": "all", "kind": "magic", "name": "Rentierenergie-Generator", "text": "Ein Laufrad voller Rentierkraft: alles ×1,2.", "base": 80000, "growth": 1.7, "max": 2},
	{"id": "goldstrasse", "phase": 5, "stage": "all", "kind": "magic", "name": "Goldene Weihnachts-Produktionsstraße", "text": "Eine goldene Straße: alles ×1,3.", "base": 140000, "growth": 1.0, "max": 1},
	{"id": "megafabrik", "phase": 5, "stage": "all", "kind": "magic", "name": "Nordpol-Megafabrik", "text": "Die ganze Halle wird zur Megafabrik: alles ×1,4.", "base": 200000, "growth": 1.0, "max": 1},
]

static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

static func cost(u: Dictionary, level: int) -> int:
	return int(round(float(u.base) * pow(float(u.growth), level)))

static func lv(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))

# ------------------------------------------------------------------------------------ derived stats
static func derive(levels: Dictionary) -> Dictionary:
	var L := func(id: String) -> int: return lv(levels, id)
	var g: float = (1.3 if L.call("vollauto") else 1.0) * pow(1.2, L.call("rentier")) * (1.3 if L.call("goldstrasse") else 1.0) * (1.4 if L.call("megafabrik") else 1.0)
	var sheet_size: int = [8, 12, 16, 24][L.call("teigrolle")]
	var strokes: int = [3, 2, 1][L.call("nudelholz")]
	var cutter: int = [1, 2, 3, 4][L.call("form")]
	var press_size: int = [0, 24, 48][L.call("stanzpresse")]
	var walze: bool = L.call("walze") > 0
	var tray_base: int = [6, 10, 16, 24][L.call("blech")]
	var carry_cap: int = 96 if L.call("schubkarre") else (24 if L.call("eimer") else 8)
	var auto_portion: float = 1.4 * pow(1.55, L.call("portionierer") - 1) if L.call("portionierer") else 0.0
	auto_portion *= pow(2.4, L.call("zufuhr")) * pow(1.8, L.call("extruder")) * pow(1.7, L.call("beschleuniger"))
	var auto_roll: float = 18.0 * pow(1.9, L.call("steuerung") - 1) if L.call("steuerung") else 0.0
	auto_roll *= pow(1.8, L.call("extruder")) * pow(1.35, L.call("hochleistung")) * pow(1.7, L.call("beschleuniger"))
	var auto_cut: float = 18.0 * pow(1.9, L.call("steuerung") - 1) if L.call("steuerung") else 0.0
	auto_cut *= pow(1.8, L.call("ausstechwalze")) * pow(1.8, L.call("industrie")) * pow(1.7, L.call("ultra"))
	var auto_load: float = 1.8 * pow(1.6, L.call("transport") - 1) if L.call("transport") else 0.0
	auto_load *= pow(2.5, L.call("platzierung")) * pow(1.8, L.call("verteiler")) * pow(1.7, L.call("portale"))
	var speed: float = 0.8 * pow(1.2, L.call("bandtempo")) * pow(1.4, L.call("motor")) * pow(1.3, L.call("syncband")) * pow(1.15, L.call("hochleistung")) * pow(1.2, L.call("magnet")) * pow(1.15, L.call("schwebend"))
	var per_row: float = float([1, 2, 3][L.call("eingang")] + 2 * L.call("durchlauf")) * pow(1.4, L.call("turboofen"))
	var lanes: int = 1 + L.call("mehrspur") + 2 * L.call("schwebend")
	var floors: int = 1 + L.call("etagen")
	var oven_rate: float = speed * per_row * lanes * floors * g
	var chute_rate: float = 3.0 * pow(1.6, L.call("schacht")) * pow(3.0, L.call("sammelstation")) * pow(2.0, L.call("sensoren")) * pow(1.7, L.call("portale")) * g
	auto_portion *= g; auto_roll *= g; auto_cut *= g; auto_load *= g
	return {
		"sheetSize": sheet_size, "strokes": strokes, "cutter": cutter, "pressSize": press_size, "walze": walze,
		"trayCap": maxi(tray_base, ceili(auto_cut * 1.5)), "carryCap": carry_cap,
		"queueCap": maxi(24, ceili(oven_rate * 3.0)), "ballCap": maxi(maxi(sheet_size * 3, carry_cap), ceili(auto_portion * 2.0)),
		"sheetCap": maxi(sheet_size * 4, ceili(maxf(auto_roll, auto_portion) * 2.0)),
		"autoPortion": auto_portion, "autoRoll": auto_roll, "autoCut": auto_cut, "autoLoad": auto_load, "pusher": L.call("blechschieber") > 0,
		"speed": minf(speed * minf(g, 1.5), OVEN_SLOTS / 1.2), "perRow": per_row, "lanes": lanes, "floors": floors,
		"ovenRate": oven_rate, "chuteRate": chute_rate, "global": g,
	}

# Production model: machines run at their rate; the elf fills the gaps (seconds of elf time per cookie).
static func stations(d: Dictionary) -> Array:
	return [
		{"id": "portion", "name": "Teig holen", "auto": d.autoPortion, "secs": (TRIP_TIME + 2.0 / CLICK_RATE) / d.carryCap},
		{"id": "roll", "name": "Ausrollen", "auto": d.autoRoll, "secs": ((1.0 / (d.sheetSize * 2.0)) if d.walze else (float(d.strokes) / d.sheetSize)) / CLICK_RATE},
		{"id": "cut", "name": "Ausstechen", "auto": d.autoCut, "secs": 1.0 / float(d.pressSize if d.pressSize else d.cutter) / CLICK_RATE},
		{"id": "load", "name": "Zum Ofen", "auto": d.autoLoad + (d.trayCap / 1.1 if d.pusher else 0.0), "secs": 1.0 / d.trayCap / CLICK_RATE},
	]

static func _hands(list: Array, T: float) -> float:
	var a := 0.0
	for st in list:
		a += maxf(0.0, T - st.auto) * st.secs
	return a

static func throughput(d: Dictionary) -> float:
	var list := stations(d)
	var cap: float = minf(d.ovenRate, d.chuteRate)
	if _hands(list, cap) <= 1.0:
		return cap
	var lo := 0.0
	var hi := cap
	for i in range(50):
		var mid := (lo + hi) / 2.0
		if _hands(list, mid) <= 1.0: lo = mid
		else: hi = mid
	return lo

static func capacities(d: Dictionary) -> Array:
	var T := throughput(d)
	var out := []
	for st in stations(d):
		out.append({"id": st.id, "name": st.name, "rate": st.auto, "hand": maxf(0.0, T - st.auto) * st.secs})
	out.append({"id": "oven", "name": "Ofen", "rate": d.ovenRate, "hand": 0.0})
	out.append({"id": "chute", "name": "Schacht", "rate": d.chuteRate, "hand": 0.0})
	return out

static func bottleneck(d: Dictionary) -> Dictionary:
	var T := throughput(d)
	var caps := capacities(d)
	if T >= minf(d.ovenRate, d.chuteRate) - 1e-6:
		return caps[4] if d.ovenRate <= d.chuteRate else caps[5]
	var best: Dictionary = caps[0]
	for i in range(1, 4):
		if caps[i].hand > best.hand: best = caps[i]
	return best

# ------------------------------------------------------------------------------------ state
static func create() -> Dictionary:
	return {
		"v": 1, "t": 0.0, "dough": GOAL, "carry": 0, "ball": 0, "rollProgress": 0.0, "sheet": 0, "tray": 0, "queue": 0,
		"belt": [], "exit": 0, "falling": [], "talers": 0, "earned": 0, "baked": 0, "spent": 0, "levels": {},
		"acc": {"portion": 0.0, "roll": 0.0, "cut": 0.0, "load": 0.0, "oven": 1.0, "chute": 1.0},
		"pushT": 0.0, "clicks": 0, "finished": null, "events": [],
	}

static func total_dough(s: Dictionary) -> int:
	var n: int = s.dough + s.carry + s.ball + s.sheet + s.tray + s.queue + s.exit + s.baked
	for b in s.belt: n += int(b[1])
	for b in s.falling: n += int(b[1])
	return n

static func _emit(s: Dictionary, type: String, n: int = 1) -> void:
	s.events.append({"type": type, "n": n})

# ------------------------------------------------------------------------------------ manual actions
static func act_take(s: Dictionary, d: Dictionary) -> int:
	var n: int = mini(d.carryCap - s.carry, s.dough)
	if n <= 0:
		_emit(s, "blocked", 0); return 0
	s.dough -= n; s.carry += n; s.clicks += 1
	_emit(s, "take", n)
	return n

static func act_deliver(s: Dictionary, d: Dictionary) -> int:
	var n: int = mini(s.carry, d.ballCap - s.ball)
	if n <= 0:
		_emit(s, "blocked", 0); return 0
	s.carry -= n; s.ball += n; s.clicks += 1
	_emit(s, "portion", n)
	return n

static func act_roll(s: Dictionary, d: Dictionary) -> int:
	if s.ball <= 0: return 0
	var space: int = d.sheetCap - s.sheet
	if space <= 0:
		_emit(s, "blocked", 0); return 0
	s.clicks += 1
	if d.walze:
		var n: int = mini(mini(s.ball, d.sheetSize * 2), space)
		s.ball -= n; s.sheet += n; s.rollProgress = 0.0
		_emit(s, "crank", n)
		return n
	s.rollProgress = minf(1.0, s.rollProgress + 1.0 / d.strokes)
	_emit(s, "roll", 0)
	if s.rollProgress >= 1.0 - 1e-9:
		var m: int = mini(mini(s.ball, d.sheetSize), space)
		s.ball -= m; s.sheet += m; s.rollProgress = 0.0
		_emit(s, "rolled", m)
		return m
	return 0

static func act_cut(s: Dictionary, d: Dictionary) -> int:
	if s.sheet <= 0: return 0
	var n: int = mini(mini(s.sheet, d.pressSize if d.pressSize else d.cutter), d.trayCap - s.tray)
	if n <= 0:
		_emit(s, "blocked", 0); return 0
	s.sheet -= n; s.tray += n; s.clicks += 1
	_emit(s, "press" if d.pressSize else "cut", n)
	return n

static func act_load(s: Dictionary, d: Dictionary) -> int:
	if s.tray <= 0: return 0
	var n: int = mini(s.tray, d.queueCap - s.queue)
	if n <= 0:
		_emit(s, "blocked", 0); return 0
	s.tray -= n; s.queue += n; s.clicks += 1
	_emit(s, "load", n)
	return n

static func phase_of(s: Dictionary) -> int:
	var p := 1
	for ph in PHASES:
		if s.earned >= ph.unlock: p = ph.n
	return p

static func is_unlocked(s: Dictionary, u: Dictionary) -> bool:
	return phase_of(s) >= u.phase

static func buy(s: Dictionary, id: String) -> bool:
	var u := upgrade(id)
	if u.is_empty() or not is_unlocked(s, u): return false
	var level := lv(s.levels, id)
	if level >= u.max: return false
	var c := cost(u, level)
	if s.talers < c: return false
	s.talers -= c; s.spent += c
	s.levels[id] = level + 1
	_emit(s, "machine" if (u.phase >= 3 or u.kind != "tool") else "buy", u.phase)
	return true

static func active_machines(levels: Dictionary) -> int:
	var n := 0
	for u in UPGRADES:
		if u.kind != "tool" and lv(levels, u.id) > 0: n += 1
	return n

static func recommended(s: Dictionary) -> Dictionary:
	var d := derive(s.levels)
	var now := maxf(throughput(d), 1e-9)
	var neck := bottleneck(d)
	var best := {}
	var best_value := 0.0
	var open := []
	for u in UPGRADES:
		if is_unlocked(s, u) and lv(s.levels, u.id) < u.max: open.append(u)
	for u in open:
		var next: Dictionary = s.levels.duplicate()
		next[u.id] = lv(s.levels, u.id) + 1
		var ratio := throughput(derive(next)) / now
		if ratio <= 1.0001: continue
		var value := log(ratio) / cost(u, lv(s.levels, u.id))
		if value > best_value:
			best = u; best_value = value
	if not best.is_empty(): return best
	var cheapest := {}
	for pass_ in range(2):
		for u in open:
			if pass_ == 0 and u.stage != neck.id and u.stage != "all": continue
			if cheapest.is_empty() or cost(u, lv(s.levels, u.id)) < cost(cheapest, lv(s.levels, cheapest.id)): cheapest = u
		if not cheapest.is_empty(): return cheapest
	return {}

# ------------------------------------------------------------------------------------ simulation
static func _flow(s: Dictionary, key: String, rate: float, avail: int, space: int, dt: float) -> int:
	if rate <= 0.0:
		s.acc[key] = 0.0; return 0
	s.acc[key] += rate * dt
	var n: int = maxi(0, mini(mini(floori(s.acc[key]), avail), space))
	s.acc[key] -= n
	var cap := maxf(1.0, rate * dt * 2.0)
	if s.acc[key] > cap: s.acc[key] = cap
	return n

static func _tick(s: Dictionary, d: Dictionary, dt: float) -> void:
	s.t += dt
	var n := _flow(s, "portion", d.autoPortion, s.dough, d.ballCap - s.ball, dt)
	if n:
		s.dough -= n
		s.ball += n
	n = _flow(s, "roll", d.autoRoll, s.ball, d.sheetCap - s.sheet, dt)
	if n:
		s.ball -= n; s.sheet += n; s.rollProgress = 0.0
	n = _flow(s, "cut", d.autoCut, s.sheet, d.trayCap - s.tray, dt)
	if n:
		s.sheet -= n
		s.tray += n
	n = _flow(s, "load", d.autoLoad, s.tray, d.queueCap - s.queue, dt)
	if n:
		s.tray -= n
		s.queue += n
	s.pushT = maxf(0.0, s.pushT - dt)
	if d.pusher and s.pushT <= 0.0 and s.tray > 0 and (s.tray >= d.trayCap or (s.sheet == 0 and s.ball == 0 and not d.autoCut)):
		var m: int = mini(s.tray, d.queueCap - s.queue)
		if m > 0:
			s.tray -= m; s.queue += m; s.pushT = 1.1
			_emit(s, "push", m)
	n = _flow(s, "oven", d.ovenRate, s.queue, BIG, dt)
	if n:
		s.queue -= n
		if s.belt.size() and float(s.belt[-1][0]) == 0.0: s.belt[-1][1] += n
		else: s.belt.append([0.0, n])
	var move: float = d.speed * dt
	for b in s.belt: b[0] += move
	while s.belt.size() and float(s.belt[0][0]) >= OVEN_SLOTS:
		s.exit += int(s.belt[0][1]); s.belt.pop_front()
	n = _flow(s, "chute", d.chuteRate, s.exit, BIG, dt)
	if n:
		s.exit -= n
		var land: float = s.t + FALL_TIME
		if s.falling.size() and absf(float(s.falling[-1][0]) - land) < 1e-9: s.falling[-1][1] += n
		else: s.falling.append([land, n])
	while s.falling.size() and float(s.falling[0][0]) <= s.t + 1e-9:
		var m: int = int(s.falling[0][1]); s.falling.pop_front()
		s.talers += m; s.earned += m; s.baked += m
		_emit(s, "land", m)
	if s.baked >= GOAL and s.finished == null:
		s.finished = s.t; _emit(s, "finale", 1)

static func step(s: Dictionary, dt: float) -> Dictionary:
	var left := minf(dt, 120.0)
	var d := derive(s.levels)
	while left > 1e-9:
		var h := minf(STEP, left)
		_tick(s, d, h)
		left -= h
	return d

# ------------------------------------------------------------------------------------ save / load (same JSON as the website)
static func serialize(s: Dictionary) -> String:
	var out := s.duplicate(true)
	out.erase("events")
	out["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	return JSON.stringify(out)

static func deserialize(text: String) -> Dictionary:
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY or int(raw.get("v", 0)) != 1: return {}
	var s := create()
	for k in raw.keys():
		if k != "events": s[k] = raw[k]
	s.levels = {}
	for k in (raw.get("levels", {}) as Dictionary).keys(): s.levels[k] = int(raw.levels[k])
	var acc: Dictionary = create().acc
	for k in (raw.get("acc", {}) as Dictionary).keys(): acc[k] = float(raw.acc[k])
	s.acc = acc
	s.belt = []
	for b in raw.get("belt", []): s.belt.append([float(b[0]), maxi(0, int(b[1]))])
	s.falling = []
	for b in raw.get("falling", []): s.falling.append([float(b[0]), maxi(0, int(b[1]))])
	for k in ["dough", "carry", "ball", "sheet", "tray", "queue", "exit", "talers", "earned", "baked", "spent", "clicks"]:
		s[k] = maxi(0, int(s.get(k, 0)))
	s.t = float(s.t); s.rollProgress = float(s.rollProgress); s.pushT = float(s.get("pushT", 0.0))
	s.events = []
	if total_dough(s) != GOAL: return {}
	return s
