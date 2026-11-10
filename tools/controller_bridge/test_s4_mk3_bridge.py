import unittest

from s4_mk3_bridge import INPUT, LENGTHS, LIGHTS, RING, STATUS, audio_command, frame, valid_feedback
from z1_bridge import Decoder


class S4Mk3BridgeChecks(unittest.TestCase):
    def test_splits_raw_hid_frames_over_midi_without_losing_high_bits(self):
        report = bytes([3] + [0xff] * 43)
        encoded = frame(INPUT, report)
        decoder = Decoder(LENGTHS)
        self.assertEqual(decoder.append(encoded[:55]), [])
        [(kind, data)] = decoder.append(encoded[55:] + frame(STATUS, b'\x01'))[:1]
        self.assertEqual(kind, INPUT)
        self.assertEqual(data[0], len(report))
        self.assertEqual(data[1:1 + len(report)], report)
        with self.assertRaises(ValueError):
            frame(INPUT, report[:-1])

    def test_accepts_panel_and_ring_feedback_and_blocks_motor_reports(self):
        self.assertTrue(valid_feedback(LIGHTS, bytes([0x80] + [0] * 94)))
        ring = bytes([0x32, 1, 5] + [0] * 6 + [47] * 32)
        self.assertTrue(valid_feedback(RING, ring))
        self.assertFalse(valid_feedback(RING, bytes([0x31]) + ring[1:]))
        self.assertFalse(valid_feedback(RING, ring[:1] + bytes([2]) + ring[2:]))
        self.assertFalse(valid_feedback(RING, ring[:9] + bytes([127]) + ring[10:]))

    def test_forwards_four_channels_with_independent_clock_resampling(self):
        self.assertEqual(
            audio_command('hw:UAC2Gadget', 'plughw:2,0'),
            ['alsaloop', '-C', 'hw:UAC2Gadget', '-P', 'plughw:2,0', '-c', '4', '-r', '48000',
             '-f', 'S32_LE', '-t', '20000', '-S', '4'],
        )
