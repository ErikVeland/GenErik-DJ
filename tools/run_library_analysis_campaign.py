"""Run the iPad inventory, verify its cloud delivery, then analyse the remaining local library."""
import argparse
import collections
import datetime
import fcntl
import json
import os
import pathlib
import shutil
import subprocess
import threading
import time

from library_analysis_delivery import stage, receipts
from prepare_library_analysis import mac_items

_result_cache = {}


def save(path, value):
    temporary = path.with_suffix('.new')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True))
    temporary.replace(path)


def summary(output):
    results = []
    for path in (output / 'results').glob('*.json'):
        stamp = path.stat().st_mtime_ns
        if path not in _result_cache or _result_cache[path][0] != stamp:
            _result_cache[path] = stamp, json.loads(path.read_text())
        results.append(_result_cache[path][1])
    return dict(processed=len(results), complete=sum(bool(r.get('revisionID')) for r in results),
                errors=[dict(id=r['id'], error=r['error']) for r in results if r.get('error')],
                revisions=sorted({r['revisionID'] for r in results if r.get('revisionID')}))


def make_remaining(mac, ipad, destination):
    done = {r['source'] for p in (ipad / 'results').glob('*.json')
            if (r := json.loads(p.read_text())).get('revisionID')}
    unique = {}
    excluded = collections.Counter()
    for item in mac_items(mac):
        path = item['path']
        if item['protected']:
            excluded['protected'] += 1
        elif not pathlib.Path(path).is_file():
            excluded['unavailable'] += 1
        elif path in done:
            excluded['iPadRun'] += 1
        elif path in unique:
            excluded['duplicatePath'] += 1
        else:
            unique[path] = item
    items = [dict(id=item['persistentID'], title=item['title'], artist=item['artist'],
                  paths=[item['path']], expected=None) for item in
             sorted(unique.values(), key=lambda x: (x['duration'], x['persistentID']))]
    manifest = dict(items=items)
    if destination.exists():
        if json.loads(destination.read_text()) != manifest:
            raise RuntimeError('The full-library inventory changed. Preserve the previous run before continuing.')
    else:
        save(destination, manifest)
    return len(items), dict(excluded)


def run(config):
    root = pathlib.Path(config['root'])
    if not root.is_dir():
        raise RuntimeError('The analysis volume is unavailable.')
    lock = (root / 'campaign.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    stop = threading.Event()
    outputs = [root / 'ipad', root / 'full']
    delivery_state = {}
    state_lock = threading.Lock()

    def delivery():
        while not stop.is_set():
            update = dict(updatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
            try:
                queued, staged = stage([p / 'outbox' for p in outputs], config['uploader'], config['account'], root / 'delivery' / 'uploader')
                update.update(waitingToStage=queued - staged, stagedThisCycle=staged)
            except Exception as error:
                update['uploadError'] = str(error)
            for name, device in config['devices'].items():
                try:
                    update[name] = sorted(receipts(device, config['account'], root / 'delivery' / name))
                except Exception as error:
                    update[name + 'Error'] = str(error)
            with state_lock:
                delivery_state.clear()
                delivery_state.update(update)
                save(root / 'delivery-status.json', update)
            stop.wait(60)

    thread = threading.Thread(target=delivery, daemon=True)
    thread.start()
    try:
        for phase in ['ipad', 'full']:
            if phase == 'full':
                previous = summary(root / 'ipad')
                if previous['errors'] or previous['complete'] != config['ipadCount']:
                    raise RuntimeError('The iPad run has unresolved tracks. The full-library phase is waiting.')
                expected = set(previous['revisions'])
                while True:
                    with state_lock:
                        confirmed = set(delivery_state.get('ipad', []))
                    if expected <= confirmed:
                        break
                    save(root / 'campaign-status.json', dict(phase='waiting-for-ipad-delivery',
                         results=len(expected), confirmed=len(expected & confirmed)))
                    time.sleep(30)
                count, excluded = make_remaining(json.loads(pathlib.Path(config['macCatalog']).read_text()),
                                                 root / 'ipad', root / 'full-manifest.json')
                save(root / 'full-inventory.json', dict(tracks=count, excluded=excluded))
            manifest = pathlib.Path(config['ipadManifest']) if phase == 'ipad' else root / 'full-manifest.json'
            if shutil.disk_usage(root).free < 5 * 1024**3:
                raise RuntimeError('Less than 5 GB is free on the analysis volume. The run is paused.')
            with (root / (phase + '.log')).open('a') as log:
                process = subprocess.Popen([config['app'], '--library-analysis', str(manifest), str(root / phase)],
                                           stdout=log, stderr=subprocess.STDOUT)
                save(root / 'campaign-status.json', dict(phase=phase, processID=process.pid, state='running'))
                while process.poll() is None:
                    status = summary(root / phase)
                    save(root / 'campaign-status.json', dict(phase=phase, processID=process.pid, state='running', **status))
                    time.sleep(30)
                if process.returncode:
                    raise RuntimeError(f'The {phase} analyser stopped with status {process.returncode}. Results are retained.')
        # Keep delivery active until every configured device acknowledges every result.
        expected = set(summary(root / 'ipad')['revisions']) | set(summary(root / 'full')['revisions'])
        while True:
            with state_lock:
                counts = {name: len(expected & set(delivery_state.get(name, []))) for name in config['devices']}
            save(root / 'campaign-status.json', dict(phase='delivery', results=len(expected), confirmed=counts,
                 ipad=summary(root / 'ipad'), full=summary(root / 'full')))
            if all(count == len(expected) for count in counts.values()):
                break
            time.sleep(30)
    except Exception as error:
        save(root / 'campaign-status.json', dict(state='needs-attention', error=str(error)))
        # Retain the delivery worker while completed results still need acknowledgements.
        while True:
            time.sleep(30)
    finally:
        stop.set()
        thread.join(timeout=60)
        lock.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=pathlib.Path)
    args = parser.parse_args()
    run(json.loads(args.config.read_text()))
