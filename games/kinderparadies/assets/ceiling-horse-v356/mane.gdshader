shader_type spatial;
render_mode cull_disabled;
uniform vec4 points[32];
uniform vec3 frames[32];
void vertex() {
 int i=int(round(UV.y*31.0));
 vec3 tangent=normalize(points[min(i+1,31)].xyz-points[max(i-1,0)].xyz);
 vec3 side=normalize(frames[i]); vec3 up=normalize(cross(tangent,side));
 vec3 radial=side*cos(UV.x*6.2831853)+up*sin(UV.x*6.2831853);
 VERTEX=points[i].xyz+radial*points[i].w+vec3(0,-UV2.x,0)+side*UV2.y;
 NORMAL=radial;
}
void fragment() { ALBEDO=vec3(.009,.006,.004); ROUGHNESS=.98; SPECULAR=.12; }
