# R23 reserved UMP packet length check: 3 November 2026

Base commit: `95c092d`.

## Change

The decoder now skips reserved UMP message types using their allocated sizes: one, two, three or four 32-bit words. Data words inside a reserved packet cannot be read as MIDI events. Truncated reserved packets are rejected. The [MIDI Association UMP specification](https://amei-music.github.io/midi2.0-docs/amei-pdf/M2-104-UM_v1-1-2_UMP_and_MIDI_2-0_Protocol_Specification.pdf) defines these message sizes.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift syntax parse | PASS | The decoder and focused test source parsed. |
| Standalone decoder assertions | PASS | The compiled production decoder skipped reserved packet payloads, retained the following note event and rejected truncated packets. |
| Repository test command | BLOCKED | `bash Replica/Scripts/check.sh --filter ControllerMIDIUMPDecoderTests` stopped during `TDJInterface` code generation with a Swift 6.3.3 `SmallVector unable to grow` crash. The test target also reported that it could not import `Testing`. The repository tests did not run. Full output is in `package-check.log`. |
| Whitespace check | PASS | `git diff --check` reported no errors. |
| Controller and iPad checks | PENDING | No hardware or iPad was accessed. |

## Source identity

| File | SHA-256 |
| --- | --- |
| `Replica/Sources/TDJCore/ControllerMIDI.swift` | `540b6b477194fdf1db3ee990ed40917302f1c9815b977f85d1125c3492bcb6eb` |
| `Replica/Tests/TDJCoreTests/ControllerMIDIUMPDecoderTests.swift` | `610e17f6466dce5498b6da67c0d5377fc5cc9afd6fee40ef09bd96d797fdd288` |

## Remaining work

Type-check and run the package tests with a supported Xcode toolchain. Verify unsupported packet handling and controller input on the iPad setup.
