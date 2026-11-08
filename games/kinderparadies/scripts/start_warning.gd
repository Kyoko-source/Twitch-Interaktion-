class_name AfterPlayStartWarning
extends CanvasLayer

signal acknowledged

const TITLE:="BEVOR DEINE SCHICHT BEGINNT"
const CONTENT:="Dieses Spiel enthält Lichtblitze, schnelle Lichtwechsel und Stroboskopeffekte sowie plötzliche laute Geräusche, Jumpscares und verstörende Bilder."
const HEALTH:="Lichtblitze können bei lichtempfindlichen Personen epileptische Anfälle auslösen. Beende das Spiel, wenn du dich unwohl fühlst."
const LIMIT:="Stroboskopeffekte kannst du hier und unter Einstellungen / Bild ausschalten. Andere Lichtwechsel und Schreckeffekte bleiben enthalten."
const JOKE:="Außerdem: erschreckend schlechte Jumpscares.\nFür verschüttete Getränke übernimmt Kyoko keine Verantwortung."
var g: Node3D
var root: Control
var strobe: CheckButton
var language: OptionButton
var continue_button: Button
var quit_button: Button

var title_label: Label
var flicker:=0.0
var crisp_body: Font
var crisp_label: Font

static func crisp(source: Font) -> Font:
 # Multichannel distance-field glyphs stay sharp at every window size and
 # display scale, where cached bitmap glyphs were resampled soft.
 var font:=source.duplicate() as Font
 if font is FontFile:(font as FontFile).multichannel_signed_distance_field=true;(font as FontFile).msdf_pixel_range=14
 elif font is SystemFont:(font as SystemFont).multichannel_signed_distance_field=true
 elif font is FontVariation and (font as FontVariation).base_font:(font as FontVariation).base_font=crisp((font as FontVariation).base_font)
 return font

func build(game: Node3D) -> void:
 g=game;name="StartupContentWarning";layer=100
 crisp_body=crisp(ThemeDB.fallback_font);crisp_label=crisp(load("res://assets/Oswald.ttf"))
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(bg)
 # Near-black, a faint blood-red glow from below, vignette and moving grain.
 var shade:=Shader.new();shade.code="shader_type canvas_item;float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}void fragment(){vec2 p=UV-vec2(.5,.56);float vig=1.-smoothstep(.25,.95,length(p*vec2(1.25,1.6)));vec2 q=(UV-vec2(.5,1.05))*vec2(1.4,2.2);float glow=exp(-dot(q,q)*3.);float n=h(floor(FRAGCOORD.xy*.5)+floor(TIME*24.)*vec2(17.,31.));vec3 c=vec3(.012,.011,.011)+vec3(.028,.026,.024)*vig+vec3(.16,.012,.014)*glow*.55;c+=(n-.5)*.018;COLOR=vec4(c,1.);}"
 var backdrop:=ShaderMaterial.new();backdrop.shader=shade;bg.material=backdrop
 var centre:=CenterContainer.new();centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(centre)
 var column:=VBoxContainer.new();column.custom_minimum_size.x=1180;column.add_theme_constant_override("separation",22);column.alignment=BoxContainer.ALIGNMENT_CENTER;centre.add_child(column)
 var brand:=text("AFTER PLAY   ·   KINDERPARADIES",18,Color("8e877a"));brand.add_theme_font_override("font",crisp_label);brand.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(brand)
 var eyebrow:=text("HINWEIS ZU LICHT UND TON",17,Color("b8343a"));eyebrow.add_theme_font_override("font",crisp_label);eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(eyebrow)
 title_label=text(TITLE,72,Color("ece4d2"));title_label.name="WarningTitle";title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title_label.add_theme_font_override("font",crisp(NightMenus.menu_font(500,2)));title_label.add_theme_color_override("font_shadow_color",Color(.55,.03,.04,.35));title_label.add_theme_constant_override("shadow_offset_y",3);column.add_child(title_label)
 var rule_row:=CenterContainer.new();column.add_child(rule_row)
 var rule:=ColorRect.new();rule.color=Color("8d1d22");rule.custom_minimum_size=Vector2(170,2);rule_row.add_child(rule)
 var content:=paragraph(CONTENT,27,Color("d8d3c6"));content.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.custom_minimum_size.x=1100;column.add_child(content)
 var health:=paragraph(HEALTH,22,Color("c98b78"));health.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;health.custom_minimum_size.x=1000;column.add_child(health)
 var gap:=Control.new();gap.custom_minimum_size.y=6;column.add_child(gap)
 var toggle_row:=CenterContainer.new();column.add_child(toggle_row)
 strobe=CheckButton.new();strobe.name="WarningStrobe";strobe.text="Stroboskopeffekte aktivieren";strobe.button_pressed=bool(g.settings.strobe);strobe.custom_minimum_size=Vector2(470,54)
 strobe.add_theme_font_size_override("font_size",22);strobe.add_theme_font_override("font",crisp_body)
 for state in ["normal","hover","pressed","focus","hover_pressed"]:
  var pill:=StyleBoxFlat.new();pill.bg_color=Color(.1,.08,.08,.9) if state=="hover" else Color(.06,.055,.055,.85);pill.border_color=Color("b8343a") if state=="focus" else Color("3a3433");pill.set_border_width_all(1);pill.set_corner_radius_all(27);pill.content_margin_left=26;pill.content_margin_right=18;strobe.add_theme_stylebox_override(state,pill)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:strobe.add_theme_color_override(state,Color("ddd7ca"))
 toggle_row.add_child(strobe)
 var limit:=paragraph(LIMIT,17,Color("8a857b"));limit.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;limit.custom_minimum_size.x=900;column.add_child(limit)
 var gap2:=Control.new();gap2.custom_minimum_size.y=14;column.add_child(gap2)
 var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER;actions.add_theme_constant_override("separation",22);column.add_child(actions)
 continue_button=Button.new();continue_button.name="WarningContinue";continue_button.text="Verstanden · Weiter";continue_button.custom_minimum_size=Vector2(460,60);actions.add_child(continue_button)
 quit_button=Button.new();quit_button.name="WarningQuit";quit_button.text="Zur Webseite" if OS.has_feature("web") else "Spiel beenden";quit_button.custom_minimum_size=Vector2(300,60);actions.add_child(quit_button)
 for button in [continue_button,quit_button]:
  button.add_theme_font_override("font",crisp_label);button.add_theme_font_size_override("font_size",24 if button==continue_button else 21)
  for state in ["normal","hover","pressed","focus"]:
   var style:=StyleBoxFlat.new();style.set_corner_radius_all(2)
   if button==continue_button:
    style.bg_color=Color("7d171c") if state in ["hover","pressed"] else Color("5c1115");style.border_color=Color("e0b9a6") if state=="focus" else Color("a5272e");style.set_border_width_all(2 if state=="focus" else 1)
   else:
    style.bg_color=Color(1,1,1,.04) if state=="hover" else Color(0,0,0,0);style.border_color=Color("6b6560") if state in ["hover","focus"] else Color("2f2b2a");style.set_border_width_all(1)
   button.add_theme_stylebox_override(state,style)
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("f1e6dc") if button==continue_button else Color("9a948a"))
 var joke:=paragraph(JOKE,17,Color("6f6a62"));joke.name="WarningJoke";joke.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;joke.custom_minimum_size.x=1000;column.add_child(joke)
 language=OptionButton.new();language.name="WarningLanguage";language.add_item("Deutsch");language.add_item("English");language.selected=1 if AfterPlayLanguage.english() else 0
 language.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);language.offset_left=-220;language.offset_right=-50;language.offset_top=40;language.offset_bottom=80
 language.add_theme_font_override("font",crisp_body);language.add_theme_font_size_override("font_size",18)
 for state in ["normal","hover","pressed","focus"]:
  var flat:=StyleBoxFlat.new();flat.bg_color=Color(0,0,0,.3);flat.border_color=Color("b8343a") if state=="focus" else Color("3a3433");flat.set_border_width_all(1);flat.set_corner_radius_all(2);flat.content_margin_left=14;language.add_theme_stylebox_override(state,flat)
 root.add_child(language)
 language.item_selected.connect(func(index: int):g.settings.language="en" if index==1 else "de";AfterPlayLanguage.choose(g.settings.language))
 continue_button.pressed.connect(accept)
 if OS.has_feature("web"):quit_button.pressed.connect(func():JavaScriptBridge.eval("window.top.location.href='/'"))
 else:quit_button.pressed.connect(g._quit)
 # Keyboard focus starts on the setting, so a stray Enter cannot dismiss the
 # warning as the game opens. Continue requires an explicit button action.
 strobe.grab_focus()

func _process(delta: float) -> void:
 # A dying fluorescent tube: the title very occasionally stutters.
 if not is_instance_valid(title_label):return
 flicker-=delta
 if flicker<=0.:flicker=randf_range(2.5,6.)
 title_label.modulate.a=.35 if flicker<.07 or (flicker>.12 and flicker<.15) else 1.

func text(value: String,size_value: int,color: Color) -> Label:
 var label:=Label.new();label.text=value;
 if crisp_body:label.add_theme_font_override("font",crisp_body)
 label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",color);return label

func paragraph(value: String,size_value: int,color: Color) -> Label:
 var label:=text(value,size_value,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=990;label.add_theme_constant_override("line_spacing",6);return label

func accept() -> void:
 g.settings.strobe=strobe.button_pressed;g._write_settings();acknowledged.emit()

func snapshot() -> Dictionary:
 var controls: Array=[]
 for button in [strobe,continue_button,quit_button]:
  var rect: Rect2=button.get_global_rect()
  controls.append({"text":button.text,"rendered_text":button.tr(button.text),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
 var rect:=language.get_global_rect()
 var popup:=language.get_popup()
 return {"visible":root.is_visible_in_tree(),"muted":AudioServer.is_bus_mute(0),"strobe":strobe.button_pressed,"language":AfterPlayLanguage.code,"language_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"dropdown":{"visible":popup.visible,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y]},"controls":controls,"content":AfterPlayLanguage.t(CONTENT),"health":AfterPlayLanguage.t(HEALTH),"joke":AfterPlayLanguage.t(JOKE)}
