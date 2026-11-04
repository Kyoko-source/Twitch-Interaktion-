class_name LiftDirectory
extends Control

func _draw() -> void:
 var ink:=Color("355247");var red:=Color("a6664b");var gold:=Color("b99855")
 draw_rect(Rect2(Vector2.ZERO,size),Color("c2b899"))
 var rng:=RandomNumberGenerator.new();rng.seed=391
 for i in range(420):
  var p:=Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y))
  draw_circle(p,rng.randf_range(.5,3.),Color(.20,.13,.065,.035))
 draw_rect(Rect2(24,24,size.x-48,size.y-48),ink,false,3.)
 draw_rect(Rect2(31,31,size.x-62,size.y-62),gold,false,1.)
 # The old sun mark belongs to the venue, rather than an unrelated illustration.
 var sun:=Vector2(384,114)
 draw_circle(sun,34,gold)
 for ray in range(12):
  var direction:=Vector2(cos(ray*TAU/12.),sin(ray*TAU/12.))
  draw_line(sun+direction*42,sun+direction*51,gold,3.,true)
 draw_arc(sun+Vector2(0,0),16,.3,PI-.3,24,ink,2.,true)
 for x in [-12,12]:draw_circle(sun+Vector2(x,-8),2.,ink)
 var serif:=load("res://assets/presentation-v250/BodoniModa.ttf") as Font
 if not serif:serif=ThemeDB.fallback_font
 draw_string(serif,Vector2(48,223),"HAPPYLAND",HORIZONTAL_ALIGNMENT_CENTER,size.x-96,66,ink)
 draw_string(ThemeDB.fallback_font,Vector2(48,266),"DEIN TAG. DEIN ABENTEUER.",HORIZONTAL_ALIGNMENT_CENTER,size.x-96,20,ink)
 draw_line(Vector2(91,296),Vector2(size.x-91,296),red,2.,true)
 var lines:=["SPIELEN · FEIERN · STAUNEN","Bitte Kinder an die Hand nehmen.","Ausgang im Erdgeschoss."]
 for i in range(lines.size()):draw_string(ThemeDB.fallback_font,Vector2(48,351+i*51),lines[i],HORIZONTAL_ALIGNMENT_CENTER,size.x-96,23 if i==0 else 22,ink)
 draw_rect(Rect2(91,503,size.x-182,45),red)
 draw_string(serif,Vector2(91,533),"IN BETRIEB SEIT 1998",HORIZONTAL_ALIGNMENT_CENTER,size.x-182,23,Color("d6c8a8"))
 # Uneven fading and a faint waterline sit at the edge of the physical card.
 for i in range(18):
  var p:=Vector2(32+i*41,32+rng.randf_range(0,9))
  draw_line(p,p+Vector2(rng.randf_range(10,32),rng.randf_range(0,3)),Color(.17,.10,.04,.13),rng.randf_range(1,3),true)
 draw_line(Vector2(35,579),Vector2(733,574),Color(.22,.16,.08,.12),1.,true)

static func texture(parent: Node) -> Texture2D:
 var view:=SubViewport.new();view.name="PeriodLiftDirectoryPrint";view.size=Vector2i(768,640);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(view)
 var print_face:=LiftDirectory.new();print_face.size=Vector2(768,640);view.add_child(print_face);return view.get_texture()
