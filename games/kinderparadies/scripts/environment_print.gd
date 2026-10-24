class_name EnvironmentPrint
extends Control

var kind:="plan"
var faded:=false

func _draw() -> void:
 var font:=ThemeDB.fallback_font
 var ink:=Color("354540");var paper:=Color("c1b18b")
 if kind=="badge": paper=Color("c7c7b0")
 draw_rect(Rect2(Vector2.ZERO,size),paper)
 draw_rect(Rect2(18,18,size.x-36,size.y-36),ink,false,2)
 # Creases and irregular grime stay on the opaque printed surface.
 var rng:=RandomNumberGenerator.new();rng.seed=270
 for i in range(145):
  draw_circle(Vector2(rng.randf_range(22,size.x-22),rng.randf_range(22,size.y-22)),rng.randf_range(.5,2.5),Color(.22,.17,.10,.14))
 draw_line(Vector2(size.x*.56,25),Vector2(size.x*.55,size.y-25),Color(.25,.20,.10,.10),2)
 if kind=="plan":
  draw_string(font,Vector2(46,64),"HAPPYLAND / TECHNISCHER DIENST",HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)
  draw_string(font,Vector2(46,99),"BESTANDSPLAN · PERSONAL / NUR INTERN",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
  var rooms:=[{"r":Rect2(48,130,400,190),"t":"SPIELHALLE"},{"r":Rect2(465,130,260,190),"t":"PARTY RAUM"},{"r":Rect2(465,335,260,120),"t":"KOSTÜME"},{"r":Rect2(48,335,125,120),"t":"KÜCHE"},{"r":Rect2(188,335,125,120),"t":"KINO"},{"r":Rect2(328,335,120,120),"t":"TECHNIK"}]
  for room in rooms:
   draw_rect(room.r,ink,false,3);draw_string(font,room.r.position+Vector2(12,32),room.t,HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
  draw_line(Vector2(565,320),Vector2(565,335),Color("7e2924"),8)
  draw_string(font,Vector2(49,501),"Altbestand hinter der Westwand: NICHT BETRETEN.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("792e27"))
  draw_string(font,Vector2(49,541),"Die Tür wurde im Bestandsplan nie eingetragen.",HORIZONTAL_ALIGNMENT_LEFT,-1,19,ink)
 elif kind=="repairs":
  draw_string(font,Vector2(45,68),"WARTUNGSBUCH",HORIZONTAL_ALIGNMENT_LEFT,-1,37,ink)
  var lines:=["03.06.  Lüftung gereinigt. Geruch bleibt.","05.06.  Kostümraum: Haken nachziehen.","07.06.  Spind 04 von innen verformt.","08.06.  Schlüssel eingezogen. Keine Freigabe.","", "Keine Ursache im Bericht angeben.","Rückfragen ausschließlich an die Leitung."]
  for i in range(lines.size()): draw_string(font,Vector2(46,135+i*47),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("772f27") if i==5 else ink)
  draw_line(Vector2(47,330),Vector2(711,330),Color("8a342b"),3)
 elif kind=="badge":
  draw_rect(Rect2(19,19,size.x-38,83),Color("365951"))
  draw_string(font,Vector2(45,75),"HAPPYLAND",HORIZONTAL_ALIGNMENT_LEFT,-1,38,Color("d9c59a"))
  draw_circle(Vector2(115,225),43,ink);draw_rect(Rect2(60,269,110,70),ink)
  draw_string(font,Vector2(214,180),"NACHTDIENST",HORIZONTAL_ALIGNMENT_LEFT,-1,30,ink)
  draw_string(font,Vector2(214,231),"MITARBEITER 013",HORIZONTAL_ALIGNMENT_LEFT,-1,25,ink)
  draw_string(font,Vector2(214,280),"Zutritt: Technik / Personal",HORIZONTAL_ALIGNMENT_LEFT,-1,20,ink)
  for i in range(51): draw_rect(Rect2(215+i*7,338,2 if i%3 else 4,72),ink)
  draw_string(font,Vector2(45,487),"EIGENTUM VON HAPPYLAND",HORIZONTAL_ALIGNMENT_LEFT,-1,24,ink)
  draw_string(font,Vector2(45,531),"Bitte nach Schichtende zurückgeben.",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
 elif kind=="torch_tag":
  draw_string(font,Vector2(90,410),"013",HORIZONTAL_ALIGNMENT_LEFT,-1,350,ink)
  draw_string(font,Vector2(105,520),"NACHTDIENST",HORIZONTAL_ALIGNMENT_LEFT,-1,70,ink)
 elif kind=="exit":
  draw_string(font,Vector2(55,215),"LIEFERAUSGANG",HORIZONTAL_ALIGNMENT_LEFT,-1,62,ink)
  draw_string(font,Vector2(55,310),"AUSSENTÜR VERRIEGELT",HORIZONTAL_ALIGNMENT_LEFT,-1,33,ink)
  draw_string(font,Vector2(55,423),"NUR FÜR PERSONAL",HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)
 elif kind=="exit_changed":
  draw_string(font,Vector2(55,195),"DU WARST",HORIZONTAL_ALIGNMENT_LEFT,-1,67,Color("762a23"))
  draw_string(font,Vector2(55,290),"SCHON DRAUSSEN.",HORIZONTAL_ALIGNMENT_LEFT,-1,57,Color("762a23"))
  draw_string(font,Vector2(55,440),"Warum bist du zurückgekommen?",HORIZONTAL_ALIGNMENT_LEFT,-1,30,ink)
 elif kind=="costumes":
  draw_string(font,Vector2(70,220),"HINTER DER BÜHNE",HORIZONTAL_ALIGNMENT_LEFT,-1,54,ink)
  draw_string(font,Vector2(70,330),"KOSTÜME / PERSONAL",HORIZONTAL_ALIGNMENT_LEFT,-1,37,ink)
  draw_string(font,Vector2(70,440),"Bitte alle Köpfe wieder aufhängen.",HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)

static func texture(parent: Node, id: String) -> ViewportTexture:
 var view:=SubViewport.new();view.name="Print_"+id;view.size=Vector2i(800,600);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(view)
 var content:=EnvironmentPrint.new();content.kind=id;content.size=Vector2(800,600);view.add_child(content)
 return view.get_texture()
