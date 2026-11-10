#!/usr/bin/env python3
"""Validate human references and score production Mac audit timelines."""
import argparse
import bisect
import hashlib
import json
import math
import re
from pathlib import Path

from mac_analysis_report import percentile, timing_summary


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def valid_hash(value):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value) is not None


def valid_times(times):
    return (isinstance(times, list) and len(times) > 0
            and all(isinstance(t, (int, float)) and math.isfinite(t) and t >= 0 for t in times)
            and all(a < b for a, b in zip(times, times[1:])))


def validate(data, verify_audio=False):
    require(data.get('format') == 'generik.verified-analysis/v1', 'Unsupported benchmark format.')
    require(bool(data.get('version')) and bool(data.get('tracks')), 'Version and tracks are required.')
    sources = data.get('sources', {})
    ids, groups, audio_hashes = set(), {}, set()
    for track in data['tracks']:
        identity = track['id']
        require(identity and identity not in ids, 'Track IDs must be unique.')
        ids.add(identity)
        require(valid_hash(track['sha256']), 'Invalid audio hash.')
        require(track['split'] in ('development', 'holdout'), 'Invalid split.')
        require(bool(track['groups']) and all(track['groups']), 'Recording and artist groups are required.')
        for group in track['groups'] + ['audio:' + track['sha256']]:
            require(group not in groups or groups[group] == track['split'], 'A group crosses a split: ' + group)
            groups[group] = track['split']
        require(track['sha256'] not in audio_hashes, 'Duplicate audio within the benchmark: ' + identity)
        audio_hashes.add(track['sha256'])
        require(bool(track['labels']), 'A track needs at least one scoped label.')
        for field, label in track['labels'].items():
            require(field in ('beats', 'downbeats', 'key'), 'Unsupported label field.')
            source = sources.get(label.get('source'), {})
            require(source.get('origin') == 'published-human', 'Verified scores require a published human source.')
            require(source.get('url') and source.get('revision') and valid_hash(source.get('sha256')),
                    'A label source needs its URL, revision and hash.')
            require(valid_hash(label.get('annotationSHA256', source['sha256'])), 'Invalid annotation hash.')
            if field in ('beats', 'downbeats'):
                require(valid_times(label.get('times')), 'Event times must increase and contain finite values.')
            else:
                require(type(label.get('tonic')) is int and 0 <= label['tonic'] < 12
                        and label.get('mode') in ('major', 'minor'), 'Invalid major/minor key label.')
        if 'downbeats' in track['labels'] and 'beats' in track['labels']:
            beats = track['labels']['beats']['times']
            require(all(any(abs(t - b) <= 1e-6 for b in beats)
                        for t in track['labels']['downbeats']['times']), 'Downbeats must be annotated beats.')
        if verify_audio:
            require(sha256(track['path']) == track['sha256'], 'Audio hash changed: ' + identity)


def event_score(reference, predicted, tolerance=0.025):
    require(valid_times(reference), 'Reference events must increase.')
    require(not predicted or valid_times(predicted), 'Predicted events must increase.')
    require(math.isfinite(tolerance) and tolerance > 0, 'Invalid event tolerance.')
    # The annotation file only establishes coverage between its first and last events.
    predicted = [t for t in predicted if reference[0] - tolerance <= t <= reference[-1] + tolerance]
    i = j = 0
    matched_errors = []
    while i < len(reference) and j < len(predicted):
        difference = predicted[j] - reference[i]
        if abs(difference) <= tolerance + 1e-12:
            matched_errors.append(abs(difference) * 1000)
            i += 1
            j += 1
        elif difference < 0:
            j += 1
        else:
            i += 1
    nearest_errors = []
    if predicted:
        for time in reference:
            k = bisect.bisect_left(predicted, time)
            nearest_errors.append(min(abs(time - p) for p in predicted[max(0, k - 1):k + 1]) * 1000)
    matched = len(matched_errors)
    precision = matched / len(predicted) if predicted else 0
    recall = matched / len(reference)
    return {
        'referenceEvents': len(reference), 'predictedEvents': len(predicted), 'matched': matched,
        'precision': precision, 'recall': recall,
        'f1': 2 * matched / (len(reference) + len(predicted)),
        'matchedP95ErrorMs': percentile(matched_errors, 0.95),
        'p95NearestErrorMs': percentile(nearest_errors, 0.95),
        'annotationCoverageSeconds': [reference[0], reference[-1]],
    }


def key_score(expected, predicted):
    relation, weight = 'wrong', 0.0
    if not predicted:
        relation = 'unresolved'
    elif expected['tonic'] == predicted['tonic'] and expected['mode'] == predicted['mode']:
        relation, weight = 'exact', 1.0
    elif expected['mode'] == predicted['mode'] and (predicted['tonic'] - expected['tonic']) % 12 == 7:
        relation, weight = 'fifth', 0.5
    elif expected['mode'] != predicted['mode']:
        relative = (expected['tonic'] + (9 if expected['mode'] == 'major' else 3)) % 12
        if predicted['tonic'] == relative:
            relation, weight = 'relative', 0.3
        elif predicted['tonic'] == expected['tonic']:
            relation, weight = 'parallel', 0.2
    return {'exact': relation == 'exact', 'relation': relation, 'weighted': weight}


def audit_manifest(data, split, ids=None):
    validate(data)
    selected = [t for t in data['tracks'] if t['split'] == split and (ids is None or t['id'] in ids)]
    require(bool(selected), 'No tracks match this selection.')
    if ids is not None:
        require(set(ids) == {t['id'] for t in selected}, 'Some selected IDs are absent from this split.')
    return {
        'format': 'tdj1.analysis-benchmark/v1', 'corpus': 'humanReference',
        'referenceBuild': data['version'], 'requiredTags': [],
        'limits': {'maximumBPMError': 0.1, 'maximumBeatPhaseErrorMilliseconds': 25,
                   'maximumGridDriftMilliseconds': 20, 'maximumDownbeatErrorMilliseconds': 25,
                   'maximumSimilarEnergyDistance': 1},
        'tracks': [{'id': t['id'], 'path': t['path'], 'sha256': t['sha256'],
                    'annotation': 'External human reference. Answers are excluded from analysis input.',
                    'tags': [t['dataset'], split], 'tempo': {'status': 'unlabelled'},
                    'key': {'status': 'unlabelled'}, 'downbeat': {'status': 'unlabelled'}} for t in selected],
        'energyComparisons': [],
    }


def score_report(data, report):
    validate(data)
    require(report.get('completedUTC'), 'The audit is incomplete. Preserve it and finish the run before scoring.')
    tracks = {t['id']: t for t in data['tracks']}
    inputs = {t['id']: t for t in report['manifest']['tracks']}
    rows = {r['id']: r for r in report['rows']}
    require(len(rows) == len(report['rows']) and rows.keys() == inputs.keys(), 'Audit rows do not match inputs.')
    require(len(inputs) == len(report['manifest']['tracks']), 'Duplicate audit inputs.')
    require(inputs.keys() <= tracks.keys(), 'Unknown audit track.')
    selected = [tracks[i] for i in inputs]
    require(len({t['split'] for t in selected}) == 1, 'Do not combine development and holdout scores.')
    output = []
    for identity, row in rows.items():
        track = tracks[identity]
        require(inputs[identity]['sha256'] == track['sha256'], 'Manifest hash differs from benchmark.')
        item = {'id': identity, 'dataset': track['dataset'], 'error': row.get('error'), 'tiers': {}}
        for tier, analysis_field, timeline_field in (
                ('first', 'firstPass', 'firstPassTimeline'), ('final', 'finalAnalysis', 'finalTimeline'),
                ('review', 'finalAnalysis', 'reviewTimeline')):
            analysis = row.get(analysis_field) or (row.get('firstPass') if tier != 'first' else None)
            timeline = row.get(timeline_field)
            if tier != 'first':
                timeline = timeline or row.get('finalTimeline') or row.get('firstPassTimeline')
            if analysis:
                require(analysis['contentSHA256'] == track['sha256'], 'Analysis hash differs from benchmark.')
            scored = {}
            for field, label in track['labels'].items():
                if field == 'key':
                    scored[field] = key_score(label, analysis.get('key') if analysis else None)
                    scored[field]['confidence'] = analysis.get('keyConfidence') if analysis else None
                else:
                    require(not analysis or timeline is not None, 'Audit lacks the actual playback timeline.')
                    scored[field] = event_score(label['times'], (timeline or {}).get(field, []))
                    confidence = 'tempoConfidence' if field == 'beats' else 'downbeatConfidence'
                    scored[field]['confidence'] = (analysis.get(confidence) if analysis else None)
                    if tier == 'review' and row.get('reviewTimeline') is not None:
                        scored[field]['confidence'] = None
            item['tiers'][tier] = scored
        output.append(item)
    tiers = {}
    for tier in ('first', 'final', 'review'):
        scores = {}
        for field in ('beats', 'downbeats', 'key'):
            values = [t['tiers'][tier][field] for t in output if field in t['tiers'][tier]]
            if not values:
                continue
            summary = {'referenceTracks': len(values)}
            if field == 'key':
                summary.update(exact=sum(v['exact'] for v in values),
                               resolved=sum(v['relation'] != 'unresolved' for v in values),
                               exactAccuracy=sum(v['exact'] for v in values) / len(values),
                               weightedAccuracy=sum(v['weighted'] for v in values) / len(values))
            else:
                for name in ('referenceEvents', 'predictedEvents', 'matched'):
                    summary[name] = sum(v[name] for v in values)
                summary.update(precision=summary['matched'] / max(1, summary['predictedEvents']),
                               recall=summary['matched'] / summary['referenceEvents'],
                               microF1=2 * summary['matched'] / (summary['referenceEvents'] + summary['predictedEvents']),
                               macroF1=sum(v['f1'] for v in values) / len(values),
                               tracksWith95PercentEvents=sum(v['precision'] >= .95 and v['recall'] >= .95 for v in values))
            summary['confidenceBins'] = []
            for low, high in ((0, .5), (.5, .8), (.8, 1.000001)):
                group = [v for v in values if v['confidence'] is not None and low <= v['confidence'] < high]
                summary['confidenceBins'].append({'low': low, 'high': min(1, high), 'tracks': len(group),
                                                 'meanScore': sum(v['exact'] if field == 'key' else v['f1']
                                                                  for v in group) / len(group) if group else None})
            scores[field] = summary
        tiers[tier] = scores
    return {
        'format': 'generik.verified-analysis-score/v1', 'benchmarkVersion': data['version'],
        'benchmarkSHA256': hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest(),
        'runID': report['runID'], 'split': selected[0]['split'], 'tracks': output, 'tiers': tiers,
        'scope': 'Published human references. One-to-one events at 25 ms. Only annotated spans are scored. Excerpt results do not establish full-track accuracy.',
        'timings': {f: timing_summary([r.get(f) for r in rows.values()])
                    for f in ('firstPassPerformance', 'deepPerformance', 'reusePerformance')},
        'failures': sum(bool(r.get('error')) for r in rows.values()),
        'reviewCandidates': sum(r.get('reviewTimeline') is not None for r in rows.values()),
        'reviewScope': 'Hypothetical acceptance of offered adaptive candidates. Final scores remain the actual playback timeline.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['validate', 'manifest', 'score'])
    parser.add_argument('benchmark', type=Path)
    parser.add_argument('--verify-audio', action='store_true')
    parser.add_argument('--split', choices=['development', 'holdout'])
    parser.add_argument('--ids', type=Path, help='JSON array of frozen cohort IDs.')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    data = json.loads(args.benchmark.read_text())
    validate(data, verify_audio=args.verify_audio)
    if args.operation == 'validate':
        print(f"Validated {len(data['tracks'])} tracks in {data['version']}.")
        return
    require(args.output and not args.output.exists(), 'Choose a new output file. Existing evidence was retained.')
    if args.operation == 'manifest':
        result = audit_manifest(data, args.split, json.loads(args.ids.read_text()) if args.ids else None)
    else:
        require(args.report is not None, 'A report is required.')
        result = score_report(data, json.loads(args.report.read_text()))
        result['reportSHA256'] = sha256(args.report)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(args.output)


if __name__ == '__main__':
    main()
