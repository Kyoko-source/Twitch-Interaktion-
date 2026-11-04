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

func build(game: Node3D) -> void:
 g=game;name="StartupContentWarning";layer=100
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
 var gradient:=Shader.new();gradient.code="shader_type canvas_item;void fragment(){vec2 p=UV-vec2(.38,.4);float glow=exp(-dot(p*vec2(1.1,1.6),p*vec2(1.1,1.6))*5.);float n=fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453);COLOR=vec4(mix(vec3(.018,.029,.025),vec3(.09,.105,.078),glow)+(n-.5)*.007,1.);}"
 var backdrop:=ShaderMaterial.new();backdrop.shader=gradient;bg.material=backdrop
 var centre:=CenterContainer.new();centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(centre)
 var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(1400,0);centre.add_child(panel)
 var surface:=StyleBoxFlat.new();surface.bg_color=Color("141d19");surface.border_color=Color("4c5341");surface.set_border_width_all(1);surface.border_width_top=3;surface.set_corner_radius_all(5);surface.shadow_size=34;surface.shadow_color=Color(0,0,0,.4);surface.content_margin_left=62;surface.content_margin_right=62;surface.content_margin_top=42;surface.content_margin_bottom=40;panel.add_theme_stylebox_override("panel",surface)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",28);panel.add_child(column)
 var header:=HBoxContainer.new();header.add_theme_constant_override("separation",20);column.add_child(header)
 var brand:=text("AFTER PLAY  /  HAPPYLAND",19,Color("b8b38f"));brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(brand)
 language=OptionButton.new();language.name="WarningLanguage";language.add_item("Deutsch");language.add_item("English");language.selected=1 if AfterPlayLanguage.english() else 0;language.custom_minimum_size=Vector2(170,44);header.add_child(language)
 language.item_selected.connect(func(index: int):g.settings.language="en" if index==1 else "de";AfterPlayLanguage.choose(g.settings.language))
 var rule:=HSeparator.new();rule.modulate=Color("5b634e");column.add_child(rule)
 var eyebrow:=text("HINWEIS ZU LICHT UND TON",17,Color("bdac7b"));column.add_child(eyebrow)
 var title:=text(TITLE,51,Color("eee5cd"));title.name="WarningTitle";title.add_theme_font_override("font",NightMenus.menu_font(500));column.add_child(title)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",54);column.add_child(body)
 var copy:=VBoxContainer.new();copy.custom_minimum_size.x=750;copy.add_theme_constant_override("separation",23);body.add_child(copy)
 var content:=paragraph(CONTENT,25,Color("d6d9c9"));content.custom_minimum_size.x=750;copy.add_child(content)
 var health:=paragraph(HEALTH,23,Color("c6bd9a"));health.custom_minimum_size.x=750;copy.add_child(health)
 var options:=PanelContainer.new();options.custom_minimum_size.x=470;body.add_child(options)
 var box:=StyleBoxFlat.new();box.bg_color=Color("202a22");box.border_color=Color("576047");box.set_border_width_all(1);box.set_corner_radius_all(4);box.set_content_margin_all(24);options.add_theme_stylebox_override("panel",box)
 var prefs:=VBoxContainer.new();prefs.add_theme_constant_override("separation",19);options.add_child(prefs)
 prefs.add_child(text("DEIN LICHT. DEINE EINSTELLUNG.",17,Color("c6ba8b")))
 strobe=CheckButton.new();strobe.name="WarningStrobe";strobe.text="Stroboskopeffekte aktivieren";strobe.button_pressed=bool(g.settings.strobe);strobe.custom_minimum_size.y=57;strobe.add_theme_font_size_override("font_size",22);prefs.add_child(strobe)
 var limit:=paragraph(LIMIT,19,Color("b3beaa"));limit.custom_minimum_size.x=420;prefs.add_child(limit)
 var joke:=paragraph(JOKE,19,Color("999f8a"));joke.name="WarningJoke";joke.custom_minimum_size.x=1240;column.add_child(joke)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",24);column.add_child(actions)
 continue_button=Button.new();continue_button.name="WarningContinue";continue_button.text="Verstanden · Weiter";continue_button.custom_minimum_size=Vector2(830,62);continue_button.add_theme_font_size_override("font_size",24);actions.add_child(continue_button)
 quit_button=Button.new();quit_button.name="WarningQuit";quit_button.text="Zur Webseite" if OS.has_feature("web") else "Spiel beenden";quit_button.custom_minimum_size=Vector2(420,62);quit_button.add_theme_font_size_override("font_size",22);actions.add_child(quit_button)
 for button in [continue_button,quit_button]:
  for state in ["normal","hover","pressed","focus"]:
   var style:=StyleBoxFlat.new();style.bg_color=Color("b6aa7b") if button==continue_button else Color("202b23");style.border_color=Color("f0dfa3") if state in ["hover","focus"] else Color("657057");style.set_border_width_all(2 if state=="focus" else 1);style.set_corner_radius_all(3);button.add_theme_stylebox_override(state,style)
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("182018") if button==continue_button else Color("d0d3be"))
 continue_button.pressed.connect(accept)
 if OS.has_feature("web"):quit_button.pressed.connect(func():JavaScriptBridge.eval("window.top.location.href='/'"))
 else:quit_button.pressed.connect(g._quit)
 # Keyboard focus starts on the setting, so a stray Enter cannot dismiss the
 # warning as the game opens. Continue requires an explicit button action.
 strobe.grab_focus()

func text(value: String,size_value: int,color: Color) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",color);return label

func paragraph(value: String,size_value: int,color: Color) -> Label:
 var label:=text(value,size_value,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=990;return label

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
