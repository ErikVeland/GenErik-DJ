#!/usr/bin/env python3
"""Fit the fixed R124 rhythm estimator from prior development cohorts only."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize
from scipy.special import expit

from verified_analysis_benchmark import score_report

ROOT = Path(__file__).resolve().parents[1]
FEATURES = ['beatLowerDecileLogit', 'medianPeakCurvature', 'barPhaseContrast',
            'intervalVariation', 'constantFitResidualMs', 'strongConstantFit']
COHORTS = [('development', 'analysis-benchmark-r116-gtzan.json', 'development'),
           ('holdout', 'analysis-benchmark-r116-gtzan.json', 'holdout'),
           ('independent', 'analysis-benchmark-r118-rhythm.json', 'holdout')]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rows_for(benchmark, report):
    scores = score_report(benchmark, report)
    scored = {row['id']: row for row in scores['tracks']}
    rows = []
    for row in report['rows']:
        if row.get('error') or not row.get('reuseMatches'):
            raise ValueError('A completed, reopened result is required.')
        deep = row['deep']
        evidence = deep.get('rhythmEvidence')
        if not evidence:
            continue
        if (evidence['version'] != 1 or len(evidence['features']) != 6
                or not np.isfinite(evidence['features']).all()):
            raise ValueError('Unsupported reliability evidence.')
        duration = deep['audio']['frameCount'] / deep['audio']['sampleRate']
        if not 20 <= duration <= 35:
            continue
        if (not row.get('reviewTimeline') or row['finalAnalysis'].get('adaptiveCandidate')
                != deep['adaptiveCandidate']['map']):
            raise ValueError('The scored review must use the measured deep candidate.')
        success = int(all(scored[row['id']]['tiers']['review'][field]['f1'] >= .95
                          for field in ('beats', 'downbeats')))
        rows.append({'id': row['id'], 'features': evidence['features'], 'success': success})
    return rows


def fit(x, y):
    mean = x.mean(axis=0)
    scale = np.maximum(x.std(axis=0), 1e-6)
    design = np.column_stack([np.ones(len(x)), (x - mean) / scale])

    def objective(w):
        z = design @ w
        loss = np.logaddexp(0, z).sum() - y @ z + .5 * (w[1:] @ w[1:])
        gradient = design.T @ (expit(z) - y) + np.r_[0, w[1:]]
        return loss, gradient

    result = minimize(objective, np.zeros(7), jac=True, method='L-BFGS-B')
    if not result.success:
        raise ValueError('The confidence fit did not converge: ' + result.message)
    return {'mean': mean.tolist(), 'scale': scale.tolist(),
            'intercept': float(result.x[0]), 'coefficients': result.x[1:].tolist()}


def predict(model, x):
    return expit(model['intercept'] + ((x - model['mean']) / model['scale']) @ model['coefficients'])


def train(report_root):
    rows, sources = [], []
    for name, filename, split in COHORTS:
        reference = ROOT / 'docs/testing' / filename
        report_path = report_root / ('rhythm-' + name) / 'report.json'
        benchmark = json.loads(reference.read_text())
        report = json.loads(report_path.read_text())
        expected = {t['id'] for t in benchmark['tracks'] if t['split'] == split}
        if {t['id'] for t in report['rows']} != expected:
            raise ValueError('Training input must match the complete prior cohort: ' + name)
        for row in rows_for(benchmark, report):
            rows.append(dict(row, cohort=name))
        sources.append({'cohort': name, 'benchmark': filename, 'benchmarkSHA256': sha(reference),
                        'reportSHA256': sha(report_path), 'runID': report['runID']})
    x = np.array([r['features'] for r in rows])
    y = np.array([r['success'] for r in rows])
    group = np.array([r['cohort'] for r in rows])
    probabilities, baseline = np.zeros(len(y)), np.zeros(len(y))
    folds = []
    for cohort in sorted(set(group)):
        training = group != cohort
        test = ~training
        probabilities[test] = predict(fit(x[training], y[training]), x[test])
        for strong in (0, 1):
            a, b = training & (x[:, -1] == strong), test & (x[:, -1] == strong)
            baseline[b] = (y[a].sum() + 1) / (a.sum() + 2)
        folds.append({'leftOut': cohort, 'brier': float(np.mean((probabilities[test] - y[test]) ** 2)),
                      'refittedTwoBinBrier': float(np.mean((baseline[test] - y[test]) ** 2))})
    model = fit(x, y)
    return {'format': 'generik.rhythm-calibration/v1', 'version': 2, 'evidenceVersion': 1,
            'features': FEATURES, 'durationSeconds': [20, 35], 'ridgePenalty': 1,
            'target': 'Beat and downbeat event F1 both at least 0.95 within 25 ms.',
            'sources': sources, 'observations': len(y), 'successes': int(y.sum()),
            'model': model, 'folds': folds,
            'crossValidatedBrier': float(np.mean((probabilities - y) ** 2)),
            'refittedTwoBinCrossValidatedBrier': float(np.mean((baseline - y) ** 2)),
            'golden': {'features': rows[0]['features'], 'probability': float(predict(model, x[:1])[0])},
            'rows': rows,
            'scope': 'The prior 300 excerpts are development data. Fresh R124 validation is excluded.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = train(args.report_root)
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('rows', 'sources')}, indent=2))
