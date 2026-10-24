extends Node3D

var SAVE := "user://qa-nachtwache-save.json" if "--self-test" in OS.get_cmdline_user_args() or "--render-qa" in OS.get_cmdline_user_args() or OS.has_feature("qa") else "user://nachtwache-save.json"
var SETTINGS := "user://qa-nachtwache-settings.json" if "--self-test" in OS.get_cmdline_user_args() or "--render-qa" in OS.get_cmdline_user_args() or OS.has_feature("qa") else "user://nachtwache-settings.json"
var state := PatrolState.new()
var archive:=ArchiveState.new()
var archive_selected:=""
var inventory_back:="play"
var archive_input:=""
var world: PlayWorld
var player: NightGuard
var phase := "menu"
var return_phase := "menu"
var ui: CanvasLayer
var menu: Control
var hud: Control
var round_label: Label
var prompt: Label
var notice: Label
var notice_time := 0.0
var post: ColorRect
var room_audio: AudioStreamPlayer
var menu_music: AudioStreamPlayer
var effect: AudioStreamPlayer
const DEFAULT_SETTINGS={"volume":.7,"brightness":1.15,"sensitivity":.0022,"motion":true,"quality":2,"render_version":2,"fov":75,"render_scale":1.0,"grain":true,"vsync":true,"fps":0,"ambience":.8,"voice":1.0,"menu_music":.35,"invert_y":false,"crosshair":true}
var settings:=DEFAULT_SETTINGS.duplicate()
var settings_tab:="Bild"
var menu_camera: Camera3D
var menu_light: SpotLight3D
var menu_clock:=0.0
var menu_scare: DoorFailure
var crosshair: Label
var last_result := {}
var qa_callback
var telemetry_clock := 0.0
var has_session := false
var last_target := ""
var inspected_count := -1
var qa_layout := {}
var title_font: FontVariation
var save_clock := 0.0
var transition_shade: ColorRect
var door_failure: DoorFailure
var intro: ElevatorIntro
var intro_pending:=false
var end_credits: EndCredits
var memories: ArchiveMemories

func _ready() -> void:
 if OS.has_feature("web"): settings.quality=1
 _actions();_read_settings()
 player=NightGuard.new();add_child(player);player.camera.current=true
 _build_world("none");player.reset_pose()
 _audio();_ui();door_failure=DoorFailure.new();player.camera.add_child(door_failure)
 intro=ElevatorIntro.new();add_child(intro);intro.build(world,player);intro.finished.connect(_intro_finished)
 menu_camera=Camera3D.new();menu_camera.fov=66;menu_camera.near=.06;menu_camera.far=70;add_child(menu_camera)
 menu_light=SpotLight3D.new();menu_light.light_color=Color("c8ba95");menu_light.light_energy=2.0;menu_light.spot_range=22;menu_light.spot_angle=42;menu_light.spot_angle_attenuation=1.5;menu_light.position=Vector3(0,.5,0);menu_camera.add_child(menu_light)
 menu_scare=DoorFailure.new();menu_camera.add_child(menu_scare)
 _apply_settings();_main_menu()
 get_tree().auto_accept_quit=false
 if OS.has_feature("qa"): _install_qa()
 if "--self-test" in OS.get_cmdline_user_args(): call_deferred("_self_test")
 if "--render-qa" in OS.get_cmdline_user_args(): call_deferred("_render_qa")

func _actions() -> void:
 if not InputMap.has_action("crouch"):
  InputMap.add_action("crouch")
  for key in ([KEY_C] if OS.has_feature("web") else [KEY_C,KEY_CTRL]):
   var crouch_key:=InputEventKey.new();crouch_key.physical_keycode=key;InputMap.action_add_event("crouch",crouch_key)
 var keys:={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"sprint":[KEY_SHIFT],"jump":[KEY_SPACE],"grab":[KEY_G],"interact":[KEY_E],"torch":[KEY_F],"notes":[KEY_TAB],"pause":[KEY_ESCAPE],"fullscreen":[KEY_F11]}
 for action in keys:
  if not InputMap.has_action(action): InputMap.add_action(action)
  for key in keys[action]:
   var event:=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)

func _build_world(anomaly: String) -> void:
 if player: player.drop_prop()
 if world:
  _stop_scene_audio(world);remove_child(world);world.queue_free()
 world=PlayWorld.new();add_child(world);world.build();world.set_anomaly(anomaly)
 world.archive.sync(archive,14 if state.completed else state.streak+1)
 world.brightness(float(settings.brightness))
 world.quality(int(settings.quality))
 if player: player.reset_pose()
 if room_audio: _apply_settings()

func _stop_scene_audio(root: Node) -> void:
 # Retire paused WAV playbacks before removing a room or closing the game.
 for source in root.find_children("*","AudioStreamPlayer",true,false)+root.find_children("*","AudioStreamPlayer3D",true,false):
  source.stop();source.stream=null

func _audio() -> void:
 if not OS.has_feature("web"): player.step_player.bus="Interior"
 room_audio=AudioStreamPlayer.new();room_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;var stream: AudioStreamOggVorbis=load("res://assets/ambience/ventilation.ogg");stream.loop=true;room_audio.stream=stream;room_audio.volume_db=-26;add_child(room_audio)
 effect=AudioStreamPlayer.new();effect.stream=load("res://assets/door.ogg");effect.volume_db=-12;add_child(effect)
 menu_music=AudioStreamPlayer.new();menu_music.name="AbandonedArcadeMenuMusic";menu_music.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var tune: AudioStreamMP3=load("res://assets/menu/abandoned-arcade.mp3").duplicate();tune.loop=true;menu_music.stream=tune;add_child(menu_music)

func _ui() -> void:
 ui=CanvasLayer.new();add_child(ui)
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
 var theme:=Theme.new();theme.default_font_size=18;root.theme=theme
 title_font=FontVariation.new();title_font.base_font=load("res://assets/Oswald.ttf");title_font.variation_opentype={"wght":600}
 post=ColorRect.new();post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);post.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D screen_texture:hint_screen_texture,filter_linear;uniform float grain=0.012;void fragment(){vec3 c=texture(screen_texture,SCREEN_UV).rgb;vec2 p=SCREEN_UV-0.5;float v=1.0-smoothstep(0.2,0.78,length(p))*0.32;float n=fract(sin(dot(FRAGCOORD.xy+TIME,vec2(12.9898,78.233)))*43758.5453)-0.5;COLOR=vec4(c*v+n*grain,1.0);}"
 var material:=ShaderMaterial.new();material.shader=shader;post.material=material;root.add_child(post)
 hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(hud)
 round_label=_label("RUNDE 00 / 13",23);round_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);round_label.offset_left=-275;round_label.offset_right=-30;round_label.offset_top=28;round_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;hud.add_child(round_label)
 crosshair=_label("+",23,Color(1,1,1,.65));var cross:=crosshair;cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER);cross.offset_left=-8;cross.offset_top=-15;hud.add_child(cross)
 prompt=_label("",19);prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);prompt.offset_left=-330;prompt.offset_right=330;prompt.offset_top=-100;prompt.offset_bottom=-65;prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(prompt)
 notice=_label("",18,Color("eadfc2"));notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);notice.offset_left=-450;notice.offset_right=450;notice.offset_top=25;notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(notice)
 memories=ArchiveMemories.new();root.add_child(memories);memories.build()
 menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(menu)
 transition_shade=ColorRect.new();transition_shade.color=Color(0,0,0,0);transition_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);transition_shade.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(transition_shade);transition_shade.hide()

func _label(value: String, size: int=18, color: Color=Color("eee7d6")) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color);return label

func _paragraph(value: String, size: int=18) -> Label:
 var label:=_label(value,size,Color("bac6c0"));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=420;return label

func _style(color: Color,border: Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(3);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=13;style.content_margin_bottom=13;return style

func _button(value: String, action: Callable, primary: bool=false) -> Button:
 var button:=Button.new();button.text=value;button.custom_minimum_size=Vector2(420,48);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
 button.add_theme_stylebox_override("normal",_style(Color("b6a16d") if primary else Color(.045,.059,.049,.8),Color("b6a16d") if primary else Color("575643")))
 button.add_theme_stylebox_override("hover",_style(Color("e8e1c8") if primary else Color("2c3021"),Color("b6a16d")))
 button.add_theme_stylebox_override("pressed",_style(Color("958354") if primary else Color("383c29"),Color("e8e1c8")))
 button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("d5d0af")))
 button.add_theme_color_override("font_color",Color("172627") if primary else Color("eee7d6"));button.add_theme_color_override("font_hover_color",Color("172627") if primary else Color.WHITE);button.add_theme_color_override("font_pressed_color",Color("172627") if primary else Color.WHITE)
 button.pressed.connect(action);return button

func _panel(title: String, subtitle: String="") -> VBoxContainer:
 for child in menu.get_children(): child.queue_free()
 menu.show();hud.hide();player.release();world.atmosphere.set_active(false)
 var shade:=ColorRect.new();shade.color=Color(.015,.03,.035,.9);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(shade)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.offset_left=65;margin.offset_top=65;margin.offset_right=-65;margin.offset_bottom=-45;menu.add_child(margin)
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size.x=480;margin.add_child(scroll)
 var column:=VBoxContainer.new();column.custom_minimum_size.x=440;column.add_theme_constant_override("separation",14);scroll.add_child(column)
 var heading:=_label(title,96 if title=="NACHTWACHE" else 54);heading.add_theme_font_override("font",title_font);column.add_child(heading)
 if subtitle!="": column.add_child(_paragraph(subtitle,18))
 var spacer:=Control.new();spacer.custom_minimum_size.y=15;column.add_child(spacer)
 room_audio.stream_paused=phase!="menu"
 return column

func _main_menu() -> void:
 end_credits=null
 if intro: intro.stop()
 phase="menu";player.lamp.visible=false
 menu_camera.position=Vector3(13.8,2.1,-6.2);menu_camera.fov=60;menu_camera.look_at(Vector3(17.2,2.3,.2));menu_camera.current=true;menu_clock=0
 NightMenus.home(self);room_audio.stream_paused=false
 if not menu_music.playing: menu_music.play()
 if not room_audio.playing: room_audio.play()
 _telemetry()

func _menu_jump() -> void:
 if phase!="settings": return
 var previous_camera:=get_viewport().get_camera_3d()
 phase="menu_scare";menu.hide();menu_scare.start(world,previous_camera);menu_scare.audio.stream=load("res://assets/intro/menu-shock.wav");menu_scare.audio.volume_db=-1.5
 # This is a nonlethal menu prank. It never changes patrol state or a setting.
 _telemetry()
 await menu_scare.finished
 if phase=="quitting": return
 phase="settings";NightMenus.settings(self,settings_tab);_telemetry()

func _new_shift() -> void:
 archive.clear();archive_selected="";archive_input=""
 state.start();has_session=true;intro_pending=true;_build_world("none");_begin_intro()

func _begin_intro() -> void:
 menu_music.stop()
 player.camera.current=true
 phase="intro";menu.hide();hud.hide();room_audio.stop();intro.start();_save();_telemetry()

func _intro_finished() -> void:
 if phase!="intro": return
 intro_pending=false;_resume();_save()
 _announce("Erster Rundgang. Verlasse den Fahrstuhl und präge dir den normalen Zustand ein.",7)

func _persistent_text(path: String) -> String:
 if OS.has_feature("web"):
  var key:=JSON.stringify("after-play:"+path.get_file())
  var cached=JavaScriptBridge.eval("(()=>{try{const raw=localStorage.getItem("+key+");const value=raw&&JSON.parse(raw);return value&&typeof value==='object'&&!Array.isArray(value)?raw:'';}catch(_){return '';}})()")
  if cached is String and not cached.is_empty(): return cached
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _write_persistent_text(path: String, content: String) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE)
 if file: file.store_string(content);file.close()
 # Godot's IndexedDB sync is asynchronous. Mirror the small JSON immediately
 # so a reload directly after pausing cannot revive the previous save.
 if OS.has_feature("web"):
  var key:=JSON.stringify("after-play:"+path.get_file())
  JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+key+","+JSON.stringify(content)+");}catch(_){}})()")

func _can_continue() -> bool:
 if has_session: return true
 var saved:=_persistent_text(SAVE)
 if saved.is_empty(): return false
 var data=JSON.parse_string(saved)
 if not data is Dictionary: return false
 var check:=PatrolState.new()
 return check.restore(data.get("patrol",{}))

func _continue() -> void:
 if has_session:
  if archive.ending=="complete": _show_archive_ending()
  elif intro_pending: _begin_intro()
  else: _resume()
  return
 var data=JSON.parse_string(_persistent_text(SAVE))
 if not data is Dictionary or not state.restore(data.get("patrol",{})): _main_menu();return
 var stored_archive=data.get("archive",{})
 if stored_archive is Dictionary: archive.restore(stored_archive)
 else: archive.clear()
 has_session=true;_build_world("none" if state.completed else state.current)
 world.backstage.restore(data.get("backstage",{}))
 intro_pending=bool(data.get("intro_pending",false))
 if archive.ending=="complete": _show_archive_ending();return
 if intro_pending: _begin_intro();return
 var pose=data.get("pose",[])
 if int(data.get("layout_version",0)) in [7,8,9] and pose is Array and pose.size()==5:
  var p:=Vector3(float(pose[0]),float(pose[1]),float(pose[2]))
  if p.is_finite() and ((p.x>-10 and p.x<19.5 and p.z>-12 and p.z<17 and p.y>-1 and p.y<7.2) or world.annex.safe_pose(p) or world.archive.safe_pose(p) or world.server_room.safe_pose(p) or world.backstage.safe_pose(p) or (p.x> -9.1 and p.x< -6.9 and p.z>=17 and p.z<20.2 and p.y>-.1 and p.y<2.5)):
   player.position=p;player.rotation.y=float(pose[3]);player.camera.rotation.x=clampf(float(pose[4]),-1.35,1.35)
   if world.tubes.contains(p): player.set_crouch(true);player.camera.position.y=.8
 _resume();_announce("Nachtschicht wieder aufgenommen.")

func _resume() -> void:
 menu_music.stop()
 player.camera.current=true;player.camera.fov=player.base_fov
 phase="play";menu.hide();hud.show();player.capture();room_audio.stream_paused=false;world.archive.finale.voice.stream_paused=false
 player.lamp.visible=player.lamp_on
 world.atmosphere.set_active(true)
 if not room_audio.playing: room_audio.play()
 _refresh_hud();_telemetry()
 if archive.ending=="recording": _show_recording_memories()

func _show_recording_memories() -> void:
 player.release();player.lamp.hide();hud.hide();Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
 memories.render(archive.recording_position,world.archive.finale.duration,bool(settings.motion))

func _end_recording_memories() -> void:
 memories.hide()
 if phase=="play":
  hud.show();player.capture();player.lamp.visible=player.lamp_on
  if OS.has_feature("web") and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: _announce("Aufnahme beendet. Klicke ins Spiel, um dich wieder umzusehen.",7)

func _pause() -> void:
 if phase!="play": return
 phase="pause";world.archive.finale.voice.stream_paused=true;_save()
 var column:=_panel("Dienstpause","Der Rundgang steht still. Dein Fortschritt ist gespeichert.")
 column.add_child(_button("Rundgang fortsetzen",_resume,true))
 column.add_child(_button("Einstellungen",func():_settings("pause")))
 column.add_child(_button("Dienstanweisung",func():_help("pause")))
 column.add_child(_button("Zum Hauptmenü",_main_menu));_telemetry()

func _help(back: String) -> void:
 phase="help";return_phase=back
 var column:=_panel("Dienstanweisung")
 column.add_child(_paragraph("13 Rundgänge. 13 mal der gleiche Raum...oder?...\n\nGeräusche und vom Spieler selbst verschobene Gegenstände zählen natürlich nicht zu den Anomalien.\n\nSterueung\n\nWASD / Pfeiltasten: bewegen\nMaus: umsehen\nLeertaste: springen\nUmschalt: rennen\nG: aufheben/loslassen\nF: Taschenlampe\nE: interagieren\nTAB: Inventar\nF11: Vollbild",22))
 column.add_child(_button("Zurück",_return_from_panel,true));_telemetry()

func _return_from_panel() -> void:
 if return_phase=="play": _resume()
 elif return_phase=="inventory": _inventory(inventory_back)
 elif return_phase=="pause": phase="play";_pause()
 else: _main_menu()

func _settings(back: String) -> void:
 phase="settings";return_phase=back;NightMenus.settings(self)

func _inventory(back: String="play") -> void:
 phase="inventory";inventory_back=back;ArchiveUI.inventory(self,archive_selected)

func _archive_back() -> void:
 if inventory_back=="code": _open_archive_lock()
 else: _resume()

func _open_archive_lock(message: String="") -> void:
 if world.archive.playback_locked(): _announce("Verriegelt. Hör die Aufnahme bis zum Ende.");return
 if archive.unlocked: _announce("Das Schloss ist offen. Die Tür führt ins Archiv.");return
 phase="code";ArchiveUI.keypad(self,message)

func _submit_archive_code() -> void:
 if phase!="code": return
 if archive_input.length()!=4: ArchiveUI.keypad(self,"Das Schloss erwartet vier Ziffern.");return
 if archive_input!="0712" and not archive.has_all_papers(): ArchiveUI.keypad(self,"Dir fehlen noch Teile der Geschichte. Finde die vier Zeitungen.");return
 if not archive.try_code(archive_input): ArchiveUI.keypad(self,"Falscher Code. Der Riegel bleibt geschlossen.");return
 archive_input="";world.archive.open();_save();_resume();_announce("Der Riegel gibt nach. Das Archiv ist offen.",5)

func _collect_paper(id: String) -> void:
 if phase!="play" or not archive.take(id,14 if state.completed else state.streak+1): return
 archive_selected=id;world.archive.take(id);_save()
 _announce("Eingesammelt: "+str(ArchiveState.document(id).title)+" · TAB zum Lesen",5)

func _slider(parent: VBoxContainer, title: String, low: float, high: float, step: float, value: float, change: Callable) -> void:
 parent.add_child(_label(title,18));var slider:=HSlider.new();slider.set_meta("qa_label",title);slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=value;slider.custom_minimum_size=Vector2(420,36);slider.value_changed.connect(change);parent.add_child(slider)

func _read_settings() -> void:
 var saved:=_persistent_text(SETTINGS)
 if saved.is_empty(): return
 var data=JSON.parse_string(saved)
 if not data is Dictionary: return
 settings.volume=clampf(float(data.get("volume",.7)),0,1);settings.brightness=clampf(float(data.get("brightness",1.15)),.7,1.8);settings.sensitivity=clampf(float(data.get("sensitivity",.0022)),.0007,.0045);settings.motion=bool(data.get("motion",true));settings.quality=clampi(int(data.get("quality",1)),0,2)
 for key in ["fov","render_scale","ambience","voice","menu_music"]:
  var low:=65.0 if key=="fov" else .65 if key=="render_scale" else 0.0
  var high:=100.0 if key=="fov" else 1.0
  var number=float(data.get(key,DEFAULT_SETTINGS[key]));settings[key]=clampf(number,low,high) if is_finite(number) else DEFAULT_SETTINGS[key]
 for key in ["grain","vsync","invert_y","crosshair"]: settings[key]=bool(data.get(key,DEFAULT_SETTINGS[key]))
 settings.fps=int(data.get("fps",0)) if int(data.get("fps",0)) in [0,30,60,120,144] else 0
 if not OS.has_feature("web") and int(data.get("render_version",0))<2: settings.quality=2

func _apply_settings() -> void:
 AudioServer.set_bus_volume_db(0,linear_to_db(float(settings.volume)) if float(settings.volume)>0 else -80)
 Engine.max_fps=int(settings.fps)
 if not OS.has_feature("web"): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
 get_viewport().scaling_3d_scale=float(settings.render_scale)
 player.base_fov=float(settings.fov);player.invert_y=bool(settings.invert_y)
 if phase=="play": player.camera.fov=player.base_fov
 if crosshair: crosshair.visible=bool(settings.crosshair)
 for bus_name in ["NightAmbience","NightVoice"]:
  if AudioServer.get_bus_index(bus_name)<0: AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
  AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name),"Interior" if bus_name=="NightAmbience" and AudioServer.get_bus_index("Interior")>=0 else "Master")
  var amount: float=settings.ambience if bus_name=="NightAmbience" else settings.voice
  AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name),linear_to_db(amount) if amount>0 else -80)
 if world:
  for branch in [world.soundscape,world.annex,world.room_horror,world.archive,world.terrors,world.server_room]:
   if branch:
    for source in branch.find_children("*","AudioStreamPlayer3D",true,false): source.bus="NightAmbience"
 if world and world.archive: world.archive.finale.voice.bus="NightVoice"
 if intro: intro.voice.bus="NightVoice"
 if room_audio: room_audio.bus="NightAmbience"
 if menu_music: menu_music.bus="Master";menu_music.volume_db=linear_to_db(float(settings.menu_music))-9 if float(settings.menu_music)>0 else -80
 player.sensitivity=float(settings.sensitivity);player.motion=bool(settings.motion);player.lamp.shadow_enabled=int(settings.quality)>0
 # Compatibility shadow maps need back-face rendering to avoid diagonal acne
 # on the crocodile and walls. Forward+ keeps its finer native bias.
 var compatibility=RenderingServer.get_current_rendering_method()=="gl_compatibility"
 player.lamp.shadow_reverse_cull_face=compatibility
 player.lamp.shadow_bias=.15 if compatibility else .025
 if world: world.quality(int(settings.quality))
 if world: world.brightness(float(settings.brightness))
 if post: post.material.set_shader_parameter("grain",.012 if settings.grain else 0.0)
 get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][int(settings.quality)]
 get_viewport().use_taa=not OS.has_feature("web") and RenderingServer.get_current_rendering_method()=="forward_plus" and int(settings.quality)>0
 if world and world.native_art and world.native_art.advanced:
  player.lamp.light_size=.025;player.lamp.light_volumetric_fog_energy=.45
  player.lamp.spot_angle=27;player.lamp.spot_angle_attenuation=2.3

func _reset_settings() -> void:
 settings=DEFAULT_SETTINGS.duplicate()
 if OS.has_feature("web"): settings.quality=1
 _apply_settings();_write_settings()

func _write_settings() -> void:
 _write_persistent_text(SETTINGS,JSON.stringify(settings))

func _save(next_round: bool=false) -> void:
 if not has_session: return
 var pose: Array=[-6.2,0,8.5,0,0] if next_round else [player.position.x,player.position.y,player.position.z,player.rotation.y,player.camera.rotation.x]
 _write_persistent_text(SAVE,JSON.stringify({"patrol":state.serialize(),"archive":archive.serialize(),"pose":pose,"layout_version":9,"backstage":{} if next_round else world.backstage.serialize(),"intro_pending":intro_pending}))

func _process(delta: float) -> void:
 if not world or not player: return
 if menu_light: menu_light.visible=phase=="menu"
 if phase=="intro": intro.tick(delta)
 if phase in ["failure","archive_scare"]: door_failure.tick(delta)
 if phase=="ending" and is_instance_valid(end_credits): end_credits.tick(delta)
 if phase=="menu_scare": menu_scare.tick(delta)
 if phase=="menu":
  menu_clock+=delta
  var travel: float=sin(menu_clock*.075)*.18 if settings.motion else 0.0
  menu_camera.position=Vector3(13.8,2.1,-6.2+travel);menu_camera.look_at(Vector3(17.2,2.3,.2))
 world.tick(delta,phase=="play")
 world.tubes.tick(delta,phase=="play",player)
 world.soundscape.tick(delta,phase=="play",player)
 world.encounters.tick(delta,phase=="play",player)
 world.terrors.tick(delta,phase=="play",player)
 world.backstage.tick(delta,phase=="play",player)
 world.archive.tick(delta,phase=="play")
 if archive.ending=="recording" and phase in ["play","pause","inventory","settings","help"]:
  memories.render(archive.recording_position,world.archive.finale.duration,bool(settings.motion))
  if phase=="play": player.active=false;hud.hide()
 else: memories.hide()
 player.fright=maxf(maxf(world.encounters.shock,world.terrors.shock),world.backstage.shock)
 if phase=="play":
  state.seconds+=delta
  save_clock+=delta
  if save_clock>10: save_clock=0;_save()
  for zone in world.zones:
   var p: Vector3=world.zones[zone]
   if Vector2(player.position.x-p.x,player.position.z-p.z).length()<2.1 and state.inspect(zone):
    _refresh_hud()
  var target:=_target()
  last_target=target
  prompt.text=""
  if state.completed and target in ["red","green"]: prompt.text="E · Erneut nach den Spuren suchen"
  elif target in ["red","green"]: prompt.text="E · "+("Rote Tür – Anomalie" if target=="red" else "Grüne Tür – Normal")
  elif target=="archive_recording": prompt.text="E · Aufnahme abspielen" if archive.ending=="idle" else "Aufnahme läuft · ESC pausiert" if archive.ending=="recording" else "Die Aufnahme ist zu Ende"
  elif target.begins_with("paper:"): prompt.text="E · "+str(ArchiveState.document(target.trim_prefix("paper:")).title)+" einsammeln"
  elif target in ["archive_door","archive_lock"]: prompt.text="Archiv · Verriegelt bis zum Ende der Aufnahme" if world.archive.playback_locked() else "Archiv · Offen" if archive.unlocked else "E · Zahlenschloss untersuchen"
  elif target=="delivery_exit": prompt.text="E · Liefertür "+("schließen" if world.backstage.exit_open else "öffnen")
  elif target.begins_with("story:"): prompt.text="E · "+str(BackstageExpansion.DOCS[target.trim_prefix("story:")].title)+" lesen"
  if target=="":
   if is_instance_valid(player.carried): prompt.text="G · Loslassen   |   Linke Maustaste · Werfen"
   else:
    var object:=player.prop_target()
    if object: prompt.text="G · "+object.title+" aufheben"
  if prompt.text=="" and (world.tubes.near_entry(player.position) or world.tubes.inside): prompt.text="C halten · Ducken und durch die Röhre krabbeln"
  if prompt.text=="" and OS.has_feature("web") and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: prompt.text="Ins Spiel klicken · Maussteuerung aktivieren"
  if notice_time>0: notice_time-=delta;notice.visible=notice_time>0
 telemetry_clock+=delta
 if telemetry_clock>.25: telemetry_clock=0;_telemetry()

func _refresh_hud() -> void:
 round_label.offset_left=-440 if state.completed else -275
 round_label.text="13 / 13 · ZURÜCK AM ANFANG" if state.completed else "RUNDGANG %02d / 13"%mini(13,state.streak+1)

func _target() -> String:
 var origin:=player.camera.global_position;var end:=origin-player.camera.global_transform.basis.z*2.7
 var query:=PhysicsRayQueryParameters3D.create(origin,end);query.exclude=[player.get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 if hit and hit.collider.has_meta("interaction"): return str(hit.collider.get_meta("interaction"))
 return ""

func _decide(red: bool) -> void:
 if phase!="play": return
 if state.completed:
  # The completed patrol is a real, saved room. A door starts another search
  # without deleting documents already found during this surviving shift.
  state.start();_build_world("none");_resume();_save();return
 var result:=state.decide(red)
 if not result.accepted: return
 phase="transition";player.release();last_result=result;effect.play();world.open_door(red)
 if result.correct: _save(true)
 if not result.correct:
  archive.clear();archive_selected="";archive_input="";state.start();intro_pending=true;_save()
  phase="failure";hud.hide();player.lamp.hide();door_failure.start(world,player.camera);_telemetry()
  await door_failure.finished
  if phase=="quitting": return
 phase="transition";await _fade(1,.3)
 if not result.correct:
  _new_shift();await _fade(0,.35);return
 if result.completed: _won();return
 _build_world(state.current);_resume()
 _announce("Rundgang %d. Bleib aufmerksam."%(state.rounds+1) if result.correct else "Falsche Tür. Serie zurückgesetzt. "+result.detail,3 if result.correct else 6)
 await _fade(0,.25)

func _fade(alpha: float, duration: float) -> void:
 transition_shade.show()
 await create_tween().tween_property(transition_shade,"color:a",alpha,duration).finished
 if alpha==0 and is_instance_valid(transition_shade): transition_shade.hide()

func _start_archive_scare() -> void:
 if phase!="play": return
 phase="archive_scare";hud.hide();menu.hide();player.release();player.lamp.hide()
 door_failure.start_archive(world,player.camera);_telemetry()
 await door_failure.finished
 if phase=="archive_scare": _show_archive_ending()

func _show_archive_ending() -> void:
 menu_music.stop()
 phase="ending";NightMenus.clear(self);room_audio.stop();effect.stop();player.lamp.hide();transition_shade.hide();_save()
 end_credits=EndCredits.new();menu.add_child(end_credits);end_credits.build(self);_telemetry()

func _won() -> void:
 _build_world("none");player.camera.rotation.x=-.58;_resume();_save()
 _announce("Dreizehn Rundgänge. Vor dir liegt eine Zeitung.",7)
 await _fade(0,.4)

func _announce(value: String, seconds: float=4.0) -> void:
 notice.text=value;notice_time=seconds;notice.show()

func _input(event: InputEvent) -> void:
 if event.is_action_pressed("pause") and phase in ["inventory","code"]:
  if phase=="inventory": _archive_back()
  else: _resume()
  get_viewport().set_input_as_handled();return
 # TAB must close the reader before GUI focus navigation consumes it.
 if event.is_action_pressed("notes") and phase in ["inventory","code"]:
  if phase=="inventory": _archive_back()
  else: _inventory("code")
  get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
 if phase in ["archive_scare","ending"]:
  if phase=="ending" and event.is_action_pressed("pause") and is_instance_valid(end_credits) and end_credits.clock>4: end_credits.finish_scroll()
  get_viewport().set_input_as_handled();return
 if phase=="menu_scare": get_viewport().set_input_as_handled();return
 if event.is_action_pressed("fullscreen"): _fullscreen();get_viewport().set_input_as_handled()
 if phase=="intro":
  if event.is_action_pressed("pause"): intro.paused=not intro.paused
  if event.is_action_pressed("interact"): intro.accept()
  get_viewport().set_input_as_handled();return
 if event.is_action_pressed("pause"):
  if phase=="play": _pause()
  elif phase=="pause": _resume()
  elif phase=="inventory": _archive_back()
  elif phase=="code": _resume()
  elif phase in ["help","settings"]: _return_from_panel()
  get_viewport().set_input_as_handled()
 if phase!="play": return
 if archive.ending=="recording" and memories.visible: get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.pressed and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: player.capture()
 if event.is_action_pressed("torch"): player.toggle_lamp()
 if event.is_action_pressed("grab"): player.grab_prop();get_viewport().set_input_as_handled()
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and is_instance_valid(player.carried): player.drop_prop(true)
 if event.is_action_pressed("notes"): _inventory("play");get_viewport().set_input_as_handled()
 if event.is_action_pressed("interact"):
  var target:=_target()
  if target in ["red","green"]: _decide(target=="red")
  elif target=="archive_recording": world.archive.finale.interact()
  elif target.begins_with("paper:"): _collect_paper(target.trim_prefix("paper:"))
  elif target in ["archive_door","archive_lock"]: _open_archive_lock()
  elif target=="delivery_exit": world.backstage.interact_exit(player)
  elif target.begins_with("story:"): _environment_note(target.trim_prefix("story:"))

func _environment_note(id: String) -> void:
 if not BackstageExpansion.DOCS.has(id): return
 phase="help";return_phase="play"
 var doc: Dictionary=BackstageExpansion.DOCS[id]
 var column:=_panel(doc.title)
 column.add_child(_paragraph(doc.text,24))
 column.add_child(_button("Zurück zum Rundgang",_return_from_panel,true));_telemetry()

func _equipment_card() -> void:
 phase="help";return_phase="inventory"
 var column:=_panel("Meine Ausrüstung")
 var card:=TextureRect.new();card.name="GuardDutyBadge";card.texture=player.equipment.badge;card.custom_minimum_size=Vector2(600,450);card.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(card)
 column.add_child(_paragraph("Dienstausweis 013 · Taschenlampe mit Reparaturband · Dienstschlüssel · Handy\n\nDie Schlüssel gehören zum Dienst. Das Zahlenschloss am Archiv öffnen sie nicht.",21))
 column.add_child(_button("Zurück zu den Fundstücken",_return_from_panel,true));_telemetry()

func _fullscreen() -> void:
 if OS.has_feature("web"): JavaScriptBridge.eval("document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen()")
 else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _quit() -> void:
 if phase=="quitting": return
 world.soundscape.stop_all()
 _save();_write_settings()
 player.release();room_audio.stop();effect.stop();world.source.stop()
 if OS.has_feature("web"): JavaScriptBridge.eval("window.top.location.href='/#games/after-play'");_main_menu()
 else:
  phase="quitting"
  _stop_scene_audio(self)
  var tree:=get_tree()
  if intro: intro.stop();remove_child(intro);intro.queue_free();intro=null
  if world: remove_child(world);world.queue_free();world=null
  ui.queue_free();player.queue_free();player=null
  await tree.process_frame
  if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
  for frame in range(3): await tree.process_frame
  # Paused/streamed MP3 decoders retire on the audio mixer, after the scene.
  await tree.create_timer(.2).timeout
  tree.quit()

func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST: _quit()
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and phase=="play" and "--render-qa" not in OS.get_cmdline_user_args(): _pause()

func _telemetry() -> void:
 if not OS.has_feature("web"): return
 var data:={"phase":phase,"streak":state.streak,"visited":state.visited,"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"torch":player.lamp_on,"target":last_target,"volume":settings.volume,"held":player.carried.title if is_instance_valid(player.carried) else "","grounded":player.is_on_floor()}
 data.rounds=state.rounds
 if OS.has_feature("qa"):
  data.anomaly=state.current;data.controls=[]
  data.completed=state.completed
  data.instructions=[]
  if phase=="help":
   for line in menu.find_children("*","Label",true,false): data.instructions.append(line.text)
  data.giant_mascots=world.find_children("*","Node3D",true,false).filter(func(n):return n.get_meta("giant_mascot",false)).size()
  data.encounter={"triggered":world.encounters.triggered,"finished":world.encounters.finished,"time":world.encounters.attack_time,"shock":world.encounters.shock}
  data.renderer=RenderingServer.get_current_rendering_method()
  var screen_size:=get_viewport().get_visible_rect().size
  var fresco:=world.find_child("TheFourEmptyChairs",true,false) as Node3D
  data.presentation={"logical_size":[screen_size.x,screen_size.y],"render_size":[get_viewport().get_texture().get_width(),get_viewport().get_texture().get_height()],"fresco":[fresco.global_position.x,fresco.global_position.y,fresco.global_position.z]}
  data.native_assets=ResourceLoader.exists("res://assets/models/SchoolChair_01/SchoolChair_01.gltf")
  data.polish={"floor":FootSurfaces.at(player),"last_surface":player.surface_name,"steps":player.footstep_count,"step_track":player.step_player.stream.resource_path,"step_playing":player.step_player.playing,"phone_state":intro.display.state_label.text,"phone_timer":intro.display.timer_label.text,"mascot":is_instance_valid(world.polish.mascot),"fur":ResourceLoader.exists("res://assets/mascot-v251/mascot-rabbit.glb"),"party_mascot":is_instance_valid(world.polish.party_mascot),"party_position":[world.polish.party_mascot.get_parent().position.x,world.polish.party_mascot.get_parent().position.y,world.polish.party_mascot.get_parent().position.z]}
  data.memories=memories.snapshot()
  data.shared_croc=is_instance_valid(world.playground.croc_visual) and ResourceLoader.exists(ExpandedPlayground.CROCODILE_PATH)
  data.croc_jaw=world.playground.croc_jaw.rotation.x
  data.crouching=player.crouching;data.tube=world.tubes.inside;data.watcher=world.tubes.watcher.visible;data.ambience=world.soundscape.snapshot()
  data.fog={"density":world.environment.environment.fog_density,"color":world.environment.environment.fog_light_color.to_html(),"volumetric":world.environment.environment.volumetric_fog_density}
  data.annex={"clock":world.annex.clock,"stirring":not (world.annex.scare or world.annex.settled),"clown":[world.annex.clown.root.position.x,world.annex.clown.root.position.y,world.annex.clown.root.position.z]}
  data.flashlight={"clock":player.torch_body.clock,"strength":player.torch_body.strength,"count":player.torch_body.count}
  data.failure={"running":door_failure.running,"clock":door_failure.clock,"count":door_failure.shown}
  data.intro=intro.snapshot()
  data.room_horror=world.room_horror.snapshot()
  data.archive=world.archive.snapshot();data.archive_reader=archive_selected;data.archive_input=archive_input
  data.ending_credits=end_credits.snapshot() if is_instance_valid(end_credits) else {}
  data.terrors=world.terrors.snapshot();data.tube_watcher_visible=world.tubes.watcher.visible
  data.backstage=world.backstage.snapshot()
  data.hud_labels=[]
  for label in hud.find_children("*","Label",true,false):
   if label.is_visible_in_tree(): data.hud_labels.append(label.text)
  var notebook:=menu.find_child("PatrolNotebook",true,false) as PatrolNotebook
  data.notebook={"visible":is_instance_valid(notebook) and notebook.is_visible_in_tree(),"visited":notebook.visited if is_instance_valid(notebook) else [],"round":notebook.round_number if is_instance_valid(notebook) else 0}
  data.settings=settings.duplicate();data.camera_fov=player.camera.fov;data.menu_prank={"running":menu_scare.running,"count":menu_scare.shown,"audio":is_instance_valid(menu_scare.audio) and menu_scare.audio.playing,"gain":AudioServer.get_bus_volume_db(0)};data.settings_tab=settings_tab
  data.layout=qa_layout
  data.props=[]
  for body in world.atmosphere.loose: data.props.append({"name":body.title,"position":[body.position.x,body.position.y,body.position.z],"velocity":body.linear_velocity.length(),"frozen":body.freeze,"impacts":body.impact_count,"sound_active":body.impact.playing,"sound":body.impact.stream.resource_path})
  for node in menu.find_children("*","Control",true,false)+intro.overlay.find_children("*","Control",true,false):
   if node.is_visible_in_tree() and (node is Button or node is HSlider):
    var rect: Rect2=node.get_global_rect()
    data.controls.append({"text":node.text if node is Button else str(node.get_meta("qa_label","")),"kind":"button" if node is Button else "slider","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
 JavaScriptBridge.eval("window.nachtwacheStatus="+JSON.stringify(data)+";window.dispatchEvent(new CustomEvent('nachtwache-state',{detail:window.nachtwacheStatus}));")

func _install_qa() -> void:
 qa_callback=JavaScriptBridge.create_callback(_qa_command)
 var window=JavaScriptBridge.get_interface("window")
 if window: window.nachtwacheQA=qa_callback

func _qa_command(args: Array) -> void:
 if args.is_empty(): return
 var command=JSON.parse_string(str(args[0]))
 if not command is Dictionary: return
 match command.get("op",""):
  "look": player.rotation.y=float(command.yaw)
  "voice": world.soundscape.cue_voice(player)
  "flicker": player.torch_body.trigger()
  "audit": qa_layout=SceneAudit.inspect(world)
  "recording_seek":
   if archive.ending=="recording":
    var at:=clampf(float(command.get("time",0)),0,world.archive.finale.duration-.08)
    archive.recording_position=at;world.archive.finale.voice.seek(at)
  "new": _new_shift()
  "warp": player.drop_prop();player.position=Vector3(command.x,float(command.get("y",0)),command.z);player.velocity=Vector3.ZERO;player.rotation.y=float(command.get("yaw",0));player.camera.rotation.x=float(command.get("pitch",0))
  "anomaly": state.current=str(command.id);_build_world(state.current);_resume()
  "inspect":
   for zone in PatrolState.ZONES: state.inspect(zone)
   _refresh_hud()
  "choose": _decide(bool(command.red))
  "pause": _pause()
  "resume": _resume()
  "menu": _main_menu()
 _telemetry()

func _self_test() -> void:
 var validation=load("res://scripts/validation.gd").new()
 var passed: bool=await validation.run(self)
 validation=null
 set_process(false);_stop_scene_audio(self)
 await get_tree().create_timer(.2).timeout
 await get_tree().process_frame
 await get_tree().process_frame
 print("NACHTWACHE SELF TEST: ","PASS" if passed else "FAIL")
 get_tree().quit(0 if passed else 1)

func _render_qa() -> void:
 await load("res://scripts/native_render_qa.gd").new().run(self)
