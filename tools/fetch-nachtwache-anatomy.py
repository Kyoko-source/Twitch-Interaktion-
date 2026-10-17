"""Fetch the attributed CC BY 3.0 head geometry used as the clown base mesh."""
from pathlib import Path
import hashlib,json,urllib.request
ROOT=Path(__file__).resolve().parents[1];RAW=ROOT/'tools/art-source/anatomy';OUT=ROOT/'games/kinderparadies/assets/props'
RAW.mkdir(parents=True,exist_ok=True);OUT.mkdir(exist_ok=True)
commit='4500a366ccfd5a59aa2ed296c386fa42bb4edb8c'
base=f'https://raw.githubusercontent.com/mrdoob/three.js/{commit}/examples/models/gltf/LeePerrySmith/'
rows=[]
for name in ['LeePerrySmith.glb','LeePerrySmith_License.txt','Infinite-Level_02_Tangent_SmoothUV.jpg']:
    data=urllib.request.urlopen(base+name).read();(RAW/name).write_bytes(data)
    rows.append(dict(file=name,url=base+name,sha256=hashlib.sha256(data).hexdigest()))
license_text=(RAW/'LeePerrySmith_License.txt').read_text()
assert 'Attribution 3.0' in license_text
(OUT/'Head-Attribution.txt').write_text(license_text+'\nSource: '+base+'LeePerrySmith.glb\nCC BY 3.0: https://creativecommons.org/licenses/by/3.0/\nModified for this game: neck crop, proportions, original clown vertex paint and superficial blood staining, hair, costume, eyes and scene animation. The original surface normal map is retained for small skin relief; portrait colour textures are not used.\n',encoding='utf8')
(OUT/'anatomy-provenance.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf8')
print('Fetched attributed head anatomy from commit '+commit)
