class_name DialogueText
extends Control

var glyphs: Array[Dictionary]=[]
var typed:=0
var dropped:=0
var font: Font
var font_size:=27
var text:=""

func _draw() -> void:
 for i in range(dropped,mini(typed,glyphs.size())):
  var glyph: Dictionary=glyphs[i]
  draw_char_outline(font,glyph.position,glyph.char,font_size,5,Color(0,0,0,.88))
  draw_char(font,glyph.position,glyph.char,font_size,glyph.color)

func layout(value: String,emphasis: Array) -> void:
 text=value;glyphs.clear();typed=0;dropped=0;font=ThemeDB.fallback_font
 var lines: Array[String]=[];var current:=""
 for word in value.split(" "):
  var candidate:=current+(" " if not current.is_empty() else "")+word
  if font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>1040 and not current.is_empty():
   lines.append(current);current=word
  else:current=candidate
 if not current.is_empty():lines.append(current)
 var text_offset:=0
 for row in range(lines.size()):
  var line:=lines[row];var width:=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  for i in range(line.length()):
   var color:=Color("ede7d6")
   for key in emphasis:
    var found:=value.find(str(key))
    if found>=0 and text_offset+i>=found and text_offset+i<found+str(key).length():color=Color("e1bc7f");break
   var x:=font.get_string_size(line.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
   glyphs.append({"char":line.substr(i,1),"position":Vector2(-width*.5+x,row*37.),"color":color})
  text_offset+=line.length()+1
 queue_redraw()
