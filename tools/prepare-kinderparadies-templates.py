"""Fetch only Windows/Web templates from the official pinned archive using HTTP ranges.
Avoids downloading unrelated Android/macOS/Linux templates. ZIP CRCs are verified.
"""
import io
import pathlib
import urllib.request
import zipfile

URL = 'https://godot-releases.nbg1.your-objectstorage.com/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz'
DEST = pathlib.Path(__file__).resolve().parent / 'godot-portable' / 'templates'

class RemoteArchive(io.RawIOBase):
    def __init__(self):
        self.pos = 0
        with urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'), timeout=30) as r:
            self.length = int(r.headers['Content-Length'])
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.length + offset
        return self.pos
    def read(self, count=-1):
        count = min(self.length-self.pos, count if count >= 0 else self.length-self.pos)
        if count <= 0: return b''
        req = urllib.request.Request(URL, headers={'Range': f'bytes={self.pos}-{self.pos+count-1}'})
        with urllib.request.urlopen(req, timeout=120) as r:
            if r.status != 206: raise RuntimeError('Server must honor byte ranges')
            data = r.read(count)
        self.pos += len(data)
        return data

if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteArchive()) as z:
        names = [n for n in z.namelist() if ('windows_release_x86_64.exe' in n or 'web_nothreads_release.zip' in n)]
        if len(names) != 2: raise RuntimeError(f'Expected two templates, got {names}')
        for name in names:
            target = DEST / pathlib.PurePosixPath(name).name
            if target.exists():
                print('Already downloaded:', target.name, flush=True)
                continue
            print('Fetching:', name, z.getinfo(name).compress_size, 'bytes', flush=True)
            target.write_bytes(z.read(name))
            print('ZIP CRC verified:', target.name, target.stat().st_size, flush=True)
