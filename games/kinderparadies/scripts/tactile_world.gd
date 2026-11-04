class_name TactileWorld
extends Node3D

var w: PlayWorld
var levers: Dictionary={}
var contact: Dictionary={}
var pulses: Dictionary={}
var caps: Array[Dictionary]=[]
var key_socket: Node3D
var metal: Material
var dark: Material

func build(world: PlayWorld) -> void:
 w=world;name="CloseInteractionCraft"
 var material:=ShaderMaterial.new();material.shader=load("res://assets/lift-v391/lift_surface.gdshader");material.set_shader_parameter("tint",Color("929b8b"));material.set_shader_parameter("metalness",.79);material.set_shader_parameter("base_roughness",.39);metal=material
 dark=w.mat(Color("161c18"),null,.87)
 for index in range(2):
  var hinge: Node3D=w.passages.lanes[index].hinge
  for child in hinge.get_children():
   if child is MeshInstance3D and child.position.y>1.0 and child.position.y<1.4 and not child.get_meta("solid_visual",false):child.free()
  var id: String="red" if index else "green"
  for side in [-1,1]:
   var face:=Node3D.new();face.position=Vector3(1.25,1.25,side*.064);face.rotation.y=PI if side<0 else 0.;hinge.add_child(face)
   var lever:=_lever(face)
   if side==1:
    var grip:=Node3D.new();grip.name="HandleGripContact";grip.position=Vector3(-.13,0,.028);lever.add_child(grip);contact[id]=grip
   if not levers.has(id):levers[id]=[]
   levers[id].append(lever)
 _exit_lock();_party_button();_keypad()
 for id in w.mechanics.records:contact["mechanical:"+id]=w.mechanics.records[id].contact

func screw(root: Node3D,p: Vector3) -> void:
 w.tube(root,p,p+Vector3.BACK*.002,.006,metal)
 w.box(root,p+Vector3.BACK*.0024,Vector3(.007,.0012,.001),dark)

func _lever(root: Node3D) -> Node3D:
 w.box(root,Vector3(0,-.015,.01),Vector3(.075,.245,.018),metal)
 for y in [-.108,.082]:screw(root,Vector3(0,y,.022))
 w.tube(root,Vector3(0,0,.022),Vector3(0,0,.039),.026,metal)
 w.tube(root,Vector3(0,-.073,.022),Vector3(0,-.073,.029),.017,metal)
 w.box(root,Vector3(0,-.076,.030),Vector3(.003,.016,.001),dark)
 CelebrationTailoring.merge_joint(root)
 var pivot:=Node3D.new();pivot.name="ArticulatedDoorHandle";pivot.position=Vector3(0,0,.050);root.add_child(pivot)
 w.tube(pivot,Vector3.ZERO,Vector3(0,0,.028),.018,metal)
 w.tube(pivot,Vector3(0,0,.028),Vector3(-.20,0,.028),.016,metal)
 w.sphere(pivot,Vector3(-.20,0,.028),.016,metal)
 w.tube(pivot,Vector3(-.195,0,.028),Vector3(-.195,0,.009),.015,metal)
 CelebrationTailoring.merge_joint(pivot);return pivot

func _exit_lock() -> void:
 var leaf: Node3D=w.backstage.exit_leaf
 var root:=Node3D.new();root.name="EuroCylinderParkingLock";root.position=Vector3(1.47,1.13,.065);leaf.add_child(root)
 w.box(root,Vector3.ZERO,Vector3(.083,.195,.014),metal)
 for y in [-.077,.077]:screw(root,Vector3(0,y,.010))
 var cylinder:=Node3D.new();cylinder.name="WorkingKeyCylinder";cylinder.position.z=.016;root.add_child(cylinder)
 w.tube(cylinder,Vector3.ZERO,Vector3.BACK*.009,.018,metal)
 w.box(cylinder,Vector3(0,-.004,.010),Vector3(.004,.023,.001),dark)
 CelebrationTailoring.merge_joint(cylinder);CelebrationTailoring.merge_joint(root)
 # Keep the cylinder as a separate articulated node after static batching.
 key_socket=cylinder;contact["delivery_exit"]=root

func _party_button() -> void:
 var panel: Node3D=w.party.control
 var old:=panel.find_child("PartyButtonCap",true,false)
 if old:old.hide()
 var cap:=Node3D.new();cap.name="SpringLoadedPartyButton";cap.position=Vector3(0,-.01,.08);panel.add_child(cap)
 w.tube(panel,Vector3(0,-.01,.068),Vector3(0,-.01,.085),.096,metal)
 w.tube(cap,Vector3.ZERO,Vector3.BACK*.022,.074,w.party.led)
 CelebrationTailoring.merge_joint(cap);caps.append({"root":cap,"rest":cap.position,"id":"party_control"});contact["party_control"]=cap

func _keypad() -> void:
 var body: Node3D
 for candidate in w.archive.find_children("*","StaticBody3D",true,false):
  if candidate.get_meta("interaction","")=="archive_lock":body=candidate;break
 if not body:return
 var panel: Node3D=body.get_parent();contact["archive_lock"]=panel;contact["archive_door"]=panel
 for child in panel.get_children():
  if child is MeshInstance3D and child.position.z>.06:child.hide()
 for row in range(4):
  for col in range(3):
   var key:=Node3D.new();key.position=Vector3(-.08+col*.08,.045-row*.07,.065);panel.add_child(key)
   w.box(key,Vector3.ZERO,Vector3(.057,.046,.028),metal)
   var value: String=str(row*3+col+1) if row<3 else ["C","0","E"][col]
   var letters:=w.text(key,value,Vector3(0,-.006,.015),.021,Color("222b24"));letters.shaded=true
   caps.append({"root":key,"rest":key.position,"id":"archive_lock"})

func point_for(id: String,fallback: Vector3) -> Vector3:
 if contact.has(id) and is_instance_valid(contact[id]):return contact[id].global_position+contact[id].global_basis.z*.035
 return fallback

func touch(id: String) -> void:
 pulses[id]=0.

func tick(delta: float,active: bool) -> void:
 if not active:return
 for id in pulses.keys():
  pulses[id]+=delta
  var pulse:=sin(clampf(pulses[id]/.45,0.,1.)*PI)
  if levers.has(id):
   for lever in levers[id]:lever.rotation.z=pulse*.43
  if id=="delivery_exit" and is_instance_valid(key_socket):key_socket.rotation.z=pulse*PI*.45
  for cap in caps:
   if cap.id==id:cap.root.position=cap.rest-Vector3.BACK*pulse*.009
  if pulses[id]>=.45:pulses.erase(id)
