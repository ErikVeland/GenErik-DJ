#!/usr/bin/env python3
"""Compare saved neural events with the accepted Mac playback timeline."""
import argparse
import base64
import collections
import hashlib
import json
import math
import struct
from pathlib import Path

from verified_analysis_benchmark import event_score, require, sha256, validate


def peaks(logits, interpolate=False):
    groups = []
    previous = -2
    for index, value in enumerate(logits):
        if value <= 0 or any(other > value for other in logits[max(0, index - 3):index + 4]):
            continue
        if index > previous + 1:
            groups.append([])
        groups[-1].append(index)
        previous = index
    output = []
    for group in groups:
        position = sum(group) / len(group)
        if interpolate and len(group) == 1 and 0 < group[0] < len(logits) - 1:
            index = group[0]
            left, center, right = logits[index - 1:index + 2]
            denominator = left - 2 * center + right
            if denominator < -1e-9:
                position += max(-.5, min(.5, .5 * (left - right) / denominator))
        output.append(position / 50)
    return output


def reconstruct(root, report):
    profile = report['deepProfile']
    identity = f"{profile['model']}|{profile['weightsSHA256']}|fp16-{profile['conversion']}|mel-{profile['preprocessing']}|1500-6-50"
    inference = hashlib.sha256(identity.encode()).hexdigest()
    saved = collections.defaultdict(dict)
    digests = {}
    for path in root.rglob('window-*.json'):
        envelope = json.loads(path.read_text())
        require(envelope['inferenceID'] == inference, 'Prediction model differs from the report.')
        window = envelope['window']
        encoded = json.dumps(window, sort_keys=True, separators=(',', ':')).replace('/', '\\/').encode()
        require(hashlib.sha256(encoded).hexdigest() == envelope['digest'], 'Prediction checksum differs.')
        audio = envelope['audio']['sha256']
        require(window['index'] not in saved[audio], 'Duplicate prediction window.')
        saved[audio][window['index']] = envelope
        digests[str(path.relative_to(root))] = sha256(path)
    output = {}
    for row in report['rows']:
        if not row.get('deep'):
            continue
        analysis = row['firstPass']
        audio = analysis['contentSHA256']
        frames = math.floor(analysis['frameCount'] * 22050 / analysis['sampleRate'] + .5) // 441 + 1
        starts = list(range(-6, frames - 6, 1488))
        if frames > 1488:
            starts[-1] = frames - 1500 + 6
        require(set(saved[audio]) == set(range(len(starts))), 'Prediction windows are incomplete.')
        beats, bars = [], []
        for index, start in enumerate(starts):
            envelope = saved[audio][index]
            require(envelope['audio'] == row['deep']['audio'], 'Prediction audio identity differs.')
            window = envelope['window']
            require(window['start'] == start, 'Prediction window starts at the wrong frame.')
            values = struct.unpack('<3000f', base64.b64decode(window['logits'], validate=True))
            require(all(math.isfinite(v) for v in values), 'Prediction contains non-finite values.')
            first, end = max(6, len(beats) - start), min(1494, frames - start)
            beats.extend(values[first:end])
            bars.extend(values[1500 + first:1500 + end])
        require(len(beats) == frames and len(bars) == frames, 'Prediction coverage differs.')
        output[row['id']] = (beats, bars)
    return output, digests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('benchmark', type=Path)
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    require(not args.output.exists(), 'Choose a new output file. Existing evidence was retained.')
    benchmark, report = json.loads(args.benchmark.read_text()), json.loads(args.report.read_text())
    validate(benchmark)
    require(report.get('completedUTC'), 'The Mac audit is incomplete.')
    references = {t['id']: t for t in benchmark['tracks']}
    require(all(references[r['id']]['split'] == 'development' for r in report['rows']),
            'This exploratory probe only accepts development data.')
    windows, hashes = reconstruct(args.report.parent / 'checkpoints', report)
    rows = []
    for row in report['rows']:
        reference = references[row['id']]
        scores = {}
        for variant in ('accepted', 'neural-events', 'neural-interpolated'):
            if variant == 'accepted':
                timeline = row.get('finalTimeline') or row.get('firstPassTimeline') or {}
            else:
                beats, bars = windows.get(row['id'], ([], []))
                beat_times = peaks(beats, interpolate=variant == 'neural-interpolated')
                bar_times = peaks(bars)
                snapped = sorted(set(min(beat_times, key=lambda t: abs(t - b)) for b in bar_times)) if beat_times else []
                timeline = {'beats': beat_times, 'downbeats': snapped}
            scores[variant] = {field: event_score(label['times'], timeline.get(field, []))
                               for field, label in reference['labels'].items() if field != 'key'}
        rows.append({'id': row['id'], 'genre': reference['genre'], 'scores': scores})
    summary = {}
    for variant in ('accepted', 'neural-events', 'neural-interpolated'):
        summary[variant] = {}
        for field in ('beats', 'downbeats'):
            values = [r['scores'][variant][field] for r in rows if field in r['scores'][variant]]
            totals = {k: sum(v[k] for v in values) for k in ('matched', 'referenceEvents', 'predictedEvents')}
            summary[variant][field] = dict(totals, macroF1=sum(v['f1'] for v in values) / len(values),
                                           microF1=2 * totals['matched'] / (totals['referenceEvents'] + totals['predictedEvents']))
    result = {'format': 'generik.rhythm-probe/v1', 'reportSHA256': sha256(args.report),
              'benchmarkSHA256': sha256(args.benchmark), 'model': report['deepProfile'],
              'checkpointSHA256': hashes, 'summary': summary, 'tracks': rows,
              'scope': 'Development diagnostic from Mac model predictions. Neural events are not accepted playback grids.'}
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
