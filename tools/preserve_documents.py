#!/usr/bin/env python3
"""Copy Traktor's shared documents from the reference iPad without changing it."""
import asyncio
import hashlib
import json
import shutil
from pathlib import Path

from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.house_arrest import HouseArrestService

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'Backups' / 'traktor-documents-2026-10-21'
REPORT = ROOT / 'Analysis' / 'document-acquisition.json'
UDID = '3c4b6e12624a577712d178b63203c9d7c249bf77'
BUNDLE = 'com.native-instruments.traktordj'


async def main():
    DEST.mkdir(exist_ok=False)
    report = {'device': UDID, 'bundle': BUNDLE, 'source': 'USB House Arrest VendDocuments',
              'destination': str(DEST), 'scope': 'Shared documents only. Private container unavailable.',
              'status': 'in_progress', 'files': []}

    def save():
        REPORT.write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        async with await create_using_usbmux(serial=UDID, connection_type='USB') as device:
            assert device.all_values['ProductType'] == 'iPad7,3', 'Unexpected target device'
            async with await HouseArrestService.create(device, BUNDLE, documents_only=True) as afc:
                for name in await afc.listdir('/Documents'):
                    if name in ('.', '..') or '/' in name or '\\' in name:
                        raise ValueError('Unsafe document name')
                    stat = await afc.stat('/Documents/' + name)
                    report['files'].append({'name': name, 'size': stat['st_size'],
                                            'type': stat['st_ifmt'], 'status': 'pending'})
                total = sum(f['size'] for f in report['files'] if f['type'] == 'S_IFREG')
                budget = shutil.disk_usage(DEST).free - 5 * 1024**3
                report['total_regular_file_bytes'] = total
                report['recordings_fit_available_space'] = total <= budget
                print(f'Document inventory: {len(report["files"])} entries, {total:,} bytes. '
                      f'Copy budget: {budget:,} bytes.', flush=True)
                save()
                for row in sorted(report['files'], key=lambda f: (not f['name'].endswith('.xml'), f['name'])):
                    if row['type'] != 'S_IFREG':
                        row['status'] = 'deferred_nonregular'
                    elif total > budget and not row['name'].endswith('.xml'):
                        row['status'] = 'deferred_insufficient_space'
                    else:
                        local = DEST / row['name']
                        await afc.pull('/Documents/' + row['name'], str(local), progress_bar=False)
                        if local.stat().st_size != row['size']:
                            raise ValueError('Document size changed during transfer: ' + row['name'])
                        with local.open('rb') as stream:
                            row['sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
                        row['status'] = 'copied_size_verified'
                        print('Copied: ' + row['name'], flush=True)
                    save()
        report['status'] = 'complete' if all(f['status'] == 'copied_size_verified' for f in report['files']) else 'partial'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        save()


if __name__ == '__main__':
    asyncio.run(main())
