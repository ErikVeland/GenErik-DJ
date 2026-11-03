# R23 DDJ-REV5 profile source check: 3 November 2026

Application base commit: `ccff624b8148f683dd4d9ebb70fc93b5b03a7ec7`.

## Source identity

| File | SHA-256 |
| --- | --- |
| `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift` | `865b446dbe4291db58342bf3cf9fbfa2a464b002dbdf71405fbbcffecb347564` |
| `Replica/Sources/TDJInterface/ControllerSettingsView.swift` | `a242483e0796d73da7dd99e897be28e7177476fa903a85aeb740261f90c93114` |
| `Replica/Tests/TDJInterfaceTests/ControllerMIDIProfileTests.swift` | `62a5db1244f752a22a7a1bbe28446b295cd14e4783837bb40d5469eb4066a6c5` |

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller, Settings view and focused profile test files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The controller coverage, research and request records passed. |
| Focused package check | BLOCKED | `bash Replica/Scripts/check.sh --filter ControllerMIDIProfileTests` stopped before tests ran. Swift 6.3.3 crashed with `SmallVector unable to grow`; the compiler also reported `no such module 'Testing'`. Full output is in `package-check.log`. |
| iPad build and device check | NOT RUN | The user asked for development without iPad access. No iPad or controller was accessed. |

The opt-in profile uses Pioneer’s [published DDJ-REV5 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-rev5/ddj-rev5_midi_message_list_e1.pdf). It maps two-deck transport, mixer, tempo, loop controls, one momentary Shift layer, Hot Cue pads, jog/touch and wheel-side jog. A separate optional output profile maps play, sync, headphone-cue and Hot Cue lights. The profile omits deck 3/4 controls and other pad modes.

The message assignments match the published table. Core MIDI endpoint access, jog calibration, pad-mode behaviour, LED behaviour and hardware acceptance remain unverified. The focused profile tests are added but did not execute.
