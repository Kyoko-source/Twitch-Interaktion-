"""Original articulated left interaction hand, with continuous weighted skin."""
import bpy, math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
helper=ROOT/'tools/model-after-play-lift-v391.py'
exec(compile(helper.read_text(encoding='utf-8').split('\nclear()\nframe=')[0],str(helper),'exec'),globals())
OUT=ROOT/'games/kinderparadies/assets/tactile-v400';OUT.mkdir(exist_ok=True)
clear()
skin=mat('Interaction hand skin',(.42,.29,.21),.76)
p=skin.node_tree.nodes['Principled BSDF'];p.inputs['Subsurface Weight'].default_value=.06;p.inputs['Specular IOR Level'].default_value=.2
nail=mat('Natural interaction fingernails',(.44,.32,.24),.48)
cloth=mat('Folded nightguard sleeve',(.027,.043,.035),.95)
parts=[];segments=[]
parts.append(egg('Palm', (0,-.002,-.003),(.041,.049,.015),skin))
parts.append(egg('Thenar pad',(.029,-.018,.002),(.017,.027,.016),skin))
parts.append(path('Wrist',[(0,-.035,-.002),(0,-.066,-.003),(0,-.100,-.004)],[.026,.022,.022],skin))
finger_defs=[('index',-.029,.119),('middle',-.010,.132),('ring',.011,.123),('little',.030,.103)]
for i,(name,x,end) in enumerate(finger_defs):
    y0=.034 if i<3 else .023
    ys=[y0,y0+(end-y0)*.44,y0+(end-y0)*.75,end]
    pts=[(x,y, -.002-math.sin(j*math.pi/6)*.005) for j,y in enumerate(ys)]
    radius=.0085-i*.0006
    parts.append(path(name+' continuous skin',pts,[radius,radius*.94,radius*.82,radius*.54],skin))
    for j in range(3):segments.append((name+str(j+1),pts[j],pts[j+1],'palm' if j==0 else name+str(j)))
thumb=[(.028,-.022,.003),(.050,-.006,.005),(.061,.016,.004),(.064,.038,.001)]
parts.append(path('Thumb skin',thumb,[.012,.010,.0085,.0055],skin))
for j in range(3):segments.append(('thumb'+str(j+1),thumb[j],thumb[j+1],'palm' if j==0 else 'thumb'+str(j)))
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();hand=bpy.context.object;hand.name='Continuous weighted hand'
rem=hand.modifiers.new('Weld sculpted skin','REMESH');rem.mode='VOXEL';rem.voxel_size=.0011;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
smooth=hand.modifiers.new('Relaxed anatomy','SMOOTH');smooth.factor=.38;smooth.iterations=4;bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=hand.modifiers.new('First person skin budget','DECIMATE');dec.ratio=.36;bpy.ops.object.modifier_apply(modifier=dec.name)
pigment=hand.data.color_attributes.new(name='SkinPigment',type='FLOAT_COLOR',domain='POINT')
for i,v in enumerate(hand.data.vertices):
    q=hand.matrix_world@v.co;noise=math.sin(q.x*991+math.sin(q.z*787))*math.sin(q.y*1109)*.016
    pos=(q.x,q.z,-q.y)
    color=(.43+noise,.30+noise,.215+noise*.8,1)
    # Nail beds are painted on the continuous skinned surface itself. Separate
    # rigid nail shells can leave the deforming fingertip during a tight pinch.
    for name,x,end in finger_defs:
        oval=((pos[0]-x)/(.0054 if name!='little' else .0042))**2+((pos[1]-(end-.009))/.0075)**2
        if oval<1 and pos[2]>.0005:color=(.63+noise,.48+noise,.39+noise,1)
    if ((pos[0]-.062)/.005)**2+((pos[1]-.030)/.007)**2<1 and pos[2]>.006:color=(.63+noise,.48+noise,.39+noise,1)
    pigment.data[i].color=color
color=skin.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='SkinPigment';skin.node_tree.links.new(color.outputs['Color'],p.inputs['Base Color'])
objects=[hand]
# A single skeleton preserves continuous finger joints instead of moving beads.
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='InteractionRig';bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,a,b,parent in [('wrist',(0,-.10,0),(0,-.035,0),None),('palm',(0,-.035,0),(0,.035,0),'wrist')]+segments:
    bone=rig.data.edit_bones.new(name);bone.head=gp(a);bone.tail=gp(b)
    if parent:bone.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
all_segments=[('wrist',(0,-.11,0),(0,-.04,0),None),('palm',(0,-.04,0),(0,.035,0),None)]+segments
def distance(p,a,b):
    d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-a-d*t).length
for obj in objects:
    if 'fixed_bone' in obj:
        group=obj.vertex_groups.new(name=obj['fixed_bone']);group.add(list(range(len(obj.data.vertices))),1.,'REPLACE')
    else:
        groups={name:obj.vertex_groups.new(name=name) for name,_,_,_ in all_segments}
        for vertex in obj.data.vertices:
            pnt=obj.matrix_world@vertex.co
            ranked=sorted([(distance(pnt,gp(a),gp(b)),name) for name,a,b,_ in all_segments])[:2]
            weights=[1/max(.001,d)**5 for d,_ in ranked];total=sum(weights)
            for (_,name),weight in zip(ranked,weights):groups[name].add([vertex.index],weight/total,'REPLACE')
    mod=obj.modifiers.new('Articulated skin','ARMATURE');mod.object=rig;obj.parent=rig
    bpy.context.view_layer.objects.active=obj
    # UV-less skin uses vertex pigment and runtime micro normals.
    for attr in list(obj.data.attributes):
        if attr.name.startswith('sharp_'):obj.data.attributes.remove(attr)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'interaction-hand.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_normals=True,export_texcoords=True)
for obj in objects:
    bpy.context.view_layer.objects.active=obj
    dec=obj.modifiers.new('Browser close-up budget','DECIMATE');dec.ratio=.45 if obj==hand else .35;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.export_scene.gltf(filepath=str(OUT/'interaction-hand-web.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_normals=True,export_texcoords=True)
print('Interaction hand exported',len(hand.data.vertices),'skin vertices',flush=True)
