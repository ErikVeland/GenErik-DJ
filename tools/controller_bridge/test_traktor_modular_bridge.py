import importlib.util
import unittest

from traktor_modular_bridge import INPUT, LENGTHS, S2_MK1, S2_MK1_INPUT, X1_MK3, Z1_MK2, feedback, input_frame
from z1_bridge import Decoder


class TraktorModularBridgeChecks(unittest.TestCase):
    def test_both_models_preserve_input_bytes_and_reject_wrong_reports(self):
        for model in (Z1_MK2, X1_MK3):
            report = bytes([1, 0xff] + [0] * (model.input_size - 2))
            frame = input_frame(model, report)
            self.assertEqual(Decoder(LENGTHS).append(frame), [(INPUT, bytes([len(report)]) + report.ljust(35, b'\0'))])
            self.assertIsNone(input_frame(model, report[:-1]))
            self.assertIsNone(input_frame(model, bytes([2]) + report[1:]))

    def test_only_the_matching_light_report_can_reach_the_hardware(self):
        for model in (Z1_MK2, X1_MK3):
            report = bytes([0x80] + [0x2e] * (model.light_size - 1))
            payload = bytes([len(report)]) + report.ljust(50, b'\0')
            self.assertEqual(feedback(model, payload), report)
            self.assertIsNone(feedback(model, payload[:1] + b'\x81' + payload[2:]))
            self.assertIsNone(feedback(model, payload[:2] + b'\xff' + payload[3:]))
            self.assertIsNone(feedback(model, bytes([len(report) - 1]) + payload[1:]))


class S2Mk1BridgeChecks(unittest.TestCase):
    def test_preserves_mk1_reports_and_only_accepts_mk1_led_brightness(self):
        for report_id, length in [(1, 16), (2, 52), (0xd4, 33)]:
            report = bytes([report_id, 0xff] + [0] * (length - 2))
            frame = input_frame(S2_MK1, report)
            payload = bytes([length]) + report.ljust(52, b'\0')
            self.assertEqual(Decoder(LENGTHS).append(frame), [(S2_MK1_INPUT, payload)])
            self.assertIsNone(input_frame(S2_MK1, report[:-1]))
        report = b'\x80' + bytes([0x1f]) * 61
        self.assertEqual(feedback(S2_MK1, report), report)
        self.assertIsNone(feedback(S2_MK1, report[:-1] + b'\x20'))
        self.assertIsNone(feedback(S2_MK1, b'\x81' + report[1:]))


@unittest.skipUnless(importlib.util.find_spec("PIL"), "Pillow is required for OLED drawing.")
class PatternScreenTests(unittest.TestCase):
    def test_pattern_screen_writes_only_the_two_fx_oleds(self):
        from traktor_modular_bridge import pattern_screen_report

        payload = bytes([1, 1, 0x11, 0x11, 4, 1]) + b'Factory Kit'.ljust(29, b'\0') + b'Kick'.ljust(29, b'\0')
        frame = pattern_screen_report(payload)
        self.assertEqual((frame[0], len(frame)), (0xe4, 1025))
        self.assertTrue(any(frame[1:]))
        def pixel(x, y):
            return bool(frame[1 + 16 * y + x // 8] & (0x80 >> (x % 8)))
        self.assertTrue(pixel(4, 55))
        self.assertFalse(pixel(12, 55))
        self.assertTrue(pixel(36, 61))
        self.assertFalse(pixel(44, 61))
        blank = pattern_screen_report(bytes(64))
        self.assertEqual(blank, b'\xe0' + bytes(1024))
        self.assertIsNone(pattern_screen_report(bytes([2]) + payload[1:]))
        self.assertIsNone(pattern_screen_report(payload[:-1]))


if __name__ == '__main__':
    unittest.main()
