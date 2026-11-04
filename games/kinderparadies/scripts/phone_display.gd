class_name GuardPhoneDisplay
extends Node3D

var viewport: SubViewport
var state_label: Label
var timer_label: Label
var call_label: Label
var last_text:=""
var artwork: CallArtwork

class CallArtwork extends Control:
 var connected:=false
 var ended:=false
 func _draw() -> void:
  # An opaque low-cost gradient and vector icons remain crisp at close range.
  for row in range(96):
   var t:=row/95.
   draw_rect(Rect2(0,row*8,360,8),Color("1c3436").lerp(Color("080f14"),t))
  for ring in range(4):draw_arc(Vector2(180,260),83+ring*19,0.,TAU,96,Color(.52,.69,.63,.07-ring*.012),1.,true)
  draw_circle(Vector2(180,260),70,Color("294c49"))
  draw_circle(Vector2(180,244),17,Color("a3bbb0"))
  draw_arc(Vector2(180,287),32,PI,TAU,32,Color("a3bbb0"),21.,true)
  # Actual battery, cellular reception and a small lock icon.
  for bar in range(4):draw_rect(Rect2(272+bar*7,36-bar*4,4,6+bar*4),Color("a8b9b0"))
  draw_rect(Rect2(313,22,29,13),Color("a8b9b0"),false,1.6);draw_rect(Rect2(316,25,20,7),Color("a8b9b0"));draw_rect(Rect2(343,26,2,5),Color("a8b9b0"))
  draw_line(Vector2(34,121),Vector2(326,121),Color(.7,.8,.75,.13),1.,true)
  for x in [88,180,272]:
   draw_circle(Vector2(x,505),25,Color(.65,.77,.72,.10))
  for j in range(3):
   for k in range(3):draw_circle(Vector2(80+j*8,497+k*8),1.5,Color("a5b9ae"))
  draw_rect(Rect2(174,493,12,18),Color("a5b9ae"),false,2.)
  draw_arc(Vector2(180,504),11,0.,PI,20,Color("a5b9ae"),2.,true);draw_line(Vector2(180,515),Vector2(180,521),Color("a5b9ae"),2.)
  draw_polyline(PackedVector2Array([Vector2(262,500),Vector2(269,500),Vector2(276,494),Vector2(276,516),Vector2(269,510),Vector2(262,510),Vector2(262,500)]),Color("a5b9ae"),2.,true)
  draw_arc(Vector2(274,505),13,-.7,.7,20,Color("a5b9ae"),2.,true)
  var button_color:=Color("833e35") if connected else Color("428a70")
  if ended:button_color=Color("293b38")
  draw_circle(Vector2(180,630),36,button_color)
  var receiver:=PackedVector2Array([Vector2(165,619),Vector2(162,625),Vector2(168,635),Vector2(180,643),Vector2(189,645),Vector2(196,637)])
  draw_polyline(receiver,Color("e5ecdf"),5.,true)
  draw_line(Vector2(133,739),Vector2(227,739),Color("abbcb2"),3.,true)
  # Fine edge damage on the protector, clear of the useful display.
  draw_polyline(PackedVector2Array([Vector2(360,710),Vector2(342,680),Vector2(350,658),Vector2(336,641)]),Color(.70,.81,.75,.19),.8,true)
  draw_line(Vector2(342,680),Vector2(328,674),Color(.7,.81,.75,.14),.7,true)

func label(parent: Control,value: String,y: float,font_size: int,colour: Color=Color("d9e3d8")) -> Label:
 var text:=Label.new();text.text=value;text.position=Vector2(0,y);text.size=Vector2(360,60);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 text.add_theme_font_size_override("font_size",font_size);text.add_theme_color_override("font_color",colour);parent.add_child(text);return text

func rounded_screen() -> ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var boundary:=PackedVector3Array();var width:=.068;var height:=.144;var radius:=.0041
 for corner in range(4):
  var centre:=Vector2((1 if corner in [0,3] else -1)*(width*.5-radius),(1 if corner<2 else -1)*(height*.5-radius))
  for sample in range(9):
   var a:=float(corner)*PI/2.+sample*PI/16.
   boundary.append(Vector3(centre.x+cos(a)*radius,centre.y+sin(a)*radius,0))
 for i in range(boundary.size()):
  for point in [Vector3.ZERO,boundary[(i+1)%boundary.size()],boundary[i]]:
   st.set_normal(Vector3.BACK);st.set_uv(Vector2(point.x/width+.5,.5-point.y/height));st.add_vertex(point)
 st.generate_tangents();st.index();return st.commit()

func build() -> void:
 name="LivePhoneDisplay"
 viewport=SubViewport.new();viewport.size=Vector2i(360,760);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
 artwork=CallArtwork.new();artwork.size=Vector2(360,760);viewport.add_child(artwork)
 var time:=label(artwork,"03:17",11,22);time.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;time.position.x=26
 label(artwork,"HAPPYLAND / NACHTDIENST",62,19,Color("9caf9e"))
 state_label=label(artwork,"Eingehender Anruf",133,25,Color("a8bfb4"))
 label(artwork,"Chef",349,53)
 timer_label=label(artwork,"Mobil",411,24,Color("a4b7ae"))
 for i in range(3):
  var text:=label(artwork,["Tasten","Stumm","Lautsprecher"][i],540,15,Color("8fa69a"));text.position.x=i*92-92
 call_label=label(artwork,"ANNEHMEN",680,19,Color("b3c8b8"))
 var face:=MeshInstance3D.new();face.name="OLEDGlassSurface";face.mesh=rounded_screen();face.position=Vector3(0,-.002,.00745)
 var glass:=StandardMaterial3D.new();glass.albedo_texture=viewport.get_texture();glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glass.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;face.material_override=glass;add_child(face)
 # A separate smooth, almost clear glass skin catches only a faint highlight.
 var reflection:=MeshInstance3D.new();reflection.name="SmudgedProtectorGloss";reflection.mesh=face.mesh;reflection.position=face.position+Vector3(0,0,.00015)
 var sheen:=StandardMaterial3D.new();sheen.albedo_color=Color(.34,.42,.38,.025);sheen.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;sheen.roughness=.22;sheen.metallic_specular=.23;reflection.material_override=sheen;add_child(reflection)

func update_call(state: String,seconds: float) -> void:
 var value:=state+str(int(seconds))+AfterPlayLanguage.code
 if value==last_text:return
 last_text=value;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 state_label.text="Eingehender Anruf" if state=="ringing" else "Verbunden" if state=="call" else "Anruf beendet"
 timer_label.text="Mobil" if state=="ringing" else "%02d:%02d"%[int(seconds)/60,int(seconds)%60] if state=="call" else ""
 call_label.text="ANNEHMEN" if state=="ringing" else "AUFLEGEN" if state=="call" else ""
 artwork.connected=state=="call";artwork.ended=state not in ["ringing","call"];artwork.queue_redraw()
