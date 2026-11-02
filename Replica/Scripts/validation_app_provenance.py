#!/usr/bin/env python3
"""Record source identity for generic unsigned diagnostic-app builds."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import uuid

BUILD_SCRIPTS = (
    'Scripts/build-ipad-validation-app.sh',
    'Scripts/build-ipad-validation-device-app.sh',
    'Scripts/validation_app_provenance.py',
)
EXCLUDED_PARTS = {'.git', '.cache', '.swiftpm', '__pycache__', 'xcuserdata', 'project.xcworkspace'}


def generated(path):
    return any(part in EXCLUDED_PARTS or part.startswith('.build') for part in path.parts) or path.name == '.DS_Store' or path.suffix in {'.pyc', '.xcuserstate'}


def snapshot(root):
    required = ['Package.swift', 'THIRD_PARTY_NOTICES.txt', *BUILD_SCRIPTS]
    paths = [root / name for name in required]
    for directory in ('Sources', 'iPadValidation'):
        base = root / directory
        if not base.is_dir():
            raise ValueError(f'Missing build input directory: {directory}')
        paths += [p for p in base.rglob('*') if p.is_file() and not generated(p.relative_to(root))]
    files = {}
    for path in paths:
        files[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    files = dict(sorted(files.items()))
    encoded = ''.join(f'{digest}  {name}\n' for name, digest in files.items()).encode('utf-8')
    return {'format': 'generik-dj.audio-check-build-inputs/v1',
            'aggregateSHA256': hashlib.sha256(encoded).hexdigest(), 'files': files}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def unchanged(before, after):
    return before['files'] == after['files'] and before['aggregateSHA256'] == after['aggregateSHA256']


def begin(root, derived, sdk):
    inputs = snapshot(root)
    identifier = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '-' + uuid.uuid4().hex[:8]
    proof = derived / 'AudioCheckBuildProofs' / identifier
    write_json(proof / 'inputs-before.json', inputs)
    write_json(derived / 'audio-check-pending-proof.json',
               {'sdk': sdk, 'proofDirectory': str(proof), 'sourceSHA256': inputs['aggregateSHA256']})
    print(inputs['aggregateSHA256'])


def finish(root, derived, sdk):
    pending = json.loads((derived / 'audio-check-pending-proof.json').read_text())
    if pending['sdk'] != sdk:
        raise ValueError('The pending build proof belongs to another SDK.')
    proof = Path(pending['proofDirectory'])
    before = json.loads((proof / 'inputs-before.json').read_text())
    after = snapshot(root)
    write_json(proof / 'inputs-after.json', after)
    if not unchanged(before, after):
        changed = sorted(name for name in before['files'].keys() | after['files'].keys()
                         if before['files'].get(name) != after['files'].get(name))
        write_json(proof / 'failure.json', {'buildInputsUnchanged': False, 'changedPaths': changed})
        raise ValueError('Build inputs changed. Preserve this attempt and build again after the source freeze.')
    app = derived / 'Build' / 'Products' / ('Release-' + sdk) / 'GenErikDJAudioCheck.app'
    with (app / 'Info.plist').open('rb') as source:
        info = plistlib.load(source)
    fingerprint = info.get('TDJValidationSourceSHA256')
    if fingerprint != before['aggregateSHA256']:
        raise ValueError('The compiled app does not contain the expected source fingerprint.')
    if info.get('TDJValidationBuildConfiguration') != 'Release':
        raise ValueError('The compiled app does not identify its Release configuration.')
    executable = app / info['CFBundleExecutable']
    record = {
        'format': 'generik-dj.audio-check-build-proof/v1',
        'recordedUTC': datetime.now(timezone.utc).isoformat(),
        'buildSucceeded': True, 'buildInputsUnchanged': True,
        'sdk': sdk, 'configuration': 'Release',
        'bundleIdentifier': info['CFBundleIdentifier'],
        'bundleVersion': info.get('CFBundleVersion'),
        'bundleShortVersion': info.get('CFBundleShortVersionString'),
        'sourceSHA256': fingerprint,
        'executableSHA256': hashlib.sha256(executable.read_bytes()).hexdigest(),
        'executable': str(executable), 'app': str(app),
        'proofDirectory': str(proof), 'physicalRuntimeAcceptance': False,
        'scope': 'Generic unsigned compilation only. No device enumeration, boot, installation or launch.',
    }
    write_json(proof / 'build-proof.json', record)
    write_json(derived / 'audio-check-build-proof.json', record)
    print(f'Build proof recorded: {derived / "audio-check-build-proof.json"}')


def self_test():
    with tempfile.TemporaryDirectory(prefix='tdj-build-provenance-') as temporary:
        roots = [Path(temporary) / name for name in ('a', 'b')]
        for root in roots:
            for name in ('Package.swift', 'THIRD_PARTY_NOTICES.txt', *BUILD_SCRIPTS,
                         'Sources/Test.swift', 'iPadValidation/App.swift'):
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(name)
        initial = snapshot(roots[0])
        assert initial == snapshot(roots[1]), 'Workspace location changed the fingerprint.'
        ignored = roots[0] / 'iPadValidation' / 'App.xcodeproj' / 'project.xcworkspace' / 'generated.txt'
        ignored.parent.mkdir(parents=True)
        ignored.write_text('generated')
        (roots[0] / 'Sources' / '.DS_Store').write_text('metadata')
        assert unchanged(initial, snapshot(roots[0])), 'Generated output affected the fingerprint.'
        (roots[0] / 'Sources' / 'Test.swift').write_text('changed source')
        assert not unchanged(initial, snapshot(roots[0])), 'Source mutation was not detected.'
        (roots[0] / 'Sources' / 'Test.swift').write_text('Sources/Test.swift')
        (roots[0] / 'Sources' / 'New.swift').write_text('new source')
        assert not unchanged(initial, snapshot(roots[0])), 'New source input was not detected.'
    print('Provenance checks passed: deterministic paths, generated-file exclusion, mutation and added-input rejection.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('begin', 'finish', 'self-test'))
    parser.add_argument('--derived-data', type=Path)
    parser.add_argument('--sdk', choices=('iphonesimulator', 'iphoneos'))
    args = parser.parse_args()
    if args.mode == 'self-test':
        self_test()
        return
    if not args.derived_data or not args.sdk:
        parser.error('--derived-data and --sdk are required for builds')
    root = Path(__file__).resolve().parents[1]
    operation = begin if args.mode == 'begin' else finish
    operation(root, args.derived_data.resolve(), args.sdk)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
