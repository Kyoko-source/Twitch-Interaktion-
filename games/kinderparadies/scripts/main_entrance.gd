class_name MainEntrance
extends RefCounted

const DOOR_Z:=-5.60
const OUTSIDE_Z:=-6.65

static func build(b: Node3D) -> void:
 var w: PlayWorld=b.w
 b.exit_root=Node3D.new();b.exit_root.name="OldHappylandMainEntrance";b.exit_root.position=Vector3(-10.2,0,9.4);b.exit_root.rotation.y=PI/2;b.add_child(b.exit_root)
 var root: Node3D=b.exit_root
 var plaster:=w.materials.wall.duplicate() as StandardMaterial3D;plaster.albedo_color=Color("aaa990")
 var floor:=w.box(root,Vector3(0,-.14,-2.85),Vector3(2.5,.3,5.8),w.materials.dark,true);floor.set_meta("foot_surface","concrete")
 for side in [-1,1]:b.wall(root,Vector3(side*1.25,1.55,-2.85),Vector3(.16,3.1,5.8),plaster)
 w.box(root,Vector3(0,3.12,-2.85),Vector3(2.65,.16,5.8),w.materials.dark,true)
 # The hall is an open arch. The actual external door is at the FAR end.
 for x in [-.87,.87]:w.box(root,Vector3(x,1.34,.08),Vector3(.12,2.68,.30),w.materials.wood,true)
 w.box(root,Vector3(0,2.72,.08),Vector3(1.86,.12,.30),w.materials.wood,true)
 var steel: Material=w.revamp.paint(Color("49574f"),.72,.47) if w.revamp else w.materials.metal
 # Side lights, door transom and mullions are all anchored to real walls.
 for side in [-1,1]:
  w.box(root,Vector3(side*1.05,1.5,DOOR_Z),Vector3(.28,3.0,.10),steel,true)
  w.box(root,Vector3(side*.83,1.5,DOOR_Z),Vector3(.075,3.0,.10),steel,true)
 w.box(root,Vector3(0,2.88,DOOR_Z),Vector3(2.24,.48,.10),steel,true)
 b.exit_leaf=Node3D.new();b.exit_leaf.name="MainEntranceDoorLeaf";b.exit_leaf.position=Vector3(-.80,0,DOOR_Z);root.add_child(b.exit_leaf)
 var leaf: Node3D=b.exit_leaf
 for x in [.035,1.565]:w.box(leaf,Vector3(x,1.32,0),Vector3(.07,2.64,.09),steel)
 for y in [.055,1.0,2.60]:w.box(leaf,Vector3(.80,y,0),Vector3(1.60,.09,.09),steel)
 var glass:=ShaderMaterial.new();glass.shader=load("res://assets/atmosphere-v320/glazing.gdshader")
 for bounds in [Vector2(.5275,.855),Vector2(1.8,1.51)]:
  var pane:=MeshInstance3D.new();pane.name="WiredEntranceGlass";var mesh:=QuadMesh.new();mesh.size=Vector2(1.46,bounds.y);pane.mesh=mesh;pane.position=Vector3(.8,bounds.x,0);pane.material_override=glass;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;leaf.add_child(pane)
 var body: StaticBody3D=b.solid(leaf,Vector3(.8,1.32,0),Vector3(1.6,2.64,.09),"EntranceGlassDoorSolid");body.set_meta("interaction","delivery_exit");body.set_meta("acoustic_barrier",true);b.exit_collider=body.get_child(0)
 for face in [-1,1]:
  w.tube(leaf,Vector3(.29,1.07,face*.06),Vector3(.29,1.07,face*.13),.019,w.materials.metal)
  w.tube(leaf,Vector3(1.31,1.07,face*.06),Vector3(1.31,1.07,face*.13),.019,w.materials.metal)
  w.tube(leaf,Vector3(.29,1.07,face*.13),Vector3(1.31,1.07,face*.13),.026,w.materials.metal)
 for y in [.28,1.30,2.38]:
  w.tube(leaf,Vector3(-.025,y-.06,.01),Vector3(-.025,y+.06,.01),.024,w.materials.metal)
 w.box(leaf,Vector3(.80,.19,.058),Vector3(1.43,.25,.019),w.materials.metal)
 w.box(leaf,Vector3(.40,2.51,.074),Vector3(.36,.07,.11),w.materials.metal)
 w.tube(root,Vector3(-.48,2.63,DOOR_Z+.12),Vector3(-.08,2.58,DOOR_Z+.12),.014,w.materials.metal)
 b.exit_sign=b.print_board(root,"exit",Vector3(0,3.18,.25),Vector2(1.45,.60))
 # Only the wall finish changes in false_exit. The entrance remains real.
 b.clean=Node3D.new();b.clean.name="ImpossibleCleanCorridor";root.add_child(b.clean)
 b.ruined=Node3D.new();b.ruined.name="DecayedCorridor";root.add_child(b.ruined)
 for group_node in [b.clean,b.ruined]:
  var bright: bool=group_node==b.clean
  var upper:=w.mat(Color("ded9c0") if bright else Color("8a8c77"),null if bright else load("res://assets/aged-plaster.png"),.90)
  var lower:=w.mat(Color("6aaca0") if bright else Color("3a574e"),load("res://assets/paint.png"),.75)
  for side in [-1,1]:
   w.box(group_node,Vector3(side*1.16,2.05,-2.80),Vector3(.025,1.72,5.42),upper)
   w.box(group_node,Vector3(side*1.14,.58,-2.80),Vector3(.03,1.12,5.42),lower)
   w.box(group_node,Vector3(side*1.10,1.16,-2.80),Vector3(.035,.055,5.42),w.materials.wood)
 b.clean_light=b.fixture(b.clean,Vector3(0,2.98,-2.6),Color("fff0d0"),1.8,6)
 b.old_light=b.fixture(b.ruined,Vector3(0,2.98,-2.6),Color("bad1b8"),.58,5.3);b.clean.hide()
 b.door_audio=AudioStreamPlayer3D.new();b.door_audio.name="EntranceDoorHinge";b.door_audio.stream=load("res://assets/door.ogg");b.door_audio.position=root.to_global(Vector3(0,1.2,DOOR_Z));b.door_audio.unit_size=2;b.door_audio.volume_db=-17;b.door_audio.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;b.add_child(b.door_audio)
 # Connected exterior landing. The player can physically step beyond the glass.
 var pavement:=w.box(root,Vector3(0,-.14,-9.10),Vector3(4.0,.30,6.7),w.materials.dark,true);pavement.set_meta("foot_surface","concrete")
 w.box(root,Vector3(0,3.06,-6.20),Vector3(2.65,.15,1.42),steel)
 for x in [-1.08,1.08]:w.tube(root,Vector3(x,2.60,DOOR_Z-.05),Vector3(x,2.98,-6.72),.024,w.materials.metal)
 for x in [-1.65,1.65]:
  w.tube(root,Vector3(x,.03,-6.55),Vector3(x,.82,-6.55),.06,w.materials.metal)
  w.tube(root,Vector3(x,.58,-6.55),Vector3(x,.65,-6.55),.064,w.materials.gold)
 w.box(root,Vector3(0,2.96,-6.25),Vector3(.65,.026,.25),w.materials.cream)
