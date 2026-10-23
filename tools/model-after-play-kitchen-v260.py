"""Original manufactured kitchen kit. Blender 4.5; dimensions in Godot metres.

Inset enamel panels, folded steel edges, oven interior, burners, hardware,
refrigerator seals, louvres and grime. Existing CC0 Poly Haven micro normals.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'games/kinderparadies/assets'
OUT=ASSETS/'kitchen-v260';OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(260)

def mat(name,color,metal=0,rough=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
enamel=mat('Chipped hospital green enamel',(.21,.27,.225),.2,.76)
cream=mat('Yellowed ivory enamel',(.54,.51,.38),.12,.79)
steel=mat('Brushed greasy steel',(.30,.34,.31),.82,.43)
black=mat('Black rubber seals and soot',(.024,.029,.022),0,.94)
rust=mat('Oxidised exposed steel',(.17,.07,.029),.32,.96)
glass=mat('Smoked oven glass',(.035,.043,.035),.25,.25)
white=mat('Faded markings',(.68,.66,.51),0,.91)

def coord(p): return (p[0],-p[2],p[1])
def box(name,p,size,m,bevel=.009):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded folded manufactured edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(m);o.modifiers.new('Weighted production normals','WEIGHTED_NORMAL')
    for poly in o.data.polygons: poly.use_smooth=True
    return o
def tube(name,a,b,r,m):
    a,b=Vector(coord(a)),Vector(coord(b));d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=d.length,location=(a+b)*.5);o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
    for poly in o.data.polygons: poly.use_smooth=True
    return o
def handle(name,p,axis='x',length=.25):
    x,y,z=p;dx=length/2 if axis=='x' else 0;dz=length/2 if axis=='z' else 0
    for sign in [-1,1]: tube(name+' mounting', (x+dx*sign,y,z+dz*sign),(x+dx*sign,y,z+dz*sign+.045) if axis=='x' else (x+.045,y,z+dz*sign),.012,steel)
    tube(name+' bar',(x-dx,y,z-dz+.045) if axis=='x' else (x+.045,y,z-dz),(x+dx,y,z+dz+.045) if axis=='x' else (x+.045,y,z+dz),.015,steel)

# Long west-wall units. Their inset fronts face east (+X).
box('Recessed cabinet plinth',(-16.70,.105,-18),(.88,.19,5.8),black)
box('Counter cabinet shell',(-16.70,.45,-18),(.96,.65,5.8),enamel,.024)
for index,z in enumerate([-20.30,-19.15,-18.0,-16.85,-15.70]):
    box('Cabinet shadow reveal',(-16.205,.55,z),(.018,.78,1.12),black,.002)
    box('Pressed enamel frame',(-16.18,.55,z),(.047,.75,1.08),cream,.016)
    box('Inset green door panel',(-16.148,.55,z),(.024,.60,.92),enamel,.018)
    handle('Cabinet handle',(-16.12,.80,z),'z',.27)
    for y in [.28,.79]:
        tube('Exposed cabinet hinge',(-16.125,y-.045,z-.49),(-16.125,y+.045,z-.49),.016,steel)
    for k in range(9):
        yy=rng.uniform(.24,.87);zz=z+rng.uniform(-.47,.47)
        scar=box('Enamel edge wear',(-16.132,yy,zz),(.004,rng.uniform(.006,.022),rng.uniform(.008,.045)),rust,.002)
for za,zb in [(-21.05,-17.16),(-16.14,-14.95)]:
    box('Rolled counter worktop',(-16.65,1.03,(za+zb)/2),(1.14,.08,zb-za),steel,.026)
for x in [-17.165,-16.135]: box('Sink rim support',(x,1.03,-16.65),(.11,.08,1.02),steel,.014)
tube('Counter rolled front',(-16.077,1.04,-21.01),(-16.077,1.04,-14.99),.018,steel)
box('Counter wall upstand',(-17.18,1.12,-18.0),(.035,.18,6.0),steel)

# Cooker: real recessed oven, gasket, layered door and calibrated knobs.
cx,cz=-13.25,-19.25
for x in [-.36,.36]:
    for z in [-.43,.43]: tube('Adjustable cooker foot',(cx+x,.02,cz+z),(cx+x,.16,cz+z),.038,black)
box('Cooker carcass',(cx,.52,cz),(.95,.78,1.1),cream,.025)
box('Cooktop perimeter',(cx,.935,cz),(1.0,.055,1.14),steel,.02)
box('Oven black gasket',(cx+.481,.47,cz),(.016,.53,.83),black,.028)
box('Oven door inset',(cx+.501,.47,cz),(.03,.48,.78),enamel,.025)
box('Oven glass',(cx+.522,.47,cz),(.008,.32,.58),glass,.025)
for z in [-.23,.23]:
    tube('Oven shelf visible behind glass',(cx+.53,.40,cz+z),(cx+.53,.41,cz+z),.008,steel)
handle('Oven horizontal handle',(cx+.52,.75,cz),'z',.65)
for z in [-.33,-.11,.11,.33]:
    tube('Knob steel bezel',(cx+.48,.84,cz+z),(cx+.507,.84,cz+z),.045,steel)
    tube('Bakelite cooker dial',(cx+.507,.84,cz+z),(cx+.548,.84,cz+z),.033,black)
    box('Knob pointer',(cx+.55,.86,cz+z),(.004,.019,.004),white,.001)
for z in [-.27,.27]:
    for x in [-.23,.23]:
        tube('Burner recess',(cx+x,.961,cz+z),(cx+x,.971,cz+z),.188,black)
        for ring in [.09,.14]:
            for i in range(20):
                a=i*math.tau/20;b=(i+1)*math.tau/20
                tube('Cast iron burner ring',(cx+x+math.cos(a)*ring,.982,cz+z+math.sin(a)*ring),(cx+x+math.cos(b)*ring,.982,cz+z+math.sin(b)*ring),.009,rust)
        for i in [-1,1]: tube('Burner trivet',(cx+x-.19,.99,cz+z+i*.11),(cx+x+.19,.99,cz+z+i*.11),.012,steel)
for z in [i*.055-.41 for i in range(16)]: box('Cooker lower vent',(cx+.483,.19,cz+z),(.009,.04,.023),black,.003)

# Vintage refrigerator, substantial gaskets, curved separate doors, hinges.
fx,fz=-11.0,-21.7
box('Refrigerator rounded body',(fx,1.015,fz),(1.25,1.99,.95),cream,.065)
for side in [-1,1]:
    for z in [-.34,.34]: tube('Refrigerator foot',(fx+side*.48,.015,fz+z),(fx+side*.48,.12,fz+z),.035,black)
for y,h in [(1.61,.64),(.71,1.10)]:
    box('Refrigerator seal',(fx,y,fz+.478),(1.15,h,.025),black,.025)
    box('Refrigerator pressed door',(fx,y,fz+.51),(1.12,h-.026,.068),enamel,.042)
    box('Refrigerator inset trim',(fx,y,fz+.55),(1.0,h-.15,.018),cream,.026)
    for yy in [y-.14,y+.14]: tube('Fridge handle post',(fx-.38,yy,fz+.57),(fx-.38,yy,fz+.64),.014,steel)
    tube('Fridge vertical handle',(fx-.38,y-.14,fz+.64),(fx-.38,y+.14,fz+.64),.022,steel)
    for yy in [y-h*.31,y+h*.31]: box('Fridge hinge',(fx+.56,yy,fz+.54),(.055,.10,.055),steel,.013)
for i in range(12): box('Fridge bottom grille',(fx-.44+i*.08,.15,fz+.49),(.037,.10,.022),black,.004)
box('Worn manufacturer badge',(fx+.27,1.73,fz+.57),(.29,.065,.008),steel,.008)
for i in range(6): box('Badge lettering',(fx+.17+i*.035,1.73,fz+.578),(.012,.027,.002),black,.001)

# Tight cracks and grime collect along folded edges, not giant flat stains.
for i in range(50):
    z=rng.uniform(-20.8,-15.1);y=rng.uniform(.2,.85)
    box('Cabinet grease speck',(-16.132,y,z),(.003,rng.uniform(.002,.009),rng.uniform(.004,.018)),rust,.001)

# Merge by material to keep draw calls practical in Web; preserve useful names.
for m in [enamel,cream,steel,black,rust,glass,white]:
    bpy.ops.object.select_all(action='DESELECT');objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==m]
    for o in objects: o.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();bpy.context.object.name=m.name
bpy.ops.export_scene.gltf(filepath=str(OUT/'industrial-kitchen.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('KITCHEN_V260',len(bpy.context.scene.objects),flush=True)
