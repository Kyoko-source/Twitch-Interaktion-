class_name ZombiesHud
extends CanvasLayer

# Partynacht HUD: round tally, points with popups, ammo and weapon, perks,
# active pickups, boss bar, announcer, crosshair, hurt vignette and the
# reality glitch overlay that grows with the rounds.
var g: Node3D
var round_label: Label
var points_label: Label
var popups: Control
var ammo_label: Label
var weapon_label: Label
var perks_row: HBoxContainer
var pickups_label: Label
var prompt: Label
var title: Label
var subtitle: Label
var title_time:=0.0
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var crosshair: Label
var hitmarker: Label
var hit_time:=0.0
var vignette: ColorRect
var glitch: ColorRect
var hurt:=0.0
var shown_points:=0.0
var health_bar: ProgressBar
var health_text: Label
var claws: Control
# 5.2.0: the big round banner.
var wave_root: Control
var wave_flash: ColorRect
var wave_top: Label
var wave_number: Label
var wave_line: Label
var wave_drips: Control
var wave_time:=0.0
var wave_tween: Tween

func build(game: Node3D) -> void:
	g=game;layer=11;name="ZombiesHud"
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	glitch=_overlay("""shader_type canvas_item;
uniform float amount=0.0;
uniform sampler2D screen:hint_screen_texture,filter_linear;
float h(float x){return fract(sin(x*91.7)*43758.5);}
void fragment(){
 vec2 uv=SCREEN_UV;float band=floor(uv.y*70.0+TIME*3.0);
 float tear=step(1.0-amount*.18,h(band+floor(TIME*12.0)))*(h(band*3.1)-.5)*.05*amount;
 vec3 c;c.r=texture(screen,uv+vec2(tear+amount*.004,0)).r;c.g=texture(screen,uv+vec2(tear,0)).g;c.b=texture(screen,uv-vec2(-tear+amount*.004,0)).b;
 c+=vec3(.15,0,.25)*amount*.25*sin(TIME*2.0+uv.y*6.0);
 COLOR=vec4(c,1.0);}""",root)
	glitch.visible=false
	vignette=_overlay("""shader_type canvas_item;
uniform float hurt=0.0;
uniform vec3 tint=vec3(.55,0.,.02);
void fragment(){float d=length((UV-.5)*vec2(1.5,1.1));COLOR=vec4(tint,smoothstep(.45,1.05,d)*hurt*.95+hurt*.08);}""",root)
	round_label=_label(root,"",108,Color("b0141e"),true);round_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);round_label.offset_left=46;round_label.offset_top=-170;round_label.offset_right=500;round_label.offset_bottom=-30
	perks_row=HBoxContainer.new();perks_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);perks_row.offset_left=50;perks_row.offset_top=-214;perks_row.offset_bottom=-176;perks_row.add_theme_constant_override("separation",8);perks_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(perks_row)
	points_label=_label(root,"",44,Color("f2e6b4"),true);points_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);points_label.offset_left=-420;points_label.offset_right=-46;points_label.offset_top=-96;points_label.offset_bottom=-36;points_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	popups=Control.new();popups.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);popups.offset_left=-420;popups.offset_right=-46;popups.offset_top=-160;popups.offset_bottom=-96;popups.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(popups)
	ammo_label=_label(root,"",40,Color("ffffff"),false);ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);ammo_label.offset_left=-520;ammo_label.offset_right=-46;ammo_label.offset_top=-210;ammo_label.offset_bottom=-160;ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label=_label(root,"",22,Color("cfd2d6"),false);weapon_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);weapon_label.offset_left=-620;weapon_label.offset_right=-46;weapon_label.offset_top=-242;weapon_label.offset_bottom=-210;weapon_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	pickups_label=_label(root,"",22,Color("ffe9a8"),false);pickups_label.position=Vector2(46,40);pickups_label.size=Vector2(600,300)
	prompt=_label(root,"",26,Color("f4ecd2"),false);prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);prompt.offset_left=-560;prompt.offset_right=560;prompt.offset_top=-300;prompt.offset_bottom=-250;prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title=_label(root,"",64,Color("ff3a3a"),true);title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);title.offset_left=-900;title.offset_right=900;title.offset_top=120;title.offset_bottom=210;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle=_label(root,"",26,Color("f0dcd8"),false);subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);subtitle.offset_left=-800;subtitle.offset_right=800;subtitle.offset_top=210;subtitle.offset_bottom=260;subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	boss_box=VBoxContainer.new();boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);boss_box.offset_left=-420;boss_box.offset_right=420;boss_box.offset_top=34;boss_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(boss_box)
	boss_name=_label(boss_box,"",24,Color("ffcfcf"),true);boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_bar=ProgressBar.new();boss_bar.custom_minimum_size=Vector2(840,16);boss_bar.show_percentage=false;boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("c0182a");boss_bar.add_theme_stylebox_override("fill",fill)
	var back:=StyleBoxFlat.new();back.bg_color=Color(0,0,0,.7);back.border_color=Color("ff6a6a");back.set_border_width_all(1);boss_bar.add_theme_stylebox_override("background",back);boss_box.add_child(boss_bar)
	boss_box.hide()
	crosshair=_label(root,"+",30,Color(1,1,1,.75),false);crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER);crosshair.offset_left=-20;crosshair.offset_right=20;crosshair.offset_top=-22;crosshair.offset_bottom=18;crosshair.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Life bar above the perks, bottom left.
	health_text=_label(root,"",20,Color("f0dcd8"),false);health_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);health_text.offset_left=50;health_text.offset_right=420;health_text.offset_top=-262;health_text.offset_bottom=-236
	health_bar=ProgressBar.new();health_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);health_bar.offset_left=50;health_bar.offset_right=400;health_bar.offset_top=-234;health_bar.offset_bottom=-220;health_bar.show_percentage=false;health_bar.step=0.;health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hfill:=StyleBoxFlat.new();hfill.bg_color=Color("c0182a");hfill.set_corner_radius_all(3);health_bar.add_theme_stylebox_override("fill",hfill)
	var hback:=StyleBoxFlat.new();hback.bg_color=Color(0,0,0,.6);hback.border_color=Color(1,1,1,.35);hback.set_border_width_all(1);hback.set_corner_radius_all(3);health_bar.add_theme_stylebox_override("background",hback);root.add_child(health_bar)
	claws=Control.new();claws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);claws.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(claws)
	_wave_ui(root)
	hitmarker=_label(root,"✕",34,Color(1,.3,.3),false);hitmarker.modulate.a=0.;hitmarker.set_anchors_and_offsets_preset(Control.PRESET_CENTER);hitmarker.offset_left=-20;hitmarker.offset_right=20;hitmarker.offset_top=-24;hitmarker.offset_bottom=20;hitmarker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _wave_ui(root: Control) -> void:
	wave_flash=ColorRect.new();wave_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wave_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;wave_flash.color=Color(.8,0,.05,0.);root.add_child(wave_flash)
	wave_drips=Control.new();wave_drips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wave_drips.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(wave_drips)
	wave_root=Control.new();wave_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wave_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(wave_root)
	wave_top=_label(wave_root,"RUNDE",58,Color("f0dcd8"),false);wave_top.set_anchors_and_offsets_preset(Control.PRESET_CENTER);wave_top.offset_left=-500;wave_top.offset_right=500;wave_top.offset_top=-330;wave_top.offset_bottom=-250;wave_top.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	wave_top.add_theme_constant_override("outline_size",14)
	wave_number=_label(wave_root,"1",300,Color("ff1a2a"),true);wave_number.set_anchors_and_offsets_preset(Control.PRESET_CENTER);wave_number.offset_left=-500;wave_number.offset_right=500;wave_number.offset_top=-270;wave_number.offset_bottom=90
	wave_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;wave_number.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;wave_number.pivot_offset=Vector2(500,180)
	wave_number.add_theme_constant_override("outline_size",26);wave_number.add_theme_color_override("font_outline_color",Color(.08,0,0,.95))
	wave_number.add_theme_color_override("font_shadow_color",Color(1,.1,.1,.55));wave_number.add_theme_constant_override("shadow_offset_x",0);wave_number.add_theme_constant_override("shadow_offset_y",0);wave_number.add_theme_constant_override("shadow_outline_size",60)
	wave_line=_label(wave_root,"",30,Color("f4ecd2"),false);wave_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER);wave_line.offset_left=-700;wave_line.offset_right=700;wave_line.offset_top=90;wave_line.offset_bottom=140;wave_line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	wave_root.hide()

# Huge round number: slams in, shakes, bleeds, then shrinks into the corner tally.
func wave(number: int, line: String, color: Color=Color("ff1a2a"), top: String="RUNDE") -> void:
	if wave_tween and wave_tween.is_valid():wave_tween.kill()
	wave_top.text=top;wave_number.text=str(number);wave_line.text=line;wave_number.add_theme_color_override("font_color",color)
	wave_root.show();wave_root.modulate.a=1.;wave_number.scale=Vector2.ONE*3.4;wave_number.modulate.a=0.;wave_top.modulate.a=0.;wave_line.modulate.a=0.
	wave_number.set_anchors_and_offsets_preset(Control.PRESET_CENTER);wave_number.offset_left=-500;wave_number.offset_right=500;wave_number.offset_top=-270;wave_number.offset_bottom=90
	wave_time=3.4;wave_flash.color=Color(color.r,color.g*.3,color.b*.3,.42)
	for child in wave_drips.get_children():child.queue_free()
	var size_value:=get_viewport().get_visible_rect().size
	for i in range(18):
		var drip:=ColorRect.new();drip.mouse_filter=Control.MOUSE_FILTER_IGNORE;drip.color=Color(.45,0,.03,.9);drip.position=Vector2(randf()*size_value.x,-4.);drip.size=Vector2(randf_range(4.,14.),0.);wave_drips.add_child(drip)
		var dt:=drip.create_tween();dt.tween_property(drip,"size:y",randf_range(60.,size_value.y*.45),randf_range(1.2,2.6)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD);dt.tween_property(drip,"modulate:a",0.,1.)
	wave_tween=create_tween()
	wave_tween.tween_property(wave_number,"scale",Vector2.ONE,.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wave_tween.parallel().tween_property(wave_number,"modulate:a",1.,.15)
	wave_tween.parallel().tween_property(wave_top,"modulate:a",1.,.3).set_delay(.15)
	wave_tween.parallel().tween_property(wave_line,"modulate:a",1.,.4).set_delay(.35)
	wave_tween.parallel().tween_property(wave_flash,"color:a",0.,.8)
	wave_tween.tween_interval(1.9)
	wave_tween.tween_property(wave_number,"scale",Vector2.ONE*.32,.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wave_tween.parallel().tween_property(wave_number,"position",Vector2(-size_value.x*.4,size_value.y*.36),.5).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wave_tween.parallel().tween_property(wave_root,"modulate:a",0.,.5)
	wave_tween.tween_callback(_wave_done)

func _wave_done() -> void:
	wave_root.hide()
	for child in wave_drips.get_children():child.queue_free()

func _overlay(code: String, parent: Control) -> ColorRect:
	var rect:=ColorRect.new();rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new();shader.code=code;var m:=ShaderMaterial.new();m.shader=shader;rect.material=m;parent.add_child(rect);return rect

func _label(parent: Control, value: String, font_size: int, color: Color, serif: bool) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
	label.add_theme_font_override("font",g.title_font if serif else load("res://assets/Oswald.ttf"))
	label.add_theme_color_override("font_outline_color",Color(0,0,0,.85));label.add_theme_constant_override("outline_size",8 if serif else 6)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label

func announce(big: String, small: String, color: Color=Color("ff3a3a"), seconds: float=4.) -> void:
	title.text=big;subtitle.text=small;title.add_theme_color_override("font_color",color);title_time=seconds;title.modulate.a=1.;subtitle.modulate.a=1.

func popup(value: int, color: Color=Color("f2e6b4")) -> void:
	var label:=_label(popups,"+%d"%value,26,color,false);label.position=Vector2(popups.size.x-160+randf_range(-30,10),20);label.size=Vector2(150,30);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var tween:=label.create_tween();tween.set_parallel(true)
	tween.tween_property(label,"position:y",-40.,.9);tween.tween_property(label,"modulate:a",0.,.9);tween.chain().tween_callback(label.queue_free)

func hit(kill: bool, head: bool) -> void:
	hit_time=.18;hitmarker.add_theme_color_override("font_color",Color(1,.2,.2) if kill else Color(1,1,1) if not head else Color(1,.85,.3))

# Three red claw rakes across the screen when a guest lands a hit.
func claw() -> void:
	var size_value:=get_viewport().get_visible_rect().size
	var start:=Vector2(randf_range(.25,.6)*size_value.x,randf_range(.15,.4)*size_value.y);var angle:=randf_range(.55,1.0)
	for k in range(3):
		var line:=ColorRect.new();line.color=Color(.65,0,.04,.85);line.size=Vector2(size_value.y*.55,9.-k*1.5);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		line.position=start+Vector2(k*42,-k*18);line.rotation=angle;claws.add_child(line)
		var tween:=line.create_tween();tween.tween_interval(.25);tween.tween_property(line,"modulate:a",0.,.7);tween.tween_callback(line.queue_free)

func set_perks(list: Array) -> void:
	for child in perks_row.get_children():child.queue_free()
	for id in list:
		var row:=ZombiesConfig.perk(id)
		var box:=PanelContainer.new();box.custom_minimum_size=Vector2(40,38);box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var style:=StyleBoxFlat.new();style.bg_color=(row[3] as Color).darkened(.35);style.border_color=row[3];style.set_border_width_all(2);style.set_corner_radius_all(6);box.add_theme_stylebox_override("panel",style)
		var label:=_label(box,str(row[1]).substr(0,2).to_upper(),18,Color.WHITE,false);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		perks_row.add_child(box)

func tick(delta: float, data: Dictionary) -> void:
	round_label.text=str(data.round) if int(data.round)>0 else ""
	shown_points=lerpf(shown_points,float(data.points),clampf(delta*10.,0,1))
	if absf(shown_points-float(data.points))<1.:shown_points=float(data.points)
	points_label.text="%d"%int(shown_points)
	ammo_label.text=data.ammo;weapon_label.text=data.weapon;weapon_label.add_theme_color_override("font_color",data.weapon_color)
	pickups_label.text=data.pickups
	prompt.text=data.prompt
	if title_time>0.:
		title_time-=delta
		if title_time<1.:title.modulate.a=title_time;subtitle.modulate.a=title_time
		if title_time<=0.:title.text="";subtitle.text=""
	hit_time=maxf(hit_time-delta,0.);hitmarker.modulate.a=hit_time/.18
	if wave_time>0.:
		wave_time-=delta;var quake:=clampf(wave_time-2.4,0.,1.)
		wave_number.rotation=sin(wave_time*60.)*.035*quake;wave_number.pivot_offset=Vector2(500,180)
	health_bar.max_value=float(data.max_health);health_bar.value=float(data.health)
	health_text.text="LEBEN  %d / %d"%[ceili(float(data.health)),int(data.max_health)]
	var low: bool=float(data.health)/float(data.max_health)<.35
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color=Color("ff2a2a") if low and fmod(Time.get_ticks_msec()/1000.,.5)<.25 else Color("c0182a")
	hurt=lerpf(hurt,float(data.hurt),clampf(delta*6.,0,1));(vignette.material as ShaderMaterial).set_shader_parameter("hurt",hurt)
	(vignette.material as ShaderMaterial).set_shader_parameter("tint",Vector3(.55,0,.02) if not data.shield else Vector3(.9,.5,.75))
	var amount: float=data.glitch
	glitch.visible=amount>.01;(glitch.material as ShaderMaterial).set_shader_parameter("amount",amount)
	boss_box.visible=data.boss_name!=""
	if boss_box.visible:boss_name.text=data.boss_name;boss_bar.value=float(data.boss_hp)*100.
	crosshair.visible=not data.aiming
