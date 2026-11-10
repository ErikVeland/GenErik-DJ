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
