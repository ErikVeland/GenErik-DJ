# R23 MIDI 2.0 native-resolution source check: 3 November 2026

Application source: `309af8c1476cd3f4e04f4f6445608ac470ea8c2e`.

Changed Swift source diff SHA-256 from `19334ac`: `f2b995b474f6c211019266ba8856f40f9e2442c5cb55b5ff11f2e6f382265d51`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The Core MIDI message decoder, value decoder and connection files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported for the source changes. |
| STE linter | PASS | The request ledger and controller research records passed the skill linter. |
| Type-check, app build and tests | NOT RUN | This pass kept to source checks. No iPad or simulator was accessed. |

The input port requests MIDI 2.0 UMP. The decoder handles MIDI 1.0 UMP and MIDI 2.0 channel voice note, Control Change, pitch, pressure and program messages. It preserves UMP groups, 16-bit note velocity and 32-bit continuous values in the action path. Relative encodings and paired 14-bit CC mappings remain limited to 7-bit MIDI 1.0 messages. Other UMP message types are skipped.

Apple documents that Core MIDI converts messages to the protocol requested by the input port and calls the receive block on a high-priority thread. The implementation keeps bounded packet, word and message counts before handing decoded input to the main-thread inbox. This source check does not verify Core MIDI conversion on a physical endpoint. [Core MIDI input-port documentation](https://developer.apple.com/documentation/coremidi/midiinputportcreatewithprotocol%28_%3A_%3A_%3A_%3A_%3A%29), [Apple MIDI 2 integration guide](https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps), [MIDI 2.0 overview](https://midi.org/what-musicians-artists-need-to-know-about-midi-2-0).

## Next evidence

On a MIDI 2.0 source, confirm 32-bit CC, pressure and pitch values reach learned controls without 7-bit truncation. Confirm MIDI 1.0 sources still work through Core MIDI conversion, group-specific mappings stay separate, and unsupported UMP types do not trigger actions. Verify protocol fallback, disconnect recovery and input bounds on the actual iPad setup.
