"""Two close-up scare heads from the project's credited anatomical scan.

Preserve the existing scan UVs and correctly seated eyes/dental arches. Add
sculpted age, a stretched lower face, original hair and vertex-painted decay.
No newly downloaded assets or baked portrait billboards.
"""
import bpy, math, random
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'games/kinderparadies/assets'
OUT = ASSETS / 'shift-v390'
OUT.mkdir(exist_ok=True)

def material(name, color, rough=.8):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    return m

def build(kind):
    rng = random.Random(390 if kind == 'granny' else 391)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ASSETS / 'detail-v310/clown-v310.glb'))
    scan = bpy.data.objects['Head']
    keep = {scan, *scan.children_recursive}
    for obj in list(bpy.context.scene.objects):
        if obj not in keep: bpy.data.objects.remove(obj, do_unlink=True)
    # Freeze all imported parenting first. glTF is Y-up; Blender imports Z-up.
    coordinates = {o: o.matrix_world.copy() for o in keep}
    for obj in keep:
        obj.parent = None; obj.matrix_world = coordinates[obj]
    for obj in list(keep):
        if obj.name == 'MattedHairStrands':
            keep.remove(obj); bpy.data.objects.remove(obj, do_unlink=True)
    eye_objects = sorted([o for o in keep if o.name.startswith('Inset eyeball')], key=lambda o:o.location.x)
    eye_z = sum(o.location.z for o in eye_objects) / 2
    oral = next(o for o in keep if o.name.startswith('Recessed oral cavity'))
    mouth_z, mouth_y = oral.location.z, oral.location.y - .035
    anchor = Vector((0, 0, eye_z - .035))
    stretch = .056 if kind == 'granny' else .105
    scale = 1.18 if kind == 'granny' else 1.38
    def deform(p):
        p = p.copy()
        below = max(0., min(1., (mouth_z + .008 - p.z) / .016))
        below = below*below*(3-2*below)
        p.z -= stretch * below
        cheek = math.exp(-((abs(p.x)-.056)/.024)**2-((p.z-eye_z+.047)/.044)**2)
        p.y += .010 * cheek
        p.x *= 1. - .085 * below
        return (p-anchor)*scale
    skin = material('Scanned aged visitor skin', (.33,.30,.24), .78)
    attr_node = skin.node_tree.nodes.new('ShaderNodeVertexColor'); attr_node.layer_name = 'AgePigment'
    skin.node_tree.links.new(attr_node.outputs['Color'],skin.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    tooth_shades = [material('Stained anatomical enamel '+str(i),(.28+i*.008,.23+i*.006,.145+i*.004),.56) for i in range(4)]
    sclera = material('Recessed cloudy sclera',(.11,.105,.085),.38)
    iris = material('Small wet amber iris',(.035,.027,.013),.25)
    pupil = material('Recessed pupil',(.002,.002,.001),.22)
    gum = material('Inflamed recessed gums',(.13,.025,.020),.46)
    cavity = material('Deep oral cavity',(.003,.001,.001),.95)
    for obj in keep:
        if obj.type != 'MESH': continue
        world = coordinates[obj]
        original_center=world.translation.copy()
        rigid = obj != scan and not obj.name.startswith(('Gum','Recessed oral'))
        for v in obj.data.vertices:
            p=world @ v.co
            v.co = deform(original_center)+(p-original_center)*scale if rigid else deform(p)
            if obj.name.startswith('Recessed oral'):
                v.co.z=(mouth_z-anchor.z)*scale-stretch*scale*.5+(p.z-mouth_z)*scale*(1.+stretch/.019)
        obj.matrix_world.identity()
        if obj == scan:
            obj.name = 'SculptedAgeAndFacialAnatomy'
            obj.data.materials.clear();obj.data.materials.append(skin)
            pigment = obj.data.color_attributes.new(name='AgePigment', type='BYTE_COLOR', domain='POINT')
            normals = [v.normal.copy() for v in obj.data.vertices]
            for i,v in enumerate(obj.data.vertices):
                p=v.co; normal=normals[i]
                forehead=max(0.,min(1.,(p.z-.045)/.06))*max(0.,1.-abs(p.x)/.12)
                wrinkle = math.sin(p.z*650.+math.sin(p.x*42.)*.8)*forehead*.00075
                eye_bags=math.exp(-((abs(p.x)-.050*scale)/(.027*scale))**2-((p.z-.006)/.020)**2)
                v.co += normal*(wrinkle-.0022*eye_bags)
                n=.5+.22*math.sin(p.x*190.+p.y*75.)*math.sin(p.z*220.)+.11*math.sin(p.z*790.)
                base=Vector((.38,.35,.285))*(.82+n*.24)
                bruise=max(math.exp(-((abs(p.x)-.052*scale)/.030)**2-((p.z-.027)/.027)**2),eye_bags*.5)
                base=base.lerp(Vector((.105,.076,.065)),min(.78,bruise*.75))
                lower_mouth=(mouth_z-anchor.z)*scale-stretch*scale*.5
                gore=math.exp(-((p.x/.058)**4+((p.z-lower_mouth)/(.073 if kind=='granny' else .12))**4)) if p.y<-.02 else 0.
                base=base.lerp(Vector((.13,.018,.014)),gore*(.5+n*.35))
                pigment.data[i].color=(*base,1)
            for face in obj.data.polygons:face.use_smooth=True
        else:
            name=obj.name
            obj.data.materials.clear()
            mat = sclera if name.startswith('Inset eyeball') else iris if name.startswith('Iris') else pupil if name.startswith('Pupil') else gum if name.startswith('Gum') else tooth_shades[rng.randrange(4)] if name.startswith('Individual rounded tooth') else cavity
            obj.data.materials.append(mat)
    # Hair cards follow the head contour and then hang beyond the jaw. Thousands
    # of fine tapered triangles form irregular clumps, never solid side panels.
    verts=[];faces=[]
    scan.data.update()
    scalp=[(v.co.copy(),v.normal.copy()) for v in scan.data.vertices if v.co.z>.09 or (abs(v.co.x)>.084*scale and v.co.z>-.07)]
    for strand in range(880 if kind=='granny' else 540):
        root,normal=rng.choice(scalp)
        if root.y<-.035 and abs(root.x)<.070*scale and root.z<.17:continue
        length=rng.uniform(.17,.42) if kind=='granny' else rng.uniform(.05,.18)
        width=rng.uniform(.0007,.0020)
        start=root+normal*.003
        points=[]
        for j in range(9):
            t=j/8
            side=1 if root.x>0 else -1
            points.append(start+normal*(.012*math.sin(t*math.pi))+Vector((side*.020*t+math.sin(t*6.+strand)*.009*t, .025*t+.005*math.sin(t*9.+strand),-length*t)))
        at=len(verts)
        for j,p in enumerate(points):
            w=width*(1-j/9.)
            verts.extend([p+Vector((-w,0,0)),p+Vector((w,0,0))])
        for j in range(8):
            a=at+j*2;faces.extend([(a,a+1,a+2),(a+1,a+3,a+2)])
    mesh=bpy.data.meshes.new('Individual clumped hair fibres');mesh.from_pydata(verts,[],faces);mesh.update()
    hair=bpy.data.objects.new('GreasyGreyHair' if kind=='granny' else 'SparseMattedHair',mesh);bpy.context.collection.objects.link(hair)
    hair_mat=material('Dirty grey hair fibres',(.105,.105,.083) if kind=='granny' else (.028,.025,.018),.92);hair.data.materials.append(hair_mat)
    hair_mat.use_backface_culling=False
    # Close the scalp silhouette beneath the individual clumps. It follows the
    # actual scan rather than an intersecting sphere or cardboard side panels.
    scalp_verts=[];scalp_faces=[];scalp_indices={}
    for poly in scan.data.polygons:
        points=[scan.data.vertices[i].co for i in poly.vertices]
        if not all((p.z>.177 and p.y>-.02) or (p.y>.020 and p.z>-.025) or (abs(p.x)>.102*scale and p.z>.035) for p in points):continue
        face=[]
        for i in poly.vertices:
            if i not in scalp_indices:
                scalp_indices[i]=len(scalp_verts)
                v=scan.data.vertices[i];scalp_verts.append(v.co+v.normal*.0018)
            face.append(scalp_indices[i])
        scalp_faces.append(tuple(face))
    cap_mesh=bpy.data.meshes.new('Conforming aged scalp');cap_mesh.from_pydata(scalp_verts,[],scalp_faces);cap_mesh.update()
    cap=bpy.data.objects.new('ConformingSparseScalp',cap_mesh);bpy.context.collection.objects.link(cap);cap.data.materials.append(hair_mat)
    for face in cap_mesh.polygons:face.use_smooth=True
    # Join static pieces by material; skin UVs and anatomical eye placement stay.
    groups={}
    for obj in list(bpy.context.scene.objects):
        if obj.type=='MESH':groups.setdefault(obj.data.materials[0],[]).append(obj)
    for mat,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        objects[0].name=mat.name.replace(' ','')
    # The runtime uses the already bundled photographic skin and normal map.
    # Remove redundant baked pigment and simplify only the dense scan, keeping
    # lips, eye apertures, original UVs, teeth and individual hair geometry.
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':continue
        for attr in list(obj.data.color_attributes):obj.data.color_attributes.remove(attr)
        if 'Scannedaged' in obj.name:
            bpy.context.view_layer.objects.active=obj
            dec=obj.modifiers.new('Portable close-up sculpt','DECIMATE');dec.ratio=.48
            bpy.ops.object.modifier_apply(modifier=dec.name)
    for node in list(skin.node_tree.nodes):
        if node.type=='VERTEX_COLOR':skin.node_tree.nodes.remove(node)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'-head.glb')),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False,export_attributes=True)
    print(kind, 'anchor', tuple(anchor), 'mouth', mouth_z, 'bytes', (OUT/(kind+'-head.glb')).stat().st_size, flush=True)

for variant in ['granny','passage']:build(variant)
