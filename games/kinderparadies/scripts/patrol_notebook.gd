class_name PatrolNotebook
extends Control

var visited: Array[String]=[]
var round_number:=1
var finished:=false
var handwriting: Font=preload("res://assets/backstage-v270/Caveat.ttf")
var paper: Texture2D=preload("res://assets/story/paper.png")

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)

func _draw() -> void:
 var factor:=minf(size.x/1000.0,size.y/760.0)
 draw_set_transform(Vector2((size.x-1000*factor)*.5,0),0,Vector2.ONE*factor)
 draw_texture_rect(paper,Rect2(0,0,1000,760),false,Color(.97,.96,.90))
 var ink:=Color("3b3b32")
 draw_string(handwriting,Vector2(65,84),"Meine Nachtschicht",HORIZONTAL_ALIGNMENT_LEFT,-1,65,ink)
 draw_string(handwriting,Vector2(740,78),"Runde %02d"%round_number,HORIZONTAL_ALIGNMENT_LEFT,-1,35,Color("625440"))
 draw_line(Vector2(63,110),Vector2(929,107),Color(.25,.25,.19,.4),1.2,true)
 draw_string(handwriting,Vector2(67,154),"Schon vorbeigeschaut?",HORIZONTAL_ALIGNMENT_LEFT,-1,33,ink)
 for i in range(PatrolState.ZONES.size()):
  var zone: String=PatrolState.ZONES[i];var y:=210.0+i*66
  var box:=PackedVector2Array([Vector2(72,y-26),Vector2(98,y-27),Vector2(100,y+1),Vector2(71,y),Vector2(72,y-26)])
  draw_polyline(box,Color(.2,.22,.18,.7),1.7,true)
  draw_string(handwriting,Vector2(125,y+1),zone,HORIZONTAL_ALIGNMENT_LEFT,-1,42,ink)
  draw_line(Vector2(126,y+11),Vector2(903,y+13),Color(.26,.24,.18,.13),1,true)
  if zone in visited:
   draw_polyline(PackedVector2Array([Vector2(75,y-12),Vector2(85,y-1),Vector2(111,y-36)]),Color("47493a"),2.8,true)
 draw_string(handwriting,Vector2(67,664),"Nur meine Merkliste. Nichts davon ist ein Beweis.",HORIZONTAL_ALIGNMENT_LEFT,-1,34,ink)
 draw_string(handwriting,Vector2(69,711),"Ich kann jederzeit zur Tür gehen." if not finished else "Dreizehn Runden. Und doch bin ich wieder hier.",HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("795045"))
