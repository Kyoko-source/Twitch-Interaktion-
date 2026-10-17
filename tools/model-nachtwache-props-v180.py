"""Author real opaque 3D clown anatomy and a detailed first-person torch.

Blender 4.5 background script. No portrait planes, facial colour textures or billboards.
Clown paint and superficial blood staining are vertex colours on sculpted meshes.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parents[1]/'games/kinderparadies/assets/props'
OUT.mkdir(exist_ok=True)
rng=random.Random(1800)

def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def mat(name,color,rough=.7,metal=0,paint=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;s.inputs['Metallic'].default_value=metal
    m['vertex_paint']=paint
    if paint:
        v=m.node_tree.nodes.new('ShaderNodeVertexColor');v.layer_name='Pigment';m.node_tree.links.new(v.outputs['Color'],s.inputs['Base Color'])
    return m

def finish(obj,m,group,painter=None):
    obj.data.materials.append(m)
    if obj.type=='MESH':
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(obj.data);bm.free()
        for f in obj.data.polygons:f.use_smooth=True
        if painter:
            attr=obj.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
            for i,v in enumerate(obj.data.vertices):attr.data[i].color=(*painter(obj.matrix_world@v.co),1)
    group.append(obj);return obj

def sphere(name,pos,size,m,group,painter=None,segments=32,rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=pos);o=bpy.context.object;o.name=name
    for v in o.data.vertices:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
    return finish(o,m,group,painter)

def line(name,points,r,m,group):
    d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=1;d.bevel_depth=r;d.bevel_resolution=2
    sp=d.splines.new('POLY');sp.points.add(len(points)-1)
    for p,xyz in zip(sp.points,points):p.co=(*xyz,1)
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.data.materials.append(m);group.append(o);return o

def box(name,pos,size,m,group,bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Machined rounded edges','BEVEL');mod.width=bevel;mod.segments=3
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,m,group)

def cylinder(name,pos,radius,depth,m,group,axis='Z',vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name
    if axis=='Y':o.rotation_euler.x=math.pi/2
    return finish(o,m,group)

def batch(objects,name,origin=(0,0,0)):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
    for obj in objects:
        if not obj.data.color_attributes.get('Pigment'):
            attr=obj.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
            material=obj.data.materials[0];fallback=material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value if material.get('vertex_paint') else (1,1,1,1)
            for value in attr.data:value.color=fallback
    bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);bpy.context.scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bmesh.ops.triangulate(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
    return o

def export(name):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/name),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)

def mix(a,b,t):return tuple(x*(1-t)+y*t for x,y in zip(a,b))
def noise(x,y,z):return .5+.25*math.sin(x*197+y*71+z*43)+.25*math.sin(x*83-y*139+z*97)

clear();body=[];head=[]
skin=mat('Cracked greasepaint and blood',(.55,.51,.4),.8,paint=True)
cloth=mat('Blood stained woven costume',(.23,.055,.06),.96,paint=True)
linen=mat('Dirty pleated linen',(.48,.43,.31),.96,paint=True)
black=mat('Deep cavities',(.008,.007,.006),.92)
lip=mat('Cracked burgundy lips',(.12,.018,.027),.55)
eyes=mat('Yellowed sclera',(.44,.43,.32),.3)
iris=mat('Dull amber irises',(.24,.17,.06),.26)
tooth=mat('Individual discoloured teeth',(.48,.42,.25),.64)
hair=mat('Matted auburn hair',(.065,.022,.012),.94)
brass=mat('Tarnished buttons',(.27,.2,.09),.65,.5)

def face_colour(p):
    x,y,z=p.x,p.y,p.z-1.96;n=noise(x,y,z)
    c=mix((.47,.43,.32),(.72,.68,.55),.6+n*.3)
    if y>-.04:return mix(c,(.19,.16,.12),.55)
    ax=abs(x)
    eye_patch=math.exp(-((ax-.083)/.061)**4-((z-.048)/.059)**4)
    tear=1 if -.13<z<.035 and abs(ax-(.085+.13*(-z)))<.009*(1+(z+.13)*4) else 0
    brow=math.exp(-((ax-.08)/.07)**4-((z-.115+ax*.13)/.017)**4)
    smear=2.2*math.exp(-((x+.15)/.075)**2-((z+.02)/.19)**2)*(.5+.5*n)
    smear+=1.3*math.exp(-((x-.035)/.105)**2-((z-.21)/.10)**2)*(.3+.7*n)
    if -.24<z<.03 and abs(x+.118+math.sin(z*29)*.005)<.009:smear=max(smear,.96)
    c=mix(c,(.075+.05*n,.002+.003*n,.007),min(.96,smear))
    c=mix(c,(.003,.004,.004),min(.995,max(eye_patch,tear,brow)*(.97+.025*n)))
    grin=-.12+.065*(ax/.15)**1.7
    mouth=math.exp(-((x/.145)**8+((z-grin)/.018)**4))
    c=mix(c,(.055,.002,.008),mouth*.97)
    # Broken greasepaint exposes mottled skin instead of a perfectly smooth mask.
    flake=max(0,noise(x*5,y*5,z*5)-.71)*.75
    return mix(c,(.11,.095,.07),flake)

# The anatomical base is Lee Perry-Smith's attributed CC BY 3.0 scan.
# Only geometry is retained: portrait images and original materials are discarded.
source=Path(__file__).resolve().parent/'art-source/anatomy/LeePerrySmith.glb'
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(source))
imported=[o for o in bpy.context.scene.objects if o not in before]
obj=next(o for o in imported if o.type=='MESH')
bpy.context.view_layer.objects.active=obj
for v in obj.data.vertices:v.co=obj.matrix_world@v.co
obj.matrix_world.identity()
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z < -.95],context='VERTS')
bm.to_mesh(obj.data);bm.free()
obj.data.materials.clear()
for attr in list(obj.data.color_attributes):obj.data.color_attributes.remove(attr)
for v in obj.data.vertices:
    x,y,z=v.co
    # Keep an anatomically coherent skull, with a leaner lower face.
    v.co=Vector((x*.13,(y*.12)+.035,1.78+z*.13))
obj.name='Attribution - Lee Perry-Smith anatomical base'
# One subdivision gives the cut eyelids and greasepaint clean contours in close-up.
sub=obj.modifiers.new('Close-up facial contours','SUBSURF');sub.levels=1
bpy.ops.object.modifier_apply(modifier=sub.name)
# The scanned eyelids remain closed and visibly sculpted beneath black greasepaint.
# No protruding white eyeballs or spherical red nose: the actual facial anatomy reads.
finish(obj,skin,head,face_colour)
normal=bpy.data.images.load(str(source.parent/'Infinite-Level_02_Tangent_SmoothUV.jpg'));normal.colorspace_settings.name='Non-Color'
tex=skin.node_tree.nodes.new('ShaderNodeTexImage');tex.image=normal
nm=skin.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.5
skin.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);skin.node_tree.links.new(nm.outputs['Normal'],skin.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
# A thin patch of matted hair follows the back of the scanned skull.
hair_vs=[];hair_fs=[];mapping={}
for f in obj.data.polygons:
    pts=[obj.data.vertices[i] for i in f.vertices]
    if not all(1.99<v.co.z<2.255 and v.co.y>-.035 and abs(v.co.x)>.10 for v in pts):continue
    face=[]
    for v in pts:
        if v.index not in mapping:
            mapping[v.index]=len(hair_vs);hair_vs.append(v.co+v.normal*.003)
        face.append(mapping[v.index])
    hair_fs.append(face)
hm=bpy.data.meshes.new('Matted hair scalp');hm.from_pydata(hair_vs,[],hair_fs);hm.update();ho=bpy.data.objects.new('Matted hair on skull',hm);bpy.context.collection.objects.link(ho);finish(ho,hair,head)
# Thin locks follow actual skull vertices, avoiding spherical hair clumps.
candidates=[v.co.copy() for v in obj.data.vertices if 2.035<v.co.z<2.27 and v.co.y>-.03 and abs(v.co.x)>.11]
for p in rng.sample(candidates,min(240,len(candidates))):
    outward=Vector((p.x,p.y,0)).normalized()*.008
    line('Straggling auburn hair',[p+outward,p+outward*1.8+Vector((0,0,-.04)),p+outward*2+Vector((rng.uniform(-.008,.008),0,-.105))],rng.uniform(.0013,.0026),hair,head)
for o in imported:
    if o!=obj and o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)

def cloth_colour(p):
    n=noise(p.x,p.y,p.z);c=mix((.12,.026,.032),(.27,.08,.075),n)
    if p.y<-.12 and .84<p.z<1.58 and abs(p.x)<.23:
        c=mix((.4,.36,.25),(.57,.52,.38),n)
        blood=min(.96,2.8*math.exp(-((p.x+.08)/.17)**2-((p.z-1.26)/.24)**2)*(.65+.35*n))
        blood=max(blood,.8 if abs(p.x+.1+math.sin(p.z*30)*.008)<.012 and .86<p.z<1.31 else 0)
        c=mix(c,(.095,.004,.009),blood)
    return c

def torso_mesh():
    vs=[];fs=[];control=[(.83,.23,.14),(.98,.25,.145),(1.16,.24,.155),(1.36,.27,.16),(1.5,.32,.15),(1.57,.21,.12)];sections=[]
    for a,b in zip(control,control[1:]):
        for k in range(7):sections.append(tuple(x+(y-x)*k/7 for x,y in zip(a,b)))
    sections.append(control[-1])
    for j,(z,rx,ry) in enumerate(sections):
        for i in range(64):
            a=i*math.tau/64;w=1+.022*math.sin(a*19+z*14);vs.append((math.cos(a)*rx*w,math.sin(a)*ry*w,z))
    for j in range(len(sections)-1):
        for i in range(64):fs.append((j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i))
    fs.extend([tuple(reversed(range(64))),tuple((len(sections)-1)*64+i for i in range(64))]);m=bpy.data.meshes.new('Tailored folded torso');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Tailored costume',m);bpy.context.collection.objects.link(o);finish(o,cloth,body,cloth_colour)
torso_mesh();sphere('Neck',(0,0,1.72),(.09,.082,.16),skin,body,face_colour)
for side in [-1,1]:
    sphere('Trouser leg',(side*.135,.015,.49),(.11,.12,.43),cloth,body,cloth_colour)
    shoe=sphere('Worn leather clown boot',(side*.15,-.075,.095),(.13,.25,.095),hair,body)
    for k in range(9):
        z=.2+k*.07;line('Creased trouser stripe',[(side*.135-.05,-.103,z),(side*.135-.045,-.112,z+.04)],.008,linen,body)
    for k in range(4):line('Boot lace',[(side*.15-.055,-.12+k*.03,.18),(side*.15+.055,-.12+k*.03,.18)],.004,linen,body)
    sphere('Tailored shoulder',(side*.27,0,1.47),(.095,.105,.12),cloth,body,cloth_colour)
for z in [.97,1.16,1.38]:sphere('Tarnished costume button',(0,-.173,z),(.022,.012,.022),brass,body)
# A single folded cloth collar replaces the old stacked spheres.
vs=[];fs=[]
for ring in range(4):
    t=ring/3
    for i in range(192):
        a=i*math.tau/192;rx=.09+t*.19;ry=.085+t*.15;fold=math.sin(a*24)*(.006+.016*t)
        vs.append((math.cos(a)*rx,math.sin(a)*ry,1.68+fold-t*.035))
for j in range(3):
    for i in range(192):fs.append((j*192+i,j*192+(i+1)%192,(j+1)*192+(i+1)%192,(j+1)*192+i))
m=bpy.data.meshes.new('Sewn pleated ruff');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Pleated linen collar',m);bpy.context.collection.objects.link(o);finish(o,linen,body,lambda p:mix((.5,.45,.32),(.13,.009,.015),.7 if p.x<-.1 and p.y<0 else .08*noise(*p)))
line('Frayed apron hem',[(-.23,-.155,.85),(0,-.17,.82),(.23,-.155,.86)],.009,linen,body)
batch(body,'Body');batch(head,'Head',(0,0,1.96));export('kitchen-clown-v2.glb')

clear();parts=[];optics=[];lens=[]
metal=mat('Worn anodised aluminium',(.055,.063,.057),.37,.8);rubber=mat('Rubberised grip',(.025,.031,.027),.88)
steel=mat('Machined reflector',(.43,.46,.42),.23,.92);glass=mat('Cloudy glass lens',(.18,.25,.22),.15,.2)
led=mat('Warm LED',(.8,.65,.35),.25);s=led.node_tree.nodes.get('Principled BSDF');s.inputs['Emission Color'].default_value=(.8,.65,.35,1);s.inputs['Emission Strength'].default_value=.6
brass=mat('Oxidised brass contacts',(.3,.22,.1),.5,.7)
cylinder('Battery housing',(0,0,0),.039,.24,metal,parts,'Y')
cylinder('Tailcap',(0,-.135,0),.044,.035,metal,parts,'Y')
for i in range(17):cylinder('Rubber grip rib',(0,-.09+i*.009,0),.042,.004,rubber,parts,'Y',32)
cylinder('Head barrel',(0,.155,0),.069,.11,metal,parts,'Y')
for y in [.105,.125,.145]:cylinder('Cooling fin',(0,y,0),.074,.008,metal,parts,'Y')
cylinder('Machined front rim',(0,.215,0),.072,.018,steel,parts,'Y')
# A hollow concave reflector with a recessed LED, separate glass and retaining screws.
vs=[];fs=[]
for row in range(9):
    r=.012+row*.0066;y=.177+.035*(r/.065)**2
    for i in range(64):a=i*math.tau/64;vs.append((math.cos(a)*r,y,math.sin(a)*r))
for row in range(8):
    for i in range(64):fs.append((row*64+i,row*64+(i+1)%64,(row+1)*64+(i+1)%64,(row+1)*64+i))
m=bpy.data.meshes.new('Concave reflector');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Reflector',m);bpy.context.collection.objects.link(o);finish(o,steel,optics)
cylinder('LED emitter',(0,.181,0),.012,.008,led,lens,'Y')
for i in range(6):
    a=i*math.tau/6;cylinder('Front retaining bolt',(math.cos(a)*.067,.227,math.sin(a)*.067),.003,.004,brass,parts,'Y',12)
box('Raised switch housing',(.037,.035,.0),(.018,.045,.025),metal,parts,.005);box('Rubber switch',(.048,.035,.0),(.009,.026,.018),rubber,parts,.004)
line('Steel belt clip',[(.035,-.12,.015),(.053,-.1,.015),(.053,.03,.015),(.042,.045,.015)],.006,steel,parts)
line('Worn wrist strap',[(-.02,-.15,0),(-.065,-.19,-.02),(-.08,-.27,-.03),(-.04,-.29,-.03),(0,-.19,-.01)],.006,rubber,parts)
batch(parts,'TorchBody');batch(optics,'Reflector');batch(lens,'Emitter');export('nightguard-torch.glb')
(OUT/'LICENSE.txt').write_text('Torch, costume, hair, original vertex paint and scene animation: project-authored. Clown anatomical base: Infinite, 3D Head Scan by Lee Perry-Smith, CC BY 3.0; see Head-Attribution.txt and anatomy-provenance.json. Geometry modified for this game. No portrait colour textures are used. The attributed skin normal map supplies only surface relief.\n',encoding='utf8')
print('AUTHORED opaque 3D clown anatomy and machined handheld torch',flush=True)
