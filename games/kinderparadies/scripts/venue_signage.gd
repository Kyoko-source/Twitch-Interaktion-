class_name VenueSignage
extends RefCounted

const ROOT:="res://assets/restoration-v350/"
const INDEX=preload("res://assets/restoration-v350/sign_index.gd")
static var textures: Dictionary={}
static var atlas: Image
const WORDS:={"GARDEROBE":"cloakroom","HAPPYLAND  /  AUF WIEDERSEHEN":"farewell","HEIZKREIS 03":"heater","KÜCHE  /  KINO":"annex","GEBURTSTAGE  /  SAAL":"hall","PERSONAL / HYGIENE":"hygiene","LETZTE VORSTELLUNG  18:00":"last_show","LÜFTUNG 03":"vent","HAPPYLAND / PERSONALGANG":"staff_hall"}

static func texture(id: String) -> Texture2D:
 if textures.has(id):return textures[id]
 var slot: int=INDEX.IDS.find(id)
 assert(slot>=0,"Unknown Happyland sign: "+id)
 if atlas==null:
  atlas=(load(ROOT+"happyland-signs.jpg") as Texture2D).get_image()
  if atlas.is_compressed():atlas.decompress()
 var image:=atlas.get_region(Rect2i((slot%4)*512,(slot/4)*256,512,256));image.generate_mipmaps()
 var result:=ImageTexture.create_from_image(image);result.set_meta("physical_sign",id);textures[id]=result
 return result

static func frame(w: PlayWorld,face: MeshInstance3D,size_value: Vector2,id: String) -> void:
 face.name="HappylandSign_"+id;face.set_meta("sign_design",id);face.set_meta("mounted_art",true)
 var paper: bool=id in INDEX.POSTERS
 var m:=face.material_override as StandardMaterial3D;m.albedo_color=Color.WHITE;m.roughness=.95 if paper else .52;m.metallic=0. if paper else .48
 m.uv1_triplanar=false;m.uv1_scale=Vector3.ONE;m.uv1_offset=Vector3.ZERO;m.texture_repeat=false
 if paper:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for y in range(10):
   for x in range(14):
    var points: Array[Vector3]=[];var uv: Array[Vector2]=[]
    for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
     var u: float=(x+corner.x)/14.;var v: float=(y+corner.y)/10.
     var curl: float=pow(absf(u-.5)*2.,8.)*.006+pow(v,9.)*.009*(.65+sin(u*24.)*.35)
     points.append(Vector3((u-.5)*size_value.x,(.5-v)*size_value.y,curl));uv.append(Vector2(u,v))
    for i in [0,2,1,1,2,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
  st.generate_normals();st.generate_tangents();face.mesh=st.commit();m.cull_mode=BaseMaterial3D.CULL_DISABLED
  for x in [-.45,.45]:
   var pin:=w.sphere(face,Vector3(x*size_value.x,.445*size_value.y,.008),.006,w.materials.rust if w.materials.has("rust") else w.materials.dark);pin.scale.z=.5
 else:
  var metal:=w.mat(Color("3a514b"),load("res://assets/paint.png"),.58,.72)
  w.box(face,Vector3(0,0,-.013),Vector3(size_value.x+.025,size_value.y+.025,.020),metal)
  for side in [-1,1]:
   w.box(face,Vector3(side*(size_value.x*.5+.004),0,.002),Vector3(.015,size_value.y+.025,.018),metal)
   w.box(face,Vector3(0,side*(size_value.y*.5+.004),.002),Vector3(size_value.x+.025,.015,.018),metal)
  var r:=minf(.012,minf(size_value.x,size_value.y)*.025)
  for x in [-.455,.455]:
   for y in [-.415,.415]:
    var p:=Vector3(x*size_value.x,y*size_value.y,.003)
    w.tube(face,p,p+Vector3(0,0,.006),r,metal)
    w.box(face,p+Vector3(0,0,.0065),Vector3(r*1.1,.002,.001),w.materials.dark)

static func plate(w: PlayWorld,parent: Node3D,words: String,p: Vector3,size_value: Vector2,yaw: float=0) -> Node3D:
 var id: String=WORDS.get(words,"")
 if id.is_empty():
  var root:=Node3D.new();root.position=p;root.rotation.y=yaw;parent.add_child(root)
  w.box(root,Vector3.ZERO,Vector3(size_value.x,size_value.y,.012),w.materials.metal)
  var letters:=TextMesh.new();letters.text=words;letters.font=load("res://assets/Oswald.ttf");letters.font_size=48;letters.pixel_size=size_value.y*.36/48.;letters.depth=.0002
  var number:=MeshInstance3D.new();number.mesh=letters;number.material_override=w.mat(Color("ded8c1"),null,.8);number.position=Vector3(0,-size_value.y*.13,.009);root.add_child(number)
  return root
 return w.artwork(parent,p,size_value,texture(id),yaw)
