import hashlib
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

from library_analysis_delivery import read_revision, stage
from prepare_library_analysis import prepare
from run_library_analysis_campaign import make_remaining, summary, reviewed_failures
from recover_library_analysis_sources import verify_source, publish


class CampaignTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.directory.name)
        self.addCleanup(self.directory.cleanup)

    def revision(self, automatic=True):
        data = json.dumps(dict(version=2, automaticAnalysis=automatic,
                              track=dict(analysis=dict(contentSHA256='a' * 64)))).encode()
        identifier = hashlib.sha256(data).hexdigest()
        (self.root / (identifier + '.payload')).write_bytes(data)
        path = self.root / (identifier + '.json')
        path.write_text(json.dumps(dict(id=identifier, automaticAnalysis=automatic, audioSHA256='a' * 64)))
        return path

    def test_corrupt_payload_is_not_staged(self):
        path = self.revision()
        path.with_suffix('.payload').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            read_revision(path)

    def test_full_phase_retains_exceptions_only_after_repeated_source_failures(self):
        errors = [dict(id='7', error='decode failed')]
        self.assertIsNone(reviewed_failures(self.root, errors))
        work = self.root / 'source-recovery' / '7'
        work.mkdir(parents=True)
        record = dict(id='7', title='Unavailable track', error='decode failed', attempts=2)
        (work / 'needs-review.json').write_text(json.dumps(record))
        self.assertIsNone(reviewed_failures(self.root, errors))
        record['attempts'] = 3
        (work / 'needs-review.json').write_text(json.dumps(record))
        self.assertEqual(reviewed_failures(self.root, errors), [record])

    def test_device_source_requires_matching_bytes_and_audio_dimensions(self):
        audio = self.root / 'source.caf'
        audio.write_bytes(b'original')
        response = dict(sha256=hashlib.sha256(b'original').hexdigest(), sampleRate=44100, frameCount=42, channelCount=2)
        expected = dict(analysis=dict(contentSHA256=response['sha256'], sampleRate=44100, frameCount=42, channelCount=2))
        verify_source(audio, response, expected)
        expected['analysis']['frameCount'] = 43
        with self.assertRaises(RuntimeError):
            verify_source(audio, response, expected)
        audio.write_bytes(b'changed')
        with self.assertRaises(RuntimeError):
            verify_source(audio, response, None)

    def test_recovery_retains_failed_attempt_and_publishes_complete_archive(self):
        path = self.revision()
        output = self.root / 'recovery'
        (output / 'outbox').mkdir(parents=True)
        (output / 'results').mkdir()
        for source in [path, path.with_suffix('.payload')]:
            (output / 'outbox' / source.name).write_bytes(source.read_bytes())
        result = dict(id='7', revisionID=path.stem, audioSHA256='a' * 64)
        (output / 'results' / '7.json').write_text(json.dumps(result))
        destination = self.root / 'ipad'
        (destination / 'results').mkdir(parents=True)
        (destination / 'results' / '7.json').write_text(json.dumps(dict(id='7', error='identity mismatch')))
        publish(output, destination, '7')
        publish(output, destination, '7')
        self.assertEqual(len(list((destination / 'failed-attempts').glob('*.json'))), 1)
        self.assertEqual(json.loads((destination / 'results' / '7.json').read_text()), result)
        read_revision(destination / 'outbox' / path.name)

    def test_manual_archive_is_not_staged(self):
        with self.assertRaises(ValueError):
            read_revision(self.revision(automatic=False))

    def test_payload_precedes_index_and_restart_skips_staged_revision(self):
        path = self.revision()
        calls = []
        account = 'b' * 64
        def command(arguments, log):
            calls.append(arguments)
            if arguments[:3] == ['device', 'copy', 'from']:
                pathlib.Path(arguments[arguments.index('--destination') + 1]).write_text(account)
        with patch('library_analysis_delivery.command', command):
            self.assertEqual(stage([self.root], 'duo', account, self.root / 'state'), (1, 1))
            self.assertEqual(stage([self.root], 'duo', account, self.root / 'state'), (0, 0))
        transfers = [x[x.index('--source') + 1] for x in calls if x[:3] == ['device', 'copy', 'to']]
        self.assertEqual(transfers, [str(path.with_suffix('.payload')), str(path)])

    def test_account_change_stops_transfer(self):
        self.revision()
        def command(arguments, log):
            pathlib.Path(arguments[arguments.index('--destination') + 1]).write_text('c' * 64)
        with patch('library_analysis_delivery.command', command), self.assertRaises(RuntimeError):
            stage([self.root], 'duo', 'b' * 64, self.root / 'state')

    def test_accented_metadata_finds_candidates_without_claiming_identity(self):
        audio = self.root / 'song.m4a'
        audio.touch()
        mac = [dict(title='Song', artist='Beyonce\u0301', album='Album', duration=100, path=str(audio))]
        device = dict(items=[dict(title='Song', artist='Beyoncé', album='Album', duration=100,
                                 availability='available', source=dict(platform='iosMusic', persistentID='7'))])
        result = prepare(device, dict(tracks=[]), mac)['items'][0]
        self.assertEqual(result['paths'], [str(audio)])
        self.assertIsNone(result['expected'])

    def test_full_phase_excludes_only_successful_ipad_sources_and_duplicate_paths(self):
        results = self.root / 'ipad' / 'results'
        results.mkdir(parents=True)
        paths = [self.root / name for name in ['done.m4a', 'failed.m4a', 'new.m4a']]
        for path in paths:
            path.touch()
        (results / '1.json').write_text(json.dumps(dict(source=str(paths[0]), revisionID='a' * 64)))
        (results / '2.json').write_text(json.dumps(dict(id='2', source=str(paths[1]), error='failed')))
        mac = [dict(path=str(path), duration=100, persistentID=str(i), title=str(i), artist='', protected=False)
               for i, path in enumerate(paths)]
        count, excluded = make_remaining(mac + [mac[-1]], self.root / 'ipad', self.root / 'full.json')
        self.assertEqual(count, 2)
        self.assertEqual(excluded, dict(iPadRun=1, duplicatePath=1))
        self.assertEqual(summary(self.root / 'ipad')['complete'], 1)


if __name__ == '__main__':
    unittest.main()
