class_name Pennant
extends RefCounted

# 4.11.0 bunting: a triangular fabric pennant folded over its string, gently
# bellied like cloth that has hung in still air for years, faded to pastel,
# lit through from behind. Replaces the flat coloured squares of older builds.
const FADED: Array[Color]=[Color("c98e95"),Color("d8c27e"),Color("86b3ad"),Color("9fb2cf"),Color("c7a3c4")]
static var mesh: ArrayMesh
static var hem: BoxMesh
static var cloths: Dictionary={}

static func _cloth(color: Color) -> StandardMaterial3D:
 var key:=color.to_html()
 if cloths.has(key):return cloths[key]
 var m:=StandardMaterial3D.new();m.resource_name="PennantCloth";m.albedo_color=color;m.roughness=.92;m.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.normal_enabled=true;m.normal_texture=load("res://assets/pbr/fabric_pattern_07/normal.jpg");m.normal_scale=.6;m.uv1_scale=Vector3(3,3,1)
 m.backlight_enabled=true;m.backlight=color.darkened(.35)
 cloths[key]=m;return m

# Unit pennant: top edge from x=-0.5 to 0.5 at y=0, tip at y=-1, belly along +z.
static func _mesh() -> ArrayMesh:
 if mesh:return mesh
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows:=6;var grid: Array=[]
 for r in range(rows+1):
  var v:=float(r)/rows;var row: Array=[];var cols:=rows-r
  for c in range(cols+1):
   var half:=.5*(1.-v);var u:=0. if cols==0 else float(c)/cols
   var x:=lerpf(-half,half,u);var y:=-v
   var z:=.06*sin(PI*u)*(1.-v)*(1.-v)+.025*sin(x*7.+v*3.)*v
   row.append([Vector3(x,y,z),Vector2(x+.5,v)])
  grid.append(row)
 for r in range(rows):
  for c in range(rows-r):
   var a: Array=grid[r][c];var b: Array=grid[r][c+1];var d: Array=grid[r+1][c]
   for p in [a,b,d]:st.set_uv(p[1]);st.add_vertex(p[0])
   if c<rows-r-1:
    var e: Array=grid[r+1][c+1]
    for p in [b,e,d]:st.set_uv(p[1]);st.add_vertex(p[0])
 st.generate_normals();mesh=st.commit();return mesh

# top: centre of the top edge on the string; along: the string's direction.
static func build(parent: Node3D,top: Vector3,width: float,height: float,index: int,along: Vector3=Vector3.RIGHT,sway: float=0.) -> Node3D:
 if not hem:hem=BoxMesh.new();hem.size=Vector3(1,1,1)
 var color: Color=FADED[index%FADED.size()]
 var root:=Node3D.new();root.name="FabricPennant";parent.add_child(root);root.position=top
 var x:=along.normalized();var z:=x.cross(Vector3.UP).normalized()
 root.basis=Basis(x,Vector3.UP,z)*Basis(Vector3.RIGHT,sway)
 var flag:=MeshInstance3D.new();flag.mesh=_mesh();flag.material_override=_cloth(color);flag.scale=Vector3(width,height,width);root.add_child(flag)
 var fold:=MeshInstance3D.new();fold.mesh=hem;fold.material_override=_cloth(color.darkened(.12));fold.scale=Vector3(width*1.02,.035,.016);fold.position=Vector3(0,-.012,0);root.add_child(fold)
 return root
