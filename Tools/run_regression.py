#!/usr/bin/env python3
"""Compile the real app sources with an isolated UIKit regression entry point."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BUNDLE = 'local.gtiit.regression'

def call(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def main():
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 Tools/run_regression.py <disposable-simulator-UDID>')
    device = sys.argv[1]
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j'], text=True))
    chosen = next(d for group in devices['devices'].values() for d in group if d['udid'] == device)
    if 'Review' not in chosen['name'] and 'Test' not in chosen['name']:
        raise SystemExit('Use a disposable simulator named with Review or Test; the test suite clears its own app data.')
    build = Path(tempfile.mkdtemp(prefix='gtiit-regression-'))
    app = build / 'Regression.app'; app.mkdir()
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    sources = sorted(str(p) for p in (ROOT/'GTIIT').rglob('*.swift') if p.name != 'GTIITApp.swift')
    call(['xcrun', 'swiftc', '-sdk', sdk, '-target', 'arm64-apple-ios17.0-simulator', '-module-name', 'Regression', '-parse-as-library', *sources, str(ROOT/'Tests/RegressionHarness.swift'), '-o', str(app/'Regression')])
    (app/'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': BUNDLE, 'CFBundleExecutable': 'Regression', 'CFBundleName': 'Regression',
        'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '1',
        'LSRequiresIPhoneOS': True, 'UILaunchScreen': {}, 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False},
        'NSFaceIDUsageDescription': 'Validate local app-lock behavior in the disposable simulator.',
        'NSAppTransportSecurity': {'NSAllowsArbitraryLoadsInWebContent': True}
    }))
    server = subprocess.Popen([sys.executable, str(ROOT/'Tests/fixture_server.py')], cwd=ROOT)
    try:
        call(['xcrun','simctl','install',device,str(app)])
        result = subprocess.run(['xcrun','simctl','launch','--console',device,BUNDLE], text=True, capture_output=True, timeout=180)
        print(result.stdout); print(result.stderr)
        container = Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,BUNDLE,'data'], text=True).strip())
        data = (container/'Documents/regression-results.json').read_bytes()
        parsed = json.loads(data)
        target = ROOT/'docs/verification/regression-results.json'; target.write_bytes(data)
        print('Results:',target,'Passed:',parsed['passed'],'Checks:',len(parsed['checks']))
        return 0 if parsed['passed'] else 1
    finally:
        server.terminate(); server.wait(timeout=5)

if __name__ == '__main__':
    raise SystemExit(main())
