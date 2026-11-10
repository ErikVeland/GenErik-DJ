"""Stage validated automatic results on a device and record cloud receipts."""
import hashlib
import json
import pathlib
import re
import subprocess

BUNDLE = 'org.generikdj.replica.audiocheck'
ROOT = 'Documents/GenErikDJ-Development/CloudPreparation'
DIGEST = re.compile(r'[0-9a-f]{64}')


def read_revision(path):
    identifier = path.stem
    if not DIGEST.fullmatch(identifier):
        raise ValueError('Invalid revision filename.')
    payload = path.with_suffix('.payload')
    data = payload.read_bytes()
    if len(data) > 32 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != identifier:
        raise ValueError('The revision payload failed its integrity check.')
    archive, revision = json.loads(data), json.loads(path.read_text())
    if (archive.get('version') != 2 or archive.get('automaticAnalysis') is not True
            or revision.get('automaticAnalysis') is not True or revision['id'] != identifier
            or revision['audioSHA256'] != archive['track']['analysis']['contentSHA256']):
        raise ValueError('Only matching automatic analysis revisions can be staged.')
    return payload, path


def command(arguments, log):
    result = subprocess.run(['xcrun', 'devicectl', *arguments, '--timeout', '45'],
                            capture_output=True, text=True, timeout=55)
    with log.open('a') as file:
        file.write(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'Device operation failed. See {log}.')


def domain(device):
    return ['--device', device, '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE]


def stage(outboxes, device, account, state):
    if not DIGEST.fullmatch(account):
        raise ValueError('Invalid iCloud account identifier.')
    state.mkdir(parents=True, exist_ok=True)
    log = state / 'device.log'
    current = state / 'last-account'
    command(['device', 'copy', 'from', *domain(device), '--source', ROOT + '/last-account',
             '--destination', str(current)], log)
    if current.read_text().strip() != account:
        raise RuntimeError('The device iCloud account changed. Delivery is paused.')
    queue = []
    for outbox in outboxes:
        for path in sorted(outbox.glob('*.json')):
            if not (state / (path.stem + '.staged')).exists():
                queue.append(read_revision(path))
    for payload, metadata in queue[:32]:
        # Commit the payload before its index. A running app can read only complete revisions.
        for source in [payload, metadata]:
            command(['device', 'copy', 'to', *domain(device), '--source', str(source),
                     '--destination', ROOT + '/' + account + '/' + source.name], log)
        (state / (metadata.stem + '.staged')).touch()
    return len(queue), min(32, len(queue))


def receipts(device, account, state):
    state.mkdir(parents=True, exist_ok=True)
    output = state / 'cloud-files.json'
    command(['device', 'info', 'files', *domain(device), '--subdirectory', ROOT + '/' + account,
             '--search', '.confirmed', '--quiet', '--json-output', str(output)], state / 'device.log')
    files = json.loads(output.read_text())['result']['files']
    return {pathlib.Path(f['name']).stem for f in files if f['name'].endswith('.confirmed')}
