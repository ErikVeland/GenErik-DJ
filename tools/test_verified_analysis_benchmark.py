import copy
import unittest

import verified_analysis_benchmark as benchmark
from build_verified_analysis_corpus import balanced_cohort, split_groups, standard_key
from probe_rhythm_checkpoints import peaks
from compare_key_candidate import as_scoring_report


def corpus():
    return {
        'format': 'generik.verified-analysis/v1', 'version': 'test-1',
        'sources': {'human': {'url': 'https://example.org/labels', 'revision': 'abc',
                              'sha256': 'b' * 64, 'origin': 'published-human'}},
        'tracks': [{'id': 'a', 'path': '/tmp/a.wav', 'sha256': 'a' * 64,
                    'groups': ['artist:a'], 'split': 'development', 'dataset': 'fixture',
                    'labels': {'beats': {'source': 'human', 'times': [0.1, 0.6, 1.1, 1.6]},
                               'key': {'source': 'human', 'tonic': 0, 'mode': 'major'}}}],
    }


class VerifiedBenchmarkTests(unittest.TestCase):
    def test_learned_key_reports_require_separate_versions(self):
        candidate = {'format': 'generik.learned-key-audit/v1', 'rows': [], 'modelArtifactSHA256': 'a' * 64,
                     'profile': {'modelID': 'test', 'weightsSHA256': 'b' * 64}}
        with self.assertRaisesRegex(ValueError, 'versions'):
            as_scoring_report(candidate)
        candidate['profile'].update(preprocessingVersion=1, conversionVersion=1, decisionPolicyVersion=1)
        self.assertEqual(as_scoring_report(candidate)['rows'], [])

    def test_neural_plateaus_remain_single_beats(self):
        self.assertEqual(peaks([-1, 2, 2, -1, -1, -1, -1, 3, -1]), [.03, .14])
        self.assertEqual(peaks([-1, 2, 2, -1], interpolate=True), [.03])

    def test_interpolation_recovers_subframe_peak(self):
        logits = [4 - (i - 4.25) ** 2 for i in range(9)]
        self.assertAlmostEqual(peaks(logits, interpolate=True)[0], 4.25 / 50)

    def test_ambiguous_and_modal_keys_do_not_become_single_keys(self):
        for text in ('C major | A minor', 'D minor dorian', 'Eb other', 'X', 'E_ major ionian'):
            self.assertIsNone(standard_key(text))
        self.assertEqual(standard_key('Gb minor harmonic'), {'tonic': 6, 'mode': 'minor'})
        self.assertEqual(standard_key('C major ionian'), {'tonic': 0, 'mode': 'major'})

    def test_collaborating_artists_and_audio_duplicates_stay_together(self):
        tracks = [
            {'id': 'a', 'groups': ['artist:a'], 'sha256': 'a' * 64},
            {'id': 'b', 'groups': ['artist:a', 'artist:b'], 'sha256': 'b' * 64},
            {'id': 'c', 'groups': ['artist:b'], 'sha256': 'c' * 64},
            {'id': 'd', 'groups': ['artist:d'], 'sha256': 'c' * 64},
        ]
        split_groups(tracks)
        self.assertEqual(len({t['split'] for t in tracks}), 1)

    def test_selection_is_stable_when_source_order_changes(self):
        tracks = [{'id': str(i), 'genre': str(i % 3)} for i in range(20)]
        selected = balanced_cohort(tracks, 9)
        self.assertEqual(selected, balanced_cohort(list(reversed(tracks)), 9))
        self.assertEqual(len({t['id'] for t in selected}), 9)

    def test_valid_corpus_has_field_scoped_labels(self):
        benchmark.validate(corpus())

    def test_rejects_automatic_labels_in_verified_score(self):
        data = corpus()
        data['sources']['human']['origin'] = 'automatic'
        with self.assertRaisesRegex(ValueError, 'human'):
            benchmark.validate(data)

    def test_rejects_artist_or_recording_overlap(self):
        data = corpus()
        other = copy.deepcopy(data['tracks'][0])
        other.update(id='b', sha256='c' * 64, split='holdout')
        data['tracks'].append(other)
        with self.assertRaisesRegex(ValueError, 'split'):
            benchmark.validate(data)

    def test_rejects_audio_hash_overlap_even_with_different_groups(self):
        data = corpus()
        other = copy.deepcopy(data['tracks'][0])
        other.update(id='b', groups=['artist:b'], split='holdout')
        data['tracks'].append(other)
        with self.assertRaisesRegex(ValueError, 'split'):
            benchmark.validate(data)

    def test_rejects_invalid_or_unordered_annotation(self):
        for times in ([0.1, float('nan')], [0.2, 0.1], [0.1, 0.1]):
            data = corpus()
            data['tracks'][0]['labels']['beats']['times'] = times
            with self.assertRaises(ValueError):
                benchmark.validate(data)

    def test_rejects_duplicate_audio_within_a_split(self):
        data = corpus()
        other = copy.deepcopy(data['tracks'][0])
        other.update(id='duplicate', groups=['artist:alternate-name'])
        data['tracks'].append(other)
        with self.assertRaisesRegex(ValueError, 'Duplicate audio'):
            benchmark.validate(data)

    def test_one_prediction_cannot_match_two_references(self):
        score = benchmark.event_score([0.1, 0.12], [0.11], tolerance=0.025)
        self.assertEqual(score['matched'], 1)
        self.assertEqual(score['recall'], 0.5)

    def test_half_and_double_tempo_are_penalised(self):
        refs = [0.1, 0.6, 1.1, 1.6]
        half = benchmark.event_score(refs, [0.1, 1.1])
        double = benchmark.event_score(refs, [0.1, 0.35, 0.6, 0.85, 1.1, 1.35, 1.6])
        self.assertEqual(half['recall'], 0.5)
        self.assertEqual(double['precision'], 4 / 7)
        self.assertLess(half['f1'], 1)

    def test_opening_beats_are_scored(self):
        score = benchmark.event_score([0.1, 0.6, 1.1], [1.1])
        self.assertEqual(score['referenceEvents'], 3)
        self.assertEqual(score['matched'], 1)

    def test_unmatched_events_are_in_timing_error_distribution(self):
        score = benchmark.event_score([0.1, 0.6, 1.1], [0.1, 0.6])
        self.assertGreater(score['p95NearestErrorMs'], 400)
        self.assertEqual(score['matchedP95ErrorMs'], 0)

    def test_relative_key_is_not_exact(self):
        expected = {'tonic': 0, 'mode': 'major'}
        self.assertEqual(benchmark.key_score(expected, {'tonic': 9, 'mode': 'minor'}),
                         {'exact': False, 'relation': 'relative', 'weighted': 0.3})
        self.assertEqual(benchmark.key_score(expected, None)['weighted'], 0)

    def test_mac_manifest_contains_no_reference_answers(self):
        manifest = benchmark.audit_manifest(corpus(), 'development')
        track = manifest['tracks'][0]
        self.assertEqual(track['tempo'], {'status': 'unlabelled'})
        self.assertEqual(track['key'], {'status': 'unlabelled'})
        self.assertEqual(track['downbeat'], {'status': 'unlabelled'})
        self.assertEqual(manifest['corpus'], 'humanReference')

    def test_failed_rows_count_in_denominator(self):
        data = corpus()
        report = {'runID': 'r', 'completedUTC': 'now', 'manifest': benchmark.audit_manifest(data, 'development'),
                  'rows': [{'id': 'a', 'error': 'decode failed'}]}
        score = benchmark.score_report(data, report)
        self.assertEqual(score['tiers']['final']['key']['referenceTracks'], 1)
        self.assertEqual(score['tiers']['final']['key']['exact'], 0)
        self.assertEqual(score['tiers']['final']['beats']['referenceEvents'], 4)
        self.assertEqual(score['tiers']['final']['beats']['recall'], 0)

    def test_rejects_changed_hash_or_missing_row(self):
        data = corpus()
        report = {'runID': 'r', 'completedUTC': 'now', 'manifest': benchmark.audit_manifest(data, 'development'),
                  'rows': [{'id': 'a', 'firstPass': {'contentSHA256': 'f' * 64}}]}
        with self.assertRaisesRegex(ValueError, 'hash'):
            benchmark.score_report(data, report)
        report['rows'] = []
        with self.assertRaisesRegex(ValueError, 'rows'):
            benchmark.score_report(data, report)


if __name__ == '__main__':
    unittest.main()
