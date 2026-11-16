class_name CookieSelfTest
extends RefCounted
## Headless checks: godot --headless --path games/cookie-crisis -- --self-test
## The economy must match the website simulation exactly (tests/fixture.json is written by
## tests/make-fixture.mjs from frontend/src/cookie/sim.js).

static func run() -> int:
	var fails := 0
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	for row in fixture.derived:
		var d := CookieSim.derive(row.levels)
		for k in ["sheetSize", "trayCap", "carryCap", "queueCap", "ballCap", "sheetCap", "lanes", "floors"]:
			if int(d[k]) != int(row.d[k]):
				print("FAIL derive %s %s: %s != %s" % [row.levels, k, d[k], row.d[k]]); fails += 1
		for k in ["autoPortion", "autoRoll", "autoCut", "autoLoad", "speed", "ovenRate", "chuteRate"]:
			if absf(float(d[k]) - float(row.d[k])) > 1e-6 * maxf(1.0, absf(float(row.d[k]))):
				print("FAIL derive %s %s: %s != %s" % [row.levels, k, d[k], row.d[k]]); fails += 1
		if absf(CookieSim.throughput(d) - float(row.throughput)) > 1e-4 * maxf(1.0, float(row.throughput)):
			print("FAIL throughput %s: %s != %s" % [row.levels, CookieSim.throughput(d), row.throughput]); fails += 1
	var s := CookieSim.create()
	for i in range(6):
		var d := CookieSim.derive(s.levels)
		CookieSim.act_take(s, d); CookieSim.act_deliver(s, d)
		for k in range(3): CookieSim.act_roll(s, d)
		for k in range(8): CookieSim.act_cut(s, d)
		CookieSim.act_load(s, d)
		CookieSim.step(s, 3.0)
	CookieSim.step(s, 30.0)
	for k in ["dough", "ball", "sheet", "tray", "queue", "exit", "baked", "talers"]:
		if int(s[k]) != int(fixture.after[k]):
			print("FAIL play %s: %s != %s" % [k, s[k], fixture.after[k]]); fails += 1
	if CookieSim.total_dough(s) != CookieSim.GOAL:
		print("FAIL dough balance"); fails += 1
	var back := CookieSim.deserialize(CookieSim.serialize(s))
	if back.is_empty() or int(back.baked) != int(s.baked) or CookieSim.total_dough(back) != CookieSim.GOAL:
		print("FAIL save round trip"); fails += 1
	s.talers = 1000; s.earned = 2000
	if not CookieSim.buy(s, "portionierer") or CookieSim.derive(s.levels).autoPortion <= 0.0:
		print("FAIL buy"); fails += 1
	if CookieSim.recommended(s).is_empty():
		print("FAIL recommended"); fails += 1
	print("self-test: %s" % ("OK" if fails == 0 else "%d failures" % fails))
	return fails
