#!/usr/bin/env python3
"""Describe copied Traktor exports without exposing track names in the report."""
import argparse
import collections
import json
import wave
import xml.etree.ElementTree as ET
from pathlib import Path


def analyze(folder, acquisition):
    attributes = collections.defaultdict(set)
    resource_types = collections.Counter()
    guid_lengths = collections.Counter()
    track_counts = []
    start_times = []
    roots = []
    for path in sorted(folder.glob('*.xml')):
        root = ET.parse(path).getroot()
        roots.append({'tag': root.tag, 'attributes': root.attrib})
        tracks = root.findall('.//track')
        track_counts.append(len(tracks))
        for element in root.iter():
            attributes[element.tag].update(element.attrib)
        for track in tracks:
            resource_types[track.get('restype')] += 1
            guid_lengths[len(track.get('guid', ''))] += 1
            start_times.append(track.get('starttime', ''))
    audio_formats = collections.Counter()
    for item in acquisition['files']:
        if not item['name'].endswith('.wav') or item['status'] != 'copied_size_verified':
            continue
        with wave.open(str(folder / item['name'])) as audio:
            audio_formats[(audio.getnchannels(), audio.getframerate(),
                           audio.getsampwidth(), audio.getcomptype())] += 1
    unique_roots = {json.dumps(root, sort_keys=True) for root in roots}
    return {
        'evidence': 'Copied USB shared documents. No executable analysis.',
        'xml_files': len(roots),
        'root_variants': [json.loads(root) for root in sorted(unique_roots)],
        'attributes_by_tag': {tag: sorted(values) for tag, values in attributes.items()},
        'track_entries': sum(track_counts),
        'track_entries_per_export': {'min': min(track_counts, default=0),
                                     'max': max(track_counts, default=0)},
        'resource_type_counts': dict(resource_types),
        'guid_string_length_counts': dict(guid_lengths),
        'starttime_values_all_nonnegative_integers': all(s.isdecimal() for s in start_times),
        'verified_wav_format_counts': [
            {'channels': key[0], 'sample_rate': key[1], 'bytes_per_sample': key[2],
             'compression': key[3], 'files': count}
            for key, count in sorted(audio_formats.items())],
        'limits': 'Recording exports do not establish private library, cue point, '
                  'beat grid, or audio engine formats. Timestamp units and GUID semantics '
                  'remain unverified.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('acquisition', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(args.folder, json.loads(args.acquisition.read_text())), indent=2))
