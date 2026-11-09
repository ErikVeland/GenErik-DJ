import unittest
from mac_analysis_report import grid_metrics, percentile, summarise


class GridScoringTests(unittest.TestCase):
    reference = {
        'tempo': {'status': 'labelled', 'bpm': 120, 'beatAnchorSeconds': 0.1},
        'downbeat': {'status': 'labelled', 'barStartSeconds': 0.1},
    }

    def test_whole_bar_shift_has_no_phase_error(self):
        result = grid_metrics(120, 8.1, 8.1, self.reference, 200, 44100)
        self.assertAlmostEqual(result['beatPhaseMs'], 0)
        self.assertAlmostEqual(result['downbeatPhaseMs'], 0)
        self.assertAlmostEqual(result['maxFullTrackGridErrorMs'], 0)

    def test_tempo_octave_and_wrong_bar_are_separate_errors(self):
        doubled = grid_metrics(240, 0.1, 0.1, self.reference, 200, 44100)
        self.assertEqual(doubled['bpmError'], 120)
        self.assertGreater(doubled['maxFullTrackGridErrorMs'], 90000)
        wrong_bar = grid_metrics(120, 0.6, 0.6, self.reference, 200, 44100)
        self.assertAlmostEqual(wrong_bar['beatPhaseMs'], 0)
        self.assertAlmostEqual(wrong_bar['downbeatPhaseMs'], 500)

    def test_drift_accumulates_without_wrapping(self):
        result = grid_metrics(121, 0.1, 0.1, self.reference, 200, 44100)
        self.assertGreater(result['maxFullTrackGridErrorMs'], 1600)
        self.assertGreater(result['p95FullTrackGridErrorMs'], 1500)

    def test_missing_reference_and_missing_grid_are_different(self):
        self.assertIsNone(grid_metrics(120, 0, 0, {'tempo': {'status': 'unlabelled'}}, 200, 44100))
        self.assertEqual(grid_metrics(None, None, None, self.reference, 200, 44100), {'resolved': False})
        self.assertEqual(percentile([1, 2, 3], 0.5), 2)

    def test_final_tempo_only_decision_does_not_invent_a_downbeat(self):
        analysis = dict(contentSHA256='audio', frameCount=44100 * 180, sampleRate=44100,
                        bpm=160, beatAnchorFrame=8820, detectedDownbeatOffset=0)
        final = dict(analysis, bpm=80)
        del final['detectedDownbeatOffset']
        labels = dict(id='a', sha256='audio',
                      tempo=dict(status='labelled', bpm=80, beatAnchorSeconds=0.2),
                      downbeat=dict(status='labelled', barStartSeconds=0.2), key=dict(status='unlabelled'))
        report = dict(runID='test', manifest=dict(tracks=[labels]), rows=[
            dict(id='a', firstPass=analysis, finalAnalysis=final, acceptedTempoOnly=True)])
        provenance = dict(tracks=[dict(id='a', title='Synthetic octave case', audioSHA256='audio')])
        result = summarise(report, provenance)
        self.assertEqual(result['scores']['firstPass']['bpmWithinPointOne'], 0)
        self.assertEqual(result['scores']['finalGrid']['bpmWithinPointOne'], 1)
        self.assertEqual(result['scores']['finalGrid']['downbeatPhaseWithin25ms'], 0)


if __name__ == '__main__':
    unittest.main()
