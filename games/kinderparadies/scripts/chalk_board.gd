class_name ChalkBoard
extends Node3D

const RESOLUTION:=Vector2i(1024,512)
const SIZE:=Vector2(1.93,.92)
const COLORS: Array[Color]=[Color("e5dfca"),Color("c38376"),Color("cbbb79"),Color("85acb4")]
var paper: Image
var ink: ImageTexture
var face: MeshInstance3D
var canvas: TextureRect
var sound: AudioStreamPlayer
var color_index:=0
var erasing:=false
var drawing:=false
var previous:=Vector2.ZERO
var dirty:=false
var encoded:=""
var history: Array[PackedByteArray]=[]
var sound_left:=0.0

func build(w: PlayWorld) -> void:
 name="ChalkBoard"
 # The grimy dressing mirror is the board requested in the costume room.
 # Retire its old frame, mirror and three cosmetic blocks, keeping the table
 # and its five lamps. Attach in the vanity's local frame, including rotation.
 var vanity:=w.backstage.find_child("BackstageDressingTable",true,false) as Node3D
 for mesh in vanity.get_children():
  if mesh is MeshInstance3D and (absf(mesh.position.y-1.53)<.001 or absf(mesh.position.y-.94)<.001):mesh.hide()
 reparent(vanity,false);position=Vector3(0,1.53,-.20)
 paper=Image.create(RESOLUTION.x,RESOLUTION.y,false,Image.FORMAT_RGBA8);paper.fill(Color.TRANSPARENT)
 ink=ImageTexture.create_from_image(paper)
 var wood:=w.mat(Color("66513c"),load("res://assets/wood.png"),.95)
 # A single opaque slate with chalk mixed into its material: no floating text.
 w.box(self,Vector3(0,0,-.027),Vector3(SIZE.x+.13,SIZE.y+.13,.055),wood)
 for side in [-1,1]:
  w.box(self,Vector3(side*(SIZE.x/2+.025),0,.016),Vector3(.05,SIZE.y+.13,.055),wood)
  w.box(self,Vector3(0,side*(SIZE.y/2+.025),.016),Vector3(SIZE.x+.13,.05,.055),wood)
 face=MeshInstance3D.new();face.name="WritableSlate";var quad:=QuadMesh.new();quad.size=SIZE;face.mesh=quad;face.position.z=.008;add_child(face)
 var shader:=Shader.new();shader.code="""
shader_type spatial;
uniform sampler2D chalk:source_color,filter_linear;
uniform sampler2D grain:source_color,filter_linear_mipmap;
void fragment(){
 vec4 mark=texture(chalk,UV);
 float wear=texture(grain,UV*2.0).r;
 vec3 slate=mix(vec3(.065,.105,.081),vec3(.13,.17,.12),wear);
 ALBEDO=mix(slate,mark.rgb,mark.a*.90);ROUGHNESS=.98;SPECULAR=.08;
}
"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("chalk",ink);material.set_shader_parameter("grain",load("res://assets/paint.png"));face.material_override=material
 var body:=StaticBody3D.new();body.name="ChalkInteraction";body.set_meta("interaction","chalk_board");face.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(SIZE.x,SIZE.y,.012);shape.shape=box;body.add_child(shape)
 w.box(self,Vector3(0,-SIZE.y/2-.095,.10),Vector3(SIZE.x+.16,.035,.23),wood)
 for i in range(3):
  var stick:=w.box(self,Vector3(-.28+i*.25,-SIZE.y/2-.063,.11),Vector3(.13,.028,.03),w.mat(COLORS[i],null,1));stick.rotation.y=(i-1)*.14
 var felt:=w.box(self,Vector3(.60,-SIZE.y/2-.052,.10),Vector3(.19,.055,.105),w.materials.dark);felt.name="ChalkEraser"
 sound=AudioStreamPlayer.new();sound.name="ChalkOnSlate";sound.volume_db=-33;sound.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;add_child(sound)
 var noise:=PackedByteArray();noise.resize(11025);var rng:=RandomNumberGenerator.new();rng.seed=3841;var smooth:=0.0
 for i in range(noise.size()):
  var raw:=rng.randf_range(-1,1);smooth=lerpf(smooth,raw,.22);noise[i]=int((raw-smooth)*30)&255
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_8_BITS;stream.mix_rate=22050;stream.data=noise;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=noise.size();sound.stream=stream

func serialize() -> String:
 finish_stroke()
 if dirty:encoded=Marshalls.raw_to_base64(paper.save_png_to_buffer());dirty=false
 return encoded

func restore(value: String) -> bool:
 if value.length()>2000000:return false
 var image:=Image.new()
 if not value.is_empty():
  if value.length()%4!=0 or not value.begins_with("iVBORw0KGgo"):return false
  var buffer:=Marshalls.base64_to_raw(value)
  if buffer.size()<24 or buffer.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or buffer.slice(16,24)!=PackedByteArray([0,0,4,0,0,0,2,0]):return false
  if image.load_png_from_buffer(buffer)!=OK or image.get_size()!=RESOLUTION:return false
  image.convert(Image.FORMAT_RGBA8)
 else:image=Image.create(RESOLUTION.x,RESOLUTION.y,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 finish_stroke();paper=image;ink.update(paper);encoded=value;dirty=false;history.clear();return true

func open(g: Node3D) -> void:
 finish_stroke();g.phase="chalk"
 var column: VBoxContainer=g._panel("Kreidetafel","Linke Maustaste halten · Zeichnen. Deine Notizen bleiben im Spielstand erhalten.")
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);column.add_child(row)
 var labels: Array[String]=["Weiße Kreide","Rote Kreide","Gelbe Kreide","Blaue Kreide","Schwamm"]
 var group:=ButtonGroup.new()
 for i in range(labels.size()):
  var button: Button=g._button(labels[i],func():select_tool(i));button.name="ChalkTool%d"%i;button.custom_minimum_size=Vector2(150,44);button.toggle_mode=true;button.button_group=group;button.button_pressed=i==(4 if erasing else color_index);row.add_child(button)
 var frame:=PanelContainer.new();frame.name="ChalkDrawingFrame";var border:=g._style(Color("4c3c2b"),Color("8c7758")) as StyleBoxFlat;border.set_content_margin_all(18);frame.add_theme_stylebox_override("panel",border);column.add_child(frame)
 var stack:=Control.new();stack.custom_minimum_size=Vector2(960,480);frame.add_child(stack)
 var slate:=TextureRect.new();slate.name="ChalkSlateBackground";slate.texture=load("res://assets/paint.png");slate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;slate.modulate=Color("283e30");slate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);slate.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_child(slate)
 canvas=TextureRect.new();canvas.name="ChalkDrawingSurface";canvas.texture=ink;canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;canvas.stretch_mode=TextureRect.STRETCH_SCALE;canvas.mouse_default_cursor_shape=Control.CURSOR_CROSS;stack.add_child(canvas)
 canvas.gui_input.connect(_canvas_input);canvas.mouse_exited.connect(finish_stroke)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);column.add_child(actions)
 for action in [["Rückgängig",undo],["Alles abwischen",clear]]:
  var button: Button=g._button(action[0],action[1]);button.custom_minimum_size=Vector2(210,44);actions.add_child(button)
 column.add_child(g._button("Zurück zum Rundgang · ESC",g._close_chalk,true))

func select_tool(index: int) -> void:
 finish_stroke();erasing=index==4;color_index=clampi(index,0,3)

func _canvas_input(event: InputEvent) -> void:
 if not is_instance_valid(canvas):return
 var point: Vector2=event.position*Vector2(RESOLUTION)/canvas.size if event is InputEventMouse else Vector2.ZERO
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:begin_stroke(point)
  else:finish_stroke()
  canvas.accept_event()
 elif event is InputEventMouseMotion and drawing:
  if event.button_mask&MOUSE_BUTTON_MASK_LEFT:extend_stroke(point)
  else:finish_stroke()
  canvas.accept_event()

func _remember() -> void:
 history.append(paper.save_png_to_buffer())
 if history.size()>16:history.pop_front()

func begin_stroke(point: Vector2) -> void:
 if not Rect2(Vector2.ZERO,Vector2(RESOLUTION)).has_point(point):return
 _remember();drawing=true;previous=point;_stamp(point);ink.update(paper);dirty=true

func extend_stroke(point: Vector2) -> void:
 if not drawing:return
 if not Rect2(Vector2.ZERO,Vector2(RESOLUTION)).has_point(point):finish_stroke();return
 var distance:=previous.distance_to(point)
 for i in range(1,ceili(distance/1.3)+1):_stamp(previous.lerp(point,minf(1,i*1.3/maxf(.001,distance))))
 previous=point;ink.update(paper);dirty=true
 if distance>1:
  sound_left=.12
  if not sound.playing:sound.play()

func _stamp(point: Vector2) -> void:
 var radius: float=18.0 if erasing else 2.8
 for y in range(maxi(0,floori(point.y-radius)),mini(RESOLUTION.y,ceili(point.y+radius)+1)):
  for x in range(maxi(0,floori(point.x-radius)),mini(RESOLUTION.x,ceili(point.x+radius)+1)):
   var distance:=Vector2(x,y).distance_to(point)
   if distance>radius:continue
   var old:=paper.get_pixel(x,y)
   if erasing:paper.set_pixel(x,y,Color(old.r,old.g,old.b,old.a*smoothstep(radius*.5,radius,distance)))
   else:
    var grain:=.34+float((x*37+y*19+x*y*13)%101)/150.0
    var amount: float=(1-smoothstep(radius*.3,radius,distance))*grain*.65
    var c:=COLORS[color_index];var alpha: float=old.a+amount*(1-old.a)
    paper.set_pixel(x,y,Color((c.r*amount+old.r*old.a*(1-amount))/maxf(.001,alpha),(c.g*amount+old.g*old.a*(1-amount))/maxf(.001,alpha),(c.b*amount+old.b*old.a*(1-amount))/maxf(.001,alpha),alpha))

func finish_stroke() -> void:
 drawing=false;sound_left=0
 if is_instance_valid(sound):sound.stop()

func undo() -> void:
 finish_stroke()
 if history.is_empty():return
 paper.load_png_from_buffer(history.pop_back());ink.update(paper);dirty=true

func clear() -> void:
 finish_stroke();_remember();paper.fill(Color.TRANSPARENT);ink.update(paper);dirty=true

func _process(delta: float) -> void:
 if drawing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):finish_stroke()
 sound_left=maxf(0,sound_left-delta)
 if sound_left==0 and is_instance_valid(sound):sound.stop()
