shader_type spatial;
uniform sampler2D dirt:source_color,filter_linear_mipmap;
uniform sampler2D micro:hint_normal,filter_linear_mipmap;
uniform vec4 tile_color:source_color=vec4(.42,.53,.45,1.);
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=abs(wn.y)>.7?wp.xz:abs(wn.x)>.7?wp.zy:wp.xy;
 vec2 cell=abs(fract(p/.30)-.5);
 float tile=1.-smoothstep(.458,.491,max(cell.x,cell.y));
 vec3 grime=texture(dirt,p*.65).rgb;
 float low=1.-smoothstep(.15,1.45,wp.y);
 float stain=smoothstep(.25,.58,grime.r)*low;
 ALBEDO=mix(vec3(.12,.15,.12),tile_color.rgb*(.65+.35*grime),tile)*(1.-.28*stain);
 ROUGHNESS=mix(.94,.33+.28*grime.r,tile);
 NORMAL_MAP=texture(micro,p*4.).rgb;NORMAL_MAP_DEPTH=.16;
}
