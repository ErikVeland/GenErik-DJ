"""Copy exact iPad audio for failed identity checks, then analyse it on the Mac."""
import argparse
import datetime
import fcntl
import hashlib
import json
import pathlib
import shutil
import subprocess
import time
import uuid

from library_analysis_delivery import command, domain, read_revision
from run_library_analysis_campaign import save

TRANSFER = 'Documents/GenErikDJ-Development/MacAnalysisTransfer'


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def verify_source(path, response, expected):
    if digest(path) != response['sha256']:
        raise RuntimeError('The copied audio failed its integrity check.')
    if expected:
        analysis = expected['analysis']
        pairs = [('sha256', 'contentSHA256'), ('sampleRate', 'sampleRate'),
                 ('frameCount', 'frameCount'), ('channelCount', 'channelCount')]
        if any(response[left] != analysis[right] for left, right in pairs):
            raise RuntimeError('The current iPad audio differs from its saved identity. Retain it for review.')


def publish(output, destination, identifier):
    result_path = output / 'results' / (identifier + '.json')
    result = json.loads(result_path.read_text())
    if result.get('error') or not result.get('revisionID') or result['id'] != identifier:
        raise RuntimeError(result.get('error') or 'The recovered analysis is incomplete.')
    payload, metadata = read_revision(output / 'outbox' / (result['revisionID'] + '.json'))
    if json.loads(payload.read_text())['track']['analysis']['contentSHA256'] != result['audioSHA256']:
        raise RuntimeError('The recovered archive has a different audio identity.')
    target = destination / 'results' / result_path.name
    if target.exists():
        previous = json.loads(target.read_text())
        if previous.get('revisionID') == result['revisionID']:
            return
        if previous.get('revisionID') and not previous.get('error'):
            raise RuntimeError('Another successful result already exists. Retain both for review.')
        history = destination / 'failed-attempts'
        history.mkdir(exist_ok=True)
        shutil.copy2(target, history / (identifier + '-' + str(time.time_ns()) + '.json'))
    (destination / 'outbox').mkdir(parents=True, exist_ok=True)
    for path in [payload, metadata]:
        final = destination / 'outbox' / path.name
        temporary = final.with_suffix(final.suffix + '.recovering')
        shutil.copy2(path, temporary)
        temporary.replace(final)
    save(target, result)


def request_audio(item, device, root):
    root.mkdir(parents=True, exist_ok=True)
    request_path = root / 'request.json'
    if request_path.exists():
        request = json.loads(request_path.read_text())
    else:
        request = dict(version=1, id=str(uuid.uuid4()).upper(), sourceID=item['id'])
        save(request_path, request)
    log = root / 'device.log'
    command(['device', 'copy', 'to', *domain(device), '--source', str(request_path),
             '--destination', TRANSFER + '/request.json'], log)
    deadline = time.monotonic() + 1800
    while time.monotonic() < deadline:
        response_path = root / 'response.json'
        try:
            command(['device', 'copy', 'from', *domain(device), '--source', TRANSFER + '/response.json',
                     '--destination', str(response_path)], log)
            response = json.loads(response_path.read_text())
        except Exception:
            time.sleep(10)
            continue
        if response['id'] != request['id']:
            time.sleep(5)
            continue
        if response['state'] == 'failed':
            raise RuntimeError(response['error'])
        if response['state'] != 'ready':
            time.sleep(5)
            continue
        if response['filename'] != request['id'] + '.caf':
            raise RuntimeError('The device returned an unexpected audio filename.')
        audio = root / 'source.caf'
        command(['device', 'copy', 'from', *domain(device), '--source', TRANSFER + '/' + response['filename'],
                 '--destination', str(audio)], log)
        verify_source(audio, response, item.get('expected'))
        return audio
    raise TimeoutError('The iPad did not prepare the source while idle. The request can resume.')


def release_audio(device, root):
    path = root / 'release.json'
    save(path, dict(version=1, id=str(uuid.uuid4()).upper(), sourceID=None))
    command(['device', 'copy', 'to', *domain(device), '--source', str(path),
             '--destination', TRANSFER + '/request.json'], root / 'device.log')


def run(config, once=False):
    root = pathlib.Path(config['root'])
    recovery = root / 'source-recovery'
    recovery.mkdir(exist_ok=True)
    lock = (recovery / 'worker.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    items = json.loads(pathlib.Path(config['ipadManifest']).read_text())['items']
    app = config['recoveryApp']
    device = config['devices']['ipad']
    status = recovery / 'status.json'
    service = None
    service_log = (recovery / 'analyser.log').open('a')
    while True:
        recovered = 0
        for item in items:
            result_path = root / 'ipad' / 'results' / (item['id'] + '.json')
            if not result_path.exists():
                continue
            previous = json.loads(result_path.read_text())
            if not previous.get('error'):
                continue
            work = recovery / item['id']
            if (work / 'needs-review.json').exists():
                continue
            save(status, dict(state='recovering', id=item['id'], title=item['title'],
                              updatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat()))
            try:
                audio = request_audio(item, device, work)
                manifest = work / 'manifest.json'
                replacement = dict(item, paths=[str(audio)], usePreparedAudio=True)
                if not manifest.exists():
                    save(manifest, dict(items=[replacement]))
                elif json.loads(manifest.read_text()) != dict(items=[replacement]):
                    raise RuntimeError('The recovered source inventory changed.')
                output = work / 'analysis'
                if service is None or service.poll() is not None:
                    service = subprocess.Popen([app, '--library-analysis-service'], stdin=subprocess.PIPE,
                                               stdout=service_log, stderr=subprocess.STDOUT, text=True)
                receipt = work / ('analysis-receipt-' + str(uuid.uuid4()) + '.json')
                service.stdin.write(json.dumps(dict(manifest=str(manifest), output=str(output), receipt=str(receipt))) + '\n')
                service.stdin.flush()
                while not receipt.exists():
                    if service.poll() is not None:
                        raise TimeoutError('The Mac analyser stopped. Saved windows will resume.')
                    time.sleep(1)
                acknowledgement = json.loads(receipt.read_text())
                if not acknowledgement['complete']:
                    raise RuntimeError(acknowledgement['error'])
                publish(output, root / 'ipad', item['id'])
                release_audio(device, work)
                audio.unlink(missing_ok=True)
                recovered += 1
            except (TimeoutError, subprocess.TimeoutExpired) as error:
                save(status, dict(state='waiting-for-device', id=item['id'], error=str(error)))
                time.sleep(30)
                break
            except Exception as error:
                work.mkdir(exist_ok=True)
                # Device disconnects retry. Identity and decode failures remain visible for review.
                if str(error).startswith('Device operation failed.'):
                    save(status, dict(state='waiting-for-device', id=item['id'], error=str(error)))
                    time.sleep(30)
                    break
                save(work / 'needs-review.json', dict(id=item['id'], title=item['title'], error=str(error)))
        if once:
            if service is not None:
                service.stdin.close()
                service.wait()
            break
        save(status, dict(state='watching-for-failed-sources', recoveredThisPass=recovered,
                          updatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat()))
        time.sleep(30)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=pathlib.Path)
    parser.add_argument('--once', action='store_true')
    arguments = parser.parse_args()
    run(json.loads(arguments.config.read_text()), once=arguments.once)
