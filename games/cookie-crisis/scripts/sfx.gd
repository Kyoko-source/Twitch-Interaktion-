class_name CookieSfx
extends Node
## Sounds. Footsteps (snow / wood), cookie landings and Schokotaler are real recorded CC0 samples
## (Kenney, see assets/sfx/CREDITS.md) with small pitch/volume variation so nothing repeats exactly.
## A landing cookie: a soft wooden "tock" in the crate, then the coin ring of its taler. Many cookies
## at once become a coin shower (a few staggered coins, louder with more cookies) – never thousands
## of sounds. Rolling, cutting and pressing are small synthesised effects.

const RATE := 22050
var rec := {}          # name -> Array[AudioStream] (recorded variants)
var streams := {}      # synthesised
var pool: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var hum: AudioStreamPlayer
var land_queue := 0
var land_clock := 0.0
var scheduled: Array = []   # [time, name, db, pitch]
var clock := 0.0
var last_variant := {}
var volume := 0.8
var music_on := true

func _ready() -> void:
	for kind in ["step-snow", "step-wood"]:
		rec[kind] = []
		for i in 5: rec[kind].append(load("res://assets/sfx/%s-%d.ogg" % [kind, i]))
	rec["coin"] = []
	for i in range(1, 6): rec["coin"].append(load("res://assets/sfx/coin-%d.ogg" % i))
	rec["cookie"] = [load("res://assets/sfx/cookie-wood.ogg"), load("res://assets/sfx/cookie-soft.ogg")]
	rec["tray"] = [load("res://assets/sfx/tray-metal.ogg")]
	streams.take = _make(0.3, func(t, i): return _env(t, 0.01, 0.28) * (_noise(i) * 0.4 + sin(TAU * 140.0 * t) * 0.35))
	streams.roll = _make(0.32, func(t, i): return _env(t, 0.05, 0.25) * _brown(i) * 0.8 * (0.6 + 0.4 * sin(t * 40)))
	streams.cut = _make(0.12, func(t, i): return _env(t, 0.001, 0.1) * (_noise(i) * 0.35 + sin(TAU * 160.0 * t) * 0.5))
	streams.press = _make(0.3, func(t, i): return _env(t, 0.002, 0.28) * (sin(TAU * (95.0 - t * 80.0) * t) * 0.9 + _noise(i) * 0.2))
	streams.buy = _make(0.6, func(t, i): return _env(t, 0.005, 0.25) * sin(TAU * 880.0 * t) * 0.28 + _env(t - 0.12, 0.005, 0.45) * sin(TAU * 1320.0 * t) * 0.28)
	streams.machine = _make(0.9, func(t, i): return (_env(t, 0.005, 0.3) * sin(TAU * 523.0 * t) + _env(t - 0.1, 0.005, 0.3) * sin(TAU * 659.0 * t) + _env(t - 0.2, 0.005, 0.3) * sin(TAU * 784.0 * t) + _env(t - 0.3, 0.005, 0.55) * sin(TAU * 1047.0 * t)) * 0.22)
	streams.blocked = _make(0.15, func(t, i): return _env(t, 0.002, 0.13) * sin(TAU * 180.0 * t) * 0.25)
	for i in 14:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)
	wind = _loop(_make(3.0, func(t, i): return _brown(i) * 0.5, true), -60.0)
	hum = _loop(_make(2.0, func(t, i): return (sin(TAU * 55.0 * t) * 0.25 + _brown(i) * 0.35), true), -60.0)
	music = AudioStreamPlayer.new(); add_child(music)
	var mp3 := load("res://assets/music/gingerbread-workshop.mp3") as AudioStreamMP3
	if mp3:
		mp3.loop = true; music.stream = mp3; music.volume_db = -20.0

var _brown_v := 0.0
func _brown(_i: int) -> float:
	_brown_v = clampf(_brown_v * 0.985 + randf_range(-1, 1) * 0.06, -1, 1)
	return _brown_v

func _noise(_i: int) -> float:
	return randf_range(-1.0, 1.0)

func _env(t: float, attack: float, length: float) -> float:
	if t < 0.0 or t > length: return 0.0
	if t < attack: return t / attack
	return pow(1.0 - (t - attack) / maxf(0.0001, length - attack), 2.0)

func _make(seconds: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(fn.call(float(i) / RATE, i), -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	return w

func _loop(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.stream = stream; p.volume_db = db; add_child(p); p.play()
	return p

func _player() -> AudioStreamPlayer:
	for p in pool:
		if not p.playing: return p
	return null

func _stream(name: String) -> AudioStream:
	if rec.has(name):
		var list: Array = rec[name]
		var i := randi() % list.size()
		if list.size() > 1 and i == last_variant.get(name, -1): i = (i + 1) % list.size()
		last_variant[name] = i
		return list[i]
	return streams.get(name)

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if volume <= 0.0: return
	var st := _stream(name)
	var p := _player()
	if not st or not p: return
	p.stream = st; p.volume_db = db + linear_to_db(volume); p.pitch_scale = pitch; p.play()

func later(delay: float, name: String, db := 0.0, pitch := 1.0) -> void:
	scheduled.append([clock + delay, name, db, pitch])

func start_music() -> void:
	if music.stream and music_on and not music.playing: music.play()

func set_music(on: bool) -> void:
	music_on = on
	if on: start_music()
	else: music.stop()

func handle(events: Array) -> void:
	for e in events:
		match e.type:
			"land": land_queue += int(e.n)
			"take": play("take", -4.0, randf_range(0.9, 1.1))
			"roll", "rolled": play("roll", -2.0, randf_range(0.9, 1.1))
			"crank": play("roll", -2.0, 0.7)
			"cut": play("cut", -2.0, randf_range(0.9, 1.15))
			"press": play("press")
			"load", "push": play("tray", -6.0, randf_range(0.9, 1.05))
			"portion": play("take", -8.0, 1.3)
			"buy": play("buy", -4.0); play("coin", -6.0, 0.9)
			"machine", "finale": play("machine", -4.0); later(0.35, "coin", -4.0, 1.1)
			"blocked": play("blocked", -10.0)

# Called every frame.
func update(delta: float, outside: bool, oven_near: float, belt_running: bool) -> void:
	clock += delta
	for i in range(scheduled.size() - 1, -1, -1):
		var sch: Array = scheduled[i]
		if sch[0] <= clock:
			play(sch[1], sch[2], sch[3]); scheduled.remove_at(i)
	land_clock += delta
	if land_queue > 0 and land_clock > 0.09:
		if land_queue <= 3:
			# each cookie: tock in the crate, then its coin
			for k in land_queue:
				later(k * 0.07, "cookie", -14.0, randf_range(1.5, 1.85))
				later(k * 0.07 + 0.05, "coin", -5.0, randf_range(0.95, 1.12))
		else:
			# a shower: 3-5 coins, louder with more cookies, plus a couple of tocks
			var n := clampi(2 + int(log(float(land_queue)) / log(3.0)), 3, 5)
			var loud := clampf(-10.0 + log(float(land_queue)) * 1.6, -10.0, -2.0)
			for k in n:
				later(k * 0.035 + randf() * 0.02, "coin", loud - k * 0.8, randf_range(0.92, 1.2))
			later(0.0, "cookie", -16.0, randf_range(1.5, 1.8))
		land_queue = 0; land_clock = 0.0
	var lin := maxf(volume, 0.0001)
	wind.volume_db = lerpf(wind.volume_db, (-16.0 if outside else -36.0) + linear_to_db(lin), delta * 2.0)
	hum.volume_db = lerpf(hum.volume_db, (-24.0 + oven_near * 8.0 if belt_running and not outside else -55.0) + linear_to_db(lin), delta * 2.0)
	music.volume_db = -20.0 + linear_to_db(lin)

func step(outside: bool) -> void:
	if outside: play("step-snow", -4.0, randf_range(0.9, 1.08))
	else: play("step-wood", -7.0, randf_range(0.92, 1.08))
