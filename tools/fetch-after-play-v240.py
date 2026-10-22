"""Pinned CC0 surface materials and recorded multi-surface footsteps for After Play."""
import hashlib, importlib.util, io, json, zipfile, tempfile, subprocess, shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'games/kinderparadies/assets'
spec=importlib.util.spec_from_file_location('art',Path(__file__).with_name('fetch-nachtwache-art.py'))
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)

if __name__=='__main__':
    manifest=json.loads((ASSETS/'polyhaven-provenance.json').read_text(encoding='utf8'))
    for asset in ['curly_teddy_natural','dirty_carpet','metal_grate_rusty']:
        entry=art.fetch_asset(('material',asset))
        manifest=[x for x in manifest if x['id']!=asset]+[entry]
    (ASSETS/'polyhaven-provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    url='https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip'
    data=art.get(url);archive=zipfile.ZipFile(io.BytesIO(data))
    target=ASSETS/'surfaces';target.mkdir(exist_ok=True)
    files=[]
    for name in archive.namelist():
        base=Path(name).name
        if base.startswith('footstep_') and base.endswith('.ogg'):
            raw=archive.read(name);(target/base).write_bytes(raw)
            files.append({'file':base,'source_path':name,'sha256':hashlib.sha256(raw).hexdigest()})
    assert len(files)>=12, 'Expected multiple original recordings for the surfaces'
    ffmpeg=shutil.which('ffmpeg');assert ffmpeg,'ffmpeg is needed to mix recorded surfaces'
    with tempfile.TemporaryDirectory(prefix='after-play-footsteps-') as temporary:
        work=Path(temporary)
        for surface,base,layer,cutoff,weight in [('metal','concrete','impactMetal_light',4600,.28),('rubber','concrete','impactSoft_medium',950,.65),('plastic','wood','impactPlank_medium',2400,.22)]:
            for i in range(5):
                names=[f'Audio/footstep_{base}_{i:03}.ogg',f'Audio/{layer}_{i:03}.ogg']
                for j,name in enumerate(names):(work/f'{j}.ogg').write_bytes(archive.read(name))
                output=target/f'footstep_{surface}_{i:03}.ogg'
                filters=f'[0:a]lowpass=f={cutoff}[step];[1:a]lowpass=f={cutoff}[layer];[step][layer]amix=inputs=2:weights=1 {weight}:normalize=0,afade=t=out:st=0.32:d=0.16,alimiter=limit=0.85'
                subprocess.run([ffmpeg,'-v','error','-y','-i',str(work/'0.ogg'),'-i',str(work/'1.ogg'),'-filter_complex',filters,'-t','0.48','-ac','1','-c:a','libvorbis','-q:a','5',str(output)],check=True)
                files.append({'file':output.name,'source_paths':names,'processing':filters,'sha256':hashlib.sha256(output.read_bytes()).hexdigest()})
    (target/'provenance.json').write_text(json.dumps({'author':'Kenney; edited mixes by After Play','license':'CC0-1.0','source':'https://kenney.nl/assets/impact-sounds','download':url,'archive_sha256':hashlib.sha256(data).hexdigest(),'files':files},indent=2)+'\n')
    (target/'LICENSE.txt').write_text('Original recorded footsteps: Kenney Impact Sounds, CC0 1.0.\nhttps://kenney.nl/assets/impact-sounds\nhttps://creativecommons.org/publicdomain/zero/1.0/\nSource filenames and SHA256 checksums: provenance.json\n')
    print('Verified original footstep recordings:',[x['file'] for x in files])
