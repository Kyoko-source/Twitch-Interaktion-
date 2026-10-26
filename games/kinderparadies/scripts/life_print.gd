class_name LifePrint
extends Control

var kind:="menu"

func _draw() -> void:
 var font:=load("res://assets/Oswald.ttf") as Font
 var ink:=Color("39382d");var cream:=Color("cab993")
 draw_rect(Rect2(Vector2.ZERO,size),cream)
 var rng:=RandomNumberGenerator.new();rng.seed=2110
 for i in range(220):
  draw_circle(Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y)),rng.randf_range(.5,4),Color(.25,.16,.07,.10))
 draw_rect(Rect2(12,12,size.x-24,size.y-24),Color("85754f"),false,2)
 if kind=="menu":
  draw_string(font,Vector2(40,76),"HAPPYLAND / SNACKBAR",HORIZONTAL_ALIGNMENT_LEFT,-1,51,ink)
  draw_line(Vector2(40,100),Vector2(728,100),ink,2)
  var rows:=["Pommes mit Ketchup                      2,50 DM","Würstchen im Brötchen                   3,00 DM","Slush / Kirsche oder Waldmeister        1,50 DM","Geburtstagsmenü                         5,00 DM"]
  for i in range(rows.size()): draw_string(font,Vector2(40,153+i*63),rows[i],HORIZONTAL_ALIGNMENT_LEFT,-1,31,ink)
  draw_string(font,Vector2(40,442),"KÜCHE GESCHLOSSEN",HORIZONTAL_ALIGNMENT_LEFT,-1,47,Color("793c30"))
 elif kind=="photo":
  draw_string(font,Vector2(30,82),"DEIN HAPPYLAND-FOTO",HORIZONTAL_ALIGNMENT_LEFT,-1,55,ink)
  draw_string(font,Vector2(34,139),"4 Aufnahmen / 2 DM",HORIZONTAL_ALIGNMENT_LEFT,-1,32,ink)
 elif kind=="wc":
  draw_string(font,Vector2(34,83),"KINDER-WC",HORIZONTAL_ALIGNMENT_LEFT,-1,68,ink)
  draw_string(font,Vector2(38,140),"Bitte Hände waschen.",HORIZONTAL_ALIGNMENT_LEFT,-1,30,ink)
 elif kind=="closed":
  draw_string(font,Vector2(34,83),"BIS AUF WEITERES",HORIZONTAL_ALIGNMENT_LEFT,-1,50,ink)
  draw_string(font,Vector2(34,142),"GESCHLOSSEN",HORIZONTAL_ALIGNMENT_LEFT,-1,53,Color("793c30"))
 elif kind=="soap":
  draw_string(font,Vector2(32,88),"SEIFE",HORIZONTAL_ALIGNMENT_LEFT,-1,71,ink)
  draw_string(font,Vector2(34,139),"HAPPYLAND",HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)

static func texture(parent: Node, id: String) -> ViewportTexture:
 var viewport:=SubViewport.new();viewport.name="LifePrint_"+id;viewport.size=Vector2i(768,480) if id=="menu" else Vector2i(768,180)
 viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(viewport)
 var print:=LifePrint.new();print.kind=id;print.size=viewport.size;viewport.add_child(print);return viewport.get_texture()
