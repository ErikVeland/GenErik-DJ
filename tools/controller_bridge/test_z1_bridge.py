import unittest
from unittest.mock import patch
from z1_bridge import Decoder, encode, valid_input, valid_output, write_report, announce


class Z1BridgeChecks(unittest.TestCase):
    def test_status_matches_independent_wire_fixture(self):
        self.assertEqual(encode(4, b'\x01'), bytes([0xf0, 0x7d, 0x47, 0x44, 0x4a, 1, 4, 1, 0, 1, 6, 0xf7]))

    def test_raw_hid_bits_survive_fragmentation_and_clock(self):
        payload = bytes((i * 37) % 256 for i in range(30))
        encoded = encode(1, payload)
        self.assertTrue(all(value < 128 for value in encoded[1:-1]))
        parser = Decoder()
        self.assertEqual(parser.append(encoded[:10]), [])
        self.assertEqual(parser.append(b'\xf8' + encoded[10:]), [(1, payload)])

    def test_corruption_and_oversized_frames_do_not_reach_hardware(self):
        encoded = bytearray(encode(2, bytes([0x80] + [0x0a] * 21)))
        encoded[9] ^= 1
        parser = Decoder()
        self.assertEqual(parser.append(encoded), [])
        self.assertEqual(parser.append(b'\xf0' + b'\x01' * 2048 + b'\xf7'), [])
        self.assertEqual(parser.append(encode(4, b'\x00')), [(4, b'\x00')])

    def test_only_z1_input_and_led_output_reports_are_valid(self):
        self.assertTrue(valid_input(b'\x01' + b'\x00' * 29))
        self.assertFalse(valid_input(b'\x01' + b'\xff' * 29))
        self.assertFalse(valid_input(b'\x01' + b'\x00' * 28 + b'\x80'))
        self.assertTrue(valid_output(b'\x80' + b'\x7f' * 21))
        self.assertFalse(valid_output(b'\x81' + b'\x7f' * 21))
        self.assertFalse(valid_output(b'\x80' + b'\xff' * 21))

    def test_unknown_kind_and_wrong_report_size_are_rejected(self):
        with self.assertRaises(ValueError): encode(99, b'\x00')
        with self.assertRaises(ValueError): encode(1, b'\x01')

    def test_a_partial_hid_write_stops_instead_of_sending_a_fragment(self):
        with patch('z1_bridge.select.select', return_value=([], [7], [])), patch('z1_bridge.os.write', return_value=21):
            with self.assertRaises(OSError): write_report(7, b'\x80' + b'\x0a' * 21)

    def test_late_app_connection_receives_calibration_status_and_current_report(self):
        output = []
        report = b'\x01' + b'\x00' * 29
        with patch('z1_bridge.calibration', return_value=None), patch('z1_bridge.write_all', side_effect=lambda fd, data: output.append(data)):
            announce(6, 7, report)
        self.assertEqual(output[0], bytes([0xf0, 0x7d, 0x47, 0x44, 0x4a, 1, 4, 1, 0, 1, 6, 0xf7]))
        self.assertEqual(Decoder().append(b''.join(output)), [(4, b'\x01'), (4, b'\x02'), (1, report)])


if __name__ == '__main__':
    unittest.main()
