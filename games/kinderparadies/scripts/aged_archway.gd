class_name AgedArchway
extends Node3D

var solids: Array[MeshInstance3D]=[]
var w: PlayWorld

func part(p: Vector3,s: Vector3,m: Material,solid: bool=false) -> MeshInstance3D:
 var mesh:=w.box(self,p,s,m,solid)
 if solid:solids.append(mesh)
 return mesh

func build(world: PlayWorld) -> void:
 w=world;name="AgedTimberAnnexPortal";position=Vector3(-7.9,0,-12.2)
 var timber:=ShaderMaterial.new();timber.shader=load("res://assets/architecture-v355/aged-timber.gdshader")
 timber.set_shader_parameter("wood",load("res://assets/wood.png"));timber.set_shader_parameter("micro",w.atmosphere.micro_normal)
 var lintel:=timber.duplicate() as ShaderMaterial;lintel.set_shader_parameter("cross_grain",true)
 var dark:=w.mat(Color("30271d"),load("res://assets/wood.png"),.98)
 var iron:=w.mat(Color("4c3827"),load("res://assets/aged-plaster.png"),.93,.3)
 # A full-depth timber liner covers the bare plaster reveal. The facing
 # mouldings sit on both wall faces, outside the actual walking aperture.
 for side in [-1.,1.]:
  part(Vector3(side*1.55,1.36,0),Vector3(.24,2.72,.40),timber,true)
  part(Vector3(side*1.55,.15,.015),Vector3(.29,.28,.44),timber)
  for face in [-1.,1.]:
   part(Vector3(side*1.62,1.43,face*.235),Vector3(.19,2.33,.08),timber)
   for edge in [-1.,1.]:
    # The right lower bead has a genuinely missing, splintered section.
    var start: float=.34 if side<0 or edge<0 else .58
    part(Vector3(side*1.62+edge*.068,(start+2.61)*.5,face*.282),Vector3(.018,2.61-start,.025),timber)
   part(Vector3(side*1.61,2.76,face*.24),Vector3(.29,.29,.095),lintel)
   for y in [.39,2.51]:
    var head:=part(Vector3(side*1.62,y,face*.284),Vector3(.022,.022,.006),iron);head.name="RecessedRustyNail"
   # Inset splits stay on the wood surface; they do not float in the opening.
   for i in range(4):
    var split:=part(Vector3(side*1.62+.026*sin(i*2.1),.43+i*.49,face*.279),Vector3(.003,.14+i*.019,.002),dark);split.rotation.z=.012*sin(i)
 part(Vector3(0,2.76,0),Vector3(3.34,.22,.40),lintel,true)
 for face in [-1.,1.]:
  part(Vector3(0,2.80,face*.235),Vector3(3.03,.20,.08),lintel)
  for y in [2.735,2.865]:part(Vector3(0,y,face*.282),Vector3(3.02,.018,.025),lintel)
  # Visible joined end grain, a sagging top drip edge and dark mitre seams.
  part(Vector3(0,2.93,face*.23),Vector3(3.56,.06,.14),lintel)
  for x in [-1.48,1.48]:part(Vector3(x,2.80,face*.279),Vector3(.006,.18,.002),dark)
