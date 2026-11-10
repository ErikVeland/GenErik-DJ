#!/usr/bin/env python3
"""Build frozen reference cohorts from checksum-verified research downloads."""
import argparse
import collections
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from verified_analysis_benchmark import require, sha256, validate


SEED = 'generik-r116-v1'


def digest_text(text):
    return hashlib.sha256(text.encode()).hexdigest()


def normalise(text):
    return re.sub(r'[^a-z0-9]+', ' ', text.lower()).strip()


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def check_md5(path, expected):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'md5').hexdigest() == expected


def split_groups(tracks):
    parents = {}

    def root(group):
        parents.setdefault(group, group)
        if parents[group] != group:
            parents[group] = root(parents[group])
        return parents[group]

    for track in tracks:
        groups = track['groups'] + ['audio:' + track['sha256']]
        for group in groups[1:]:
            a, b = root(groups[0]), root(group)
            parents[max(a, b)] = min(a, b)
    for track in tracks:
        group = root(track['groups'][0])
        track['split'] = 'holdout' if int(digest_text(SEED + group)[:8], 16) % 3 == 0 else 'development'


def balanced_cohort(tracks, size):
    buckets = collections.defaultdict(list)
    for track in tracks:
        buckets[track['genre']].append(track)
    for values in buckets.values():
        values.sort(key=lambda t: digest_text(SEED + t['id']))
    selected = []
    while buckets and len(selected) < size:
        for genre in sorted(list(buckets)):
            selected.append(buckets[genre].pop(0))
            if not buckets[genre]:
                del buckets[genre]
            if len(selected) == size:
                break
    return selected


def gtzan(research, audio_root):
    index_path = research / 'gtzan-index.json'
    require(check_md5(index_path, '533ca050855f22acf2feb283d9957fe3'), 'GTZAN source index changed.')
    index = json.loads(index_path.read_text())['tracks']
    group_root = research / 'gtzan-groups'
    require(revision(group_root) == 'fedc781026cf1a20034830f8071c98d93a422016', 'GTZAN group revision changed.')
    annotation_root = research / 'beat-this-annotations'
    require(revision(annotation_root) == 'fd9fcc0896cb78730bae735102c8753ef3a3badd', 'Beat annotation revision changed.')
    files = {p.stem: p for p in audio_root.rglob('*.wav')}
    identities = {}
    for line in (group_root / 'index.txt').read_text().splitlines():
        if ':::' in line and not line.startswith('#'):
            file, artist, title = (part.strip() for part in line.split(':::', 2))
            identities[Path(file).stem] = (artist, title)
    allowed = set()
    for partition in ('train', 'valid', 'test'):
        allowed.update(Path(p).stem for p in (group_root / (partition + '_filtered.txt')).read_text().splitlines())
    tracks, excluded = [], []
    for identity, record in sorted(index.items()):
        reason = None
        audio = files.get(identity)
        artist, title = identities.get(identity, ('', ''))
        annotation = annotation_root / 'gtzan/annotations/beats' / ('gtzan_' + identity.replace('.', '_') + '.beats')
        if identity not in allowed:
            reason = 'Excluded by the published fault-filtered partitions.'
        elif not artist.strip() or normalise(artist) in ('unknown', 'unk', 'na') or artist.strip() == '?':
            reason = 'Artist identity is unknown.'
        elif audio is None or not check_md5(audio, record['audio'][1]):
            reason = 'Audio is absent or its source checksum differs.'
        elif not annotation.exists():
            reason = 'No pinned beat annotation.'
        if reason:
            excluded.append({'id': identity, 'reason': reason})
            continue
        events = [line.split() for line in annotation.read_text().splitlines() if line.strip()]
        if not events:
            excluded.append({'id': identity, 'reason': 'No annotated beats.'})
            continue
        beats = [float(row[0]) for row in events]
        bars = [float(row[0]) for row in events if len(row) > 1 and row[1] == '1']
        label = {'source': 'gtzan-beats', 'annotationSHA256': sha256(annotation), 'times': beats}
        labels = {'beats': label}
        if bars:
            labels['downbeats'] = dict(label, times=bars)
        groups = ['gtzan:artist:' + normalise(a) for a in artist.split(';')]
        if title.strip():
            groups.append('gtzan:recording:' + normalise(artist + ' ' + title))
        tracks.append({'id': 'gtzan:' + identity, 'path': str(audio.resolve()), 'sha256': sha256(audio),
                       'sourceMD5': record['audio'][1], 'dataset': 'gtzan', 'artist': artist, 'title': title,
                       'genre': identity.split('.')[0], 'groups': groups, 'labels': labels})
    source = {'url': 'https://github.com/CPJKU/beat_this_annotations/tree/fd9fcc0896cb78730bae735102c8753ef3a3badd/gtzan',
              'revision': revision(annotation_root), 'sha256': digest_text('\n'.join(
                  str(p.relative_to(annotation_root)) + ':' + sha256(p)
                  for p in sorted((annotation_root / 'gtzan/annotations/beats').glob('*.beats')))),
              'origin': 'published-human', 'audioIndexSHA256': sha256(index_path),
              'groupIndexSHA256': sha256(group_root / 'index.txt'),
              'groupRevision': revision(group_root),
              'trainingOverlap': {'beat-this-small0': 'GTZAN excluded according to the model authors.',
                                  'beat-this-final0': 'GTZAN excluded according to the model authors.'}}
    return tracks, excluded, {'gtzan-beats': source}


def standard_key(text):
    match = re.fullmatch(r'([A-G])([b#]?) (major|minor)(?: (ionian|aeolian|harmonic|melodic))?', text.strip())
    if not match:
        return None
    note, accidental, mode, variant = match.groups()
    if variant and ((mode == 'major' and variant != 'ionian') or (mode == 'minor' and variant == 'ionian')):
        return None
    tonic = ({'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[note]
             + {'': 0, 'b': -1, '#': 1}[accidental]) % 12
    return {'tonic': tonic, 'mode': mode}


def key_annotation_rows(path):
    ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with zipfile.ZipFile(path) as archive:
        strings = [''.join(x.itertext()) for x in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', ns)]
        rows = []
        for row in ET.fromstring(archive.read('xl/worksheets/sheet1.xml')).findall('s:sheetData/s:row', ns):
            values = {}
            for cell in row.findall('s:c', ns):
                value = cell.find('s:v', ns)
                if value is not None:
                    column = re.sub('[0-9]', '', cell.attrib['r'])
                    values[column] = strings[int(value.text)] if cell.attrib.get('t') == 's' else value.text
            rows.append(values)
    return {row['A']: row for row in rows[1:]}


def giantsteps(research, audio_root):
    expected = {'giantsteps-index.json': 'abce33ea617809a0d534299b00412024',
                'keys.zip': '775b7d17e009f5818544cf505b6a96fd',
                'metadata.zip': '54181e0f34c35d9720439750d0b08091',
                'GiantSteps-plus.xlsx': '79ac74fe9d192514da1ffd686226c77b'}
    for name, checksum in expected.items():
        require(check_md5(research / name, checksum), 'GiantSteps source changed: ' + name)
    index = json.loads((research / 'giantsteps-index.json').read_text())['tracks']
    detailed = key_annotation_rows(research / 'GiantSteps-plus.xlsx')
    tracks, excluded = [], []
    with zipfile.ZipFile(research / 'keys.zip') as labels, zipfile.ZipFile(research / 'metadata.zip') as metadata:
        for record in index.values():
            if not all(record[field][0] for field in ('audio', 'key', 'meta')):
                excluded.append({'id': str(record['audio'][0]), 'reason': 'Published audio, key or artist metadata is absent.'})
                continue
            raw_label = labels.read(record['key'][0])
            raw_metadata = metadata.read(record['meta'][0])
            require(hashlib.md5(raw_label).hexdigest() == record['key'][1], 'Key annotation checksum differs.')
            require(hashlib.md5(raw_metadata).hexdigest() == record['meta'][1], 'Key metadata checksum differs.')
            meta = json.loads(raw_metadata)
            identity = str(meta['id'])
            detail = detailed[identity]
            label = standard_key(raw_label.decode())
            reason = None
            if label is None:
                reason = 'Modal, ambiguous or multiple-key annotation.'
            elif detail.get('I') != '2':
                reason = 'No revised high-confidence annotation.'
            elif detail.get('N') or detail.get('M'):
                reason = 'An annotated key change occurs in the excerpt.'
            elif not meta.get('artists'):
                reason = 'Artist identity is unknown.'
            if reason:
                excluded.append({'id': identity, 'rawLabel': raw_label.decode().strip(), 'reason': reason})
                continue
            audio = audio_root / record['audio'][0]
            require(audio.exists() and check_md5(audio, record['audio'][1]), 'Verified key audio is required: ' + identity)
            groups = ['giantsteps:artist:' + str(a['id']) for a in meta['artists'] + meta.get('remixers', [])]
            groups.append('giantsteps:recording:' + normalise(detail.get('C', '') + ' ' + detail.get('D', '')))
            label.update(source='giantsteps-key', annotationSHA256=hashlib.sha256(raw_label).hexdigest(),
                         rawLabel=raw_label.decode().strip(), confidence=2)
            tracks.append({'id': 'giantsteps:' + identity, 'path': str(audio.resolve()), 'sha256': sha256(audio),
                           'sourceMD5': record['audio'][1], 'dataset': 'giantsteps-plus',
                           'artist': detail.get('C', ''), 'title': detail.get('D', ''),
                           'genre': detail.get('G', 'unknown'), 'groups': groups, 'labels': {'key': label}})
    source = {'url': 'https://zenodo.org/records/1095691', 'revision': 'GiantSteps+ / 1095691',
              'sha256': sha256(research / 'keys.zip'), 'origin': 'published-human',
              'detailSHA256': sha256(research / 'GiantSteps-plus.xlsx'),
              'audioIndexSHA256': sha256(research / 'giantsteps-index.json'),
              'trainingOverlap': {'madmom-key-cnn-2018': 'Authors report GiantSteps Key as test data, distinct from GiantSteps MTG training data. Artist overlap is not established.'}}
    return tracks, excluded, {'giantsteps-key': source}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='Local acquisition folder with research and corpus directories.')
    parser.add_argument('output', type=Path)
    parser.add_argument('--per-split', type=int, default=100)
    parser.add_argument('--dataset', choices=['gtzan', 'giantsteps'], default='gtzan')
    args = parser.parse_args()
    require(not args.output.exists(), 'Choose a new output file. Existing evidence was retained.')
    builder = gtzan if args.dataset == 'gtzan' else giantsteps
    tracks, excluded, sources = builder(args.root / 'research', args.root / 'corpus' / args.dataset)
    split_groups(tracks)
    selected = []
    for split in ('development', 'holdout'):
        selected.extend(balanced_cohort([t for t in tracks if t['split'] == split], args.per_split))
    data = {'format': 'generik.verified-analysis/v1', 'version': 'r116-' + args.dataset + '-1', 'selectionSeed': SEED,
            'selection': 'Eligible sources. Artist components split before genre-balanced hash selection.',
            'eligibleTracks': len(tracks), 'sources': sources, 'tracks': selected, 'exclusions': excluded}
    validate(data, verify_audio=True)
    args.output.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')
    print(json.dumps({'tracks': len(selected), 'eligible': len(tracks), 'excluded': len(excluded),
                      'counts': dict(collections.Counter(t['split'] + ':' + t['genre'] for t in selected))}, indent=2))


if __name__ == '__main__':
    main()
