"""Dense groomed mesh fur and conforming blood layers; Blender 4.5, original geometry."""
import bpy,bmesh,math,random,bisect
from pathlib import Path
from mathutils import Vector

SOURCE=Path(__file__).with_name('model-after-play-v240.py')
exec(compile(SOURCE.read_text(encoding='utf-8').split('# Geometric fur tufts')[0],str(SOURCE),'exec'),globals())
OUT=ROOT/'games/kinderparadies/assets/mascot-v250';OUT.mkdir(exist_ok=True)
rng=random.Random(250)
image=bpy.data.images.load(str(ASSETS/'presentation-v250/blood-texture.png'))
import numpy as np
pixels=np.array(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)

def neutral(p):
    variation=.5+.18*math.sin(p.x*13+p.z*7)+.14*math.sin(p.y*23-p.z*17)
    return mix((.48,.43,.34),(.77,.70,.55),variation)

fur.name='CC0 teddy fur, groomed undercoat'
for obj in parts:
    if obj.type=='MESH' and len(obj.data.materials) and obj.data.materials[0]==fur: repaint(obj,neutral)
fur_parts=[o for o in parts if o.type=='MESH' and len(o.data.materials) and o.data.materials[0]==fur]

# Coordinates in the actual authored model (Blender Z-up); front is negative Y.
regions=[(-.62,.80,1.28,1.42),(-.83,2.70,.99,.77),(-1.5,.72,.65,.72)]
def blood_uv(p):
    if p.y>-.40:return None
    for x,z,width,height in regions:
        u=(p.x-x)/width;v=(p.z-z)/height
        if 0<u<1 and 0<v<1:return (u,v)
    return None

def blood_at(p):
    uv=blood_uv(p)
    if uv is None:return 0
    return float(pixels[min(image.size[1]-1,int(uv[1]*image.size[1])),min(image.size[0]-1,int(uv[0]*image.size[0])),3])

coat=mat('Mascot wet blood conforming film',(.18,.006,.010),.20)
coat.use_nodes=True;bs=coat.node_tree.nodes.get('Principled BSDF');tex=coat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
coat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);coat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
bs.inputs['Coat Weight'].default_value=.42;bs.inputs['Coat Roughness'].default_value=.16
coat.surface_render_method='DITHERED'
clot=mat('Mascot blood-matted fibres',(.075,.004,.008),.42,paint=True)
hair=mat('Mascot Fur Fibres',(.65,.56,.41),.9,paint=True)

# A physical surface offset conforms to the sculpt rather than hovering as a quad.
body.data.calc_loop_triangles();bv=[];bf=[];bu=[]
for triangle in body.data.loop_triangles:
    points=[body.matrix_world@body.data.vertices[i].co for i in triangle.vertices]
    if triangle.normal.y>-.28:continue
    uv=[blood_uv(p) for p in points]
    if any(p is None for p in uv):continue
    if max(blood_at(p) for p in points)<.08:continue
    n=triangle.normal.normalized();base=len(bv)
    bv.extend(p+n*.004 for p in points);bu.extend(uv);bf.append((base,base+1,base+2))
mesh=bpy.data.meshes.new('Conforming coagulated blood film');mesh.from_pydata(bv,[],bf);mesh.update()
obj=bpy.data.objects.new('Blood absorbed around open seams',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(coat);parts.append(obj)
uvlayer=mesh.uv_layers.new(name='Blood projection')
for loop in mesh.loops:uvlayer.data[loop.index].uv=bu[loop.vertex_index]

# Sample surface area, not polygon counts: uniform fur density despite sculpt topology.
triangles=[];weights=[];total=0
for skin in fur_parts:
    skin.data.calc_loop_triangles()
    for tri in skin.data.loop_triangles:
        ps=[skin.matrix_world@skin.data.vertices[i].co for i in tri.vertices]
        ns=[(skin.matrix_world.to_3x3()@skin.data.vertices[i].normal).normalized() for i in tri.vertices]
        area=(ps[1]-ps[0]).cross(ps[2]-ps[0]).length*.5
        if area<1e-8:continue
        total+=area;weights.append(total);triangles.append((ps,ns))

def groom(count):
    verts=[];faces=[];colours=[];material_ids=[]
    for strand in range(count):
        ps,ns=triangles[bisect.bisect_left(weights,rng.random()*total)]
        a=math.sqrt(rng.random());b=rng.random();ws=(1-a,a*(1-b),a*b)
        p=sum((ps[i]*ws[i] for i in range(3)),Vector());n=sum((ns[i]*ws[i] for i in range(3)),Vector()).normalized()
        if p.z<.095:continue
        tangent=n.cross(Vector((0,0,1)))
        if tangent.length<.05:tangent=n.cross(Vector((1,0,0)))
        tangent.normalize();bitangent=n.cross(tangent).normalized()
        wet=blood_at(p)>.35 and n.y<-.2
        length=rng.uniform(.04,.09)*(.42 if wet else 1)
        radius=rng.uniform(.00065,.00115)*(2.2 if wet else 1)
        lean=tangent*math.sin(p.x*23+p.z*13)*length*.36+bitangent*math.sin(p.y*19-p.z*17)*length*.2
        base=len(verts);color=(.16,.008,.012) if wet else neutral(p)
        for row in range(3):
            t=row/3;center=p+n*(.001+length*t)+lean*t*t+Vector((0,0,-length*.40*t*t))
            for k in range(3):
                angle=k*math.tau/3
                verts.append(center+(tangent*math.cos(angle)+bitangent*math.sin(angle))*radius*(1-t*.8))
                colours.append((*tuple(c*(.75+.25*t) for c in color),1))
        verts.append(p+n*length+lean+Vector((0,0,-length*.4)));colours.append((*color,1))
        faces.append((base+2,base+1,base));material_ids.append(1 if wet else 0)
        for row in range(2):
            for k in range(3):
                j=(k+1)%3;faces.append((base+row*3+k,base+row*3+j,base+(row+1)*3+j,base+(row+1)*3+k));material_ids.append(1 if wet else 0)
        for k in range(3):faces.append((base+6+k,base+6+(k+1)%3,base+9));material_ids.append(1 if wet else 0)
    mesh=bpy.data.meshes.new('Groomed fine three-dimensional fibres');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Dense curved and matted fur',mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(hair);obj.data.materials.append(clot)
    attr=mesh.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
    for i,c in enumerate(colours):attr.data[i].color=c
    for polygon,material in zip(mesh.polygons,material_ids):polygon.material_index=material;polygon.use_smooth=True
    return obj

fine=groom(56000);print('Native fur strands authored',len(fine.data.vertices)//10,flush=True)
export('mascot-native.glb')
bpy.data.objects.remove(fine,do_unlink=True)
light=groom(14000);print('Web fur strands authored',len(light.data.vertices)//10,flush=True)
export('mascot-web.glb')
print('Finished groomed fur editions with original blood film.',flush=True)
