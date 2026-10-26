extends RefCounted

# Store media from the actual playable scene. No added lights or model changes.
func settle(game: Node3D) -> void:
 await game.get_tree().create_timer(2.5).timeout
 await RenderingServer.frame_post_draw

func save(game: Node3D, output: String, name: String) -> void:
 var image:=game.get_viewport().get_texture().get_image()
 assert(image.save_png(output.path_join(name+".png"))==OK)
 print("ITCH CAPTURE ",name," ",image.get_width(),"x",image.get_height())

func pose(game: Node3D, position: Vector3, target: Vector3) -> void:
 game.player.position=position;game.player.velocity=Vector3.ZERO
 game.player.rotation=Vector3.ZERO;game.player.camera.position=Vector3(0,1.65,0)
 game.player.camera.look_at(target);game.player.camera.fov=75

func run(game: Node3D, output: String) -> void:
 game.get_window().size=Vector2i(1920,1080)
 game.settings=game.DEFAULT_SETTINGS.duplicate(true);game.settings.volume=0
 game._apply_settings();game._new_shift();game.intro.skip();game.player.active=false
 game.player.set_physics_process(false);game.player.lamp_on=true;game.player.lamp.show()
 game.player.torch_body.show();Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
 game.notice_time=0;game.notice.hide()
 var views: Array[Dictionary]=[
  {"id":"01-hauptsaal","p":Vector3(-3.5,0,8.8),"look":Vector3(4,2.5,0)},
  {"id":"02-baellebad","p":Vector3(.9,0,9.6),"look":Vector3(2.8,1,4.5)},
  {"id":"03-partyraum","p":Vector3(7.2,0,-9),"look":Vector3(13,1.8,-4.3)},
  {"id":"04-stoffhase","p":Vector3(15.2,0,-4.7),"look":Vector3(17.9,2.25,.38)},
  {"id":"05-kueche","p":Vector3(-10.6,0,-17.4)+ServiceAnnex.OFFSET,"look":Vector3(-14.6,1.5,-19.8)+ServiceAnnex.OFFSET},
  {"id":"06-kino","p":Vector3(-5.5,0,-17.65)+ServiceAnnex.OFFSET,"look":Vector3(2.6,1.7,-17.65)+ServiceAnnex.OFFSET},
  {"id":"07-kostuemraum","p":Vector3(17.6,.2,-13.5),"look":Vector3(13.2,1.7,-16.1)},
  {"id":"08-wartungsraum","p":Vector3(-11.3,0,-4.55),"look":Vector3(-15.8,1.6,-5.6)}]
 for view in views:
  pose(game,view.p,view.look);await settle(game);save(game,output,view.id)
 game.hud.hide();game.player.torch_body.hide()
 game.get_window().content_scale_size=Vector2i(1260,1000)
 game.get_window().size=Vector2i(1260,1000)
 pose(game,Vector3(15.2,0,-4.7),Vector3(19.1,2.15,.38))
 game.player.camera.fov=66
 await settle(game);save(game,output,"after-play-cover-original-ohne-schrift")
 var layer:=CanvasLayer.new();layer.layer=110;game.add_child(layer)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader:=Shader.new();shader.code="shader_type canvas_item;void fragment(){float edge=(1.0-smoothstep(.28,.82,UV.x))*.65;float top=(1.0-smoothstep(.1,.48,UV.y))*.28;COLOR=vec4(vec3(.012,.017,.014),max(edge,top));}"
 var material:=ShaderMaterial.new();material.shader=shader;shade.material=material;layer.add_child(shade)
 var title:=Label.new();title.text="AFTER PLAY";title.position=Vector2(64,62)
 title.add_theme_font_override("font",NightMenus.menu_font(500,2));title.add_theme_font_size_override("font_size",150)
 title.add_theme_color_override("font_color",Color("e8e1c8"));title.scale.x=.72;layer.add_child(title)
 var subtitle:=Label.new();subtitle.text="KINDERPARADIES";subtitle.position=Vector2(70,238)
 subtitle.add_theme_font_override("font",NightMenus.menu_font(400,5));subtitle.add_theme_font_size_override("font_size",23)
 subtitle.add_theme_color_override("font_color",Color("d9d0b5"));layer.add_child(subtitle)
 await settle(game);save(game,output,"after-play-cover-1260x1000")
 var report:={"version":"2.12.2","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"quality":2,"brightness":game.settings.brightness,"screenshots":views,"cover":"Actual party room and mascot; title and dark translucent backing only; no image generation, added lights, material or model changes."}
 var file:=FileAccess.open(output.path_join("aufnahme-info.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("ITCH MEDIA COMPLETE ",output)
