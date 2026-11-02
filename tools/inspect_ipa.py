#!/usr/bin/env python3
"""Inventory an IPA without extracting or modifying its contents."""
import argparse
import hashlib
import json
import plistlib
import struct
import zipfile
from pathlib import Path


def macho(data):
    magic = data[:4]
    thin = {b'\xce\xfa\xed\xfe': ('<', 28), b'\xcf\xfa\xed\xfe': ('<', 32),
            b'\xfe\xed\xfa\xce': ('>', 28), b'\xfe\xed\xfa\xcf': ('>', 32)}
    fat = {b'\xca\xfe\xba\xbe': ('>', False), b'\xbe\xba\xfe\xca': ('<', False),
           b'\xca\xfe\xba\xbf': ('>', True), b'\xbf\xba\xfe\xca': ('<', True)}
    if magic in fat:
        endian, wide = fat[magic]
        count, = struct.unpack_from(endian + 'I', data, 4)
        stride = 32 if wide else 20
        if count > (len(data) - 8) // stride:
            raise ValueError('Invalid universal binary header')
        result = []
        for i in range(count):
            offset, size = struct.unpack_from(endian + ('QQ' if wide else 'II'),
                                              data, 8 + i * stride + 8)
            if offset + size > len(data):
                raise ValueError('Binary slice exceeds file size')
            result.extend(macho(data[offset:offset + size]))
        return result
    if magic not in thin:
        return []
    endian, header_size = thin[magic]
    cpu, subtype, _, ncmds, sizeofcmds = struct.unpack_from(endian + '5I', data, 4)
    limit = header_size + sizeofcmds
    if limit > len(data) or ncmds > sizeofcmds // 8:
        raise ValueError('Invalid Mach-O command table')
    result = {'cpu_type': cpu, 'cpu_subtype': subtype,
              'architecture': {12: 'arm', 0x100000c: 'arm64', 7: 'x86',
                               0x1000007: 'x86_64'}.get(cpu, 'unknown'),
              'bits': 64 if header_size == 32 else 32, 'encryption_commands': []}
    pos = header_size
    for _ in range(ncmds):
        if pos + 8 > limit:
            raise ValueError('Truncated load command')
        cmd, size = struct.unpack_from(endian + 'II', data, pos)
        if size < 8 or pos + size > limit:
            raise ValueError('Invalid load command size')
        if cmd in (0x21, 0x2c):
            if size < (24 if cmd == 0x2c else 20):
                raise ValueError('Truncated encryption command')
            offset, length, cryptid = struct.unpack_from(endian + 'III', data, pos + 8)
            result['encryption_commands'].append(
                {'offset': offset, 'size': length, 'cryptid': cryptid})
        pos += size
    return [result]


def inspect(path):
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        plists = [n for n in names if n.startswith('Payload/')
                  and n.count('/') == 2 and n.endswith('.app/Info.plist')]
        if len(plists) != 1:
            raise ValueError('Expected one top-level app Info.plist')
        info = plistlib.loads(archive.read(plists[0]))
        executable = plists[0].rsplit('/', 1)[0] + '/' + info['CFBundleExecutable']
        files = []
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            with archive.open(entry) as stream:
                file_digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            files.append({'path': entry.filename, 'size': entry.file_size,
                          'sha256': file_digest})
        keys = ('CFBundleIdentifier', 'CFBundleDisplayName', 'CFBundleExecutable',
                'CFBundleShortVersionString', 'CFBundleVersion', 'MinimumOSVersion',
                'UIDeviceFamily', 'UIBackgroundModes', 'UISupportedInterfaceOrientations')
        return {'package': path.name, 'size': path.stat().st_size, 'sha256': digest,
                'metadata': {k: info[k] for k in keys if k in info},
                'executable': executable, 'slices': macho(archive.read(executable)),
                'files': files}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    try:
        report = inspect(args.ipa)
    except (OSError, ValueError, KeyError, struct.error, zipfile.BadZipFile,
            plistlib.InvalidFileException) as error:
        parser.exit(1, f'Cannot inspect IPA: {error}\n')
    print(json.dumps(report, indent=2))
