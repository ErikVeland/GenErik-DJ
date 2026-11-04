#!/usr/bin/env python3
"""Select an even music review set and capture source-bound engine predictions."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import unicodedata

ROOT = Path(__file__).resolve().parents[2]

def normal(text):
    return re.sub(r'[^a-z0-9]+', '', unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode().lower())

def hints(track):
    genre=(track.get('genre') or '').lower()
    rules=[('mashup',r'mash.?up'),('drum-bass-breaks',r'drum.?n?.?bass|drum.and.bass|jungle|breakbeat|breaks'),
           ('house-disco',r'house|disco'),('techno-trance',r'techno|trance'),('hiphop-rnb-soul',r'hip.?hop|\brap\b|r.?&.?b|rnb|soul'),
           ('reggae-latin-afro',r'reggae|ragga|dancehall|latin|salsa|afro|reggaeton|moombahton'),
           ('ambient-downtempo',r'ambient|downtempo|chill|trip.?hop'),('pop-rock',r'pop|rock|indie|alternative|punk'),
           ('electronic-other',r'electro|dance|garage|dubstep|idm')]
    family=next((name for name,pattern in rules if re.search(pattern,genre)), 'unclassified')
    title=track['title'].lower()
    context=' '.join(re.findall(r'[\[(]([^\])]+)',title)+re.split(r'\s-\s',title)[1:])
    versions=[]
    for name,pattern in [('12-inch',r'12(?:[\s-]*(?:["”″\']|inch)|_\s*(?:mix|version|scratch))'),('dub',r'\bdub\b'),('extended',r'\bextended\b'),
                         ('radio-edit',r'\bradio\b|\bsingle edit\b'),('acappella',r'\ba\s?cap+p?ella\b'),('instrumental',r'\binstrumental\b'),
                         ('live',r'\blive\b'),('club',r'\bclub\b'),('remix',r'\bremix\b'),('mashup',r'\bmash.?up\b')]:
        explicit=re.search(pattern,context)
        if name in ['12-inch','extended','acappella','instrumental','remix','mashup']:
            explicit=explicit or re.search(pattern,title)
        if name=='radio-edit': explicit=explicit or re.search(r'\bradio (?:edit|mix|version)\b',title)
        if explicit: versions.append(name)
    if family=='mashup' and 'mashup' not in versions: versions.append('mashup')
    return family, versions or ['unspecified']

def song_family(track):
    # Group title variants across artists, including covers and mashups, to reduce test leakage.
    title=re.split(r'[\[(]|\s-\s',track['title'])[0]
    title=re.sub(r'\b(?:extended|radio|remix|instrumental|acappella|club mix|dub mix)\b.*','',title,flags=re.I)
    return hashlib.sha256(normal(title).encode()).hexdigest()[:16]

def select(tracks, count):
    groups=collections.defaultdict(lambda:collections.defaultdict(list))
    for source in tracks:
        track=dict(source)
        family,versions=hints(track)
        track.update(genreFamilyHint=family,versionHints=versions,songFamily=song_family(track))
        track['split']='held-out' if int(track['songFamily'],16)%5==0 else 'development'
        track['referenceStatus']='unverified-source-match' if track.get('reference') else 'unlabelled'
        groups[family][versions[0]].append(track)
    for versions in groups.values():
        for rows in versions.values(): rows.sort(key=lambda t:hashlib.sha256(t['id'].encode()).hexdigest())
    selected=[]; offsets=collections.Counter()
    while len(selected)<count:
        progress=False
        for family,versions in sorted(groups.items()):
            available=sorted(v for v,rows in versions.items() if rows)
            if not available: continue
            version=available[offsets[family]%len(available)]; offsets[family]+=1
            selected.append(versions[version].pop()); progress=True
            if len(selected)==count: break
        if not progress: break
    return selected

def compile_probe(work):
    core=ROOT/'Replica/Sources/TDJCore'
    (work/'Values.swift').write_text((core/'Models.swift').read_text().split('public struct Preparation:')[0])
    (work/'BeatGridMap.swift').write_text((core/'BeatGridMap.swift').read_text().split('extension BeatTiming {')[0])
    (work/'main.swift').write_text((Path(__file__).parent/'CorpusProbe.swift').read_text())
    sources=[work/'Values.swift',work/'BeatGridMap.swift',work/'main.swift']
    sources += [core/name for name in ['AudioAnalyzer.swift','MusicalSpectrumAnalyzer.swift','MusicalAnalysisFeatures.swift',
                'AdaptiveRhythmAnalyzer.swift','BeatGrid.swift','TrackArrangement.swift','MusicalStructureAnalyzer.swift','VocalFormAnalyzer.swift']]
    subprocess.run(['xcrun','swiftc','-O',*map(str,sources),'-o',str(work/'probe')],check=True)
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources if p.is_relative_to(ROOT)}

def audit(track, result):
    analysis=result['analysis']; sections=result['arrangement']['sections']; rate=analysis['sampleRate']
    duration=analysis['frameCount']/rate
    flags=[]
    if abs(duration-track['durationSeconds'])>2: flags.append('source-duration-mismatch')
    if sum(s['end']-s['start'] for s in sections if s['role']=='chorus')/analysis['frameCount']>0.6:
        flags.append('review-high-chorus-coverage')
    if len(sections)/(duration/60)>4: flags.append('review-many-short-sections')
    if result['vocalSeconds']>8 and not any(s['role'] in ['verse','chorus','hook','preChorus','bridge'] for s in sections):
        flags.append('vocal-form-unassigned')
    if analysis.get('bpm') is None: flags.append('tempo-unresolved')
    if analysis.get('key') is None: flags.append('key-unresolved')
    reference=track.get('reference') or {}; grid=reference.get('grid') or {}
    if analysis.get('bpm') and grid.get('bpm'):
        ratio=analysis['bpm']/grid['bpm']
        if abs(ratio-1)>0.01:
            flags.append('review-tempo-vs-unverified-reference')
            if min(abs(ratio-0.5),abs(ratio-2))<0.02: flags.append('review-half-double-tempo')
    if reference.get('key') and analysis.get('key') and reference['key']!=analysis['key']:
        flags.append('review-key-vs-unverified-reference')
    return flags

def run(manifest, work):
    work.mkdir(parents=True,exist_ok=True)
    hashes=compile_probe(work)
    rows=[]
    for index,track in enumerate(manifest['tracks']):
        output=work/(track['id']+'.json'); pcm=work/'current.pcm'; started=time.monotonic()
        row=dict(track)
        try:
            source=Path(track['path'])
            before=source.stat()
            with source.open('rb') as stream: row['inputSHA256']=hashlib.file_digest(stream,'sha256').hexdigest()
            context=work/'current-context.json'
            context.write_text(json.dumps({'title':track['title'],'genre':track.get('genre')}))
            completed=subprocess.run([str(work/'probe'),str(source),str(output),str(pcm),str(context)],capture_output=True,text=True,timeout=90)
            if completed.returncode:
                raise RuntimeError(completed.stderr[-2000:] or f'Probe exited {completed.returncode}')
            result=json.loads(output.read_text())
            after=source.stat()
            if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns):
                raise RuntimeError('Source changed during review analysis.')
            row.update(state='analysed',prediction=result,reviewFlags=audit(track,result))
        except (OSError,RuntimeError,subprocess.TimeoutExpired,json.JSONDecodeError) as error:
            row.update(state='failed',error=str(error),reviewFlags=['analysis-failed'])
        finally:
            pcm.unlink(missing_ok=True)
        row.update(elapsedSeconds=round(time.monotonic()-started,3),reviewStatus='unreviewed')
        rows.append(row)
        report={'format':'generik.analysis-review/v1','sourceCommit':subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),
                'sourceHashes':hashes,'preprocessing':'Production AVAudioFile decode and analysis on each original local audio file. The helper writes a temporary stereo cache for structure analysis. This does not exercise the iPad library importer.',
                'groundTruthStatus':'No section annotations. Reference comparisons remain unscored until source identity and labels are confirmed.',
                'tracks':rows}
        (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(f'{index+1}/{len(manifest["tracks"])} {track["genreFamilyHint"]} {track["versionHints"]}: {track["artist"]} — {track["title"]}: {row["state"]}',flush=True)
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='action',required=True)
    pick=sub.add_parser('select');pick.add_argument('candidates',type=Path);pick.add_argument('output',type=Path);pick.add_argument('--count',type=int,default=96)
    analyse=sub.add_parser('run');analyse.add_argument('manifest',type=Path);analyse.add_argument('work',type=Path)
    args=parser.parse_args()
    if args.action=='select':
        rows=select(json.loads(args.candidates.read_text()),args.count)
        args.output.write_text(json.dumps({'format':'generik.analysis-review-manifest/v1','selection':'Even genre-family sampling, rotating version types within each family. Metadata hints require audio review.','tracks':rows},indent=2)+'\n')
        print(json.dumps({'selected':len(rows),'genres':dict(collections.Counter(t['genreFamilyHint'] for t in rows)),
              'versions':dict(collections.Counter(v for t in rows for v in t['versionHints'])),'splits':dict(collections.Counter(t['split'] for t in rows))},indent=2))
    else: run(json.loads(args.manifest.read_text()),args.work)

if __name__=='__main__': main()
