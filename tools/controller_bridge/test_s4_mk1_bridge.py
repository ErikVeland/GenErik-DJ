import unittest

from s4_mk1_bridge import INPUT, LENGTHS, InputState, four_channel_pcm, unpack_lights
from z1_bridge import Decoder


class S4Mk1BridgeChecks(unittest.TestCase):
    def test_alsa_preserves_both_stereo_subdevices_in_order(self):
        config = four_channel_pcm('plughw:7,0')
        self.assertIn('slaves.first.pcm "hw:7,0,0"', config)
        self.assertIn('slaves.second.pcm "hw:7,0,1"', config)
        self.assertIn('bindings.2 { slave second channel 0 }', config)
        self.assertIn('bindings.3 { slave second channel 1 }', config)
        self.assertIn('slave.pcm "generik_s4_pairs"', config)

    def test_native_state_keeps_high_resolution_and_fixed_keys(self):
        state = InputState([0x100 + 63], [0] * 47)
        state.axes[2] = 4095
        state.axes[36] = 1023
        state.axes[46] = 15
        frames = [Decoder(LENGTHS).append(packet)[0] for packet in state.frames()]
        self.assertEqual([kind for kind, _ in frames], [INPUT, INPUT])
        buttons, pots = [frame[1] for frame in frames]
        self.assertEqual((buttons[0], buttons[9], buttons[14:16], buttons[26]),
                         (32, 128, b'\xff\x03', 15))
        self.assertEqual((pots[0], pots[6:8]), (73, b'\xff\x0f'))

    def test_light_frame_unpacks_only_the_documented_five_bit_controls(self):
        values = [0] * 163
        values[4], values[71], values[162] = 31, 19, 11
        word = sum(value << (index * 5) for index, value in enumerate(values))
        packet = b'\x80' + word.to_bytes(102, 'little')
        self.assertEqual(unpack_lights(packet), values)
        self.assertIsNone(unpack_lights(packet[:-1]))
        self.assertIsNone(unpack_lights(packet[:-1] + bytes([packet[-1] | 0x80])))


if __name__ == '__main__':
    unittest.main()
