class_name DressingPrint
extends Control

var kind:="arcade"

func _draw() -> void:
 var font:=load("res://assets/Oswald.ttf") as Font
 var paper:=Color("c8b78c");var ink:=Color("343d35")
 draw_rect(Rect2(Vector2.ZERO,size),Color("253a3b") if kind in ["arcade","orbit","prizes"] else paper)
 if kind in ["arcade","orbit","prizes"]:
  var gold:=Color("c7ab66")
  for x in range(30,640,70):
   draw_line(Vector2(x,12),Vector2(x-65,148),Color("506c69"),4)
  draw_rect(Rect2(8,8,624,144),gold,false,3)
  var title:="STAR HOPPER" if kind=="arcade" else "LUNAR ORBIT" if kind=="orbit" else "HAPPYLAND / PREISE"
  draw_string(font,Vector2(38,105),title,HORIZONTAL_ALIGNMENT_LEFT,-1,67 if kind!="prizes" else 54,gold)
 elif kind=="film":
  draw_string(font,Vector2(28,76),"HAPPYLAND / FILM",HORIZONTAL_ALIGNMENT_LEFT,-1,48,ink)
  draw_string(font,Vector2(28,126),"Ein Tag voller Abenteuer",HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)
 elif kind=="found":
  draw_string(font,Vector2(28,72),"HAPPYLAND / FUNDSTÜCKE",HORIZONTAL_ALIGNMENT_LEFT,-1,42,ink)
  draw_string(font,Vector2(28,123),"Vermisst jemand noch etwas?",HORIZONTAL_ALIGNMENT_LEFT,-1,29,ink)
 elif kind=="tickets":
  draw_string(font,Vector2(24,66),"HAPPYLAND / EINTRITT",HORIZONTAL_ALIGNMENT_LEFT,-1,43,ink)
  draw_string(font,Vector2(26,119),"Bitte die Schuhe hier lassen.",HORIZONTAL_ALIGNMENT_LEFT,-1,29,ink)
 elif kind=="service":
  draw_string(font,Vector2(25,61),"NACH DER LETZTEN FEIER",HORIZONTAL_ALIGNMENT_LEFT,-1,39,ink)
  draw_string(font,Vector2(25,111),"Geschirr abräumen. Fundstücke am Empfang abgeben.",HORIZONTAL_ALIGNMENT_LEFT,-1,23,ink)
 elif kind=="popcorn":
  draw_rect(Rect2(0,0,640,160),Color("713b31"))
  for x in range(0,640,64): draw_rect(Rect2(x,0,29,160),Color("bdac86"))
  draw_rect(Rect2(130,25,380,110),paper)
  draw_string(font,Vector2(160,106),"POPCORN",HORIZONTAL_ALIGNMENT_LEFT,-1,67,ink)
 else:
  draw_string(font,Vector2(27,67),"TECHNISCHER DIENST",HORIZONTAL_ALIGNMENT_LEFT,-1,40,ink)
  draw_string(font,Vector2(27,120),"Ersatzteile / Reinigung / nur für Personal",HORIZONTAL_ALIGNMENT_LEFT,-1,28,ink)
 var rng:=RandomNumberGenerator.new();rng.seed=290
 for i in range(80): draw_circle(Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y)),rng.randf_range(.4,2),Color(.1,.07,.03,.18))

static func texture(parent: Node, id: String) -> ViewportTexture:
 var viewport:=SubViewport.new();viewport.name="DressingPrint_"+id;viewport.size=Vector2i(640,160);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(viewport)
 var print:=DressingPrint.new();print.kind=id;print.size=Vector2(640,160);viewport.add_child(print)
 return viewport.get_texture()
