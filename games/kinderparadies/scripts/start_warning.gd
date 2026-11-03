class_name AfterPlayStartWarning
extends CanvasLayer

signal acknowledged

const TITLE:="BEVOR DEINE SCHICHT BEGINNT"
const CONTENT:="Dieses Spiel enthält Lichtblitze, schnelle Lichtwechsel und Stroboskopeffekte sowie plötzliche laute Geräusche, Jumpscares und verstörende Bilder."
const HEALTH:="Lichtblitze können bei lichtempfindlichen Personen epileptische Anfälle auslösen. Beende das Spiel, wenn du dich unwohl fühlst."
const LIMIT:="Stroboskopeffekte kannst du hier und unter Einstellungen → Bild ausschalten. Andere Lichtwechsel und Schreckeffekte bleiben enthalten."
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
 var bg:=ColorRect.new();bg.color=Color("0c1110");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
 var centre:=CenterContainer.new();centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(centre)
 var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(1120,0);centre.add_child(panel)
 var surface:=StyleBoxFlat.new();surface.bg_color=Color("131b18");surface.border_color=Color("6c6550");surface.set_border_width_all(1);surface.content_margin_left=64;surface.content_margin_right=64;surface.content_margin_top=38;surface.content_margin_bottom=38;panel.add_theme_stylebox_override("panel",surface)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",19);panel.add_child(column)
 var header:=HBoxContainer.new();header.alignment=BoxContainer.ALIGNMENT_END;column.add_child(header)
 var brand:=text("AFTER PLAY",20,Color("a9a28b"));brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(brand)
 language=OptionButton.new();language.name="WarningLanguage";language.add_item("Deutsch");language.add_item("English");language.selected=1 if AfterPlayLanguage.english() else 0;language.custom_minimum_size=Vector2(165,42);header.add_child(language)
 language.item_selected.connect(func(index: int):g.settings.language="en" if index==1 else "de";AfterPlayLanguage.choose(g.settings.language))
 var title:=text(TITLE,42,Color("e9dfc0"));title.name="WarningTitle";title.add_theme_font_override("font",load("res://assets/Oswald.ttf"));column.add_child(title)
 column.add_child(paragraph(CONTENT,26,Color("e2dfd4")))
 column.add_child(paragraph(HEALTH,23,Color("d9bc94")))
 column.add_child(paragraph(LIMIT,20,Color("a9b4a8")))
 var rule:=HSeparator.new();column.add_child(rule)
 var joke:=paragraph(JOKE,21,Color("a69d86"));joke.name="WarningJoke";column.add_child(joke)
 strobe=CheckButton.new();strobe.name="WarningStrobe";strobe.text="Stroboskopeffekte aktivieren";strobe.button_pressed=bool(g.settings.strobe);strobe.custom_minimum_size.y=54;strobe.add_theme_font_size_override("font_size",23);column.add_child(strobe)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",24);column.add_child(actions)
 continue_button=Button.new();continue_button.name="WarningContinue";continue_button.text="Verstanden · Weiter";continue_button.custom_minimum_size=Vector2(640,62);continue_button.add_theme_font_size_override("font_size",24);actions.add_child(continue_button)
 quit_button=Button.new();quit_button.name="WarningQuit";quit_button.text="Zur Webseite" if OS.has_feature("web") else "Spiel beenden";quit_button.custom_minimum_size=Vector2(250,62);quit_button.add_theme_font_size_override("font_size",22);actions.add_child(quit_button)
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
