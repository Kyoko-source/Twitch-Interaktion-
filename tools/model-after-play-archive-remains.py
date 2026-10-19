"""Original adult male skeletal remains, in metres, authored for the archive."""
from pathlib import Path

# Share the project's mesh/boolean/vertex-pigment helpers, without regenerating
# its existing creatures or changing any previously supplied reference assets.
source=Path(__file__).with_name('model-after-play-nightmares.py')
exec(compile(source.read_text(encoding='utf-8').split('\nreset()\nivory=')[0],str(source),'exec'))
OUT=source.parents[1]/'games/kinderparadies/assets/finale'
OUT.mkdir(exist_ok=True)
reset()
bone=mat('Ancient human bone',(.50,.45,.32),.96)
dark=mat('Hollow cranial recess',(.024,.021,.015),.99)

def long_bone(name,a,b,r):
 a,b=Vector(a),Vector(b);d=b-a
 strand(name,[a,a+d*.10,a+d*.35,a+d*.75,a+d*.93,b],[r*1.5,r*1.1,r*.73,r*.67,r*1.3,r*1.5],bone,16)
 for p in [a,b]:egg('Articular condyle',p,(r*1.55,r*1.5,r*1.2),bone,16)

# The body lies on its back: skull cavities and the rib cage face the ceiling.
skull=egg('Adult male cranium',(0,-.78,.19),(.091,.119,.097),bone,40)
for s in [-1,1]:
 cut(skull,egg('Orbital excavation',(s*.039,-.827,.270),(.032,.041,.040),dark))
 egg('Shadow deep inside the orbit',(s*.036,-.815,.237),(.023,.026,.014),dark)
 strand('Heavy supraorbital ridge',[(s*.014,-.866,.281),(s*.036,-.871,.285),(s*.068,-.842,.266)],[.009,.014,.007],bone)
 strand('Zygomatic arch',[(s*.079,-.795,.23),(s*.089,-.85,.23),(s*.060,-.900,.225)],[.009,.011,.007],bone)
cut(skull,egg('Open nasal aperture',(0,-.879,.269),(.015,.029,.035),dark))
strand('Nasal bridge',[(0,-.846,.28),(0,-.863,.285),(0,-.877,.268)],[.009,.008,.005],bone)
strand('Mandible',[(-.075,-.814,.18),(-.067,-.877,.18),(-.035,-.921,.198),(0,-.932,.20),(.035,-.921,.198),(.067,-.877,.18),(.075,-.814,.18)],[.012,.013,.012,.013,.012,.013,.012],bone,16)
for side in [-1,1]:
 for i in range(7):
  a=.12+i*.19
  x=side*math.sin(a)*.050;y=-.888-math.cos(a)*.022
  egg('Individual upper tooth',(x,y,.238),(.006,.008,.011),bone,12)
  egg('Individual lower tooth',(x,y-.011,.216),(.005,.007,.010),bone,12)
# Supine facial anatomy: the chin faces the chest, the vault faces away.
for o in list(bpy.data.objects):
 if o.type!='MESH':continue
 inv=o.matrix_world.inverted()
 for v in o.data.vertices:
  p=o.matrix_world@v.co;p.y=-1.56-p.y;v.co=inv@p
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
for i in range(21):
 y=-.62+i*.031
 egg('Vertebral body',(0,y,.105),(.022,.012,.015),bone,16)
 for s in [-1,1]:strand('Vertebral process',[(0,y,.10),(s*.034,y+.007,.085)],[.009,.004],bone,8)
for i in range(9):
 y=-.46+i*.042;width=.18-i*.004
 for s in [-1,1]:
  pts=[]
  for k in range(22):
   t=k/21;theta=math.pi*(1-t)
   pts.append((s*math.sin(theta)*width,y+math.sin(theta)*.024,.14+math.cos(theta)*(.103-i*.003)))
  strand('Curved rib',pts,[.0075-i*.00013]*len(pts),bone,10)
long_bone('Sternum',(0,-.45,.253),(0,-.17,.225),.012)
for s in [-1,1]:
 strand('Clavicle',[(0,-.49,.235),(s*.10,-.51,.22),(s*.20,-.46,.16)],[.011,.014,.012],bone)
 wing=egg('Pelvic ilium',(s*.072,.045,.116),(.073,.090,.044),bone,24)
 cut(wing,egg('Obturator opening',(s*.066,.074,.136),(.032,.043,.06),dark))
 strand('Pubic arch',[(s*.1,.035,.11),(s*.068,.132,.11),(0,.149,.12)],[.014,.014,.011],bone)
 long_bone('Femur',(s*.104,.151,.10),(s*.12,.54,.087),.020)
 egg('Patella',(s*.12,.55,.116),(.023,.028,.017),bone,16)
 long_bone('Tibia',(s*.12,.58,.075),(s*.11,.966,.060),.014)
 long_bone('Fibula',(s*.153,.58,.075),(s*.142,.965,.059),.008)
 long_bone('Humerus',(s*.215,-.45,.145),(s*.31,-.20,.08),.016)
 long_bone('Radius',(s*.31,-.17,.082),(s*.38,.09,.082),.011)
 long_bone('Ulna',(s*.329,-.18,.072),(s*.399,.09,.075),.009)
 for k in range(5):
  x=s*(.352+k*.012);length=.080-abs(k-2)*.012
  long_bone('Metacarpal',(x,.10,.076),(x+s*.013,.15,.073),.005)
  for joint in range(3):
   a=(x+s*(.013+joint*.006),.15+joint*length/3,.073-joint*.008)
   b=(x+s*(.019+joint*.006),.15+(joint+1)*length/3,.065-joint*.008)
   long_bone('Finger phalanx',a,b,.0038-joint*.0005)
 for k in range(5):
  x=s*(.084+k*.012)
  long_bone('Metatarsal',(x,.968,.058),(x,1.054,.052),.005)
  long_bone('Toe',(x,1.054,.052),(x,1.091-abs(k-1)*.006,.046),.004)
 for name,p in [('Wrist',(s*.386,.085,.080)),('Ankle',(s*.123,.955,.061))]:
  o=bpy.data.objects.new(('Left' if s<0 else 'Right')+name,None);bpy.context.collection.objects.link(o);o.location=p

# Consolidated surfaces keep this detailed prop affordable in the Web edition.
for m in [bone,dark]:
 parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0]==m]
 if parts:
  o=join(parts,'WeatheredSkeleton' if m==bone else 'CranialDarkness')
  if m==bone:pigment(o,(.50,.45,.32))
root=bpy.data.objects.new('ChainedAdultRemains',None);bpy.context.collection.objects.link(root)
root['anatomy']='adult male skeleton, supine; no living body'
for o in list(bpy.data.objects):
 if o!=root and o.parent is None:o.parent=root
export('archive-remains.glb')
print('Authored archive skeleton with articulated hand bones and true skull cavities')
