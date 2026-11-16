class_name CookieHud
extends CanvasLayer
## Screen overlay: logo, cookie counter with progress, Schokotaler, crosshair + prompt, quest line,
## hotbar, key hints, the Christmas order book (shop), settings and the finale message.

signal buy_requested(id: String)
signal tool_selected(i: int)
signal settings_changed(sound: float, music: bool, sensitivity: float)
signal new_game_requested
signal resume_requested

const GOLD := Color("ffd23f")
const CREAM := Color("fbf1dc")
const PANEL := Color(0.12, 0.06, 0.03, 0.82)
const EDGE := Color(0.62, 0.43, 0.2, 0.9)

var root: Control
var cookies_label: Label
var percent_label: Label
var progress: ProgressBar
var talers_label: Label
var rate_label: Label
var prompt: Label
var quest: Label
var cross: Control
var hotbar: HBoxContainer
var slots: Array = []
var shop: PanelContainer
var shop_list: VBoxContainer
var shop_talers: Label
var shop_phase: Label
var shop_line: GridContainer
var settings: PanelContainer
var start_overlay: Control
var toast: Label
var toast_t := 0.0
var finale: PanelContainer
var finale_title: Label
var shop_dirty := true
var last_shop_key := ""

static func fmt(n) -> String:
	var v := int(round(float(n)))
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

static func rate_text(r: float) -> String:
	if r >= 100.0: return fmt(r)
	return String.num(r, 1).replace(".", ",")

class Draw extends Control:
	var fn: Callable
	func _draw() -> void:
		if fn.is_valid(): fn.call(self)

func _panel(radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL; sb.border_color = EDGE; sb.set_border_width_all(2); sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.45); sb.shadow_size = 8
	return sb

func _label(text: String, size := 18, color := CREAM, outline := 0) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", outline); l.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02))
	return l

func build() -> void:
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	# logo with a Santa hat
	var logo := Draw.new(); logo.position = Vector2(18, 10); logo.size = Vector2(300, 110); logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.fn = func(c: Control):
		var f := c.get_theme_default_font()
		for o in [Vector2(3, 3), Vector2(0, 0)]:
			var col := Color(0.3, 0.12, 0.03) if o.x > 0 else Color("f6c46a")
			c.draw_string_outline(f, Vector2(70, 48) + o, "Santa's", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(0.3, 0.12, 0.03))
			c.draw_string(f, Vector2(70, 48) + o, "Santa's", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
			c.draw_string_outline(f, Vector2(24, 92) + o, "Cookie Crisis", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(0.3, 0.12, 0.03))
			c.draw_string(f, Vector2(24, 92) + o, "Cookie Crisis", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
		c.draw_colored_polygon(PackedVector2Array([Vector2(8, 52), Vector2(30, 10), Vector2(62, 6), Vector2(70, 40)]), Color("c81d2a"))
		c.draw_rect(Rect2(4, 44, 70, 16), Color("fbf7f2"))
		c.draw_circle(Vector2(30, 10), 9, Color("fbf7f2"))
	root.add_child(logo)
	# cookies + talers (top right)
	var tr := VBoxContainer.new(); tr.set_anchors_preset(Control.PRESET_TOP_RIGHT); tr.position = Vector2(-330, 14); tr.custom_minimum_size = Vector2(310, 0); tr.add_theme_constant_override("separation", 8)
	tr.anchor_left = 1; tr.anchor_right = 1; tr.offset_left = -330; tr.offset_right = -18
	root.add_child(tr)
	var cp := PanelContainer.new(); cp.add_theme_stylebox_override("panel", _panel()); tr.add_child(cp)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 12); cp.add_child(ch)
	ch.add_child(_icon_cookie(42))
	var cv := VBoxContainer.new(); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ch.add_child(cv)
	cv.add_child(_label("Kekse", 16))
	cookies_label = _label("0 / 1.000.000", 24, CREAM, 2); cv.add_child(cookies_label)
	progress = ProgressBar.new(); progress.max_value = 1.0; progress.step = 0.0; progress.show_percentage = false; progress.custom_minimum_size = Vector2(0, 16)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.5); bg.set_corner_radius_all(8); bg.border_color = EDGE; bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new(); fg.bg_color = GOLD; fg.set_corner_radius_all(8)
	progress.add_theme_stylebox_override("background", bg); progress.add_theme_stylebox_override("fill", fg)
	cv.add_child(progress)
	percent_label = _label("0,00 %", 13); percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(percent_label)
	var tp := PanelContainer.new(); tp.add_theme_stylebox_override("panel", _panel()); tr.add_child(tp)
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation", 12); tp.add_child(th)
	th.add_child(_icon_coin(42))
	var tv := VBoxContainer.new(); th.add_child(tv)
	tv.add_child(_label("Schokotaler", 16))
	talers_label = _label("0", 26, CREAM, 2); tv.add_child(talers_label)
	rate_label = _label("0 Kekse/s", 14, Color(1, 0.9, 0.7)); rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; tr.add_child(rate_label)
	# settings gear
	var gear := Button.new(); gear.text = "Menü"; gear.flat = false; gear.focus_mode = Control.FOCUS_NONE
	gear.anchor_left = 1; gear.anchor_right = 1; gear.offset_left = -100; gear.offset_right = -18; gear.offset_top = 214; gear.offset_bottom = 260
	gear.add_theme_font_size_override("font_size", 18); gear.add_theme_stylebox_override("normal", _panel(23)); gear.add_theme_stylebox_override("hover", _panel(23))
	gear.pressed.connect(func(): toggle_settings(true))
	root.add_child(gear)
	# crosshair + prompt + quest
	cross = Draw.new(); cross.set_anchors_preset(Control.PRESET_CENTER); cross.size = Vector2(20, 20); cross.position = -Vector2(10, 10); cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.anchor_left = 0.5; cross.anchor_right = 0.5; cross.anchor_top = 0.5; cross.anchor_bottom = 0.5; cross.offset_left = -10; cross.offset_top = -10; cross.offset_right = 10; cross.offset_bottom = 10
	cross.fn = func(c: Control):
		c.draw_circle(Vector2(10, 10), 3.2, Color(0, 0, 0, 0.5)); c.draw_circle(Vector2(10, 10), 2.2, Color(1, 1, 1, 0.92))
	root.add_child(cross)
	prompt = _label("", 20, CREAM, 6); prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.5; prompt.anchor_right = 0.5; prompt.anchor_top = 0.5; prompt.anchor_bottom = 0.5; prompt.offset_left = -400; prompt.offset_right = 400; prompt.offset_top = 34; prompt.offset_bottom = 70
	root.add_child(prompt)
	quest = _label("", 19, CREAM, 6); quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest.anchor_left = 0.5; quest.anchor_right = 0.5; quest.offset_left = -420; quest.offset_right = 420; quest.offset_top = 20; quest.offset_bottom = 54
	root.add_child(quest)
	toast = _label("", 22, GOLD, 8); toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_left = 0.5; toast.anchor_right = 0.5; toast.anchor_top = 0.3; toast.anchor_bottom = 0.3; toast.offset_left = -500; toast.offset_right = 500
	root.add_child(toast)
	# hotbar
	hotbar = HBoxContainer.new(); hotbar.add_theme_constant_override("separation", 10)
	hotbar.anchor_left = 0.5; hotbar.anchor_right = 0.5; hotbar.anchor_top = 1; hotbar.anchor_bottom = 1; hotbar.offset_left = -170; hotbar.offset_right = 170; hotbar.offset_top = -96; hotbar.offset_bottom = -18
	root.add_child(hotbar)
	var icons := [_draw_hand, _draw_pin, _draw_star, _draw_tray]
	var names := ["Hand", "Nudelholz", "Ausstechform", "Backblech"]
	for i in 4:
		var b := Button.new(); b.custom_minimum_size = Vector2(76, 76); b.focus_mode = Control.FOCUS_NONE; b.tooltip_text = names[i]
		var d := Draw.new(); d.set_anchors_preset(Control.PRESET_FULL_RECT); d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idx := i
		d.fn = func(c: Control): icons[idx].call(c); c.draw_string(c.get_theme_default_font(), Vector2(8, 70), str(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
		b.add_child(d)
		b.pressed.connect(func(): tool_selected.emit(idx))
		hotbar.add_child(b); slots.append(b)
	# key hints
	var hints := VBoxContainer.new(); hints.anchor_left = 1; hints.anchor_right = 1; hints.anchor_top = 1; hints.anchor_bottom = 1
	hints.offset_left = -250; hints.offset_right = -18; hints.offset_top = -132; hints.offset_bottom = -18; hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hints)
	for pair in [["E", "Interagieren"], ["F", "Fallen lassen"], ["Tab", "Bestellbuch"], ["Leertaste", "Nächster Schritt"]]:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); row.alignment = BoxContainer.ALIGNMENT_END
		var key := PanelContainer.new(); var ks := _panel(6); ks.content_margin_left = 7; ks.content_margin_right = 7; ks.content_margin_top = 1; ks.content_margin_bottom = 1; key.add_theme_stylebox_override("panel", ks)
		key.add_child(_label(pair[0], 14, CREAM)); row.add_child(key); row.add_child(_label(pair[1], 16, CREAM, 4)); hints.add_child(row)
	_build_shop(); _build_settings(); _build_start(); _build_finale()

func _icon_cookie(s: int) -> Control:
	var d := Draw.new(); d.custom_minimum_size = Vector2(s, s); d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.fn = func(c: Control):
		c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.46, Color("b8742e")); c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.4, Color("e3a456"))
		for p in [Vector2(0.35, 0.35), Vector2(0.62, 0.42), Vector2(0.45, 0.65), Vector2(0.68, 0.68), Vector2(0.3, 0.58)]: c.draw_circle(p * s, s * 0.06, Color("5a2f12"))
	return d

func _icon_coin(s: int) -> Control:
	var d := Draw.new(); d.custom_minimum_size = Vector2(s, s); d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.fn = func(c: Control):
		c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.46, Color("9a6a10")); c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.4, Color("f2c14a"))
		c.draw_arc(Vector2(s / 2.0, s / 2.0), s * 0.3, 0, TAU, 32, Color("b8860b"), 2)
		c.draw_colored_polygon(PackedVector2Array([Vector2(0.3, 0.6) * s, Vector2(0.5, 0.3) * s, Vector2(0.7, 0.6) * s, Vector2(0.5, 0.7) * s]), Color("6b3a10"))
	return d

func _draw_hand(c: Control) -> void:
	c.draw_circle(Vector2(38, 44), 15, Color("f2c19c"))
	for i in 4: c.draw_rect(Rect2(25 + i * 7, 16, 6, 22), Color("f2c19c"))
	c.draw_rect(Rect2(46, 36, 14, 6), Color("f2c19c"))
	c.draw_rect(Rect2(24, 56, 28, 8), Color("c81d2a"))
func _draw_pin(c: Control) -> void:
	c.draw_line(Vector2(14, 58), Vector2(62, 18), Color("d9a066"), 12); c.draw_line(Vector2(8, 64), Vector2(16, 56), Color("6b4224"), 6); c.draw_line(Vector2(60, 20), Vector2(68, 12), Color("6b4224"), 6)
func _draw_star(c: Control) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var r := 24.0 if i % 2 == 0 else 11.0
		var a := -PI / 2 + i * PI / 5
		pts.append(Vector2(38, 38) + Vector2(cos(a), sin(a)) * r)
	c.draw_polyline(pts, Color("dfe6ee"), 3)
func _draw_tray(c: Control) -> void:
	c.draw_rect(Rect2(12, 28, 52, 26), Color("a9b2bc")); c.draw_rect(Rect2(16, 32, 44, 18), Color("c5cdd5"))
	for i in 3: c.draw_circle(Vector2(24 + i * 14, 41), 5, Color("f2d6a0"))

func _build_shop() -> void:
	shop = PanelContainer.new(); shop.add_theme_stylebox_override("panel", _panel(20)); shop.visible = false
	shop.anchor_left = 0.5; shop.anchor_right = 0.5; shop.anchor_top = 0.5; shop.anchor_bottom = 0.5
	shop.offset_left = -520; shop.offset_right = 520; shop.offset_top = -330; shop.offset_bottom = 330
	root.add_child(shop)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); shop.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	var title := _label("Weihnachts-Bestellbuch", 30, GOLD, 4); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	shop_talers = _label("", 24, CREAM, 2); head.add_child(shop_talers)
	shop_phase = _label("", 16, Color(1, 0.88, 0.7)); v.add_child(shop_phase)
	shop_line = GridContainer.new(); shop_line.columns = 6; shop_line.add_theme_constant_override("h_separation", 8); v.add_child(shop_line)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(scroll)
	shop_list = VBoxContainer.new(); shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shop_list.add_theme_constant_override("separation", 6); scroll.add_child(shop_list)
	var close := Button.new(); close.text = "Zurück an die Arbeit  (Tab)"; close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(func(): resume_requested.emit()); v.add_child(close)

func _build_settings() -> void:
	settings = PanelContainer.new(); settings.add_theme_stylebox_override("panel", _panel(20)); settings.visible = false
	settings.anchor_left = 0.5; settings.anchor_right = 0.5; settings.anchor_top = 0.5; settings.anchor_bottom = 0.5
	settings.offset_left = -260; settings.offset_right = 260; settings.offset_top = -200; settings.offset_bottom = 200
	root.add_child(settings)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); settings.add_child(v)
	v.add_child(_label("Einstellungen", 28, GOLD, 4))
	v.add_child(_label("Lautstärke", 16))
	var vol := HSlider.new(); vol.min_value = 0; vol.max_value = 1; vol.step = 0.05; vol.value = 0.8; v.add_child(vol)
	var mus := CheckButton.new(); mus.text = "Hintergrundmusik"; mus.button_pressed = true; v.add_child(mus)
	v.add_child(_label("Maus-Empfindlichkeit", 16))
	var sens := HSlider.new(); sens.min_value = 0.0008; sens.max_value = 0.005; sens.step = 0.0002; sens.value = 0.0022; v.add_child(sens)
	var apply := func(_x = null): settings_changed.emit(vol.value, mus.button_pressed, sens.value)
	vol.value_changed.connect(apply); mus.toggled.connect(apply); sens.value_changed.connect(apply)
	var row := HBoxContainer.new(); v.add_child(row)
	var resume := Button.new(); resume.text = "Weiterspielen"; resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL; resume.pressed.connect(func(): resume_requested.emit()); row.add_child(resume)
	var reset := Button.new(); reset.text = "Neues Spiel"; reset.pressed.connect(func(): new_game_requested.emit()); row.add_child(reset)

func _build_start() -> void:
	start_overlay = PanelContainer.new(); start_overlay.add_theme_stylebox_override("panel", _panel(18))
	start_overlay.anchor_left = 0.5; start_overlay.anchor_right = 0.5; start_overlay.anchor_top = 1; start_overlay.anchor_bottom = 1
	start_overlay.offset_left = -330; start_overlay.offset_right = 330; start_overlay.offset_top = -170; start_overlay.offset_bottom = -112
	start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("Klick ins Bild zum Spielen  ·  WASD laufen  ·  Maus schauen  ·  Esc pausiert", 17, CREAM); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_overlay.add_child(l); root.add_child(start_overlay)

func _build_finale() -> void:
	finale = PanelContainer.new(); finale.add_theme_stylebox_override("panel", _panel(24)); finale.visible = false
	finale.anchor_left = 0.5; finale.anchor_right = 0.5; finale.anchor_top = 0.5; finale.anchor_bottom = 0.5
	finale.offset_left = -360; finale.offset_right = 360; finale.offset_top = -220; finale.offset_bottom = 220
	root.add_child(finale)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); finale.add_child(v)
	var t := _label("Ho ho ho – du hast Weihnachten gerettet!", 30, GOLD, 4); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.autowrap_mode = TextServer.AUTOWRAP_WORD; v.add_child(t)
	var m := _label("„Eine Million Plätzchen, jedes einzelne goldbraun und duftend. Aus einem kleinen Holztisch ist die größte Keksfabrik des Nordpols geworden – und du hast das ganz allein geschafft. Danke, mein lieber Elf!“\n– Der Weihnachtsmann", 19)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD; m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(m)
	finale_title = _label("~ Oberster Keksmeister des Nordpols ~", 24, GOLD, 4); finale_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(finale_title)
	var b := Button.new(); b.text = "Weiter feiern"; b.pressed.connect(func(): finale.visible = false; resume_requested.emit()); v.add_child(b)

# ---------------------------------------------------------------- per frame
func show_toast(text: String) -> void:
	toast.text = text; toast_t = 2.4

func update(s: Dictionary, d: Dictionary, rate: float, look: Dictionary, quest_text: String, tool: int, captured: bool, delta: float) -> void:
	cookies_label.text = "%s / 1.000.000" % fmt(s.baked)
	progress.value = float(s.baked) / CookieSim.GOAL
	percent_label.text = String.num(float(s.baked) / CookieSim.GOAL * 100.0, 2).replace(".", ",") + " %"
	talers_label.text = fmt(s.talers)
	rate_label.text = "%s Kekse/s  ·  %s kg Teig im Berg" % [rate_text(rate), fmt(s.dough * CookieSim.GRAMS_PER_COOKIE / 1000.0)]
	prompt.text = look.get("text", "")
	prompt.modulate = Color(1, 1, 1) if look.get("ok", true) else Color(1, 0.7, 0.7)
	quest.text = ("Aufgabe: " + quest_text) if quest_text != "" else ""
	cross.visible = captured
	start_overlay.visible = not captured and not shop.visible and not settings.visible and not finale.visible
	for i in slots.size():
		var sb := _panel(14)
		if i == tool:
			sb.border_color = GOLD; sb.set_border_width_all(4); sb.bg_color = Color(0.3, 0.18, 0.04, 0.9)
		slots[i].add_theme_stylebox_override("normal", sb); slots[i].add_theme_stylebox_override("hover", sb); slots[i].add_theme_stylebox_override("pressed", sb)
	toast_t = maxf(0.0, toast_t - delta)
	toast.modulate.a = clampf(toast_t, 0, 1)
	if shop.visible: _update_shop(s, d)

func toggle_shop(on: bool) -> void:
	shop.visible = on; settings.visible = false; shop_dirty = true

func toggle_settings(on: bool) -> void:
	settings.visible = on; shop.visible = false

func _update_shop(s: Dictionary, d: Dictionary) -> void:
	shop_talers.text = "%s Schokotaler" % fmt(s.talers)
	var ph := CookieSim.phase_of(s)
	var nxt := ""
	if ph < 5: nxt = "  ·  Phase %d ab %s gebackenen Keksen" % [ph + 1, fmt(CookieSim.PHASES[ph].unlock)]
	shop_phase.text = "Phase %d: %s%s" % [ph, CookieSim.PHASES[ph - 1].name, nxt]
	var rec := CookieSim.recommended(s)
	var key := "%s|%s|%s|%d" % [JSON.stringify(s.levels), rec.get("id", ""), ph, int(s.talers / 50)]
	if key == last_shop_key and not shop_dirty: return
	last_shop_key = key; shop_dirty = false
	for c in shop_line.get_children(): c.queue_free()
	var neck := CookieSim.bottleneck(d)
	for c in CookieSim.capacities(d):
		var box := VBoxContainer.new()
		var name_l := _label(c.name, 14, GOLD if c.id == neck.id else CREAM); box.add_child(name_l)
		box.add_child(_label(("%s /s" % rate_text(c.rate)) if c.rate > 0 else "Handarbeit", 13, Color(1, 0.6, 0.6) if c.id == neck.id else Color(0.85, 0.8, 0.7)))
		shop_line.add_child(box)
	for c in shop_list.get_children(): c.queue_free()
	var tp := CookieSim.throughput(d)
	var list := []
	for u in CookieSim.UPGRADES:
		if CookieSim.is_unlocked(s, u) and CookieSim.lv(s.levels, u.id) < u.max: list.append(u)
	list.sort_custom(func(a, b): return (a.id == rec.get("id", "")) or (b.id != rec.get("id", "") and CookieSim.cost(a, CookieSim.lv(s.levels, a.id)) < CookieSim.cost(b, CookieSim.lv(s.levels, b.id))))
	for u in list:
		var level := CookieSim.lv(s.levels, u.id)
		var price := CookieSim.cost(u, level)
		var row := PanelContainer.new(); var sb := _panel(12)
		if u.id == rec.get("id", ""):
			sb.border_color = GOLD; sb.set_border_width_all(3); sb.bg_color = Color(0.28, 0.17, 0.04, 0.9)
		row.add_theme_stylebox_override("panel", sb); shop_list.add_child(row)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); row.add_child(h)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
		var title: String = ("Empfohlen: " if u.id == rec.get("id", "") else "") + u.name + ("  (Stufe %d/%d)" % [level, u.max] if u.max > 1 else "")
		info.add_child(_label(title, 18, GOLD if u.id == rec.get("id", "") else CREAM))
		var t := _label(u.text, 14, Color(0.9, 0.84, 0.72)); t.autowrap_mode = TextServer.AUTOWRAP_WORD; info.add_child(t)
		var next: Dictionary = s.levels.duplicate(); next[u.id] = level + 1
		var after := CookieSim.throughput(CookieSim.derive(next))
		if after > tp * 1.0001: info.add_child(_label("Produktion %s → %s Kekse/s" % [rate_text(tp), rate_text(after)], 14, Color("7fe0a0")))
		var b := Button.new(); b.text = "%s Taler" % fmt(price); b.custom_minimum_size = Vector2(150, 44); b.disabled = s.talers < price; b.focus_mode = Control.FOCUS_NONE
		var id: String = u.id
		b.pressed.connect(func(): buy_requested.emit(id))
		h.add_child(b)

func show_finale(title: String) -> void:
	finale_title.text = "~ %s ~" % title; finale.visible = true
