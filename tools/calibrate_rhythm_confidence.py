#!/usr/bin/env python3
"""Record development calibration and evaluate fixed rhythm reliability estimates."""
import argparse,json,math
from pathlib import Path
from verified_analysis_benchmark import require,score_report,sha256


def strong(row):
    c=row['deep'].get('candidate') or {}
    return c.get('beatAgreement',0)>=.9 and c.get('barAgreement',0)>=.8 and c.get('residualMilliseconds',math.inf)<=20


def interval(successes,count):
    z=1.96;rate=successes/count;den=1+z*z/count
    center=(rate+z*z/(2*count))/den
    width=z*math.sqrt(rate*(1-rate)/count+z*z/(4*count*count))/den
    return [center-width,center+width]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('operation',choices=['fit','evaluate']);p.add_argument('benchmark',type=Path);p.add_argument('report',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    require(not a.output.exists(),'Choose a new results file.')
    benchmark=json.loads(a.benchmark.read_text());report=json.loads(a.report.read_text());scores=score_report(benchmark,report);by_id={r['id']:r for r in scores['tracks']}
    require(scores['failures']==0,'Complete all rows before calibration.')
    if a.operation=='fit':require(scores['split']=='development','Calibration only accepts development data.')
    rows=[]
    for r in report['rows']:
        d=r.get('deep') or {};audio=d.get('audio') or {}
        if not d.get('adaptiveCandidate') or not 20<=audio['frameCount']/audio['sampleRate']<=35:continue
        truth=by_id[r['id']]['tiers']['review'];success=all(truth[f]['f1']>=.95 for f in ['beats','downbeats'])
        expected=27/45 if strong(r) else 1/11
        measured=(r.get('finalAnalysis') or {}).get('adaptiveConfidence')
        if a.operation=='evaluate':require(measured is not None and abs(measured-expected)<1e-12,'The app confidence differs from the frozen calibration.')
        rows.append({'id':r['id'],'bin':'strong-constant-fit' if strong(r) else 'weak-or-missing-constant-fit','success':success,'probability':expected,'modelBarConsistency':d['adaptiveCandidate']['barConsistency']})
    bins={}
    for name in ['strong-constant-fit','weak-or-missing-constant-fit']:
        values=[r for r in rows if r['bin']==name];n=len(values);k=sum(r['success'] for r in values)
        bins[name]={'observations':n,'successes':k,'observedRate':k/n if n else None,'wilson95':interval(k,n) if n else None,'smoothedDevelopmentEstimate':(k+1)/(n+2) if a.operation=='fit' else None}
    result={'format':'generik.rhythm-confidence/v1','operation':a.operation,'split':scores['split'],'sourceReportSHA256':sha256(a.report),'benchmarkSHA256':sha256(a.benchmark),'runID':report['runID'],'profile':report['deepProfile'],'target':'Both beat and downbeat F1 at least 0.95 within 25 ms, over annotated spans.','domain':'20–35 second excerpts with a valid four-beat adaptive proposal.','bins':bins,'rows':rows}
    if rows:result['brierScore']={name:sum((r[field]-r['success'])**2 for r in rows)/len(rows) for name,field in [('calibrated','probability'),('modelConsistency','modelBarConsistency')]}
    if a.operation=='fit':
        require(bins['strong-constant-fit']['observations']==43 and bins['strong-constant-fit']['successes']==26,'Development calibration differs.')
        require(bins['weak-or-missing-constant-fit']['observations']==9 and bins['weak-or-missing-constant-fit']['successes']==0,'Development calibration differs.')
    a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['rows','profile']},indent=2))


if __name__=='__main__':main()
