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
	hitmarker=_label(root,"✕",34,Color(1,.3,.3,0),false);hitmarker.set_anchors_and_offsets_preset(Control.PRESET_CENTER);hitmarker.offset_left=-20;hitmarker.offset_right=20;hitmarker.offset_top=-24;hitmarker.offset_bottom=20;hitmarker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

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
	hit_time=maxf(hit_time-delta,0.);var c:=hitmarker.get_theme_color("font_color");c.a=hit_time/.18;hitmarker.add_theme_color_override("font_color",c)
	hurt=lerpf(hurt,float(data.hurt),clampf(delta*6.,0,1));(vignette.material as ShaderMaterial).set_shader_parameter("hurt",hurt)
	(vignette.material as ShaderMaterial).set_shader_parameter("tint",Vector3(.55,0,.02) if not data.shield else Vector3(.9,.5,.75))
	var amount: float=data.glitch
	glitch.visible=amount>.01;(glitch.material as ShaderMaterial).set_shader_parameter("amount",amount)
	boss_box.visible=data.boss_name!=""
	if boss_box.visible:boss_name.text=data.boss_name;boss_bar.value=float(data.boss_hp)*100.
	crosshair.visible=not data.aiming
