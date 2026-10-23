class_name ArchiveMemories
extends Control

const MANIFEST:="res://assets/presentation-v250/memories.json"
var shots: Array=[]
var textures: Dictionary={}
var previous: TextureRect
var current: TextureRect
var hint: Label
var shot_index:=-1
var audio_position:=0.0
var blend:=0.0

func build() -> void:
 name="ArchiveMemories";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 shots=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)).shots
 var black:=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);black.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(black)
 previous=_image();current=_image()
 hint=Label.new();hint.text="ESC · Pause";hint.add_theme_font_size_override("font_size",15);hint.add_theme_color_override("font_color",Color(.9,.86,.74,.7));hint.position=Vector2(42,1020);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hint)
 hide()

func _image() -> TextureRect:
 var image:=TextureRect.new();image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var shader:=Shader.new();shader.code="shader_type canvas_item;uniform float progress=0.0;uniform float motion=1.0;uniform float direction=1.0;varying vec4 tint;void vertex(){tint=COLOR;}void fragment(){float p=clamp(progress,0.0,1.0)*motion;vec2 uv=(UV-.5)/(1.025+p*.055)+.5+vec2((p-.5)*.009*direction,(p-.5)*.004);vec4 c=texture(TEXTURE,uv);float edge=1.0-smoothstep(.20,.76,length(UV-.5))*.23;COLOR=vec4(c.rgb*edge,c.a)*tint;}"
 var material:=ShaderMaterial.new();material.shader=shader;image.material=material;add_child(image);return image

func index_at(seconds: float) -> int:
 var index:=0
 for i in range(shots.size()):
  if seconds>=float(shots[i].start): index=i
 return index

func _texture(index: int) -> Texture2D:
 if not textures.has(index): textures[index]=load("res://assets/presentation-v250/"+str(shots[index].image))
 return textures[index]

func render(seconds: float, duration: float, motion: bool) -> void:
 if shots.is_empty(): hide();return
 audio_position=clampf(seconds,0,duration);var index:=index_at(audio_position);shot_index=index
 current.texture=_texture(index);previous.texture=_texture(maxi(0,index-1))
 var start: float=shots[index].start
 var end: float=shots[index+1].start if index+1<shots.size() else duration
 blend=smoothstep(0.0,1.1,audio_position-start) if index>0 else 1.0
 current.modulate.a=blend
 previous.material.set_shader_parameter("progress",1.0)
 current.material.set_shader_parameter("progress",clampf((audio_position-start)/maxf(.1,end-start),0,1))
 for image in [previous,current]:
  image.material.set_shader_parameter("motion",1.0 if motion else 0.0);image.material.set_shader_parameter("direction",1.0 if index%2==0 else -1.0)
 modulate.a=minf(smoothstep(0.0,.7,audio_position),1.0-smoothstep(duration-.6,duration,audio_position))
 hint.modulate.a=1.0-smoothstep(6.0,9.0,audio_position)
 show()

func snapshot() -> Dictionary:
 return {"visible":visible,"shot":shot_index,"position":audio_position,"blend":blend,"image":shots[shot_index].image if shot_index>=0 else "","count":shots.size()}
