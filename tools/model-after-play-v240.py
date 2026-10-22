"""Original sewn mascot and first-person telephone/hand; Blender 4.5 background.

Real geometry, no portrait planes. Fur surface: Poly Haven Curly Teddy Natural CC0.
"""
import bpy,bmesh,math,random
from pathlib import Path
from mathutils import Vector

SOURCE=Path(__file__).with_name('model-nachtwache-props-v180.py')
exec(compile(SOURCE.read_text(encoding='utf8').split('clear();body=[];head=[]')[0],str(SOURCE),'exec'),globals())
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/polish-v240';OUT.mkdir(exist_ok=True)
ASSETS=ROOT/'games/kinderparadies/assets'
rng=random.Random(240)

def merged_skin(objects,name,voxel):
    o=batch(objects,name);bpy.context.view_layer.objects.active=o
    rem=o.modifiers.new('Continuous sculpted form','REMESH');rem.mode='VOXEL';rem.voxel_size=voxel;rem.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=rem.name)
    sm=o.modifiers.new('Sculpt relaxation','SMOOTH');sm.factor=.45;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
    return o

def repaint(o,painter):
    for attr in list(o.data.color_attributes):o.data.color_attributes.remove(attr)
    attr=o.data.color_attributes.new(name='Pigment',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(o.data.vertices):attr.data[i].color=(*painter(o.matrix_world@v.co),1)

def rope(name,points,radius,material,parts):
    return line(name,[tuple(p) for p in points],radius,material,parts)

clear();parts=[];core=[]
fur=mat('CC0 teddy fur, stained pigment',(.50,.39,.26),.98,paint=True)
dark=mat('Missing button cavity',(.006,.004,.003),.99)
blood=mat('Soaked clotted seams',(.105,.008,.012),.48)
fresh=mat('Dried burgundy stitching',(.25,.013,.02),.67)
patch=mat('Aged woven repairs',(.25,.19,.12),.99)
thread=mat('Waxed black thread',(.022,.015,.01),.99)
cotton=mat('Exposed yellowed stuffing',(.41,.36,.25),1)
eye=mat('Scratched glass button',(.055,.032,.014),.28)

def stains(p):
    x,y,z=p;n=.5+.25*math.sin(x*9+y*7+z*11)+.25*math.sin(x*27-z*14)
    c=mix((.28,.23,.15),(.62,.51,.34),n)
    # Irregular face runoff, torn torso and saturated left sleeve.
    marks=max(math.exp(-((x+.32)/.46)**2-((z-2.9)/.5)**2)*max(0,-y),
              math.exp(-((x-.32)/.35)**2-((z-1.8)/.8)**2)*max(0,-y),
              math.exp(-((x+1.05)/.35)**2-((z-1.4)/.8)**2))
    streak=(math.sin(x*38+z*.9)+math.sin(x*19-z*.6))*.12
    return mix(c,(.20+n*.08,.009+n*.012,.012+n*.009),min(1,max(0,marks*3+streak-.12)))

sphere('Uneven slumped torso',(0,.02,1.53),(.94,.66,1.18),fur,core)
sphere('Sagging belly',(.17,-.22,1.12),(.86,.64,.75),fur,core)
sphere('Twisted neck',(-.13,-.03,2.49),(.5,.45,.58),fur,core)
head=sphere('Collapsed asymmetric head',(-.22,-.20,3.12),(.89,.66,.82),fur,core)
head.rotation_euler.y=.18;head.rotation_euler.x=.13
for side in [-1,1]:
    a=sphere('Long slumped stuffed arm',(side*.95,-.05,1.55),(.39,.38,.92 if side<0 else .72),fur,core);a.rotation_euler.y=side*.28
    sphere('Flattened sleeve paw',(side*1.15,-.24,.83 if side<0 else 1.04),(.42,.42,.35),fur,core)
    sphere('Heavy splayed foot',(side*.72,-.67,.34),(.57,.86,.34),fur,core)
    sphere('Stuffed bent thigh',(side*.56,-.16,.70),(.48,.51,.64),fur,core)
body=merged_skin(core,'Continuous deformed sewn mascot',.032)
body.data.materials.clear();body.data.materials.append(fur);repaint(body,stains);parts.append(body)

def ear(name,points,width):
    vs=[];fs=[];rings=50;around=24
    for j in range(rings):
        t=j/(rings-1);c=(1-t)**3*points[0]+3*(1-t)**2*t*points[1]+3*(1-t)*t*t*points[2]+t**3*points[3]
        r=.035+width*math.sin(t*math.pi)**.7
        for k in range(around):
            a=k*math.tau/around;vs.append(c+Vector((math.cos(a)*r,math.sin(a)*r*.40,0)))
    for j in range(rings-1):
        for k in range(around):a=j*around+k;fs.append((a,j*around+(k+1)%around,(j+1)*around+(k+1)%around,a+around))
    m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,fur,parts,stains)
    ev=[];ef=[]
    for row in range(41):
        t=.06+row/40*.88;c=(1-t)**3*points[0]+3*(1-t)**2*t*points[1]+3*(1-t)*t*t*points[2]+t**3*points[3]
        r=width*math.sin(t*math.pi)**.7
        for col in range(7):
            u=col/6*2-1;ev.append(c+Vector((u*r*.65,-.061-r*.40-.008*math.cos(u*math.pi),0)))
    for row in range(40):
        for col in range(6):a=row*7+col;ef.append((a,a+1,a+8,a+7))
    em=bpy.data.meshes.new('Continuous inner ear cloth');em.from_pydata(ev,[],ef);em.update();eo=bpy.data.objects.new('Inset sewn ear lining',em);bpy.context.collection.objects.link(eo);finish(eo,patch,parts)
ear('Tall buckled ear',[Vector((-.65,-.09,3.57)),Vector((-.94,.02,4.55)),Vector((-.9,.1,5.22)),Vector((-.39,-.4,4.86))],.25)
ear('Broken hanging ear',[Vector((.2,-.04,3.66)),Vector((.63,.0,4.68)),Vector((1.01,-.12,4.37)),Vector((1.02,-.46,3.83))],.28)

# The empty eye is a deep cut in the actual head; the other is a broken button.
cutter=sphere('Eye socket cutter',(-.54,-.79,3.27),(.25,.26,.28),dark,[])
bpy.context.view_layer.objects.active=body;mod=body.modifiers.new('Missing eye depression','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
sphere('Deep missing eye',(-.54,-.63,3.27),(.24,.095,.25),dark,parts)
button=sphere('Single hanging button',(.11,-.812,3.24),(.20,.055,.20),eye,parts);button.rotation_euler.y=.16
for side in [-1,1]:
    rope('Button cross stitch',[(.11+side*.075,-.872,3.31),(.11-side*.075,-.875,3.17)],.012,cotton,parts)
sphere('Torn triangular nose',(-.17,-.92,2.96),(.145,.10,.10),patch,parts)
mouth=[(-.73,-.74,2.93),(-.58,-.87,2.74),(-.26,-.90,2.66),(.07,-.85,2.73),(.43,-.69,2.99)]
rope('Split black stitched smile',mouth,.052,dark,parts)
for i in range(18):
    t=i/17;x=-.68+t*1.05;z=2.69+.32*(abs(t-.46)*2)**1.6;y=-.88+.20*(abs(t-.46)*2)**2
    rope('Uneven mouth stitches',[(x-.018,y,z-.045),(x+.028,y-.012,z+.065)],.009,thread,parts)
for i in range(12):
    x=-.68+rng.random()*1.12;z=2.68+rng.random()*.15;y=-.86+.16*(abs(x+.2))
    sphere('Stuffing in split mouth',(x,y,z),(.037,.018,.025),cotton,parts)
for x,z in [(.39,1.72),(-.23,2.32),(-.77,.49),(1.13,1.2)]:
    patch_obj=sphere('Thick stitched repair patch',(x,-.62,z),(.20,.025,.25),patch,parts);patch_obj.rotation_euler.y=.2
    for i in range(10):
        a=i*math.tau/10;rope('Repair blanket stitch',[(x+math.cos(a)*.20,-.654,z+math.sin(a)*.25),(x+math.cos(a)*.17,-.663,z+math.sin(a)*.21)],.008,thread,parts)
rope('Torn abdomen seam',[(.23,-.77,.91),(.4,-.83,1.15),(.32,-.79,1.4),(.39,-.69,1.7),(.29,-.61,1.94)],.065,blood,parts)
for i in range(22):
    z=.95+i*.044;x=.34+math.sin(i*.7)*.07
    rope('Loose torso stitching',[(x-.09,-.80,z),(x+.10,-.85,z+.035)],.008,thread,parts)
    if i%3==0:sphere('Exposed cotton clump',(x,-.84,z),(.055,.04,.045),cotton,parts)
# Geometric fur tufts survive GLB export and both renderers, no alpha overdraw.
bpy.context.view_layer.update();verts=[];faces=[];colours=[]
for poly in body.data.polygons:
    if rng.random()>.10:continue
    p=body.matrix_world@poly.center;n=poly.normal
    if p.z<.12:continue
    tangent=n.cross(Vector((0,0,1)))
    if tangent.length<.1:tangent=n.cross(Vector((1,0,0)))
    tangent.normalize();bitangent=n.cross(tangent).normalized();length=rng.uniform(.012,.040);width=rng.uniform(.0012,.0028);idx=len(verts)
    for height,radius in [(0,width),(.55,width*.7)]:
        c=p+n*(length*height+.001)+Vector((0,0,-length*height*.18))
        for k in range(3):a=k*math.tau/3;verts.append(c+(tangent*math.cos(a)+bitangent*math.sin(a))*radius)
    verts.append(p+n*length+Vector((0,0,-length*.22)));faces.append((idx+2,idx+1,idx))
    for k in range(3):j=(k+1)%3;faces.extend([(idx+k,idx+j,idx+3+j,idx+3+k),(idx+3+k,idx+3+j,idx+6)])
m=bpy.data.meshes.new('Individual clumped pile');m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new('Silhouette fur tufts',m);bpy.context.collection.objects.link(o);finish(o,fur,parts,stains)
for i in range(16):
    x=-.75+rng.random()*1.3;z=1.3+rng.random()*1.9
    rope('Crusted runoff in fur',[(x,-.73,z),(x+.025,-.76,z-.18),(x-.01,-.76,z-.35)],.003,fresh,parts)
batch(parts,'HappylandMascot');export('mascot-rabbit.glb')

# Upgrade the existing purpose-built grip: sub-millimetre skin continuity,
# knuckle folds, tendon contours, natural nails and an actual cloth cuff.
clear();parts=[]
source=ASSETS/'props/phone-grip.glb';bpy.ops.import_scene.gltf(filepath=str(source))
for o in list(bpy.context.scene.objects):
    if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True);continue
    o.name='Anatomical phone grip';parts.append(o)
    for m in o.data.materials:
        m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
        if p:p.inputs['Roughness'].default_value=.64;p.inputs['Subsurface Weight'].default_value=.065
skin=mat('Knuckle crease skin',(.24,.17,.12),.8)
def gp(p):return Vector((p[0],-p[2],p[1]))
for i,y in enumerate([.039,.018,-.003,-.024]):
    for j in range(3):
        x=.042-j*.0005;pts=[gp((x,y-.004,-.005+j*.004)),gp((x+.0015,y,-.007+j*.004)),gp((x,y+.004,-.005+j*.004))]
        rope('Fine bent finger creases',pts,.00024,skin,parts)
cloth=mat('Woven sleeve cuff',(.032,.041,.037),.97)
linen=mat('Cuff stitches',(.13,.14,.11),.95)
box('Realistic jacket cuff',gp((.004,-.095,-.019)),(.055,.049,.06),cloth,parts,.012)
for k in range(13):rope('Cuff seam stitches',[gp((-.020+k*.004,-.073,-.042)),gp((-.019+k*.004,-.076,-.042))],.00034,linen,parts)
batch(parts,'PhoneGrip');export('phone-hand.glb')

# Keep the carefully dimensioned original handset, refine its reflective glass.
clear();bpy.ops.import_scene.gltf(filepath=str(ASSETS/'props/guard-phone.glb'))
for m in bpy.data.materials:
    if not m.use_nodes:continue
    p=m.node_tree.nodes.get('Principled BSDF')
    if p and 'glass' in m.name.lower():p.inputs['Roughness'].default_value=.17;p.inputs['Coat Weight'].default_value=.35
export('guard-phone.glb')
print('Created mascot, anatomical phone grip and refined physical handset.',flush=True)
