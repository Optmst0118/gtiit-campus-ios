#!/usr/bin/env python3
"""Verify simulator Debug/Release and unsigned device Release from the same sources."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
checks = []
for name, configuration, destination, derived in [
    ('debug-simulator', 'Debug', 'generic/platform=iOS Simulator', '/tmp/GTIIT-improvements'),
    ('release-simulator', 'Release', 'generic/platform=iOS Simulator', '/tmp/GTIIT-improvements'),
    ('release-device-unsigned', 'Release', 'generic/platform=iOS', '/tmp/GTIIT-device-improvements'),
]:
    log = Path('/tmp/gtiit-final-' + name + '.log')
    command = ['xcodebuild', '-project', 'GTIIT.xcodeproj', '-scheme', 'GTIIT', '-configuration', configuration,
               '-destination', destination, '-derivedDataPath', derived, 'CODE_SIGNING_ALLOWED=NO', 'build']
    with log.open('w') as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    checks.append({'name': name, 'configuration': configuration, 'destination': destination,
                   'exitCode': result.returncode, 'signing': False, 'log': str(log)})
    print(name, result.returncode, flush=True)
    if result.returncode:
        break
snapshot = hashlib.sha256()
for source in sorted((ROOT/'GTIIT').rglob('*.swift')):
    snapshot.update(str(source.relative_to(ROOT)).encode())
    snapshot.update(source.read_bytes())
report = {'sourceSHA256': snapshot.hexdigest(), 'builds': checks,
          'passed': len(checks) == 3 and all(x['exitCode'] == 0 for x in checks)}
(ROOT/'docs/verification/build-results.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if report['passed'] else 1)
