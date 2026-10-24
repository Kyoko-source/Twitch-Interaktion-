"""After Play's passage attacker: a deformed scan, excavated mouth and worn teeth.
Uses the existing attributed Lee Perry-Smith CC BY 3.0 geometry, no portrait image.
Run with Blender 4.5 in background mode. Coordinates are Blender Z-up metres.
"""
import bpy, bmesh, math, random, hashlib, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/passage-v280';OUT.mkdir(exist_ok=True)
SOURCE=ROOT/'tools/art-source/anatomy/LeePerrySmith.glb'
rng=random.Random(280)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
head=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for v in head.data.vertices:v.co=head.matrix_world@v.co
head.matrix_world.identity()
for o in list(bpy.context.scene.objects):
    if o!=head:bpy.data.objects.remove(o,do_unlink=True)
bm=bmesh.new();bm.from_mesh(head.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<-.95],context='VERTS');bm.to_mesh(head.data);bm.free()
head.data.materials.clear()
for a in list(head.data.color_attributes):head.data.color_attributes.remove(a)
for v in head.data.vertices:
    x,y,z=v.co;x*=.13;y=y*.12+.035;z=1.78+z*.13-1.96
    jaw=max(0,min(1,(-z-.08)/.16))
    v.co=(x*(1-.12*jaw),y-.025*jaw,z-.13*jaw+.012*math.sin(x*23))
bpy.context.view_layer.objects.active=head
mod=head.modifiers.new('Facial detail','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
def material(name,c,r=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=r;return m
skin=material('Bruised desiccated skin',(.5,.42,.34));dark=material('Unlit oral cavity',(.0008,.0003,.0004),1);tooth=material('Uneven stained enamel',(.38,.31,.17),.68)
head.data.materials.append(skin);head.name='Deformed anatomical head - Lee Perry-Smith derivative'
def egg(name,p,s,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=p);o=bpy.context.object;o.name=name;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
    for f in o.data.polygons:f.use_smooth=True
    return o
def cut(p,s):
    cutter=egg('Cavity cutter',p,s,dark);bpy.context.view_layer.objects.active=head;mod=head.modifiers.new('Excavated flesh','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
cut((0,-.25,-.245),(.095,.18,.175))
egg('Deep open throat',(0,-.10,-.245),(.082,.065,.153),dark)
for side in [-1,1]:
    cut((side*.083,-.23,.048),(.050,.12,.038))
    egg('Black eye recess',(side*.083,-.13,.048),(.044,.043,.031),dark)
for side in [-1,1]:
    for i in range(7):
        x=(i-3)*.017;length=rng.uniform(.028,.052);z=-.125 if side==1 else -.36
        bpy.ops.mesh.primitive_cone_add(vertices=14,radius1=.003 if side==1 else .008,radius2=.008 if side==1 else .003,depth=length,location=(x,-.245,z-side*length*.35));o=bpy.context.object;o.name='Broken tooth';o.rotation_euler.y=rng.uniform(-.23,.23);o.data.materials.append(tooth)
for f in head.data.polygons:f.use_smooth=True
attr=head.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
for i,v in enumerate(head.data.vertices):
    x,y,z=v.co;n=.5+.23*math.sin(x*187+y*83+z*61)+.2*math.sin(x*59-y*173+z*109)
    c=Vector((.46,.39,.31))*(.73+n*.35)
    mouth=math.exp(-((x/.105)**6+((z+.24)/.18)**4)) if y<-.055 else 0
    tear=max(math.exp(-((x-.086)/.016)**2),math.exp(-((x+.082)/.013)**2))*max(0,1-abs(z+.06)/.20) if y<-.05 else 0
    blood=min(.95,mouth*.85+tear*.8);c=c.lerp(Vector((.07,.002,.008)),blood*(.7+n*.3))
    attr.data[i].color=(*c,1)
node=skin.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Pigment';skin.node_tree.links.new(node.outputs['Color'],skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
normal=bpy.data.images.load(str(SOURCE.parent/'Infinite-Level_02_Tangent_SmoothUV.jpg'));normal.colorspace_settings.name='Non-Color'
tex=skin.node_tree.nodes.new('ShaderNodeTexImage');tex.image=normal;nm=skin.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.48;skin.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);skin.node_tree.links.new(nm.outputs['Normal'],skin.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
bpy.ops.export_scene.gltf(filepath=str(OUT/'passage-head.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
(OUT/'LICENSE.txt').write_text('Passage head: derivative of Infinite, 3D Head Scan by Lee Perry-Smith (CC BY 3.0).\nSource: https://www.triplegangers.com/ and https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf/LeePerrySmith\nLicense: https://creativecommons.org/licenses/by/3.0/\nChanges for After Play: distorted lower face, excavated eye and mouth cavities, original teeth and vertex-painted wounds. No portrait textures used.\nOriginal attribution and source hashes are also included in Head-Attribution.txt and anatomy-provenance.json.\n','utf8')
(OUT/'provenance.json').write_text(json.dumps({'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'generated_by':'tools/model-after-play-passage-v280.py','license':'CC BY 3.0','changes':'Deformed scan; carved cavities; original teeth; painted wounds','output_sha256':hashlib.sha256((OUT/'passage-head.glb').read_bytes()).hexdigest()},indent=2),'utf8')
