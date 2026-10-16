"""Original metre-scale PVC attraction; Blender 4.5 background authoring."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/hero'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def material(name,color,roughness=.4):
    m=bpy.data.materials.new(name);m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=roughness
    noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=95;noise.inputs['Detail'].default_value=2
    bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.025
    m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],s.inputs['Normal'])
    return m

green=material('Faded olive PVC',(.21,.29,.115),.36)
yellow=material('Yellowed welded PVC',(.48,.43,.17),.42)
dark=material('Deep dark mouth',(.018,.029,.016),.72)
ivory=material('Dirty inflatable teeth',(.68,.63,.4),.4)
seam=material('Heat welded edge',(.13,.18,.075),.55)
eye=material('Pale painted eyes',(.67,.64,.41),.3)
pupil=material('Black split pupils',(.012,.015,.008),.28)
rust=material('Rusted attachment rings',(.12,.085,.05),.7)

def smooth(obj,m):
    obj.data.materials.append(m)
    for f in obj.data.polygons:f.use_smooth=True
    return obj

def blob(name,pos,size,m,wrinkle=.008):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,location=pos)
    obj=bpy.context.object;obj.name=name
    for v in obj.data.vertices:
        p=v.co.copy();w=1+wrinkle*math.sin(p.z*47+p.x*17)*math.sin(p.y*35)
        v.co=Vector((p.x*size[0]*w,p.y*size[1]*w,p.z*size[2]*w))
    return smooth(obj,m)

def line(name,points,r,m):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=2;data.bevel_depth=r;data.bevel_resolution=2
    poly=data.splines.new('POLY');poly.points.add(len(points)-1)
    for p,xyz in zip(poly.points,points):p.co=(*xyz,1)
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(m);return obj

def loft(name,centers,radii,m):
    vertices=[];faces=[];n=32
    for (x,y,z),(rx,rz) in zip(centers,radii):
        for i in range(n):
            a=i*math.tau/n;vertices.append((x+math.cos(a)*rx,y,z+math.sin(a)*rz))
    for j in range(len(centers)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple((len(centers)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);smooth(obj,m)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    return obj

blob('Main sealed bottom mattress',(0,0,.39),(2.3,3.9,.38),green)
# Individual pressure chambers, seams and wear marks on the jumping mattress.
for j in range(14):
    y=-3.15+j*.46
    blob('Inflated bed chamber',(0,y,.63),(1.71,.28,.19),yellow)
    line('Welded mattress channel',[(-1.55,y-.24,.68),(0,y-.24,.72),(1.55,y-.24,.68)],.012,seam)
for side in [-1,1]:
    blob('Raised side bolster',(side*2,0,.88),(.37,3.75,.57),green)
    line('Full length welded rail',[(side*2.28,-3.25+i*.2,.78+math.sin(i*.5)*.01) for i in range(34)],.018,seam)
    for y in [-2.1,1.65]:
        limb=blob('Sprawling inflated foot',(side*2.47,y,.34),(.72,.81,.28),green);limb.rotation_euler.z=side*.3
        for k in range(3):
            blob('Soft rounded claw',(side*(2.9+k*.06),y-.45+k*.27,.28),(.24,.17,.15),ivory)
    # Huge cheeks and deliberately mismatched stalked eyes.
    blob('Crocodile jaw cheek',(side*1.82,-2.95,1.63),(.58,1.35,1.22),green)
    blob('Heavy eye socket',(side*1.28,-3.25,2.72),(.59,.68,.6),green)
    blob('Bulging pale eye',(side*1.28,-3.79,2.81),(.4,.21,.38),eye)
    blob('Vertical split pupil',(side*1.28-.035,-3.985,2.8+side*.035),(.06,.025,.26),pupil,0)
    line('Painted eye crack',[(side*1.23,-4.009,3.02),(side*1.31,-4.01,2.88),(side*1.2,-4.009,2.74)],.007,seam)
    for i in range(9):
        y=-4.3+i*.29
        tooth=blob('Upper soft hanging tooth',(side*1.52,y,1.94+i*.025),(.16,.18,.34),ivory);tooth.rotation_euler.y=-side*.16
        blob('Lower soft tooth',(side*1.5,y,.94),(.14,.17,.25),ivory)
    # Anchor weld and safety straps with actual steel loops.
    for y in [-2.7,.5,3]:
        line('Anchor webbing',[(side*2.23,y,.35),(side*2.65,y,.12)],.045,yellow)
        bpy.ops.mesh.primitive_torus_add(major_radius=.09,minor_radius=.016,major_segments=24,minor_segments=8,location=(side*2.67,y,.11));smooth(bpy.context.object,rust)
loft('Broad lower smiling snout',[(0,-4.85,.46),(0,-4.7,.5),(0,-3.8,.61),(0,-2.8,.68)],[(.1,.08),(1.3,.2),(1.7,.25),(1.7,.3)],yellow)
loft('Upper open crocodile snout',[(0,-4.85,2.05),(0,-4.6,2.2),(0,-3.7,2.35),(0,-2.6,2.37)],[(.08,.05),(1.3,.25),(1.7,.38),(1.7,.43)],green)
line('Crooked lower smile',[(-1.55,-3.7,.72),(-1.3,-4.55,.65),(0,-4.79,.62),(1.3,-4.55,.65),(1.55,-3.7,.72)],.028,seam)
for side in [-1,1]:
    blob('Raised nostril',(side*.62,-4.2,2.53),(.24,.28,.12),green)
    blob('Nostril paint',(side*.62,-4.35,2.61),(.13,.12,.024),dark)
loft('Swept inflated tail',[(0,2.5,.5),(.15,3.3,.5),(.5,4.1,.45),(1.1,4.8,.4),(1.65,5.25,.35),(1.9,5.45,.32)],[(1.3,.45),(1.1,.4),(.75,.32),(.43,.24),(.19,.15),(.02,.025)],green)
for j in range(9):
    y=1.7+j*.39;x=max(0,(y-3)*.5)
    spike=blob('Soft dorsal ridges',(x,y,.95-j*.045),(.26-j*.017,.24,.32-j*.022),green);spike.rotation_euler.x=.3
line('Tail welded seam',[(.1,3,.85),(.4,3.8,.76),(.9,4.5,.65),(1.5,5.12,.48),(1.9,5.44,.34)],.018,seam)
for side in [-1,1]:
    for j in range(6):
        blob('Painted faded scales',(side*2.29,-2.3+j*.85,1),(.018,.22,.12),seam,0)
# Blower inlet and modelled capped valve.
blob('Inflation pipe',(1.5,3.55,.4),(.21,.6,.21),yellow)
bpy.ops.mesh.primitive_torus_add(major_radius=.12,minor_radius=.028,location=(-2.25,1.5,.8),rotation=(0,math.pi/2,0));smooth(bpy.context.object,seam)
blob('Valve cap',(-2.28,1.5,.8),(.04,.12,.12),dark)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH');bpy.context.view_layer.objects.active=bpy.context.selected_objects[0];bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=str(OUT/'inflatable-crocodile.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('AUTHORED inflatable-crocodile',flush=True)
