class_name CinematicLook
extends RefCounted

# 4.11.0 camera look over the whole frame: lens fringe towards the corners, a
# light unsharp mask, cold shadows and warm highlights with a soft S-curve, a
# deeper vignette and animated grain that sits in the shadows, as on film.
const CODE:="""
shader_type canvas_item;
uniform sampler2D screen_texture:hint_screen_texture,filter_linear;
uniform float grain=0.02;
uniform float aberration=0.0007;
uniform float sharpen=0.32;
uniform float grade=1.0;
uniform float vignette=0.42;
uniform float exposure=1.12;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 uv=SCREEN_UV;vec2 p=uv-0.5;float r2=dot(p,p);
 vec2 fringe=p*r2*aberration*16.0;
 vec3 c=vec3(texture(screen_texture,uv+fringe).r,texture(screen_texture,uv).g,texture(screen_texture,uv-fringe).b);
 vec2 px=SCREEN_PIXEL_SIZE;
 vec3 blur=(texture(screen_texture,uv+vec2(px.x,0.0)).rgb+texture(screen_texture,uv-vec2(px.x,0.0)).rgb+texture(screen_texture,uv+vec2(0.0,px.y)).rgb+texture(screen_texture,uv-vec2(0.0,px.y)).rgb)*0.25;
 c=max(c+(c-blur)*sharpen,vec3(0.0))*exposure;
 float l=dot(c,vec3(0.2126,0.7152,0.0722));
 vec3 tint=mix(vec3(0.88,1.0,1.1),vec3(1.08,1.0,0.88),smoothstep(0.04,0.55,l));
 vec3 g=c*tint;
 vec3 s=clamp(g,0.0,1.0);g=mix(g,s*s*(3.0-2.0*s),0.35);
 g=mix(vec3(dot(g,vec3(0.2126,0.7152,0.0722))),g,1.08);
 c=mix(c,g,grade);
 c*=1.0-smoothstep(0.16,0.86,sqrt(r2)*1.18)*vignette;
 float n=hash(FRAGCOORD.xy+vec2(fract(TIME*7.13)*613.0,fract(TIME*3.71)*389.0))-0.5;
 c+=n*grain*(1.35-l);
 COLOR=vec4(c,1.0);
}
"""

static func material() -> ShaderMaterial:
 var shader:=Shader.new();shader.code=CODE
 var m:=ShaderMaterial.new();m.shader=shader;return m

# Quality 0 keeps grade, vignette and grain; the lens taps cost nothing above it.
static func configure(m: ShaderMaterial,quality: int,grain_on: bool) -> void:
 m.set_shader_parameter("grain",.022 if grain_on else 0.)
 m.set_shader_parameter("aberration",.0007 if quality>0 else 0.)
 m.set_shader_parameter("sharpen",.32 if quality>0 else 0.)
 m.set_shader_parameter("grade",1. if quality>0 else .7)
