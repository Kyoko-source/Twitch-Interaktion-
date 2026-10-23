"""Derive the giant mascot from the existing small sewn rabbit, Blender 4.5.

Short textile pile, an actual opening in the cloth, torn lining and cotton.
No flesh, long needle-like hair, flat wound card or floating repair discs.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path(__file__).with_name('model-nachtwache-heroes.py')
exec(compile(SOURCE.read_text(encoding='utf-8').split("export('stitched-rabbit')")[0],str(SOURCE),'exec'),globals())
OUT=ASSETS/'mascot-v251';OUT.mkdir(exist_ok=True)
rng=random.Random(251)

# At five metres the small toy's stitches must remain yarn, not ivory pegs.
for obj in bpy.context.scene.objects:
    if obj.type=='CURVE' and obj.name.startswith(('Individual belly stitch','Visible toy seam','Crooked embroidered smile','Inset ear seam')):
        obj.data.bevel_depth*=.32

# Preserve the approved little rabbit's silhouette, muzzle, ears and woven maps.
body=bpy.data.objects['Pear-shaped stuffed body']
patch_obj=bpy.data.objects['Sewn belly patch']
for obj in [body,bpy.data.objects['Asymmetric soft head'],patch_obj]:
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Textile detail sampling','SUBSURF');modifier.levels=1
    bpy.ops.object.modifier_apply(modifier=modifier.name)

lining=material('Dark woven inside of the torn toy',(.065,.048,.031),ASSETS/'pbr/fabric_pattern_07/albedo.jpg',ASSETS/'pbr/fabric_pattern_07/normal.jpg',1)
cotton=material('Dirty irregular cotton stuffing',(.66,.62,.51),ASSETS/'plush-fur.png',ASSETS/'pbr/fabric_pattern_07/normal.jpg',1)
loose=material('Loose cotton fibres',(.64,.60,.51),roughness=1)

# The opening follows a crooked manufactured seam rather than a red human wound.
def tear(t):
    return Vector((.047+.014*math.sin(t*8.2)+.003*math.sin(t*31),0,.20+t*.32)),(.010+.028*math.sin(math.pi*t)**.75)*(.90+.12*math.sin(t*51))

coords=[body.matrix_world@v.co for v in body.data.vertices]
skin=BVHTree.FromPolygons(coords,[tuple(p.vertices) for p in body.data.polygons])
def front(x,z):
    hit=skin.ray_cast(Vector((x,-.60,z)),Vector((0,1,0)))
    return hit[0].y if hit[0] is not None else -.18

def cloth_front(x,z):
    y=front(x,z);inside=1-(x/.16)**2-((z-.29)/.19)**2
    return min(y,-.205-.027*math.sqrt(inside)) if inside>0 else y

verts=[];faces=[];rows=39
for i in range(rows):
    p,width=tear(i/(rows-1))
    for y in [-.40,-.105]:
        verts.extend([(p.x-width,y,p.z),(p.x+width,y,p.z)])
for i in range(rows-1):
    a=i*4;b=a+4
    faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
faces.extend([(0,1,3,2),((rows-1)*4+2,(rows-1)*4+3,(rows-1)*4+1,(rows-1)*4)])
mesh=bpy.data.meshes.new('Irregular seam opening cutter');mesh.from_pydata(verts,[],faces);mesh.update()
cut=bpy.data.objects.new('Opening cutter',mesh);bpy.context.collection.objects.link(cut);cut.data.materials.append(lining)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
for obj in [body,patch_obj]:
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Real hole through cloth and repair','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cut;modifier.material_mode='TRANSFER'
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cut,do_unlink=True)

# Delete stitches physically severed by the rip. Keep all sound manufactured seams.
for obj in list(bpy.context.scene.objects):
    if obj.type!='CURVE' or not obj.name.startswith(('Visible toy seam','Individual belly stitch')):continue
    points=[obj.matrix_world@Vector(p.co[:3]) for s in obj.data.splines for p in s.points]
    if not points:continue
    mid=sum(points,Vector())/len(points);t=(mid.z-.20)/.32
    if 0<t<1:
        center,width=tear(t)
        if abs(mid.x-center.x)<width+.013:bpy.data.objects.remove(obj,do_unlink=True)

# Sew through the curved patch and torso; the original tiny-toy stitch positions
# would otherwise turn into floating pins when enlarged to mascot scale.
for obj in list(bpy.context.scene.objects):
    if obj.type!='CURVE' or not obj.name.startswith(('Visible toy seam','Individual belly stitch')):continue
    old=obj.data.splines[0];a=Vector(old.points[0].co[:3]);b=Vector(old.points[-1].co[:3])
    obj.data.splines.remove(old);seam=obj.data.splines.new('POLY');seam.points.add(6)
    for i,p in enumerate(seam.points):
        t=i/6;v=a.lerp(b,t);y=cloth_front(v.x,v.z) if obj.name.startswith('Individual') else front(v.x,v.z)
        v.y=y+.0007 if i in [0,6] else y-.0018-.0015*math.sin(math.pi*t)
        p.co=(*v,1)

# Folded outer cloth, each vertex placed against the original curved torso.
for side in [-1,1]:
    vertices=[];polygons=[];uvs=[]
    for i in range(rows):
        t=i/(rows-1);p,width=tear(t)
        for j in range(4):
            u=j/3;x=p.x+side*(width+u*(.012+.006*math.sin(t*43)))
            z=p.z+.002*math.sin(t*31+side)*math.sin(math.pi*u)
            y=cloth_front(x,z)-.002-(1-u)*(.006+.006*math.sin(t*29+side)**2)
            vertices.append((x,y,z));uvs.append((u*.3,t*3))
    for i in range(rows-1):
        for j in range(3):
            a=i*4+j;polygons.append((a,a+1,a+5,a+4))
    mesh=bpy.data.meshes.new('Folded frayed cloth lip');mesh.from_pydata(vertices,[],polygons);mesh.update()
    obj=bpy.data.objects.new('Turned fabric edge',mesh);bpy.context.collection.objects.link(obj);smooth(obj,fur)
    uv=mesh.uv_layers.new()
    for loop in mesh.loops:uv.data[loop.index].uv=uvs[loop.vertex_index]
    bpy.context.view_layer.objects.active=obj
    thick=obj.modifiers.new('Real fabric thickness','SOLIDIFY');thick.thickness=.0012;bpy.ops.object.modifier_apply(modifier=thick.name)
    for i in range(23):
        t=.03+i*.041;p,width=tear(t);x=p.x+side*(width+.001);y=front(x,p.z)-.003
        end=(x+side*rng.uniform(.004,.010),y-.006,p.z+rng.uniform(-.009,.009))
        curve('Frayed cloth yarn',[(x,y,p.z),end],.00045,ivory)
    for i in range(9):
        t=.09+i*.10;p,width=tear(t);x=p.x+side*(width+.009);y=front(x,p.z)-.004
        curve('Broken seam thread',[(x,y,p.z),(x-side*.008,y-.013,p.z-.004),(x-side*.012,y-.009,p.z-.016)],.0008,thread)

# Irregular masses tucked into the hole, not a row of beads attached to its face.
cotton_parts=[]
for i in range(18):
    t=.12+rng.random()*.77;p,width=tear(t)
    obj=ellipsoid('Tangled stuffing', (p.x+rng.uniform(-width*.6,width*.6),front(p.x,p.z)+rng.uniform(.007,.035),p.z),
                  (width*rng.uniform(.45,.80),rng.uniform(.017,.026),rng.uniform(.018,.036)),cotton,True)
    for v in obj.data.vertices:
        v.co*=1+.16*math.sin(v.co.x*1311+v.co.z*633)+.10*math.sin(v.co.y*911-v.co.z*737)
    cotton_parts.append(obj)
# Fine, short tangled wool exists only inside the torn seam.
fverts=[];ffaces=[]
for i in range(1600):
    obj=rng.choice(cotton_parts);v=rng.choice(list(obj.data.vertices));p=obj.matrix_world@v.co;n=v.normal.normalized()
    tangent=n.cross(Vector((0,0,1)))
    if tangent.length<.1:tangent=n.cross(Vector((1,0,0)))
    tangent.normalize();end=p+n*rng.uniform(.002,.007)+tangent*rng.uniform(-.003,.003);a=len(fverts)
    width=.00022;fverts.extend([p-tangent*width,p+tangent*width,end]);ffaces.append((a,a+1,a+2))
mesh=bpy.data.meshes.new('Fine tangled stuffing fibres');mesh.from_pydata(fverts,[],ffaces);mesh.update()
obj=bpy.data.objects.new('Loose wool inside the rip',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(loose)

# Stains soak the textured cloth. Never replace the weave with a flat red card.
for obj in bpy.context.scene.objects:
    if obj.type!='MESH' or not any(m in [fur,patch] for m in obj.data.materials):continue
    attr=obj.data.color_attributes.new(name='TextileWear',type='FLOAT_COLOR',domain='POINT')
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co;x,y,z=p
        dirt=.055+.10*(.5+.5*math.sin(x*63+z*47)*math.sin(y*71-z*27))
        amount=0.0
        if y<-.12:
            t=(z-.20)/.32;c,width=tear(max(0,min(1,t)))
            if -.06<t<1.07:
                d=abs(x-c.x)-width
                amount=max(0,1-max(0,d)/(.022+.012*math.sin(z*137)**2))*.88
            for start,drop in [(.032,.16),(.063,.14),(.081,.21)]:
                amount=max(amount,math.exp(-((x-start-.004*math.sin(z*21))/.008)**2)*max(0,1-abs(z-(.20-drop*.5))/(drop*.5))*.62)
            # Old, absorbed staining around one loose button and the torn seam.
            face=math.exp(-((x+.10+.015*math.sin(z*31))/.085)**2-((z-.80)/.105)**2)
            face*=.65+.35*math.sin(x*239+z*173)**2
            amount=max(amount,face*.88)
            runoff=math.exp(-((x+.105+.008*math.sin(z*53))/.012)**2)*max(0,1-abs(z-.65)/.14)
            amount=max(amount,runoff*.76)
        amount*=.80+.20*math.sin(x*227+z*139)*math.sin(z*191-y*73)
        base=(1-dirt,1-dirt*1.12,1-dirt*1.25)
        dark=(.12,.019,.012)
        attr.data[v.index].color=(*tuple(a*(1-amount)+b*amount for a,b in zip(base,dark)),1)
    for m in obj.data.materials:
        if m not in [fur,patch]:continue
        m['textile_vertex_colour']='TextileWear'

# Join by material to share this one compact mesh between both room instances.
for obj in list(bpy.context.scene.objects):
    obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.convert(target='MESH')
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    if not obj.data.color_attributes.get('TextileWear'):
        attr=obj.data.color_attributes.new(name='TextileWear',type='FLOAT_COLOR',domain='POINT')
        for value in attr.data:value.color=(1,1,1,1)
    for v in obj.data.vertices:v.co=obj.matrix_world@v.co
    obj.matrix_world.identity()
    for v in obj.data.vertices:v.co=Vector((v.co.x*3.65,v.co.y*3.65,(v.co.z+.03)*3.65))
    # Export real grain plus portable vertex pigmentation, sampled in Godot.
bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name='Tailored giant cloth mascot'
bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
for m in [fur,patch]:
    bs=m.node_tree.nodes.get('Principled BSDF');tex=next(n for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image.colorspace_settings.name!='Non-Color')
    vertex=m.node_tree.nodes.new('ShaderNodeVertexColor');vertex.layer_name='TextileWear'
    multiply=m.node_tree.nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1
    m.node_tree.links.new(tex.outputs['Color'],multiply.inputs[1]);m.node_tree.links.new(vertex.outputs['Color'],multiply.inputs[2]);m.node_tree.links.new(multiply.outputs[0],bs.inputs['Base Color'])
    # Custom material wiring is applied explicitly in Godot; exported maps stay intact.
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(body.data);bm.free()
bpy.ops.export_scene.gltf(filepath=str(OUT/'mascot-rabbit.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False,export_vertex_color='ACTIVE')
print('Original small rabbit adapted into a tailored giant: actual cloth tear, lining and irregular cotton; no long coat or flesh.',flush=True)
