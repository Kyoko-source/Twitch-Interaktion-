"""Original After Play stage, empty mascot costumes, and battered staff locker.
Blender 4.5. Godot coordinates are in metres; no downloaded mesh dependencies.
"""
import bpy, math, random, subprocess, shutil, hashlib, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'games/kinderparadies/assets/backstage-v270'
OUT.mkdir(exist_ok=True)
rng=random.Random(270)

def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name, color, rough=.85, metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
wood=mat('Carved dark walnut',(.19,.105,.058))
gold=mat('Tarnished brass trim',(.43,.29,.10),.57,.64)
velvet=mat('Faded mulberry velvet',(.29,.065,.085),.98)
cloth=mat('Empty costume canvas',(.40,.33,.23),.98)
patch=mat('Mended russet patches',(.18,.055,.032),.99)
black=mat('Empty black lining',(.009,.012,.011),1)
thread=mat('Exposed coarse seams',(.19,.15,.095),.99)
steel=mat('Oxidised steel',(.20,.25,.25),.66,.7)
enamel=mat('Dented blue enamel',(.14,.26,.27),.84,.2)
bone=mat('Cracked yellowed resin',(.49,.44,.29),.9)

def co(p):return (p[0],-p[2],p[1])
def finish(o,name,m):
    o.name=name;o.data.materials.append(m)
    for f in o.data.polygons:f.use_smooth=True
    return o
def box(name,p,s,m,b=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=co(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if b:
        mod=o.modifiers.new('Manufactured edges','BEVEL');mod.width=b;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return finish(o,name,m)
def ell(name,p,s,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=co(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m)
def tube(name,a,b,r,m,r2=None):
    a,b=Vector(co(a)),Vector(co(b));d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,name,m)
def line(name,points,r,m):
    for a,b in zip(points,points[1:]):tube(name,a,b,r,m)
def hoop(name,p,rx,ry,m,r=.018):
    x,y,z=p;line(name,[(x+math.sin(i*math.tau/48)*rx,y+math.cos(i*math.tau/48)*ry,z) for i in range(49)],r,m)
def export(filename):
    # Static props are merged by material, retaining only 6–9 draw calls each.
    for m in list(bpy.data.materials):
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==m]
        if not objects:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join();bpy.context.object.name=m.name
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)

clear()
# A substantial hand-built birthday chair. Seat at 0.83 m; crown at 3.2 m.
for side in [-1,1]:
    for z in [-.43,.45]:
        tube('Tapered carved leg',(side*.66,.04,z+.10),(side*.59,.77,z),.066,wood,.105)
        ell('Turned leg collar',(side*.625,.41,z+.05),(.095,.065,.095),gold)
    tube('Back post',(side*.64,.66,-.49),(side*.75,2.50,-.49),.075,wood)
    for y in [1.13,2.48]:ell('Carved post finial',(side*(.67 if y<2 else .75),y,-.49),(.11,.10,.11),gold)
    box('Shaped armrest',(side*.75,1.20,.05),(.18,.13,1.04),wood,.065)
    box('Velvet arm cushion',(side*.75,1.29,.06),(.20,.12,.73),velvet,.055)
    tube('Arm support',(side*.75,.80,.40),(side*.75,1.15,.40),.053,wood)
box('Seat apron',(0,.70,0),(1.50,.20,1.15),wood,.04)
box('Plump velvet seat',(0,.85,.025),(1.40,.18,1.08),velvet,.085)
line('Seat piping',[(-.64,.91,.50),(.64,.91,.50),(.64,.91,-.45),(-.64,.91,-.45),(-.64,.91,.50)],.012,gold)
box('High scalloped back',(0,1.67,-.49),(1.42,1.55,.19),wood,.13)
ell('Back carved arch',(0,2.36,-.50),(.70,.38,.105),wood)
box('Inset padded back',(0,1.76,-.37),(1.19,1.45,.15),velvet,.12)
ell('Velvet arched top',(0,2.38,-.37),(.57,.25,.08),velvet)
for row in range(4):
    for col in range(3):
        x=(col-1)*.36+(0.08 if row%2 else 0);y=1.2+row*.32
        ell('Tufted brass button',(x,y,-.277),(.025,.025,.012),gold)
        for sign in [-1,1]:line('Upholstery tuck',[(x,y,-.28),(x+sign*.13,y+.12,-.289)],.004,thread)
for side in [-1,1]:
    # Carved rabbit-ear crest; a curved profile, rather than floating primitives.
    points=[(side*.26,2.55,-.48),(side*.40,2.85,-.49),(side*.44,3.13,-.49),(side*.37,3.32,-.49),(side*.25,3.16,-.49),(side*.19,2.84,-.48),(side*.26,2.55,-.48)]
    line('Rabbit ear carved crest',points,.055,wood)
    line('Inset brass ear',[(x,y,z+.065) for x,y,z in points],.012,gold)
    for k in range(15):ell('Upholstery nail',(side*.59,1.03+k*.097,-.285),(.009,.009,.007),gold)
# Abraded seam at the lower back and a few loose stitches.
for i in range(15):
    x=-.44+i*.048;line('Repaired seat seam',[(x,.936,.33),(x+.012,.939,.36)],.004,thread)
export('birthday-throne.glb')

clear()
# The body is an EMPTY fabric costume with an open neck and hanging sleeves.
verts=[];faces=[];rings=22;n=48
for iy in range(rings):
    t=iy/(rings-1);y=.52+t*1.20
    width=.23+.16*math.sin(t*math.pi)*(.85+.15*math.sin(t*9));depth=.15+.09*math.sin(t*math.pi)
    for j in range(n):
        a=j*math.tau/n;ripple=1+.027*math.sin(a*8+y*7)+.015*math.sin(a*15-y*4)
        verts.append(co((math.cos(a)*width*ripple,y,math.sin(a)*depth*ripple)))
for iy in range(rings-1):
    for j in range(n):a=iy*n+j;b=iy*n+(j+1)%n;faces.append((a,b,b+n,a+n))
mesh=bpy.data.meshes.new('Wrinkled cloth shell');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Hollow costume torso',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,cloth)
sol=o.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=.012;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=sol.name)
ell('Dark empty neck',(0,1.685,0),(.205,.014,.135),black)
for side in [-1,1]:
    line('Drooping sleeve',[(side*.25,1.55,0),(side*.43,1.34,.03),(side*.46,1.05,.09)],.115,cloth)
    ell('Empty mitten',(side*.46,.95,.10),(.13,.17,.095),cloth)
    ell('Unstuffed trouser leg',(side*.17,.43,.01),(.14,.36,.16),cloth)
    ell('Hanging fabric foot',(side*.17,.10,.12),(.17,.13,.26),patch)
    line('Outer seam',[(side*.25,.58,.11),(side*.35,1.05,.16),(side*.27,1.58,.11)],.006,thread)
for i in range(26):
    y=.64+i*.035;t=(y-.52)/1.2;z=(.15+.09*math.sin(t*math.pi))+.008
    tube('Split zipper stitches',(-.014,y,z),(.014,y+.009,z),.003,gold)
ell('Fabric elbow repair',(.48,1.16,.15),(.07,.13,.015),patch)
export('empty-costume.glb')

clear()
# Hollow theatrical bear mask; separately pivoted so the anomaly can wake up.
ell('Worn mask shell',(0,0,0),(.32,.34,.26),cloth)
for side in [-1,1]:
    ell('Flattened felt ear',(side*.29,.26,-.025),(.14,.18,.07),cloth)
    ell('Ear lining',(side*.29,.26,.038),(.093,.12,.014),patch)
    ell('Empty eye aperture',(side*.12,.085,.232),(.077,.10,.027),black)
    for k in range(8):
        a=k*math.tau/8;tube('Eye seam',(side*.12+math.cos(a)*.086,.085+math.sin(a)*.11,.244),(side*.12+math.cos(a)*.095,.085+math.sin(a)*.12,.244),.004,thread)
ell('Collapsed muzzle',(0,-.08,.24),(.19,.11,.10),patch)
ell('Worn resin nose',(0,-.015,.324),(.065,.043,.033),black)
ell('Torn open mouth',(0,-.165,.252),(.15,.054,.024),black)
for i in range(7):
    x=-.12+i*.04;tube('Cracked mask tooth',(x,-.142,.277),(x+.007,-.185-rng.random()*.012,.276),.013,bone,.006)
for i in range(7):tube('Forehead repair',(-.065+i*.02,.22,.207),(-.06+i*.02,.25,.201),.004,thread)
export('costume-mask.glb')

clear()
# A dented locker door is a deformed sheet, not a flat coloured rectangle.
box('Locker carcass',(0,1.04,0),(.76,2.08,.54),enamel,.035)
box('Door black reveal',(0,1.07,.275),(.66,1.89,.012),black,.016)
verts=[];faces=[];nx=18;ny=38
for j in range(ny):
    y=.16+j/(ny-1)*1.80
    for i in range(nx):
        x=-.31+i/(nx-1)*.62
        dent=.12*math.exp(-((x+.07)**2/.023+(y-1.27)**2/.075))+.035*math.sin(y*19+x*32)*math.exp(-((y-1.27)**2/.09))
        verts.append(co((x,y,.302+dent)))
for j in range(ny-1):
    for i in range(nx-1):a=j*nx+i;faces.append((a,a+1,a+1+nx,a+nx))
mesh=bpy.data.meshes.new('Deformed steel door');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Bulged locker panel',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,enamel)
for y in [.32,.39,.46,1.74,1.81]:box('Vent aperture',(0,y,.314),(.41,.023,.013),black,.007)
for y in [.45,1.65]:box('Steel hinge',(-.34,y,.32),(.06,.11,.05),steel,.009)
box('Number plate',(.16,1.88,.32),(.16,.065,.008),bone,.005)
line('Locker handle',[(.24,1.01,.34),(.24,1.01,.41),(.24,1.16,.41),(.24,1.16,.34)],.014,steel)
for i in range(4):line('Raked exposed metal',[(x,1.35,.42-i*.008) for x in [-.15+i*.04,-.08+i*.04]],.004,steel)
export('staff-locker.glb')
clear()
# A genuinely seated visitor: bend the gown/thighs over the chair, preserve
# anatomical arm/head pivots, and let the calves hang below the knees.
bpy.ops.import_scene.gltf(filepath=str(ROOT/'games/kinderparadies/assets/creatures/night-visitor-v21.glb'))
for obj in bpy.context.scene.objects:
    if obj.type!='MESH': continue
    transform=obj.matrix_world.copy();inverse=transform.inverted()
    for vertex in obj.data.vertices:
        p=transform@vertex.co;h=p.z
        if h>=.9:p.z=h-.03
        elif h>=.4:
            t=(.9-h)/.5;p.z=.87-.06*t;p.y-=.48*t
        else:p.z=.81-(.4-h)*1.6;p.y-=.48
        vertex.co=inverse@p
    obj.data.update()
bpy.ops.export_scene.gltf(filepath=str(OUT/'seated-visitor.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
# Quiet equipment detail derived from an already licensed project recording.
source=ROOT/'games/kinderparadies/assets/ambience-v180/chain.wav'
ffmpeg=shutil.which('ffmpeg')
if not ffmpeg: raise RuntimeError('ffmpeg is required to reproduce keys.wav')
filters='asetrate=70400,aresample=32000,highpass=f=1600,lowpass=f=9500,afade=t=out:st=0.10:d=0.06,volume=0.6'
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-ss','0.14','-i',str(source),'-t','0.25','-af',filters,'-ac','1','-c:a','pcm_s16le',str(OUT/'keys.wav')],check=True)
(OUT/'provenance.json').write_text(json.dumps({'keys.wav':{'source':'https://bigsoundbank.com/heavy-chain-s0359.html','author':'Joseph SARDIN','license':'CC0-1.0','source_file':'assets/ambience-v180/chain.wav','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256((OUT/'keys.wav').read_bytes()).hexdigest(),'processing':{'start_seconds':0.14,'length_seconds':0.25,'ffmpeg_filter':filters}}},indent=2)+'\n',encoding='utf-8')
(OUT/'LICENSE.txt').write_text('After Play 2.7.0 backstage props\nOriginal geometry created for Kyoko / After Play, including the seated adaptation of the original night visitor.\nReproducible with tools/model-after-play-backstage-v270.py (Blender 4.5 and ffmpeg).\nRuntime materials reuse the project original textures and its attributed CC0 Poly Haven maps.\nNo third-party mesh, trademark or character was used.\n\nkeys.wav: derivative of Heavy Chain by Joseph SARDIN / BigSoundBank, CC0-1.0.\nhttps://bigsoundbank.com/heavy-chain-s0359.html\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nProcessed to a short, quiet keyring sound; provenance and hashes in provenance.json.\n',encoding='utf-8')
print('BACKSTAGE_V270_COMPLETE',flush=True)
