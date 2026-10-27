#!/usr/bin/env python3
"""Export the real Godot project and validate the self-contained web bundle."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    godot = args.godot.expanduser().resolve()
    out = (args.output_dir or root / 'dist/web').resolve()
    out.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(godot), '--version'], text=True).strip()
    if not version.startswith('4.7.1.'):
        raise RuntimeError(f'Expected Godot 4.7.1, got {version}')
    for path in out.iterdir():
        if path.is_file() and (path.name.startswith('index.') or path.name == 'build-manifest.json'):
            path.unlink()
    for name, command in [
        ('import', [str(godot), '--headless', '--path', str(root/'godot'), '--import']),
        ('export', [str(godot), '--headless', '--path', str(root/'godot'), '--export-release', 'Web', str(out/'index.html')]),
    ]:
        log = out.parent / f'web-{name}.log'
        with log.open('w', encoding='utf-8') as handle:
            result = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT)
        text = log.read_text(encoding='utf-8', errors='replace')
        if result.returncode or re.search(r'SCRIPT ERROR|Parse Error|^ERROR:', text, re.M):
            raise RuntimeError(f'{name} failed; see {log}\n{text[-5000:]}')
        print(f'{name}: OK', flush=True)
    for path in out.glob('index.pck-*'):
        path.unlink()  # Exporter intermediate, never a bundle dependency.
    for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
        assert (out/name).is_file() and (out/name).stat().st_size, name
    assert (out/'index.wasm').read_bytes()[:4] == b'\x00asm'
    pack = (out/'index.pck').read_bytes()
    assert pack[:4] == b'GDPC'
    ghosts = sorted((root/'godot/ghosts').glob('*.dat'))
    for path in ghosts:
        assert str(path.relative_to(root/'godot')).encode() in pack, f'Missing ghost: {path.name}'
    for path in ['music/menu.ogg', 'music/race.ogg', 'fonts/bungee-latin-400-normal.woff2']:
        assert path.encode() in pack, f'Missing resource: {path}'
    html = (out/'index.html').read_text()
    assert '$GODOT_' not in html and 'const threads = false;' in html
    manifest = {
        'stage': 'W01', 'godot': version,
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'dirty_tracked_sources': bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=no'], cwd=root, text=True).strip()),
        'threads': False, 'pwa': False, 'ghost_files': len(ghosts),
        'limitations': ['Web audio is deferred to W03', 'Temporary centre-line AI fallback until W02', 'Online disabled until W10–W12', 'Browser sensors and haptics deferred to W04'],
        'files': [{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
                  for p in sorted(out.iterdir()) if p.is_file()],
    }
    (out/'build-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'bundle':str(out),'bytes':sum(x['bytes'] for x in manifest['files']),'ghosts':len(ghosts)}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
