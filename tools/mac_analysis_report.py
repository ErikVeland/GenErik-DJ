#!/usr/bin/env python3
"""Summarise Mac audit timings and agreement with saved reference grids."""
import argparse
import json
import math
from pathlib import Path


def percentile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    position = fraction * (len(values) - 1)
    lower = math.floor(position)
    return values[lower] + (values[math.ceil(position)] - values[lower]) * (position - lower)


def grid_metrics(bpm, anchor, bar, expected, duration, sample_rate):
    if expected['tempo']['status'] != 'labelled':
        return None
    if not bpm or anchor is None:
        return {'resolved': False}
    reference = expected['tempo']
    period, reference_period = 60 / bpm, 60 / reference['bpm']
    origin = reference['beatAnchorSeconds']
    first = math.floor((origin - anchor) / period + 0.5)
    phase = anchor + first * period - origin
    last = max(0, math.floor((duration - 1 / sample_rate - origin) / reference_period))
    end = phase + last * (period - reference_period)
    errors = [abs(phase + beat * (period - reference_period)) * 1000 for beat in range(last + 1)]
    result = {
        'resolved': True, 'bpm': bpm, 'bpmError': abs(bpm - reference['bpm']),
        'bpmErrorPercent': abs(bpm / reference['bpm'] - 1) * 100,
        'beatPhaseMs': abs(phase) * 1000,
        'maxFullTrackGridErrorMs': max(abs(phase), abs(end)) * 1000,
        'p95FullTrackGridErrorMs': percentile(errors, 0.95),
        'downbeatPhaseMs': None,
    }
    if bar is not None and expected['downbeat']['status'] == 'labelled':
        offset = bar - expected['downbeat']['barStartSeconds']
        bar_period = period * 4
        result['downbeatPhaseMs'] = abs(offset - math.floor(offset / bar_period + 0.5) * bar_period) * 1000
    return result


def timing_summary(records):
    records = [r for r in records if r and r['outcome'] == 'success']
    walls = [r['wallSeconds'] for r in records]
    seconds = sum(walls)
    audio = sum(r.get('durationSeconds') or 0 for r in records)
    return {
        'tracks': len(records), 'wallSeconds': seconds, 'audioSeconds': audio,
        'timesRealtime': audio / seconds if seconds else None,
        'secondsPerAudioMinute': seconds * 60 / audio if audio else None,
        'p50Seconds': percentile(walls, 0.5), 'p90Seconds': percentile(walls, 0.9),
        'p95Seconds': percentile(walls, 0.95),
        'processCPUSeconds': sum(r.get('processCPUSeconds') or 0 for r in records),
        'processLifetimePeakRSSBytes': max((r.get('processLifetimePeakRSSBytes') or 0 for r in records), default=0),
        'thermalStates': sorted({r.get(key, 'unknown') for r in records for key in ['thermalStart', 'thermalEnd']}),
    }


def analysis_grid_metrics(analysis, labels):
    rate = analysis['sampleRate']
    bpm = analysis.get('bpm')
    anchor = analysis.get('beatAnchorFrame')
    anchor = anchor / rate if anchor is not None else None
    offset = analysis.get('detectedDownbeatOffset')
    bar = anchor + offset * 60 / bpm if bpm and anchor is not None and offset is not None else None
    return grid_metrics(bpm, anchor, bar, labels, analysis['frameCount'] / rate, rate)


def summarise(report, provenance):
    expected = {row['id']: row for row in report['manifest']['tracks']}
    sources = {row['id']: row for row in provenance['tracks']}
    output = []
    for row in report['rows']:
        source, labels = sources[row['id']], expected[row['id']]
        analysis = row.get('firstPass')
        item = {'id': row['id'], 'title': source['title'], 'error': row.get('error')}
        if not analysis:
            output.append(item)
            continue
        assert analysis['contentSHA256'] == labels['sha256'] == source['audioSHA256']
        duration = analysis['frameCount'] / analysis['sampleRate']
        item.update(durationSeconds=duration, referenceBPM=labels['tempo'].get('bpm'))
        anchor = analysis.get('beatAnchorFrame')
        anchor = anchor / analysis['sampleRate'] if anchor is not None else None
        bpm = analysis.get('bpm')
        offset = analysis.get('detectedDownbeatOffset')
        bar = anchor + offset * 60 / bpm if bpm and anchor is not None and offset is not None else None
        item['firstPass'] = grid_metrics(bpm, anchor, bar, labels, duration, analysis['sampleRate'])
        candidate = row.get('deep', {}).get('candidate', {})
        item['deepCandidate'] = grid_metrics(
            candidate.get('bpm'), candidate.get('firstBarSeconds'), candidate.get('firstBarSeconds'),
            labels, duration, analysis['sampleRate'])
        item['deepAccepted'] = row.get('acceptedOverFirstPass', False)
        item['finalGrid'] = item['deepCandidate'] if item['deepAccepted'] else item['firstPass']
        if row.get('finalAnalysis'):
            assert row['finalAnalysis']['contentSHA256'] == analysis['contentSHA256']
            item['finalGrid'] = analysis_grid_metrics(row['finalAnalysis'], labels)
        item['deepTempoAccepted'] = row.get('acceptedTempoOnly', False)
        item['deepTempoCandidateBPM'] = row.get('deep', {}).get('tempoCandidateBPM')
        item['deepEvidence'] = candidate
        item['keyExact'] = analysis.get('key') == labels['key'].get('key') if labels['key']['status'] == 'labelled' else None
        item['ourKey'] = analysis.get('key')
        item['referenceKey'] = labels['key'].get('key')
        item['reuseMatches'] = row.get('reuseMatches', False)
        for field in ['firstPassPerformance', 'deepPerformance', 'reusePerformance']:
            item[field] = row.get(field)
        output.append(item)
    scores = {}
    for tier in ['firstPass', 'deepCandidate', 'finalGrid']:
        labelled = [r[tier] for r in output if r.get(tier) is not None]
        resolved = [r for r in labelled if r['resolved']]
        scores[tier] = {
            'referenceTracks': len(labelled), 'resolved': len(resolved),
            'bpmWithinPointOne': sum(r['bpmError'] <= 0.1 for r in resolved),
            'bpmWithinTwoPercent': sum(r['bpmErrorPercent'] <= 2 for r in resolved),
            'beatPhaseWithin25ms': sum(r['beatPhaseMs'] <= 25 for r in resolved),
            'downbeatPhaseWithin25ms': sum(r['downbeatPhaseMs'] is not None and r['downbeatPhaseMs'] <= 25 for r in resolved),
            'fullTrackGridWithin25ms': sum(r['maxFullTrackGridErrorMs'] <= 25 for r in resolved),
        }
    return {
        'format': 'generik.mac-analysis-summary/v1', 'runID': report['runID'],
        'completed': report.get('completedUTC') is not None,
        'scope': 'Saved-reference agreement on a small selected sample, not independently labelled accuracy.',
        'timingScope': 'Production Mac app diagnostic. Fresh analysis caches; ordinary filesystem and OS model caches. Queue scheduling and UI playback are not measured.',
        'timings': {field: timing_summary([r.get(field) for r in output]) for field in ['firstPassPerformance', 'deepPerformance', 'reusePerformance']},
        'scores': scores, 'keyExact': sum(r.get('keyExact') is True for r in output),
        'keyReferences': sum(r.get('keyExact') is not None for r in output),
        'deepAccepted': sum(r.get('deepAccepted', False) for r in output),
        'deepTempoAccepted': sum(r.get('deepTempoAccepted', False) for r in output), 'tracks': output,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('provenance', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Choose a new output file. Existing evidence was retained.')
    result = summarise(json.loads(args.report.read_text()), json.loads(args.provenance.read_text()))
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'tracks'}, indent=2))


if __name__ == '__main__':
    main()
