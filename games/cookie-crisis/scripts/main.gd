extends Node3D
## Santa's Cookie Crisis – game root: builds the snowy clearing with the log-cabin bakery and the
## dough mountain, runs the economy (CookieSim), turns its events into hands, sounds and physics,
## and saves (browser storage + the website account when it runs on my-aviary.de).

const LINE := Vector3(-1, 0, -1)
const BENCH_Y := 0.9
const BELT := {"y": 1.18, "z": -0.95, "x0": -2.3, "oven0": -1.2, "oven1": 1.2, "x1": 1.62, "floorH": 0.75, "laneGap": 0.24}
const CRATE := Vector3(2.05, 0, -0.95)
const MOUNTAIN := Vector3(2.5, 0, 18)
const BAKE_STEPS := 10
const MAX_COOKIES := 4000
const SPOTS := {
	"mountain": {"x": 2.5, "z": 12.4, "yaw": PI, "outside": true},
	"bench": {"x": -0.6, "z": 0.15, "yaw": 0.0, "outside": false},
	"tray": {"x": -2.05, "z": 0.15, "yaw": 0.0, "outside": false},
}
const ACTION_SPOT := {"take": "mountain", "deliver": "bench", "roll": "bench", "cut": "bench", "load": "tray", "shop": "bench"}
const LABELS := {"take": "Teig greifen", "deliver": "Teig ablegen", "roll": "Ausrollen", "cut": "Ausstechen", "load": "Blech aufs Band", "shop": "Bestellbuch öffnen"}
const QUEST := {"take": "Geh raus zum Teigberg und greif dir Teig", "deliver": "Bring den Teig zur Werkbank und leg ihn ab", "roll": "Roll den Teig auf der Werkbank aus", "cut": "Stich Sterne aus dem Teig aus", "load": "Heb das volle Blech aufs Förderband"}
const WALLS := [
	[-7.3, -6.3, 7.3, -5.7], [-7.3, -6.3, -6.7, 4.3], [6.7, -6.3, 7.3, 4.3], [-7.3, 3.7, 1.6, 4.3], [3.4, 3.7, 7.3, 4.3],
	[-2.8, -1.6, 0.8, -0.45], [-3.5, -3.0, 0.8, -1.6], [0.7, -1.45, 1.45, -0.45], [-1.45, 5.5, -1.15, 14.2], [4.45, 5.5, 4.75, 14.2],
]

var s: Dictionary
var d: Dictionary
var player: ElfPlayer
var hud: CookieHud
var sfx: CookieSfx
var nodes := {}
var line: Node3D
var parts := {}
var machines := {}
var cookies: MultiMeshInstance3D
var bake_cols: Array[Color] = []
var mountain: Node3D
var mountain_shape: CollisionShape3D
var mountain_area: CollisionShape3D
var belt_root: Node3D
var belt_key := ""
var belt_mat: StandardMaterial3D
var physics_cookies: Array[RigidBody3D] = []
var coin_pile: MultiMeshInstance3D
var landings: Array = []
var save_clock := 0.0
var server_clock := 0.0
var ready_state := false
var web := false
var finale_shown := false
var paused_ui := false
var t := 0.0

func _ready() -> void:
	if "--self-test" in OS.get_cmdline_user_args():
		var fails := CookieSelfTest.run()
		get_tree().quit(1 if fails else 0)
		return
	web = OS.has_feature("web")
	_inputs()
	s = CookieSim.create()
	d = CookieSim.derive(s.levels)
	sfx = CookieSfx.new(); add_child(sfx)
	_environment()
	_world()
	_line()
	_machines()
	_player()
	hud = CookieHud.new(); add_child(hud); hud.build()
	hud.buy_requested.connect(_buy)
	hud.tool_selected.connect(func(i): player.tool = i)
	hud.resume_requested.connect(_resume)
	hud.new_game_requested.connect(_new_game)
	hud.settings_changed.connect(func(vol, mus, sens): sfx.volume = vol; sfx.set_music(mus); player.sensitivity = sens)
	_load_save()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-shots="): _qa(arg.split("=")[1])

# Screenshots of fixed scenes for review: godot --path games/cookie-crisis -- --qa-shots=<folder>
func _qa(dir: String) -> void:
	await get_tree().process_frame
	ready_state = true
	var scenes := [
		{"name": "bench", "pos": Vector3(-0.6, 0.05, 0.15), "yaw": 0.0, "pitch": -0.55, "levels": {}, "earned": 40, "act": ["take", "deliver", "roll"]},
		{"name": "room", "pos": Vector3(3.5, 0.05, 2.6), "yaw": 0.9, "pitch": -0.12, "levels": {}, "earned": 40, "act": []},
		{"name": "mountain", "pos": Vector3(2.5, 0.05, 11.0), "yaw": PI, "pitch": 0.0, "levels": {}, "earned": 40, "act": []},
		{"name": "outside", "pos": Vector3(-3.0, 0.05, 13.0), "yaw": PI * 1.25, "pitch": -0.05, "levels": {}, "earned": 40, "act": []},
		{"name": "workshop", "pos": Vector3(-0.4, 0.05, 1.1), "yaw": 0.15, "pitch": -0.35, "levels": {"eimer": 1, "portionierer": 2, "walze": 1, "stanzpresse": 1, "motor": 2, "blechschieber": 1, "transport": 1, "bandtempo": 3, "form": 2}, "earned": 5000, "act": []},
		{"name": "factory", "pos": Vector3(0.6, 0.05, 2.0), "yaw": 0.35, "pitch": -0.2, "levels": {"portionierer": 5, "zufuhr": 3, "steuerung": 4, "extruder": 2, "industrie": 2, "etagen": 2, "mehrspur": 3, "durchlauf": 2, "platzierung": 2, "rentier": 1, "turboofen": 1, "portale": 1, "goldstrasse": 1, "motor": 3, "syncband": 3}, "earned": 600000, "act": []},
	]
	for sc in scenes:
		s = CookieSim.create(); s.levels = sc.levels; s.earned = sc.earned; s.baked = sc.earned; s.talers = sc.earned; s.dough = CookieSim.GOAL - sc.earned
		d = CookieSim.derive(s.levels)
		player.global_position = sc.pos; player.rotation.y = sc.yaw; player.camera.rotation.x = sc.pitch
		for a in sc.act: _perform(a)
		for i in 150: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/godot-%s.png" % [dir, sc.name])
	_open_shop()
	for i in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/godot-shop.png" % dir)
	get_tree().quit()

func _inputs() -> void:
	var keys := {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "run": [KEY_SHIFT],
		"interact": [KEY_E], "drop": [KEY_F], "shop": [KEY_TAB], "next": [KEY_SPACE], "tool_1": [KEY_1], "tool_2": [KEY_2], "tool_3": [KEY_3], "tool_4": [KEY_4], "menu": [KEY_ESCAPE]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- environment
func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("0a1230"); sm.sky_horizon_color = Color("27345e"); sm.ground_bottom_color = Color("0c0f1a"); sm.ground_horizon_color = Color("27345e")
	sm.sun_angle_max = 1.0; sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 1.1
	env.glow_enabled = true; env.glow_intensity = 0.7; env.glow_bloom = 0.15
	env.fog_enabled = true; env.fog_light_color = Color("26345a"); env.fog_density = 0.012
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var moon := DirectionalLight3D.new(); moon.light_color = Color("aebfff"); moon.light_energy = 0.55; moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-38, -35, 0); moon.directional_shadow_max_distance = 40; add_child(moon)
	for p in [Vector3(-1, 3.5, 0.5), Vector3(4, 3.3, -2.5), Vector3(-4.5, 3.3, -3)]:
		var l := OmniLight3D.new(); l.light_color = Color("ffbf6e"); l.light_energy = 1.1; l.omni_range = 8.0; l.position = p; l.shadow_enabled = p.x < 0 and p.z > 0; add_child(l)
	for p in [Vector3(0.6, 2.35, 5.2), Vector3(4.4, 2.35, 5.2), Vector3(-1.0, 2.35, 10), Vector3(4.4, 2.35, 12), Vector3(1.5, 2.35, 15.5), Vector3(2.5, 4.5, 13)]:
		var l := OmniLight3D.new(); l.light_color = Color("ffc46a"); l.light_energy = 1.2; l.omni_range = 7.0; l.position = p; add_child(l)
	# snow falling around the player
	var snow := CPUParticles3D.new(); snow.amount = 1600; snow.lifetime = 9.0; snow.preprocess = 9.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; snow.emission_box_extents = Vector3(22, 0.5, 22)
	snow.direction = Vector3(0, -1, 0); snow.spread = 12; snow.initial_velocity_min = 0.6; snow.initial_velocity_max = 1.2; snow.gravity = Vector3(0.15, -0.3, 0)
	var flake := SphereMesh.new(); flake.radius = 0.02; flake.height = 0.04; flake.radial_segments = 4; flake.rings = 2
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(1, 1, 1); fm.emission_enabled = true; fm.emission = Color(0.6, 0.65, 0.8); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm; snow.mesh = flake; snow.position = Vector3(0, 12, 4); add_child(snow)
	parts.snow = snow

# ---------------------------------------------------------------- world: assets, materials, collision
func _scene(name: String) -> Node3D:
	var packed := load("res://assets/models/%s.glb" % name) as PackedScene
	return packed.instantiate() as Node3D if packed else Node3D.new()

func _grab(from: Node3D, name: String) -> Node3D:
	var n := from.find_child(name, true, false) as Node3D
	if not n: return Node3D.new()
	var copy := n.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	return copy

func _world() -> void:
	var w := _scene("world"); add_child(w)
	_style(w)
	var m := _scene("mountain"); add_child(m)
	mountain = m.find_child("Mountain", true, false) as Node3D
	for n in ["Mountain", "Chunks", "MountainSign"]:
		var o := m.find_child(n, true, false) as Node3D
		if o: o.position += MOUNTAIN
	nodes.mountain_scene = m
	nodes.props = _scene("props"); nodes.machines = _scene("machines"); nodes.parts = _scene("parts"); nodes.interior = _scene("interior"); nodes.bakery = _scene("bakery")
	# the interior: tree, presents, rug, lanterns, garlands, shelves, stockings, flour sacks
	var deco := func(name: String, p: Vector3, ry := 0.0, sc := 1.0):
		var n := _grab(nodes.interior, name); n.position = p; n.rotation.y = ry; n.scale = Vector3.ONE * sc; add_child(n); return n
	deco.call("ChristmasTree", Vector3(5.3, 0, 1.9)); deco.call("Presents", Vector3(5.3, 0, 1.9)); deco.call("Rug", Vector3(-0.9, 0, 1.4), 0.0, 1.2)
	for p in [Vector3(-3.5, 3.6, 1), Vector3(0.5, 3.6, 1.6), Vector3(4, 3.6, -2.5), Vector3(-4.5, 3.6, -3.5)]: deco.call("HangingLantern", p)
	deco.call("BeamGarland", Vector3(0, 4.05, -5.75)); deco.call("BeamGarland", Vector3(0, 4.05, 3.75), PI)
	deco.call("WallShelf", Vector3(6.75, 2.0, -3), -PI / 2); deco.call("WallShelf", Vector3(-6.75, 2.0, 1.5), PI / 2)
	deco.call("Stockings", Vector3(4.6, 2.3, -5.78)); deco.call("FlourSack", Vector3(-3.3, 0, 0.6), 0.4); deco.call("FlourSack", Vector3(-3.75, 0, 0.2), 1.2, 0.85)
	var tl := OmniLight3D.new(); tl.light_color = Color("ffd27a"); tl.light_energy = 1.3; tl.omni_range = 5; tl.position = Vector3(5.3, 1.6, 1.9); add_child(tl); parts.tree_light = tl
	# collision: ground, house walls, bench/oven, fence, mountain
	var body := StaticBody3D.new(); add_child(body)
	var ground := CollisionShape3D.new(); var plane := WorldBoundaryShape3D.new(); ground.shape = plane; body.add_child(ground)
	for wall in WALLS:
		var c := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = Vector3(wall[2] - wall[0], 3.0, wall[3] - wall[1]); c.shape = b
		c.position = Vector3((wall[0] + wall[2]) / 2.0, 1.5, (wall[1] + wall[3]) / 2.0); body.add_child(c)
	mountain_shape = CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = 4.0; cyl.height = 6.0; mountain_shape.shape = cyl; mountain_shape.position = MOUNTAIN + Vector3(0, 3, 0); body.add_child(mountain_shape)
	var edge := CollisionShape3D.new(); var ring := CylinderShape3D.new(); ring.radius = 0.5; ring.height = 4
	# keep the elf on the clearing
	for i in 24:
		var a := TAU * i / 24.0
		var c2 := CollisionShape3D.new(); var b2 := BoxShape3D.new(); b2.size = Vector3(10, 4, 1); c2.shape = b2
		c2.position = Vector3(cos(a) * 34, 2, 4 + sin(a) * 34); c2.rotation.y = -a + PI / 2; body.add_child(c2)
	# interaction target: the dough mountain
	var area := _target("take", Vector3.ZERO, Vector3.ONE)
	area.remove_child(area.get_child(0))
	mountain_area = CollisionShape3D.new(); var sph := SphereShape3D.new(); sph.radius = 4.2; mountain_area.shape = sph; mountain_area.position = MOUNTAIN + Vector3(0, 0.8, 0); area.add_child(mountain_area)

# Warm window glass becomes see-through (you look out into the snow), wood gets grain.
func _style(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if not mesh: continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if not mat: continue
			if mat.resource_name == "Warm window":
				var g := StandardMaterial3D.new(); g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; g.albedo_color = Color(1, 0.85, 0.6, 0.18); g.roughness = 0.05; g.metallic = 0.2
				g.emission_enabled = true; g.emission = Color(1, 0.6, 0.25); g.emission_energy_multiplier = 0.25; g.cull_mode = BaseMaterial3D.CULL_DISABLED
				(mi as MeshInstance3D).set_surface_override_material(i, g)
			elif mat.resource_name in ["Oven window", "Oven glow", "Lantern glass", "Lantern light"]:
				var gm := mat.duplicate() as StandardMaterial3D
				gm.emission_energy_multiplier = {"Oven window": 0.35, "Oven glow": 1.4, "Lantern glass": 0.8, "Lantern light": 1.5}[mat.resource_name]
				(mi as MeshInstance3D).set_surface_override_material(i, gm)
			elif mat.resource_name == "Flour":
				var fm := mat.duplicate() as StandardMaterial3D
				fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.albedo_color = Color(1, 1, 1, 0.35)
				(mi as MeshInstance3D).set_surface_override_material(i, fm)
			elif mat.resource_name in ["Log wood", "Floor planks", "Bench wood", "Dark wood", "Dark beam"]:
				var wm := mat.duplicate() as StandardMaterial3D
				var tex := NoiseTexture2D.new(); var n := FastNoiseLite.new(); n.frequency = 0.02; n.fractal_octaves = 3; n.noise_type = FastNoiseLite.TYPE_PERLIN
				tex.noise = n; tex.width = 256; tex.height = 256; tex.seamless = true
				var ramp := Gradient.new(); ramp.set_color(0, mat.albedo_color.darkened(0.4)); ramp.set_color(1, mat.albedo_color.darkened(0.05)); tex.color_ramp = ramp
				wm.albedo_texture = tex; wm.albedo_color = Color(1, 1, 1); wm.uv1_scale = Vector3(1, 8, 1); wm.uv1_triplanar = true; wm.uv1_triplanar_sharpness = 2.0
				(mi as MeshInstance3D).set_surface_override_material(i, wm)

func _target(action: String, pos: Vector3, size: Vector3, parent: Node3D = null) -> Area3D:
	var a := Area3D.new(); a.collision_layer = 2; a.collision_mask = 0; a.monitoring = false
	a.set_meta("action", action)
	var c := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; c.shape = b; a.add_child(c)
	a.position = pos
	(parent if parent else self).add_child(a)
	return a

# ---------------------------------------------------------------- the production line
func _line() -> void:
	line = Node3D.new(); line.position = LINE; add_child(line)
	var put := func(name: String, from: Node3D, p: Vector3, ry := 0.0, sc := 1.0) -> Node3D:
		var n := _grab(from, name); n.position = p; n.rotation.y = ry; n.scale = Vector3.ONE * sc; line.add_child(n); return n
	put.call("Workbench", nodes.props, Vector3.ZERO)
	_style(line)
	for x in [-1.55, 1.45]:
		put.call("Candle", nodes.props, Vector3(x, BENCH_Y, 0.38))
		var fl := OmniLight3D.new(); fl.light_color = Color("ffc46a"); fl.light_energy = 0.3; fl.omni_range = 2.0; fl.position = Vector3(x, BENCH_Y + 0.25, 0.38); line.add_child(fl)
		var flame := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.018; fm.height = 0.07; flame.mesh = fm
		var fmat := StandardMaterial3D.new(); fmat.emission_enabled = true; fmat.emission = Color("ffcf5a"); fmat.emission_energy_multiplier = 3; fmat.albedo_color = Color("ffcf5a"); fm.material = fmat
		flame.position = Vector3(x, BENCH_Y + 0.2, 0.38); line.add_child(flame); (parts.get_or_add("flames", []) as Array).append(flame)
	parts.pin = put.call("RollingPin", nodes.props, Vector3(0.3, BENCH_Y + 0.045, 0.38))
	parts.cutter = put.call("StarCutter", nodes.props, Vector3(-0.45, BENCH_Y + 0.005, 0.34))
	parts.tray = put.call("Tray", nodes.props, Vector3(-1.2, BENCH_Y + 0.01, 0.02))
	put.call("DoughBowl", nodes.bakery, Vector3(0.95, BENCH_Y, 0.02))
	parts.bowl_dough = put.call("BowlDough", nodes.bakery, Vector3(0.95, BENCH_Y, 0.02))
	put.call("FlourDust", nodes.bakery, Vector3(0.12, BENCH_Y + 0.002, 0.05), 0.0, 0.55)
	put.call("Lantern", nodes.bakery, Vector3(1.5, BENCH_Y, -0.32))
	put.call("Mug", nodes.bakery, Vector3(-1.62, BENCH_Y, -0.3), 0.6)
	put.call("CandyJar", nodes.bakery, Vector3(1.55, BENCH_Y, 0.25))
	var dough_mat := StandardMaterial3D.new(); dough_mat.albedo_color = Color("f2dcae"); dough_mat.roughness = 0.85
	var sheet := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(0.7, 0.012, 0.4); sm.material = dough_mat; sheet.mesh = sm; sheet.position = Vector3(-0.25, BENCH_Y + 0.007, 0.02); line.add_child(sheet); parts.sheet = sheet
	var rolling := MeshInstance3D.new(); var rm := SphereMesh.new(); rm.radius = 0.09; rm.height = 0.18; rm.material = dough_mat; rolling.mesh = rm; line.add_child(rolling); parts.rolling = rolling
	parts.balls = []
	for i in 6:
		var b := _grab(nodes.mountain_scene, "DoughBlob"); b.scale = Vector3.ONE * 0.85; b.position = Vector3(0.45 + (i % 3) * 0.1, BENCH_Y + 0.07, -0.2 + (i / 3) * 0.1); line.add_child(b); parts.balls.append(b)
	put.call("Shelf", nodes.props, Vector3(-0.3, 1.95, -2.05))
	_style(line)
	# targets on the bench
	_target("deliver", Vector3(0.92, BENCH_Y + 0.12, 0.02), Vector3(0.6, 0.3, 0.55), line)
	_target("roll", Vector3(0.15, BENCH_Y + 0.1, 0.02), Vector3(0.55, 0.25, 0.5), line)
	_target("cut", Vector3(-0.45, BENCH_Y + 0.1, 0.02), Vector3(0.5, 0.25, 0.5), line)
	_target("load", Vector3(-1.2, BENCH_Y + 0.08, 0.02), Vector3(0.7, 0.22, 0.5), line)
	var book := _target("shop", Vector3(-2.75, 1.45, 0.4), Vector3(0.6, 0.5, 0.4), line)
	var lectern := MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.5, 1.2, 0.4); var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color("5a3a22"); lm.material = lmat; lectern.mesh = lm; lectern.position = Vector3(-2.75, 0.6, 0.4); line.add_child(lectern)
	var bookm := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.46, 0.06, 0.34); var bkm := StandardMaterial3D.new(); bkm.albedo_color = Color("a3121c"); bb.material = bkm; bookm.mesh = bb; bookm.position = Vector3(-2.75, 1.24, 0.4); bookm.rotation.x = -0.3; line.add_child(bookm)
	var page := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.42, 0.02, 0.3); var pm := StandardMaterial3D.new(); pm.albedo_color = Color("fbf1dc"); pm.emission_enabled = true; pm.emission = Color(0.4, 0.35, 0.25); pb.material = pm; page.mesh = pb; page.position = Vector3(-2.75, 1.28, 0.4); page.rotation.x = -0.3; line.add_child(page)
	book.position.y = 1.3
	# crate with Schokotaler at the belt end, a slide from the belt into it
	var crate := Node3D.new(); crate.position = CRATE; line.add_child(crate); parts.crate = crate
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("8a5a33"); wood.roughness = 0.8
	for sp in [[Vector3(0.8, 0.05, 0.62), Vector3(0, 0.025, 0)], [Vector3(0.8, 0.5, 0.05), Vector3(0, 0.25, 0.3)], [Vector3(0.8, 0.5, 0.05), Vector3(0, 0.25, -0.3)], [Vector3(0.05, 0.5, 0.62), Vector3(0.38, 0.25, 0)], [Vector3(0.05, 0.5, 0.62), Vector3(-0.38, 0.25, 0)]]:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = sp[0]; cs.shape = bs; sb.add_child(cs); sb.position = sp[1]; sb.collision_layer = 4; crate.add_child(sb)
	var crate_model := _grab(nodes.bakery, "CoinCrate"); crate.add_child(crate_model)
	var slide := MeshInstance3D.new(); var sl := BoxMesh.new(); sl.size = Vector3(0.6, 0.02, 0.3); var steel := StandardMaterial3D.new(); steel.albedo_color = Color("b9c2cc"); steel.metallic = 0.7; steel.roughness = 0.3; sl.material = steel; slide.mesh = sl
	slide.position = Vector3(1.78, 0.88, BELT.z); slide.rotation.z = -0.75; line.add_child(slide)
	var ssb := StaticBody3D.new(); var scs := CollisionShape3D.new(); var sbs := BoxShape3D.new(); sbs.size = Vector3(0.6, 0.02, 0.3); scs.shape = sbs; ssb.add_child(scs); ssb.position = slide.position; ssb.rotation = slide.rotation; ssb.collision_layer = 4; line.add_child(ssb)
	# coins in the crate (one per 1/2000 of the goal, shown as a growing heap)
	coin_pile = MultiMeshInstance3D.new()
	var cm := MultiMesh.new(); cm.transform_format = MultiMesh.TRANSFORM_3D
	var coin := CylinderMesh.new(); coin.top_radius = 0.03; coin.bottom_radius = 0.03; coin.height = 0.008; coin.radial_segments = 16
	var gold := StandardMaterial3D.new(); gold.albedo_color = Color("f2c14a"); gold.metallic = 0.9; gold.roughness = 0.25; gold.emission_enabled = true; gold.emission = Color(0.25, 0.15, 0.0); coin.material = gold
	var coin_node: Node = nodes.bakery.find_child("Coin", true, false)
	var coin_mi: MeshInstance3D = coin_node if coin_node is MeshInstance3D else (coin_node.find_children("*", "MeshInstance3D", true, false)[0] if coin_node else null)
	cm.mesh = coin_mi.mesh if coin_mi else coin; cm.instance_count = 600; cm.visible_instance_count = 0; coin_pile.multimesh = cm; crate.add_child(coin_pile)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 600:
		var layer := i / 60
		var tr := Transform3D(Basis(Vector3(rng.randf() - 0.5, 1, rng.randf() - 0.5).normalized(), rng.randf() * 0.5), Vector3(rng.randf_range(-0.33, 0.33), 0.06 + layer * 0.03 + rng.randf() * 0.01, rng.randf_range(-0.25, 0.25)))
		cm.set_instance_transform(i, tr)
	# instanced cookies for belts, trays and the backlog
	cookies = MultiMeshInstance3D.new()
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = _star_mesh(); mm.instance_count = MAX_COOKIES; mm.visible_instance_count = 0
	cookies.multimesh = mm; line.add_child(cookies)
	for i in BAKE_STEPS: bake_cols.append(Color("f6e2b8").lerp(Color("c27a2c"), float(i) / (BAKE_STEPS - 1)))
	belt_root = Node3D.new(); line.add_child(belt_root)
	belt_mat = StandardMaterial3D.new(); belt_mat.albedo_color = Color(1, 1, 1); belt_mat.roughness = 0.7
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8); img.fill(Color("242424"))
	for x in range(0, 64, 16):
		for y in 8: img.set_pixel(x, y, Color("5a5a5a")); img.set_pixel(x + 1, y, Color("5a5a5a"))
	belt_mat.albedo_texture = ImageTexture.create_from_image(img); belt_mat.uv1_scale = Vector3(12, 1, 1)
	# physics cookies that tumble into the crate
	var star_shape := CylinderShape3D.new(); star_shape.radius = 0.034; star_shape.height = 0.014
	var star_mesh := _star_mesh()
	var pm2 := StandardMaterial3D.new(); pm2.albedo_color = bake_cols[BAKE_STEPS - 1]; pm2.roughness = 0.75
	for i in 50:
		var rb := RigidBody3D.new(); rb.mass = 0.025; rb.collision_layer = 8; rb.collision_mask = 4 | 8; rb.freeze = true; rb.visible = false
		var cs := CollisionShape3D.new(); cs.shape = star_shape; rb.add_child(cs)
		var mi := MeshInstance3D.new(); mi.mesh = star_mesh; mi.material_override = pm2; rb.add_child(mi)
		rb.set_meta("age", 0.0); line.add_child(rb); physics_cookies.append(rb)

func _star_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in 10:
		var r := 0.038 if i % 2 == 0 else 0.02
		var a := -PI / 2 + i * PI / 5
		pts.append(Vector2(cos(a), sin(a)) * r)
	var h := 0.012
	for i in 10:
		var a := pts[i]; var b := pts[(i + 1) % 10]
		st.set_normal(Vector3.UP); st.add_vertex(Vector3(0, h, 0)); st.add_vertex(Vector3(b.x, h, b.y)); st.add_vertex(Vector3(a.x, h, a.y))
		st.set_normal(Vector3.DOWN); st.add_vertex(Vector3(0, 0, 0)); st.add_vertex(Vector3(a.x, 0, a.y)); st.add_vertex(Vector3(b.x, 0, b.y))
		var n := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		st.set_normal(n); st.add_vertex(Vector3(a.x, 0, a.y)); st.add_vertex(Vector3(a.x, h, a.y)); st.add_vertex(Vector3(b.x, h, b.y))
		st.add_vertex(Vector3(a.x, 0, a.y)); st.add_vertex(Vector3(b.x, h, b.y)); st.add_vertex(Vector3(b.x, 0, b.y))
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.75
	st.set_material(m)
	return st.commit()

func _build_belts() -> void:
	var floors: int = mini(3, d.floors)
	var lanes: int = mini(4, d.lanes)
	var key := "%d:%d:%d:%d" % [floors, lanes, CookieSim.lv(s.levels, "turboofen"), CookieSim.lv(s.levels, "goldstrasse")]
	if key == belt_key: return
	belt_key = key
	for c in belt_root.get_children(): c.queue_free()
	var oven_len: float = BELT.oven1 - BELT.oven0
	var len: float = BELT.x1 - BELT.x0
	var frame_mat := StandardMaterial3D.new(); frame_mat.albedo_color = Color("7a1d1a"); frame_mat.metallic = 0.4; frame_mat.roughness = 0.5
	var oven_mat := StandardMaterial3D.new(); oven_mat.albedo_color = Color("9b2a1a") if CookieSim.lv(s.levels, "turboofen") else Color("a3261c"); oven_mat.metallic = 0.35; oven_mat.roughness = 0.45
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color("c89a3a"); brass.metallic = 0.85; brass.roughness = 0.3
	var glow := StandardMaterial3D.new(); glow.albedo_color = Color("ff8a2a"); glow.emission_enabled = true; glow.emission = Color("ff6a00"); glow.emission_energy_multiplier = 3.0
	var box := func(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; b.material = mat; mi.mesh = b; mi.position = pos; belt_root.add_child(mi); return mi
	for f in floors:
		var y: float = BELT.y + f * BELT.floorH
		for l in lanes:
			var z: float = BELT.z - l * BELT.laneGap
			box.call(Vector3(len, 0.03, 0.2), Vector3(BELT.x0 + len / 2.0, y - 0.015, z), belt_mat)
			box.call(Vector3(len, 0.08, 0.025), Vector3(BELT.x0 + len / 2.0, y - 0.03, z + 0.11), frame_mat)
			box.call(Vector3(len, 0.08, 0.025), Vector3(BELT.x0 + len / 2.0, y - 0.03, z - 0.11), frame_mat)
			if f == 0:
				for x in [BELT.x0 + 0.15, BELT.x0 + 1.0, BELT.x1 - 0.15]: box.call(Vector3(0.06, y - 0.05, 0.06), Vector3(x, (y - 0.05) / 2.0, z), frame_mat)
		# the riveted red oven tunnel (model), stretched for more lanes
		var depth := 0.36 + (lanes - 1) * BELT.laneGap
		var zc: float = BELT.z - (lanes - 1) * BELT.laneGap / 2.0
		var oven := _grab(nodes.bakery, "OvenTunnel"); oven.position = Vector3(0, y, zc); oven.scale = Vector3(1, 1, (depth + 0.2) / 0.56); belt_root.add_child(oven)
		var inner := _grab(nodes.bakery, "OvenGlow"); inner.position = oven.position; inner.scale = oven.scale; belt_root.add_child(inner)
		if f == 0:
			for l in lanes:
				for seg in 4:
					var fr := _grab(nodes.bakery, "ConveyorFrame"); fr.position = Vector3(BELT.x0 + 0.5 + seg * (len - 1.0) / 3.0, y, BELT.z - l * BELT.laneGap); fr.scale = Vector3((len) / 4.0, 1, 1) if false else Vector3.ONE; belt_root.add_child(fr)
		var light := OmniLight3D.new(); light.light_color = Color("ff8a3a"); light.light_energy = 1.6; light.omni_range = 3.2; light.position = Vector3(0, y + 0.25, zc + 0.7); belt_root.add_child(light)

# ---------------------------------------------------------------- machines (show when bought)
func _machines() -> void:
	var place := func(id: String, from: Node3D, name: String, p: Vector3, ry := 0.0, sc := 1.0) -> Node3D:
		var n := _grab(from, name); n.position = p; n.rotation.y = ry; n.scale = Vector3.ONE * sc; n.visible = false; line.add_child(n)
		(machines.get_or_add(id, []) as Array).append(n); return n
	place.call("portionierer", nodes.parts, "HopperBody", Vector3(0.95, 1.7, 0.02))
	place.call("extruder", nodes.machines, "Extruder", Vector3(0.95, 1.75, -0.15), 0.0, 0.75)
	place.call("walze", nodes.parts, "RollerFrame", Vector3(0.15, BENCH_Y, 0.02))
	parts.rollers = [place.call("walze", nodes.parts, "Roller", Vector3(0.15, BENCH_Y + 0.05, 0.02)), place.call("walze", nodes.parts, "Roller", Vector3(0.15, BENCH_Y + 0.15, 0.02))]
	parts.flywheel = place.call("walze", nodes.parts, "Flywheel", Vector3(0.15, BENCH_Y + 0.2, 0.4))
	place.call("stanzpresse", nodes.parts, "PressFrame", Vector3(-0.45, BENCH_Y, -0.05))
	parts.stamp = place.call("stanzpresse", nodes.parts, "PressStamp", Vector3(-0.45, BENCH_Y + 0.62, -0.05))
	parts.lever = place.call("stanzpresse", nodes.parts, "PressLever", Vector3(-0.17, BENCH_Y + 0.6, -0.05))
	place.call("steuerung", nodes.machines, "ControlPanel", Vector3(-3.2, 0, -0.6), PI / 2)
	place.call("platzierung", nodes.parts, "ArmBase", Vector3(-1.85, BELT.y - 0.05, BELT.z + 0.45))
	parts.arm_upper = place.call("platzierung", nodes.parts, "ArmUpper", Vector3(-1.85, BELT.y + 0.25, BELT.z + 0.45))
	place.call("portale", nodes.machines, "Portal", Vector3(-2.35, BELT.y + 0.3, BELT.z), PI / 2)
	place.call("rentier", nodes.machines, "Generator", Vector3(-2.9, 0, -2.6), 0.0, 1.2)
	parts.gears = [place.call("motor", nodes.machines, "Gear", Vector3(BELT.x0 + 0.1, BELT.y - 0.2, BELT.z + 0.3)), place.call("syncband", nodes.machines, "Gear", Vector3(BELT.oven1 + 0.2, BELT.y - 0.25, BELT.z + 0.25))]
	var pump := _grab(nodes.machines, "Pump"); pump.position = Vector3(5.6, 0, 12.4); pump.rotation.y = -PI / 2; pump.visible = false; add_child(pump)
	(machines.get_or_add("portionierer", []) as Array).append(pump)
	var curve := Curve3D.new()
	for p in [Vector3(4.5, 0.3, 14.5), Vector3(5.6, 0.6, 12.6), Vector3(5.6, 0.9, 6), Vector3(5.6, 3.3, 4.6), Vector3(5.6, 3.6, 3), Vector3(0, 3.6, -1), LINE + Vector3(0.95, 2.1, 0.02)]: curve.add_point(p)
	var pipe_mi := MeshInstance3D.new()
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color("a9b2bc"); steel.metallic = 0.75; steel.roughness = 0.35
	var pipe := ImmediateMesh.new()
	var pts := curve.tessellate(4, 3)
	pipe.surface_begin(Mesh.PRIMITIVE_TRIANGLES, steel)
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]; var dir := (b - a).normalized()
		var u := dir.cross(Vector3.UP); if u.length() < 0.1: u = dir.cross(Vector3.RIGHT)
		u = u.normalized(); var v := dir.cross(u).normalized()
		for k in 10:
			var a0 := TAU * k / 10.0; var a1 := TAU * (k + 1) / 10.0
			var o0 := (u * cos(a0) + v * sin(a0)) * 0.07; var o1 := (u * cos(a1) + v * sin(a1)) * 0.07
			for q in [[a, o0], [b, o0], [b, o1], [a, o0], [b, o1], [a, o1]]:
				pipe.surface_set_normal(q[1].normalized()); pipe.surface_add_vertex(q[0] + q[1])
	pipe.surface_end()
	pipe_mi.mesh = pipe; pipe_mi.visible = false; add_child(pipe_mi)
	(machines.get_or_add("portionierer", []) as Array).append(pipe_mi)
	parts.pipe_curve = curve

# ---------------------------------------------------------------- player
func _player() -> void:
	player = ElfPlayer.new()
	add_child(player)
	player.build(load("res://assets/models/elf-arm.glb"))
	player.position = Vector3(0.2, 0.05, 1.4)
	player.rotation.y = 0.4
	player.interact.connect(_perform)
	player.drop_requested.connect(_drop)
	player.stepped.connect(func(outside): sfx.step(outside))
	player.outside_fn = func(p: Vector3): return not _inside(p)
	var held := _grab(nodes.mountain_scene, "DoughBlob"); held.visible = false; player.camera.add_child(held); held.position = Vector3(0, -0.21, -0.55); parts.held = held
	var bucket := _grab(nodes.props, "Bucket"); bucket.scale = Vector3.ONE * 0.55; bucket.visible = false; bucket.position = Vector3(-0.26, -0.55, -0.45); player.camera.add_child(bucket); parts.bucket = bucket
	var barrow := _grab(nodes.props, "Wheelbarrow"); barrow.scale = Vector3.ONE * 0.85; barrow.visible = false; barrow.position = Vector3(0, -1.45, -1.15); barrow.rotation.y = PI; player.camera.add_child(barrow); parts.barrow = barrow
	var tools := [null, _grab(nodes.props, "RollingPin"), _grab(nodes.props, "StarCutter"), _grab(nodes.props, "Tray")]
	parts.hand_tools = tools
	for i in range(1, 4):
		var tl: Node3D = tools[i]; tl.visible = false; player.camera.add_child(tl)
	tools[1].position = Vector3(0, -0.27, -0.52)
	tools[2].position = Vector3(0.2, -0.22, -0.45); tools[2].scale = Vector3.ONE * 1.4
	tools[3].position = Vector3(0, -0.28, -0.6); tools[3].scale = Vector3.ONE * 0.8

func _inside(p: Vector3) -> bool:
	return p.x > -7 and p.x < 7 and p.z > -6 and p.z < 4

func route_for(action: String, from: Vector3) -> Array:
	var spot: Dictionary = SPOTS[ACTION_SPOT.get(action, "bench")]
	var pts := []
	var now_in := _inside(from)
	if now_in and spot.outside: pts.append_array([{"x": 2.5, "z": 2.8}, {"x": 2.5, "z": 5.6}])
	if not now_in and not spot.outside: pts.append_array([{"x": 2.5, "z": 5.6}, {"x": 2.5, "z": 2.8}])
	if action == "shop": pts.append({"x": -3.1, "z": 0.3, "yaw": PI / 2})
	else: pts.append({"x": spot.x, "z": spot.z, "yaw": spot.yaw})
	return pts

# ---------------------------------------------------------------- actions
func _perform(action: String) -> void:
	sfx.start_music()
	if action == "shop":
		_open_shop(); return
	var n := 0
	match action:
		"take": n = CookieSim.act_take(s, d)
		"deliver": n = CookieSim.act_deliver(s, d)
		"roll": n = CookieSim.act_roll(s, d)
		"cut": n = CookieSim.act_cut(s, d)
		"load": n = CookieSim.act_load(s, d)
	var tool_for := {"take": 0, "deliver": 0, "roll": 1, "cut": 2, "load": 3}
	if tool_for.has(action): player.tool = tool_for[action]
	if n == 0 and action != "roll":
		var why := _why_not(action)
		if why != "": hud.show_toast(why)

func _why_not(action: String) -> String:
	match action:
		"take": return "Deine Hände sind voll – bring den Teig zur Werkbank." if s.carry >= d.carryCap else ""
		"deliver": return "Erst draußen am Teigberg Teig greifen." if s.carry <= 0 else "Auf der Werkbank ist kein Platz mehr."
		"roll": return "Kein Teig zum Ausrollen."
		"cut": return "Erst Teig ausrollen." if s.sheet <= 0 else "Das Blech ist voll – heb es aufs Band."
		"load": return "Das Blech ist leer." if s.tray <= 0 else "Vor dem Ofen ist alles voll."
	return ""

func _drop() -> void:
	if s.carry > 0 and _inside(player.global_position) and player.global_position.distance_to(LINE + Vector3(0.9, 0, 0)) < 2.5:
		_perform("deliver")
	elif s.carry > 0:
		hud.show_toast("Leg den Teig auf der Werkbank ab – draußen wird er kalt.")
	else:
		player.tool = 0

func _next_step() -> String:
	if s.tray > 0 and (s.tray >= d.trayCap or (s.sheet == 0 and s.ball == 0)) and s.queue < d.queueCap: return "load"
	if s.sheet > 0 and s.tray < d.trayCap: return "cut"
	if s.ball > 0 and s.sheet < d.sheetCap: return "roll"
	if s.carry > 0 and s.ball < d.ballCap: return "deliver"
	if s.dough > 0 and s.ball < d.sheetSize and d.autoPortion <= 0.0: return "take"
	if s.tray > 0: return "load"
	return ""

func _buy(id: String) -> void:
	if CookieSim.buy(s, id):
		d = CookieSim.derive(s.levels)
		hud.shop_dirty = true
		_save(false)

func _open_shop() -> void:
	hud.toggle_shop(true); player.release(); paused_ui = true

func _resume() -> void:
	hud.toggle_shop(false); hud.toggle_settings(false); paused_ui = false; player.capture()

func _new_game() -> void:
	s = CookieSim.create(); d = CookieSim.derive(s.levels); finale_shown = false
	_save(true, true); _resume()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop"):
		if hud.shop.visible: _resume()
		else: _open_shop()
	elif event.is_action_pressed("next") and not paused_ui:
		var a := _next_step()
		if a != "": player.go_to(a) if not _near_spot(a) else _perform(a)
	elif event.is_action_pressed("menu"):
		if hud.shop.visible or hud.settings.visible: _resume()
		else:
			hud.toggle_settings(true); player.release(); paused_ui = true

func _near_spot(action: String) -> bool:
	var sp: Dictionary = SPOTS[ACTION_SPOT[action]]
	return Vector2(player.global_position.x - sp.x, player.global_position.z - sp.z).length() < 1.4

# ---------------------------------------------------------------- frame
func _process(delta: float) -> void:
	if not s or not ready_state:
		_poll_save(); return
	t += delta
	d = CookieSim.step(s, delta)
	var outside := not _inside(player.global_position)
	for e in s.events:
		match e.type:
			"land": landings.append([t, int(e.n)])
			"finale":
				_finale()
		if e.type in ["take", "roll", "rolled", "crank", "cut", "press", "load", "portion"]: player.anim[e.type] = 1.0
	sfx.handle(s.events)
	if s.events.size() and s.events.any(func(e): return e.type == "take"): _dough_burst()
	s.events.clear()
	_build_belts()
	_update_world(delta)
	player.animate(delta, t, {"holding": s.carry > 0})
	var oven_dist := player.global_position.distance_to(LINE + Vector3(0, 0, BELT.z))
	sfx.update(delta, outside, clampf(1.0 - oven_dist / 5.0, 0, 1), s.belt.size() > 0)
	while landings.size() and t - landings[0][0] > 4.0: landings.pop_front()
	var rate := 0.0
	for l in landings: rate += l[1]
	rate /= clampf(t, 1.0, 4.0)
	var look := {}
	if player.look_target.has("action"):
		var a: String = player.look_target.action
		var why := _blocked_hint(a)
		look = {"text": ("[E] " + LABELS[a] + ("" if player.look_target.near else "  (hinlaufen)")) if why == "" else why, "ok": why == ""}
	elif outside and s.carry > 0:
		look = {"text": "Bring den Teig in die Backstube zur Werkbank", "ok": true}
	var q := _next_step()
	var quest_text: String = QUEST.get(q, "") if (CookieSim.phase_of(s) <= 2 or _hand_work()) and s.finished == null else ""
	hud.update(s, d, rate, look, quest_text, player.tool, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, delta)
	save_clock += delta; server_clock += delta
	if save_clock > 5.0:
		save_clock = 0.0; _save(server_clock > 30.0)
		if server_clock > 30.0: server_clock = 0.0

func _hand_work() -> bool:
	for c in CookieSim.capacities(d):
		if c.hand > 0.05: return true
	return false

func _blocked_hint(a: String) -> String:
	match a:
		"take": return "Hände voll – bring den Teig zur Werkbank" if s.carry >= d.carryCap else ""
		"deliver": return "Erst draußen am Teigberg Teig greifen" if s.carry <= 0 else ""
		"roll": return "Kein Teig zum Ausrollen" if s.ball <= 0 else ""
		"cut": return "Erst Teig ausrollen" if s.sheet <= 0 else ""
		"load": return "Das Blech ist leer" if s.tray <= 0 else ""
	return ""

func _dough_burst() -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.emitting = true; p.amount = 24; p.lifetime = 0.8; p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0); p.spread = 60; p.initial_velocity_min = 1.0; p.initial_velocity_max = 2.0; p.gravity = Vector3(0, -6, 0)
	var m := SphereMesh.new(); m.radius = 0.02; m.height = 0.04; var mat := StandardMaterial3D.new(); mat.albedo_color = Color("f2dcae"); m.material = mat; p.mesh = m
	p.position = player.global_position + (-player.global_transform.basis.z * 1.2) + Vector3(0, 1.0, 0); add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _update_world(delta: float) -> void:
	var L: Dictionary = s.levels
	# mountain shrinks as the dough is used
	var ms := 0.18 + 0.82 * pow(float(s.dough) / CookieSim.GOAL, 1.0 / 3.0)
	if mountain: mountain.scale = Vector3(ms, maxf(0.05, ms), ms)
	(mountain_shape.shape as CylinderShape3D).radius = 4.0 * ms
	(mountain_area.shape as SphereShape3D).radius = 4.2 * ms + 0.4
	parts.snow.position = Vector3(player.global_position.x, 12, player.global_position.z)
	# what the elf holds
	var hands_hold: bool = s.carry > 0 and not CookieSim.lv(L, "eimer") and not CookieSim.lv(L, "schubkarre")
	parts.held.visible = hands_hold
	parts.held.scale = Vector3.ONE * 1.25 * (0.6 + 0.4 * float(s.carry) / d.carryCap)
	parts.bucket.visible = CookieSim.lv(L, "eimer") > 0 and not CookieSim.lv(L, "schubkarre") and d.autoPortion <= 0.0
	parts.barrow.visible = CookieSim.lv(L, "schubkarre") > 0 and d.autoPortion <= 0.0 and (s.carry > 0 or not _inside(player.global_position))
	for i in range(1, 4): (parts.hand_tools[i] as Node3D).visible = player.tool == i and s.carry == 0
	# bench
	var fill_b := clampf(float(s.ball) / maxf(1.0, d.ballCap), 0.0, 1.0)
	parts.bowl_dough.visible = s.ball > 0
	parts.bowl_dough.scale = Vector3(0.6 + fill_b * 0.45, 0.4 + fill_b * 0.9, 0.6 + fill_b * 0.45)
	var n_balls := 0 if s.rollProgress <= 0 else 1
	for i in 6: (parts.balls[i] as Node3D).visible = i < n_balls and not (i == 0 and s.rollProgress > 0)
	parts.rolling.visible = s.rollProgress > 0 and s.ball > 0
	if parts.rolling.visible:
		var p: float = s.rollProgress
		parts.rolling.scale = Vector3(1 + p * 2.6, 0.7 - p * 0.55, 1 + p * 1.4); parts.rolling.position = Vector3(0.15, BENCH_Y + 0.04 - p * 0.02, 0.02)
	parts.sheet.visible = s.sheet > 0
	if parts.sheet.visible:
		var k := clampf(float(s.sheet) / (d.sheetSize * 2.0), 0.25, 1.0)
		parts.sheet.scale.x = k; parts.sheet.position.x = -0.6 + 0.35 * k
	parts.pin.visible = not d.walze and d.autoRoll <= 0.0 and player.tool != 1
	parts.cutter.visible = not d.pressSize and d.autoCut <= 0.0 and player.tool != 2
	parts.tray.visible = player.tool != 3
	if belt_root.get_child_count() and str(belt_root.get_meta("styled", "")) != belt_key:
		_style(belt_root); belt_root.set_meta("styled", belt_key)
	for f in parts.flames: f.scale.y = 1.0 + sin(t * 13.0 + f.position.x) * 0.15
	# machines
	for id in machines:
		var on := CookieSim.lv(L, id) > 0
		if id == "walze": on = d.walze or d.autoRoll > 0.0
		if id == "stanzpresse": on = d.pressSize > 0 or d.autoCut > 0.0
		for n in machines[id]: n.visible = on
	var working: bool = s.dough > 0 or s.ball > 0 or s.sheet > 0
	var cyc: float = (sin(t * minf(14.0, 4.0 + d.autoCut / 60.0)) + 1.0) / 2.0 if d.autoCut > 0.0 and working else sin(PI * clampf(1.0 - player.anim.get("press", 0.0), 0, 1)) * (1.0 if player.anim.get("press", 0.0) > 0 else 0.0)
	parts.stamp.position.y = BENCH_Y + 0.62 - cyc * 0.3; parts.lever.rotation.z = -cyc * 0.9
	var spin: float = t * 7.0 if d.autoRoll > 0.0 else (player.anim.get("crank", 0.0) + player.anim.get("roll", 0.0)) * 6.0
	parts.rollers[0].rotation.z = spin; parts.rollers[1].rotation.z = -spin; parts.flywheel.rotation.z = spin
	parts.arm_upper.rotation.y = sin(t * 2.4) * 0.9
	for g in parts.gears: g.rotation.z = t * d.speed * 3.0
	belt_mat.uv1_offset.x = -t * d.speed * 0.6
	parts.tree_light.light_energy = 1.2 + sin(t * 2.2) * 0.3
	_update_cookies(delta)

func _update_cookies(delta: float) -> void:
	var mm := cookies.multimesh
	var i := 0
	var raw: Color = bake_cols[0]
	var baked: Color = bake_cols[BAKE_STEPS - 1]
	var finale: bool = s.finished != null
	var lift := sin(PI * clampf(1.0 - player.anim.get("load", 0.0), 0, 1)) * 0.25 if player.anim.get("load", 0.0) > 0 else 0.0
	parts.tray.position = Vector3(-1.2, BENCH_Y + 0.01 + lift, 0.02 - lift * 2.2)
	for k in mini(s.tray, 40):
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, k * 0.7), Vector3(-1.45 + (k % 8) * 0.07, BENCH_Y + 0.025 + lift, -0.13 + (k / 8) * 0.075 - lift * 2.2))); mm.set_instance_color(i, raw); i += 1
	for k in mini(s.queue, 120):
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, k * 0.9), Vector3(BELT.x0 + 0.15 + (k % 12) * 0.07, BELT.y + 0.01 + (k / 36) * 0.015, BELT.z - 0.07 + ((k / 12) % 3) * 0.07))); mm.set_instance_color(i, raw); i += 1
	var floors: int = mini(3, d.floors)
	var lanes: int = mini(4, d.lanes)
	var rows: int = mini(3, roundi(d.perRow))
	var slot_w: float = (BELT.oven1 - BELT.oven0) / CookieSim.OVEN_SLOTS
	var cells := int(CookieSim.OVEN_SLOTS * 3)
	var occ := PackedInt64Array(); occ.resize(cells + 1)
	for b in s.belt: occ[clampi(int(float(b[0]) * 3.0), 0, cells)] += int(b[1])
	var per_cell := floors * lanes * rows
	if finale:
		var shift := int(t * d.speed * 3.0)
		for k in cells:
			if (k + shift) % 2 == 0: occ[k] = maxi(occ[k], per_cell)
	for k in cells:
		var n := mini(occ[k], per_cell)
		if n <= 0: continue
		var pos := (k + 0.5) / 3.0
		var bake := mini(BAKE_STEPS - 1, int(pos / CookieSim.OVEN_SLOTS * BAKE_STEPS))
		var col: Color = Color("ffd84a") if finale or (CookieSim.lv(s.levels, "goldstrasse") and bake > 6) else bake_cols[bake]
		for slot in n:
			if i >= MAX_COOKIES: break
			var f := slot / (lanes * rows); var l := (slot / rows) % lanes; var r := slot % rows
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, k * 1.3), Vector3(BELT.oven0 + pos * slot_w, BELT.y + f * BELT.floorH + 0.01, BELT.z - l * BELT.laneGap - 0.06 + r * 0.06))); mm.set_instance_color(i, col); i += 1
	for k in mini(s.exit, 30):
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, k), Vector3(BELT.oven1 + 0.1 + (k % 5) * 0.06, BELT.y + 0.01 + (k / 15) * 0.015, BELT.z - 0.06 + ((k / 5) % 3) * 0.06))); mm.set_instance_color(i, baked); i += 1
	mm.visible_instance_count = i
	# falling cookies become real physics bodies that tumble down the slide into the crate
	var spawn := 0
	for fb in s.falling:
		if not (fb as Array).size() > 2:
			(fb as Array).append(true)
			spawn += mini(int(fb[1]), 2)
	for rb in physics_cookies:
		if spawn <= 0: break
		if rb.visible and float(rb.get_meta("age")) < 3.0: continue
		rb.freeze = false; rb.visible = true; rb.set_meta("age", 0.0)
		rb.global_position = line.to_global(Vector3(BELT.x1 - 0.05, BELT.y + 0.05, BELT.z + randf_range(-0.05, 0.05)))
		rb.linear_velocity = Vector3(1.2, 0.3, 0); rb.angular_velocity = Vector3(randf() * 4, randf() * 4, randf() * 4)
		spawn -= 1
	for rb in physics_cookies:
		if rb.visible:
			rb.set_meta("age", float(rb.get_meta("age")) + delta)
			if float(rb.get_meta("age")) > 6.0: rb.visible = false; rb.freeze = true
	coin_pile.multimesh.visible_instance_count = mini(600, int(ceil(sqrt(float(s.baked) / CookieSim.GOAL) * 600.0)) if s.baked > 0 else 0)

# The serialized save must not contain the physics markers added to falling batches.
func _clean_state() -> Dictionary:
	var c := s.duplicate(true)
	var f := []
	for b in c.falling: f.append([b[0], b[1]])
	c.falling = f
	return c

func _finale() -> void:
	if finale_shown: return
	finale_shown = true
	_save(true)
	var title := "Oberster Keksmeister des Nordpols"
	if web:
		JavaScriptBridge.eval("window.ccFinale && window.ccFinale()")
	hud.show_finale(title); player.release(); paused_ui = true

# ---------------------------------------------------------------- saving (browser storage + website account)
const JS := """
window.ccLoad = async () => {
  try {
    const token = localStorage.getItem('aviary_token');
    let remote = null;
    if (token) { const r = await fetch('/api/cookie/save', { headers: { Authorization: 'Bearer ' + token } }); if (r.ok) remote = (await r.json()).save; }
    const local = [];
    for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); if (k && k.startsWith('aviary_cookie_save_')) local.push(localStorage.getItem(k)); }
    window.ccLoaded = JSON.stringify({ remote, local, user: Boolean(token) });
  } catch (e) { window.ccLoaded = JSON.stringify({ error: String(e), local: [] }); }
};
window.ccSave = (data, server, reset) => {
  try { localStorage.setItem('aviary_cookie_save_godot', data); } catch (e) {}
  const token = localStorage.getItem('aviary_token');
  if (server && token) fetch('/api/cookie/save', { method: 'PUT', keepalive: true, headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token }, body: JSON.stringify({ data, reset: Boolean(reset) }) }).catch(() => {});
};
window.ccFinale = () => {
  const token = localStorage.getItem('aviary_token');
  if (token) fetch('/api/cookie/finale', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token }, body: '{}' }).catch(() => {});
};
"""

func _load_save() -> void:
	if web:
		JavaScriptBridge.eval(JS, true)
		JavaScriptBridge.eval("window.ccLoaded = null; window.ccLoad();", true)
	else:
		if FileAccess.file_exists("user://save.json"):
			var loaded := CookieSim.deserialize(FileAccess.get_file_as_string("user://save.json"))
			if not loaded.is_empty(): s = loaded
		_start()

func _poll_save() -> void:
	if not web or ready_state: return
	var raw = JavaScriptBridge.eval("window.ccLoaded", true)
	if raw == null or str(raw) == "" or str(raw) == "null": return
	var info = JSON.parse_string(str(raw))
	var best := {}
	if typeof(info) == TYPE_DICTIONARY:
		var candidates := []
		if info.get("remote") != null: candidates.append(str(info.remote))
		for l in info.get("local", []): if l != null: candidates.append(str(l))
		for c in candidates:
			var st := CookieSim.deserialize(c)
			if not st.is_empty() and (best.is_empty() or int(st.baked) > int(best.baked)): best = st
	if not best.is_empty(): s = best
	_start()

func _start() -> void:
	d = CookieSim.derive(s.levels)
	ready_state = true
	finale_shown = s.finished != null

func _save(server: bool, reset := false) -> void:
	var text := CookieSim.serialize(_clean_state())
	if web:
		var win = JavaScriptBridge.get_interface("window")
		if win: win.ccSave(text, server, reset)
	else:
		var f := FileAccess.open("user://save.json", FileAccess.WRITE)
		if f: f.store_string(text)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if ready_state: _save(true)
