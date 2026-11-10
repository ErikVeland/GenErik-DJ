"""Run disjoint Mac analysis workers and publish verified results to one campaign."""
import argparse
import fcntl
import hashlib
import json
import pathlib
import re
import shutil
import struct
import subprocess
import time

from recover_library_analysis_sources import publish
from run_library_analysis_campaign import analysis_is_running, save


def terminal(result):
    return bool(result.get('revisionID') or result.get('error'))


def make_plan(manifest, output, workers):
    if not 1 <= workers <= 4:
        raise ValueError('Use between one and four offline workers.')
    data = manifest.read_bytes()
    fingerprint = hashlib.sha256(data).hexdigest()
    pool = output / 'pool'
    pool.mkdir(parents=True, exist_ok=True)
    plan_path = pool / 'plan.json'
    if plan_path.exists():
        plan = json.loads(plan_path.read_text())
        if plan['manifestSHA256'] != fingerprint or plan['workers'] != workers:
            raise RuntimeError('The worker inventory changed. Preserve this pool before starting another.')
        return plan
    items = json.loads(data)['items']
    if len({item['id'] for item in items}) != len(items):
        raise ValueError('The source inventory has duplicate identifiers.')
    shards = [[] for _ in range(workers)]
    excluded = []
    for item in items:
        previous = output / 'results' / (item['id'] + '.json')
        result = json.loads(previous.read_text()) if previous.exists() else {}
        profile = result.get('profile', {})
        if terminal(result) and profile.get('generation') == 14 and profile.get('decisionPolicy') == 14:
            excluded.append(item['id'])
            continue
        shards[sum(len(shard) for shard in shards) % workers].append(item)
    plan = dict(manifestSHA256=fingerprint, workers=workers, excluded=excluded, shards=[])
    for index, items in enumerate(shards):
        if not items:
            continue
        shard = pool / ('manifest-' + str(index) + '.json')
        work = pool / ('worker-' + str(index))
        work.mkdir(exist_ok=True)
        save(shard, dict(items=items))
        plan['shards'].append(dict(manifest=str(shard), output=str(work), ids=[item['id'] for item in items]))
        # Retain an interrupted first pass and its verified prediction windows.
        (work / 'results').mkdir(exist_ok=True)
        for item in items:
            previous = output / 'results' / (item['id'] + '.json')
            if not previous.exists():
                continue
            result = json.loads(previous.read_text())
            shutil.copy2(previous, work / 'results' / previous.name)
            analysis = result.get('firstPass')
            if not analysis:
                continue
            bits = struct.unpack('<Q', struct.pack('<d', analysis['sampleRate']))[0]
            key = hashlib.sha256(f"{analysis['contentSHA256']}|{bits}|{analysis['frameCount']}|{analysis['channelCount']}".encode()).hexdigest()
            for kind in ['DeepAnalysis', 'LearnedKey']:
                source = output / 'checkpoints' / kind / key
                if source.exists():
                    shutil.copytree(source, work / 'checkpoints' / kind / key, dirs_exist_ok=True)
    save(plan_path, plan)
    return plan


def publish_result(work, output, path):
    result = json.loads(path.read_text())
    if result['id'] != path.stem or not terminal(result):
        return False
    destination = output / 'results' / path.name
    previous = json.loads(destination.read_text()) if destination.exists() else {}
    if previous.get('revisionID') and not previous.get('error'):
        return True
    if result.get('revisionID') and not result.get('error'):
        publish(work, output, result['id'])
    else:
        save(destination, result)
    return True


def run(app, manifest, output, workers):
    output.mkdir(parents=True, exist_ok=True)
    lock = (output / 'run.lock').open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    saved = output / 'manifest.json'
    if saved.exists() and saved.read_bytes() != manifest.read_bytes():
        raise RuntimeError('The campaign inventory changed.')
    if not saved.exists():
        saved.write_bytes(manifest.read_bytes())
    (output / 'results').mkdir(exist_ok=True)
    plan = make_plan(manifest, output, workers)
    app_hash = hashlib.sha256(pathlib.Path(app).read_bytes()).hexdigest()
    if plan.get('appSHA256', app_hash) != app_hash:
        raise RuntimeError('The analyser changed. Preserve this pool before starting another.')
    if 'appSHA256' not in plan:
        plan['appSHA256'] = app_hash
        save(output / 'pool' / 'plan.json', plan)
    running = []
    logs = []
    readers = {}
    buffers = {}
    initial = {}
    for shard in plan['shards']:
        work = pathlib.Path(shard['output'])
        attached = analysis_is_running(work)
        completed = (work / 'finished.txt').exists() and all(
            (work / 'results' / (identifier + '.json')).exists()
            and terminal(json.loads((work / 'results' / (identifier + '.json')).read_text())) for identifier in shard['ids'])
        process = None
        if not attached and not completed:
            log = (work / 'run.log').open('a')
            logs.append(log)
            process = subprocess.Popen([app, '--library-analysis', shard['manifest'], str(work)],
                                       stdout=log, stderr=subprocess.STDOUT)
        running.append((shard, work, process, attached))
        (work / 'run.log').touch(exist_ok=True)
        readers[work] = (work / 'run.log').open(encoding='utf-8', errors='replace')
        buffers[work] = ''
        initial[work] = list((work / 'results').glob('*.json'))
    seen = {}
    final_scanned = set()
    while True:
        active = []
        failures = []
        for shard, work, process, attached in running:
            alive = process.poll() is None if process is not None else attached and analysis_is_running(work)
            paths = initial.pop(work, [])
            lines = (buffers[work] + readers[work].read()).split('\n')
            buffers[work] = lines.pop()
            for line in lines:
                match = re.match(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ (\d+)/(\d+) ', line)
                if match and int(match[2]) == len(shard['ids']) and 1 <= int(match[1]) <= len(shard['ids']):
                    paths.append(work / 'results' / (shard['ids'][int(match[1]) - 1] + '.json'))
            if not alive and work not in final_scanned:
                paths.extend((work / 'results').glob('*.json'))
                final_scanned.add(work)
            for path in set(paths):
                if not path.exists():
                    continue
                stamp = path.stat().st_mtime_ns
                if seen.get(path) != stamp and publish_result(work, output, path):
                    seen[path] = stamp
            if alive:
                active.append(work.name)
            elif process is not None and process.returncode:
                failures.append(dict(worker=work.name, exitCode=process.returncode))
            elif not (work / 'finished.txt').exists():
                failures.append(dict(worker=work.name, error='The worker stopped before completion.'))
        save(output / 'pool' / 'status.json', dict(active=active, failures=failures, published=len(seen),
                                                  previous=len(plan['excluded'])))
        if not active:
            if failures:
                raise RuntimeError('An offline worker stopped. Its results and checkpoints are retained.')
            break
        time.sleep(3)
    (output / 'finished.txt').write_text(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    for log in logs:
        log.close()
    for reader in readers.values():
        reader.close()
    lock.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True)
    parser.add_argument('--manifest', required=True, type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    run(args.app, args.manifest, args.output, args.workers)
