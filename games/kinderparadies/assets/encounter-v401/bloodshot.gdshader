shader_type canvas_item;
render_mode unshaded;
uniform float injury : hint_range(0.0, 1.0) = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0)),f.x),f.y);
}
float vessels(vec2 uv) {
 float distance_to_edge=min(uv.x,1.0-uv.x);
 float travel=distance_to_edge*14.0;
 float wave=uv.y*31.0+sin(travel*2.7+uv.y*17.0)*0.42+sin(travel*6.2)*0.12;
 float main=1.0-smoothstep(0.008,0.055,abs(fract(wave)-0.5));
 float branch=1.0-smoothstep(0.01,0.045,abs(fract(wave*1.83+travel*1.5)-0.5));
 float taper=1.0-smoothstep(0.025,0.21+noise(vec2(uv.y*20.0,1.0))*0.05,distance_to_edge);
 return (main+branch*0.4)*taper;
}
void fragment() {
 vec2 p=abs(UV-0.5)*2.0;
 float shape=pow(p.x,4.0)+pow(p.y,4.0);
 float mottling=noise(UV*vec2(24.0,15.0));
 float rim=smoothstep(0.24,1.1,shape)*(0.74+mottling*0.26);
 float capillaries=max(vessels(UV),vessels(UV.yx)*0.55);
 float alpha=injury*(rim*0.50+capillaries*0.16)+impact*rim*0.12;
 // Keep the centre clear: a translucent injury rather than a full red wash.
 vec3 blood=mix(vec3(0.13,0.004,0.012),vec3(0.40,0.018,0.035),mottling*0.6);
 COLOR=vec4(blood,clamp(alpha,0.0,0.75));
}
