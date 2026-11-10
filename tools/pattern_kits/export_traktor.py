#!/usr/bin/env python3
"""Export Pattern Player kits from a local Traktor Pro 4 macOS app."""
import argparse
import base64
from collections import defaultdict
import json
import math
import mmap
from pathlib import Path
import re
import struct
import subprocess
from tempfile import TemporaryDirectory

SYMBOL = re.compile(r'^(\w+) \((__TEXT|__DATA_CONST),__const\).* (\S+)$')
KIT_SYMBOL = re.compile(r'^__ZN3kit(\d+)([a-z0-9_]+?)(6sample|7pattern)L(\d+)([a-z0-9_]+)E$')
ALIASES = {
    'camea_raw_techno': {'pulse': 'spulserubbs', 'rubb': 'spulserubbs'},
    'dubfire_evolv': {'chat': 'schhs', 'kick2': 'skicks', 'tom2': 'stoms', 'ohat': 'sohhs'},
    'riemann_industrial': {'tom': 'basss'},
}
SOUND_NAMES = {'chh': 'Closed Hat', 'ohh': 'Open Hat', 'ch': 'Closed Hat', 'oh': 'Open Hat'}


def segments(data):
    if data[:8] != b'\xcf\xfa\xed\xfe\x0c\x00\x00\x01':
        raise ValueError('Select the Apple Silicon version of Traktor Pro 4.')
    offset = 32
    result = {}
    commands = struct.unpack_from('<I', data, 16)[0]
    if commands > 256:
        raise ValueError('The Traktor executable has an unsupported layout.')
    for _ in range(commands):
        command, size = struct.unpack_from('<II', data, offset)
        if size < 8 or offset + size > len(data):
            raise ValueError('The Traktor executable has an invalid load command.')
        if command == 0x19:
            name, address, _, start, length = struct.unpack_from('<16sQQQQ', data, offset + 8)
            result[name.rstrip(b'\0').decode('ascii')] = (address, start, length)
        offset += size
    return result


def read_kits(data, symbol_text, wanted):
    layout = segments(data)
    if not {'__TEXT', '__DATA_CONST'} <= layout.keys():
        raise ValueError('This Traktor version does not expose the expected kit data.')
    text_base = layout['__TEXT'][0]
    positions = defaultdict(set)
    samples, tables = defaultdict(dict), defaultdict(dict)
    for line in symbol_text.splitlines():
        row = SYMBOL.match(line)
        if not row:
            continue
        address, segment, name = int(row[1], 16), row[2], row[3]
        positions[segment].add(address)
        match = KIT_SYMBOL.match(name)
        if not match or len(match[2]) != int(match[1]) or len(match[5]) != int(match[4]):
            continue
        if match[3] == '6sample' and segment == '__TEXT':
            samples[match[2]][match[5]] = address
        elif match[3] == '7pattern' and segment == '__DATA_CONST':
            tables[match[2]][match[5]] = address
    text_addresses = sorted(positions['__TEXT'])
    ends = dict(zip(text_addresses, text_addresses[1:]))

    def section(segment, address, length):
        base, start, size = layout[segment]
        relative = address - base
        if not 0 <= relative <= relative + length <= size or start + relative + length > len(data):
            raise ValueError('Kit data extends outside the Traktor executable section.')
        return data[start + relative:start + relative + length]

    def presets(address):
        result = []
        table = section('__DATA_CONST', address, 24 * 8)
        for slot in range(8):
            pointer, count, beats = struct.unpack_from('<QQd', table, slot * 24)
            if beats != 4 or not 1 <= count <= 16:
                raise ValueError('This Traktor version uses an unsupported preset layout.')
            start = text_base + (pointer & ((1 << 36) - 1))
            values = struct.unpack('<' + 'd' * count, section('__TEXT', start, 8 * count))
            if not all(math.isfinite(value) and 0 <= value <= 4 for value in values):
                raise ValueError('A Traktor pattern contains an invalid beat.')
            result.append(sorted({value % 4 for value in values}))
        return result

    kits = []
    if not samples or wanted - samples.keys():
        raise ValueError('The selected Pattern Player kits were not found.')
    for kit in sorted(wanted or samples.keys()):
        if len(samples[kit]) != 8:
            raise ValueError(f'{kit} does not have eight one-shots.')
        sounds = []
        for name, address in sorted(samples[kit].items(), key=lambda item: item[1]):
            end = ends.get(address, address)
            length = end - address
            if not 4 <= length <= 44100 * 4 * 5 or length % 4:
                raise ValueError(f'{kit} has an unsupported sample length.')
            pcm = section('__TEXT', address, length)
            if not all(math.isfinite(value) and abs(value) <= 1.001 for (value,) in struct.iter_unpack('<f', pcm)):
                raise ValueError(f'{kit} has an unsupported PCM sample.')
            names = ALIASES.get(kit, {})
            candidates = (names.get(name), name + 's', 's' + name + 's')
            table = next((tables[kit][key] for key in candidates if key in tables[kit]), None)
            if table is None:
                raise ValueError(f'{kit} has an unknown preset table for {name}.')
            sounds.append(dict(name=SOUND_NAMES.get(name, name.title()),
                               pcm=base64.b64encode(pcm).decode('ascii'), presets=presets(table)))
        label = {'roland808': '808 Kit', 'roland909': '909 Kit'}.get(kit, kit.replace('_', ' ').title())
        kits.append(dict(id=kit, name=label, sounds=sounds))
    return kits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--kit', action='append', default=[], help='Export only this kit ID. Repeat to select more kits.')
    args = parser.parse_args()
    executable = args.app / 'Contents/MacOS/Traktor Pro 4'
    if not executable.is_file():
        parser.error('Select a local Traktor Pro 4.app.')
    try:
        with TemporaryDirectory() as folder:
            with executable.open('rb') as source:
                thin = source.read(4) == b'\xcf\xfa\xed\xfe'
            image = executable if thin else Path(folder) / 'Traktor'
            if not thin:
                subprocess.run(['lipo', '-thin', 'arm64', str(executable), '-output', str(image)], check=True)
            symbols = subprocess.check_output(['nm', '-m', str(image)], text=True)
            with image.open('rb') as source, mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as data:
                kits = read_kits(data, symbols, set(args.kit))
        with args.output.open('x', encoding='utf-8') as output:
            json.dump(dict(version=1, kits=kits), output, separators=(',', ':'))
        print(f'Exported {len(kits)} kits to {args.output}.')
    except (OSError, ValueError, subprocess.SubprocessError, struct.error) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
