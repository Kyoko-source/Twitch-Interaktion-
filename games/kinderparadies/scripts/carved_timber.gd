class_name CarvedTimber
extends RefCounted

# Draw the handwriting into a surface-height mask. The wood itself carries the
# cut and its lighting; no floating text, outline or second coplanar panel.
class CutMask extends Control:
 var marks: Array[Dictionary]=[]
 var font: Font=preload("res://assets/backstage-v270/Caveat.ttf")
 func _draw() -> void:
  for mark in marks:
   var p: Vector2=mark.p
   draw_set_transform(p,mark.angle)
   draw_string(font,Vector2.ZERO,mark.text,HORIZONTAL_ALIGNMENT_LEFT,-1,mark.size,Color.WHITE)
  draw_set_transform(Vector2.ZERO)

static func apply(board: MeshInstance3D,marks: Array[Dictionary]) -> void:
 var viewport:=SubViewport.new();viewport.name="CarvingHeightMask";viewport.size=Vector2i(1024,256);viewport.disable_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;board.add_child(viewport)
 var ink:=CutMask.new();ink.marks=marks;ink.size=Vector2(1024,256);viewport.add_child(ink)
 var shader:=Shader.new();shader.code="""
shader_type spatial;
uniform sampler2D wood : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cuts : filter_linear, repeat_disable;
varying vec3 local_normal;
void vertex(){local_normal=NORMAL;}
float depth(vec2 p){return texture(cuts,p).a;}
void fragment(){
 vec2 p=vec2(UV.x,1.0-UV.y);
 float face=step(.9,local_normal.z);
 float ink=depth(p)*face;
 vec2 step_size=vec2(1.0/1024.0,1.0/256.0);
 float dx=(depth(p+vec2(step_size.x,0.0))-depth(p-vec2(step_size.x,0.0)))*face;
 float dy=(depth(p+vec2(0.0,step_size.y))-depth(p-vec2(0.0,step_size.y)))*face;
 vec3 grain=texture(wood,vec2(UV.x*2.4,UV.y*.55)).rgb*vec3(.54,.48,.35);
 // Exposed pale fibres at the cut differ from ink sitting on top of timber.
 vec3 raw_wood=grain*.58+vec3(.055,.034,.012);
 ALBEDO=mix(grain,raw_wood,ink);
 NORMAL_MAP=normalize(vec3(dx*5.5,-dy*5.5,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=2.0;
 ROUGHNESS=mix(.94,.83,ink);
 SPECULAR=.20;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("wood",load("res://assets/wood.png"));material.set_shader_parameter("cuts",viewport.get_texture());board.material_override=material;board.set_meta("carved_wood",true)
