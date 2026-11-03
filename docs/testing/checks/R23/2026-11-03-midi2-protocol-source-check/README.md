# R23 Core MIDI protocol conversion source check — 3 November 2026

Application source: `dd49d060e136941eb3e17f5caec034a0dae5bb5d`.

Changed source: `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift`.

SHA-256: `0cc89736e786b79799ed8a8db5f19f7290c4b69843d9f1f4a23ac14504985874`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The changed controller connection source parsed without syntax errors. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The changed controller records passed the skill linter. |
| Swift type-check | BLOCKED | Command Line Tools Swift 6.3.3 does not match the installed SDK interface built with Swift 6.3.2. The compiler also could not write its module cache in the default location. |
| Tests, app build, MIDI hardware and iPad | NOT RUN | No test suite, app build, physical MIDI controller or iPad was used. |

The app requests MIDI 1.0 messages through Core MIDI's protocol-aware input port. Core MIDI can convert a MIDI 2.0 UMP source to that protocol. The existing controller layer then uses its current 7-bit values. Native MIDI 2.0 resolution and other UMP message types remain unsupported. The original Z1 SysEx bridge continues to use the legacy byte input.

Apple documents the protocol-aware [Core MIDI input port](https://developer.apple.com/documentation/coremidi/midiinputportcreatewithprotocol%28_%3A_%3A_%3A_%3A_%3A%29) and [MIDI 2 conversion](https://developer.apple.com/documentation/coremidi/incorporating-midi-2-into-your-apps). These documents support the API and protocol-conversion design. They do not verify the app's type-check or a connected controller.

## Next evidence

Type-check the app with a matching Xcode SDK. Then verify Learn with MIDI 1.0 and MIDI 2.0 sources, including notes, controls, pitch bend and unsupported message filtering. Erik owns the physical controller and iPad checks.
