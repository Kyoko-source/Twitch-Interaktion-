class_name GuardPhoneDisplay
extends Node3D

var viewport: SubViewport
var state_label: Label
var timer_label: Label
var call_label: Label
var last_text:=""

func label(parent: Control, value: String, y: float, font_size: int, colour: Color=Color("e1e7df")) -> Label:
 var text:=Label.new();text.text=value;text.position=Vector2(0,y);text.size=Vector2(360,70);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 text.add_theme_font_size_override("font_size",font_size);text.add_theme_color_override("font_color",colour);parent.add_child(text);return text

func build() -> void:
 name="LivePhoneDisplay"
 viewport=SubViewport.new();viewport.size=Vector2i(360,760);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
 var root:=Control.new();root.size=Vector2(360,760);viewport.add_child(root)
 var backdrop:=ColorRect.new();backdrop.size=root.size;backdrop.color=Color("102027");root.add_child(backdrop)
 label(root,"03:17                         82%",8,20,Color("b1c1bf"))
 state_label=label(root,"Eingehender Anruf",92,24,Color("99adac"))
 var portrait:=Panel.new();portrait.position=Vector2(125,200);portrait.size=Vector2(110,110)
 var style:=StyleBoxFlat.new();style.bg_color=Color("30494e");style.corner_radius_top_left=55;style.corner_radius_top_right=55;style.corner_radius_bottom_left=55;style.corner_radius_bottom_right=55;portrait.add_theme_stylebox_override("panel",style);root.add_child(portrait)
 var initials:=label(root,"C",215,51,Color("b0c4bd"))
 label(root,"Chef",341,48)
 timer_label=label(root,"Mobil",407,23,Color("8eaaa5"))
 call_label=label(root,"ANNEHMEN",620,24,Color("8ee3ac"))
 var accept:=Panel.new();accept.position=Vector2(148,550);accept.size=Vector2(64,64)
 var green:=StyleBoxFlat.new();green.bg_color=Color("2d8861");green.corner_radius_top_left=32;green.corner_radius_top_right=32;green.corner_radius_bottom_left=32;green.corner_radius_bottom_right=32;accept.add_theme_stylebox_override("panel",green);root.add_child(accept)
 var handset:=Line2D.new();handset.width=5;handset.default_color=Color("eff8ed");handset.points=PackedVector2Array([Vector2(20,20),Vector2(16,27),Vector2(23,37),Vector2(34,45),Vector2(43,41)]);accept.add_child(handset)
 var swipe:=ColorRect.new();swipe.position=Vector2(122,727);swipe.size=Vector2(116,4);swipe.color=Color("a4b7b1");root.add_child(swipe)
 var face:=MeshInstance3D.new();face.name="OLEDGlassSurface";var quad:=QuadMesh.new();quad.size=Vector2(.068,.144);face.mesh=quad;face.position=Vector3(0,-.002,.0082)
 var glass:=StandardMaterial3D.new();glass.albedo_texture=viewport.get_texture();glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glass.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;face.material_override=glass;add_child(face)

func update_call(state: String, seconds: float) -> void:
 var value:=state+str(int(seconds))
 if value==last_text: return
 last_text=value;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 state_label.text="Eingehender Anruf" if state=="ringing" else "Verbunden" if state=="call" else "Anruf beendet"
 timer_label.text="Mobil" if state=="ringing" else "%02d:%02d"%[int(seconds)/60,int(seconds)%60] if state=="call" else ""
 call_label.text="ANNEHMEN" if state=="ringing" else "AUFLEGEN" if state=="call" else ""
