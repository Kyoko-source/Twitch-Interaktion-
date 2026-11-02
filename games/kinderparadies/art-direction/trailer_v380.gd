extends Node3D

# Actual production world, production lighting and materials. No anomalies,
# ambushes, additional lights or secret-ending rooms are used in this trailer.
var world: PlayWorld
var player: NightGuard
var clock:=-2.4
var probe:=false
var shade: ColorRect
var title: Label
var subtitle: Label
var small: Label
var shots: Array[Dictionary]=[]
var last_shot:=""
var finish_at:=75.0

func shot(id: String,start: float,end: float,a: Vector3,b: Vector3,target: Vector3,words: String="",torch: bool=true) -> void:
 shots.append({"id":id,"start":start,"end":end,"a":a,"b":b,"target":target,"words":words,"torch":torch})

func _ready() -> void:
 probe="--trailer-probe" in OS.get_cmdline_user_args()
 AudioServer.set_bus_mute(0,true)
 get_window().size=Vector2i(1920,1080)
 world=PlayWorld.new();add_child(world);world.build();world.set_anomaly("none");world.quality(2);world.brightness(1.15)
 player=NightGuard.new();add_child(player);player.release();player.set_physics_process(false);player.camera.current=true
 player.lamp.light_size=.025;player.lamp.light_volumetric_fog_energy=.45;player.lamp.spot_angle=27;player.lamp.spot_angle_attenuation=2.3
 player.torch_body.hide()
 var lift:=ElevatorIntro.new();add_child(lift);lift.build(world,player);lift.set_floor(1)
 lift.overlay.hide();lift.phone.hide()
 for door in lift.doors:door.position.x=signf(door.position.x)*1.89
 shot("lift",0,6,Vector3(-8,1.65,19.15),Vector3(-8,1.65,17.25),Vector3(-6.7,2,6),"DEINE NACHTSCHICHT BEGINNT.")
 shot("hall",6,13,Vector3(-7.5,1.8,9.5),Vector3(-6.9,1.9,8.8),Vector3(6,2.5,3))
 shot("rain",13,18,Vector3(-7.4,1.65,2.1),Vector3(-7.9,1.65,1.8),Vector3(-10,2.6,1.7),"DRAUSSEN IST NIEMAND.")
 shot("arcade",18,24,Vector3(8.7,1.45,14.1),Vector3(9.1,1.5,14.7),Vector3(9,1.25,16.55))
 shot("birthday",24,30,Vector3(7.3,1.65,-9),Vector3(8,1.65,-8.7),Vector3(12,1.5,-5.8),"HIER WURDE EINMAL GEFEIERT.")
 shot("sky-tube",30,36,Vector3(3.35,4.95,-4.5),Vector3(5.25,4.95,-4.5),Vector3(8.7,4.88,-4.4),"PRÄGE DIR JEDES DETAIL EIN.")
 shot("corridor",36,42,Vector3(-8,1.65,-14.6),Vector3(-8,1.65,-17.3),Vector3(-7.9,1.9,-24))
 shot("kitchen",42,48,Vector3(-10.6,1.65,-17.4)+ServiceAnnex.OFFSET,Vector3(-11.15,1.65,-17.8)+ServiceAnnex.OFFSET,Vector3(-14.6,1.5,-19.8)+ServiceAnnex.OFFSET,"NICHTS IST WIRKLICH VERGESSEN.")
 shot("cinema",48,54,Vector3(-5.5,1.65,-17.65)+ServiceAnnex.OFFSET,Vector3(-4.9,1.65,-17.65)+ServiceAnnex.OFFSET,Vector3(2.6,1.7,-17.65)+ServiceAnnex.OFFSET)
 shot("music-box",54,59,Vector3(17,1.5,-3.4),Vector3(17.5,1.4,-3.25),Vector3(19.07,1.22,-2.63),"DREIZEHN RUNDGÄNGE.")
 shot("doors",59,65,Vector3(-3.2,1.65,-8.4),Vector3(-3.2,1.65,-9.2),Vector3(-3.2,1.8,-12.2),"ZWEI TÜREN. DEINE ENTSCHEIDUNG.")
 shot("mascot",65,70,Vector3(15.2,1.65,-4.7),Vector3(15.4,1.72,-4.3),Vector3(17.9,2.25,.38),"KEINE ZWEITE SICHERHEIT.")
 if "--hall-take" in OS.get_cmdline_user_args():shots=shots.filter(func(row):return row.id=="hall");clock=3.6;finish_at=13.0
 var layer:=CanvasLayer.new();add_child(layer)
 shade=ColorRect.new();shade.color=Color.BLACK;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(shade)
 title=_label(layer,108,Vector2(120,825),Vector2(1680,145));title.add_theme_font_override("font",NightMenus.menu_font(500,3));title.text="AFTER PLAY";title.hide()
 subtitle=_label(layer,36,Vector2(120,928),Vector2(1680,70));subtitle.add_theme_font_override("font",NightMenus.menu_font(500,1))
 small=_label(layer,24,Vector2(120,704),Vector2(1680,60));small.hide()
 get_viewport().msaa_3d=Viewport.MSAA_4X;get_viewport().use_taa=true
 if probe:call_deferred("_probes")

func _label(parent: Node,value: int,p: Vector2,s: Vector2) -> Label:
 var label:=Label.new();label.position=p;label.size=s;label.add_theme_font_size_override("font_size",value);label.add_theme_color_override("font_color",Color("e8e1c8"));label.add_theme_color_override("font_shadow_color",Color(0,0,0,.9));label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);parent.add_child(label);return label

func _process(delta: float) -> void:
 if probe:return
 _frame(delta);clock+=delta
 if clock>=finish_at:
  print("TRAILER V380 COMPLETE: 75s, 16:9, no anomalies or jumpscares")
  set_process(false);call_deferred("_finish")

func _finish() -> void:
 for audio in find_children("*","AudioStreamPlayer3D",true,false)+find_children("*","AudioStreamPlayer",true,false):audio.stop()
 world.queue_free();player.queue_free()
 for i in range(4):await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_tree().quit()

func _frame(delta: float) -> void:
 var selected: Dictionary=shots[0]
 for row in shots:
  if clock>=row.start and clock<row.end:selected=row;break
 if clock>=70:
  shade.color.a=1;title.show();title.position=Vector2(120,330);title.size.y=180;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",150)
  subtitle.position=Vector2(120,535);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.text="JETZT AUF ITCH.IO"
  small.show();small.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;small.text="kyokohauntedgames.itch.io/after-play"
  var alpha:=smoothstep(70.2,71.4,clock)*(1.0-smoothstep(74.1,75,clock))
  title.modulate.a=alpha;subtitle.modulate.a=alpha;small.modulate.a=alpha;return
 if selected.id!=last_shot:last_shot=selected.id;print("TRAILER SHOT ",last_shot," @ ",clock)
 var t:=clampf((clock-float(selected.start))/(float(selected.end)-float(selected.start)),0,1)
 player.position=selected.a.lerp(selected.b,smoothstep(0,1,t))-Vector3.UP*1.65;player.rotation=Vector3.ZERO;player.camera.position=Vector3.UP*1.65;player.camera.look_at(selected.target);player.camera.fov=66
 player.lamp.visible=selected.torch
 world.tick(delta,true)
 var edge:=minf(clock-float(selected.start),float(selected.end)-clock)
 shade.color.a=1.0-smoothstep(0,.48,maxf(0,edge))
 subtitle.text=selected.words;subtitle.modulate.a=smoothstep(.6,1.4,clock-float(selected.start))*(1.0-smoothstep(float(selected.end)-1,float(selected.end)-.4,clock))
 if clock<0:shade.color.a=1;subtitle.modulate.a=0

func _probes() -> void:
 var output:=OS.get_environment("TEMP").path_join("after-play-v380-trailer-probes");DirAccess.make_dir_recursive_absolute(output)
 for row in shots:
  clock=(float(row.start)+float(row.end))*.5;_frame(.1)
  for i in range(30):await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output.path_join(row.id+".png"))
 clock=72;_frame(0);await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(output.path_join("end-card.png"))
 print("TRAILER PROBES COMPLETE ",output);get_tree().quit()
