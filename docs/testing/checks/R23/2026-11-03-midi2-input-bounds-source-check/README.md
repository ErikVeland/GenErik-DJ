# R23 MIDI 2 input bounds source check — 3 November 2026

Application source: `1ef097e044ae27cf934229e5aa604b39c179f98a`.

Changed source: `Replica/Sources/TDJInterface/ControllerMIDIConnection.swift`.

SHA-256: `4bd551a8567c30e511ac185305c5579f6f97932e9b394b9140f02a805f194bf4`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The controller connection source parsed without syntax errors. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The request ledger passed the skill linter. |
| Tests, app build, MIDI hardware and iPad | NOT RUN | No test suite, app build, physical MIDI controller or iPad was used. |

The protocol-aware input caps each callback at 128 event packets, 1,024 words per packet and 4,096 words total. It caps decoded bytes at 4,096. Oversized input uses the existing overflow path and disconnects the controller. Unsupported UMP message types do not enter the input queue.

## Next evidence

Type-check the app with a matching Xcode SDK. Then check input latency and overflow handling with real MIDI 1.0 and MIDI 2.0 sources. Erik owns the physical controller and iPad checks.
