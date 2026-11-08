class_name ShoutText
extends Control

# The comment typewriter's look (outlined fallback font, glyphs that later
# fall into the scene), but huge, blood red and shaking as if screamed.
const RED:=Color("d0161d")
var glyphs: Array[Dictionary]=[]
var typed:=0
var dropped:=0
var font: Font
var font_size:=84
var text:=""
var shake:=0.0
var rng:=RandomNumberGenerator.new()

func layout(value: String) -> void:
 text=value;glyphs.clear();typed=0;dropped=0;font=ThemeDB.fallback_font;rng.seed=430
 var lines: Array[String]=[];var current:=""
 for word in value.split(" "):
  var candidate:=current+(" " if not current.is_empty() else "")+word
  if font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>1640 and not current.is_empty():
   lines.append(current);current=word
  else:current=candidate
 if not current.is_empty():lines.append(current)
 for row in range(lines.size()):
  var line:=lines[row];var width:=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  for i in range(line.length()):
   var x:=font.get_string_size(line.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
   glyphs.append({"char":line.substr(i,1),"position":Vector2(-width*.5+x,row*104.),"born":-1.,"jitter":Vector2.ZERO,"tilt":0.})
 queue_redraw()

func type_all_until(index: int,now: float) -> void:
 while typed<mini(index,glyphs.size()):
  glyphs[typed].born=now;typed+=1

func tick(now: float) -> void:
 # Every glyph trembles on its own, harder while the voice is loudest.
 for i in range(dropped,typed):
  var glyph: Dictionary=glyphs[i]
  glyph.jitter=Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*shake
  glyph.tilt=rng.randf_range(-1,1)*shake*.004
 queue_redraw()

func glyph_screen(i: int) -> Vector2:
 var glyph: Dictionary=glyphs[i]
 return global_position+glyph.position+glyph.jitter

func _draw() -> void:
 if not font:return
 for i in range(dropped,mini(typed,glyphs.size())):
  var glyph: Dictionary=glyphs[i]
  # Each letter slams in oversized and snaps down to size.
  var age: float=float(get_meta("now",0.))-float(glyph.born)
  var punch:=1.+.45*maxf(0.,1.-age/.1)
  var at: Vector2=glyph.position+glyph.jitter
  draw_set_transform(at+Vector2(font_size*.3,-font_size*.35),glyph.tilt,Vector2.ONE*punch)
  var local:=Vector2(-font_size*.3,font_size*.35)
  draw_char_outline(font,local,glyph.char,font_size,12,Color(0,0,0,.92))
  draw_char(font,local,glyph.char,font_size,RED)
 draw_set_transform(Vector2.ZERO)
