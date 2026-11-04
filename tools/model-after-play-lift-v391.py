"""Original close-up handset and continuous, fitted phone hand. Blender 4.5."""
import bpy, math, random
from mathutils import Vector
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/lift-v391'
OUT.mkdir(exist_ok=True)
rng=random.Random(391)

def clear(): bpy.ops.wm.read_factory_settings(use_empty=True)
def gp(p): return Vector((p[0],-p[2],p[1]))
def mat(name,col,rough=.6,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
def finish(o,name,m):
    o.name=name;o.data.materials.clear();o.data.materials.append(m)
    for f in o.data.polygons:f.use_smooth=True
    return o
def box(name,p,size,m,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=gp(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    b=o.modifiers.new('Machined rounded edge','BEVEL');b.width=bevel;b.segments=5;bpy.ops.object.modifier_apply(modifier=b.name)
    finish(o,name,m);n=o.modifiers.new('Weighted broad face normals','WEIGHTED_NORMAL');n.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=n.name);return o
def egg(name,p,size,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=gp(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m)
def path(name,pts,radii,m):
    points=[gp(p) for p in pts];verts=[];faces=[];sides=24
    for j,p in enumerate(points):
        t=(points[min(j+1,len(points)-1)]-points[max(j-1,0)]).normalized();u=t.cross(Vector((0,0,1)))
        if u.length<.1:u=t.cross(Vector((1,0,0)))
        u.normalize();v=t.cross(u).normalized()
        for k in range(sides):
            a=k*math.tau/sides;verts.append(p+(math.cos(a)*u+math.sin(a)*v)*radii[j])
    for j in range(len(points)-1):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+k for k in range(sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,m)
    bpy.context.view_layer.objects.active=o;s=o.modifiers.new('Rounded joint continuity','SUBSURF');s.levels=2;bpy.ops.object.modifier_apply(modifier=s.name);return o
def export(file):
    # One node per material keeps the close-up inexpensive in both renderers.
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':groups.setdefault(o.data.materials[0],[]).append(o)
    for material,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        bpy.context.object.name=material.name
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/file),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_normals=True,export_texcoords=True)

clear()
frame=mat('Worn graphite aluminium',(.095,.112,.107),.31,.83)
edge=mat('Polished edge wear',(.34,.365,.33),.29,.86)
rubber=mat('Soft touch protective bumper',(.021,.028,.025),.82)
glass=mat('Black polished glass',(.008,.014,.012),.13,.05)
dark=mat('Recessed ports and grille',(.002,.004,.003),.92)
lens=mat('Blue optical coatings',(.014,.045,.052),.11,.28)
box('Radiused aluminium chassis',(0,0,0),(.079,.165,.010),frame,.006)
box('Moulded protective bumper',(0,0,-.001),(.081,.167,.012),rubber,.0065)
box('Front chamfer catching light',(0,0,.0052),(.0775,.162,.0015),edge,.0058)
box('Inset black front glass',(0,0,.0061),(.0758,.160,.0015),glass,.0054)
# Display is supplied as a rounded, live viewport mesh by Godot.
box('Earpiece recess',(0,.075,.007),(.019,.0018,.0006),dark,.0007)
for i in range(10):box('Earpiece mesh',(-.008+i*.0018,.075,.0074),(.0006,.0011,.0002),frame,.0001)
egg('Inset front camera',(.018,.074,.0075),(.0018,.0018,.00035),lens)
egg('Proximity sensor',(-.021,.074,.0074),(.0011,.0011,.0002),dark)
for side in [-1,1]:
    for y in [-.062,.058]:box('Antenna isolator',(side*.0401,y,0),(.0006,.0026,.006),dark,.0002)
    box('Separate side key',(side*.041,.025 if side>0 else .031,0),(.0013,.019 if side>0 else .029,.0036),frame,.00055)
box('Charging socket',(0,-.0837,0),(.009,.0005,.003),dark,.0007)
for x in [-.028,-.024,-.020,-.016,.016,.020,.024,.028]:egg('Bottom speaker perforation',(x,-.0837,0),(.0009,.00025,.0009),dark)
for x in [-.010,.010]:egg('Recessed assembly screw',(x,-.0836,0),(.00065,.00025,.00065),edge)
box('Raised rear camera island',(-.019,.052,-.008),(.034,.038,.006),frame,.006)
for x,y in [(-.026,.060),(-.012,.047),(-.026,.043)]:
    egg('Rear camera metal rim',(x,y,-.012),(.0057,.0057,.0015),edge);egg('Recessed rear lens',(x,y,-.0133),(.0048,.0048,.0005),lens)
# Tiny discontinuous edge wear, concentrated at corners rather than random dirt.
for side in [-1,1]:
    for k in range(12):
        y=side*(.058+rng.random()*.016);x=(-1 if k%2 else 1)*(.030+rng.random()*.005)
        box('Bumper abrasion',(x,y,.0069),(.001+rng.random()*.002,.0002,.0001),edge,.00004)
export('nightguard-handset.glb')

clear();skin=mat('Phone hand skin',(.49,.36,.27),.64)
p=skin.node_tree.nodes['Principled BSDF'];p.inputs['Subsurface Weight'].default_value=.08;p.inputs['Specular IOR Level'].default_value=.24
nail=mat('Translucent natural nail plates',(.48,.37,.29),.42)
cuticle=mat('Fine nail cuticles',(.34,.22,.16),.8)
cloth=mat('Nightguard woven cuff',(.027,.043,.036),.97)
skin_parts=[]
skin_parts.append(egg('Palm fitted behind handset',(.003,-.014,-.026),(.029,.046,.013),skin))
skin_parts.append(egg('Thumb saddle',(-.020,-.030,-.022),(.014,.025,.014),skin))
skin_parts.append(path('Continuous wrist and forearm',[(.001,-.042,-.025),(.003,-.067,-.021),(.006,-.092,-.016),(.019,-.152,-.002),(.041,-.228,.025)],[.020,.0185,.019,.023,.027],skin))
tips=[]
for i,y in enumerate([.042,.020,-.002,-.023]):
    # Segmented path folds around the edge; long terminal pads touch the glass.
    offset=i*.0008
    pts=[(.017,y,-.035),(.033,y+.001,-.030),(.045+offset,y,-.020),(.047+offset,y-.001,-.006),(.042,y-.002,.008),(.035,y-.003,.010)]
    radii=[.0078-i*.0004,.0077-i*.0003,.0072-i*.0003,.0066-i*.0003,.0058-i*.0003,.0040-i*.0002]
    skin_parts.append(path('Wrapped finger '+str(i+1),pts,radii,skin));tips.append((.036,y-.003,.014))
skin_parts.append(path('Opposed thumb',[(-.020,-.037,-.027),(-.034,-.030,-.020),(-.043,-.012,-.007),(-.040,.003,.009),(-.030,.009,.011)],[.0105,.010,.0085,.0070,.0048],skin))
# Fuse skin to remove palm/finger seams, preserving distinct fingertip silhouettes.
bpy.ops.object.select_all(action='DESELECT')
for o in skin_parts:o.select_set(True)
bpy.context.view_layer.objects.active=skin_parts[0];bpy.ops.object.join();hand=bpy.context.object;hand.name='Continuous anatomical phone hand'
rem=hand.modifiers.new('Continuous sculpted skin','REMESH');rem.mode='VOXEL';rem.voxel_size=.00075;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
sm=hand.modifiers.new('Relaxed skin','SMOOTH');sm.factor=.38;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
dec=hand.modifiers.new('Close-up silhouette budget','DECIMATE');dec.ratio=.28;bpy.ops.object.modifier_apply(modifier=dec.name)
world=hand.matrix_world.copy();attribute=hand.data.color_attributes.new(name='SkinPigment',type='FLOAT_COLOR',domain='POINT')
for i,v in enumerate(hand.data.vertices):
    q=world@v.co;g=Vector((q.x,q.z,-q.y))
    noise=math.sin(g.x*963+math.sin(g.y*625))*math.sin(g.z*1307)*.018
    red=sum(math.exp(-((g.y-y)/.005)**2-((g.x-.044)/.012)**2) for y in [.042,.020,-.002,-.023])*.045
    attribute.data[i].color=(.47+red+noise,.34+noise,.245+noise*.7,1)
node=skin.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='SkinPigment';skin.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
# Smooth, very shallow joint folds and fitted nails instead of spherical beads.
for i,(x,y,z) in enumerate(tips+[(-.031,.009,.015)]):
    plate=egg('Fitted nail plate '+str(i),(x,y,z),(.0040 if i<4 else .0053,.0060,.00065),nail)
    plate.rotation_euler.y=-.12 if i<4 else .3
    for j in range(2):
        yy=y-.010-j*.002
        path('Subtle distal finger crease',[(x-.003,yy,z-.004),(x,yy-.0005,z-.0044),(x+.003,yy,z-.005)],[.00010,.00013,.00010],cuticle)
box('Tailored dark uniform cuff',(.009,-.124,-.008),(.053,.042,.050),cloth,.011)
path('Folded uniform sleeve',[(.012,-.139,-.004),(.022,-.170,.005),(.038,-.218,.022),(.055,-.265,.039)],[.027,.030,.033,.036],cloth)
seam=mat('Cuff seam thread',(.085,.10,.077),.97)
for i in range(16):
    x=-.007+i*.0031
    box('Cuff topstitch',(x,-.105,.0175),(.0016,.0011,.00045),seam,.00015)
export('nightguard-phone-hand.glb')
print('Lift handset and fitted continuous phone hand exported.',flush=True)
