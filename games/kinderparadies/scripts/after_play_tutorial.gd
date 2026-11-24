class_name AfterPlayTutorial
extends CanvasLayer

# 5.7.0: the After Play tutorial. One normal round (look at everything, green
# door), then one anomaly round with the big party rabbit floating (red door).
# Wrong doors are never fatal here: the guide just gets more and more tired.
# Nothing is saved; the real shift stays as it was.

const PURPLE:=Color("b763ff")
const ARROW_RED:=Color("ff3a2c")
const DOOR_RED:=Vector3(-2.15,0,-12.2)
const RABBIT_VIEW:=Vector3(12.2,0,-3.4)
const FLOAT_HEIGHT:=1.15
var g: Node3D
var active:=false
var step:="normal"
var wrong:=0
var again:=false
var clock:=0.0
var shown:=0.0
var box: VBoxContainer
var title: Label
var body: Label
var reminder: Label
var fade_tween: Tween
var arrows: Array[Node3D]=[]
var arrow_root: Node3D
var rabbit: Node3D
var rabbit_base:=Vector3.ZERO
var screen: Control

func build(game: Node3D) -> void:
 g=game;layer=2;name="AfterPlayTutorial"
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 box=VBoxContainer.new();box.name="TutorialText";box.set_anchors_and_offsets_preset(Control.PRESET_CENTER);box.offset_left=-760;box.offset_right=760;box.offset_top=-190;box.offset_bottom=150;box.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation",18);box.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(box)
 title=_text(78);title.name="TutorialTitle";box.add_child(title)
 body=_text(36);body.name="TutorialBody";box.add_child(body)
 reminder=_text(25);reminder.name="TutorialReminder";reminder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);reminder.offset_left=-700;reminder.offset_right=700;reminder.offset_top=70;reminder.offset_bottom=140;root.add_child(reminder)
 box.hide();reminder.hide();hide()

func _text(size: int) -> Label:
 var label:=Label.new();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_override("font",g.title_font);label.add_theme_font_size_override("font_size",size)
 label.add_theme_color_override("font_color",PURPLE);label.add_theme_color_override("font_outline_color",Color(.05,0,.09,.92));label.add_theme_constant_override("outline_size",maxi(8,size/5))
 label.add_theme_color_override("font_shadow_color",Color(0,0,0,.6));label.add_theme_constant_override("shadow_offset_x",0);label.add_theme_constant_override("shadow_offset_y",4)
 return label

func begin() -> void:
 active=true;step="normal";wrong=0;again=false;clock=0;rabbit=null;arrows.clear();arrow_root=null
 _close_screen();show()

func stop() -> void:
 active=false;step="normal";wrong=0
 if fade_tween:fade_tween.kill()
 box.hide();reminder.hide();_close_screen();hide()
 arrows.clear();arrow_root=null;rabbit=null

# The big text in the middle; after a while it gives way and only the short
# reminder stays at the top.
func say(head: String, text: String, hint: String, seconds: float=9.0) -> void:
 title.text=AfterPlayLanguage.t(head);body.text=AfterPlayLanguage.t(text);reminder.text=AfterPlayLanguage.t(hint)
 title.visible=not head.is_empty();body.visible=not text.is_empty()
 if fade_tween:fade_tween.kill()
 box.modulate.a=0.;box.show();reminder.hide();shown=seconds
 fade_tween=create_tween();fade_tween.tween_property(box,"modulate:a",1.,.35)

func tick(delta: float, playing: bool) -> void:
 if not active:return
 if shown>0 and playing:
  shown-=delta
  if shown<=0:
   if fade_tween:fade_tween.kill()
   fade_tween=create_tween();fade_tween.tween_property(box,"modulate:a",0.,.6);fade_tween.tween_callback(box.hide)
   reminder.visible=not reminder.text.is_empty()
 reminder.modulate.a=1. if not playing else .78+sin(clock*3.)*.22
 if not playing:return
 clock+=delta
 if is_instance_valid(rabbit):
  rabbit.position=rabbit_base+Vector3(0,FLOAT_HEIGHT+sin(clock*1.1)*.16,0)
  rabbit.rotation.z=sin(clock*.7)*.05;rabbit.rotation.x=sin(clock*.9+1.)*.04
 var eye: Vector3=g.player.camera.global_position if g.player else Vector3.ZERO
 for i in range(arrows.size()):
  if is_instance_valid(arrows[i]):arrows[i].visible=fmod(clock*2.6+i*.37,1.)<.62;_face(arrows[i],eye)

func start_text() -> void:
 say("Willkommen zu After Play","Sieh dir jeden Raum an. Das ist der Ist-Zustand – so soll jeder Raum aussehen.\nWenn du fertig bist, gehe durch die grüne Tür.","Präge dir jeden Raum ein · dann durch die GRÜNE Tür",11.)

func anomaly_text() -> void:
 say("Das ist jetzt eine Anomalie-Runde","Der große Hase im Party Raum schwebt – so sah er vorhin nicht aus.\nWenn sich etwas verändert hat, gehe durch die rote Tür.","Anomalie: Der große Hase schwebt · durch die ROTE Tür",11.)

# The tutorial's own door result, instead of the shift's.
func door(red: bool) -> void:
 if step=="normal":
  if red:again=true;g._tutorial_round(false)
  else:
   step="anomaly";g._tutorial_round(true)
  return
 if red:g._tutorial_done();return
 wrong+=1
 if wrong>=3:g._tutorial_give_up();return
 g._tutorial_retry()

# Out of the lift: what this round is about.
func arrived() -> void:
 if step=="anomaly":anomaly_text()
 elif again:say("Hier war doch alles normal","Wenn sich nichts verändert hat, nimmst du die grüne Tür.","Alles normal · durch die GRÜNE Tür",8.)
 else:start_text()

func retry_text() -> void:
 if wrong==1:say("Vielleicht hab ich mich nicht richtig ausgedrückt …","ES IST EINE ANOMALIE. ALSO DIE ROTE TÜR!","ANOMALIE · ROTE TÜR",9.)
 else:say("Oh man …","… und du willst 13 Runden schaffen? …","Folge den Pfeilen · ROTE TÜR",9.)

func done_text() -> void:
 say("Richtig!","Rote Tür, wenn sich etwas verändert hat. Grüne Tür, wenn alles normal ist.\nDu bist bereit für die Nachtschicht.","",99.)

# The rabbit lifts off its corner and drifts there.
func float_rabbit(w: PlayWorld) -> void:
 rabbit=w.polish.party_mascot if w and w.polish else null
 if rabbit:rabbit_base=rabbit.position;rabbit.position.y+=FLOAT_HEIGHT

# Lots of blinking arrows, seen through every wall, all pointing at the red door.
func show_arrows(w: PlayWorld) -> void:
 arrows.clear()
 arrow_root=Node3D.new();arrow_root.name="TutorialArrows";w.add_child(arrow_root)
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=ARROW_RED;mat.no_depth_test=true;mat.render_priority=20;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 var door_top:=DOOR_RED+Vector3(0,3.,.6)
 # Straight down onto the red door.
 for i in range(3):_arrow(mat,door_top+Vector3((i-1)*.9,.9+absf(i-1)*.25,0),Vector3.DOWN,1.25)
 # A ring in front of the door.
 for a in range(7):
  var angle:=PI*(.1+.8*a/6.);var p:=DOOR_RED+Vector3(cos(angle)*2.3,1.2,.4+sin(angle)*2.3)
  _arrow(mat,p,(DOOR_RED+Vector3(0,1.2,.2)-p),.8)
 # Trails from the rabbit and from the hall to the door.
 for start in [RABBIT_VIEW+Vector3(0,2.,0),Vector3(-6.2,2.,8.5),Vector3(3.,2.,6.)]:
  var to:=DOOR_RED+Vector3(0,2.2,3.4)
  for k in range(1,7):
   var p: Vector3=start.lerp(to,k/7.)
   _arrow(mat,p,to-p,.9)

func _arrow(mat: Material, p: Vector3, dir: Vector3, size: float) -> void:
 var node:=Node3D.new();node.position=p;node.set_meta("dir",dir.normalized());node.set_meta("size",size);arrow_root.add_child(node)
 _face(node,p+Vector3(0,0,5))
 for turn in [0.]:
  var part:=Node3D.new();node.add_child(part)
  var shaft:=MeshInstance3D.new();var bar:=BoxMesh.new();bar.size=Vector3(.22,.55,.04);shaft.mesh=bar;shaft.position.y=-.27;shaft.material_override=mat;shaft.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;part.add_child(shaft)
  var head:=MeshInstance3D.new();var tip:=PrismMesh.new();tip.size=Vector3(.6,.45,.05);head.mesh=tip;head.position.y=.2;head.material_override=mat;head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;part.add_child(head)
 arrows.append(node)

# Flat arrow: points along its direction, its face turned to the viewer.
func _face(node: Node3D, eye: Vector3) -> void:
 var y: Vector3=node.get_meta("dir");var view:=(eye-node.global_position) if node.is_inside_tree() else (eye-node.position)
 var z:=view-y*view.dot(y)
 if z.length()<.05:z=y.cross(Vector3.UP) if absf(y.y)<.95 else Vector3.BACK
 z=z.normalized();var x:=y.cross(z).normalized()
 node.basis=Basis(x,y,z)*Basis.from_scale(Vector3.ONE*float(node.get_meta("size")))

# The third wrong door: how to close and uninstall the game, circled in red.
# Real screenshots cut together (game menus, Windows start menu and settings);
# each card is 680x800, shown at half size, ring = the circled spot in card pixels.
const UNINSTALL:="res://assets/uninstall-v571/"
const STEPS:=[["step1-quit","ESC · Zum Hauptmenü · Spiel beenden",Rect2(73,677,209,43)],["step2-settings","Windows-Taste · Einstellungen",Rect2(287,394,109,90)],["step3-apps","Apps · Installierte Apps",Rect2(130,339,417,59)],["step4-uninstall","After Play · … · Deinstallieren",Rect2(340,418,281,36)]]

func give_up_screen(back: Callable) -> void:
 _close_screen();box.hide();reminder.hide();show()
 screen=Control.new();screen.name="TutorialGiveUp";screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(screen)
 var shade:=ColorRect.new();shade.color=Color(.035,.03,.05,.97);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.add_child(shade)
 var head:=_text(46);head.text=AfterPlayLanguage.t("Vllt. ist das Spiel nichts für dich, aber hey, mach dir nichts draus.
Spiel einfach mit Bauklötzen oder so.");head.position=Vector2(120,46);head.size=Vector2(1680,150);screen.add_child(head)
 for i in range(STEPS.size()):
  var card:=Panel.new();card.position=Vector2(110+i*430,250);card.size=Vector2(400,520);card.add_theme_stylebox_override("panel",_box(Color("1d1f24"),Color("3d4048"),8));screen.add_child(card)
  var shot:=TextureRect.new();shot.name="TutorialShot%d"%(i+1);shot.texture=load(UNINSTALL+STEPS[i][0]+".png");shot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shot.stretch_mode=TextureRect.STRETCH_SCALE;shot.position=Vector2(30,30);shot.size=Vector2(340,400);card.add_child(shot)
  var caption:=Label.new();caption.text=AfterPlayLanguage.t(STEPS[i][1]);caption.position=Vector2(20,450);caption.size=Vector2(360,60);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",19);caption.add_theme_color_override("font_color",Color("d9d4c6"));card.add_child(caption)
  var spot: Rect2=STEPS[i][2];var circled:=Rect2(shot.position+spot.position*.5,spot.size*.5)
  var ring:=Panel.new();ring.position=circled.position-Vector2(16,14);ring.size=circled.size+Vector2(32,28);ring.add_theme_stylebox_override("panel",_ring());card.add_child(ring)
  var badge:=Label.new();badge.text=str(i+1);badge.position=ring.position+Vector2(ring.size.x-22,-26);badge.size=Vector2(46,46);badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;badge.add_theme_font_size_override("font_size",26);badge.add_theme_color_override("font_color",Color.WHITE);badge.add_theme_stylebox_override("normal",_box(Color("e3261b"),Color("e3261b"),23));card.add_child(badge)
  if i<STEPS.size()-1:
   var next:=Label.new();next.text="→";next.position=Vector2(110+i*430+398,470);next.size=Vector2(34,60);next.add_theme_font_size_override("font_size",40);next.add_theme_color_override("font_color",Color("e3261b"));screen.add_child(next)
 var button: Button=g._button("Zurück zum Hauptmenü",back,true);button.name="TutorialGiveUpBack";button.position=Vector2(680,860);button.size=Vector2(560,56);screen.add_child(button)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;button.grab_focus()

func _close_screen() -> void:
 if is_instance_valid(screen):screen.queue_free()
 screen=null

func _box(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=edge;s.set_border_width_all(1);s.set_corner_radius_all(radius);return s

func _ring() -> StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=Color(0,0,0,0);s.border_color=Color("e3261b");s.set_border_width_all(5);s.set_corner_radius_all(60);s.anti_aliasing=true;return s

func snapshot() -> Dictionary:
 return {"active":active,"step":step,"wrong":wrong,"title":title.text if box.visible else "","reminder":reminder.text if reminder.visible else "","arrows":arrows.size(),"rabbit_float":rabbit.position.y-rabbit_base.y if is_instance_valid(rabbit) else 0.,"give_up":is_instance_valid(screen)}
