#!/usr/bin/env python3
"""Build frozen reference cohorts from checksum-verified research downloads."""
import argparse
import collections
import hashlib
import json
import re
import subprocess
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='Local acquisition folder with research and corpus directories.')
    parser.add_argument('output', type=Path)
    parser.add_argument('--per-split', type=int, default=100)
    args = parser.parse_args()
    require(not args.output.exists(), 'Choose a new output file. Existing evidence was retained.')
    tracks, excluded, sources = gtzan(args.root / 'research', args.root / 'corpus/gtzan')
    split_groups(tracks)
    selected = []
    for split in ('development', 'holdout'):
        selected.extend(balanced_cohort([t for t in tracks if t['split'] == split], args.per_split))
    data = {'format': 'generik.verified-analysis/v1', 'version': 'r116-gtzan-1', 'selectionSeed': SEED,
            'selection': 'Fault-filtered sources. Artist components split before genre-balanced hash selection.',
            'eligibleTracks': len(tracks), 'sources': sources, 'tracks': selected, 'exclusions': excluded}
    validate(data, verify_audio=True)
    args.output.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')
    print(json.dumps({'tracks': len(selected), 'eligible': len(tracks), 'excluded': len(excluded),
                      'counts': dict(collections.Counter(t['split'] + ':' + t['genre'] for t in selected))}, indent=2))


if __name__ == '__main__':
    main()
