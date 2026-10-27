#!/usr/bin/env python3
"""Install the pinned Linux CI editor and only the single-threaded web templates."""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = '4.7.1'
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/'
EDITOR = f'Godot_v{VERSION}-stable_linux.x86_64.zip'
EDITOR_SHA = 'c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba'
TEMPLATES = {
    'web_nothreads_debug.zip': 'eb6ca0ca168c405e73b20a4439d6dc048d74ae65eb31cc7675b6bc3cf7ad1815',
    'web_nothreads_release.zip': 'b7b7d7da29fc6cc2f4934fdd26cc571a40e7af57f716ea3eb7e18da720dae28a',
}


class RemoteArchive(io.RawIOBase):
    def __init__(self):
        url = BASE + f'Godot_v{VERSION}-stable_export_templates.tpz'
        with urllib.request.urlopen(urllib.request.Request(url,method='HEAD'),timeout=45) as response:
            self.url, self.length = response.geturl(), int(response.headers['Content-Length'])
        self.position = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position+offset if whence == 1 else self.length+offset
        return self.position

    def read(self, size=-1):
        size = self.length-self.position if size < 0 else size
        if not size: return b''
        end = min(self.length,self.position+size)-1
        req = urllib.request.Request(self.url,headers={'Range':f'bytes={self.position}-{end}'})
        with urllib.request.urlopen(req,timeout=180) as response:
            if response.status != 206: raise RuntimeError('Template server did not honor the byte range.')
            data = response.read(size+1)
        if len(data) != end-self.position+1: raise RuntimeError('Incomplete template response.')
        self.position += len(data)
        return data


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--github-env', type=Path)
    args = parser.parse_args()
    cache = Path.home()/f'.cache/skodaracer-godot/{VERSION}'
    cache.mkdir(parents=True,exist_ok=True)
    archive = cache/EDITOR
    if not archive.exists() or digest(archive) != EDITOR_SHA:
        with urllib.request.urlopen(BASE+EDITOR,timeout=180) as response, archive.open('wb') as target:
            shutil.copyfileobj(response,target)
    assert digest(archive) == EDITOR_SHA
    with zipfile.ZipFile(archive) as z:
        editor = cache/f'Godot_v{VERSION}-stable_linux.x86_64'
        expected = z.read(editor.name)
        if not editor.exists() or hashlib.sha256(editor.read_bytes()).digest() != hashlib.sha256(expected).digest():
            editor.write_bytes(expected)
    editor.chmod(0o755)
    target = Path.home()/f'.local/share/godot/export_templates/{VERSION}.stable'
    target.mkdir(parents=True,exist_ok=True)
    missing = {name:sha for name,sha in TEMPLATES.items() if not (target/name).exists() or digest(target/name)!=sha}
    if missing:
        with zipfile.ZipFile(RemoteArchive()) as z:
            assert z.read('templates/version.txt').decode().strip() == f'{VERSION}.stable'
            for name,sha in missing.items():
                data = z.read('templates/'+name)
                assert hashlib.sha256(data).hexdigest() == sha
                with zipfile.ZipFile(io.BytesIO(data)) as inner:
                    assert inner.testzip() is None
                (target/name).write_bytes(data)
    if args.github_env:
        with args.github_env.open('a') as handle: handle.write(f'GODOT_BIN={editor}\n')
    print(editor)


if __name__ == '__main__': main()
