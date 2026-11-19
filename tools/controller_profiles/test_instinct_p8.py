"""Keep P8 independent of original Instinct and private Bluetooth modes."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class InstinctP8Tests(unittest.TestCase):
    def test_independent_factory_profile_retains_selected_stream_and_output_contracts(self):
        by = {p['id']:p for p in json.loads((ROOT / 'Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json').read_text())['profiles']}
        self.assertTrue('Hercules DJControl Instinct P8' in by, 'Add the independent P8 contract')
        p = by['Hercules DJControl Instinct P8']
        self.assertTrue(p['autoSelect'])
        self.assertEqual((len(p['inputs']),len(p['outputs'])),(86,22))
        self.assertNotIn('audioOutput',p)
        self.assertEqual(len(p['bankChanges']),3)
        self.assertEqual([r.get('releaseShiftChannels') for r in p['bankChanges']],[[0],[1],None])
        self.assertTrue(all(r['channel']==0 for r in p['inputs']+p['outputs']))
        self.assertEqual(len(p['startup']),22)
        self.assertEqual(p['startup'],p['shutdown'])
        self.assertEqual([(r['number'],r['argument'],r.get('requiresTouch')) for r in p['inputs'] if r['action'].startswith('jog') and r['kind']=='control'],[(105,256,True),(106,256,True),(107,256,True),(108,256,True)])
        self.assertEqual([r['number'] for r in p['inputs'] if r['action'].startswith('tempo')],[49,51])
        self.assertTrue(all(r['onValue']==125 for r in p['outputs'] if r['action'].startswith('hotcue')))
        self.assertTrue(all(r['inverted'] for r in p['inputs'] if r['action'].startswith(('high','mid','low'))))

    def test_source_bytes_and_factory_four_target_contract_are_independent(self):
        from instinct_p8 import instinct_p8_profiles, P8_REFERENCES
        p = instinct_p8_profiles()[0]
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['kind']=='control' and r['number'] in [65,69,71,73]}, {'c'})
        self.assertEqual({r['targetDeck'] for r in p['inputs'] if r['kind']=='control' and r['number'] in [67,81,83,85]}, {'d'})
        self.assertNotIn('DJ Control Instinct',p['aliases'])
        ref = P8_REFERENCES[p['id']]
        path = ROOT / 'TestBuilds/r397/upstream/instinctp8-midi.pdf'
        if path.exists():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),ref['sha256'])
        source = ROOT / 'TestBuilds/r382/unpacked/djuced.pkg/Payload/Applications/DJUCED/DJUCED.app/Contents/Resources/midi/DJControl InstinctP8.djm'
        if source.exists():self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),ref['relatedSources'][0]['memberSHA256'])

    def test_public_source_limits_do_not_invent_queries_or_full_audio(self):
        from instinct_p8 import instinct_p8_profiles
        p=instinct_p8_profiles()[0]
        self.assertTrue(all(message[0]==0x90 and message[2]==0 for message in p['startup']+p['shutdown']))
        self.assertTrue(all(r['kind']=='note' and 0<=r['number']<=127 and 0<=r['onValue']<=127 for r in p['outputs']))
        self.assertIn('1024',p['scope'])
        self.assertIn('audio',' '.join(p['gaps']).lower())
