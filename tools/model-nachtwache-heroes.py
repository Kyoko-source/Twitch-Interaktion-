"""Author original UV-mapped hero props. Run with portable Blender --background --python."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "games/kinderparadies/assets"
OUT = ASSETS / "hero"
OUT.mkdir(exist_ok=True)

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def material(name, color, albedo=None, normal=None, roughness=.85):
    m=bpy.data.materials.new(name);m.use_nodes=True
    shader=m.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=roughness
    if albedo:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(albedo),check_existing=True)
        m.node_tree.links.new(t.outputs['Color'],shader.inputs['Base Color'])
    if normal:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(normal),check_existing=True);t.image.colorspace_settings.name='Non-Color'
        n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.28
        m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],shader.inputs['Normal'])
    return m

def smooth(obj, m):
    obj.data.materials.append(m)
    for face in obj.data.polygons:face.use_smooth=True
    return obj

def ellipsoid(name, pos, size, m, wrinkles=False, pear=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=28,location=pos)
    obj=bpy.context.object;obj.name=name
    for v in obj.data.vertices:
        p=v.co.copy()
        if pear:p.x*=1-.2*p.z;p.y*=1-.12*p.z
        if wrinkles:
            ripple=1+.013*math.sin(p.z*42+p.x*12)*math.sin(p.y*23)+.009*math.sin(p.x*67+p.z*23)
            p*=ripple
        v.co=Vector((p.x*size[0],p.y*size[1],p.z*size[2]))
    return smooth(obj,m)

def curve(name, points, radius, m):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=2;data.bevel_depth=radius;data.bevel_resolution=3
    poly=data.splines.new('POLY');poly.points.add(len(points)-1)
    for p,xyz in zip(poly.points,points):p.co=(*xyz,1)
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(m);return obj

def box(name,pos,size,m,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);obj=bpy.context.object;obj.name=name;obj.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    modifier=obj.modifiers.new('Soft manufactured edges','BEVEL');modifier.width=bevel;modifier.segments=5
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)
    smooth(obj,m);obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');return obj

def export(name):
    # Apply modifiers and convert sewn curves to actual portable geometry.
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
    bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
    if len(bpy.context.selected_objects)>1:bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
    print('AUTHORED',name,flush=True)

clear()
fur=material('Worn oatmeal plush',(0.55,.44,.32),ASSETS/'plush-fur.png',ASSETS/'pbr/fabric_pattern_07/normal.jpg',.97)
patch=material('Vintage sewn cloth',(.5,.3,.2),ASSETS/'pbr/fabric_pattern_07/albedo.jpg',ASSETS/'pbr/fabric_pattern_07/normal.jpg',.98)
thread=material('Heavy dark thread',(.15,.1,.065),roughness=1)
ivory=material('Ivory thread',(.73,.66,.5),roughness=1)
button=material('Worn black buttons',(.025,.019,.012),roughness=.45)
ellipsoid('Pear-shaped stuffed body',(0,0,.33),(.29,.22,.34),fur,True,True)
head=ellipsoid('Asymmetric soft head',(.015,-.025,.77),(.25,.215,.245),fur,True)
head.rotation_euler.y=.07
for side in [-1,1]:
    arm=ellipsoid('Slumped arm',(side*.275,-.01,.32),(.105,.12,.24),fur,True);arm.rotation_euler.y=-side*.26
    foot=ellipsoid('Flattened paw',(side*.17,-.13,.075),(.15,.225,.105),fur,True);foot.rotation_euler.z=side*.15
    ellipsoid('Sewn paw pad',(side*.17,-.307,.086),(.085,.025,.066),patch)
    # Floppy lofted ears with genuinely curved, asymmetric tips.
    vertices=[];faces=[];uvs=[];rings=32;segments=16
    control=[Vector((side*.13,0,.94)),Vector((side*.21,.015,1.35)),Vector((side*.33,-.08,1.45)),Vector((side*.35,-.2,1.18 if side<0 else 1.34))]
    for j in range(rings):
        t=j/(rings-1);c=(1-t)**3*control[0]+3*(1-t)**2*t*control[1]+3*(1-t)*t*t*control[2]+t**3*control[3]
        width=.016+.07*math.sin(math.pi*t)**.65
        for i in range(segments):
            a=2*math.pi*i/segments;vertices.append(c+Vector((math.cos(a)*width,math.sin(a)*width*.38,0)));uvs.append((i/segments,t))
    for j in range(rings-1):
        for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
    mesh=bpy.data.meshes.new('Tailored floppy ear');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('Floppy ear',mesh);bpy.context.collection.objects.link(obj);smooth(obj,fur)
    uv=mesh.uv_layers.new()
    for polygon in mesh.polygons:
        for li in polygon.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    points=[]
    for j in range(23):
        t=.08+j/22*.82;c=(1-t)**3*control[0]+3*(1-t)**2*t*control[1]+3*(1-t)*t*t*control[2]+t**3*control[3];c.y-=.03;points.append(c)
    curve('Inset ear seam',points,.006,patch)
    eye=ellipsoid('Button eye',(side*.091,-.22,.81),(.037,.016,.037),button)
    for diagonal in [-1,1]:curve('Cross sewn through button',[(side*.091-.014,-.239,.81-diagonal*.014),(side*.091+.014,-.239,.81+diagonal*.014)],.0025,ivory)
ellipsoid('Muzzle left',(-.045,-.218,.7),(.078,.055,.05),fur)
ellipsoid('Muzzle right',(.045,-.218,.7),(.078,.055,.05),fur)
ellipsoid('Soft stitched nose',(0,-.275,.735),(.031,.021,.02),thread)
curve('Crooked embroidered smile',[(-.07,-.267,.685),(-.035,-.278,.672),(0,-.277,.69),(.035,-.278,.672),(.07,-.267,.685)],.0035,thread)
ellipsoid('Sewn belly patch',(0,-.205,.29),(.16,.027,.19),patch)
for i in range(32):
    a=i*2*math.pi/32;x=math.cos(a)*.157;z=.29+math.sin(a)*.19
    curve('Individual belly stitch',[(x*.94,-.235,.29+(z-.29)*.94),(x*1.05,-.229,.29+(z-.29)*1.05)],.0028,ivory)
for i in range(17):
    z=.16+i*.028;y=-.22*math.sqrt(max(.1,1-((z-.33)/.34)**2))-.004
    curve('Visible toy seam',[(-.012,y,z),(.012,y,z+.009)],.0023,thread)
export('stitched-rabbit')

clear()
leather=material('Worn vinyl upholstery',(.4,.26,.15),ASSETS/'pbr/fabric_leather_01/albedo.jpg',ASSETS/'pbr/fabric_leather_01/normal.jpg',.68)
metal=material('Dark tubular steel',(.035,.045,.045),roughness=.34)
for i in range(3):
    box('Individual rounded seat',(i*.92-.92,0,.56),(.88,.7,.19),leather,.085)
    back=box('Padded tilted back',(i*.92-.92,.29,.97),(.88,.15,.7),leather,.07);back.rotation_euler.x=-.12
    curve('Seat piping',[(i*.92-.92+math.cos(a/32*math.tau)*.42,math.sin(a/32*math.tau)*.32,.655) for a in range(33)],.006,thread)
for x in [-1.12,1.12]:
    for y in [-.24,.24]:curve('Bent steel bench foot',[(x,y,.04),(x,y,.46),(x,y+.04,.54)],.035,metal)
curve('Seat support',[(-1.28,0,.45),(1.28,0,.45)],.045,metal)
export('waiting-bench')

clear()
cloth=material('Stained hanging fabric',(.42,.43,.38),None,ASSETS/'pbr/fabric_pattern_07/normal.jpg',.98)
vertices=[];faces=[];uvs=[];cols=56;rows=48
for j in range(rows+1):
    v=j/rows
    for i in range(cols+1):
        u=i/cols;x=(u-.5)*1.65;y=math.sin(u*math.pi*12)*(.045+.065*v)+math.sin(u*math.pi*3)*v*v*.22
        rag=(math.sin(u*57)*.07+math.sin(u*113)*.025)*v**7
        z=(1-v)*2.1+rag-math.sin(u*math.pi)*.13
        vertices.append((x,y,z));uvs.append((u*2,v*3))
for j in range(rows):
    for i in range(cols):
        u=(i+.5)/cols;v=(j+.5)/rows
        if ((u-.32)**2/.018**2+(v-.74)**2/.11**2<1) or (j>rows-4 and .68<u<.72):continue
        a=j*(cols+1)+i;faces.append((a,a+1,a+cols+2,a+cols+1))
mesh=bpy.data.meshes.new('Draped woven cloth');mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new('Draped torn curtain',mesh);bpy.context.collection.objects.link(obj);smooth(obj,cloth);uv=mesh.uv_layers.new()
for polygon in mesh.polygons:
    for li in polygon.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
export('torn-drape')

clear()
icing=material('Old vanilla icing',(.78,.72,.55),roughness=.72)
chocolate=material('Chocolate sponge',(.12,.055,.027),roughness=.93)
berry=material('Strawberry topping',(.42,.025,.018),roughness=.48)
def cylinder(name,pos,radius,depth,m,vertices=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    obj=bpy.context.object;obj.name=name
    bevel=obj.modifiers.new('Soft edible edge','BEVEL');bevel.width=.008;bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name);return smooth(obj,m)
cylinder('Chocolate layers',(0,0,.105),.3,.21,chocolate)
for z in [.04,.12,.205]:cylinder('Cream layer',(0,0,z),.306,.025,icing)
cylinder('Soft frosted top',(0,0,.223),.31,.035,icing)
for i in range(24):
    a=i*math.tau/24
    curve('Icing drip',[(math.cos(a)*.308,math.sin(a)*.308,.235),(math.cos(a)*.312,math.sin(a)*.312,.2),(math.cos(a)*.309,math.sin(a)*.309,.13+(i%4)*.018)],.009,icing)
for radius in [.06,.13,.2,.275]:
    curve('Piped top swirl',[(math.cos(i/95*math.tau)*radius,math.sin(i/95*math.tau)*radius,.246+math.sin(i*.6)*.003) for i in range(96)],.009,icing)
for i in range(8):
    a=i*math.tau/8;x=math.cos(a)*.23;y=math.sin(a)*.23
    ellipsoid('Strawberry',(x,y,.278),(.035,.035,.046),berry,True)
    for j in range(6):
        ang=j*math.tau/6
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.003,location=(x+math.cos(ang)*.033,y+math.sin(ang)*.033,.279))
        smooth(bpy.context.object,ivory)
for i in range(6):
    a=i*math.tau/6;x=math.cos(a)*.12;y=math.sin(a)*.12
    wax=material('Pastel candle '+str(i),[(.35,.52,.57),(.72,.36,.35),(.72,.62,.3)][i%3],roughness=.7)
    cylinder('Birthday candle',(x,y,.32),.012,.15,wax,16)
    curve('Candle stripe',[(x+math.cos(j/23*math.tau*3)*.0125,y+math.sin(j/23*math.tau*3)*.0125,.25+j/23*.14) for j in range(24)],.0015,ivory)
    curve('Unlit wick',[(x,y,.395),(x+.002,y,.408)],.0018,thread)
export('birthday-cake')
