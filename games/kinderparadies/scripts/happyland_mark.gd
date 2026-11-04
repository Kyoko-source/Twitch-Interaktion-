class_name HappylandMark
extends Control

func _draw() -> void:
 var ink:=Color("264e46");var cream:=Color("c7b98e")
 draw_rect(Rect2(Vector2.ZERO,size),cream)
 draw_rect(Rect2(10,10,620,236),ink,false,3.)
 var center:=Vector2(80,109)
 draw_circle(center,27,Color("af7944"))
 for i in range(12):
  var direction:=Vector2.from_angle(i*TAU/12.)
  draw_line(center+direction*33.,center+direction*43.,Color("af7944"),4.,true)
 draw_arc(center+Vector2(0,-1),13,0,PI,18,ink,3.,true)
 for x in [-9,9]:draw_circle(center+Vector2(x,-8),2.3,ink)
 var font:=load("res://assets/Oswald.ttf") as Font
 draw_string(font,Vector2(139,135),"HAPPYLAND",HORIZONTAL_ALIGNMENT_LEFT,-1,71,ink)
 draw_string(font,Vector2(140,190),"DEIN TAG. DEIN ABENTEUER.",HORIZONTAL_ALIGNMENT_LEFT,-1,25,ink)
 var rng:=RandomNumberGenerator.new();rng.seed=391
 for i in range(580):draw_circle(Vector2(rng.randf_range(0,640),rng.randf_range(0,256)),rng.randf_range(.5,2.),Color(.55,.49,.34,.18))

static func texture(parent: Node) -> ViewportTexture:
 var view:=SubViewport.new();view.name="SharedHappylandIdentity";view.size=Vector2i(640,256);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(view)
 var mark:=HappylandMark.new();mark.size=Vector2(640,256);view.add_child(mark);return view.get_texture()
