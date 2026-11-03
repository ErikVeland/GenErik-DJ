# R23 DDJ-REV1 profile source check: 3 November 2026

Branch: `feature/project-integration`.

## Change

The controller settings now offer opt-in DDJ-REV1 input and LED profiles. The input profile covers two-deck transport, mixer controls, tempo, loop controls, one momentary Shift layer, Hot Cue pads, platter jog/touch and wheel-side jog. The Hot Cue pads must be in Hot Cue mode. The LED profile covers play, sync, headphone-cue and Hot Cue status. The user selects a MIDI endpoint and confirms each profile. Feedback stays off until the user enables it.

The mappings use the [official DDJ-REV1 MIDI message list](https://www.pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-rev1/ddj-rev1_midi_message_list_e1.pdf). The unit tests check the published channels, message numbers, paired CC encoding, relative jog encoding and LED values.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The connection, Settings view and new profile tests parsed. |
| Source mapping review | PASS | The input and output values match the listed DDJ-REV1 MIDI channels and messages. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger, controller coverage, controller research and known-issues records passed. |
| Focused package tests | BLOCKED | `bash Scripts/check.sh --filter ControllerMIDIProfileTests` stopped while compiling `TDJInterface`. Swift 6.3.3 crashed with `SmallVector unable to grow`. The test target also reported `no such module 'Testing'`. The log is retained in `package-check.log`. |
| Controller and iPad checks | PENDING | No controller or iPad was accessed. |

## Source identity

| File | SHA-256 |
| --- | --- |
| `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift` | `ffb1e6efd59d72cf1dea9a8bfa35c526a35abc6205150cc15d62ce429c87af14` |
| `Replica/Sources/TDJInterface/ControllerSettingsView.swift` | `03a4acdbaa99802c1cd5b7ab78b5d3ec38b503bc3aa4249ead0c87fd0d8adddc` |
| `Replica/Tests/TDJInterfaceTests/ControllerMIDIProfileTests.swift` | `0d5d0a348e31927e0f3d962803bd3a5f4c8f89f2d18d0df95794ed6c0668ef95` |

## Remaining work

Type-check and run the focused tests with a supported Xcode toolchain. On a DDJ-REV1 MIDI endpoint, verify transport, loops, jog/touch, Hot Cue mode and status lights. Hardware acceptance remains open.
