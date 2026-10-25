class_name LostArchive
extends Node3D

const ENTRY:=Vector3(-10.2,0,-9.9)
const PAPERS:={"opening":Vector3(10.2,.853,-6.05),"missing":Vector3(-.2,.558,-19.9),"coverup":Vector3(-12.94,.991,-18.84)}
var w: PlayWorld
var progress: ArchiveState
var stage:=1
var leaf: Node3D
var items: Dictionary={}
var creak: AudioStreamPlayer3D
var target_angle:=0.0
var finale: ArchiveFinale

func build(world: PlayWorld) -> void:
 w=world;name="LostArchive"
 _entrance();_room()
 finale=ArchiveFinale.new();add_child(finale);finale.build(w)

func _entrance() -> void:
 var frame:=Node3D.new();frame.position=ENTRY;add_child(frame)
 var rust:=w.mat(Color.WHITE,load("res://assets/story/rust-door.png"),.94,.28)
 rust.normal_enabled=true;rust.normal_texture=load("res://assets/story/rust-normal.png");rust.normal_scale=.75
 rust.roughness_texture=load("res://assets/story/rust-roughness.png")
 var frame_rust:=rust.duplicate() as StandardMaterial3D;frame_rust.albedo_texture=load("res://assets/story/rust-metal.png")
 for z in [-.81,.81]: w.box(frame,Vector3(0,1.26,z),Vector3(.28,2.52,.12),frame_rust,true)
 w.box(frame,Vector3(0,2.53,0),Vector3(.28,.12,1.74),frame_rust,true)
 w.box(frame,Vector3(0,.016,0),Vector3(.40,.025,1.50),w.materials.metal)
 leaf=Node3D.new();leaf.name="CorrodedDoorLeaf";leaf.position=Vector3(.015,0,-.75);frame.add_child(leaf)
 w.box(leaf,Vector3(0,1.235,.75),Vector3(.09,2.43,1.48),frame_rust)
 var front:=MeshInstance3D.new();var face:=QuadMesh.new();face.size=Vector2(1.48,2.43);front.mesh=face;front.material_override=rust;front.position=Vector3(.047,1.235,.75);front.rotation.y=PI/2;leaf.add_child(front)
 var body:=StaticBody3D.new();body.set_meta("interaction","archive_door");leaf.add_child(body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(.09,2.43,1.48);shape.shape=bounds;shape.position=Vector3(0,1.235,.75);body.add_child(shape)
 for y in [.32,1.23,2.13]:
  w.tube(frame,Vector3(.065,y-.07,-.76),Vector3(.065,y+.07,-.76),.034,rust)
  w.sphere(frame,Vector3(.07,y,-.77),.018,w.materials.metal)
 w.box(leaf,Vector3(.058,1.12,1.31),Vector3(.025,.34,.13),w.materials.metal)
 w.tube(leaf,Vector3(.08,1.11,1.25),Vector3(.15,1.11,1.25),.025,w.materials.rust)
 w.tube(leaf,Vector3(.15,1.11,1.25),Vector3(.15,1.11,1.04),.025,w.materials.rust)
 # The note is nailed onto the actual leaf; collecting it removes its hitbox too.
 var nail:=w.sphere(leaf,Vector3(.076,1.79,.75),.012,w.materials.rust);nail.scale.x=.4
 var keypad:=Node3D.new();keypad.position=ENTRY+Vector3(.23,1.27,1.03);keypad.rotation.y=PI/2;add_child(keypad)
 w.box(keypad,Vector3.ZERO,Vector3(.29,.48,.09),w.materials.rust)
 w.box(keypad,Vector3(0,.15,.051),Vector3(.23,.09,.015),w.mat(Color("10221b"),null,.45))
 for row in range(4):
  for col in range(3): w.box(keypad,Vector3(-.08+col*.08,.045-row*.07,.065),Vector3(.058,.047,.035),w.materials.metal)
 var key_body:=StaticBody3D.new();key_body.set_meta("interaction","archive_lock");keypad.add_child(key_body)
 var key_shape:=CollisionShape3D.new();var key_bounds:=BoxShape3D.new();key_bounds.size=Vector3(.29,.48,.12);key_shape.shape=key_bounds;key_body.add_child(key_shape)
 w.tube(self,ENTRY+Vector3(.15,1.54,1.03),ENTRY+Vector3(.15,2.65,1.03),.012,w.materials.dark)
 w.tube(self,ENTRY+Vector3(.15,2.65,1.03),ENTRY+Vector3(.15,2.65,.72),.012,w.materials.dark)
 creak=AudioStreamPlayer3D.new();creak.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;creak.stream=load("res://assets/ambience-v193/metal-door.wav");creak.position=ENTRY+Vector3(0,1,0);creak.volume_db=-13;creak.max_distance=10;add_child(creak)

func _room() -> void:
 var floor_mat:=w.mat(Color("53544a"),load("res://assets/floor.png"),.91)
 w.box(self,Vector3(-13.18,-.136,-9.9),Vector3(6.25,.3,4.35),floor_mat,true)
 # Every wall and ceiling meets the floor; the opening into the hall stays clear.
 for wall in [{"p":Vector3(-16.28,1.65,-9.9),"s":Vector3(.18,3.3,4.4)},{"p":Vector3(-13.18,1.65,-12.0),"s":Vector3(6.2,3.3,.18)},{"p":Vector3(-13.18,1.65,-7.8),"s":Vector3(6.2,3.3,.18)}]:
  var mesh:=w.box(self,wall.p,wall.s,w.materials.wall,true);mesh.set_meta("architecture_wall",true)
 w.box(self,Vector3(-13.18,3.35,-9.9),Vector3(6.25,.16,4.4),w.materials.dark,true)
 var wood:=w.mat(Color("5c4736"),load("res://assets/wood.png"),.9)
 w.box(self,Vector3(-15.15,.77,-9.9),Vector3(1.5,.09,2.7),wood,true)
 for x in [-15.75,-14.55]:
  for z in [-11.05,-8.75]: w.box(self,Vector3(x,.38,z),Vector3(.09,.76,.09),w.materials.metal,true)
 for i in range(9):
  var folder:=w.box(self,Vector3(-15.28+(i%2)*.42,.834+(i/3)*.021,-10.8+(i%3)*.48),Vector3(.31,.018,.39),w.materials.paper if i%2 else wood);folder.rotation.y=i*.13
 var record:=0
 for z in [-11.1,-10.3,-9.5,-8.7]:
  record+=1
  var board:=Node3D.new();board.position=Vector3(-16.16,1.85,z);board.rotation.y=PI/2;add_child(board)
  w.box(board,Vector3(0,0,-.012),Vector3(.61,.85,.035),wood)
  var print_mesh:=MeshInstance3D.new();var page:=QuadMesh.new();page.size=Vector2(.53,.75);print_mesh.mesh=page;print_mesh.position.z=.012
  print_mesh.material_override=w.mat(Color("b4ac91"),load("res://assets/story/record-"+str(record)+".png"),.99);board.add_child(print_mesh)
  w.tube(board,Vector3(-.21,.31,.023),Vector3(.21,.31,.023),.009,w.materials.rust)
 # Empty storage shelves and archive boxes have supports, lids and shelf boards.
 for x in [-13.7,-12.3]:
  for side in [-.55,.55]: w.box(self,Vector3(x+side,1.1,-11.75),Vector3(.045,2.2,.42),w.materials.metal,true)
  for y in [.12,.68,1.24,1.8,2.22]:
   w.box(self,Vector3(x,y,-11.75),Vector3(1.15,.035,.47),wood)
   if y<2:
    for k in [-.28,.28]:
     w.box(self,Vector3(x+k,y+.19,-11.75),Vector3(.48,.34,.36),wood)
     w.box(self,Vector3(x+k,y+.365,-11.75),Vector3(.49,.025,.37),w.materials.paper)
 var lamp:=w.lamp(Vector3(-13.9,2.91,-9.9),Color("c4b078"),.27,5);lamp.shadow_enabled=true
 w.box(self,Vector3(-13.9,3.25,-9.9),Vector3(.25,.04,.25),w.materials.dark)
 w.tube(self,Vector3(-13.9,3.25,-9.9),Vector3(-13.9,3.0,-9.9),.018,w.materials.metal)
 w.sphere(self,Vector3(-13.9,2.97,-9.9),.075,w.materials.cream)

func sync(value: ArchiveState, round_stage: int) -> void:
 progress=value;stage=round_stage;finale.sync(value)
 for item in items.values(): remove_item(item)
 items.clear()
 if stage==14 and "patrol_hint" not in progress.collected:
  _paper("patrol_hint",self,Vector3(-8,.038,17.95),Vector2(.52,.69),Vector3(-PI/2,.06,0))
 if "note" not in progress.collected: _paper("note",leaf,Vector3(.067,1.63,.75),Vector2(.26,.35),Vector3(0,PI/2,.025))
 for id in ArchiveState.PAPERS:
  if int(ArchiveState.document(id).stage)!=stage or id in progress.collected: continue
  var point: Vector3=PAPERS[id] if PAPERS.has(id) else CrawlTubes.route(8.7)
  if id in ["missing","coverup"]: point+=ServiceAnnex.OFFSET
  if id=="closure": point.y=.322
  _paper(id,self,point,Vector2(.24,.19) if id=="coverup" else Vector2(.34,.43),Vector3(-PI/2,.13,0))
 if progress.unlocked and "casefile" not in progress.collected: _paper("casefile",self,Vector3(-15.15,.819,-9.05),Vector2(.34,.43),Vector3(-PI/2,-.12,0))
 target_angle=-1.76 if progress.unlocked and not playback_locked() else 0.0;leaf.rotation.y=target_angle

func _paper(id: String, parent: Node3D, pos: Vector3, size: Vector2, turn: Vector3) -> void:
 var root:=Node3D.new();root.name="Story_"+id;root.position=pos;root.rotation=turn;parent.add_child(root)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(16):
  for col in range(12):
   for q in [Vector2(col,row),Vector2(col+1,row),Vector2(col,row+1),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
    var u: float=q.x/12;var v: float=q.y/16;var bend: float=pow(absf(u-.5)*2,5)*.009+sin(v*PI)*.0015+absf(u-.5)*.004+sin(v*9)*.001
    tool.set_uv(Vector2(u,v));tool.add_vertex(Vector3((u-.5)*size.x,(.5-v)*size.y,bend))
 tool.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit()
 var texture: Texture2D=_hint_front(root) if id=="patrol_hint" else load("res://assets/story/"+id+".png")
 var material:=w.mat(Color.WHITE,texture,.99);material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.5;mesh.material_override=material;root.add_child(mesh)
 var body:=StaticBody3D.new();body.collision_layer=4;body.collision_mask=0;body.set_meta("interaction","paper:"+id);root.add_child(body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(size.x,size.y,.018);collision.shape=shape;body.add_child(collision);items[id]=root

func _hint_front(parent: Node3D) -> Texture2D:
 # Render real typeset text onto the aged sheet, including the world pickup.
 var page:=SubViewport.new();page.name="FinalPatrolNewspaper";page.size=Vector2i(600,800);page.disable_3d=true;page.render_target_update_mode=SubViewport.UPDATE_ONCE;parent.add_child(page)
 var background:=TextureRect.new();background.texture=load("res://assets/story/paper.png");background.size=Vector2(600,800);background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;page.add_child(background)
 var column:=VBoxContainer.new();column.position=Vector2(42,40);column.size.x=516;column.add_theme_constant_override("separation",20);page.add_child(column)
 for entry in [["HAPPYLAND NACHRICHTEN",31],["SONDERAUSGABE · NACHTSCHICHT 13",16],["Du bist wieder hier.",42],[ArchiveState.document("patrol_hint").body,27]]:
  var line:=Label.new();line.text=entry[0];line.add_theme_font_size_override("font_size",entry[1]);line.add_theme_color_override("font_color",Color("29261e"));line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(line)
 var archive_photo:=AtlasTexture.new();archive_photo.atlas=load("res://assets/story/archive-photos-v21.png");var source_size:=archive_photo.atlas.get_size();archive_photo.region=Rect2(source_size*.5,source_size*.5)
 var photo:=TextureRect.new();photo.texture=archive_photo;photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;photo.custom_minimum_size=Vector2(516,240);photo.modulate=Color("aaa18b");column.add_child(photo)
 return page.get_texture()

func remove_item(item: Node3D) -> void:
 for collider in item.find_children("*","StaticBody3D",true,false): collider.collision_layer=0
 item.hide();item.queue_free()

func take(id: String) -> void:
 if items.has(id): remove_item(items[id]);items.erase(id)

func open() -> void:
 if playback_locked(): return
 target_angle=-1.76;creak.play()
 if "casefile" not in progress.collected and not items.has("casefile"): _paper("casefile",self,Vector3(-15.15,.819,-9.05),Vector2(.34,.43),Vector3(-PI/2,-.12,0))

func playback_locked() -> bool:
 return progress!=null and progress.unlocked and progress.ending=="recording"

func hold_for_recording() -> void:
 if not playback_locked(): return
 # Shut the real leaf and its collider together; no invisible exit barrier.
 target_angle=0.0;leaf.rotation.y=0.0;creak.play()

func tick(delta: float, active: bool) -> void:
 finale.tick(delta,active)
 if playback_locked(): target_angle=0.0
 if creak.stream_paused==active: creak.stream_paused=not active
 if active: leaf.rotation.y=move_toward(leaf.rotation.y,target_angle,delta*.92)

func safe_pose(p: Vector3) -> bool:
 return p.x> -16.1 and p.x< -10 and p.z> -11.8 and p.z< -8 and p.y>-.1 and p.y<2.8 and progress!=null and progress.unlocked

func snapshot() -> Dictionary:
 var visible: Array[Dictionary]=[]
 for id in items:
  if is_instance_valid(items[id]) and items[id].visible:
   var p: Vector3=items[id].global_position;visible.append({"id":id,"position":[p.x,p.y,p.z]})
 return {"stage":stage,"spawned":visible,"angle":leaf.rotation.y,"target_angle":target_angle,"recording_locked":playback_locked(),"unlocked":progress.unlocked,"collected":progress.collected,"finale":finale.snapshot()}
