class_name ServiceRoom
extends Node3D

func build(w: PlayWorld) -> void:
 name="ServerRoom"
 var steel:=w.mat(Color("3b4846"),load("res://assets/paint.png"),.8,.4)
 var floor_mat:=w.mat(Color("42483e"),load("res://assets/floor.png"),.94);floor_mat.uv1_triplanar=true
 w.box(self,Vector3(-13.3,-.138,-4.45),Vector3(6.2,.3,4.9),floor_mat,true)
 w.box(self,Vector3(-13.3,3.18,-4.45),Vector3(6.2,.2,4.9),w.materials.dark,true)
 for z in [-6.95,-1.95]: w.box(self,Vector3(-13.3,1.5,z),Vector3(6.3,3,.2),w.materials.wall,true).set_meta("architecture_wall",true)
 w.box(self,Vector3(-16.45,1.5,-4.45),Vector3(.2,3,5.2),w.materials.wall,true).set_meta("architecture_wall",true)
 for z in [-6.28,-4.52]: w.box(self,Vector3(-10.2,1.25,z),Vector3(.36,2.5,.09),w.materials.rust,true)
 w.box(self,Vector3(-10.2,2.55,-5.4),Vector3(.36,.13,1.94),w.materials.rust,true)
 # Door is parked against the inside wall, clear of the threshold in both directions.
 w.box(self,Vector3(-11.15,1.2,-6.68),Vector3(1.65,2.4,.08),steel,true)
 w.mounted_sign(self,"maintenance",Vector3(-10.015,2.94,-5.4),Vector2(1.15,.48),PI/2)
 for x in [-15.7,-14.35,-13.0]:
  var rack:=Node3D.new();rack.name="MountedServerRack";rack.position=Vector3(x,0,-2.65);rack.rotation.y=PI;add_child(rack)
  w.box(rack,Vector3(0,1.28,0),Vector3(1.05,2.56,.72),steel,true)
  for i in range(11):
   var y:=.2+i*.21
   w.box(rack,Vector3(0,y,.37),Vector3(.91,.16,.035),w.materials.dark)
   for col in range(7): w.box(rack,Vector3(-.37+col*.09,y,.394),Vector3(.045,.085,.01),steel)
   var glow:=w.mat(Color("63805b"),null,.6);glow.emission_enabled=true;glow.emission=Color("59784c");glow.emission_energy_multiplier=.7
   w.sphere(rack,Vector3(.36,y,.398),.015,glow)
  for side in [-1,1]: w.box(rack,Vector3(side*.56,1.28,.28),Vector3(.07,2.56,.1),w.materials.metal)
  for col in range(4):
   w.tube(self,Vector3(x-.3+col*.18,2.58,-2.65),Vector3(x-.3+col*.18,2.91,-2.65),.013,w.materials.dark)
 for z in [-6.72,-2.16]:
  w.box(self,Vector3(-13.4,2.92,z),Vector3(5.6,.05,.24),steel)
  for x in [-15.8,-13.4,-11.0]: w.tube(self,Vector3(x,3.07,z),Vector3(x,2.94,z),.014,steel)
 w.tube(self,Vector3(-15.7,2.95,-2.65),Vector3(-15.7,2.95,-6.72),.035,w.materials.dark)
 w.box(self,Vector3(-15.85,1.15,-6.73),Vector3(.8,1.3,.2),steel,true)
 for i in range(5): w.box(self,Vector3(-16.08+i*.12,1.3,-6.61),Vector3(.06,.16,.04),w.materials.dark)
 w.box(self,Vector3(-13.35,3.035,-4.4),Vector3(1.1,.06,.2),steel)
 var light:=w.lamp(Vector3(-13.35,2.89,-4.4),Color("819d88"),.65,6);light.shadow_enabled=true
 var glow:=w.mat(Color("929c85"),null,.6);glow.emission_enabled=true;glow.emission=Color("91a18c");glow.emission_energy_multiplier=.5
 w.box(self,Vector3(-13.35,2.99,-4.4),Vector3(.96,.025,.13),glow)
 w.mounted_sign(self,"maintenance",Vector3(-16.325,2.1,-4.7),Vector2(.9,.45),PI/2)
 for z in [-6.45,-4.7,-2.45]:
  w.box(self,Vector3(-16.31,.12,z),Vector3(.08,.2,1.45),w.materials.dark)
 for y in [.4,2.65]: w.tube(self,Vector3(-16.27,y,-6.7),Vector3(-16.27,y,-2.2),.022,w.materials.rust)
 for i in range(12): w.box(self,Vector3(-16.27,1.7+i*.055,-6.0),Vector3(.09,.023,.65),steel)
 for i in range(4):
  w.tube(self,Vector3(-15.9+i*.11,.04,-3.25),Vector3(-15.9+i*.11,.04,-6.55),.012,w.materials.dark)
 for x in [-15.6,-14.8]: w.box(self,Vector3(x,.17,-6.25),Vector3(.55,.34,.55),w.materials.wood,true)
 var fan:=AudioStreamPlayer3D.new();fan.name="ServerVentilation";fan.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
 var stream: AudioStreamWAV=load("res://assets/fan.wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);fan.stream=stream;fan.position=Vector3(-14.3,1.6,-2.65);fan.unit_size=1.4;fan.max_distance=7;fan.volume_db=-28;fan.bus="Interior" if w.native_art else "Master";add_child(fan)
 set_process(true)

func _process(_delta: float) -> void:
 var game:=get_parent().get_parent()
 var active: bool=game.get("phase")=="play"
 var fan: AudioStreamPlayer3D=get_node("ServerVentilation")
 fan.stream_paused=not active
 if active and not fan.playing: fan.play()

func safe_pose(p: Vector3) -> bool:
 return p.x> -16.25 and p.x< -10.0 and p.z> -6.8 and p.z< -2.1 and p.y>-.2 and p.y<2.8
