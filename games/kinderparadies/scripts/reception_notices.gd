class_name ReceptionNotices
extends Control

const NOTES=[
 ["SCHICHTÜBERGABE","Bitte die Seitentür\nnach Feierabend\nabschließen.\n\nSchlüssel zurück\nans Brett!\n\nDanke, Ralf", "reception_shift"],
 ["Rückruf!","Frau Weber\nwegen Reservierung\nzurückrufen.\n\nSamstag, 14 Uhr?\n\n– Jana", "reception_phone"],
 ["GEBURTSTAGSFEIER","Samstag · 14:00 Uhr\n\nMia / 8 Kinder\nTisch am Fenster\n\nKeine Nüsse!\n\nAnzahlung erhalten.", "reception_birthday"],
 ["Nicht vergessen!","[x] Becher auffüllen\n[ ] Handtücher\n[ ] Kasse zählen\n\nDie kleine Lampe\nbitte anlassen.\n\nBis morgen!", "reception_list"],
 ["HAUSMEISTER","Licht am Automaten\nwieder ausgefallen.\n\nErsatzbirnen liegen\nim unteren Fach.\n\nNicht wegwerfen!", "reception_repair"]
]
var index:=0

func _draw() -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=408+index*29
 var paper:=Color("e5ddc4") if index%2==0 else Color("d9d0ae")
 draw_rect(Rect2(Vector2.ZERO,size),paper)
 # Fine paper fibres and translucent edge wear, rather than wall plaster.
 for i in range(1600):
  var p:=Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y))
  draw_line(p,p+Vector2(rng.randf_range(.5,2.4),.2),Color(.33,.28,.19,rng.randf_range(.025,.085)),.7,true)
 for edge in range(9):draw_rect(Rect2(Vector2.ONE*edge,size-Vector2.ONE*edge*2),Color(.42,.33,.18,.025),false,1.)
 for i in range(45):
  var p:=Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y))
  if p.x<18 or p.x>size.x-18:draw_circle(p,rng.randf_range(2,12),Color(.41,.31,.16,.025))
 var ink:=Color("354749") if index%2 else Color("57534a")
 var typed:=load("res://assets/Oswald.ttf") as Font
 var pen:=load("res://assets/backstage-v270/Caveat.ttf") as Font
 if index in [0,2,4]:
  draw_string(typed,Vector2(29,47),"HAPPYLAND / INTERN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("6e7667"))
  draw_line(Vector2(29,58),Vector2(355,58),Color("7b8273"),1.,true)
  draw_string(typed,Vector2(29,99),NOTES[index][0],HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)
 else:
  draw_set_transform(Vector2(26,85),-.035 if index==1 else .018)
  draw_string(pen,Vector2.ZERO,NOTES[index][0],HORIZONTAL_ALIGNMENT_LEFT,-1,43,ink);draw_set_transform(Vector2.ZERO)
 var y:=143.
 for line: String in str(NOTES[index][1]).split("\n"):
  draw_set_transform(Vector2(30+rng.randf_range(-1.5,1.5),y),rng.randf_range(-.012,.012))
  draw_string(pen,Vector2.ZERO,line,HORIZONTAL_ALIGNMENT_LEFT,-1,30,ink)
  draw_set_transform(Vector2.ZERO);y+=35.
 if index==2:draw_line(Vector2(27,319),Vector2(175,317),Color("92594c"),1.8,true)
 # Subtle fold and a dried ring, in different places on each sheet.
 var fold:=278.+index*21.
 draw_line(Vector2(0,fold),Vector2(size.x,fold+1),Color(.43,.36,.25,.10),1.,true)
 draw_line(Vector2(0,fold+1.5),Vector2(size.x,fold+2.5),Color(1,1,.9,.22),1.,true)
 if index==1:
  for i in range(3):draw_arc(Vector2(307,414),46.+i*.7,.3,5.5,45,Color(.37,.28,.13,.035),1.2,true)

static func build(w: PlayWorld,board: Node3D) -> void:
 for i in range(NOTES.size()):
  var view:=SubViewport.new();view.name="NoticePrint%d"%i;view.size=Vector2i(384,512);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;board.add_child(view)
  var drawing:=ReceptionNotices.new();drawing.index=i;drawing.size=Vector2(384,512);view.add_child(drawing)
  var page:=MeshInstance3D.new();page.name="PinnedPaperNotice%d"%i
  var tint:=Color(.55,.55,.55) if OS.has_feature("web") else Color.WHITE
  var material:=w.mat(tint,view.get_texture(),.98);material.metallic_specular=.08;material.texture_repeat=false
  page.material_override=material;board.add_child(page)
  var dims: Vector2=[Vector2(.37,.49),Vector2(.33,.43),Vector2(.36,.47),Vector2(.35,.46),Vector2(.38,.50)][i]
  page.position=Vector3(-.62+(i%3)*.52,-.18+floori(i/3.)*.57,.027)
  page.rotation.z=[-.035,.048,-.018,.065,-.045][i]
  PaperCraft.finish(page,dims)
  page.set_meta("sign_rect",dims);page.set_meta("sign_design",NOTES[i][2]);page.set_meta("sign_text",NOTES[i][0]+"\n"+NOTES[i][1]);page.add_to_group("caption_signs")
  var p:=Vector3(0,dims.y*.5-.028,.009)
  w.tube(page,p-Vector3.BACK*.010,p+Vector3.BACK*.005,.0011,w.materials.metal)
  var pin:=w.sphere(page,p+Vector3.BACK*.006,.009,w.materials.red if i%2==0 else w.materials.gold);pin.scale.z=.47
