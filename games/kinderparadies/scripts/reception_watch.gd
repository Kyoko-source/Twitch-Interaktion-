class_name ReceptionWatch
extends Node3D

const ROOT:="res://assets/reception-v2120/"
const WALL:=Vector3(1.2,3.15,16.94)
const FEEDS:=[
 {"label":"01 / EMPFANG","p":Vector3(-9.6,3.65,8.4),"at":Vector3(-4.6,1.0,4.0)},
 {"label":"02 / SPIELANLAGE","p":Vector3(5.8,5.9,9.5),"at":Vector3(1.2,1.1,5.4)},
 {"label":"03 / PARTY RAUM","p":Vector3(7.3,4.5,-2.3),"at":Vector3(13.7,1.2,-7.3)},
 {"label":"04 / TECHNIK","p":Vector3(-10.65,2.88,-2.25),"at":Vector3(-14.4,1.1,-5.0)},
 {"label":"05 / KÜCHE","p":Vector3(-12.0,3.30,-26.2),"at":Vector3(-14.0,1.1,-31.0)},
 {"label":"06 / KINO","p":Vector3(-5.9,3.05,-25.85),"at":Vector3(.7,1.0,-30.0)},
 {"label":"07 / WC-VORRAUM","p":Vector3(20.3,2.9,9.9),"at":Vector3(24.0,1.1,6.0)}
]
var w: PlayWorld
var board: Node3D
var viewport: SubViewport
var camera: Camera3D
var display: MeshInstance3D
var glass: ShaderMaterial
var standby: Material
var opened:=false
var feed:=0
var changes:=0
var photos: Array[MeshInstance3D]=[]

func build(world: PlayWorld) -> void:
 w=world;name="ReceptionMemoriesAndCCTV"
 _wall();_monitor();_housings()

func _wall() -> void:
 board=Node3D.new();board.name="BirthdayMemoriesWall";board.position=WALL;board.rotation.y=PI;add_child(board)
 w.box(board,Vector3(0,0,-.055),Vector3(4.45,2.03,.075),w.mat(Color("756c4b"),load("res://assets/aged-plaster.png"),.98))
 for sign_value in [-1,1]:
  w.box(board,Vector3(sign_value*2.24,0,-.015),Vector3(.07,2.14,.09),w.materials.wood)
  w.box(board,Vector3(0,sign_value*1.055,-.015),Vector3(4.55,.07,.09),w.materials.wood)
 var cream:=w.mat(Color("c8b891"),load("res://assets/paint.png"),.97)
 var tape:=w.mat(Color("9d9069"),load("res://assets/paint.png"),.99)
 var names:=["Mara / 6","Jonas / 8","Sommer 98","Lena / 7","Happyland","Felix / 9"]
 for i in range(8):
  var row:=i/4;var col:=i%4
  var sheet:=Node3D.new();sheet.position=Vector3(-1.78+col*.60,.38-row*.91,.025);sheet.rotation.z=sin(i*3.71)*.075;board.add_child(sheet)
  if i in [2,5]:
   # A dark rectangular sun mark and torn adhesive are the missing prints.
   w.box(sheet,Vector3(0,0,-.023),Vector3(.46,.63,.003),w.mat(Color("564d34"),null,.99))
  else:
   w.box(sheet,Vector3.ZERO,Vector3(.46,.64,.012),cream)
   var photo:=_image(sheet,Vector3(0,.06,.008),Vector2(.39,.40),i%3);photos.append(photo)
   var caption:=_print(names[photos.size()-1],true)
   _face(sheet,Vector3(0,-.235,.009),Vector2(.39,.10),caption)
  for side in [-1,1]:
   var strip:=w.box(sheet,Vector3(side*.16,.29,.017),Vector3(.15,.055,.006),tape);strip.rotation.z=side*.25
 var staff:=w.artwork(board,Vector3(1.30,.12,.036),Vector2(1.25,1.25),load(ROOT+"birthday-memories.png"),0,3);staff.name="FormerHappylandStaff"
 _face(board,Vector3(1.30,-.73,.04),Vector2(1.39,.22),_print("Unser Team / 1998",true))
 _face(board,Vector3(-.63,.88,.028),Vector2(2.5,.20),_print("DEIN TAG IM HAPPYLAND",false))
 var target:=StaticBody3D.new();target.set_meta("interaction","memory_wall");board.add_child(target)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4.40,2.0,.055);shape.shape=box;shape.position.z=.035;target.add_child(shape)
 # Two short picture lights are mechanically fastened to the wall board.
 for x in [-1.4,1.4]:
  w.tube(board,Vector3(x,1.05,-.01),Vector3(x,1.13,.18),.012,w.materials.metal)
  w.box(board,Vector3(x,1.13,.18),Vector3(.46,.06,.12),w.materials.metal)
  var light:=OmniLight3D.new();light.position=Vector3(x,.87,.28);light.light_color=Color("b9a276");light.light_energy=.36;light.omni_range=1.9;board.add_child(light)

func _image(parent: Node3D, pos: Vector3, size_value: Vector2, cell: int) -> MeshInstance3D:
 var image:=_face(parent,pos,size_value,load(ROOT+"birthday-memories.png"))
 var arrays:=image.mesh.surface_get_arrays(0);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var offset:=Vector2(cell%2,floori(cell/2.0))*.5
 for i in range(uv.size()): uv[i]=offset+Vector2.ONE*.006+uv[i]*.488
 arrays[Mesh.ARRAY_TEX_UV]=uv;var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);image.mesh=mesh;return image

func _face(parent: Node3D, pos: Vector3, size_value: Vector2, texture: Texture2D) -> MeshInstance3D:
 var face:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size_value;face.mesh=quad;face.position=pos;face.material_override=w.mat(Color.WHITE,texture,.96);parent.add_child(face);return face

func _print(value: String, handwritten: bool) -> ViewportTexture:
 var view:=SubViewport.new();view.size=Vector2i(768,96);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(view)
 var paper:=ColorRect.new();paper.size=view.size;paper.color=Color("bfae85");view.add_child(paper)
 var label:=Label.new();label.text=value;label.position=Vector2(17,0);label.size=Vector2(734,96);label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_font_override("font",load("res://assets/backstage-v270/Caveat.ttf" if handwritten else "res://assets/Oswald.ttf"));label.add_theme_font_size_override("font_size",66 if handwritten else 50);label.add_theme_color_override("font_color",Color("3f3a2e"));view.add_child(label);return view.get_texture()

func _monitor() -> void:
 var pc:=w.props.counter.get_node("ReceptionPC") as Node3D;pc.rotation.y=PI/2
 var screen:=pc.get_child(2) as Node3D
 # Find the front QuadMesh rather than relying on the bezel's child index.
 for mesh in pc.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh is QuadMesh: display=mesh;break
 assert(display!=null,"Reception CRT has no display")
 screen=display.get_parent()
 var idle:=SubViewport.new();idle.size=Vector2i(384,224);idle.disable_3d=true;idle.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(idle)
 var bg:=ColorRect.new();bg.color=Color("17251b");bg.size=idle.size;idle.add_child(bg)
 var label:=Label.new();label.text="HAPPYLAND\nSICHERHEIT\n\n[E] MONITOR";label.size=idle.size;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",26);label.add_theme_color_override("font_color",Color("9caf8c"));idle.add_child(label)
 standby=w.mat(Color.WHITE,idle.get_texture(),.6);standby.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;display.material_override=standby
 var target:=StaticBody3D.new();target.set_meta("interaction","reception_cctv");screen.add_child(target)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.43,.32,.24);shape.shape=box;shape.position=Vector3(0,0,-.065);target.add_child(shape)
 viewport=SubViewport.new();viewport.name="LiveSecurityCamera";viewport.size=Vector2i(640,360);viewport.world_3d=w.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.positional_shadow_atlas_size=512;add_child(viewport)
 camera=Camera3D.new();camera.near=.12;camera.far=48;camera.fov=78;camera.cull_mask=1;viewport.add_child(camera);camera.current=true
 glass=ShaderMaterial.new();glass.shader=load(ROOT+"cctv.gdshader")
 _select(0)

func _housings() -> void:
 for item in FEEDS:
  var mount:=Node3D.new();mount.position=item.p;add_child(mount);mount.look_at(item.at)
  w.box(mount,Vector3(0,0,.17),Vector3(.075,.08,.27),w.materials.metal)
  w.box(mount,Vector3(0,0,0),Vector3(.22,.18,.37),w.materials.cream)
  w.box(mount,Vector3(0,0,-.19),Vector3(.16,.12,.025),w.materials.dark)
  w.tube(mount,Vector3(0,0,-.21),Vector3(0,0,-.19),.042,w.materials.metal)
  for mesh in mount.find_children("*","MeshInstance3D",true,false): mesh.layers=2
  # Wall-bracket and cable fasten each housing to its nearest actual wall.
  var anchor: Vector3=item.p
  if item.label.begins_with("01"): anchor.x=-10.02
  elif item.label.begins_with("02"): anchor=Vector3(5.8,7.28,9.5)
  elif item.label.begins_with("03"): anchor.x=6.93
  elif item.label.begins_with("04"): anchor.x=-10.35
  elif item.label.begins_with("05"): anchor.y=3.53
  elif item.label.begins_with("06"): anchor.z=-25.5
  else: anchor.z=10.38
  w.tube(self,item.p,anchor,.014,w.materials.metal)
  w.box(self,anchor,Vector3(.12,.12,.06),w.materials.dark)

func _select(index: int) -> void:
 feed=clampi(index,0,FEEDS.size()-1);camera.position=FEEDS[feed].p;camera.look_at(FEEDS[feed].at)
 changes+=1

func open(index: int=0) -> void:
 opened=true;_select(index);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func close() -> void:
 opened=false;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED

func snapshot() -> Dictionary:
 return {"opened":opened,"feed":feed,"label":FEEDS[feed].label,"count":FEEDS.size(),"updates":viewport.render_target_update_mode,"changes":changes,"photos":photos.size(),"world_shared":viewport.world_3d==w.get_world_3d()}
