import struct
import unittest

from configure_midi_gadget import MODULAR_PRODUCTS
from traktor_factory_bridge import LIGHTS, LENGTHS, MODELS, LightReports, fragments
from traktor_factory_screens import HEIGHT, STRIDE, WIDTH, encode_screen
from z1_bridge import Decoder


class FactoryBridgeTests(unittest.TestCase):
    def test_every_light_report_crosses_the_midi_frame_limit(self):
        for key, model in MODELS.items():
            self.assertEqual(MODULAR_PRODUCTS[key], model.gadget)
            for report_id, size in enumerate(model.lights, 0x80):
                raw = bytes((report_id,)) + bytes(range(128, 128 + size - 1))
                assembly = LightReports(model)
                decoder = Decoder(LENGTHS)
                received = []
                for wire in fragments(LIGHTS, raw):
                    self.assertLessEqual(len(wire), 128)
                    for kind, payload in decoder.append(wire):
                        self.assertEqual(kind, LIGHTS)
                        if report := assembly.append(payload):
                            received.append(report)
                self.assertEqual(received, [raw])

    def test_late_and_wrong_light_chunks_are_discarded(self):
        model = MODELS['d2']
        size = model.lights[0]
        chunks = [Decoder(LENGTHS).append(frame)[0][1] for frame in
                  fragments(LIGHTS, b'\x80' + bytes(size - 1))]
        assembly = LightReports(model)
        self.assertIsNone(assembly.append(chunks[1]))
        self.assertIsNone(assembly.append(chunks[0]))
        self.assertIsNone(assembly.append(b'\x81' + chunks[1][1:]))
        self.assertIsNone(assembly.append(chunks[1]))
        self.assertIsNone(assembly.append(chunks[0]))
        self.assertEqual(len(assembly.append(chunks[1])), size)

    def test_screen_updates_only_changed_rows_and_uses_rgb565(self):
        old = bytes(HEIGHT * STRIDE)
        current = bytearray(old)
        offset = 7 * STRIDE
        current[offset:offset + 3] = b'\xff\x80\x00'
        report, = encode_screen(1, current, old)
        self.assertEqual(report[:4], b'\x84\0\x01\x60')
        self.assertEqual(struct.unpack('>HHH', report[10:16]), (7, WIDTH, 1))
        self.assertEqual(struct.unpack('>IH', report[16:22]), (WIDTH // 2, 0xfc00))
        self.assertEqual(report[-8:], b'\x03\0\0\0\x40\0\x01\0')
        self.assertEqual(list(encode_screen(1, current, current)), [])


class PerformanceBridgeTests(unittest.TestCase):
    def test_z2_capture_keeps_timecode_and_mic_pairs_separate(self):
        from traktor_factory_bridge import capture_configuration
        model = MODELS['z2']
        alsa = capture_configuration('plughw:2,0', model.capture_source_channels, model.capture)
        self.assertIn('slave.channels 8', alsa)
        self.assertEqual([row.strip() for row in alsa.splitlines() if 'ttable' in row], [
            'ttable.0.2 1', 'ttable.1.3 1', 'ttable.2.4 1', 'ttable.3.5 1', 'ttable.4.0 1', 'ttable.5.1 1',
        ])

    def test_s4_panel_uses_blue_in_the_high_bits(self):
        report, = encode_screen(0, b'\xff\x00\x00' * 2, width=2, height=1, runs=False)
        self.assertEqual(report[:4], b'\x84\0\0\x21')
        self.assertEqual(report[16:20], b'\0\x1f\0\x1f')
        self.assertEqual(report[20:], b'\x40\0\0\0')
