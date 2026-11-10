#!/usr/bin/env python3
"""Compare a native learned-key audit with the same files in a production audit."""
import argparse
import json
import math
from pathlib import Path

from verified_analysis_benchmark import require, score_report, sha256, valid_hash


def as_scoring_report(candidate):
    require(candidate.get('format') == 'generik.learned-key-audit/v1', 'Unsupported key audit format.')
    profile = candidate['profile']
    require(profile.get('modelID') and valid_hash(profile.get('weightsSHA256'))
            and valid_hash(candidate.get('modelArtifactSHA256')),
            'A learned model needs its identity and artifact hashes.')
    require(all(type(profile.get(k)) is int and profile[k] > 0
                for k in ('preprocessingVersion', 'conversionVersion', 'decisionPolicyVersion')),
            'A learned model needs preprocessing, conversion and decision versions.')
    rows = []
    for row in candidate['rows']:
        analysis = None
        if row.get('contentSHA256'):
            analysis = {'contentSHA256': row['contentSHA256'], 'key': row.get('key'),
                        'keyConfidence': row.get('confidence')}
        if row.get('key'):
            probabilities = row.get('probabilities', [])
            require(len(probabilities) == 24 and all(math.isfinite(v) and 0 <= v <= 1 for v in probabilities)
                    and abs(sum(probabilities) - 1) < 1e-6, 'Invalid key probability distribution.')
            winner = max(range(24), key=probabilities.__getitem__)
            require(profile['classOrder'][winner] == row['key']
                    and abs(probabilities[winner] - row['confidence']) < 1e-6,
                    'The reported key differs from its model distribution.')
        rows.append({'id': row['id'], 'firstPass': analysis, 'error': row.get('error')})
    return dict(candidate, rows=rows)


def compare(data, baseline, candidate):
    require({t['id']: t['sha256'] for t in baseline['manifest']['tracks']}
            == {t['id']: t['sha256'] for t in candidate['manifest']['tracks']},
            'Both runs must use exactly the same audio files.')
    first = score_report(data, baseline)
    learned = score_report(data, as_scoring_report(candidate))
    previous = {t['id']: t['tiers']['final']['key'] for t in first['tracks']}
    current = {t['id']: t['tiers']['final']['key'] for t in learned['tracks']}
    references = {t['id']: t for t in data['tracks']}
    rows = [{'id': identity, 'genre': references[identity]['genre'],
             'baseline': previous[identity], 'candidate': current[identity]} for identity in previous]
    wins = sum(not r['baseline']['exact'] and r['candidate']['exact'] for r in rows)
    losses = sum(r['baseline']['exact'] and not r['candidate']['exact'] for r in rows)
    by_genre = {}
    for genre in sorted({r['genre'] for r in rows}):
        group = [r for r in rows if r['genre'] == genre]
        by_genre[genre] = {'tracks': len(group), 'baselineExact': sum(r['baseline']['exact'] for r in group),
                           'candidateExact': sum(r['candidate']['exact'] for r in group)}
    return {'format': 'generik.key-comparison/v1', 'benchmarkVersion': data['version'],
            'split': first['split'], 'baselineRunID': baseline['runID'], 'candidateRunID': candidate['runID'],
            'model': candidate['profile'], 'modelArtifactSHA256': candidate['modelArtifactSHA256'],
            'baseline': first['tiers']['final']['key'], 'candidate': learned['tiers']['final']['key'],
            'pairedWins': wins, 'pairedLosses': losses, 'byGenre': by_genre, 'tracks': rows,
            'candidateSeconds': sum(r.get('wallSeconds') or 0 for r in candidate['rows']),
            'scope': 'Exact keys on published high-confidence, stable-key excerpts. Related keys receive no exact credit. Unresolved results remain in the denominator.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('benchmark', type=Path)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    require(not args.output.exists(), 'Choose a new output file. Existing evidence was retained.')
    result = compare(*(json.loads(p.read_text()) for p in (args.benchmark, args.baseline, args.candidate)))
    result['inputSHA256'] = {name: sha256(getattr(args, name)) for name in ('benchmark', 'baseline', 'candidate')}
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + '\n')
    print(json.dumps({k: result[k] for k in ('split', 'baseline', 'candidate', 'pairedWins', 'pairedLosses', 'candidateSeconds')}, indent=2))


if __name__ == '__main__':
    main()
