class_name VenueTouch
extends Node3D

var w: PlayWorld
var records: Array[Dictionary]=[]
var mark: StandardMaterial3D
var brands:=0
var bumps:=0
var cup: NightProp
var ticket: Node3D
var note: Label3D
var paper_amount:=0.
var printing:=false
var printed:=false
var printer_audio: AudioStreamPlayer3D
var cup_cooldown:=0.

func build(world: PlayWorld) -> void:
 w=world;name="HappylandTouchAndIdentity"
 mark=w.mat(Color("e2dcc0"),HappylandMark.texture(self),.95)
 mark.cull_mode=BaseMaterial3D.CULL_DISABLED
 _bin();_jacket();_cup();_branding()

func label(parent: Node3D,p: Vector3,s: Vector2,yaw: float=0.) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.name="HappylandSunMark";var quad:=QuadMesh.new();quad.size=s;mesh.mesh=quad;mesh.material_override=mark;mesh.position=p;mesh.rotation.y=yaw;parent.add_child(mesh);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;brands+=1;return mesh

func audio(parent: Node3D,file: String,volume: float) -> AudioStreamPlayer3D:
 var source:=AudioStreamPlayer3D.new();source.name="OrdinaryContactSound";source.stream=load(file);source.unit_size=1.6;source.max_distance=7;source.volume_db=volume;source.bus="NightAmbience" if AudioServer.get_bus_index("NightAmbience")>=0 else "Master";parent.add_child(source);return source

func contact(root: Node3D,pivot: Node3D,kind: String,source: AudioStreamPlayer3D) -> void:
 records.append({"root":root,"pivot":pivot,"rest":pivot.rotation,"kind":kind,"angle":0.,"speed":0.,"cooldown":0.,"audio":source})

func _bin() -> void:
 var bin: Node3D=w.props.reception_bin
 var lid:=bin.get_child(1) as MeshInstance3D
 if not lid:return
 var pivot:=Node3D.new();pivot.name="ContactBinLidHinge";pivot.position=Vector3(0,.55,-.22);bin.add_child(pivot);lid.reparent(pivot,true)
 var body:=StaticBody3D.new();body.name="SimpleBinCollision";bin.add_child(body);var collision:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.23;cylinder.height=.55;collision.shape=cylinder;collision.position.y=.275;body.add_child(collision);body.set_meta("touch_reaction",records.size())
 contact(bin,pivot,"bin",audio(bin,"res://assets/polish/impact-plastic.wav",-23))
 label(bin,Vector3(0,.31,.233),Vector2(.21,.084))

func _jacket() -> void:
 var jacket:=w.backstage.exit_root.find_child("ForgottenJacket",true,false) as Node3D
 if not jacket:return
 var area:=Area3D.new();area.name="JacketContactOnly";area.collision_layer=0;area.collision_mask=1;jacket.add_child(area)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.68,.69,.18);shape.shape=box;shape.position=Vector3(0,-.34,.12);area.add_child(shape)
 contact(jacket,jacket,"jacket",audio(jacket,"res://assets/polish/impact-cloth.wav",-26))
 var index:=records.size()-1
 area.body_entered.connect(func(body):if body is NightGuard and body.active and body.velocity.length()>.2:bump(index,body.velocity.length()))
 var patch:=label(jacket,Vector3.ZERO,Vector2(.11,.06))
 var stitch:=SurfaceTool.new();stitch.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in range(4):
  for col in range(8):
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
    var uv:=Vector2((col+corner.x)/8.,(row+corner.y)/4.)
    var x:=lerpf(.045,.155,uv.x);var y:=lerpf(-.16,-.22,uv.y)
    var v:=(-.03-y)/.64;var width:=.22+sin(v*PI)*.07;var u:=.5+x/(width*2.)
    stitch.set_uv(uv);stitch.add_vertex(Vector3(x,y,.032+.027*sin(u*TAU*5.)+v*.025))
 stitch.generate_normals();stitch.index();patch.mesh=stitch.commit()

func _cup() -> void:
 # One cheap convex rigid body, outside the cinema aisle and all door arcs.
 cup=NightProp.new();cup.name="RollingEmptyHappylandCup";cup.title="Leerer Pappbecher";cup.mass=.08;cup.position=Vector3(-5.65,.055,-32.0);cup.rotation.z=PI/2;add_child(cup)
 var rim:=StandardMaterial3D.new();rim.albedo_color=Color("c4baa0");rim.roughness=.96
 SurfaceDetails.vessel(cup,Vector3(0,-.075,0),.15,.051,.034,.003,rim,w.materials.dark,"OpenPaperCup")
 var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.051;cylinder.height=.15;shape.shape=cylinder;cup.add_child(shape)
 var physics:=PhysicsMaterial.new();physics.friction=.34;physics.bounce=.12;cup.physics_material_override=physics;cup.linear_damp=.12;cup.angular_damp=.18
 label(cup,Vector3(0,0,.045),Vector2(.072,.029))
 w.atmosphere.loose.append(cup);cup.suspend(true)

func _branding() -> void:
 # Reuse one deliberately faded mark on existing objects, never add clutter to routes.
 for node in w.find_children("AbandonedCinemaCup*","Node3D",true,false):label(node,Vector3(0,.078,.043),Vector2(.06,.024))
 var rail: Node3D=w.props.counter
 w.box(rail,Vector3(.465,.70,0),Vector3(.02,.17,.39),w.materials.wood)
 label(rail,Vector3(.477,.70,0),Vector2(.36,.144),PI/2)
 var tickets:=w.details.find_child("AdmissionWristbands",true,false) as Node3D
 if tickets:
  var stub:=w.box(tickets,Vector3(.035,.186,.03),Vector3(.14,.002,.07),w.materials.paper)
  var print_face:=label(stub,Vector3(0,.0013,0),Vector2(.128,.051));print_face.rotation.x=-PI/2
 # Physical brass tokens sit in a shallow existing counter tray.
 var tray:=Node3D.new();tray.name="HappylandArcadeTokens";tray.position=Vector3(.25,1.009,.64);rail.add_child(tray)
 for i in range(4):
  var token:=w.tube(tray,Vector3(i*.035-.05,.002,0),Vector3(i*.035-.05,.005,0),.023,w.materials.gold)
  var stamp:=label(token,Vector3(0,.002,0),Vector2(.036,.0144));stamp.rotation.x=-PI/2
 label(w.life.snack,Vector3(-1.25,.59,.60),Vector2(.31,.124))

func bump(index: int,speed: float) -> void:
 if index<0 or index>=records.size():return
 var record:=records[index]
 if record.cooldown>0:return
 record.cooldown=1.4;record.speed=clampf(speed*.30,.28,1.6);record.audio.play();bumps+=1

func tick(delta: float,active: bool) -> void:
 if active and is_instance_valid(cup):
  cup_cooldown=maxf(0.,cup_cooldown-delta)
  var guard: NightGuard=get_parent().get_parent().player
  var toward:=cup.global_position-guard.global_position;toward.y=0
  var speed:=Vector2(guard.velocity.x,guard.velocity.z).length()
  if guard.active and speed>.3 and toward.length()<.43 and absf(cup.global_position.y-guard.position.y)<.4 and cup_cooldown<=0 and not cup.held:
   cup_cooldown=.5;cup.sleeping=false;cup.apply_central_impulse(toward.normalized()*.035*minf(speed,4.5));cup.apply_torque_impulse(Vector3(.002,0,.002));cup.impact.volume_db=-28;cup.impact.play();bumps+=1
 for record in records:
  record.audio.stream_paused=not active
  if not active:continue
  record.cooldown=maxf(0.,record.cooldown-delta)
  var remaining:=minf(delta,.1)
  while remaining>0:
   var dt:=minf(.01,remaining);record.speed+=(-record.angle*42.-record.speed*4.4)*dt;record.angle+=record.speed*dt;remaining-=dt
  record.pivot.rotation=record.rest+Vector3(-absf(record.angle)*.6,0,record.angle*.12) if record.kind=="bin" else record.rest+Vector3(record.angle*.15,0,record.angle*.35)

func snapshot() -> Dictionary:
 return {"brands":brands,"reactions":records.size(),"bumps":bumps,"cup":is_instance_valid(cup)}
