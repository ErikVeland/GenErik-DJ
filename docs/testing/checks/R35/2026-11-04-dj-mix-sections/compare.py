from pathlib import Path
import hashlib
import json
import subprocess
import sys

root=Path(__file__).resolve().parents[5]
sys.path.insert(0,str(root/'tools/analysis_review'))
import review
work=root/'TestBuilds/ipad/R35/review-2026-11-04/compare'
work.mkdir(parents=True,exist_ok=True)
sources=review.compile_probe(work)
s=(work/'main.swift').read_text().replace('let arrangement=TrackArrangement.prepare(analysis:analysis,features:features,context:context)',
    'let baseline=TrackArrangement.prepare(analysis:analysis,features:features)\nlet arrangement=TrackArrangement.prepare(analysis:analysis,features:features,context:context)')
s=s.replace('["analysis":values,"arrangement":','["baseline":try JSONSerialization.jsonObject(with:JSONEncoder().encode(baseline)),"analysis":values,"arrangement":')
(work/'main.swift').write_text(s)
core=root/'Replica/Sources/TDJCore'
files=[work/'Values.swift',work/'BeatGridMap.swift',work/'main.swift']+[core/name for name in ['AudioAnalyzer.swift','MusicalSpectrumAnalyzer.swift','MusicalAnalysisFeatures.swift','AdaptiveRhythmAnalyzer.swift','BeatGrid.swift','TrackArrangement.swift','MusicalStructureAnalyzer.swift']]
subprocess.run(['xcrun','swiftc','-O',*map(str,files),'-o',str(work/'probe')],check=True)
manifest=json.loads((work.parent/'selection.json').read_text())
rows=[]
for t in manifest['tracks']:
    output=work/(t['id']+'.json');context=work/'context.json'
    context.write_text(json.dumps({'title':t['title'],'genre':t.get('genre')}))
    run=subprocess.run([str(work/'probe'),t['path'],str(output),str(work/'current.pcm'),str(context)],capture_output=True,text=True,timeout=90)
    row={k:t[k] for k in ['id','title','artist','genre','split']}
    if run.returncode:
        row.update(state='failed',error=run.stderr)
    else:
        d=json.loads(output.read_text());rate=d['analysis']['sampleRate']
        row.update(state='compared',sourceSHA256=d['analysis']['contentSHA256'],
                   oldSections=len(d['baseline']['sections']),newSections=len(d['arrangement']['sections']))
        for key,source in [('baseline','baseline'),('candidate','arrangement')]:
            row[key]=[{**{k:s[k] for k in ['role','name','behaviour']},'startSeconds':s['start']/rate,'endSeconds':s['end']/rate} for s in d[source]['sections']]
        assert d['analysis']['contentSHA256']==hashlib.sha256(Path(t['path']).read_bytes()).hexdigest()
    rows.append(row)
    print(t['title'],row.get('oldSections'),row.get('newSections'),[(s['role'],round(s['startSeconds'],2),round(s['endSeconds'],2)) for s in row.get('candidate',[]) if s['name'].startswith('Rhythmic')],flush=True)
    (Path(__file__).parent/'comparison.json').write_text(json.dumps({'requestID':'R35','sourceHashes':sources,'rows':rows,'interpretation':'Default-context and genre/version-context outputs use identical decoded audio and feature extraction. This is a focused feature review, not independent semantic ground truth or a blind held-out evaluation.'},indent=2)+'\n')
