#!/usr/bin/env python3
"""Run the repository's existing native test steps without publishing a build.

Requires Python 3, PyYAML, Bash and the exact Godot version from build.yml.
Results and logs go outside the source tree unless --output-dir is specified.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time

import yaml


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--select', default='.*', help='Regex against existing step names.')
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    workflow_path = root / '.github/workflows/build.yml'
    workflow = yaml.safe_load(workflow_path.read_text(encoding='utf-8'))
    steps = [s for s in workflow['jobs']['build']['steps']
             if (s.get('name') == 'Import project' or s.get('name', '').startswith('Test –'))
             and re.search(args.select, s.get('name', ''))]
    if args.list:
        for step in steps:
            print(step['name'])
        return 0
    if not steps:
        parser.error('No matching existing test steps.')
    binary = args.godot.expanduser().resolve()
    version = subprocess.check_output([str(binary), '--version'], text=True).strip()
    expected_version = str(workflow['env']['GODOT_VERSION'])
    if not version.startswith(expected_version + '.'):
        parser.error(f'Expected Godot {expected_version}, got {version}')
    out = (args.output_dir or Path(tempfile.mkdtemp(prefix='skodaracer-w00-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    report = {
        'schema_version': 1,
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'working_tree_dirty': bool(subprocess.check_output(['git','status','--porcelain'], cwd=root, text=True).strip()),
        'started_at': dt.datetime.now(dt.timezone.utc).isoformat(),
        'godot': version,
        'workflow_sha256': hashlib.sha256(workflow_path.read_bytes()).hexdigest(),
        'scope': 'Existing native headless logic tests; no browser, GPU, audible sound or physical sensors are verified.',
        'results': [],
    }
    print(f'Godot {version}; {len(steps)} steps; output: {out}', flush=True)
    for index, step in enumerate(steps, 1):
        case = out / f'{index:02}'
        case.mkdir(exist_ok=True)
        command = step['run'].replace('~/godot-bin/godot', shlex.quote(str(binary)))
        command = command.replace('--path godot', '--path ' + shlex.quote(str(root / 'godot')))
        environment = os.environ.copy()
        # Deliberately isolate game saves from real player data and other cases.
        environment['XDG_DATA_HOME'] = str(case / 'userdata')
        started = time.monotonic()
        print(f'START {index:02}: {step["name"]}', flush=True)
        timeout = False
        with (case / 'step.log').open('w', encoding='utf-8') as log:
            process = subprocess.Popen(['bash', '-o', 'pipefail', '-c', command], cwd=case,
                                       stdout=log, stderr=subprocess.STDOUT, env=environment,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=1200)
            except subprocess.TimeoutExpired:
                import signal
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                code, timeout = 124, True
        logs = sorted(case.glob('*.log'))
        issues = []
        engine_messages = []
        evidence = []
        for log in logs:
            content = log.read_text(encoding='utf-8', errors='replace')
            for line in content.splitlines():
                if re.search(r'SCRIPT ERROR|Parse Error', line):
                    issues.append({'log': log.name, 'line': line})
                if line.startswith(('ERROR:', 'WARNING:')):
                    engine_messages.append({'log': log.name, 'line': line})
                if re.search(r'TEST PASS|TEST FAIL|PREDICTION|BATTLE STATE|HOST TAKEOVER|FOUND HOSTS|JOIN FAILED', line):
                    evidence.append({'log': log.name, 'line': line})
        ok = code == 0 and not issues
        result = {'index': index, 'name': step['name'], 'ok': ok, 'exit_code': code,
                  'timeout': timeout, 'seconds': round(time.monotonic() - started, 3),
                  'logs': [str(p.relative_to(out)) for p in logs],
                  'script_errors': issues, 'engine_messages': engine_messages,
                  'evidence': evidence}
        report['results'].append(result)
        report['completed_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
        report['all_passed'] = all(r['ok'] for r in report['results'])
        (out / 'baseline.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'{"PASS" if ok else "FAIL"} {index:02}: {result["seconds"]} s', flush=True)
        if not ok:
            print((case / 'step.log').read_text(encoding='utf-8', errors='replace')[-4000:], flush=True)
    print(f'COMPLETE: {sum(r["ok"] for r in report["results"])}/{len(steps)} passed', flush=True)
    return 0 if report['all_passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
