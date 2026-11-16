class_name CookieSfx
extends Node
## Sounds made at start-up (no sample files): dough, rolling, cutting, pressing, steps on snow and
## wood, the soft "plop" + coin of a landing cookie, purchases. Many landings are clustered into
## one shimmer, so thousands of cookies per second never mean thousands of sounds.

const RATE := 22050
var streams := {}
var pool: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var hum: AudioStreamPlayer
var land_queue := 0
var land_clock := 0.0
var volume := 0.8
var music_on := true

func _ready() -> void:
	streams.plop = _make(0.12, func(t, i): return _env(t, 0.004, 0.11) * sin(TAU * (330.0 - t * 1400.0) * t) * 0.8)
	streams.coin = _make(0.18, func(t, i): return _env(t, 0.002, 0.17) * (sin(TAU * 2350.0 * t) + 0.5 * sin(TAU * 3520.0 * t)) * 0.28)
	streams.shimmer = _make(0.35, func(t, i): return _env(t, 0.01, 0.33) * (sin(TAU * (1800 + 600 * sin(t * 30)) * t) + sin(TAU * 2900.0 * t)) * 0.18)
	streams.take = _make(0.3, func(t, i): return _env(t, 0.01, 0.28) * (_noise(i) * 0.5 + sin(TAU * 140.0 * t) * 0.4))
	streams.roll = _make(0.32, func(t, i): return _env(t, 0.05, 0.25) * _noise(i) * 0.35 * (0.6 + 0.4 * sin(t * 40)))
	streams.cut = _make(0.12, func(t, i): return _env(t, 0.001, 0.1) * (_noise(i) * 0.5 + sin(TAU * 160.0 * t) * 0.5))
	streams.press = _make(0.3, func(t, i): return _env(t, 0.002, 0.28) * (sin(TAU * (95.0 - t * 80.0) * t) * 0.9 + _noise(i) * 0.25))
	streams.load = _make(0.4, func(t, i): return _env(t, 0.02, 0.38) * _noise(i) * 0.25 + _env(t - 0.25, 0.005, 0.1) * sin(TAU * 330.0 * t) * 0.2)
	streams.step_snow = _make(0.18, func(t, i): return _env(t, 0.005, 0.16) * _noise(i) * 0.35)
	streams.step_wood = _make(0.1, func(t, i): return _env(t, 0.002, 0.09) * (sin(TAU * 120.0 * t) * 0.5 + _noise(i) * 0.15))
	streams.buy = _make(0.5, func(t, i): return _env(t, 0.005, 0.2) * sin(TAU * 880.0 * t) * 0.3 + _env(t - 0.1, 0.005, 0.35) * sin(TAU * 1320.0 * t) * 0.3)
	streams.machine = _make(0.9, func(t, i): return (_env(t, 0.005, 0.3) * sin(TAU * 523.0 * t) + _env(t - 0.1, 0.005, 0.3) * sin(TAU * 659.0 * t) + _env(t - 0.2, 0.005, 0.3) * sin(TAU * 784.0 * t) + _env(t - 0.3, 0.005, 0.55) * sin(TAU * 1047.0 * t)) * 0.25)
	streams.blocked = _make(0.15, func(t, i): return _env(t, 0.002, 0.13) * signf(sin(TAU * 160.0 * t)) * 0.12)
	for i in 10:
		var p := AudioStreamPlayer.new(); add_child(p); pool.append(p)
	wind = _loop(_make(3.0, func(t, i): return _brown(i) * 0.5, true), -60.0)
	hum = _loop(_make(2.0, func(t, i): return (sin(TAU * 55.0 * t) * 0.3 + _brown(i) * 0.4), true), -60.0)
	music = AudioStreamPlayer.new(); add_child(music)
	var mp3 := load("res://assets/music/gingerbread-workshop.mp3") as AudioStreamMP3
	if mp3:
		mp3.loop = true; music.stream = mp3; music.volume_db = -20.0

var _brown_v := 0.0
func _brown(i: int) -> float:
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
		var v := clampf(fn.call(float(i) / RATE, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	return w

func _loop(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.stream = stream; p.volume_db = db; add_child(p); p.play()
	return p

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if not streams.has(name) or volume <= 0.0: return
	for p in pool:
		if not p.playing:
			p.stream = streams[name]; p.volume_db = db + linear_to_db(volume); p.pitch_scale = pitch * randf_range(0.94, 1.06); p.play()
			return

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
			"take": play("take")
			"roll", "rolled": play("roll")
			"crank": play("roll", 0.0, 0.7)
			"cut": play("cut")
			"press": play("press")
			"load", "push": play("load")
			"portion": play("take", -4.0, 1.3)
			"buy": play("buy")
			"machine", "finale": play("machine")
			"blocked": play("blocked", -6.0)

func update(delta: float, outside: bool, oven_near: float, belt_running: bool) -> void:
	land_clock += delta
	if land_queue > 0 and land_clock > 0.12:
		if land_queue <= 2:
			play("plop", -2.0); play("coin", -6.0)
		else:
			play("shimmer", -14.0 + minf(10.0, log(land_queue + 1.0) * 3.0)); play("plop", -8.0)
		land_queue = 0; land_clock = 0.0
	var lin := maxf(volume, 0.0001)
	wind.volume_db = lerpf(wind.volume_db, (-14.0 if outside else -34.0) + linear_to_db(lin), delta * 2.0)
	hum.volume_db = lerpf(hum.volume_db, (-22.0 + oven_near * 8.0 if belt_running and not outside else -50.0) + linear_to_db(lin), delta * 2.0)
	music.volume_db = -20.0 + linear_to_db(lin)

func step(outside: bool) -> void:
	play("step_snow" if outside else "step_wood", -8.0)
