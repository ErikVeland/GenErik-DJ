# R23 MIDI 2.0 controller source check: 3 November 2026

Application source: `c3958a18f85e6961b55700233b35ec286f5169b0`.

Changed source diff SHA-256 from `648f0ac`: `75ebfa414bb2cad7715ee2e311c667719fef542a9a6eaf0bdbc80d5d787e4182`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | All three changed Swift files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The R23 ledger and controller notes passed the skill linter. |
| Swift type-check | BLOCKED | Command Line Tools Swift 6.3.3 does not match the installed SDK's Swift 6.3.2. |
| Tests, signed iPad build and controller access | NOT RUN | No tests or build ran. No iPad or controller was accessed. |

The decoder now maps MIDI 2.0 registered and assignable controllers, their relative variants, per-note registered and assignable controllers, and per-note pitch bend. Learned bindings retain group, channel, parameter and note identity. Relative values use the specification's two's-complement field and clamp to 127 action steps in either direction. The decoder also reads the MIDI 2.0 Program Change value from its program field. The [MIDI 2.0 UMP specification](https://amei-music.github.io/midi2.0-docs/amei-pdf/M2-104-UM_v1-1-2_UMP_and_MIDI_2-0_Protocol_Specification.pdf) defines these message fields and relative-value format. Apple documents the [Core MIDI MIDI 2.0 input path](https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps).

## Next evidence

Use a matching Xcode SDK to type-check the app. Then verify Learn and action mapping with conformant MIDI 2.0 sources for RPN, NRPN, relative, per-note controller and per-note pitch messages. Confirm existing MIDI 1.0 mapping and persisted bindings still work. Erik owns physical controller and iPad acceptance.
