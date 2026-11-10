import unittest

from traktor_modular_bridge import INPUT, LENGTHS, X1_MK3, Z1_MK2, feedback, input_frame
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


if __name__ == '__main__':
    unittest.main()
