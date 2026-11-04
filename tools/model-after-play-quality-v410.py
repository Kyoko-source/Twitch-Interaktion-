"""Native close-up derivatives. Preserve authored pivots, UVs and skin bindings.

Uses existing project models and their retained credits. No runtime colliders.
Run with Blender 4.5 --background --python this_file.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'games/kinderparadies/assets'
OUT=A/'quality-v410/desktop';OUT.mkdir(parents=True,exist_ok=True)
helper=ROOT/'tools/model-after-play-lift-v391.py'
exec(compile(helper.read_text(encoding='utf-8').split('\nclear()\nframe=')[0],str(helper),'exec'),globals())
OUT=A/'quality-v410/desktop'
report={}

def load_model(source):
    clear();bpy.ops.import_scene.gltf(filepath=str(A/source))

def refine(obj,amount=0.,level=1):
    if obj.type!='MESH' or len(obj.data.polygons)<4:return
    bpy.context.view_layer.objects.active=obj
    if level:
        sub=obj.modifiers.new('Close-up contour subdivision','SUBSURF');sub.levels=level
        # Keep an armature last, so weights are interpolated before deformation.
        bpy.ops.object.modifier_move_up(modifier=sub.name)
        bpy.ops.object.modifier_apply(modifier=sub.name)
    if amount:
        original=[(v.co.copy(),v.normal.copy()) for v in obj.data.vertices]
        for v,(p,normal) in zip(obj.data.vertices,original):
            grain=math.sin(p.x*901+math.sin(p.z*413))*math.sin(p.y*787)
            v.co=p+normal*grain*amount
    for p in obj.data.polygons:p.use_smooth=True

def save(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=True,export_materials='EXPORT')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    report[name]={'vertices':sum(len(o.data.vertices) for o in meshes),'meshes':len(meshes)}
    print('QUALITY MODEL',name,report[name],flush=True)

load_model('tactile-v400/interaction-hand.glb')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
hand=next(o for o in bpy.context.scene.objects if o.type=='MESH')
refine(hand,.000075)
# Light transverse creases are part of the skin itself, not loose black strips.
original=[(v.co.copy(),v.normal.copy()) for v in hand.data.vertices]
for v,(p,normal) in zip(hand.data.vertices,original):
    gx,gy,gz=p.x,p.z,-p.y
    crease=0.
    for x,ys in [(-.029,[.071,.098]),(-.010,[.077,.108]),(.011,[.073,.101]),(.030,[.058,.083])]:
        for y in ys:crease+=math.exp(-((gx-x)/.008)**4-((gy-y)/.00115)**2)
    crease+=.6*math.exp(-((gy+.058)/.0018)**2)
    v.co=p-normal*min(1.,crease)*.00028
nail=mat('Natural translucent fingernails',(.55,.405,.335),.41)
for name,x,end in [('index',-.029,.119),('middle',-.010,.132),('ring',.011,.123),('little',.030,.103)]:
    # Anatomical dorsal face; each plate follows the last phalanx's binding.
    o=egg('Fitted '+name+' nail',(x,end-.008,-.011),(.0045,.0065,.00075),nail)
    o.parent=rig;group=o.vertex_groups.new(name=name+'3');group.add(list(range(len(o.data.vertices))),1.,'REPLACE')
    arm=o.modifiers.new('Fingertip binding','ARMATURE');arm.object=rig
save('interaction-hand')

for source,target in [('revamp-v300/anatomical-grip-v300.glb','torch-grip'),('lift-v391/nightguard-phone-hand.glb','phone-hand')]:
    load_model(source)
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            labels=' '.join(m.name for m in o.data.materials if m).lower()
            if 'skin' in labels:refine(o,.000055)
            if 'nail' in labels:
                for material in o.data.materials:
                    material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.48,.335,.285,1)
                    material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.49
                if target=='phone-hand':bpy.data.objects.remove(o,do_unlink=True)
    if target=='phone-hand':
        nail=mat('Fitted satin keratin plates',(.48,.335,.285),.49)
        # The curled fingers approach the glass along X. The old discs had
        # their long axis sideways and read as five grey beads in the intro.
        for i,y in enumerate([.042,.020,-.002,-.023]):
            points=[];faces=[]
            for row in range(7):
                t=row/6;half=.0034*math.sin(.45+math.pi*.72*t)
                for col in range(7):
                    u=col/3-1
                    points.append(gp((.0335+t*.009,y-.003+u*half,.0138+.00055*(1-u*u))))
            for row in range(6):
                for col in range(6):
                    a=row*7+col;faces.append((a,a+1,a+8,a+7))
            mesh=bpy.data.meshes.new('Curved longitudinal nail plate');mesh.from_pydata(points,[],faces);mesh.update()
            plate=bpy.data.objects.new('Fitted phone fingernail '+str(i),mesh);bpy.context.collection.objects.link(plate);finish(plate,plate.name,nail)
            solid=plate.modifiers.new('Thin keratin edge','SOLIDIFY');solid.thickness=.00018;bpy.context.view_layer.objects.active=plate;bpy.ops.object.modifier_apply(modifier=solid.name)
    save(target)

load_model('detail-v310/clown-v310.glb')
body=bpy.data.objects.get('Body')
# Replace the disconnected triangular collar with one closed folded ruff.
bm=bmesh.new();bm.from_mesh(body.data)
bad=[f for f in bm.faces if body.data.materials[f.material_index].name=='Dirty pleated linen' and min(v.co.z for v in f.verts)>1.52]
bmesh.ops.delete(bm,geom=bad,context='FACES');bm.to_mesh(body.data);bm.free()
for o in list(bpy.context.scene.objects):
    if o.type!='MESH':continue
    labels=' '.join(m.name for m in o.data.materials if m).lower()
    if o.name=='Head':refine(o,.00014)
    elif 'woven costume' in labels or 'pleated linen' in labels:refine(o,.00020)
    elif 'enamel' in labels or 'gum tissue' in labels:refine(o,.00006)
linen=next(m for m in body.data.materials if m.name=='Dirty pleated linen')
verts=[];faces=[];sides=192
for row in range(5):
    for side in range(sides):
        a=math.tau*side/sides;radius=[.078,.13,.205,.252,.25][row]
        height=1.635+math.sin(a*24)*(.003+row*.005)-row*.014
        verts.append(gp((math.cos(a)*radius,height,math.sin(a)*radius)))
for row in range(4):
    for side in range(sides):
        a=row*sides+side;b=row*sides+(side+1)%sides;faces.append((a,b,b+sides,a+sides))
mesh=bpy.data.meshes.new('Continuous folded linen ruff');mesh.from_pydata(verts,[],faces);mesh.update()
ruff=bpy.data.objects.new('Continuous folded linen ruff',mesh);bpy.context.collection.objects.link(ruff);finish(ruff,ruff.name,linen)
solid=ruff.modifiers.new('Folded cloth thickness','SOLIDIFY');solid.thickness=.003;bpy.context.view_layer.objects.active=ruff;bpy.ops.object.modifier_apply(modifier=solid.name)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);ruff.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
save('clown')

load_model('ceiling-horse-v356/bloodied-equine-mask.glb')
for o in list(bpy.context.scene.objects):
    if o.type!='MESH':continue
    labels=' '.join(m.name for m in o.data.materials if m).lower()
    if 'mane' not in labels and 'darkness' not in labels:refine(o,.00027 if 'skin' in labels else .0001)
save('horse-mask')

for kind in ['granny','passage']:
    load_model('shift-v390/'+kind+'-head.glb')
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH' and len(o.data.vertices)<40000:refine(o,.00010)
    save(kind+'-head')

load_model('revamp-v300/mascot-rabbit-v300.glb')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m and m.name.startswith('Worn oatmeal') for m in o.data.materials))
refine(body,0.,1)
# Short, combed clusters replace the straight protruding pile. All fibres share
# one mesh and one material, without thousands of nodes or individual curves.
old=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m and 'Short matted' in m.name for m in o.data.materials))
pile=old.data.materials[0]
verts=[];faces=[];colours=[];rnd=random.Random(410)
plush_materials={i for i,m in enumerate(body.data.materials) if m and m.name.startswith('Worn oatmeal')}
plush_vertices={i for p in body.data.polygons if p.material_index in plush_materials for i in p.vertices}
available=[v for v in body.data.vertices if v.index in plush_vertices and v.normal.length>.5]
for i in range(11000):
    v=rnd.choice(available);p=body.matrix_world@v.co;n=(body.matrix_world.to_3x3()@v.normal).normalized()
    down=Vector((0,0,-1));comb=down-n*down.dot(n)
    if comb.length<.01:comb=n.cross(Vector((1,0,0)))
    comb.normalize();side=n.cross(comb).normalized()
    length=rnd.uniform(.006,.017);shade=rnd.uniform(.38,.61)
    for strand in range(3):
        start=len(verts);root=p+side*(strand-1)*.0015
        tip=root+n*length*.55+comb*length
        width=rnd.uniform(.00045,.00085)
        verts.extend([root-side*width,root+side*width,tip])
        faces.append((start,start+1,start+2));colours.extend([(shade*.94,shade*.87,shade*.72,1)]*2+[(shade*1.1,shade,shade*.84,1)])
mesh=bpy.data.meshes.new('Combed short matted plush clusters');mesh.from_pydata(verts,[],faces);mesh.materials.append(pile)
colour_name=next((node.layer_name for node in pile.node_tree.nodes if node.type=='VERTEX_COLOR'),'Color')
attr=mesh.color_attributes.new(name=colour_name,type='FLOAT_COLOR',domain='POINT')
for i,c in enumerate(colours):attr.data[i].color=c
old.data=mesh;old.matrix_world.identity()
save('mascot-rabbit')

# A manufactured desk phone with a separate handset, recessed keypad, vents,
# mould seams, rubber feet and a continuous coiled cable, in local desk metres.
clear()
plastic=mat('Aged olive telephone ABS',(.105,.135,.105),.67)
rubber=mat('Desk phone black rubber',(.018,.024,.020),.91)
ivory=mat('Yellowed phone keycaps',(.49,.47,.35),.72)
box('Moulded telephone base',(0,.037,0),(.235,.074,.275),plastic,.015)
box('Underside service plate',(0,.005,0),(.183,.009,.226),rubber,.004)
box('Recessed keypad',(0,.077,.031),(.122,.008,.134),rubber,.004)
for row in range(4):
    for col in range(3):box('Individual dial key',(-.037+col*.037,.085,.001+row*.030),(.028,.011,.022),ivory,.003)
for x in [-.092,.092]:
    box('Handset cradle',(x,.084,-.080),(.033,.021,.055),plastic,.006)
    for z in [-.10,.10]:egg('Rubber isolation foot',(x,.004,z),(.012,.004,.013),rubber)
path('Curved handset spine',[(-.098,.111,-.089),(-.057,.123,-.085),(0,.126,-.084),(.057,.123,-.085),(.098,.111,-.089)],[.026,.021,.019,.021,.026],plastic)
for x in [-.097,.097]:
    egg('Handset earpiece',(x,.106,-.087),(.035,.025,.039),plastic)
    for j in range(5):box('Speaker grille',(x-.012+j*.006,.124,-.104),(.002,.002,.018),rubber,.0005)
coil=[]
for i in range(241):
    t=i/240;coil.append((-.139+math.sin(t*math.tau*22)*.007,.04+math.cos(t*math.tau*22)*.007,-.095+t*.205))
path('Connected coiled handset lead',coil,[.0022]*len(coil),rubber)
for material in [plastic,rubber,ivory]:
    bpy.ops.object.select_all(action='DESELECT')
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and material in list(o.data.materials)]
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
save('desk-phone')

(OUT.parent/'model-provenance.json').write_text(json.dumps({'author':'Original project derivatives and original telephone model','sources':['existing credited project hand and costume models','Lee Perry Smith credited facial scan in existing clown derivative'],'models':report},indent=2),encoding='utf-8')
