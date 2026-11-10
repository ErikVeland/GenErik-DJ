"""Bind a device inventory to candidate Mac files. The app verifies decoded audio hashes."""
import argparse
import collections
import json
import pathlib
import unicodedata
import urllib.parse


def normalise(text):
    text = unicodedata.normalize('NFKD', text.casefold().replace('ø', 'o'))
    return ''.join(c for c in text if not unicodedata.combining(c)).strip()


def mac_items(mac):
    if not isinstance(mac, dict):
        return mac
    return [dict(persistentID=item['source']['persistentID'], title=item['title'], artist=item['artist'],
                 album=item['album'], duration=item['duration'],
                 path=urllib.parse.unquote(urllib.parse.urlparse(item.get('assetURL', '')).path),
                 protected=item['availability'] == 'protected') for item in mac['items']]


def prepare(device, library, mac):
    local = mac_items(mac)
    by_title = collections.defaultdict(list)
    for item in local:
        path = item.get('path') or urllib.parse.unquote(urllib.parse.urlparse(item.get('assetURL', '')).path)
        protected = item.get('protected') or item.get('availability', 'available') != 'available'
        if path and not protected and pathlib.Path(path).is_file():
            by_title[normalise(item['title'])].append((item, path))
    by_source = collections.defaultdict(list)
    for track in library['tracks']:
        for source in track.get('musicLibrarySources', []):
            if source['platform'] == 'iosMusic':
                by_source[source['persistentID']].append(track)
    items = []
    for item in device['items']:
        if item['availability'] != 'available':
            continue
        identifier = item['source']['persistentID']
        tracks = by_source[identifier]
        if len(tracks) > 1:
            raise ValueError(f'Duplicate device source: {identifier}')
        candidates = [(m, p) for m, p in by_title[normalise(item['title'])]
                      if abs(m['duration'] - item['duration']) < 1]
        exact = [(m, p) for m, p in candidates if
                 normalise(m['artist']) == normalise(item['artist']) and
                 normalise(m['album']) == normalise(item['album'])]
        paths = sorted({p for _, p in exact or candidates})
        items.append(dict(id=identifier, title=item['title'], artist=item['artist'],
                          paths=paths, expected=tracks[0] if tracks else None))
    items.sort(key=lambda x: (x['expected']['analysis']['frameCount'] / x['expected']['analysis']['sampleRate']
                             if x['expected'] else 0, x['id']))
    if len({x['id'] for x in items}) != len(items):
        raise ValueError('The device inventory contains duplicate identifiers.')
    return dict(items=items)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['device_catalog', 'device_library', 'mac_catalog', 'output']:
        parser.add_argument(name, type=pathlib.Path)
    args = parser.parse_args()
    manifest = prepare(*(json.loads(p.read_text()) for p in
                         [args.device_catalog, args.device_library, args.mac_catalog]))
    with args.output.open('x') as file:
        json.dump(manifest, file, sort_keys=True)
    print(json.dumps(dict(tracks=len(manifest['items']),
                          missingCandidates=sum(not x['paths'] for x in manifest['items']),
                          knownIdentities=sum(x['expected'] is not None for x in manifest['items']))))
